import 'dart:async';
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
  final String status;

  const MiningState({
    this.isMining = false,
    this.isPoolMining = true,
    this.hashrate = 0,
    this.sharesAccepted = 0,
    this.sharesSubmitted = 0,
    this.poolHost = 'loudmining.com',
    this.poolPort = 4200,
    this.error,
    this.status = 'idle',
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
    String? status,
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
        status: status ?? this.status,
      );
}

class MiningCubit extends Cubit<MiningState> {
  final PoolMiningService _pool;
  Timer? _refreshTimer;

  MiningCubit()
      : _pool = PoolMiningService(),
        super(const MiningState()) {
    _pool.onAuthorized = () {
      if (!isClosed) emit(state.copyWith(status: 'mining'));
    };
  }

  Future<void> startMining({required String walletAddress, String? poolHost, int? poolPort}) async {
    if (state.isMining) return;

    final host = poolHost ?? state.poolHost;
    final port = poolPort ?? state.poolPort;
    emit(state.copyWith(poolHost: host, poolPort: port, status: 'connecting', error: null));

    final ok = await _pool.start(
      walletAddress: walletAddress,
      poolHost: host,
      poolPort: port,
    );

    if (ok) {
      emit(state.copyWith(isMining: true, status: 'connected', error: null));
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => refreshStatus());
    } else {
      emit(state.copyWith(status: 'error', error: 'Failed to connect to ${host}:${port}'));
    }
  }

  Future<void> stopMining() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    await _pool.stop();
    emit(state.copyWith(isMining: false, hashrate: 0, status: 'idle'));
  }

  void refreshStatus() {
    if (!state.isMining) return;
    final h = _pool.hashrate;
    final shares = _pool.sharesAccepted;
    emit(state.copyWith(
      hashrate: h,
      sharesAccepted: shares,
      sharesSubmitted: shares,
      status: h > 0 ? 'mining' : 'connected',
    ));
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    _pool.stop();
    return super.close();
  }
}
