import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuego_defi_sdk/fuego_defi_sdk.dart';
import 'package:fuego_defi_types/fuego_defi_types.dart';

// ── State ──

class WalletState {
  final bool isLoading;
  final bool isMining;
  final int miningSpeed;
  final int miningThreads;
  final String? error;
  final Map<String, AssetBalanceInfo> balances;
  final List<String> enabledCoins;
  final int syncProgress;
  final bool isSynced;

  const WalletState({
    this.isLoading = false,
    this.isMining = false,
    this.miningSpeed = 0,
    this.miningThreads = 1,
    this.error,
    this.balances = const {},
    this.enabledCoins = const [],
    this.syncProgress = 0,
    this.isSynced = false,
  });

  WalletState copyWith({
    bool? isLoading,
    bool? isMining,
    int? miningSpeed,
    int? miningThreads,
    String? error,
    Map<String, AssetBalanceInfo>? balances,
    List<String>? enabledCoins,
    int? syncProgress,
    bool? isSynced,
  }) =>
      WalletState(
        isLoading: isLoading ?? this.isLoading,
        isMining: isMining ?? this.isMining,
        miningSpeed: miningSpeed ?? this.miningSpeed,
        miningThreads: miningThreads ?? this.miningThreads,
        error: error,
        balances: balances ?? this.balances,
        enabledCoins: enabledCoins ?? this.enabledCoins,
        syncProgress: syncProgress ?? this.syncProgress,
        isSynced: isSynced ?? this.isSynced,
      );
}

// ── Cubit ──

class WalletCubit extends Cubit<WalletState> {
  final FuegoDefiSdk _sdk;

  WalletCubit(this._sdk) : super(const WalletState());

  Future<void> refresh() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final balanceManager = _sdk.balances;
      final balances = await balanceManager.getAllBalances();

      final assets = _sdk.assets;
      final enabled = await assets.getEnabledAssetIds();

      emit(state.copyWith(
        isLoading: false,
        balances: balances,
        enabledCoins: enabled.map((e) => e.toString()).toList(),
        isSynced: true,
        syncProgress: 100,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> enableCoin(String ticker, {required List<String> electrumServers}) async {
    emit(state.copyWith(isLoading: true));
    try {
      final assetId = AssetId.fromString(ticker);
      await _sdk.activation.enableCoin(
        assetId,
        ActivationConfig.electrum(servers: electrumServers),
      );
      await refresh();
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void setMining(bool active, {int speed = 0, int threads = 1}) {
    emit(state.copyWith(
      isMining: active,
      miningSpeed: speed,
      miningThreads: threads,
    ));
  }

  void clearError() => emit(state.copyWith(error: null));
}
