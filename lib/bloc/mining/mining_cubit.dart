import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/pool_mining_service.dart';

class MiningState {
  final bool isMining;
  final bool isPoolMining;
  final int hashrate;
  final int sharesAccepted;
  final int sharesSubmitted;
  final String poolHost;
  final int poolPort;
  final String? error;

  const MiningState({
    this.isMining = false,
    this.isPoolMining = true,
    this.hashrate = 0,
    this.sharesAccepted = 0,
    this.sharesSubmitted = 0,
    this.poolHost = 'loudmining.com',
    this.poolPort = 3333,
    this.error,
  });

  MiningState copyWith({
    bool? isMining,
    bool? isPoolMining,
    int? hashrate,
    int? sharesAccepted,
    int? sharesSubmitted,
    String? poolHost,
    int? poolPort,
    String? error,
  }) =>
      MiningState(
        isMining: isMining ?? this.isMining,
        isPoolMining: isPoolMining ?? this.isPoolMining,
        hashrate: hashrate ?? this.hashrate,
        sharesAccepted: sharesAccepted ?? this.sharesAccepted,
        sharesSubmitted: sharesSubmitted ?? this.sharesSubmitted,
        poolHost: poolHost ?? this.poolHost,
        poolPort: poolPort ?? this.poolPort,
        error: error,
      );
}

class MiningCubit extends Cubit<MiningState> {
  final PoolMiningService _pool;

  MiningCubit()
      : _pool = PoolMiningService(),
        super(const MiningState());

  Future<void> startMining({required String walletAddress, String? poolHost, int? poolPort}) async {
    if (state.isMining) return;

    if (poolHost != null) emit(state.copyWith(poolHost: poolHost));
    if (poolPort != null) emit(state.copyWith(poolPort: poolPort));

    final ok = await _pool.start(
      walletAddress: walletAddress,
      poolHost: poolHost ?? state.poolHost,
      poolPort: poolPort ?? state.poolPort,
    );

    if (ok) {
      emit(state.copyWith(isMining: true, error: null));
    } else {
      emit(state.copyWith(error: 'Failed to connect to pool ${state.poolHost}:${state.poolPort}'));
    }
  }

  Future<void> stopMining() async {
    await _pool.stop();
    emit(state.copyWith(isMining: false, hashrate: 0));
  }

  void refreshStatus() {
    if (!state.isMining) return;
    emit(state.copyWith(
      hashrate: _pool.hashrate,
      sharesAccepted: _pool.sharesAccepted,
      sharesSubmitted: _pool.sharesAccepted,
    ));
  }
}
