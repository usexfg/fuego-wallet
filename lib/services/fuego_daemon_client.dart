import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/network_config.dart';
import '../models/heat_amm.dart';

class FuegoDaemonClient {
  final Dio _dio;
  String _baseUrl;
  NetworkConfig _networkConfig;

  FuegoDaemonClient({
    String host = 'localhost',
    NetworkConfig? networkConfig,
  })  : _networkConfig = networkConfig ?? NetworkConfig.mainnet,
        _baseUrl = 'http://$host:${networkConfig?.daemonRpcPort ?? NetworkConfig.mainnet.daemonRpcPort}',
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ));

  NetworkConfig get networkConfig => _networkConfig;

  void updateNode(String host, {int? port}) {
    _baseUrl = 'http://$host:${port ?? _networkConfig.daemonRpcPort}';
  }

  // ── HEAT Stablecoin ──

  /// Get HEAT metrics: supply, redemption price, treasury, CD yield
  Future<HeatMetrics> getHeatMetrics() async {
    final result = await _daemonGet('/heat_metrics');
    return HeatMetrics.fromJson(result);
  }

  /// Mint HEAT by burning XFG. Amount in atomic units.
  Future<Map<String, dynamic>> mintHeat(int xfgAmount) async {
    return _jsonRpc('mint_heat', {'amount': xfgAmount});
  }

  // ── Hearth AMM ──

  /// Get a swap quote from the Hearth AMM
  Future<AmmQuote> getAmmQuote({
    required bool sellXfg,
    required String amount,
  }) async {
    final result = await _daemonGet('/amm_quote', queryParameters: {
      'sell_xfg': sellXfg.toString(),
      'amount': amount,
    });
    return AmmQuote.fromJson(result);
  }

  /// Get pool information: reserves, spot price, LP fees
  Future<PoolInfo> getPoolInfo() async {
    final result = await _daemonGet('/amm_pool_info');
    return PoolInfo.fromJson(result);
  }

  /// Execute a swap on the Hearth AMM
  Future<Map<String, dynamic>> swap({
    required bool sellXfg,
    required String inputAmount,
    required String minOutput,
  }) async {
    return _jsonRpc('swap', {
      'direction': sellXfg ? 'xfg_to_heat' : 'heat_to_xfg',
      'input_amount': inputAmount,
      'min_output': minOutput,
    });
  }

  /// Add liquidity to the Hearth AMM pool
  Future<Map<String, dynamic>> addLiquidity({
    required String xfgAmount,
    required String heatAmount,
  }) async {
    return _jsonRpc('add_liq', {
      'xfg_amount': xfgAmount,
      'heat_amount': heatAmount,
    });
  }

  /// Remove liquidity from the Hearth AMM pool
  Future<Map<String, dynamic>> removeLiquidity({
    required String shares,
    required String minXfg,
    required String minHeat,
  }) async {
    return _jsonRpc('remove_liq', {
      'shares': shares,
      'min_xfg': minXfg,
      'min_heat': minHeat,
    });
  }

  // ── Mining ──
  // (Mining methods are in FuegoRPCService which already uses daemon RPC)

  // ── Private helpers ──

  Future<Map<String, dynamic>> _jsonRpc(
      String method, Map<String, dynamic> params) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/json_rpc',
        data: json.encode({
          'jsonrpc': '2.0',
          'id': DateTime.now().millisecondsSinceEpoch,
          'method': method,
          'params': params,
        }),
      );
      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('error')) {
        throw DaemonException(data['error']['message'] as String);
      }
      return data['result'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw DaemonException('Daemon request failed: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> _daemonGet(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl$path',
        queryParameters: queryParameters,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw DaemonException('Daemon GET $path failed: ${e.message}');
    }
  }

  Future<bool> testConnection() async {
    try {
      await _daemonGet('/getinfo');
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _dio.close();
}

class DaemonException implements Exception {
  final String message;
  DaemonException(this.message);
  @override
  String toString() => 'DaemonException: $message';
}
