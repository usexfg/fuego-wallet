// Copyright (c) 2025 Fuego Developers
// Copyright (c) 2025 Elderfire Privacy Group

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import '../models/wallet.dart';
import '../models/network_config.dart';
import '../models/cd.dart';

class FuegoRPCService {
  final Dio _dio;
  String _baseUrl;
  final String? _password;
  NetworkConfig _networkConfig;

  static const List<String> defaultRemoteNodes = [
    '207.244.247.64:18180'
  ];

  FuegoRPCService({
    String host = 'localhost',
    int? port,
    String? password,
    NetworkConfig? networkConfig,
  }) : _baseUrl = 'http://$host:${port ?? NetworkConfig.mainnet.walletRpcPort}',
       _password = password,
       _networkConfig = networkConfig ?? NetworkConfig.mainnet,
       _dio = Dio(BaseOptions(
         connectTimeout: const Duration(seconds: 30),
         receiveTimeout: const Duration(seconds: 30),
         headers: {'Content-Type': 'application/json'},
       ));

  void updateNode(String host, {int? port}) {
    _baseUrl = 'http://$host:${port ?? _networkConfig.daemonRpcPort}';
  }

  void updateNetworkConfig(NetworkConfig config) {
    _networkConfig = config;
    final uri = Uri.parse(_baseUrl);
    _baseUrl = 'http://${uri.host}:${config.daemonRpcPort}';
  }

  NetworkConfig get networkConfig => _networkConfig;
  String get currentNodeUrl => _baseUrl;

  // ── Daemon RPC (routed through Rust proxy → fuegod) ──

  Future<Map<String, dynamic>> getInfo() async {
    return _makeDaemonRPCCall('getinfo', {});
  }

  Future<int> getHeight() async {
    final response = await _makeRPCCall('getheight', {});
    return response['height'] as int;
  }

  Future<Map<String, dynamic>> getBlockHash(int height) async {
    return _makeRPCCall('on_getblockhash', [height]);
  }

  Future<Map<String, dynamic>> getBlock(String hash) async {
    return _makeRPCCall('getblock', {'hash': hash});
  }

  // ── Wallet RPC (routed through Rust proxy → walletd) ──

  Future<Wallet> getBalance() async {
    try {
      // getBalance → proxy remaps to walletd's "getbalance"
      final response = await _makeRPCCall('getBalance', {});
      final info = await getInfo();
      final bchainHeight = info['height'] as int;

      int localHeight = 0;
      try {
        // getStatus → proxy remaps to walletd's "get_height"
        final status = await _makeRPCCall('getStatus', {});
        localHeight = status['height'] as int? ?? 0;
      } catch (_) {}

      final available = response['available_balance'] ?? response['availableBalance'] ?? response['balance'] ?? 0;
      final locked = response['locked_amount'] ?? response['lockedAmount'] ?? 0;

      final effectiveLocal = localHeight > 0 ? localHeight : bchainHeight;

      return Wallet(
        address: '',
        viewKey: '',
        spendKey: '',
        balance: available as int,
        unlockedBalance: locked as int,
        blockchainHeight: bchainHeight,
        localHeight: effectiveLocal,
        synced: (bchainHeight - effectiveLocal) <= 1,
      );
    } catch (e) {
      throw FuegoRPCException('Failed to get balance: $e');
    }
  }

  Future<String> getAddress() async {
    try {
      // getAddresses → proxy remaps to walletd's "get_address"
      final response = await _makeRPCCall('getAddresses', {});
      return response['address'] as String? ?? '';
    } catch (e) {
      throw FuegoRPCException('Failed to get address: $e');
    }
  }

  Future<List<WalletTransaction>> getTransactions({
    int blockCount = 1000000,
    int firstBlockIndex = 0,
  }) async {
    try {
      // getTransactions → proxy remaps to walletd's "get_transfers"
      final response = await _makeRPCCall('getTransactions', {});

      final transfers = response['transfers'] as List? ?? [];
      return transfers.map((tx) {
        final txMap = tx as Map<String, dynamic>;
        return WalletTransaction(
          txid: txMap['transactionHash'] ?? txMap['transaction_hash'] ?? '',
          amount: (txMap['amount'] ?? 0) as int,
          fee: (txMap['fee'] ?? 0) as int,
          paymentId: txMap['paymentId'] ?? txMap['payment_id'] ?? '',
          blockHeight: txMap['blockIndex'] ?? txMap['block_index'] ?? 0,
          timestamp: (txMap['time'] ?? 0) as int,
          isSpending: ((txMap['amount'] ?? 0) as int) < 0,
          address: txMap['address'] as String?,
          confirmations: 0,
        );
      }).toList();
    } catch (e) {
      throw FuegoRPCException('Failed to get transactions: $e');
    }
  }

  Future<String> sendTransaction(SendTransactionRequest request) async {
    try {
      // sendTransaction → proxy remaps to walletd's "transfer"
      // Proxy also converts anonymity → mixin, adds unlock_time
      final response = await _makeRPCCall('sendTransaction', {
        'destinations': [{
          'amount': request.amount,
          'address': request.address,
        }],
        'fee': request.fee,
        'anonymity': request.mixins,
        'paymentId': request.paymentId.isNotEmpty ? request.paymentId : null,
      });

      return response['tx_hash'] as String? ?? response['transactionHash'] as String? ?? '';
    } catch (e) {
      throw FuegoRPCException('Failed to send transaction: $e');
    }
  }

