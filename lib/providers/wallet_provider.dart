import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wallet.dart';
import '../models/network_config.dart';
import '../services/fuego_rpc_service.dart';
import '../services/security_service.dart';
import '../services/wallet_daemon_service.dart';

class WalletProvider extends ChangeNotifier {
  static final Logger _logger = Logger('WalletProvider');
  final FuegoRPCService _rpcService;
  final SecurityService _securityService;

  Wallet? _wallet;
  List<WalletTransaction> _transactions = [];
  List<ElderfierNode> _elderfierNodes = [];
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isSyncing = false;
  bool _isMining = false;
  String? _error;
  String? _nodeUrl;
  Timer? _syncTimer;
  NetworkConfig _networkConfig = NetworkConfig.mainnet;

  // Wallet file management
  static const String _walletPathKey = 'wallet_file_path';

  // Currency symbol (XFG for mainnet, TEST for testnet)
  String _currencySymbol = 'XFG';

  // Mining status
  int _miningSpeed = 0;
  int _miningThreads = 1;

  // Network status
  ConnectivityResult _connectivityResult = ConnectivityResult.none;

  WalletProvider({
    FuegoRPCService? rpcService,
    SecurityService? securityService,
  }) : _rpcService = rpcService ?? FuegoRPCService(),
       _securityService = securityService ?? SecurityService() {
    _initConnectivity();
  }

  // Getters
  Wallet? get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;
  List<ElderfierNode> get elderfierNodes => _elderfierNodes;
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

  bool get hasWallet => _wallet != null;
  bool get isWalletSynced => _wallet?.synced ?? false;
  double get syncProgress => _wallet?.syncProgress ?? 0.0;

