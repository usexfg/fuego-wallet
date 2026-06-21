import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import '../models/wallet.dart';
import '../models/network_config.dart';
import '../adapters/fuego_node_adapter.dart';
import '../adapters/fuego_wallet_adapter_native.dart';
import '../services/wallet_daemon_service.dart';
import '../services/key_service.dart';
import '../services/fuego_rpc_service.dart';

/// Hybrid wallet provider that uses native crypto when available
/// and falls back to RPC for blockchain sync
class WalletProviderHybrid extends ChangeNotifier {
  static final Logger _logger = Logger('WalletProviderHybrid');
  final FuegoNodeAdapter _nodeAdapter;
  final FuegoWalletAdapterNative _walletAdapter;
  
  Wallet? _wallet;
  final List<WalletTransaction> _transactions = [];
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isSyncing = false;
  String? _error;
  Timer? _syncTimer;
  final NetworkConfig _networkConfig = NetworkConfig.mainnet;

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
    _nodeAdapter.init(
      nodeUrl: _nodeAdapter.nodeUrl,
      onEvent: (event) {
        switch (event.type) {
          case NodeEventType.initCompleted:
            _isConnected = true;
            notifyListeners();
            break;
          case NodeEventType.initFailed:
            _isConnected = false;
            notifyListeners();
            break;
          case NodeEventType.blockchainUpdated:
            _isSyncing = true;
            notifyListeners();
            break;
          case NodeEventType.deinitCompleted:
            _isConnected = false;
            notifyListeners();
            break;
          default:
            break;
        }
      },
    );
  }

  void _listenToWalletEvents() {
    // Wallet adapter events are handled via _handleWalletEvent callback
    // passed during wallet creation/opening operations
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

      if (_useNativeCrypto) {
        // Native crypto not available — use pure Dart derivation
      }

      final keyPair = await KeyService.deriveFromMnemonic(mnemonic);

      bool success = await _walletAdapter.createWithKeysNative(
        viewKey: keyPair.viewPrivateKey,
        spendKey: keyPair.spendPrivateKey,
        password: password,
        onEvent: _handleWalletEvent,
      );

      if (success) {
        _wallet = Wallet(
          address: keyPair.address,
          viewKey: keyPair.viewPublicKey,
          spendKey: keyPair.spendPublicKey,
          balance: 0,
          unlockedBalance: 0,
          blockchainHeight: 0,
          localHeight: 0,
          synced: false,
        );
        notifyListeners();
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

      await _walletAdapter.createWithKeysNative(
        viewKey: '',
        spendKey: '',
        password: password,
        onEvent: _handleWalletEvent,
      );
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
    try {
      if (FuegoWalletAdapterNative.isAvailable) {
        // FFI mnemonic retrieval
        return null; // FFI not yet available
      }
    } catch (_) {}
    return await _getMnemonicFromRPC();
  }

  Future<String?> _getMnemonicFromRPC() async {
    try {
      final rpcService = FuegoRPCService(host: '207.244.247.64', port: 18180);
      final result = await rpcService.makeRPCCall('query_key', {'key_type': 'mnemonic'});
      if (result.containsKey('result')) {
        return result['result']['key'] as String?;
      }
    } catch (_) {}
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
    final success = await WalletDaemonService.startWalletd();
    _isConnected = success;
  }

  /// Load wallet data after operations
  Future<void> _loadWalletData() async {
    try {
      if (_walletAdapter.wallet != null) {
        _wallet = _walletAdapter.wallet;
      } else {
        // Fallback to RPC
        await _updateWalletFromRPC();
      }
    } catch (e) {
      _logger.warning('Failed to load wallet data: $e');
    }
    _updateWallet();
  }

  Future<void> _updateWalletFromRPC() async {
    try {
      final rpcService = FuegoRPCService(host: '207.244.247.64', port: 18180);
      final info = await rpcService.getInfo();
      final height = info['height'] as int? ?? 0;
      _wallet = Wallet(
        address: '',
        viewKey: '',
        spendKey: '',
        balance: 0,
        unlockedBalance: 0,
        blockchainHeight: height,
        localHeight: height,
        synced: false,
      );
    } catch (_) {}
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

  @visibleForTesting
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

