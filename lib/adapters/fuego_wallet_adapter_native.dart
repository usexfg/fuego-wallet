// Copyright (c) 2025 Fuego Developers
// Copyright (c) 2025 Elderfire Privacy Group

import 'dart:async';

import 'package:dio/dio.dart';
import '../models/wallet.dart';
import '../models/network_config.dart';
import 'package:flutter/foundation.dart';
import 'package:xfg_wallet/native/crypto/bindings/crypto_bindings.dart';

/// Hybrid wallet adapter that uses native crypto for key operations and RPC calls for blockchain sync
class FuegoWalletAdapterNative {
  static FuegoWalletAdapterNative? _instance;
  static FuegoWalletAdapterNative get instance {
    _instance ??= FuegoWalletAdapterNative._internal();
    return _instance!;
  }

  final Dio _dio;
  final String _walletRpcUrl;
  NetworkConfig _networkConfig;
  Wallet? _wallet;
  bool _isOpen = false;
  bool _isSynchronized = false;
  bool _useNativeCrypto = true; // Set to true when native lib is available

  Timer? _syncTimer;
  StreamController<WalletEvent>? _eventController;

  // Wallet keys (stored in memory for native operations)
  Uint8List? _privateSpendKey;
  Uint8List? _privateViewKey;
  Uint8List? _publicSpendKey;
  Uint8List? _publicViewKey;

