import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/core.dart';

class WalletState {
  final bool isLoading;
  final bool isConnected;
  final bool isSyncing;
  final bool isMining;
  final int miningSpeed;
  final int miningThreads;
  final String? error;
  final int balance;
  final int unlockedBalance;
  final String? address;
  final double syncProgress;
  final bool isSynced;
  final List<FuegoTransaction> transactions;
  final int blockHeight;
  final int peerCount;

  const WalletState({
    this.isLoading = false,
    this.isConnected = false,
    this.isSyncing = false,
    this.isMining = false,
    this.miningSpeed = 0,
    this.miningThreads = 1,
    this.error,
    this.balance = 0,
    this.unlockedBalance = 0,
    this.address,
    this.syncProgress = 0,
    this.isSynced = false,
    this.transactions = const [],
    this.blockHeight = 0,
    this.peerCount = 0,
  });

  WalletState copyWith({
    bool? isLoading,
    bool? isConnected,
    bool? isSyncing,
    bool? isMining,
    int? miningSpeed,
    int? miningThreads,
    String? error,
    int? balance,
    int? unlockedBalance,
    String? address,
    double? syncProgress,
    bool? isSynced,
    List<FuegoTransaction>? transactions,
    int? blockHeight,
    int? peerCount,
  }) =>
      WalletState(
        isLoading: isLoading ?? this.isLoading,
        isConnected: isConnected ?? this.isConnected,
        isSyncing: isSyncing ?? this.isSyncing,
        isMining: isMining ?? this.isMining,
        miningSpeed: miningSpeed ?? this.miningSpeed,
        miningThreads: miningThreads ?? this.miningThreads,
        error: error,
        balance: balance ?? this.balance,
        unlockedBalance: unlockedBalance ?? this.unlockedBalance,
        address: address ?? this.address,
        syncProgress: syncProgress ?? this.syncProgress,
        isSynced: isSynced ?? this.isSynced,
        transactions: transactions ?? this.transactions,
        blockHeight: blockHeight ?? this.blockHeight,
        peerCount: peerCount ?? this.peerCount,
      );

  double get balanceXfg => balance / atomicPerCoin;
  double get unlockedBalanceXfg => unlockedBalance / atomicPerCoin;
}

class WalletCubit extends Cubit<WalletState> {
  final FuegoDaemonClient _daemon;

  WalletCubit(this._daemon) : super(const WalletState()) {
    refreshWallet();
  }

  Future<void> refreshWallet() async {
    emit(state.copyWith(isLoading: true, isSyncing: true, error: null));

    for (var attempt = 0; attempt < 15; attempt++) {
      try {
        NetworkInfo? info;
        int peers = 0;
        try {
          info = await _daemon.getInfo();
        } catch (_) {}
        try {
          peers = await _daemon.getPeerCount();
        } catch (_) {}

        String addr = '';
        int bal = 0;
        List<FuegoTransaction> txs = [];
        try {
          addr = await _daemon.getAddress();
        } catch (_) {}
        try {
          bal = await _daemon.getBalance();
        } catch (_) {}
        try {
          txs = await _daemon.getTransactions(count: 50);
        } catch (_) {}

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
        ));
        return;
      } catch (_) {
        if (attempt < 4) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    }

    emit(state.copyWith(
      isLoading: false,
      isSyncing: false,
      isConnected: false,
      error: 'Daemon not available',
    ));
  }

  Future<String> getAddress() async {
    try {
      return await _daemon.getAddress();
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

  Future<void> startMining({int threads = 1, String? address}) async {
    await _daemon.startMining(threads: threads, address: address);
    emit(state.copyWith(isMining: true, miningThreads: threads));
  }

  Future<void> stopMining() async {
    await _daemon.stopMining();
    emit(state.copyWith(isMining: false, miningSpeed: 0));
  }

  Future<void> refreshMiningStatus() async {
    try {
      final status = await _daemon.getMiningStatus();
      final active = (status['active'] ?? status['status'] == 'active') as bool? ?? false;
      emit(state.copyWith(
        isMining: active,
        miningSpeed: (status['speed'] ?? status['hashrate'] ?? 0) as int,
      ));
    } catch (_) {}
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
    final addr = await _daemon.getAddress();
    return '$addr?payment_id=$paymentId';
  }
}
