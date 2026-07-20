import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'network_info.dart';
import 'transaction.dart';

class FuegoDaemonClient {
  final String host;
  final int port;
  final int walletPort;
  final http.Client _http;

  FuegoDaemonClient({
    this.host = '127.0.0.1',
    this.port = defaultRpcPort,
    this.walletPort = 8070,
    http.Client? client,
  }) : _http = client ?? http.Client();

  Uri _rest(String path, {bool useWallet = false}) => Uri(
        scheme: 'http',
        host: useWallet ? '127.0.0.1' : host,
        port: useWallet ? walletPort : port,
        path: path,
      );

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? query, bool useWallet = false}) async {
    final uri = _rest(path, useWallet: useWallet)
        .replace(queryParameters: query);
    print('[daemon] GET $uri');
    final resp = await _http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      print('[daemon] GET $uri → HTTP ${resp.statusCode}: ${resp.body}');
      throw FuegoRpcException('HTTP ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body,
      {bool useWallet = false}) async {
    final uri = _rest(path, useWallet: useWallet);
    print('[daemon] POST $uri');
    final resp = await _http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      print('[daemon] POST $uri → HTTP ${resp.statusCode}: ${resp.body}');
      throw FuegoRpcException('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data.containsKey('error') && data['error'] != null) {
      print('[daemon] POST $uri → RPC error: ${data['error']}');
      throw FuegoRpcException(data['error'].toString());
    }
    return data;
  }

  // ── Network info (remote daemon, no walletd needed) ──

  Future<NetworkInfo> getInfo() async {
    final r = await _post('/json_rpc', {
      'jsonrpc': '2.0',
      'id': 'fuego_core',
      'method': 'getinfo',
      'params': {},
    }, useWallet: true);
    final result = r['result'] as Map<String, dynamic>? ?? r;
    return NetworkInfo.fromJson(result);
  }

  Future<int> getPeerCount() async {
    final r = await _post('/json_rpc', {
      'jsonrpc': '2.0',
      'id': 'fuego_core',
      'method': 'getinfo',
      'params': {},
    }, useWallet: true);
    final result = r['result'] as Map<String, dynamic>? ?? r;
    final outgoing = result['outgoing_connections_count'] as int? ?? 0;
    final incoming = result['incoming_connections_count'] as int? ?? 0;
    return outgoing + incoming;
  }

  // ── Wallet operations (walletd, the real source of truth) ──

  Future<String> getWalletAddress() async {
    final r = await _post('/json_rpc', {
      'jsonrpc': '2.0',
      'id': 'fuego_core',
      'method': 'getAddress',
      'params': {},
    }, useWallet: true);
    final result = r['result'] as Map<String, dynamic>? ?? r;
    return (result['address'] as String?) ?? '';
  }

  Future<String> getAddress() async {
    final r = await _post('/json_rpc', {
      'jsonrpc': '2.0',
      'id': 'fuego_core',
      'method': 'getAddresses',
      'params': {},
    }, useWallet: true);
    final result = r['result'] as Map<String, dynamic>? ?? r;
    final addresses = result['addresses'] as List<dynamic>? ?? [];
    return addresses.isNotEmpty ? addresses.first as String : '';
  }

  /// CryptoNote subaddress creation via walletd `create_address`.
  Future<String> createSubaddress(String label) async {
    final r = await _post('/json_rpc', {
      'jsonrpc': '2.0',
      'id': 'fuego_core',
      'method': 'create_address',
      'params': {
        if (label.isNotEmpty) 'label': label,
      },
    }, useWallet: true);
    final result = r['result'] as Map<String, dynamic>? ?? r;
    return (result['address'] as String?) ?? '';
  }

  /// List subaddresses (indices ≥ 1) via walletd `getAddresses`.
  Future<List<Map<String, dynamic>>> getSubaddresses() async {
    final r = await _post('/json_rpc', {
      'jsonrpc': '2.0',
      'id': 'fuego_core',
      'method': 'getAddresses',
      'params': {},
    }, useWallet: true);
    final result = r['result'] as Map<String, dynamic>? ?? r;
    final addresses = result['addresses'] as List<dynamic>? ?? [];
    return addresses.map((a) => a as Map<String, dynamic>).toList();
  }

  Future<int> getBalance() async {
    final r = await _post('/json_rpc', {
      'jsonrpc': '2.0',
      'id': 'fuego_core',
      'method': 'getBalance',
      'params': {},
    }, useWallet: true);
    final result = r['result'] as Map<String, dynamic>? ?? r;
    return (result['availableBalance'] ?? result['balance'] ?? 0) as int;
  }

  Future<String> sendTransaction(SendTransactionRequest req) async {
    final r = await _post('/json_rpc', {
      'jsonrpc': '2.0',
      'id': 'fuego_core',
      'method': 'sendTransaction',
      'params': {
        'destinations': [
          {'amount': (req.amount * 1e7).toInt(), 'address': req.address}
        ],
        'fee': (req.fee * 1e7).toInt(),
        'anonymity': req.mixin,
        if (req.paymentId != null) 'paymentId': req.paymentId,
      },
    }, useWallet: true);
    final result = r['result'] as Map<String, dynamic>? ?? r;
    return result['transactionHash'] as String? ?? '';
  }

  Future<List<FuegoTransaction>> getTransactions({int count = 20}) async {
    final r = await _post('/json_rpc', {
      'jsonrpc': '2.0',
      'id': 'fuego_core',
      'method': 'getTransactions',
      'params': {
        'blockCount': count,
        'firstBlockIndex': 0,
      },
    }, useWallet: true);
    final result = r['result'] as Map<String, dynamic>? ?? r;
    final items = result['items'] as List<dynamic>? ?? [];
    final txs = <FuegoTransaction>[];
    for (final item in items) {
      final txList = item['transactions'] as List<dynamic>? ?? [];
      for (final t in txList) {
        txs.add(FuegoTransaction.fromJson({
          ...(t as Map<String, dynamic>),
          'direction': (t['amount'] ?? 0) < 0 ? 'out' : 'in',
        }));
      }
    }
    txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return txs.take(count).toList();
  }

  // ── Mining (walletd) ──

  Future<void> startMining({int threads = 1, String? address}) async {
    try {
      await _post('/json_rpc', {
        'jsonrpc': '2.0',
        'id': 'fuego_core',
        'method': 'start_mining',
        'params': {
          'threads_count': threads,
          if (address != null) 'miner_address': address,
        },
      }, useWallet: true);
    } catch (_) {}
  }

  Future<void> stopMining() async {
    try {
      await _post('/json_rpc', {
        'jsonrpc': '2.0',
        'id': 'fuego_core',
        'method': 'stop_mining',
        'params': {},
      }, useWallet: true);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getMiningStatus() async {
    try {
      final r = await _post('/json_rpc', {
        'jsonrpc': '2.0',
        'id': 'fuego_core',
        'method': 'getinfo',
        'params': {},
      }, useWallet: true);
      final result = r['result'] as Map<String, dynamic>? ?? r;
      return {
        'active': (result['mining_speed'] ?? 0) > 0,
        'speed': result['mining_speed'] ?? 0,
        'hashrate': result['mining_speed'] ?? 0,
        'threads': result['threads_count'] ?? 0,
      };
    } catch (_) {
      return {};
    }
  }

  // ── Status (Axum health) ──

  Future<Map<String, dynamic>> getStatus() async {
    return await _get('/status');
  }

  // ── Output scanning (bypasses walletd) ──

  /// Scan blockchain for outputs belonging to our keys.
  /// Returns {balance, outputs, scanned_height, current_height, scanned_tx_count}
  Future<Map<String, dynamic>> scanBalance({
    required String viewSecret,
    required String spendPublic,
    int startHeight = 0,
    int batchSize = 100,
  }) async {
    final uri = _rest('/scan_balance');
    print('[daemon] POST $uri (scan_balance)');
    final resp = await _http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'view_secret': viewSecret,
            'spend_public': spendPublic,
            'start_height': startHeight,
            'batch_size': batchSize,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200) {
      throw FuegoRpcException('scan_balance HTTP ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  void dispose() => _http.close();
}

class FuegoRpcException implements Exception {
  final String message;
  const FuegoRpcException(this.message);
  @override
  String toString() => 'FuegoRpcException: $message';
}
