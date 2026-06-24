// Copyright (c) 2025 Fuego Developers
// Copyright (c) 2025 Elderfire Privacy Group

import 'dart:convert';
import 'dart:io';
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

  // Default remote Fuego nodes (public community nodes)
  static const List<String> defaultRemoteNodes = [
    '207.244.247.64:18180'
  ];

  FuegoRPCService({
    String host = 'localhost',
    int? port,
    String? password,
    NetworkConfig? networkConfig,
  }) : _baseUrl = 'http://$host:${port ?? NetworkConfig.mainnet.daemonRpcPort}',
       _password = password,
       _networkConfig = networkConfig ?? NetworkConfig.mainnet,
       _dio = Dio(BaseOptions(
         connectTimeout: const Duration(seconds: 30),
         receiveTimeout: const Duration(seconds: 30),
         headers: {'Content-Type': 'application/json'},
       ));

  // Update connection to a new node
  void updateNode(String host, {int? port}) {
    _baseUrl = 'http://$host:${port ?? _networkConfig.daemonRpcPort}';
  }

  // Update network configuration
  void updateNetworkConfig(NetworkConfig config) {
    _networkConfig = config;
    // Update base URL with new port if needed
    final uri = Uri.parse(_baseUrl);
    _baseUrl = 'http://${uri.host}:${config.daemonRpcPort}';
  }

  // Get current network configuration
  NetworkConfig get networkConfig => _networkConfig;

  // Get current node URL
  String get currentNodeUrl => _baseUrl;

  // Daemon RPC Methods
  Future<Map<String, dynamic>> getInfo() async {
    return _makeRPCCall('getinfo', {});
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

  // Wallet RPC Methods (requires wallet service running)
  Future<Wallet> getBalance() async {
    try {
      final response = await _makeWalletRPCCall('getBalance', {});
      final info = await getInfo();
      
      return Wallet(
        address: '', // Will be filled by getAddress
        viewKey: '',
        spendKey: '',
        balance: response['availableBalance'] as int,
        unlockedBalance: response['lockedAmount'] as int,
        blockchainHeight: info['height'] as int,
        localHeight: response['blockCount'] as int,
        synced: (info['height'] - response['blockCount']) <= 1,
      );
    } catch (e) {
      throw FuegoRPCException('Failed to get balance: $e');
    }
  }

  Future<String> getAddress() async {
    try {
      final response = await _makeWalletRPCCall('getAddresses', {});
      final addresses = response['addresses'] as List;
      return addresses.isNotEmpty ? addresses.first : '';
    } catch (e) {
      throw FuegoRPCException('Failed to get address: $e');
    }
  }

  Future<List<WalletTransaction>> getTransactions({
    int blockCount = 1000000,
    int firstBlockIndex = 0,
  }) async {
    try {
      final response = await _makeWalletRPCCall('getTransactions', {
        'blockCount': blockCount,
        'firstBlockIndex': firstBlockIndex,
      });

      final items = response['items'] as List;
      return items.map((item) {
        final transactions = item['transactions'] as List;
        return transactions.map((tx) => WalletTransaction(
          txid: tx['transactionHash'] as String,
          amount: tx['amount'] as int,
          fee: tx['fee'] as int,
          paymentId: tx['paymentId'] as String? ?? '',
          blockHeight: item['blockHash'] != null ? 
              (item['blockIndex'] as int) : 0,
          timestamp: tx['timestamp'] as int,
          isSpending: (tx['amount'] as int) < 0,
          address: tx['transfers']?.isNotEmpty == true ? 
              tx['transfers'][0]['address'] as String? : null,
          confirmations: tx['confirmations'] as int? ?? 0,
        )).toList();
      }).expand((x) => x).toList();
    } catch (e) {
      throw FuegoRPCException('Failed to get transactions: $e');
    }
  }

  Future<String> sendTransaction(SendTransactionRequest request) async {
    try {
      final response = await _makeWalletRPCCall('sendTransaction', {
        'destinations': [{
          'amount': request.amount,
          'address': request.address,
        }],
        'fee': request.fee,
        'anonymity': request.mixins,
        'paymentId': request.paymentId.isNotEmpty ? request.paymentId : null,
      });
      
      return response['transactionHash'] as String;
    } catch (e) {
      throw FuegoRPCException('Failed to send transaction: $e');
    }
  }

Future<String> createIntegratedAddress(String paymentId) async {
  try {
    // Validate payment ID (must be 64 hex characters)
    if (paymentId.length != 64 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(paymentId)) {
      throw FuegoRPCException('Invalid payment ID: must be 64 hex characters');
    }

    final address = await getAddress();
    
    // Call RPC method if available
    final response = await _makeWalletRPCCall('create_integrated', {
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

  // Mining Methods
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
        'active': info['mining_speed'] as int > 0,
        'speed': info['mining_speed'] as int,
        'threads': info['threads_count'] as int? ?? 0,
      };
    } catch (e) {
      throw FuegoRPCException('Failed to get mining status: $e');
    }
  }

  // ── CD Methods (through mm2 v2 RPC) ──
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

  // Private helper methods
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

  Future<Map<String, dynamic>> _makeWalletRPCCall(
    String method, 
    Map<String, dynamic> params,
  ) async {
    try {
      // Use local walletd with network-specific port
      final walletUrl = 'http://localhost:${_networkConfig.walletRpcPort}';
      
      final response = await _dio.post(
        '$walletUrl/json_rpc',
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
      throw FuegoRPCException('Wallet service error: ${e.message}');
    }
  }

  // Test connection
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
