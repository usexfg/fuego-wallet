import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';
import '../models/wallet.dart';

import '../models/network_config.dart';
import '../services/security_service.dart';
import '../services/fuego_rpc_service.dart';
import '../services/key_service.dart';
import '../sdk/fuego_sdk_service.dart';
import 'package:fuego_sdk/fuego_sdk.dart';

class WalletProvider extends ChangeNotifier {
  static final Logger _logger = Logger('WalletProvider');
  final FuegoRPCService _rpcService;
  final SecurityService _securityService;
  final FuegoSDKService _sdkService;

  Wallet? _wallet;
  List<WalletTransaction> _transactions = [];
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isSyncing = false;
  bool _isMining = false;
  String? _error;
  String? _nodeUrl;
  Timer? _syncTimer;
  NetworkConfig _networkConfig = NetworkConfig.mainnet;

  // Price feeds
  double _xfgEurPrice = 0.0;
  double _heatXfgPrice = 0.0;
  double _heatEurPrice = 0.0;

  // Mining status
  int _miningSpeed = 0;
  int _miningThreads = 1;

  // Network status
  ConnectivityResult _connectivityResult = ConnectivityResult.none;

  WalletProvider({
    FuegoRPCService? rpcService,
    SecurityService? securityService,
  }) : _rpcService = rpcService ?? FuegoRPCService(),
       _securityService = securityService ?? SecurityService(),
       _sdkService = FuegoSDKService.instance {
    _initConnectivity();
    // Test daemon connection immediately at startup
    _checkConnection().then((_) {
      if (!_isConnected) {
        _startConnectionRetry();
      }
    });
  }

  // Getters
  Wallet? get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  bool get isSyncing => _isSyncing;
  bool get isMining => _isMining;
  String? get error => _error;
  String? get nodeUrl => _nodeUrl;
  int get miningSpeed => _miningSpeed;
  int get miningThreads => _miningThreads;
  ConnectivityResult get connectivityResult => _connectivityResult;
  NetworkConfig get networkConfig => _networkConfig;

  // Prices
  double get xfgEurPrice => _xfgEurPrice;
  double get heatXfgPrice => _heatXfgPrice;
  double get heatEurPrice => _heatEurPrice;

  bool get hasWallet => _wallet != null;
  bool get isWalletSynced => _wallet?.synced ?? false;
  double get syncProgress => _wallet?.syncProgress ?? 0.0;
  FuegoSDKService get sdkService => _sdkService;

  // Get private key for burn transactions (requires PIN verification)
  Future<String?> getPrivateKeyForBurn(String pin) async {
    try {
      _logger.info('Attempting to get private key for burn transaction');

      final isValidPin = await _securityService.verifyPIN(pin);
      if (!isValidPin) {
        _logger.warning('Invalid PIN provided for private key access');
        throw Exception('Invalid PIN');
      }

      final keys = await _securityService.getWalletKeys(pin);
      if (keys == null || _wallet == null) {
        _logger.severe('Wallet keys not found');
        throw Exception('Wallet keys not found');
      }

      _logger.info('Private key accessed successfully for burn transaction');
      return keys['spendKey'];
    } catch (e) {
      _logger.severe('Failed to get private key: $e');
      _setError('Failed to get private key: $e');
      return null;
    }
  }

  // Get private key without PIN verification (for internal use when wallet is unlocked)
  String? getPrivateKey() {
    if (_wallet == null) {
      _setError('Wallet not loaded');
      return null;
    }

    if (!isWalletSynced) {
      _setError('Wallet must be synced to access private key');
      return null;
    }

    return _wallet?.spendKey;
  }

  // Validate private key format (basic validation)
  bool isValidPrivateKey(String privateKey) {
    return privateKey.isNotEmpty && privateKey.length >= 32;
  }

  // Clear sensitive data from memory
  void clearSensitiveData() {
    _wallet = null;
    notifyListeners();
  }

  // Initialize connectivity monitoring
  void _initConnectivity() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
      _connectivityResult = result;
      notifyListeners();

