// Copyright (c) 2025 Fuego Developers
// Copyright (c) 2025 Elderfire Privacy Group

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/wallet.dart';
import '../models/network_config.dart';

class FuegoRPCService {
  final Dio _dio;
  String _baseUrl;
  NetworkConfig _networkConfig;

  // Default remote Fuego nodes (public community nodes)
  static const List<String> defaultRemoteNodes = [
    '207.244.247.64:18180',
    '216.145.66.230:28280'
  ];

  FuegoRPCService({
    String host = 'localhost',
    int? port,
    String? password,
    NetworkConfig? networkConfig,
  }) : _baseUrl = 'http://$host:${port ?? (networkConfig?.daemonRpcPort ?? NetworkConfig.mainnet.daemonRpcPort)}',
       _networkConfig = networkConfig ?? NetworkConfig.mainnet,
       _dio = Dio(BaseOptions(
         connectTimeout: const Duration(seconds: 30),
         receiveTimeout: const Duration(seconds: 30),
         headers: {'Content-Type': 'application/json'},
       )) {
   // Update wallet URL to use correct port
   debugPrint('RPC Service initialized with base URL: $_baseUrl');
   debugPrint('Network config: ${_networkConfig.name} (daemon: ${_networkConfig.daemonRpcPort}, wallet: ${_networkConfig.walletRpcPort})');
 }

  // Update connection to a new node
  void updateNode(String host, {int? port}) {
    _baseUrl = 'http://$host:${port ?? _networkConfig.daemonRpcPort}';
    debugPrint('Updated node to: $_baseUrl');
  }

  // Update network configuration
  void updateNetworkConfig(NetworkConfig config) {
    _networkConfig = config;
    // Update base URL with new host and port if needed
    String host;
    if (config.defaultSeedNode.contains(':')) {
      host = config.defaultSeedNode.split(':')[0];
    } else {
      host = config.defaultSeedNode;
    }
    _baseUrl = 'http://$host:${config.daemonRpcPort}';
    debugPrint('Updated network config: ${config.name} (daemon: ${config.daemonRpcPort}, wallet: ${config.walletRpcPort})');
    debugPrint('New base URL: $_baseUrl');
  }

  // Get current network configuration
  NetworkConfig get networkConfig => _networkConfig;

  // Get current node URL
  String get currentNodeUrl => _baseUrl;

  // Daemon REST API Methods
  Future<Map<String, dynamic>> getInfo() async {
    try {
      debugPrint('REST: Calling GET $_baseUrl/getinfo');
      final response = await _dio.get('$_baseUrl/getinfo');
      debugPrint('REST: Response: ${response.data}');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('REST: Network error for getinfo: $e');
      throw FuegoRPCException('Network error: ${e.message}');
    }
  }

  Future<int> getHeight() async {
    final response = await getInfo();
    return response['height'] as int;
  }

  Future<Map<String, dynamic>> getBlockHash(int height) async {
    // Not directly supported, return placeholder
    return {'block_hash': '0' * 64};
  }

  Future<Map<String, dynamic>> getBlock(String hash) async {
    // Not directly supported, return placeholder
    return {
      'block': {
        'hash': hash,
        'height': 0,
      }
    };
  }

  // Wallet RPC Methods (requires wallet service running)
  Future<Wallet> getBalance() async {
    try {
      // Get balance from wallet RPC service
      final response = await _makeWalletRPCCall('getBalance', {});
      final info = await getInfo();

      return Wallet(
        address: '', // Will be filled by getAddress
        viewKey: '',
        spendKey: '',
        balance: response['availableBalance'] as int,
        unlockedBalance: response['lockedAmount'] as int,
        blockchainHeight: info['height'] as int,
        localHeight: info['height'] as int,
        synced: true,
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

    // Return placeholder integrated address for now
    return 'fireIntegratedAddressPlaceholder1234567890${paymentId.substring(0, 32)}';
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

  // Elderfier Methods (custom implementation for Fuego)
  Future<List<ElderfierNode>> getElderfierNodes() async {
    try {
      // This would be a custom RPC call specific to Fuego's Elderfier system
      final response = await _makeRPCCall('get_elderfier_nodes', {});
      final nodes = response['nodes'] as List;

      return nodes.map((node) => ElderfierNode(
        nodeId: node['node_id'] as String,
        customName: node['custom_name'] as String,
        address: node['address'] as String,
        stakeAmount: node['stake_amount'] as int,
        isActive: node['is_active'] as bool,
        uptime: node['uptime'] as int,
        lastSeenBlock: node['last_seen_block'] as int,
        consensusType: node['consensus_type'] as String,
      )).toList();
    } catch (e) {
      // Return empty list if Elderfier functionality is not available
      return [];
    }
  }

  Future<bool> registerElderfierNode({
    required String customName,
    required String address,
    required int stakeAmount,
  }) async {
    try {
      await _makeRPCCall('register_elderfier', {
        'custom_name': customName,
        'address': address,
        'stake_amount': stakeAmount,
      });
      return true;
    } catch (e) {
      throw FuegoRPCException('Failed to register Elderfier node: $e');
    }
  }

  // Message Methods (encrypted messaging)
  Future<bool> sendMessage({
    required String recipientAddress,
    required String message,
    bool selfDestruct = false,
    int? destructTime,
  }) async {
    try {
      await _makeRPCCall('send_message', {
        'recipient': recipientAddress,
        'message': message,
        'self_destruct': selfDestruct,
        'destruct_time': destructTime,
      });
      return true;
    } catch (e) {
      throw FuegoRPCException('Failed to send message: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMessages() async {
    try {
      final response = await _makeRPCCall('get_messages', {});
      return List<Map<String, dynamic>>.from(response['messages'] as List);
    } catch (e) {
      return []; // Return empty list if messaging not available
    }
  }

  // Private helper methods (deprecated - using REST API now)
  Future<Map<String, dynamic>> _makeRPCCall(
    String method,
    dynamic params,
  ) async {
    // This method is no longer used since we're using REST API
    throw UnimplementedError('JSON-RPC calls are not supported. Use REST API methods instead.');
  }

  Future<Map<String, dynamic>> _makeWalletRPCCall(
    String method,
    Map<String, dynamic> params,
  ) async {
    try {
      // Use local walletd with network-specific port for wallet operations
      final walletUrl = 'http://localhost:${_networkConfig.walletRpcPort}';
      debugPrint('Wallet RPC: Calling $method on $walletUrl');

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
      debugPrint('Wallet RPC: Response for $method: $data');

      if (data.containsKey('error')) {
        debugPrint('Wallet RPC: Error for $method: ${data['error']}');
        throw FuegoRPCException(data['error']['message'] as String);
      }

      return data['result'] as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('Wallet RPC: Network error for $method: $e');
      throw FuegoRPCException('Wallet service error: ${e.message}');
    }
  }

  // Test connection
  Future<bool> testConnection() async {
    debugPrint('REST: testConnection called for node: $_baseUrl');
    try {
      final info = await getInfo();
      debugPrint('REST: testConnection successful, node info: $info');
      return info['status'] == 'OK';
    } catch (e) {
      debugPrint('REST: testConnection failed due to error: $e');
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
