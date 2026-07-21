import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/core.dart';
import '../../models/subaddress.dart';
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
  final List<Subaddress> subaddresses;

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
    this.subaddresses = const [],
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
    List<Subaddress>? subaddresses,
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
        subaddresses: subaddresses ?? this.subaddresses,
      );

  double get balanceXfg => balance / atomicPerCoin;
  double get unlockedBalanceXfg => unlockedBalance / atomicPerCoin;
}

class WalletCubit extends Cubit<WalletState> {
  final FuegoDaemonClient _daemon;
  final FuegoVaultService? _vault;
  final Future<void>? _backendReady;
  final SubaddressStore _subaddressStore = SubaddressStore();

  WalletCubit(this._daemon, {FuegoVaultService? vault, Future<void>? backendReady})
      : _vault = vault,
        _backendReady = backendReady,
        super(const WalletState()) {
    _init();
  }

  Future<void> _init() async {
    await _subaddressStore.load();
    emit(state.copyWith(subaddresses: _subaddressStore.subaddresses));
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
            try {
              bal = await _daemon.getBalance();
              print('[wallet] attempt $attempt: getBalance (walletd fallback) OK — $bal');
            } catch (e2) {
              print('[wallet] attempt $attempt: getBalance (walletd fallback) FAILED — $e2');
            }
          }
        } else {
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

  /// Generate a new subaddress locally via FFI.
  Future<Subaddress?> createSubaddress(String label) async {
    if (_vault == null || _vault!.vaultBytes == null) return null;

    try {
      final index = _subaddressStore.nextIndex;
      final address = _vault!.ffi.vaultGetAddress(_vault!.vaultBytes!, index);
      if (address.isEmpty) return null;

      final sub = await _subaddressStore.add(address: address, label: label);
      emit(state.copyWith(subaddresses: _subaddressStore.subaddresses));
      return sub;
    } catch (e) {
      print('[wallet] createSubaddress failed: $e');
      return null;
    }
  }

  Future<void> removeSubaddress(int index) async {
    await _subaddressStore.remove(index);
    emit(state.copyWith(subaddresses: _subaddressStore.subaddresses));
  }

  Future<void> updateSubaddressLabel(int index, String label) async {
    await _subaddressStore.updateLabel(index, label);
    emit(state.copyWith(subaddresses: _subaddressStore.subaddresses));
  }

  Future<String> sendTransaction({
    required String address,
    required double amount,
    required double fee,
    int mixin = 0,
  }) async {
    final req = SendTransactionRequest(
      address: address,
      amount: amount,
      fee: fee,
      mixin: mixin,
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
}
