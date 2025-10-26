import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/wallet.dart';
import '../models/network_config.dart';
import '../adapters/fuego_node_adapter.dart';
import '../adapters/fuego_wallet_adapter_native.dart';
import '../services/wallet_daemon_service.dart';

/// Hybrid wallet provider that uses native crypto when available
/// and falls back to RPC for blockchain sync
class WalletProviderHybrid extends ChangeNotifier {
  final FuegoNodeAdapter _nodeAdapter;
  final FuegoWalletAdapterNative _walletAdapter;
  
  Wallet? _wallet;
  List<WalletTransaction> _transactions = [];
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isSyncing = false;
  String? _error;
  Timer? _syncTimer;
  NetworkConfig _networkConfig = NetworkConfig.mainnet;

  // Native crypto status
  bool _useNativeCrypto = false;

  WalletProviderHybrid({
    FuegoNodeAdapter? nodeAdapter,
    FuegoWalletAdapterNative? walletAdapter,
  }) : _nodeAdapter = nodeAdapter ?? FuegoNodeAdapter.instance,
       _walletAdapter = walletAdapter ?? FuegoWalletAdapterNative.instance {
    _init();
  }

  Future<void> _init() async {
    // Try to initialize native crypto
    _useNativeCrypto = await _walletAdapter.initNativeCrypto();
    
    // Listen to node adapter events
    _listenToNodeEvents();
    
    // Listen to wallet adapter events
    _listenToWalletEvents();
  }

  void _listenToNodeEvents() {
    // Handle node adapter events
  }

  void _listenToWalletEvents() {
    // Handle wallet adapter events for UI updates
  }

  // Getters
  Wallet? get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  NetworkConfig get networkConfig => _networkConfig;
  bool get useNativeCrypto => _useNativeCrypto;

  bool get hasWallet => _wallet != null;
  bool get isWalletSynced => _wallet?.synced ?? false;
  double get syncProgress => _wallet?.syncProgress ?? 0.0;

  /// Create a new wallet using native crypto (if available) or RPC
  Future<bool> createWallet({String? password}) async {
    try {
      _setLoading(true);
      
      bool success;
      if (_useNativeCrypto) {
        success = await _walletAdapter.createWalletNative(
          password: password,
          onEvent: _handleWalletEvent,
        );
      } else {
        // Fall back to RPC
        await _startWalletDaemon();
        success = await _walletAdapter.createWalletNative(password: password);
      }

      if (success) {
        await _loadWalletData();
        _setError(null);
        return true;
      }

      return false;
    } catch (e) {
      _setError('Failed to create wallet: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Create wallet from mnemonic seed phrase
  Future<bool> createWalletFromMnemonic({
    required String mnemonic,
    String? password,
  }) async {
    try {
      _setLoading(true);
      
      // First, try to derive private keys from mnemonic using native crypto
      if (_useNativeCrypto) {
        // TODO: Implement mnemonic-to-keys conversion
        // This will call fuego_mnemonic_to_key FFI function
      }

      // Create wallet with keys
      bool success = await _walletAdapter.createWithKeysNative(
        viewKey: 'TODO',
        spendKey: 'TODO',
        password: password,
        onEvent: _handleWalletEvent,
      );

      if (success) {
        await _loadWalletData();
        _setError(null);
        return true;
      }

      return false;
    } catch (e) {
      _setError('Failed to create wallet from mnemonic: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Open existing wallet
  Future<bool> openWallet({required String walletPath, String? password}) async {
    try {
      _setLoading(true);
      
      // Start wallet daemon if not running
      await _startWalletDaemon();

      // TODO: Implement wallet opening via adapter
      await _loadWalletData();
      
      _setError(null);
      return true;
    } catch (e) {
      _setError('Failed to open wallet: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get mnemonic seed phrase for backup
  Future<String?> getMnemonicSeed() async {
    if (!_useNativeCrypto) {
      // Fall back to RPC if native crypto not available
      return await _getMnemonicFromRPC();
    }

    // TODO: Call fuego_key_to_mnemonic FFI function
    return null;
  }

  Future<String?> _getMnemonicFromRPC() async {
    // Implement RPC-based mnemonic retrieval
    return null;
  }

  /// Send transaction
  Future<bool> sendTransaction({
    required String recipient,
    required int amount,
    String? paymentId,
  }) async {
    try {
      if (!hasWallet) {
        _setError('No wallet loaded');
        return false;
      }

      final txHash = await _walletAdapter.sendTransactionNative(
        destinations: {recipient: amount},
        paymentId: paymentId,
      );

      // Refresh wallet data
      await _loadWalletData();
      
      return true;
    } catch (e) {
      _setError('Failed to send transaction: $e');
      return false;
    }
  }

  /// Start wallet daemon for blockchain sync
  Future<void> _startWalletDaemon() async {
    await WalletDaemonService.startWalletd();
    _isConnected = true;
    notifyListeners();
  }

  /// Load wallet data after operations
  Future<void> _loadWalletData() async {
    // TODO: Fetch wallet data from adapter
    _updateWallet();
  }

  void _updateWallet() {
    notifyListeners();
  }

  void _handleWalletEvent(WalletEvent event) {
    switch (event.type) {
      case WalletEventType.opened:
      case WalletEventType.created:
        _loadWalletData();
        break;
      case WalletEventType.transactionCreated:
        _loadWalletData();
        break;
      case WalletEventType.synchronizationProgress:
        _setSyncing(true);
        // Update sync progress from event data
        break;
      case WalletEventType.openFailed:
      case WalletEventType.creationFailed:
        _setError(event.message ?? 'Operation failed');
        _setLoading(false);
        break;
      default:
        break;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSyncing(bool syncing) {
    _isSyncing = syncing;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _walletAdapter.dispose();
    super.dispose();
  }
}

