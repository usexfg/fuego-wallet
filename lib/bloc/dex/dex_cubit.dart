import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuego_defi_sdk/fuego_defi_sdk.dart';
import 'package:fuego_defi_framework/fuego_defi_framework.dart';

class DexState {
  final bool isLoading;
  final String? baseCoin;
  final String? relCoin;
  final String? error;
  final List<OrderRow> bids;
  final List<OrderRow> asks;
  final List<String> availableCoins;
  final double? bestBid;
  final double? bestAsk;
  final double? spread;
  final List<OpenOrder> openOrders;
  final String? lastOrderResult;
  final bool isSubmitting;

  const DexState({
    this.isLoading = false,
    this.baseCoin,
    this.relCoin,
    this.error,
    this.bids = const [],
    this.asks = const [],
    this.availableCoins = const [],
    this.bestBid,
    this.bestAsk,
    this.spread,
    this.openOrders = const [],
    this.lastOrderResult,
    this.isSubmitting = false,
  });

  DexState copyWith({
    bool? isLoading,
    String? baseCoin,
    String? relCoin,
    String? error,
    List<OrderRow>? bids,
    List<OrderRow>? asks,
    List<String>? availableCoins,
    double? bestBid,
    double? bestAsk,
    double? spread,
    List<OpenOrder>? openOrders,
    String? lastOrderResult,
    bool? isSubmitting,
  }) =>
      DexState(
        isLoading: isLoading ?? this.isLoading,
        baseCoin: baseCoin ?? this.baseCoin,
        relCoin: relCoin ?? this.relCoin,
        error: error,
        bids: bids ?? this.bids,
        asks: asks ?? this.asks,
        availableCoins: availableCoins ?? this.availableCoins,
        bestBid: bestBid ?? this.bestBid,
        bestAsk: bestAsk ?? this.bestAsk,
        spread: spread ?? this.spread,
        openOrders: openOrders ?? this.openOrders,
        lastOrderResult: lastOrderResult,
        isSubmitting: isSubmitting ?? this.isSubmitting,
      );
}

class OrderRow {
  final String price;
  final String volume;
  final double priceNum;
  final double volNum;
  final double depthPct;
  final bool isMine;

  const OrderRow({
    required this.price,
    required this.volume,
    required this.priceNum,
    required this.volNum,
    this.depthPct = 0,
    this.isMine = false,
  });
}

class OpenOrder {
  final String uuid;
  final String base;
  final String rel;
  final String price;
  final String volume;
  final bool isMine;

  const OpenOrder({
    required this.uuid,
    required this.base,
    required this.rel,
    required this.price,
    required this.volume,
    this.isMine = false,
  });
}

class DexCubit extends Cubit<DexState> {
  final FuegoDefiSdk? _sdk;
  StreamSubscription<OrderbookEvent>? _orderbookSub;

  DexCubit(this._sdk) : super(const DexState());

  void loadAvailableCoins() {
    if (_sdk == null) {
      emit(state.copyWith(error: 'KDF not running — configure KDF in Settings > DEX Server'));
      return;
    }
    try {
      final coins = _sdk!.assets.available.keys
          .map((id) => id.id)
          .where((t) => t.isNotEmpty)
          .toList()
        ..sort();
      emit(state.copyWith(availableCoins: coins));
    } catch (e) {
      debugPrint('DexCubit: loadAvailableCoins error: $e');
    }
  }

  Future<void> selectPair(String base, String rel) async {
    await _orderbookSub?.cancel();
    emit(state.copyWith(baseCoin: base, relCoin: rel, isLoading: true, error: null));

    if (_sdk == null) {
      emit(state.copyWith(isLoading: false, error: 'SDK not initialized'));
      return;
    }

    try {
      final ob = await _sdk!.trading.getOrderbook(base: base, rel: rel);
      final json = ob.toJson();
      _applyOrderbook(json);
    } catch (e) {
      debugPrint('DexCubit: getOrderbook failed: $e');
      emit(state.copyWith(isLoading: false));
    }

    try {
      _orderbookSub?.cancel();
      final sub = await _sdk!.subscribeToOrderbook(base: base, rel: rel);
      _orderbookSub = sub;
      sub.onData((event) {
        _applyEventOrders(event.bids, event.asks);
      });
    } catch (e) {
      debugPrint('DexCubit: subscribe failed: $e (ok, will use polling)');
    }

    await loadOpenOrders();
  }