  /// Get private key for burn transactions (requires PIN verification)
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
      // Return the spend key as the private key for burn transactions
      return keys['spendKey'];
    } catch (e) {
      _logger.severe('Failed to get private key: $e');
      _setError('Failed to get private key: $e');
      return null;
    }
  }

  /// Get current currency symbol
  String get currencySymbol => _currencySymbol;

  // Get private key without PIN verification (for internal use when wallet is unlocked)
  String? getPrivateKey() {
    if (_wallet == null) {
      _setError('Wallet not loaded');
      return null;
    }

    // Only return private key if wallet is synced and unlocked
    if (!isWalletSynced) {
      _setError('Wallet must be synced to access private key');
      return null;
    }

    return _wallet?.spendKey;
  }

  // Validate private key format (basic validation)
  bool isValidPrivateKey(String privateKey) {
    // Basic validation - in real implementation, this would validate against Fuego key format
    return privateKey.isNotEmpty && privateKey.length >= 32;
  }

  // Clear sensitive data from memory
  void clearSensitiveData() {
    // In a real implementation, this would securely clear memory
    // For now, we'll just clear the wallet reference
    _wallet = null;
    notifyListeners();
  }

  // Initialize connectivity monitoring
  void _initConnectivity() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _connectivityResult = result;
      notifyListeners();

      if (result != ConnectivityResult.none) {
        _checkConnection();
      } else {
        _isConnected = false;
        notifyListeners();
      }
    });
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

      // Store mnemonic securely
      await _securityService.storeWalletSeed(seed, pin);
      await _securityService.setPIN(pin);

      // TODO: Derive keys from the mnemonic
      // For now, we'll simulate this process
      final viewKey = 'view_key_placeholder_${DateTime.now().millisecondsSinceEpoch}';
      final spendKey = 'spend_key_placeholder_${DateTime.now().millisecondsSinceEpoch}';

      await _securityService.storeWalletKeys(
        viewKey: viewKey,
        spendKey: spendKey,
        pin: pin,
      );

      _setLoading(false);
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

      // Store mnemonic and create PIN
      await _securityService.storeWalletSeed(mnemonic, pin);
      await _securityService.setPIN(pin);

      // TODO Derive keys from mnemonic (placeholder implementation)
      final viewKey = 'restored_view_key_${DateTime.now().millisecondsSinceEpoch}';
      final spendKey = 'restored_spend_key_${DateTime.now().millisecondsSinceEpoch}';

      await _securityService.storeWalletKeys(
        viewKey: viewKey,
        spendKey: spendKey,
        pin: pin,
      );

      _setLoading(false);
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

      // Start wallet daemon with stored wallet file if available
      debugPrint('Starting wallet daemon for unlocked wallet...');
      final storedWalletPath = await getStoredWalletPath();
      bool walletStarted = false;

      if (storedWalletPath != null) {
        debugPrint('Opening stored wallet file: $storedWalletPath');
        walletStarted = await WalletDaemonService.openWallet(
          walletPath: storedWalletPath,
          password: pin, // Using PIN as password for the wallet file
        );
        debugPrint('Wallet daemon open result: $walletStarted');
        if (!walletStarted) {
          _setError('Failed to open wallet file. The password may be incorrect or the file may be corrupted.');
        }
      } else {
        debugPrint('No stored wallet file found, creating temporary wallet');
        // Create a temporary wallet file for this session
        final tempDir = await getTemporaryDirectory();
        final walletPath = path.join(tempDir.path, 'temp_wallet_${DateTime.now().millisecondsSinceEpoch}.wallet');
        debugPrint('Creating temporary wallet at: $walletPath');
        final walletCreated = await WalletDaemonService.createWallet(
          walletPath: walletPath,
          password: pin,
        );

        if (walletCreated) {
          debugPrint('Temporary wallet created successfully');
          await _storeWalletPath(walletPath);
          walletStarted = await WalletDaemonService.openWallet(
            walletPath: walletPath,
            password: pin,
          );
          debugPrint('Wallet daemon open result: $walletStarted');
          if (!walletStarted) {
            _setError('Failed to open newly created wallet file. Please try again.');
          }
        } else {
          _setError('Failed to create wallet file. Please try again or restore from backup.');
          _setLoading(false);
          return false;
        }
      }

      debugPrint('Wallet daemon start completed, result: $walletStarted');
      // Initialize wallet with actual data
      await refreshWallet();

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
    _stopSyncTimer();
    notifyListeners();
  }

  Future<bool> hasWalletData() async {
    return await _securityService.hasWalletData();
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

      // Get wallet balance and info
      debugPrint('Refreshing wallet data...');
      final info = await _rpcService.getInfo();
      debugPrint('Node info retrieved: ${info['height']}');

      // Check if wallet daemon is available before trying to get wallet data
      final isWalletdAvailable = await WalletDaemonService.isWalletRpcAvailable();
      debugPrint('Wallet daemon availability: $isWalletdAvailable');

      if (isWalletdAvailable) {
        try {
          // Get wallet data from RPC service
          final balance = await _rpcService.getBalance();
          debugPrint('Balance retrieved: ${balance.balance}');
          final address = await _rpcService.getAddress();
          debugPrint('Address retrieved: $address');

          // Set currency symbol based on current network
          balance.setCurrencySymbol(_networkConfig.addressPrefix == 'TEST' ? 'TEST' : 'XFG');

          _wallet = balance;

          debugPrint('Wallet created with balance: ${balance.balance}, address: $address, currency: ${balance.currencySymbol}');
        } catch (walletError) {
          debugPrint('Error getting wallet data: $walletError');
          // Create a placeholder wallet with just node info
          _wallet = Wallet(
            address: 'Wallet not available',
            viewKey: '',
            spendKey: '',
            balance: 0,
            unlockedBalance: 0,
            blockchainHeight: info['height'] as int,
            localHeight: info['height'] as int,
            synced: true,
          );
        }
      } else {
        debugPrint('Wallet daemon not available, creating placeholder wallet');
        // Create a placeholder wallet with just node info
        _wallet = Wallet(
          address: 'Wallet daemon not running',
          viewKey: '',
          spendKey: '',
          balance: 0,
          unlockedBalance: 0,
          blockchainHeight: info['height'] as int,
          localHeight: info['height'] as int,
          synced: true,
        );
      }

      // Start sync timer if not already running
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
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final atomicAmount = (amount * 10000000).round();
      const fee = 10000000; // Default fee in atomic units

      final request = SendTransactionRequest(
        address: address,
        amount: atomicAmount,
        paymentId: paymentId ?? '',
        fee: fee,
        mixins: mixins,
      );

      final txHash = await _rpcService.sendTransaction(request);

      // Refresh wallet after sending
      await refreshWallet();
      await refreshTransactions();

      _setLoading(false);
      return txHash;
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
      final success = await _rpcService.startMining(threads: threads);

      if (success) {
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
      await _rpcService.stopMining();
      _isMining = false;
      _miningSpeed = 0;
      notifyListeners();
    } catch (e) {
      _setError('Failed to stop mining: $e');
    }
  }

  Future<void> refreshMiningStatus() async {
    try {
      final status = await _rpcService.getMiningStatus();
      _isMining = status['active'] as bool;
      _miningSpeed = status['speed'] as int;
      _miningThreads = status['threads'] as int;
      notifyListeners();
    } catch (e) {
      // Mining might not be supported, ignore errors
    }
  }

  // Elderfier Operations
  Future<void> refreshElderfierNodes() async {
    try {
      final nodes = await _rpcService.getElderfierNodes();
      _elderfierNodes = nodes;
      notifyListeners();
    } catch (e) {
      // Elderfier functionality might not be available
    }
  }

  Future<bool> registerElderfierNode({
    required String customName,
    required String address,
    required double stakeAmount,
  }) async {
    try {
      final atomicStake = (stakeAmount * 10000000).round();
      final success = await _rpcService.registerElderfierNode(
        customName: customName,
        address: address,
        stakeAmount: atomicStake,
      );

      if (success) {
        await refreshElderfierNodes();
      }

      return success;
    } catch (e) {
      _setError('Failed to register Elderfier node: $e');
      return false;
    }
  }

  // Connection Management
  Future<void> connectToNode(String url) async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint('Connecting to node: $url');
      // Parse the URL to extract host and port
      final uri = Uri.parse(url);
      final host = uri.host;
      final port = uri.port == 80 || uri.port == 443 ? _networkConfig.daemonRpcPort : uri.port;

      // Update the RPC service with new node
      _rpcService.updateNode(host, port: port);
      _nodeUrl = url;

      await _checkConnection();

      if (_isConnected && hasWallet) {
        await refreshWallet();
      }

      debugPrint('Node connection completed. Connected: $_isConnected');
    } catch (e) {
      debugPrint('Failed to connect to node: $e');
      _setError('Invalid node URL: $e');
    }

    _setLoading(false);
  }

  /// Update network configuration
  Future<void> updateNetworkConfig(NetworkConfig config) async {
    _networkConfig = config;
    _rpcService.updateNetworkConfig(config);

    // Update currency symbol based on network
    _currencySymbol = config.addressPrefix == 'TEST' ? 'TEST' : 'XFG';

    // Update node URL if it's using the old port
    if (_nodeUrl != null) {
      final uri = Uri.parse(_nodeUrl!);
      final newUrl = '${uri.scheme}://${uri.host}:${config.daemonRpcPort}';
      _nodeUrl = newUrl;
    }

    // Update any existing wallet with new currency symbol
    if (_wallet != null) {
      _wallet!.setCurrencySymbol(_currencySymbol);
    }

    notifyListeners();
  }

  /// Open an existing wallet file
  Future<bool> openWallet({
    required String walletPath,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Store wallet path for future use
      await _storeWalletPath(walletPath);

      // Start wallet daemon with the wallet file
      final success = await WalletDaemonService.openWallet(
        walletPath: walletPath,
        password: password,
      );

      if (success) {
        await refreshWallet();
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Create a new wallet file
  Future<bool> createWalletFile({
    required String walletPath,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Create wallet using wallet daemon service
      final success = await WalletDaemonService.createWallet(
        walletPath: walletPath,
        password: password,
      );

      if (success) {
        // Store wallet path for future use
        await _storeWalletPath(walletPath);

        // Open the newly created wallet
        final openSuccess = await WalletDaemonService.openWallet(
          walletPath: walletPath,
          password: password,
        );

        if (openSuccess) {
          await refreshWallet();
        }

        return openSuccess;
      }

      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Manually trigger a sync status refresh
  Future<void> refreshSyncStatus() async {
    debugPrint('Manual sync status refresh triggered');
    await _refreshSyncStatus();
  }

  /// Store wallet path in shared preferences
  Future<void> _storeWalletPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_walletPathKey, path);
  }

  /// Get stored wallet path from shared preferences
  Future<String?> getStoredWalletPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_walletPathKey);
  }



  Future<void> _checkConnection() async {
    try {
      debugPrint('Checking connection to Fuego node...');
      _isConnected = await _rpcService.testConnection();
      debugPrint('Connection check result: $_isConnected');
    } catch (e) {
      debugPrint('Connection check failed: $e');
      _isConnected = false;
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
    // Only refresh if we're connected
    if (!_isConnected) {
      debugPrint('Not refreshing sync status: Not connected to node');
      return;
    }

    try {
      debugPrint('Refreshing sync status...');
      _isSyncing = true;
      notifyListeners();

      final info = await _rpcService.getInfo();
      debugPrint('Node info: ${info['height']} height');

      // Check if wallet daemon is available and responding
      final isWalletdAvailable = await WalletDaemonService.isWalletRpcAvailable();
      debugPrint('Wallet daemon availability: $isWalletdAvailable');

      if (isWalletdAvailable) {
        try {
          final balance = await _rpcService.getBalance();
          debugPrint('Wallet balance: ${balance.balance}, local height: ${balance.localHeight}');

          if (_wallet != null) {
            final blockchainHeight = info['height'] as int;
            final localHeight = balance.localHeight;
            final isSynced = (blockchainHeight - localHeight) <= 1;

            debugPrint('Sync status - Blockchain: $blockchainHeight, Local: $localHeight, Synced: $isSynced');

            _wallet = _wallet!.copyWith(
              blockchainHeight: blockchainHeight,
              localHeight: localHeight,
              synced: isSynced,
            );
          }
        } catch (walletError) {
          debugPrint('Error getting wallet balance: $walletError');
          // Even if wallet RPC fails, we can still update node info
        }
      } else {
        debugPrint('Wallet daemon not available, updating node info only');
        if (_wallet != null) {
          final blockchainHeight = info['height'] as int;
          _wallet = _wallet!.copyWith(
            blockchainHeight: blockchainHeight,
            localHeight: blockchainHeight, // Assume synced if no wallet
            synced: true,
          );
        }
      }

      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing sync status: $e');
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
        // Message sent successfully
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

      // Transform messages for UI consumption
      return messages.map((msg) {
        return {
          'id': msg['id'] ?? '',
          'type': msg['type'] ?? 'received', // 'received' or 'sent'
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
    _rpcService.dispose();
    super.dispose();
  }
}