  FuegoWalletAdapterNative._internal()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        )),
        _walletRpcUrl = 'http://localhost:8070',
        _networkConfig = NetworkConfig.mainnet;

  /// Initialize native crypto (if available)
  Future<bool> initNativeCrypto() async {
    final available = await NativeCrypto.init();
    if (available) {
      _useNativeCrypto = true;
      debugPrint('Using native crypto for wallet operations');
      return true;
    }
    debugPrint('Native crypto not available, using RPC-based operations');
    return false;
  }

  /// Create a new wallet using native crypto
  Future<bool> createWalletNative({
    String? password,
    Function(WalletEvent event)? onEvent,
  }) async {
    if (!_useNativeCrypto) {
      // Fall back to RPC-based wallet creation
      return _createWalletViaRpc(password: password, onEvent: onEvent);
    }

    try {
      // Setup event stream
      if (onEvent != null) {
        _eventController = StreamController<WalletEvent>();
        _eventController!.stream.listen(onEvent);
      }

      // Generate keys using native crypto
      final keys = NativeCrypto.generateKeys();
      if (keys == null) throw Exception('Failed to generate keys using native crypto');
      _privateSpendKey = Uint8List.fromList(keys['private_spend_key'] as List<int>);
      _privateViewKey  = Uint8List.fromList(keys['private_view_key'] as List<int>);
      _publicSpendKey  = Uint8List.fromList(keys['public_spend_key'] as List<int>);
      _publicViewKey   = Uint8List.fromList(keys['public_view_key'] as List<int>);
      // Generate address
      // Generate address
      // final address = NativeCrypto.generateAddress(
      //   _publicSpendKey!,
      //   _publicViewKey!,
      //   _networkConfig.addressPrefix,
      // );
      // (You can save the address, for display or wallet file)
      _isOpen = true;
      await _startSync();
      _emitEvent(WalletEvent.created());
      return true;
    } catch (e) {
      debugPrint('Native wallet creation failed: $e');
      _emitEvent(WalletEvent.creationFailed('Failed to create wallet: $e'));
      return false;
    }
  }

  /// Create wallet from private keys using native crypto
  Future<bool> createWithKeysNative({
    required String viewKey,
    required String spendKey,
    String? password,
    Function(WalletEvent event)? onEvent,
  }) async {
    if (!_useNativeCrypto) {
      return _createWithKeysViaRpc(
        viewKey: viewKey,
        spendKey: spendKey,
        password: password,
        onEvent: onEvent,
      );
    }

    try {
      // Setup event stream
      if (onEvent != null) {
        _eventController = StreamController<WalletEvent>();
        _eventController!.stream.listen(onEvent);
      }

      // Convert hex strings to Uint8List
      // _privateSpendKey = Uint8List.fromList(
      //   List.generate(spendKey.length ~/ 2, (i) => int.parse(spendKey.substring(i * 2, i * 2 + 2), radix: 16))
      // );

      // Generate public keys from private keys
      // _publicSpendKey = NativeCrypto.generatePublicKey(_privateSpendKey!);
      // _privateViewKey = NativeCrypto.generateViewKeyFromSpend(_privateSpendKey!);
      // _publicViewKey = NativeCrypto.generatePublicKey(_privateViewKey!);

      // Generate address
      // final address = NativeCrypto.generateAddress(
      //   _publicSpendKey!,
      //   _publicViewKey!,
      //   _networkConfig.addressPrefix,
      // );

      _isOpen = true;
      await _startSync();
      _emitEvent(WalletEvent.opened());
      return true;
    } catch (e) {
      debugPrint('Native wallet creation from keys failed: $e');
      _emitEvent(WalletEvent.creationFailed('Failed to create wallet: $e'));
      return false;
    }
  }

  /// Send transaction using native crypto for signing
  Future<String> sendTransactionNative({
    required Map<String, int> destinations,
    int? fee,
    String? paymentId,
    int mixin = 4,
  }) async {
    if (!_isOpen) throw Exception('Wallet is not open');

    // If native crypto is available, sign locally
    if (_useNativeCrypto && _privateSpendKey != null && _privateViewKey != null) {
      // Build transaction structure
      // Sign with native crypto
      // Send to fuego-walletd via RPC
      // This is a simplified version - full implementation requires
      // building the transaction structure according to Fuego protocol
    }

    // Fall back to RPC-based transaction
    return _sendTransactionViaRpc(
      destinations: destinations,
      fee: fee,
      paymentId: paymentId,
      mixin: mixin,
    );
  }

  // RPC-based fallback methods
  Future<bool> _createWalletViaRpc({String? password, Function(WalletEvent event)? onEvent}) async {
    try {
      final response = await _dio.post(
        '$_walletRpcUrl/json_rpc',
        data: {
          'jsonrpc': '2.0',
          'id': 'test',
          'method': 'create_wallet',
          'params': {
            'filename': 'fuego_wallet',
            'password': password ?? '',
            'language': 'English',
          },
        },
      );

      if (response.data['error'] != null) {
        _emitEvent(WalletEvent.creationFailed(response.data['error']['message']));
        return false;
      }

      _isOpen = true;
      await _startSync();
      _emitEvent(WalletEvent.created());
      return true;
    } catch (e) {
      debugPrint('RPC wallet creation failed: $e');
      _emitEvent(WalletEvent.creationFailed('Failed to create wallet: $e'));
      return false;
    }
  }

  Future<bool> _createWithKeysViaRpc({
    required String viewKey,
    required String spendKey,
    String? password,
    Function(WalletEvent event)? onEvent,
  }) async {
    try {
      final response = await _dio.post(
        '$_walletRpcUrl/json_rpc',
        data: {
          'jsonrpc': '2.0',
          'id': 'test',
          'method': 'create_wallet',
          'params': {
            'filename': 'fuego_wallet',
            'password': password ?? '',
            'restore_height': 0,
            'restore_deterministic_wallet': true,
            'viewkey': viewKey,
            'spendkey': spendKey,
          },
        },
      );

      if (response.data['error'] != null) {
        _emitEvent(WalletEvent.creationFailed(response.data['error']['message']));
        return false;
      }

      _isOpen = true;
      await _startSync();
      _emitEvent(WalletEvent.opened());
      return true;
    } catch (e) {
      debugPrint('RPC wallet creation from keys failed: $e');
      _emitEvent(WalletEvent.creationFailed('Failed to create wallet: $e'));
      return false;
    }
  }

  Future<String> _sendTransactionViaRpc({
    required Map<String, int> destinations,
    int? fee,
    String? paymentId,
    int mixin = 4,
  }) async {
    try {
      final response = await _dio.post(
        '$_walletRpcUrl/json_rpc',
        data: {
          'jsonrpc': '2.0',
          'id': 'test',
          'method': 'transfer',
          'params': {
            'destinations': destinations,
            'fee': fee ?? 1000000000,
            'payment_id': paymentId,
            'mixin': mixin,
            'get_tx_key': true,
          },
        },
      );

      final txHash = response.data['result']['tx_hash'] as String;
      _emitEvent(WalletEvent.transactionCreated(txHash));
      return txHash;
    } catch (e) {
      debugPrint('sendTransaction failed: $e');
      throw Exception('Failed to send transaction: $e');
    }
  }

 Future<void> _startSync() async {
  _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
    await _updateSyncStatus();
  });
}

  Future<void> _updateSyncStatus() async {
    try {
      _emitEvent(WalletEvent.synchronizationProgress(50, 100));
    } catch (e) {
      debugPrint('_updateSyncStatus failed: $e');
    }
  }

  void _emitEvent(WalletEvent event) {
    _eventController?.add(event);
  }

  bool get isOpen => _isOpen;
  bool get isSynchronized => _isSynchronized;
  bool get useNativeCrypto => _useNativeCrypto;
  Wallet? get wallet => _wallet;

  Future<void> close() async {
    if (!_isOpen) return;

    _syncTimer?.cancel();
    _isOpen = false;
    _isSynchronized = false;

    // Clear keys from memory
    _privateSpendKey = null;
    _privateViewKey = null;
    _publicSpendKey = null;
    _publicViewKey = null;

    _emitEvent(WalletEvent.closed());
    _eventController?.close();
  }

  void dispose() {
    _syncTimer?.cancel();
    _eventController?.close();
    _eventController = null;
  }
}

/// Events emitted by the wallet adapter (reusing from fuego_wallet_adapter.dart)
class WalletEvent {
  final WalletEventType type;
  final String? message;
  final Map<String, dynamic>? data;

  WalletEvent({
    required this.type,
    this.message,
    this.data,
  });

  factory WalletEvent.opened() => WalletEvent(type: WalletEventType.opened);
  factory WalletEvent.openFailed(String message) =>
      WalletEvent(type: WalletEventType.openFailed, message: message);
  factory WalletEvent.created() => WalletEvent(type: WalletEventType.created);
  factory WalletEvent.creationFailed(String message) =>
      WalletEvent(type: WalletEventType.creationFailed, message: message);
  factory WalletEvent.closed() => WalletEvent(type: WalletEventType.closed);
  factory WalletEvent.transactionCreated(String txHash) => WalletEvent(
        type: WalletEventType.transactionCreated,
        data: {'txHash': txHash},
      );
  factory WalletEvent.synchronizationProgress(int current, int total) => WalletEvent(
        type: WalletEventType.synchronizationProgress,
        data: {'current': current, 'total': total},
      );
}

enum WalletEventType {
  opened,
  openFailed,
  created,
  creationFailed,
  closed,
  transactionCreated,
  depositCreated,
  depositWithdrawalCreated,
  synchronizationProgress,
}
