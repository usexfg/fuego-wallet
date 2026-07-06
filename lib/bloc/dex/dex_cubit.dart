import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

enum SwapPairVal {
  sol(0, 'SOL'),
  eth(1, 'ETH'),
  xmr(2, 'XMR'),
  bch(3, 'BCH'),
  arb(4, 'ARB'),
  base(5, 'BASE');

  final int id;
  final String ticker;
  const SwapPairVal(this.id, this.ticker);

  static SwapPairVal fromId(int id) =>
      SwapPairVal.values.firstWhere((p) => p.id == id, orElse: () => sol);
}

class SwapOffer {
  final String offerId;
  final int xfgAmount;
  final int rateNum;
  final SwapPairVal pair;
  final String makerPubKey;
  final int timestamp;
  final int ttlBlocks;
  final int postedHeight;
  final bool isSoftOrder;

  const SwapOffer({
    required this.offerId,
    required this.xfgAmount,
    required this.rateNum,
    required this.pair,
    required this.makerPubKey,
    required this.timestamp,
    required this.ttlBlocks,
    required this.postedHeight,
    this.isSoftOrder = false,
  });

  factory SwapOffer.fromJson(Map<String, dynamic> j) => SwapOffer(
        offerId: j['offerId'] ?? '',
        xfgAmount: _toInt(j['xfgAmount']),
        rateNum: _toInt(j['rateNum']),
        pair: SwapPairVal.fromId(j['pair'] ?? 0),
        makerPubKey: j['makerPubKey'] ?? '',
        timestamp: _toInt(j['timestamp']),
        ttlBlocks: j['ttlBlocks'] ?? 0,
        postedHeight: j['postedHeight'] ?? 0,
        isSoftOrder: j['isSoftOrder'] ?? false,
      );

  double get rate => rateNum > 0 ? xfgAmount / rateNum : 0;
  String get pairLabel => 'XFG/${pair.ticker}';
}

class TradeRecord {
  final SwapPairVal pair;
  final int xfgAmount;
  final int ctrAmount;
  final String rate;
  final int blockHeight;
  final int timestamp;

  const TradeRecord({
    required this.pair,
    required this.xfgAmount,
    required this.ctrAmount,
    required this.rate,
    required this.blockHeight,
    required this.timestamp,
  });

  factory TradeRecord.fromJson(Map<String, dynamic> j) => TradeRecord(
        pair: SwapPairVal.fromId(j['pair'] ?? 0),
        xfgAmount: _toInt(j['xfgAmount']),
        ctrAmount: _toInt(j['ctrAmount']),
        rate: j['rate']?.toString() ?? '0',
        blockHeight: j['blockHeight'] ?? 0,
        timestamp: _toInt(j['timestamp']),
      );
}

class SwapPrice {
  final String twap;
  final String compositeRate;
  final String xfgUsdMid;
  final String hearthRatio;
  final String heatUsd;

  const SwapPrice({
    required this.twap,
    required this.compositeRate,
    required this.xfgUsdMid,
    required this.hearthRatio,
    required this.heatUsd,
  });

  factory SwapPrice.fromJson(Map<String, dynamic> j) => SwapPrice(
        twap: j['twap']?.toString() ?? '0',
        compositeRate: j['compositeRate']?.toString() ?? '0',
        xfgUsdMid: j['xfgUsdMid']?.toString() ?? '0',
        hearthRatio: j['hearthRatio']?.toString() ?? '0',
        heatUsd: j['heatUsd']?.toString() ?? '0',
      );
}

class DexState {
  final bool isLoading;
  final String? error;
  final SwapPairVal selectedPair;
  final List<SwapOffer> offers;
  final List<TradeRecord> recentTrades;
  final SwapPrice? price;
  final String? lastResult;
  final bool isConnected;

  const DexState({
    this.isLoading = false,
    this.error,
    this.selectedPair = SwapPairVal.eth,
    this.offers = const [],
    this.recentTrades = const [],
    this.price,
    this.lastResult,
    this.isConnected = false,
  });

  DexState copyWith({
    bool? isLoading,
    String? error,
    SwapPairVal? selectedPair,
    List<SwapOffer>? offers,
    List<TradeRecord>? recentTrades,
    SwapPrice? price,
    String? lastResult,
    bool? isConnected,
  }) =>
      DexState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        selectedPair: selectedPair ?? this.selectedPair,
        offers: offers ?? this.offers,
        recentTrades: recentTrades ?? this.recentTrades,
        price: price ?? this.price,
        lastResult: lastResult,
        isConnected: isConnected ?? this.isConnected,
      );
}

class DexCubit extends Cubit<DexState> {
  final http.Client _http;
  String _baseUrl = '';

  DexCubit() : _http = http.Client(), super(const DexState());

  void configure(String host, {int port = 18180}) {
    _baseUrl = 'http://$host:$port';
  }

