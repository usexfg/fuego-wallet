import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/heat_amm.dart';
import '../../services/fuego_daemon_client.dart';

class HearthState {
  final bool isLoading;
  final PoolInfo? pool;
  final AmmQuote? quote;
  final String? error;

  const HearthState({this.isLoading = false, this.pool, this.quote, this.error});

  HearthState copyWith({bool? isLoading, PoolInfo? pool, AmmQuote? quote, String? error}) =>
      HearthState(isLoading: isLoading ?? this.isLoading, pool: pool ?? this.pool,
          quote: quote, error: error);
}

class HearthCubit extends Cubit<HearthState> {
  final FuegoDaemonClient _daemon;

  HearthCubit(this._daemon) : super(const HearthState());

  Future<void> loadPool() async {
    emit(state.copyWith(isLoading: true));
    try {
      final pool = await _daemon.getPoolInfo();
      emit(state.copyWith(isLoading: false, pool: pool));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> getQuote({required bool sellXfg, required String amount}) async {
    try {
      final quote = await _daemon.getAmmQuote(sellXfg: sellXfg, amount: amount);
      emit(state.copyWith(quote: quote));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<Map<String, dynamic>> executeSwap({
    required bool sellXfg,
    required String inputAmount,
    required String minOutput,
  }) async {
    return _daemon.swap(sellXfg: sellXfg, inputAmount: inputAmount, minOutput: minOutput);
  }

  Future<Map<String, dynamic>> addLiquidity({
    required String xfgAmount,
    required String heatAmount,
  }) async {
    return _daemon.addLiquidity(xfgAmount: xfgAmount, heatAmount: heatAmount);
  }

  Future<Map<String, dynamic>> removeLiquidity({
    required String shares,
    required String minXfg,
    required String minHeat,
  }) async {
    return _daemon.removeLiquidity(shares: shares, minXfg: minXfg, minHeat: minHeat);
  }
}
