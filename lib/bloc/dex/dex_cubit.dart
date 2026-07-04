import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  final bool isConnected;

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
    this.isConnected = false,
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
    bool? isConnected,
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
        isConnected: isConnected ?? this.isConnected,
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
  final http.Client _http;
  String _rpcUrl = '';
  String _rpcPassword = '';

  DexCubit() : _http = http.Client(), super(const DexState());

  Future<void> init() async {
    await _loadConfig();
    await _checkConnection();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('kdf_host') ?? '';
    final port = prefs.getInt('kdf_port') ?? 7783;
    final password = prefs.getString('kdf_rpc_password') ?? '';
    final https = prefs.getBool('kdf_https') ?? false;

    if (host.isEmpty) {
      emit(state.copyWith(error: 'Configure KDF in Settings > DEX Server'));
      return;
    }

    final scheme = https ? 'https' : 'http';
    _rpcUrl = '$scheme://$host:$port';
    _rpcPassword = password;
  }

  Future<void> _checkConnection() async {
    if (_rpcUrl.isEmpty) return;
    try {
      final response = await _rpc('version', {});
      if (response.containsKey('result')) {
        emit(state.copyWith(isConnected: true, error: null));
        await _loadCoins();
      } else {
        emit(state.copyWith(error: 'KDF responded with error: ${response['error']}'));
      }
    } catch (e) {
      emit(state.copyWith(error: 'Cannot connect to KDF at $_rpcUrl: $e'));
    }
  }

  Future<Map<String, dynamic>> _rpc(String method, Map<String, dynamic> params) async {
    final body = jsonEncode({
      'userpass': _rpcPassword,
      'method': method,
      ...params,
    });
    final response = await _http.post(
      Uri.parse(_rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> _loadCoins() async {
    try {
      final response = await _rpc('get_coins', {});
      final List<dynamic> resultList;
      if (response['result'] is List) {
        resultList = response['result'] as List<dynamic>;
      } else if (response['result'] is Map) {
        final result = response['result'] as Map<String, dynamic>;
        resultList = result['coins'] as List<dynamic>? ?? [];
      } else {
        resultList = [];
      }
      final coins = resultList
          .map((c) => c['ticker'] as String? ?? c['coin'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .toList()
        ..sort();
      if (coins.isEmpty) {
        emit(state.copyWith(error: 'No coins returned from KDF — check daemon connection'));
      } else {
        emit(state.copyWith(availableCoins: coins, error: null));
      }
    } catch (e) {
      debugPrint('DexCubit: _loadCoins error: $e');
      emit(state.copyWith(error: 'Failed to load coins: $e'));
    }
  }

  Future<void> selectPair(String base, String rel) async {
    emit(state.copyWith(baseCoin: base, relCoin: rel, isLoading: true, error: null));

    if (_rpcUrl.isEmpty) {
      emit(state.copyWith(isLoading: false, error: 'KDF not configured'));
      return;
    }

    try {
      final response = await _rpc('orderbook', {'base': base, 'rel': rel});
      final result = response['result'] as Map<String, dynamic>? ?? response;
      final bidsRaw = (result['bids'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final asksRaw = (result['asks'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      _computeOrderbookState(bidsRaw, asksRaw);
    } catch (e) {
      debugPrint('DexCubit: orderbook failed: $e');
      emit(state.copyWith(isLoading: false, error: 'Orderbook failed: $e'));
    }

    await loadOpenOrders();
  }

  Future<void> placeMakerOrder({
    required String price,
    required String volume,
  }) async {
    if (state.baseCoin == null || state.relCoin == null) return;
    emit(state.copyWith(isSubmitting: true, lastOrderResult: null, error: null));

    try {
      final response = await _rpc('setprice', {
        'base': state.baseCoin,
        'rel': state.relCoin,
        'price': price,
        'volume': volume,
      });
      final uuid = response['result']?['uuid'] ?? response['result']?['order']?['uuid'] ?? 'unknown';
      emit(state.copyWith(
        isSubmitting: false,
        lastOrderResult: 'Order placed: $uuid',
      ));
      await loadOpenOrders();
      await selectPair(state.baseCoin!, state.relCoin!);
    } catch (e) {
      debugPrint('DexCubit: placeMakerOrder failed: $e');
      emit(state.copyWith(isSubmitting: false, error: 'Order failed: $e'));
    }
  }

  Future<void> takerBuy({
    required String volume,
    required String price,
  }) async {
    if (state.baseCoin == null || state.relCoin == null) return;
    emit(state.copyWith(isSubmitting: true, lastOrderResult: null, error: null));

    try {
      final response = await _rpc('buy', {
        'base': state.baseCoin,
        'rel': state.relCoin,
        'volume': volume,
        'price': price,
      });
      final uuid = response['result']?['uuid'] ?? 'unknown';
      emit(state.copyWith(
        isSubmitting: false,
        lastOrderResult: 'Buy order: $uuid',
      ));
    } catch (e) {
      debugPrint('DexCubit: takerBuy failed: $e');
      emit(state.copyWith(isSubmitting: false, error: 'Buy failed: $e'));
    }
  }

  Future<void> takerSell({
    required String volume,
    required String price,
  }) async {
    if (state.baseCoin == null || state.relCoin == null) return;
    emit(state.copyWith(isSubmitting: true, lastOrderResult: null, error: null));

    try {
      final response = await _rpc('sell', {
        'base': state.baseCoin,
        'rel': state.relCoin,
        'volume': volume,
        'price': price,
      });
      final uuid = response['result']?['uuid'] ?? 'unknown';
      emit(state.copyWith(
        isSubmitting: false,
        lastOrderResult: 'Sell order: $uuid',
      ));
    } catch (e) {
      debugPrint('DexCubit: takerSell failed: $e');
      emit(state.copyWith(isSubmitting: false, error: 'Sell failed: $e'));
    }
  }

  Future<void> loadOpenOrders() async {
    if (_rpcUrl.isEmpty) return;
    try {
      final response = await _rpc('my_orders', {});
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
    if (_rpcUrl.isEmpty) return;
    try {
      await _rpc('cancel_order', {'uuid': uuid});
      await loadOpenOrders();
    } catch (e) {
      debugPrint('DexCubit: cancelOrder failed: $e');
    }
  }

  Future<void> cancelAllOrders() async {
    if (_rpcUrl.isEmpty) return;
    try {
      await _rpc('cancel_all_orders', {'cancel_by': {'type': 'All'}});
      await loadOpenOrders();
    } catch (e) {
      debugPrint('DexCubit: cancelAllOrders failed: $e');
    }
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

  Future<void> refresh() async {
    await _loadConfig();
    await _checkConnection();
  }

  @override
  Future<void> close() {
    _http.close();
    return super.close();
  }
}
