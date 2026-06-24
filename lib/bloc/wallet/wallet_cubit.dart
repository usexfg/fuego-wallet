import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crypto/crypto.dart';
import 'package:fuego_defi_sdk/fuego_defi_sdk.dart';
import 'package:fuego_defi_rpc_methods/src/common_structures/general/balance_info.dart';
import '../../services/fuego_rpc_service.dart';
import '../../models/wallet.dart' as legacy;

class WalletState {
  final bool isLoading;
  final bool isConnected;
  final bool isSyncing;
  final bool isMining;
  final int miningSpeed;
  final int miningThreads;
  final String? error;
  final double xfgBalance;
  final double xfgUnlockedBalance;
  final String? xfgAddress;
  final double syncProgress;
  final bool isSynced;
  final List<String> enabledCoins;
  final List<legacy.WalletTransaction> transactions;

  const WalletState({
    this.isLoading = false,
    this.isConnected = false,
    this.isSyncing = false,
    this.isMining = false,
    this.miningSpeed = 0,
    this.miningThreads = 1,
    this.error,
    this.xfgBalance = 0,
    this.xfgUnlockedBalance = 0,
    this.xfgAddress,
    this.syncProgress = 0,
    this.isSynced = false,
    this.enabledCoins = const [],
    this.transactions = const [],
  });

  WalletState copyWith({
    bool? isLoading,
    bool? isConnected,
    bool? isSyncing,
    bool? isMining,
    int? miningSpeed,
    int? miningThreads,
    String? error,
    double? xfgBalance,
    double? xfgUnlockedBalance,
    String? xfgAddress,
    double? syncProgress,
    bool? isSynced,
    List<String>? enabledCoins,
    List<legacy.WalletTransaction>? transactions,
  }) =>
      WalletState(
        isLoading: isLoading ?? this.isLoading,
        isConnected: isConnected ?? this.isConnected,
        isSyncing: isSyncing ?? this.isSyncing,
        isMining: isMining ?? this.isMining,
        miningSpeed: miningSpeed ?? this.miningSpeed,
        miningThreads: miningThreads ?? this.miningThreads,
        error: error,
        xfgBalance: xfgBalance ?? this.xfgBalance,
        xfgUnlockedBalance: xfgUnlockedBalance ?? this.xfgUnlockedBalance,
        xfgAddress: xfgAddress ?? this.xfgAddress,
        syncProgress: syncProgress ?? this.syncProgress,
        isSynced: isSynced ?? this.isSynced,
        enabledCoins: enabledCoins ?? this.enabledCoins,
        transactions: transactions ?? this.transactions,
      );
}

class WalletCubit extends Cubit<WalletState> {
  final FuegoDefiSdk _sdk;
  final FuegoRPCService _rpc;

  WalletCubit(this._sdk, this._rpc) : super(const WalletState());

  Future<void> refreshWallet() async {
    emit(state.copyWith(isLoading: true, isSyncing: true, error: null));
    try {
      final wallet = await _rpc.getBalance();
      final address = await _rpc.getAddress();
      emit(state.copyWith(
        isLoading: false,
        isSyncing: false,
        isConnected: true,
        isSynced: wallet.synced,
        syncProgress: wallet.syncProgress,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        isSyncing: false,
        isConnected: false,
        error: e.toString(),
      ));
    }
  }

  Future<String> getAddress() async {
    return await _rpc.getAddress();
  }

  Future<String> sendTransaction({
    required String address,
    required String amount,
    required String fee,
    required int mixins,
    String paymentId = '',
  }) async {
    final request = legacy.SendTransactionRequest(
      amount: int.parse(amount),
      address: address,
      fee: int.parse(fee),
      mixins: mixins,
      paymentId: paymentId,
    );
    return _rpc.sendTransaction(request);
  }

  Future<void> startMining({int threads = 1}) async {
    await _rpc.startMining(threads: threads);
    emit(state.copyWith(isMining: true, miningThreads: threads));
  }

  Future<void> stopMining() async {
    await _rpc.stopMining();
    emit(state.copyWith(isMining: false, miningSpeed: 0));
  }

  Future<void> refreshMiningStatus() async {
    try {
      final status = await _rpc.getMiningStatus();
      emit(state.copyWith(
        isMining: status['active'] as bool,
        miningSpeed: status['speed'] as int,
        miningThreads: status['threads'] as int? ?? 1,
      ));
    } catch (_) {}
  }

  String generatePaymentId() {
    final bytes = List<int>.generate(32, (i) => DateTime.now().millisecondsSinceEpoch + i);
    return sha256.convert(bytes).toString().substring(0, 64);
  }

  Future<String> createIntegratedAddress(String paymentId) async {
    return _rpc.createIntegratedAddress(paymentId);
  }

  Future<void> refreshTransactions() async {
    try {
      final txs = await _rpc.getTransactions();
      emit(state.copyWith(transactions: txs));
    } catch (_) {}
  }

  Future<void> refreshSdkBalances() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final enabled = await _sdk.assets.getEnabledCoins();
      emit(state.copyWith(
        isLoading: false,
        enabledCoins: enabled.toList(),
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void clearError() => emit(state.copyWith(error: null));
}
