import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/heat_amm.dart';
import '../../services/fuego_daemon_client.dart';

enum OrderType { market, limit }

class HearthState {
  final bool isLoading;
  final PoolInfo? pool;
  final AmmQuote? quote;
  final OrderBook? orderBook;
  final OrderType orderType;
  final String? error;

  const HearthState({
    this.isLoading = false,
    this.pool,
    this.quote,
    this.orderBook,
    this.orderType = OrderType.market,
    this.error,
  });

  HearthState copyWith({
    bool? isLoading,
    PoolInfo? pool,
    AmmQuote? quote,
    OrderBook? orderBook,
    OrderType? orderType,
    String? error,
  }) =>
      HearthState(
        isLoading: isLoading ?? this.isLoading,
        pool: pool ?? this.pool,
        quote: quote,
        orderBook: orderBook ?? this.orderBook,
        orderType: orderType ?? this.orderType,
        error: error,
      );
}

class HearthCubit extends Cubit<HearthState> {
  final FuegoDaemonClient _daemon;

  HearthCubit(this._daemon) : super(const HearthState());

  Future<void> loadPool() async {
    emit(state.copyWith(isLoading: true));
    try {
      final pool = await _daemon.getPoolInfo();
      final orderBook = OrderBook.fromPool(pool);
      emit(state.copyWith(isLoading: false, pool: pool, orderBook: orderBook));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void setOrderType(OrderType type) {
    emit(state.copyWith(orderType: type, quote: null));
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
  }) {
    return _daemon.swap(sellXfg: sellXfg, inputAmount: inputAmount, minOutput: minOutput);
  }

  Future<Map<String, dynamic>> placeLimitOrder({
    required bool sellXfg,
    required String amount,
    required String price,
  }) {
    return _daemon.placeLimitOrder(sellXfg: sellXfg, amount: amount, price: price);
  }

  Future<Map<String, dynamic>> addLiquidity({
    required String xfgAmount,
    required String heatAmount,
  }) {
    return _daemon.addLiquidity(xfgAmount: xfgAmount, heatAmount: heatAmount);
  }

  Future<Map<String, dynamic>> removeLiquidity({
    required String shares,
    required String minXfg,
    required String minHeat,
  }) {
    return _daemon.removeLiquidity(shares: shares, minXfg: minXfg, minHeat: minHeat);
  }
}