  Future<String> createIntegratedAddress(String paymentId) async {
    try {
      if (paymentId.length != 64 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(paymentId)) {
        throw FuegoRPCException('Invalid payment ID: must be 64 hex characters');
      }

      final address = await getAddress();

      final response = await _makeRPCCall('create_integrated', {
        'address': address,
        'payment_id': paymentId,
      });

      return response['integrated_address'] as String;
    } catch (e) {
      throw FuegoRPCException('Failed to create integrated address: $e');
    }
  }

  Future<String> generatePaymentId() async {
    final bytes = List<int>.generate(32, (i) =>
        DateTime.now().millisecondsSinceEpoch + i);
    return sha256.convert(bytes).toString().substring(0, 64);
  }

  // ── Mining (routed through proxy → fuegod) ──

  Future<bool> startMining({
    String? address,
    int threads = 1,
  }) async {
    try {
      final minerAddress = address ?? await getAddress();
      await _makeRPCCall('start_mining', {
        'miner_address': minerAddress,
        'threads_count': threads,
      });
      return true;
    } catch (e) {
      throw FuegoRPCException('Failed to start mining: $e');
    }
  }

  Future<bool> stopMining() async {
    try {
      await _makeRPCCall('stop_mining', {});
      return true;
    } catch (e) {
      throw FuegoRPCException('Failed to stop mining: $e');
    }
  }

  Future<Map<String, dynamic>> getMiningStatus() async {
    try {
      final info = await getInfo();
      return {
        'active': (info['mining_speed'] ?? 0) as int > 0,
        'speed': (info['mining_speed'] ?? 0) as int,
        'threads': (info['threads_count'] ?? 0) as int,
      };
    } catch (e) {
      throw FuegoRPCException('Failed to get mining status: $e');
    }
  }

  // ── CD Methods ──
  // cd::list → proxy remaps to walletd "list_cds"
  // cd::create → proxy remaps to walletd "create_cd"
  // cd::claim → proxy remaps to walletd "withdraw_cd"
  // cd::market_list → proxy remaps to fuegod "getcdoffers"
  // cd::sell → proxy remaps to fuegod "submitcd"
  // cd::buy → proxy remaps to fuegod "submitcd"
  // cd::cancel_listing → proxy remaps to fuegod "cancelcd"
  // cd::apy → proxy remaps to fuegod/walletd "estimate_cd_yield"

  Future<CdListResult> cdList() async {
    final response = await _makeRPCCall('cd::list', {});
    return CdListResult.fromJson(response);
  }

  Future<CdCreateResult> cdCreate({
    required String coin,
    required String amount,
    int? durationBlocks,
  }) async {
    final params = <String, dynamic>{
      'coin': coin,
      'amount': amount,
    };
    if (durationBlocks != null) {
      params['duration_blocks'] = durationBlocks;
    }
    final response = await _makeRPCCall('cd::create', params);
    return CdCreateResult.fromJson(response);
  }

  Future<CdClaimResult> cdClaim(String cdId) async {
    final response = await _makeRPCCall('cd::claim', {'cd_id': cdId});
    return CdClaimResult.fromJson(response);
  }

  Future<CdMarketListResult> cdMarketList() async {
    final response = await _makeRPCCall('cd::market_list', {});
    return CdMarketListResult.fromJson(response);
  }

  Future<CdSellResult> cdSell({
    required String cdId,
    required String price,
  }) async {
    final response = await _makeRPCCall('cd::sell', {
      'cd_id': cdId,
      'price': price,
    });
    return CdSellResult.fromJson(response);
  }

  Future<CdBuyResult> cdBuy(String listingId) async {
    final response = await _makeRPCCall('cd::buy', {
      'listing_id': listingId,
    });
    return CdBuyResult.fromJson(response);
  }

  Future<void> cdCancelListing(String listingId) async {
    await _makeRPCCall('cd::cancel_listing', {
      'listing_id': listingId,
    });
  }

  Future<CdApyResult> cdApy() async {
    final response = await _makeRPCCall('cd::apy', {});
    return CdApyResult.fromJson(response);
  }

  // ── Private helpers ──

  Future<Map<String, dynamic>> _makeDaemonRPCCall(
    String method,
    dynamic params,
  ) async {
    try {
      // Get daemon host from current node URL
      final uri = Uri.parse(_baseUrl);
      final daemonUrl = 'http://${uri.host}:${_networkConfig.daemonRpcPort}';
      final response = await _dio.post(
        '$daemonUrl/json_rpc',
        data: json.encode({
          'jsonrpc': '2.0',
          'id': DateTime.now().millisecondsSinceEpoch,
          'method': method,
          'params': params,
        }),
      );

      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('error')) {
        throw FuegoRPCException(data['error']['message'] as String);
      }
      return data['result'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw FuegoRPCException('Network error: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> _makeRPCCall(
    String method,
    dynamic params,
  ) async {
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
        throw FuegoRPCException(data['error']['message'] as String);
      }

      return data['result'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw FuegoRPCException('Network error: ${e.message}');
    }
  }

  Future<bool> testConnection() async {
    try {
      await getInfo();
      return true;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _dio.close();
  }
}

class FuegoRPCException implements Exception {
  final String message;

  FuegoRPCException(this.message);

  @override
  String toString() => 'FuegoRPCException: $message';
}