  Future<void> init({String host = '207.244.247.64', int port = 18180}) async {
    configure(host, port: port);
    await _checkConnection();
  }

  Future<void> _checkConnection() async {
    if (_baseUrl.isEmpty) return;
    try {
      final resp = await _http
          .get(Uri.parse('$_baseUrl/getinfo'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        emit(state.copyWith(isConnected: true, error: null));
        await loadOffers();
        await loadPrice();
      }
    } catch (e) {
      emit(state.copyWith(error: 'Cannot connect to fuegod: $e'));
    }
  }

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? query}) async {
    final uri = _rest(path, query: query);
    final resp =
        await _http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final resp = await _http
        .post(_rest(path),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Uri _rest(String path, {Map<String, String>? query}) =>
      Uri(scheme: 'http', host: Uri.parse(_baseUrl).host, port: Uri.parse(_baseUrl).port, path: path, queryParameters: query);

  Future<void> loadOffers() async {
    if (_baseUrl.isEmpty) return;
    try {
      final r = await _get('/getswapoffers', query: {
        'pair': state.selectedPair.id.toString()
      });
      final offersList = (r['offers'] as List<dynamic>? ?? [])
          .map((o) => SwapOffer.fromJson(o as Map<String, dynamic>))
          .toList();
      emit(state.copyWith(offers: offersList, error: null));
    } catch (e) {
      debugPrint('DexCubit: loadOffers failed: $e');
    }
  }

  Future<void> loadPrice() async {
    if (_baseUrl.isEmpty) return;
    try {
      final r = await _get('/getswapprice', query: {
        'pair': state.selectedPair.id.toString()
      });
      emit(state.copyWith(price: SwapPrice.fromJson(r)));
    } catch (e) {
      debugPrint('DexCubit: loadPrice failed: $e');
    }
  }

  Future<void> loadTrades() async {
    if (_baseUrl.isEmpty) return;
    try {
      final r = await _get('/getswaptrades', query: {
        'pair': state.selectedPair.id.toString(),
        'limit': '50',
      });
      final trades = (r['trades'] as List<dynamic>? ?? [])
          .map((t) => TradeRecord.fromJson(t as Map<String, dynamic>))
          .toList();
      emit(state.copyWith(recentTrades: trades));
    } catch (e) {
      debugPrint('DexCubit: loadTrades failed: $e');
    }
  }

  void selectPair(SwapPairVal pair) {
    emit(state.copyWith(
        selectedPair: pair,
        offers: [],
        recentTrades: [],
        isLoading: true));
    loadOffers();
    loadPrice();
    loadTrades();
  }

  Future<void> submitOffer({
    required int xfgAmount,
    required int rateNum,
    required String makerPubKey,
    required String signature,
    int ttlBlocks = 1440,
  }) async {
    emit(state.copyWith(isLoading: true, lastResult: null, error: null));
    try {
      final r = await _post('/submitswap', {
        'offerId': DateTime.now().millisecondsSinceEpoch.toRadixString(16),
        'xfgAmount': xfgAmount,
        'rateNum': rateNum,
        'pair': state.selectedPair.id,
        'makerPubKey': makerPubKey,
        'signature': signature,
        'ttlBlocks': ttlBlocks,
      });
      final status = r['status'] ?? 'error';
      emit(state.copyWith(
          isLoading: false, lastResult: 'Offer submitted: $status'));
      await loadOffers();
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Submit failed: $e'));
    }
  }

  Future<void> cancelOffer({
    required String offerId,
    required String makerPubKey,
    required String signature,
  }) async {
    emit(state.copyWith(isLoading: true, lastResult: null, error: null));
    try {
      final r = await _post('/cancelswap', {
        'offerId': offerId,
        'makerPubKey': makerPubKey,
        'signature': signature,
      });
      final status = r['status'] ?? 'error';
      emit(state.copyWith(
          isLoading: false, lastResult: 'Offer cancelled: $status'));
      await loadOffers();
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Cancel failed: $e'));
    }
  }

  Future<void> requestSwap({
    required String offerId,
    required int amount,
    required String takerPubKey,
    required String proofOfFunds,
  }) async {
    emit(state.copyWith(isLoading: true, lastResult: null, error: null));
    try {
      final r = await _post('/requestswap', {
        'offerId': offerId,
        'amount': amount,
        'takerPubKey': takerPubKey,
        'proofOfFunds': proofOfFunds,
      });
      final status = r['status'] ?? 'error';
      emit(state.copyWith(
          isLoading: false, lastResult: 'Swap requested: $status'));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Swap failed: $e'));
    }
  }

  Future<void> refresh() async {
    await loadOffers();
    await loadPrice();
    await loadTrades();
  }

  @override
  Future<void> close() {
    _http.close();
    return super.close();
  }
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