  Future<void> placeMakerOrder({
    required String price,
    required String volume,
  }) async {
    if (_sdk == null || state.baseCoin == null || state.relCoin == null) return;
    emit(state.copyWith(isSubmitting: true, lastOrderResult: null, error: null));

    try {
      final response = await _sdk!.client.executeRpc({
        'mmrpc': '2.0',
        'method': 'setprice',
        'params': {
          'base': state.baseCoin,
          'rel': state.relCoin,
          'price': price,
          'volume': volume,
        },
      });
      final uuid = response['result']?['uuid'] ?? 'unknown';
      emit(state.copyWith(
        isSubmitting: false,
        lastOrderResult: 'Order placed: $uuid',
      ));
      await loadOpenOrders();
      await selectPair(state.baseCoin!, state.relCoin!);
    } catch (e) {
      debugPrint('DexCubit: placeMakerOrder failed: $e');
      emit(state.copyWith(
        isSubmitting: false,
        error: 'Order failed: $e',
      ));
    }
  }

  Future<void> takerBuy({
    required String volume,
    required String price,
  }) async {
    if (_sdk == null || state.baseCoin == null || state.relCoin == null) return;
    emit(state.copyWith(isSubmitting: true, lastOrderResult: null, error: null));

    try {
      final response = await _sdk!.client.executeRpc({
        'mmrpc': '2.0',
        'method': 'buy',
        'params': {
          'base': state.baseCoin,
          'rel': state.relCoin,
          'volume': volume,
          'price': price,
        },
      });
      final uuid = response['result']?['uuid'] ?? 'unknown';
      emit(state.copyWith(
        isSubmitting: false,
        lastOrderResult: 'Swap started: $uuid',
      ));
    } catch (e) {
      debugPrint('DexCubit: takerBuy failed: $e');
      emit(state.copyWith(
        isSubmitting: false,
        error: 'Buy failed: $e',
      ));
    }
  }

  Future<void> takerSell({
    required String volume,
    required String price,
  }) async {
    if (_sdk == null || state.baseCoin == null || state.relCoin == null) return;
    emit(state.copyWith(isSubmitting: true, lastOrderResult: null, error: null));

    try {
      final response = await _sdk!.client.executeRpc({
        'mmrpc': '2.0',
        'method': 'sell',
        'params': {
          'base': state.baseCoin,
          'rel': state.relCoin,
          'volume': volume,
          'price': price,
        },
      });
      final uuid = response['result']?['uuid'] ?? 'unknown';
      emit(state.copyWith(
        isSubmitting: false,
        lastOrderResult: 'Swap started: $uuid',
      ));
    } catch (e) {
      debugPrint('DexCubit: takerSell failed: $e');
      emit(state.copyWith(
        isSubmitting: false,
        error: 'Sell failed: $e',
      ));
    }
  }

  Future<void> loadOpenOrders() async {
    if (_sdk == null) return;
    try {
      final response = await _sdk!.client.executeRpc({
        'mmrpc': '2.0',
        'method': 'my_orders',
        'params': {},
      });
      final result = response['result'] as Map<String, dynamic>? ?? {};
      final rawOrders = result['orders'] as List<dynamic>? ?? [];
      final orders = rawOrders.map((o) {
        return OpenOrder(
          uuid: o['uuid'] ?? '',
          base: o['base'] ?? '',
          rel: o['rel'] ?? '',
          price: o['price'] ?? '0',
          volume: o['amount'] ?? o['volume'] ?? '0',
          isMine: o['is_mine'] == true,
        );
      }).toList();
      emit(state.copyWith(openOrders: orders));
    } catch (e) {
      debugPrint('DexCubit: loadOpenOrders failed: $e');
    }
  }

