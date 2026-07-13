import 'dart:async';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/core.dart';
import '../../services/fuego_vault_service.dart';

class WalletState {
  final bool isLoading;
  final bool isConnected;
  final bool isSyncing;
  final String? error;
  final int balance;
  final int unlockedBalance;
  final String? address;
  final String? alias;
  final double syncProgress;
  final bool isSynced;
  final List<FuegoTransaction> transactions;
  final int blockHeight;
  final int peerCount;
  final int scannedHeight;

  const WalletState({
    this.isLoading = false,
    this.isConnected = false,
    this.isSyncing = false,
    this.error,
    this.balance = 0,
    this.unlockedBalance = 0,
    this.address,
    this.alias,
    this.syncProgress = 0,
    this.isSynced = false,
    this.transactions = const [],
    this.blockHeight = 0,
    this.peerCount = 0,
    this.scannedHeight = 0,
  });

  WalletState copyWith({
    bool? isLoading,
    bool? isConnected,
    bool? isSyncing,
    String? error,
    int? balance,
    int? unlockedBalance,
    String? address,
    String? alias,
    double? syncProgress,
    bool? isSynced,
    List<FuegoTransaction>? transactions,
    int? blockHeight,
    int? peerCount,
    int? scannedHeight,
  }) =>
      WalletState(
        isLoading: isLoading ?? this.isLoading,
        isConnected: isConnected ?? this.isConnected,
        isSyncing: isSyncing ?? this.isSyncing,
        error: error,
        balance: balance ?? this.balance,
        unlockedBalance: unlockedBalance ?? this.unlockedBalance,
        address: address ?? this.address,
        alias: alias ?? this.alias,
        syncProgress: syncProgress ?? this.syncProgress,
        isSynced: isSynced ?? this.isSynced,
        transactions: transactions ?? this.transactions,
        blockHeight: blockHeight ?? this.blockHeight,
        peerCount: peerCount ?? this.peerCount,
        scannedHeight: scannedHeight ?? this.scannedHeight,
      );

  double get balanceXfg => balance / atomicPerCoin;
  double get unlockedBalanceXfg => unlockedBalance / atomicPerCoin;
}

class WalletCubit extends Cubit<WalletState> {
  final FuegoDaemonClient _daemon;
  final FuegoVaultService? _vault;
  final Future<void>? _backendReady;

  WalletCubit(this._daemon, {FuegoVaultService? vault, Future<void>? backendReady})
      : _vault = vault,
        _backendReady = backendReady,
        super(const WalletState()) {
    _init();
  }

  Future<void> _init() async {
    if (_backendReady != null) {
      await _backendReady;
    }
    refreshWallet();
  }

