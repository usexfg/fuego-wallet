import 'dart:convert';
import 'package:http/http.dart' as http;

class SwapDaemonClient {
  final String host;
  final int port;
  http.Client? _httpClient;

  SwapDaemonClient({this.host = '127.0.0.1', this.port = 18902});

  String get _baseUrl => 'http://$host:$port';
  http.Client get _client => _httpClient ??= http.Client();

  void dispose() { _httpClient?.close(); _httpClient = null; }

  Future<bool> isAvailable() async {
    try {
      final resp = await _client.get(Uri.parse('$_baseUrl/health')).timeout(const Duration(seconds: 3));
      return resp.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<dynamic> _rpc(String method, [Map<String, dynamic>? params]) async {
    final body = json.encode({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params ?? {}});
    final resp = await _client.post(Uri.parse('$_baseUrl/'), headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) throw SwapRpcException('HTTP ${resp.statusCode}', -1);
    final decoded = json.decode(resp.body) as Map<String, dynamic>;
    if (decoded.containsKey('error')) {
      final err = decoded['error'] as Map<String, dynamic>;
      throw SwapRpcException(err['message'] as String? ?? 'Unknown error', (err['code'] as num?)?.toInt() ?? -1);
    }
    return decoded['result'];
  }

  Future<String> initiateSwap({required String pair, required int xfgAmount, required int ctrAmount, required String peer, String role = 'alice', String? expectedPeerPubkey, String? swapId, String? ourSwapSecretKey, bool afk = false, String? adaptorPoint, String? hashLock, String? preSig, String? ctrAddress}) async {
    final params = <String, dynamic>{'pair': pair, 'xfg_amount': xfgAmount, 'ctr_amount': ctrAmount, 'peer': peer, 'role': role};
    if (expectedPeerPubkey != null && expectedPeerPubkey.isNotEmpty) params['expected_peer_pubkey'] = expectedPeerPubkey;
    if (swapId != null && swapId.isNotEmpty) params['swap_id'] = swapId;
    if (ourSwapSecretKey != null && ourSwapSecretKey.isNotEmpty) params['our_swap_secret_key'] = ourSwapSecretKey;
    if (afk) params['afk'] = true;
    if (adaptorPoint != null && adaptorPoint.isNotEmpty) params['adaptor_point'] = adaptorPoint;
    if (hashLock != null && hashLock.isNotEmpty) params['hash_lock'] = hashLock;
    if (preSig != null && preSig.isNotEmpty) params['pre_sig'] = preSig;
    if (ctrAddress != null && ctrAddress.isNotEmpty) params['ctr_address'] = ctrAddress;
    final result = await _rpc('initiate_swap', params) as Map<String, dynamic>;
    return result['swap_id'] as String;
  }

  Future<Map<String, dynamic>> acceptSwap(String swapId) async {
    final result = await _rpc('accept', {'swap_id': swapId}) as Map<String, dynamic>;
    return result;
  }

  /// XMR reserve proof via the daemon → the configured monero-wallet-rpc.
  Future<String> getReserveProof({required String address, required String message}) async {
    final result = await _rpc('get_reserve_proof', {'address': address, 'message': message}) as Map<String, dynamic>;
    return result['signature'] as String;
  }

  Future<List<SwapInfo>> listSwaps() async {
    final result = await _rpc('list_swaps') as Map<String, dynamic>;
    return (result['swaps'] as List<dynamic>).map((s) => SwapInfo.fromJson(s as Map<String, dynamic>)).toList();
  }

  Future<SwapInfo> swapStatus(String swapId) async {
    final result = await _rpc('swap_status', {'swap_id': swapId}) as Map<String, dynamic>;
    return SwapInfo.fromJson(result['swap'] as Map<String, dynamic>);
  }

  Future<bool> refund(String swapId) async {
    final result = await _rpc('refund', {'swap_id': swapId}) as Map<String, dynamic>;
    return result['success'] == true;
  }

  Future<TimeoutResult> checkTimeouts() async {
    final result = await _rpc('check_timeouts') as Map<String, dynamic>;
    return TimeoutResult.fromJson(result);
  }
}

class SwapInfo {
  final String swapId;
  final String state;
  final int pair;
  final int xfgAmount;
  final int ctrAmount;
  final String peerEndpoint;
  final int createdAt;
  final int updatedAt;
  final int? timeoutHeight;

  SwapInfo({required this.swapId, required this.state, required this.pair, required this.xfgAmount, required this.ctrAmount, required this.peerEndpoint, required this.createdAt, required this.updatedAt, this.timeoutHeight});

  factory SwapInfo.fromJson(Map<String, dynamic> j) {
    final params = j['params'] as Map<String, dynamic>? ?? j;
    // The daemon sends the numeric state id in "state" plus a human-readable
    // "stateName". Prefer stateName; fall back to numeric id → name mapping.
    String? stateName = j['stateName'] as String?;
    if (stateName == null || stateName.isEmpty) {
      final rawState = j['state'];
      if (rawState is num) {
        stateName = _stateNames[rawState.toInt()] ?? 'UNKNOWN';
      } else if (rawState is String) {
        stateName = rawState;
      } else {
        stateName = 'UNKNOWN';
      }
    }
    return SwapInfo(
      swapId: params['swapId'] as String? ?? j['swapId'] as String? ?? '',
      state: stateName,
      pair: (params['pair'] as num?)?.toInt() ?? 0,
      xfgAmount: (params['xfgAmount'] as num?)?.toInt() ?? 0,
      ctrAmount: (params['ctrAmount'] as num?)?.toInt() ?? 0,
      peerEndpoint: params['peerEndpoint'] as String? ?? '',
      createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      timeoutHeight: (params['xfgTimeoutHeight'] as num?)?.toInt(),
    );
  }

  String get pairName {
    const names = {0: 'SOL', 1: 'ETH', 2: 'XMR', 3: 'BCH', 4: 'ARB', 5: 'BASE', 6: 'KMD', 7: 'BNB', 8: 'DCR', 9: 'BTC', 10: 'LTC', 11: 'POLYGON'};
    return names[pair] ?? 'PAIR_$pair';
  }

  // Numeric SwapState ids (XfgSwap::SwapState) → names. Kept in sync with the
  // C++ SwapTypes.h enum; terminal names match the daemon's isTerminal set.
  static const Map<int, String> _stateNames = {
    0: 'INITIATED', 1: 'XFG_LOCKED', 2: 'CTR_LOCKED', 3: 'XFG_CLAIMED',
    4: 'CTR_CLAIMED', 5: 'XFG_REFUNDED', 6: 'CTR_REFUNDED', 7: 'FAILED',
    10: 'ADAPTOR_KEYS_EXCHANGED', 11: 'ADAPTOR_ESCROW_FUNDED',
    12: 'ADAPTOR_PRESIGS_READY', 13: 'ADAPTOR_CTR_LOCKED',
    14: 'ADAPTOR_SECRET_REVEALED', 15: 'ADAPTOR_XFG_SPENT',
    16: 'ADAPTOR_REFUNDED', 17: 'ADAPTOR_WAITING_SPV',
    18: 'ADAPTOR_SECRET_CONFIRMED_SPV',
    100: 'AFK_OFFER_LOCKED', 101: 'AFK_OFFER_ACCEPTED',
    102: 'AFK_CLAIMED', 103: 'AFK_REFUNDED',
  };

  bool get isTerminal {
    const terminal = {'ADAPTOR_XFG_SPENT', 'ADAPTOR_REFUNDED', 'AFK_CLAIMED', 'AFK_REFUNDED', 'FAILED', 'XFG_REFUNDED', 'XFG_CLAIMED', 'CTR_CLAIMED', 'CTR_REFUNDED'};
    return terminal.contains(state);
  }

  double get xfgAmountDecimal => xfgAmount / 10000000;
  double get ctrAmountDecimal => ctrAmount / 10000000;
}

class TimeoutResult {
  final int processed;
  final List<String> refunded;
  TimeoutResult({required this.processed, required this.refunded});
  factory TimeoutResult.fromJson(Map<String, dynamic> j) => TimeoutResult(
    processed: (j['processed'] as num?)?.toInt() ?? 0,
    refunded: (j['refunded'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
  );
}

class SwapRpcException implements Exception {
  final String message;
  final int code;
  SwapRpcException(this.message, this.code);
  @override
  String toString() => 'SwapRpcException($code): $message';
}