  Future<void> cancelOrder(String uuid) async {
    if (_sdk == null) return;
    try {
      await _sdk!.client.executeRpc({
        'mmrpc': '2.0',
        'method': 'cancel_order',
        'params': {'uuid': uuid},
      });
      await loadOpenOrders();
    } catch (e) {
      debugPrint('DexCubit: cancelOrder failed: $e');
    }
  }

  Future<void> cancelAllOrders() async {
    if (_sdk == null) return;
    try {
      await _sdk!.client.executeRpc({
        'mmrpc': '2.0',
        'method': 'cancel_all_orders',
        'params': {'cancel_by': {'type': 'All'}},
      });
      await loadOpenOrders();
    } catch (e) {
      debugPrint('DexCubit: cancelAllOrders failed: $e');
    }
  }

  void _applyEventOrders(List<Map<String, dynamic>> bidsRaw, List<Map<String, dynamic>> asksRaw) {
    _computeOrderbookState(bidsRaw, asksRaw);
  }

  void _applyOrderbook(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>? ?? json;
    final bidsRaw = (result['bids'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final asksRaw = (result['asks'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    _computeOrderbookState(bidsRaw, asksRaw);
  }

  void _computeOrderbookState(List<Map<String, dynamic>> bidsRaw, List<Map<String, dynamic>> asksRaw) {

    final bids = _parseOrders(bidsRaw);
    final asks = _parseOrders(asksRaw);

    final totalBidVol = bids.fold<double>(0, (s, b) => s + b.volNum);
    double bidAccum = 0;
    final bidsWithDepth = bids.map((b) {
      bidAccum += b.volNum;
      return OrderRow(
        price: b.price,
        volume: b.volume,
        priceNum: b.priceNum,
        volNum: b.volNum,
        depthPct: totalBidVol > 0 ? (bidAccum / totalBidVol) : 0,
        isMine: b.isMine,
      );
    }).toList();

    final totalAskVol = asks.fold<double>(0, (s, a) => s + a.volNum);
    double askAccum = 0;
    final asksWithDepth = asks.map((a) {
      askAccum += a.volNum;
      return OrderRow(
        price: a.price,
        volume: a.volume,
        priceNum: a.priceNum,
        volNum: a.volNum,
        depthPct: totalAskVol > 0 ? (askAccum / totalAskVol) : 0,
        isMine: a.isMine,
      );
    }).toList();

    final bestBid = bidsWithDepth.isNotEmpty ? bidsWithDepth.first.priceNum : null;
    final bestAsk = asksWithDepth.isNotEmpty ? asksWithDepth.first.priceNum : null;
    final spread = (bestBid != null && bestAsk != null) ? bestAsk - bestBid : null;

    emit(state.copyWith(
      isLoading: false,
      bids: bidsWithDepth,
      asks: asksWithDepth,
      bestBid: bestBid,
      bestAsk: bestAsk,
      spread: spread,
    ));
  }

  List<OrderRow> _parseOrders(List<Map<String, dynamic>> orders) {
    return orders.map((o) {
      final price = _toDouble(o['price']);
      final vol = _toDouble(o['max_volume'] ?? o['base_max_volume'] ?? o['maxvolume']);
      return OrderRow(
        price: price.toStringAsFixed(7),
        volume: vol.toStringAsFixed(7),
        priceNum: price,
        volNum: vol,
        isMine: o['is_mine'] == true,
      );
    }).toList()
      ..sort((a, b) => b.priceNum.compareTo(a.priceNum));
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    if (v is Map) {
      final d = v['decimal'] ?? v['Decimal'];
      if (d != null) return double.tryParse(d.toString()) ?? 0;
    }
    return 0;
  }

  @override
  Future<void> close() {
    _orderbookSub?.cancel();
    return super.close();
  }
}
