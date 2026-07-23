import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/core.dart';
import '../../models/subaddress.dart';
import '../../services/fuego_vault_service.dart';
import '../../services/security_service.dart';

class WalletState extends Equatable {
  final bool isLoading;
  final bool isConnected;
  final bool isSyncing;
  final bool isUnlocked;
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
    this.isUnlocked = false,
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
    bool? isUnlocked,
    String? error,
    bool clearError = false,
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
        isUnlocked: isUnlocked ?? this.isUnlocked,
        error: clearError ? null : (error ?? this.error),
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

  @override
  List<Object?> get props => [
        isLoading,
        isConnected,
        isSyncing,
        isUnlocked,
        error,
        balance,
        unlockedBalance,
        address,
        alias,
        syncProgress,
        isSynced,
        transactions,
        blockHeight,
        peerCount,
        scannedHeight,
        subaddresses,
      ];
}

class WalletCubit extends Cubit<WalletState> {
  final FuegoDaemonClient _daemon;
  final FuegoVaultService? _vault;
  final Future<void>? _backendReady;
  final SecurityService _security;
  final SubaddressStore _subaddressStore = SubaddressStore();

  WalletCubit(
    this._daemon, {
    FuegoVaultService? vault,
    Future<void>? backendReady,
    SecurityService? security,
  })  : _vault = vault,
        _backendReady = backendReady,
        _security = security ?? SecurityService(),
        super(const WalletState()) {
    _init();
  }

  Future<void> _init() async {
    await _subaddressStore.load();
    emit(state.copyWith(subaddresses: _subaddressStore.subaddresses));
    if (_backendReady != null) {
      await _backendReady;
    }
    // Do not auto-refresh with secrets until unlocked
    if (_vault?.isUnlocked == true) {
      emit(state.copyWith(isUnlocked: true, address: _vault!.address));
      await refreshWallet();
    } else {
      emit(state.copyWith(isUnlocked: false));
    }
  }

  Future<void> onUnlocked() async {
    if (_vault == null || !_vault!.isUnlocked) return;
    emit(state.copyWith(
      isUnlocked: true,
      address: _vault!.address,
      clearError: true,
    ));
    await refreshWallet();
  }

  Future<void> lock() async {
    _vault?.lock();
    emit(const WalletState());
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint(msg);
  }

  Future<void> refreshWallet() async {
    if (_vault != null && !_vault!.isUnlocked) {
      emit(state.copyWith(
        isLoading: false,
        isSyncing: false,
        isUnlocked: false,
        error: 'Wallet locked',
      ));
      return;
    }

    _log('[wallet] refreshWallet starting');
    emit(state.copyWith(isLoading: true, isSyncing: true, clearError: true));

    for (var attempt = 0; attempt < 15; attempt++) {
      try {
        NetworkInfo? info;
        int peers = 0;
        try {
          info = await _daemon.getInfo();
        } catch (e) {
          _log('[wallet] getInfo failed attempt $attempt');
        }
        try {
          peers = await _daemon.getPeerCount();
        } catch (_) {}

        String addr = '';
        int bal = 0;
        int unlocked = 0;
        List<FuegoTransaction> txs = [];

        if (_vault != null && _vault!.address.isNotEmpty) {
          addr = _vault!.address;
        } else {
          try {
            addr = await _daemon.getWalletAddress();
          } catch (_) {}
        }

        int scannedH = state.scannedHeight;
        if (_vault != null &&
            _vault!.isUnlocked &&
            _vault!.viewSecretKey != null &&
            _vault!.spendPublicKey != null) {
          try {
            final scan = await _daemon.scanBalance(
              viewSecret: _vault!.viewSecretKey!,
              spendPublic: _vault!.spendPublicKey!,
              startHeight: scannedH,
              batchSize: 500,
            );
            bal = scan['balance'] as int? ?? 0;
            unlocked = scan['unlocked_balance'] as int? ??
                scan['unlockedBalance'] as int? ??
                bal;
            scannedH = scan['scanned_height'] as int? ?? scannedH;
          } catch (e) {
            _log('[wallet] scanBalance failed — local fallback');
            try {
              final d = await _daemon.getBalanceDetailed();
              bal = d.available + d.locked;
              unlocked = d.available;
            } catch (_) {}
          }
        } else {
          try {
            final d = await _daemon.getBalanceDetailed();
            bal = d.available + d.locked;
            unlocked = d.available;
          } catch (_) {
            try {
              bal = await _daemon.getBalance();
              unlocked = bal;
            } catch (_) {}
          }
        }

        try {
          txs = await _daemon.getTransactions(count: 50);
        } catch (_) {}

        emit(state.copyWith(
          isLoading: false,
          isSyncing: false,
          isConnected: true,
          isUnlocked: _vault?.isUnlocked ?? true,
          blockHeight: info?.height ?? 0,
          address: addr.isNotEmpty ? addr : state.address,
          balance: bal,
          unlockedBalance: unlocked,
          peerCount: peers,
          transactions: txs,
          syncProgress: 1.0,
          isSynced: true,
          scannedHeight: scannedH,
          clearError: true,
        ));
        return;
      } catch (e) {
        if (attempt < 14) {
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
    if (_vault != null && _vault!.isUnlocked && _vault!.address.isNotEmpty) {
      return _vault!.address;
    }
    try {
      return await _daemon.getWalletAddress();
    } catch (_) {
      return state.address ?? '';
    }
  }

  Future<Subaddress?> createSubaddress(String label) async {
    if (_vault == null || !_vault!.isUnlocked || _vault!.vaultBytes == null) {
      return null;
    }
    try {
      final index = _subaddressStore.nextIndex;
      final address = _vault!.ffi.vaultGetAddress(_vault!.vaultBytes!, index);
      if (address.isEmpty) return null;
      final sub = await _subaddressStore.add(address: address, label: label);
      emit(state.copyWith(subaddresses: _subaddressStore.subaddresses));
      return sub;
    } catch (e) {
      _log('[wallet] createSubaddress failed');
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

  /// Send requires a verified PIN. Default mixin is 7 (not 0).
  Future<String> sendTransaction({
    required String address,
    required double amount,
    required double fee,
    required String pin,
    int mixin = 7,
  }) async {
    if (!state.isUnlocked && !(_vault?.isUnlocked ?? false)) {
      throw StateError('Wallet is locked');
    }
    final pinOk = await _security.verifyPIN(pin);
    if (!pinOk) {
      throw StateError('Invalid PIN');
    }
    if (amount <= 0) {
      throw ArgumentError('Amount must be positive');
    }
    if (fee < 0) {
      throw ArgumentError('Fee cannot be negative');
    }
    final totalAtomic =
        ((amount + fee) * atomicPerCoin).round();
    if (totalAtomic > state.unlockedBalance) {
      throw StateError('Insufficient unlocked balance (including fee)');
    }

    final req = SendTransactionRequest(
      address: address,
      amount: amount,
      fee: fee,
      mixin: mixin,
    );
    final txHash = await _daemon.sendTransaction(req);
    if (txHash.isEmpty) {
      throw StateError('Empty transaction hash');
    }
    unawaited(refreshWallet());
    return txHash;
  }

  Future<void> refreshTransactions() async {
    try {
      final txs = await _daemon.getTransactions(count: 50);
      emit(state.copyWith(transactions: txs));
    } catch (_) {}
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
