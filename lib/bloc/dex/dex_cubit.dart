import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuego_defi_sdk/fuego_defi_sdk.dart';

class DexState {
  final bool isLoading;
  final String? baseCoin;
  final String? relCoin;
  final String? error;
  final List<Map<String, dynamic>> bids;
  final List<Map<String, dynamic>> asks;

  const DexState({
    this.isLoading = false,
    this.baseCoin,
    this.relCoin,
    this.error,
    this.bids = const [],
    this.asks = const [],
  });

  DexState copyWith({
    bool? isLoading,
    String? baseCoin,
    String? relCoin,
    String? error,
    List<Map<String, dynamic>>? bids,
    List<Map<String, dynamic>>? asks,
  }) =>
      DexState(
        isLoading: isLoading ?? this.isLoading,
        baseCoin: baseCoin ?? this.baseCoin,
        relCoin: relCoin ?? this.relCoin,
        error: error,
        bids: bids ?? this.bids,
        asks: asks ?? this.asks,
      );
}

class DexCubit extends Cubit<DexState> {
  final FuegoDefiSdk _sdk;

  DexCubit(this._sdk) : super(const DexState());

  Future<void> loadOrderbook(String base, String rel) async {
    emit(state.copyWith(isLoading: true, baseCoin: base, relCoin: rel));
    try {
      final result = await _sdk.client.executeRpc({
        'method': 'orderbook',
        'base': base,
        'rel': rel,
      });
      final bids = (result['bids'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final asks = (result['asks'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      emit(state.copyWith(isLoading: false, bids: bids, asks: asks));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> submitBuyOrder(String base, String rel, String price, String volume) async {
    await _sdk.client.executeRpc({
      'method': 'buy',
      'base': base,
      'rel': rel,
      'price': price,
      'volume': volume,
    });
  }

  Future<void> submitSellOrder(String base, String rel, String price, String volume) async {
    await _sdk.client.executeRpc({
      'method': 'sell',
      'base': base,
      'rel': rel,
      'price': price,
      'volume': volume,
    });
  }
}
