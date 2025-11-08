// Copyright (c) 2025 Fuego Developers
// Copyright (c) 2025 Elderfire Privacy Group

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/wallet.dart';
import '../models/transaction_model.dart';

class WalletService {
  static const String _baseUrl = 'http://localhost:8080'; // Default Fuego RPC endpoint
  
  // Singleton pattern
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  /// Get wallet balance
  Future<String> getBalance(String address) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/json_rpc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': '0',
          'method': 'get_balance',
          'params': {'address': address}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result']['balance'].toString();
      }
      throw Exception('Failed to get balance: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error getting balance: $e');
    }
  }

  /// Get wallet address
  Future<String> getAddress() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/json_rpc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': '0',
          'method': 'get_address'
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result']['address'];
      }
      throw Exception('Failed to get address: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error getting address: $e');
    }
  }

  /// Create a new wallet
  Future<Wallet> createWallet() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/json_rpc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': '0',
          'method': 'create_wallet'
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Wallet.fromJson(data['result']);
      }
      throw Exception('Failed to create wallet: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error creating wallet: $e');
    }
  }

  /// Send transaction
  Future<String> sendTransaction({
    required String toAddress,
    required String amount,
    required String privateKey,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/json_rpc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': '0',
          'method': 'send_transaction',
          'params': {
            'to_address': toAddress,
            'amount': amount,
            'private_key': privateKey,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result']['tx_hash'];
      }
      throw Exception('Failed to send transaction: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error sending transaction: $e');
    }
  }

  /// Get transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/json_rpc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': '0',
          'method': 'get_transaction_history'
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['result']['transactions']);
      }
      throw Exception('Failed to get transaction history: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error getting transaction history: $e');
    }
  }

  /// Get transactions as TransactionModel objects
  Future<List<TransactionModel>> getTransactions() async {
    try {
      final List<Map<String, dynamic>> transactionData = await getTransactionHistory();
      return transactionData.map((data) => TransactionModel.fromJson(data)).toList();
    } catch (e) {
      throw Exception('Error getting transactions: $e');
    }
  }

  /// Check if transaction is a burn transaction
  bool isBurnTransaction(Map<String, dynamic> transaction) {
    return transaction['type'] == 'burn' || 
           transaction['to_address'] == null ||
           transaction['to_address'].isEmpty;
  }
}