      if (result != ConnectivityResult.none) {
        await _checkConnection();
        if (_isConnected && hasWallet && !isWalletSynced) {
          _startSyncTimer();
        }
      } else {
        _isConnected = false;
        notifyListeners();
      }
    });

    // Initial connection check
    _checkConnection();
  }

  // Wallet Management
  Future<bool> createWallet({
    required String pin,
    String? mnemonic,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final seed = mnemonic ?? SecurityService.generateMnemonic();

      if (!SecurityService.validateMnemonic(seed)) {
        throw Exception('Invalid mnemonic phrase');
      }

      await _securityService.storeWalletSeed(seed, pin);
      await _securityService.setPIN(pin);

      final keyPair = await KeyService.deriveFromMnemonic(seed);

      await _securityService.storeWalletKeys(
        viewKey: keyPair.viewPrivateKey,
        spendKey: keyPair.spendPrivateKey,
        address: keyPair.address,
        pin: pin,
      );

      _wallet = Wallet(
        address: keyPair.address,
        viewKey: keyPair.viewPublicKey,
        spendKey: keyPair.spendPublicKey,
        balance: 0,
        unlockedBalance: 0,
        balanceHEAT: 0,
        unlockedBalanceHEAT: 0,
        blockchainHeight: 0,
        localHeight: 0,
        synced: false,
      );

      _setLoading(false);
      notifyListeners();

      _checkConnection();

      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> restoreWallet({
    required String mnemonic,
    required String pin,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      if (!SecurityService.validateMnemonic(mnemonic)) {
        throw Exception('Invalid mnemonic phrase');
      }

      await _securityService.storeWalletSeed(mnemonic, pin);
      await _securityService.setPIN(pin);

      final keyPair = await KeyService.deriveFromMnemonic(mnemonic);

      await _securityService.storeWalletKeys(
        viewKey: keyPair.viewPrivateKey,
        spendKey: keyPair.spendPrivateKey,
        address: keyPair.address,
        pin: pin,
      );

      _wallet = Wallet(
        address: keyPair.address,
        viewKey: keyPair.viewPublicKey,
        spendKey: keyPair.spendPublicKey,
        balance: 0,
        unlockedBalance: 0,
        balanceHEAT: 0,
        unlockedBalanceHEAT: 0,
        blockchainHeight: 0,
        localHeight: 0,
        synced: false,
      );

      _setLoading(false);
      notifyListeners();

      _checkConnection();

      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> unlockWallet(String pin) async {
    _setLoading(true);
    _clearError();

    try {
      final isValidPin = await _securityService.verifyPIN(pin);
      if (!isValidPin) {
        throw Exception('Invalid PIN');
      }

      final keys = await _securityService.getWalletKeys(pin);
      if (keys == null) {
        throw Exception('Wallet keys not found');
      }

      // Restore wallet from stored keys
      _wallet = Wallet(
        address: keys['address'] ?? '',
        viewKey: keys['viewKey'] ?? '',
        spendKey: keys['spendKey'] ?? '',
        balance: 0,
        unlockedBalance: 0,
        balanceHEAT: 0,
        unlockedBalanceHEAT: 0,
        blockchainHeight: 0,
        localHeight: 0,
        synced: false,
      );

      // Try SDK init but don't crash if native lib missing
      try {
        await _sdkService.initialize();
      } catch (_) {
        _logger.info('Native SDK not available, using RPC mode');
      }

      // Check connection and fetch daemon info
      await _checkConnection();

      if (_isConnected) {
        // Get daemon height first
        try {
          final height = await _rpcService.getHeight();
          final info = await _rpcService.getInfo();
          _wallet = _wallet!.copyWith(
            blockchainHeight: height,
            localHeight: height,
          );
        } catch (_) {}

        // Now do a full wallet refresh to get balance/transactions
        notifyListeners();
        await refreshWallet();
      } else {
        _setError('Could not connect to Fuego daemon at ${_rpcService.currentNodeUrl}');
      }

      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> lockWallet() async {
    _wallet = null;
    _transactions.clear();
    _sdkService.closeWallet();
    _stopSyncTimer();
    notifyListeners();
  }

  Future<bool> hasWalletData() async {
    return await _securityService.hasWalletData();
  }

  // Wallet credentials
  String get walletFile {
    try {
      return _securityService.walletPath ?? '/tmp/fuego/wallets/default.wallet';
    } catch (_) {
      return '/tmp/fuego/wallets/default.wallet';
    }
  }

  String get walletPassword {
    try {
      return _securityService.walletPassword ?? 'fuego_wallet';
    } catch (_) {
      return 'fuego_wallet';
    }
  }

  // Wallet Operations
  Future<void> refreshWallet() async {
    if (!_isConnected) {
      await _checkConnection();
      if (!_isConnected) {
        _setError('Not connected to Fuego node');
        return;
      }
    }

    try {
      _setLoading(true);
      _clearError();

      // RPC path — always reliable
      // 1. Get daemon height
      try {
        final height = await _rpcService.getHeight();
        _wallet = _wallet!.copyWith(
          blockchainHeight: height,
          localHeight: height,
          synced: true,
        );
        _logger.info('Daemon height: $height');
      } catch (e) {
        _logger.warning('Could not get height from daemon: $e');
      }

      // 2. Try wallet RPC if walletd is running locally (for balance)
      try {
        final rpcWallet = await _rpcService.getBalance();
        final address = await _rpcService.getAddress();
        _wallet = Wallet(
          address: address,
          viewKey: _wallet?.viewKey ?? '',
          spendKey: _wallet?.spendKey ?? '',
          balance: rpcWallet.balance,
          unlockedBalance: rpcWallet.unlockedBalance,
          balanceHEAT: rpcWallet.balanceHEAT,
          unlockedBalanceHEAT: rpcWallet.unlockedBalanceHEAT,
          blockchainHeight: rpcWallet.blockchainHeight,
          localHeight: rpcWallet.localHeight,
          synced: rpcWallet.synced,
        );
        _logger.info('Wallet balance loaded via wallet RPC');
      } catch (e) {
        // Wallet RPC not available (no local walletd) — daemon height only
        _logger.info('Wallet RPC not available (RPC-only mode): $e');
      }

      _refreshPrices();

      if (!isWalletSynced) {
        _startSyncTimer();
      }

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _refreshPrices() async {
    _xfgEurPrice = 0.05;
    _heatXfgPrice = 100.0;
    _heatEurPrice = _heatXfgPrice * _xfgEurPrice;
    notifyListeners();
  }

  Future<void> refreshTransactions() async {
    try {
      final txs = await _rpcService.getTransactions();
      _transactions = txs;
      notifyListeners();
    } catch (e) {
      _setError('Failed to refresh transactions: $e');
    }
  }

  Future<String?> sendTransaction({
    required String address,
    required double amount,
    String? paymentId,
    int mixins = 7,
    String? assetId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = _sdkService.wallet.send(
        address: address,
        amount: amount,
        assetId: assetId,
      );

      if (result.error != FuegoError.FUEGO_OK) {
        throw Exception('Send failed: ${result.error}');
      }

      await refreshWallet();
      await refreshTransactions();

      _setLoading(false);
      return result.txHash;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  Future<String> generatePaymentId() async {
    return await _rpcService.generatePaymentId();
  }

  Future<String> createIntegratedAddress(String paymentId) async {
    return await _rpcService.createIntegratedAddress(paymentId);
  }

  // Mining Operations
  Future<void> startMining({int threads = 1}) async {
    try {
      _miningThreads = threads;
      final addr = _wallet?.address;
      if (addr == null || addr.isEmpty) {
        throw Exception('No wallet address available for mining');
      }
      final error = await _sdkService.mining.start(addr);

      if (error == FuegoError.FUEGO_OK) {
        _isMining = true;
        _startMiningStatusTimer();
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to start mining: $e');
    }
  }

  Future<void> stopMining() async {
    try {
      await _sdkService.mining.stop();
      _isMining = false;
      _miningSpeed = 0;
      notifyListeners();
    } catch (e) {
      _setError('Failed to stop mining: $e');
    }
  }

  Future<void> refreshMiningStatus() async {
    try {
      final running = _sdkService.mining.isRunning();
      _isMining = running;
      if (running) {
        final hashrate = await _sdkService.mining.getHashrate();
        _miningSpeed = hashrate.round();
      }
      notifyListeners();
    } catch (e) {
      // Mining might not be supported, ignore errors
    }
  }


  // Connection Management
  Future<void> connectToNode(String url) async {
    _setLoading(true);
    _clearError();

    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      final port = uri.port == 0 ? _networkConfig.daemonRpcPort : uri.port;

      _rpcService.updateNode(host, port: port);
      _nodeUrl = url;

      await _checkConnection();

      if (_isConnected && hasWallet) {
        await refreshWallet();
      }
    } catch (e) {
      _setError('Failed to connect to node: $e');
    }

    _setLoading(false);
  }

  Future<void> updateNetworkConfig(NetworkConfig config) async {
    _networkConfig = config;
    _rpcService.updateNetworkConfig(config);

    if (_nodeUrl != null) {
      final uri = Uri.parse(_nodeUrl!);
      final newUrl = '${uri.scheme}://${uri.host}:${config.daemonRpcPort}';
      _nodeUrl = newUrl;
    }

    notifyListeners();
  }

  // Auto-retry connection timer
  Timer? _connectionRetryTimer;
  int _connectionAttempts = 0;
  static const int _maxRetryInterval = 30;

  void _startConnectionRetry() {
    _connectionRetryTimer?.cancel();
    _connectionAttempts = 0;
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_isConnected) {
      _connectionRetryTimer?.cancel();
      return;
    }
    _connectionAttempts++;
    final delaySeconds = min(3 * _connectionAttempts, _maxRetryInterval);
    _connectionRetryTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (!_isConnected && !_isLoading) {
        _logger.info('Connection retry #$_connectionAttempts');
        await _checkConnection();
        if (!_isConnected) {
          _scheduleRetry();
        }
      }
    });
  }

  void _stopConnectionRetry() {
    _connectionRetryTimer?.cancel();
    _connectionRetryTimer = null;
  }

  Future<void> _checkConnection() async {
    try {
      // Try SDK first (fast check, no network)
      try {
        final sdkRunning = _sdkService.isNodeRunning();
        if (sdkRunning) {
          _isConnected = true;
          _error = null;
          _stopConnectionRetry();
          notifyListeners();
          return;
        }
      } catch (_) {}

      // RPC connection check — the reliable path
      final result = await _rpcService.testConnectionDetailed();

      if (result['connected'] == true) {
        _isConnected = true;
        _error = null;
        _stopConnectionRetry();

        // Fetch network height so it's not stuck at 0
        try {
          final height = await _rpcService.getHeight();
          if (_wallet != null && _wallet!.blockchainHeight == 0) {
            _wallet = _wallet!.copyWith(
              blockchainHeight: height,
              localHeight: height,
            );
          }
          _logger.info('Connected to daemon at height $height');
        } catch (e) {
          _logger.warning('Connected but failed to get height: $e');
        }
      } else {
        _isConnected = false;
        _error = result['error']?.toString();
        _logger.warning('Connection failed: ${_error ?? "unknown"}');
        if (!_isLoading) _scheduleRetry();
      }
    } catch (e) {
      _isConnected = false;
      _error = 'Connection check failed: $e';
      _logger.severe('Connection check exception: $e');
      if (!_isLoading) _scheduleRetry();
    }
    notifyListeners();
  }

  // Timer Management
  void _startSyncTimer() {
    if (_syncTimer?.isActive == true) return;

    _syncTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_wallet != null && !isWalletSynced) {
        _refreshSyncStatus();
      } else {
        _stopSyncTimer();
      }
    });
  }

  void _stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _isSyncing = false;
    notifyListeners();
  }

  void _startMiningStatusTimer() {
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isMining) {
        refreshMiningStatus();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _refreshSyncStatus() async {
    try {
      _isSyncing = true;

      int height = _wallet?.blockchainHeight ?? 0;
      bool synced = false;

      // RPC is the reliable path — always use it
      try {
        height = await _rpcService.getHeight();
        synced = (height > 0);
      } catch (_) {}

      if (_wallet != null) {
        _wallet = _wallet!.copyWith(
          blockchainHeight: height,
          localHeight: height,
          synced: synced,
        );
      }

      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Messaging Operations
  Future<bool> sendMessage({
    required String recipientAddress,
    required String message,
    bool selfDestruct = false,
    int? destructTime,
  }) async {
    try {
      final success = await _rpcService.sendMessage(
        recipientAddress: recipientAddress,
        message: message,
        selfDestruct: selfDestruct,
        destructTime: destructTime,
      );

      if (success) {
        return true;
      } else {
        _setError('Failed to send message');
        return false;
      }
    } catch (e) {
      _setError('Failed to send message: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> loadMessages() async {
    try {
      final messages = await _rpcService.getMessages();

      return messages.map((msg) {
        return {
          'id': msg['id'] ?? '',
          'type': msg['type'] ?? 'received',
          'address': msg['address'] ?? '',
          'content': msg['content'] ?? '',
          'preview': _generateMessagePreview(msg['content'] as String? ?? ''),
          'timestamp': msg['timestamp'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'unread': msg['unread'] ?? false,
          'self_destruct': msg['self_destruct'] ?? false,
          'attachment': msg['attachment'] ?? false,
        };
      }).toList();
    } catch (e) {
      _setError('Failed to load messages: $e');
      return [];
    }
  }

  String _generateMessagePreview(String content) {
    if (content.isEmpty) return 'Encrypted message';
    if (content.length <= 50) return content;
    return '${content.substring(0, 50)}...';
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _connectionRetryTimer?.cancel();
    _rpcService.dispose();
    _sdkService.cleanup();
    super.dispose();
  }
}
