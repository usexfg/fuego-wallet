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
    final resp = await _http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw FuegoRpcException('HTTP ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body,
      {bool useWallet = false}) async {
    final resp = await _http
        .post(
          _rest(path, useWallet: useWallet),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw FuegoRpcException('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data.containsKey('error') && data['error'] != null) {
      throw FuegoRpcException(data['error'].toString());
    }
    return data;
  }

  Future<NetworkInfo> getInfo() async {
    final r = await _get('/getinfo');
    return NetworkInfo.fromJson(r);
  }

  Future<int> getPeerCount() async {
    final r = await _get('/getinfo');
    final outgoing = r['outgoing_connections_count'] as int? ?? 0;
    final incoming = r['incoming_connections_count'] as int? ?? 0;
    return outgoing + incoming;
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

  Future<void> startMining({int threads = 1, String? address}) async {
    try {
      await _post('/start_mining', {
        'threads_count': threads,
        if (address != null) 'miner_address': address,
      });
    } catch (_) {}
  }

  Future<void> stopMining() async {
    try {
      await _post('/stop_mining', {});
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getMiningStatus() async =>
      await _get('/mining_status');

  void dispose() => _http.close();
}

class FuegoRpcException implements Exception {
  final String message;
  const FuegoRpcException(this.message);
  @override
  String toString() => 'FuegoRpcException: $message';
}