  Future<void> refreshWallet() async {
    print('[wallet] refreshWallet starting');
    emit(state.copyWith(isLoading: true, isSyncing: true, error: null));

    for (var attempt = 0; attempt < 15; attempt++) {
      try {
        NetworkInfo? info;
        int peers = 0;
        try {
          info = await _daemon.getInfo();
          print('[wallet] attempt $attempt: getInfo OK — height=${info.height}, peers=${info.peerCount}');
        } catch (e) {
          print('[wallet] attempt $attempt: getInfo FAILED — $e');
        }
        try {
          peers = await _daemon.getPeerCount();
          print('[wallet] attempt $attempt: getPeerCount OK — $peers');
        } catch (e) {
          print('[wallet] attempt $attempt: getPeerCount FAILED — $e');
        }

        String addr = '';
        int bal = 0;
        List<FuegoTransaction> txs = [];

        // Try vault for instant local address (no walletd needed)
        if (_vault != null && _vault!.address.isNotEmpty) {
          addr = _vault!.address;
          print('[wallet] attempt $attempt: vault address OK — $addr');
        } else {
          try {
            addr = await _daemon.getWalletAddress();
            print('[wallet] attempt $attempt: getWalletAddress OK — $addr');
          } catch (e) {
            print('[wallet] attempt $attempt: getWalletAddress FAILED — $e');
          }
        }

        // Scan blockchain for our outputs using FFI (bypasses walletd)
        int scannedH = state.scannedHeight;
        if (_vault != null && _vault!.viewSecretKey != null && _vault!.spendPublicKey != null) {
          try {
            final scan = await _daemon.scanBalance(
              viewSecret: _vault!.viewSecretKey!,
              spendPublic: _vault!.spendPublicKey!,
              startHeight: scannedH,
              batchSize: 500,
            );
            bal = scan['balance'] as int? ?? 0;
            scannedH = scan['scanned_height'] as int? ?? scannedH;
            print('[wallet] attempt $attempt: scanBalance OK — bal=$bal, scanned=$scannedH');
          } catch (e) {
            print('[wallet] attempt $attempt: scanBalance FAILED — $e');
            // Fallback to walletd
            try {
              bal = await _daemon.getBalance();
              print('[wallet] attempt $attempt: getBalance (walletd fallback) OK — $bal');
            } catch (e2) {
              print('[wallet] attempt $attempt: getBalance (walletd fallback) FAILED — $e2');
            }
          }
        } else {
          // No vault keys — try walletd
          try {
            bal = await _daemon.getBalance();
            print('[wallet] attempt $attempt: getBalance OK — $bal');
          } catch (e) {
            print('[wallet] attempt $attempt: getBalance FAILED — $e');
          }
        }

        try {
          txs = await _daemon.getTransactions(count: 50);
          print('[wallet] attempt $attempt: getTransactions OK — ${txs.length} txs');
        } catch (e) {
          print('[wallet] attempt $attempt: getTransactions FAILED — $e');
        }

        emit(state.copyWith(
          isLoading: false,
          isSyncing: false,
          isConnected: true,
          blockHeight: info?.height ?? 0,
          address: addr.isNotEmpty ? addr : state.address,
          balance: bal,
          unlockedBalance: bal,
          peerCount: peers,
          transactions: txs,
          syncProgress: 1.0,
          isSynced: true,
          scannedHeight: scannedH,
        ));
        print('[wallet] refreshWallet SUCCESS on attempt $attempt');
        return;
      } catch (e) {
        print('[wallet] attempt $attempt: outer error — $e');
        if (attempt < 14) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    }

    print('[wallet] refreshWallet FAILED after 15 attempts');
    emit(state.copyWith(
      isLoading: false,
      isSyncing: false,
      isConnected: false,
      error: 'Daemon not available',
    ));
  }

  Future<String> getAddress() async {
    if (_vault != null && _vault!.address.isNotEmpty) {
      return _vault!.address;
    }
    try {
      return await _daemon.getWalletAddress();
    } catch (_) {
      return state.address ?? '';
    }
  }

  Future<String> sendTransaction({
    required String address,
    required double amount,
    required double fee,
    int mixin = 0,
    String paymentId = '',
  }) async {
    final req = SendTransactionRequest(
      address: address,
      amount: amount,
      fee: fee,
      mixin: mixin,
      paymentId: paymentId.isNotEmpty ? paymentId : null,
    );
    final txHash = await _daemon.sendTransaction(req);
    refreshWallet();
    return txHash;
  }

  Future<void> refreshTransactions() async {
    try {
      final txs = await _daemon.getTransactions(count: 50);
      emit(state.copyWith(transactions: txs));
    } catch (_) {}
  }

  void clearError() => emit(state.copyWith(error: null));

  String generatePaymentId() {
    final rand = Random().nextInt(1 << 30);
    final bytes = '$rand${DateTime.now().millisecondsSinceEpoch}'.codeUnits;
    return sha256.convert(bytes).toString().substring(0, 64);
  }

  Future<String> createIntegratedAddress(String paymentId) async {
    final addr = _vault != null && _vault!.address.isNotEmpty
        ? _vault!.address
        : await _daemon.getWalletAddress();
    return '$addr?payment_id=$paymentId';
  }
}
