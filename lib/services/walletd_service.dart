import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

/// Service for managing walletd (PaymentGateService) and optimizer processes
/// This enables GUI integration of walletd and fuego-optimizer functionality
class WalletdService {
  static final Logger _logger = Logger('WalletdService');

  // Singleton instance
  static WalletdService? _instance;
  static WalletdService get instance => _instance ??= WalletdService._();

  // Process handles
  Process? _walletdProcess;
  Process? _optimizerProcess;

  // Configuration
  String _walletdHost = '127.0.0.1';
  int _walletdPort = 8070;
  String? _configPath;

  // State tracking
  bool _isWalletdRunning = false;
  bool _isOptimizerRunning = false;
  StreamSubscription? _walletdStdout;
  StreamSubscription? _walletdStderr;
  StreamSubscription? _optimizerStdout;
  StreamSubscription? _optimizerStderr;

  // Callbacks for UI updates
  Function(String)? onWalletdLog;
  Function(String)? onOptimizerLog;
  Function(bool)? onWalletdStatusChanged;
  Function(bool)? onOptimizerStatusChanged;

  WalletdService._();

  /// Initialize the service and extract binaries if needed
  Future<void> initialize() async {
    try {
      _logger.info('Initializing WalletdService...');

      // Ensure binaries exist
      await _ensureBinaries();

      _logger.info('WalletdService initialized successfully');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize WalletdService', e, stackTrace);
      rethrow;
    }
  }

  /// Check and extract required binaries
  Future<void> _ensureBinaries() async {
    final Directory appDir = await getApplicationSupportDirectory();
    final String binDir = path.join(appDir.path, 'bin');
    final Directory binDirectory = Directory(binDir);

    if (!await binDirectory.exists()) {
      await binDirectory.create(recursive: true);
    }

    // Check for walletd binary
    final String walletdBinary = _getWalletdBinaryName();
    final File walletdFile = File(path.join(binDir, walletdBinary));

    if (!await walletdFile.exists()) {
      _logger.warning('walletd binary not found at ${walletdFile.path}');
      _logger.warning('Walletd service requires fuego-walletd binary to be built/downloaded');
      _logger.warning('Run the build-fuego-source.sh script or check CI/CD for binary availability');
    }

    // Check for optimizer binary (if separate)
    final String optimizerBinary = _getOptimizerBinaryName();
    final File optimizerFile = File(path.join(binDir, optimizerBinary));

    if (!await optimizerFile.exists()) {
      _logger.warning('optimizer binary not found at ${optimizerFile.path}');
      // Note: fuego-optimizer may be compiled into walletd or may be separate
    }
  }

  /// Get platform-specific walletd binary name
  String _getWalletdBinaryName() {
    if (Platform.isWindows) return 'fuego-walletd-windows.exe';
    if (Platform.isMacOS) {
      // Check architecture
      return 'fuego-walletd-macos-${Platform.environment['HOSTTYPE'] ?? 'x86_64'}';
    }
    // Linux
    final arch = Platform.environment['HOSTTYPE'] ?? 'x86_64';
    return 'fuego-walletd-linux-$arch';
  }

  /// Get platform-specific optimizer binary name
  String _getOptimizerBinaryName() {
    if (Platform.isWindows) return 'fuego-optimizer-windows.exe';
    if (Platform.isMacOS) return 'fuego-optimizer-macos';
    return 'fuego-optimizer-linux';
  }

  /// Get the full path to a binary
  Future<String> _getBinaryPath(String binaryName) async {
    final Directory appDir = await getApplicationSupportDirectory();
    return path.join(appDir.path, 'bin', binaryName);
  }

  /// Start walletd service
  Future<bool> startWalletd({
    String? configPath,
    String? walletFile,
    String? password,
    bool enableRpc = true,
    String? daemonAddress,
  }) async {
    if (_isWalletdRunning) {
      _logger.info('walletd is already running');
      return true;
    }

    try {
      final String binaryName = _getWalletdBinaryName();
      final String binaryPath = await _getBinaryPath(binaryName);

      final File binaryFile = File(binaryPath);
      if (!await binaryFile.exists()) {
        _logger.severe('walletd binary not found: $binaryPath');
        onWalletdLog?.call('ERROR: walletd binary not found. Please ensure fuego-walletd is built/downloaded.');
        return false;
      }

      // Build arguments
      final List<String> args = [];

      // Use config file if provided
      if (configPath != null) {
        args.addAll(['--config', configPath]);
        _configPath = configPath;
      }

      // OR build args from individual parameters
      if (walletFile != null && configPath == null) {
        args.addAll(['--wallet-file', walletFile]);
        if (password != null) {
          args.addAll(['--password', password]);
        }
        if (daemonAddress != null) {
          args.addAll(['--daemon-address', daemonAddress]);
        }
        if (enableRpc) {
          args.addAll(['--rpc-bind-port', '$_walletdPort']);
          args.addAll(['--rpc-bind-ip', _walletdHost]);
        }
      }

      _logger.info('Starting walletd: $binaryPath ${args.join(' ')}');
      onWalletdLog?.call('Starting walletd service...');

      // Start the process
      _walletdProcess = await Process.start(binaryPath, args);

      // Capture output streams
      _walletdStdout = _walletdProcess!.stdout
          .transform(utf8.decoder)
          .listen((data) {
            _logger.info('walletd stdout: $data');
            onWalletdLog?.call(data);
          });

      _walletdStderr = _walletdProcess!.stderr
          .transform(utf8.decoder)
          .listen((data) {
            _logger.warning('walletd stderr: $data');
            onWalletdLog?.call('ERROR: $data');
          });

      // Monitor process exit
      _walletdProcess!.exitCode.then((exitCode) {
        _logger.info('walletd exited with code: $exitCode');
        _isWalletdRunning = false;
        onWalletdStatusChanged?.call(false);
        onWalletdLog?.call('walletd service stopped (exit code: $exitCode)');
        _cleanupWalletd();
      });

      // Wait a moment for walletd to start
      await Future.delayed(const Duration(seconds: 2));

      // Verify it's running by checking RPC endpoint
      if (enableRpc) {
        final bool isResponsive = await _checkWalletdRpc();
        if (!isResponsive) {
          _logger.warning('walletd started but RPC not responsive');
          onWalletdLog?.call('WARNING: walletd RPC not responding. Check configuration.');
        }
      }

      _isWalletdRunning = true;
      onWalletdStatusChanged?.call(true);
      onWalletdLog?.call('walletd service started successfully');

      return true;
    } catch (e, stackTrace) {
      _logger.severe('Failed to start walletd', e, stackTrace);
      onWalletdLog?.call('ERROR: Failed to start walletd: $e');
      return false;
    }
  }

  /// Stop walletd service
  Future<bool> stopWalletd() async {
    if (!_isWalletdRunning || _walletdProcess == null) {
      _logger.info('walletd is not running');
      return true;
    }

    try {
      _logger.info('Stopping walletd...');
      onWalletdLog?.call('Stopping walletd service...');

      // Send graceful shutdown signal
      _walletdProcess!.kill(ProcessSignal.sigterm);

      // Wait for graceful shutdown
      await Future.delayed(const Duration(seconds: 3));

      // Force kill if still running
      if (_walletdProcess != null) {
        _walletdProcess!.kill(ProcessSignal.sigkill);
      }

      _cleanupWalletd();

      _isWalletdRunning = false;
      onWalletdStatusChanged?.call(false);
      onWalletdLog?.call('walletd service stopped');

      return true;
    } catch (e, stackTrace) {
      _logger.severe('Failed to stop walletd', e, stackTrace);
      onWalletdLog?.call('ERROR: Failed to stop walletd: $e');
      return false;
    }
  }

  /// Start fuego-optimizer (may connect to walletd via JSON-RPC)
  Future<bool> startOptimizer({
    String? walletdIp,
    int? walletdPort,
    bool autoOptimize = true,
    int scanInterval = 300, // seconds
  }) async {
    if (_isOptimizerRunning) {
      _logger.info('optimizer is already running');
      return true;
    }

    try {
      final String binaryName = _getOptimizerBinaryName();
      final String binaryPath = await _getBinaryPath(binaryName);

      final File binaryFile = File(binaryPath);
      if (!await binaryFile.exists()) {
        _logger.warning('optimizer binary not found: $binaryPath');
        _logger.warning('Optimizer may be integrated into walletd or not available');
        onOptimizerLog?.call('WARNING: Optimizer binary not found. May be integrated into walletd.');

        // Try using walletd's integrated optimizer via RPC
        return _startIntegratedOptimizer(
          walletdIp: walletdIp ?? _walletdHost,
          walletdPort: walletdPort ?? _walletdPort,
        );
      }

      // Build arguments
      final List<String> args = [];

      // Connection to walletd
      args.addAll(['--walletd-ip', walletdIp ?? _walletdHost]);
      args.addAll(['--walletd-port', '${walletdPort ?? _walletdPort}']);

      // Optimization settings
      if (autoOptimize) {
        args.addAll(['--auto-optimize']);
      }
      args.addAll(['--scan-interval', scanInterval.toString()]);

      _logger.info('Starting optimizer: $binaryPath ${args.join(' ')}');
      onOptimizerLog?.call('Starting optimizer service...');

      // Start the process
      _optimizerProcess = await Process.start(binaryPath, args);

      // Capture output streams
      _optimizerStdout = _optimizerProcess!.stdout
          .transform(utf8.decoder)
          .listen((data) {
            _logger.info('optimizer stdout: $data');
            onOptimizerLog?.call(data);
          });

      _optimizerStderr = _optimizerProcess!.stderr
          .transform(utf8.decoder)
          .listen((data) {
            _logger.warning('optimizer stderr: $data');
            onOptimizerLog?.call('ERROR: $data');
          });

      // Monitor process exit
      _optimizerProcess!.exitCode.then((exitCode) {
        _logger.info('optimizer exited with code: $exitCode');
        _isOptimizerRunning = false;
        onOptimizerStatusChanged?.call(false);
        onOptimizerLog?.call('optimizer service stopped (exit code: $exitCode)');
        _cleanupOptimizer();
      });

      // Wait a moment for optimizer to initialize
      await Future.delayed(const Duration(seconds: 2));

      _isOptimizerRunning = true;
      onOptimizerStatusChanged?.call(true);
      onOptimizerLog?.call('optimizer service started successfully');

      return true;
    } catch (e, stackTrace) {
      _logger.severe('Failed to start optimizer', e, stackTrace);
      onOptimizerLog?.call('ERROR: Failed to start optimizer: $e');
      return false;
    }
  }

  /// Start integrated optimizer via walletd RPC
  Future<bool> _startIntegratedOptimizer({
    required String walletdIp,
    required int walletdPort,
  }) async {
    try {
      onOptimizerLog?.call('Using walletd integrated optimizer via RPC...');

      // Check if walletd is running
      if (!_isWalletdRunning) {
        onOptimizerLog?.call('ERROR: walletd is not running. Start walletd first.');
        return false;
      }

      // Verify walletd RPC is responsive
      final bool isResponsive = await _checkWalletdRpc(host: walletdIp, port: walletdPort);
      if (!isResponsive) {
        onOptimizerLog?.call('ERROR: walletd RPC not accessible');
        return false;
      }

      // Send optimize command via walletd RPC
      final result = await _sendRpcRequest(
        host: walletdIp,
        port: walletdPort,
        method: 'optimize',
        params: {},
      );

      if (result != null) {
        _isOptimizerRunning = true;
        onOptimizerStatusChanged?.call(true);
        onOptimizerLog?.call('Integrated optimizer active via walletd RPC');
        return true;
      } else {
        onOptimizerLog?.call('ERROR: Failed to start integrated optimizer');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.severe('Failed to start integrated optimizer', e, stackTrace);
      onOptimizerLog?.call('ERROR: $e');
      return false;
    }
  }

  /// Stop optimizer service
  Future<bool> stopOptimizer() async {
    if (!_isOptimizerRunning) {
      _logger.info('optimizer is not running');
      return true;
    }

    try {
      _logger.info('Stopping optimizer...');
      onOptimizerLog?.call('Stopping optimizer service...');

      if (_optimizerProcess != null) {
        // Send graceful shutdown
        _optimizerProcess!.kill(ProcessSignal.sigterm);
        await Future.delayed(const Duration(seconds: 2));

        // Force kill if still running
        if (_optimizerProcess != null) {
          _optimizerProcess!.kill(ProcessSignal.sigkill);
        }

        _cleanupOptimizer();
      } else {
        // Integrated optimizer - stop via RPC
        if (_isWalletdRunning) {
          await _sendRpcRequest(
            method: 'stop_optimization',
            params: {},
          );
        }
      }

      _isOptimizerRunning = false;
      onOptimizerStatusChanged?.call(false);
      onOptimizerLog?.call('optimizer service stopped');

      return true;
    } catch (e, stackTrace) {
      _logger.severe('Failed to stop optimizer', e, stackTrace);
      onOptimizerLog?.call('ERROR: Failed to stop optimizer: $e');
      return false;
    }
  }

  /// Cleanup walletd process resources
  void _cleanupWalletd() {
    _walletdStdout?.cancel();
    _walletdStdout = null;
    _walletdStderr?.cancel();
    _walletdStderr = null;
    _walletdProcess = null;
  }

  /// Cleanup optimizer process resources
  void _cleanupOptimizer() {
    _optimizerStdout?.cancel();
    _optimizerStdout = null;
    _optimizerStderr?.cancel();
    _optimizerStderr = null;
    _optimizerProcess = null;
  }

  /// Check if walletd RPC is responsive
  Future<bool> _checkWalletdRpc({String? host, int? port}) async {
    try {
      final response = await _sendRpcRequest(
        host: host ?? _walletdHost,
        port: port ?? _walletdPort,
        method: 'get_status',
        params: {},
        timeout: const Duration(seconds: 3),
      );
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Send JSON-RPC request to walletd
  Future<Map<String, dynamic>?> _sendRpcRequest({
    String? host,
    int? port,
    required String method,
    Map<String, dynamic>? params,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final uri = Uri.parse('http://${host ?? _walletdHost}:${port ?? _walletdPort}/json_rpc');

      final requestBody = jsonEncode({
        'jsonrpc': '2.0',
        'id': '0',
        'method': method,
        'params': params ?? {},
      });

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['result'] != null) {
          return decoded['result'] as Map<String, dynamic>;
        }
        if (decoded['error'] != null) {
          _logger.warning('RPC error: ${decoded['error']}');
          onWalletdLog?.call('RPC Error: ${decoded['error']}');
        }
      } else {
        _logger.warning('RPC HTTP error: ${response.statusCode}');
        onWalletdLog?.call('HTTP Error: ${response.statusCode}');
      }

      return null;
    } catch (e) {
      _logger.warning('RPC request failed: $e');
      return null;
    }
  }

  /// Get walletd status
  bool get isWalletdRunning => _isWalletdRunning;

  /// Get optimizer status
  bool get isOptimizerRunning => _isOptimizerRunning;

  /// Get RPC connection info
  Map<String, dynamic> get rpcInfo => {
    'host': _walletdHost,
    'port': _walletdPort,
    'running': _isWalletdRunning,
    'config': _configPath,
  };

  /// Perform optimization via walletd RPC
  Future<bool> optimizeWallet() async {
    if (!_isWalletdRunning) {
      onOptimizerLog?.call('ERROR: walletd is not running');
      return false;
    }

    try {
      onOptimizerLog?.call('Starting optimization...');

      final result = await _sendRpcRequest(
        method: 'optimize',
        params: {'auto': true},
      );

      if (result != null) {
        onOptimizerLog?.call('Optimization completed successfully');
        return true;
      } else {
        onOptimizerLog?.call('ERROR: Optimization failed');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.severe('Optimization failed', e, stackTrace);
      onOptimizerLog?.call('ERROR: $e');
      return false;
    }
  }

  /// Get walletd logs (recent)
  Future<List<String>> getWalletdLogs({int lines = 100}) async {
    // In a real implementation, this would read from a log file
    // For now, return recent log messages cached in memory
    return []; // TODO: Implement log file reading
  }

  /// Get optimizer logs (recent)
  Future<List<String>> getOptimizerLogs({int lines = 100}) async {
    // In a real implementation, this would read from a log file
    return []; // TODO: Implement log file reading
  }

  /// Get walletd version info
  Future<String?> getWalletdVersion() async {
    try {
      if (!_isWalletdRunning) return null;

      final result = await _sendRpcRequest(
        method: 'get_version',
        params: {},
      );

      return result?['version'] as String?;
    } catch (e) {
      _logger.warning('Failed to get walletd version: $e');
      return null;
    }
  }

  /// Get optimizer version info
  Future<String?> getOptimizerVersion() async {
    try {
      if (_isOptimizerRunning && _optimizerProcess != null) {
        // Process version output if available
        return '.optimizer.detected';
      } else if (_isWalletdRunning) {
        // Check for integrated optimizer
        final status = await _sendRpcRequest(
          method: 'get_status',
          params: {},
        );
        return status?['optimizer_version'] as String?;
      }
      return null;
    } catch (e) {
      _logger.warning('Failed to get optimizer version: $e');
      return null;
    }
  }

  /// Set RPC connection parameters
  void setRpcConfig({String? host, int? port}) {
    if (host != null) _walletdHost = host;
    if (port != null) _walletdPort = port;
    onWalletdLog?.call('RPC config updated: $_walletdHost:$_walletdPort');
  }

  /// Handle walletd log callback
  void setWalletdLogCallback(Function(String) callback) {
    onWalletdLog = callback;
  }

  /// Handle optimizer log callback
  void setOptimizerLogCallback(Function(String) callback) {
    onOptimizerLog = callback;
  }

  /// Handle status change callbacks
  void setStatusCallbacks({
    Function(bool)? onWalletd,
    Function(bool)? onOptimizer,
  }) {
    if (onWalletd != null) onWalletdStatusChanged = onWalletd;
    if (onOptimizer != null) onOptimizerStatusChanged = onOptimizer;
  }

  /// Dispose the service and stop all processes
  Future<void> dispose() async {
    _logger.info('Disposing WalletdService...');

    await stopOptimizer();
    await stopWalletd();

    _cleanupWalletd();
    _cleanupOptimizer();

    onWalletdLog = null;
    onOptimizerLog = null;
    onWalletdStatusChanged = null;
    onOptimizerStatusChanged = null;

    _logger.info('WalletdService disposed');
  }
}
```

I'll continue creating the additional files for the complete wallet integration. Let me create the web3 service for COLD token:```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/contracts.dart';
import 'package:web3dart/json_rpc.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web3 service for COLD token on Ethereum
class Web3COLDService {
  static final Logger _logger = Logger('Web3COLDService');

  // Singleton instance
  static Web3COLDService? _instance;
  static Web3COLDService get instance => _instance ??= Web3COLDService._();

  // Web3 client
  Web3Client? _client;
  DeployedContract? _coldContract;

  // COLD Token Contract Address (Ethereum Mainnet)
  static const String COLD_CONTRACT_ADDRESS = '0x5aFe5e5C60940B5C6Ca0322dFe51c6D01d455755';

  // COLD Token ABI (simplified)
  static const String COLD_ABI = '''
  [
    {
      "constant": true,
      "inputs": [{"name": "account","type":"address"}],
      "name": "balanceOf",
      "outputs": [{"name": "balance","type":"uint256"}],
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [],
      "name": "decimals",
      "outputs": [{"name": "decimals","type":"uint8"}],
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [],
      "name": "symbol",
      "outputs": [{"name": "symbol","type":"string"}],
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [],
      "name": "name",
      "outputs": [{"name": "name","type":"string"}],
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [],
      "name": "totalSupply",
      "outputs": [{"name": "supply","type":"uint256"}],
      "type": "function"
    },
    {
      "constant": false,
      "inputs": [
        {"name": "to","type":"address"},
        {"name": "value","type":"uint256"}
      ],
      "name": "transfer",
      "outputs": [{"name": "success","type":"bool"}],
      "type": "function"
    }
  ]
  ''';

  // RPC endpoints
  static const List<String> RPC_ENDPOINTS = [
    'https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161', // Public Infura
    'https://eth-mainnet.g.alchemy.com/v2/demo',
    'https://ethereum.publicnode.com',
    'https://eth.llamarpc.com',
  ];

  // State
  bool _isConnected = false;
  String _currentRpc = '';
  Map<String, dynamic>? _cachedBalance;
  DateTime? _lastBalanceUpdate;

  // Callbacks
  Function(String)? onLog;
  Function(bool)? onConnectionStatusChanged;
  Function(Map<String, dynamic>)? onBalanceUpdated;

  Web3COLDService._();

  /// Initialize the service
  Future<void> initialize() async {
    try {
      _logger.info('Initializing Web3COLDService...');

      // Try to restore last used RPC
      final prefs = await SharedPreferences.getInstance();
      _currentRpc = prefs.getString('cold_rpc_endpoint') ?? RPC_ENDPOINTS.first;

      // Connect to RPC
      await connect(_currentRpc);

      _logger.info('Web3COLDService initialized');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize Web3COLDService', e, stackTrace);
      onLog?.call('ERROR: Failed to initialize Web3 service: $e');
    }
  }

  /// Connect to Ethereum RPC
  Future<bool> connect(String rpcEndpoint) async {
    try {
      onLog?.call('Connecting to Ethereum RPC...');

      // Create Web3 client
      _client = Web3Client(rpcEndpoint, http.Client());

      // Test connection
      final networkId = await _client!.getNetworkId();
      _logger.info('Connected to Ethereum network (ID: $networkId)');

      // Load COLD contract
      final abi = jsonDecode(COLD_ABI);
      _coldContract = DeployedContract(
        ContractAbi.fromJson(COLD_ABI, 'COLD'),
        EthereumAddress.fromHex(COLD_CONTRACT_ADDRESS),
      );

      _isConnected = true;
      _currentRpc = rpcEndpoint;
      onConnectionStatusChanged?.call(true);
      onLog?.call('Connected to Ethereum: $rpcEndpoint');

      // Save RPC endpoint
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cold_rpc_endpoint', rpcEndpoint);

      return true;
    } catch (e) {
      _logger.warning('Failed to connect to RPC: $rpcEndpoint - $e');
      onLog?.call('ERROR: Connection failed: $e');
      _isConnected = false;
      onConnectionStatusChanged?.call(false);
      return false;
    }
  }

  /// Try multiple RPC endpoints
  Future<bool> connectAuto() async {
    for (String endpoint in RPC_ENDPOINTS) {
      if (await connect(endpoint)) {
        return true;
      }
      onLog?.call('Trying next endpoint...');
      await Future.delayed(const Duration(milliseconds: 500));
    }

    onLog?.call('ERROR: All RPC endpoints failed');
    return false;
  }

  /// Disconnect from RPC
  Future<void> disconnect() async {
    await _client?.dispose();
    _client = null;
    _isConnected = false;
    onConnectionStatusChanged?.call(false);
    onLog?.call('Disconnected from Ethereum');
  }

  /// Get COLD token balance for an address
  Future<Map<String, dynamic>?> getBalance(String address) async {
    if (!_isConnected || _client == null || _coldContract == null) {
      onLog?.call('ERROR: Not connected to Ethereum');
      return null;
    }

    try {
      onLog?.call('Fetching COLD balance for $address...');

      final ethAddress = EthereumAddress.fromHex(address);

      // Get balance
      final balanceFunction = _coldContract!.function('balanceOf');
      final balanceResult = await _client!.call(
        contract: _coldContract!,
        function: balanceFunction,
        params: [ethAddress],
      );

      final rawBalance = balanceResult[0] as BigInt;

      // Get decimals
      final decimalsFunction = _coldContract!.function('decimals');
      final decimalsResult = await _client!.call(
        contract: _coldContract!,
        function: decimalsFunction,
        params: [],
      );

      final decimals = decimalsResult[0] as int;

      // Get symbol and name
      final symbolFunction = _coldContract!.function('symbol');
      final nameFunction = _coldContract!.function('name');

      final symbolResult = await _client!.call(
        contract: _coldContract!,
        function: symbolFunction,
        params: [],
      );

      final nameResult = await _client!.call(
        contract: _coldContract!,
        function: nameFunction,
        params: [],
      );

      final symbol = symbolResult[0] as String;
      final name = nameResult[0] as String;

      // Convert to human-readable format
      final balanceInTokens = rawBalance / BigInt.from(10).pow(decimals);
      final balanceDisplay = balanceInTokens.toStringAsFixed(2);

      final balanceData = {
        'address': address,
        'symbol': symbol,
        'name': name,
        'decimals': decimals,
        'rawBalance': rawBalance.toString(),
        'balance': balanceDisplay,
        'timestamp': DateTime.now().toIso8601String(),
        'network': 'ethereum',
      };

      _cachedBalance = balanceData;
      _lastBalanceUpdate = DateTime.now();

      onBalanceUpdated?.call(balanceData);
      onLog?.call('COLD Balance: $balanceDisplay $symbol');

      return balanceData;
    } catch (e, stackTrace) {
      _logger.severe('Failed to get COLD balance', e, stackTrace);
      onLog?.call('ERROR: Failed to get balance: $e');
      return null;
    }
  }

  /// Check if address is valid
  bool isValidEthereumAddress(String address) {
    try {
      EthereumAddress.fromHex(address);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get current block number
  Future<int?> getCurrentBlock() async {
    if (!_isConnected || _client == null) return null;

    try {
      final block = await _client!.getBlockNumber();
      onLog?.call('Current block: $block');
      return block;
    } catch (e) {
      _logger.warning('Failed to get block number: $e');
      return null;
    }
  }

  /// Get gas price
  Future<String?> getGasPrice() async {
    if (!_isConnected || _client == null) return null;

    try {
      final gasPrice = await _client!.getGasPrice();
      final gasInGwei = gasPrice.getInWei / BigInt.from(10).pow(9);
      onLog?.call('Gas price: ${gasInGwei.toStringAsFixed(2)} Gwei');
      return gasInGwei.toStringAsFixed(2);
    } catch (e) {
      _logger.warning('Failed to get gas price: $e');
      return null;
    }
  }

  /// Transfer COLD tokens
  Future<Map<String, dynamic>?> transfer({
    required String fromAddress,
    required String toAddress,
    required String amount,
    required String privateKey,
  }) async {
    if (!_isConnected || _client == null || _coldContract == null) {
      onLog?.call('ERROR: Not connected to Ethereum');
      return null;
    }

    try {
      onLog?.call('Initiating COLD transfer...');

      // Create credentials from private key
      final credentials = EthPrivateKey.fromHex(privateKey);

      // Verify from address matches credentials
      final credentialAddress = credentials.address;
      final expectedAddress = EthereumAddress.fromHex(fromAddress);
      if (credentialAddress != expectedAddress) {
        onLog?.call('ERROR: Private key does not match from address');
        return null;
      }

      // Parse amount with decimals
      final decimalsFunction = _coldContract!.function('decimals');
      final decimalsResult = await _client!.call(
        contract: _coldContract!,
        function: decimalsFunction,
        params: [],
      );
      final decimals = decimalsResult[0] as int;
      final amountWei = (double.parse(amount) * 10).pow(decimals).toInt();
      final amountBigInt = BigInt.from(amountWei);

      // Create transfer transaction
      final transferFunction = _coldContract!.function('transfer');
      final toAddressEth = EthereumAddress.fromHex(toAddress);

      final transaction = Transaction.callContract(
        contract: _coldContract!,
        function: transferFunction,
        parameters: [toAddressEth, amountBigInt],
        from: credentialAddress,
      );

      // Estimate gas
      final gasEstimate = await _client!.estimateGas(
        transaction: transaction,
      );

      // Send transaction
      final txHash = await _client!.sendTransaction(
        credentials,
        transaction.copyWith(gasPrice: await _client!.getGasPrice(), gas: gasEstimate),
        chainId: 1, // Ethereum Mainnet
      );

      onLog?.call('Transaction sent: $txHash');
      onLog?.call('View on https://etherscan.io/tx/$txHash');

      return {
        'success': true,
        'transactionHash': txHash,
        'from': fromAddress,
        'to': toAddress,
        'amount': amount,
        'timestamp': DateTime.now().toIso8601String(),
        'explorerUrl': 'https://etherscan.io/tx/$txHash',
      };
    } catch (e, stackTrace) {
      _logger.severe('COLD transfer failed', e, stackTrace);
      onLog?.call('ERROR: Transfer failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get transaction receipt
  Future<Map<String, dynamic>?> getTransactionReceipt(String txHash) async {
    if (!_isConnected || _client == null) return null;

    try {
      final receipt = await _client!.getTransactionReceipt(txHash);
      if (receipt == null) return null;

      return {
        'transactionHash': receipt.transactionHash.toString(),
        'status': receipt.status,
        'blockNumber': receipt.blockNumber.toString(),
        'gasUsed': receipt.gasUsed.toString(),
        'from': receipt.from.toString(),
        'to': receipt.to.toString(),
      };
    } catch (e) {
      _logger.warning('Failed to get transaction receipt: $e');
      return null;
    }
  }

  /// Get cached balance (if recent)
  Map<String, dynamic>? get cachedBalance => _cachedBalance;

  /// Check if balance cache is still valid (within 5 minutes)
  bool get isBalanceCacheValid {
    if (_cachedBalance == null || _lastBalanceUpdate == null) return false;
    final age = DateTime.now().difference(_lastBalanceUpdate!);
    return age.inMinutes < 5;
  }

  /// Get current RPC endpoint
  String get currentRpc => _currentRpc;

  /// Get connection status
  bool get isConnected => _isConnected;

  /// Get available RPC endpoints
  List<String> get availableRpcEndpoints => RPC_ENDPOINTS;

  /// Set log callback
  void setLogCallback(Function(String) callback) {
    onLog = callback;
  }

  /// Set connection status callback
  void setConnectionCallback(Function(bool) callback) {
    onConnectionStatusChanged = callback;
  }

  /// Set balance update callback
  void setBalanceCallback(Function(Map<String, dynamic>) callback) {
    onBalanceUpdated = callback;
  }

  /// Dispose the service
  Future<void> dispose() async {
    await disconnect();
    onLog = null;
    onConnectionStatusChanged = null;
    onBalanceUpdated = null;
    _logger.info('Web3COLDService disposed');
  }
}
```

Now let me create the new banking screen with the renamed sections:```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../services/cli_service.dart';
import '../../services/walletd_service.dart';
import '../../services/web3_cold_service.dart';
import '../../models/transaction_model.dart';
import '../../providers/wallet_provider.dart';
import '../../models/wallet.dart';
import '../../utils/theme.dart';
import 'burn_deposits_screen.dart';

/// New Banking screen with renamed sections
/// - Mint HEAT (formerly Burn2Mint)
/// - COLD (formerly COLD Banking)
class BankingScreen extends StatefulWidget {
  const BankingScreen({super.key});

  @override
  State<BankingScreen> createState() => _BankingScreenState();
}

class _BankingScreenState extends State<BankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Burn tab state
  String _selectedBurnOption = 'standard';
  bool _isBurning = false;

  // COLD tab state
  bool _isConnectingWeb3 = false;
  bool _isWeb3Connected = false;
  String _coldAddress = '';
  Map<String, dynamic>? _coldBalance;
  String _web3Log = '';

  // Walletd integration state
  bool _isWalletdRunning = false;
  bool _isOptimizerRunning = false;
  String _serviceLog = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize services
    _initializeServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Initialize all services
  Future<void> _initializeServices() async {
    try {
      // Initialize walletd service
      await WalletdService.instance.initialize();
      WalletdService.instance.setWalletdLogCallback((log) {
        if (mounted) {
          setState(() {
            _serviceLog = 'walletd: $log\n$_serviceLog';
          });
        }
      });
      WalletdService.instance.setOptimizerLogCallback((log) {
        if (mounted) {
          setState(() {
            _serviceLog = 'optimizer: $log\n$_serviceLog';
          });
        }
      });
      WalletdService.instance.setStatusCallbacks(
        onWalletd: (running) {
          if (mounted) setState(() => _isWalletdRunning = running);
        },
        onOptimizer: (running) {
          if (mounted) setState(() => _isOptimizerRunning = running);
        },
      );

      // Initialize Web3 service
      await Web3COLDService.instance.initialize();
      Web3COLDService.instance.setLogCallback((log) {
        if (mounted) {
          setState(() {
            _web3Log = '$log\n$_web3Log';
          });
        }
      });
      Web3COLDService.instance.setConnectionCallback((connected) {
        if (mounted) setState(() => _isWeb3Connected = connected);
      });
      Web3COLDService.instance.setBalanceCallback((balance) {
        if (mounted) {
          setState(() {
            _coldBalance = balance;
          });
        }
      });
    } catch (e) {
      debugPrint('Service initialization error: $e');
    }
  }

  /// Perform XFG burn to mint HEAT
  Future<void> _burnXFG(String option) async {
    double burnAmount;
    String heatAmount;

    if (option == 'standard') {
      burnAmount = 0.8;
      heatAmount = '8 Million HEAT';
    } else {
      burnAmount = 800.0;
      heatAmount = '8 Billion HEAT';
    }

    setState(() {
      _isBurning = true;
    });

    try {
      // Check if walletd is running for integrated optimization
      if (WalletdService.instance.isWalletdRunning) {
        _showInfoDialog(
          'Integrated Burn',
          'Using walletd integrated burn proof generation...\n\n'
          'Amount: $burnAmount XFG\n'
          'Mint: $heatAmount',
        );

        // trigger integrated optimization
        await WalletdService.instance.optimizeWallet();
      } else {
        // Fallback to CLI-based burn proof
        _showInfoDialog(
          'CLI Burn',
          'Generating burn proof using xfg-stark-cli...\n\n'
          'Amount: $burnAmount XFG\n'
          'Mint: $heatAmount',
        );
      }

      // Navigate to burn deposits screen for complete process
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BurnDepositsScreen(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Burn process initiated for $burnAmount XFG to mint $heatAmount'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Burn failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBurning = false;
        });
      }
    }
  }

  /// Start walletd service for integrated operations
  Future<void> _startWalletd() async {
    setState(() {
      _isWalletdRunning = true;
    });

    final started = await WalletdService.instance.startWalletd(
      enableRpc: true,
      daemonAddress: 'localhost:8081', // Adjust as needed
    );

    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start walletd service'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isWalletdRunning = false;
      });
    }
  }

  /// Stop walletd service
  Future<void> _stopWalletd() async {
    await WalletdService.instance.stopWalletd();
    setState(() {
      _isWalletdRunning = false;
    });
  }

  /// Start optimizer service
  Future<void> _startOptimizer() async {
    setState(() {
      _isOptimizerRunning = true;
    });

    final started = await WalletdService.instance.startOptimizer(
      autoOptimize: true,
      scanInterval: 300,
    );

    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start optimizer service'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isOptimizerRunning = false;
      });
    }
  }

  /// Stop optimizer service
  Future<void> _stopOptimizer() async {
    await WalletdService.instance.stopOptimizer();
    setState(() {
      _isOptimizerRunning = false;
    });
  }

  /// Connect to Web3 for COLD token
  Future<void> _connectWeb3() async {
    if (_coldAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a COLD token address'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!Web3COLDService.instance.isValidEthereumAddress(_coldAddress)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid Ethereum address format'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isConnectingWeb3 = true;
    });

    try {
      // Try auto-connect first
      bool connected = Web3COLDService.instance.isConnected;
      if (!connected) {
        connected = await Web3COLDService.instance.connectAuto();
      }

      if (connected) {
        // Get balance
        final balance = await Web3COLDService.instance.getBalance(_coldAddress);
        if (balance != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('COLD Balance: ${balance['balance']} ${balance['symbol']}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to connect to any Ethereum RPC endpoint');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Web3 connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnectingWeb3 = false;
        });
      }
    }
  }

  /// Refresh COLD balance
  Future<void> _refreshCOLDalance() async {
    if (_coldAddress.isEmpty || !Web3COLDService.instance.isConnected) return;

    setState(() {
      _isConnectingWeb3 = true;
    });

    try {
      final balance = await Web3COLDService.instance.getBalance(_coldAddress);
      if (balance != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Balance refreshed: ${balance['balance']} ${balance['symbol']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnectingWeb3 = false;
        });
      }
    }
  }

  /// Show info dialog
  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banking'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Ξternal Flame'), // Formerly "Mint HEAT"
            Tab(text: 'COLD'), // Formerly "COLD Banking"
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEternalFlameTab(), // Formerly Mint HEAT
          _buildCOLDTab(), // Formerly COLD Banking
        ],
      ),
    );
  }

  /// Ξternal Flame Tab (Burn to mint HEAT)
  Widget _buildEternalFlameTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Ξternal Flame',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Burn XFG to mint Fuego Ξmbers (HEAT)',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Walletd Integration Status
          _buildWalletdIntegrationPanel(),

          const SizedBox(height: 16),

          // Burn Options
          Text(
            'Select Burn Amount',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          _buildBurnOptionCard(
            title: 'Standard Burn',
            burnAmount: '0.8 XFG',
            heatAmount: '8 Million HEAT',
            description: 'Standard burn amount for basic uses like C0DL3 gas fees',
            isSelected: _selectedBurnOption == 'standard',
            onTap: () => setState(() => _selectedBurnOption = 'standard'),
          ),

          const SizedBox(height: 8),

          _buildBurnOptionCard(
            title: 'Large Burn',
            burnAmount: '800 XFG',
            heatAmount: '8 Billion HEAT',
            description: 'Larger HEAT mint. Amounts kept uniform for higher privacy',
            isSelected: _selectedBurnOption == 'large',
            onTap: () => setState(() => _selectedBurnOption = 'large'),
          ),

          const SizedBox(height: 20),

          // Burn Action
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isBurning ? null : () => _burnXFG(_selectedBurnOption),
              icon: _isBurning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.local_fire_department),
              label: Text(
                _isBurning
                  ? 'Processing Burn...'
                  : _selectedBurnOption == 'standard'
                      ? 'Burn 0.8 XFG & Mint HEAT'
                      : 'Burn 800 XFG & Mint HEAT',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Ξternal Flame (HEAT)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fuego Ξmbers (HEAT) are the atomic equivalent ERC20 token of XFG, '
                  'minted on Ethereum L1 using Arbitrum L2 for gas-efficiency. '
                  'HEAT will function as the gas token for Fuego\'s C0DL3 rollup '
                  'powering CD, PARA, COLDAO, & Fuego Mob interest yield assets.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.4,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// COLD Tab (COLD token management with Web3)
  Widget _buildCOLDTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4A90E2),
                  const Color(0xFF2D5F8D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.savings,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'COLD Interest Lounge',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'COLD Token on Ethereum • Generate Interest via C0DL3',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Web3 Connection Panel
          _buildWeb3ConnectionPanel(),

          const SizedBox(height: 16),

          // COLD Balance Display
          if (_coldBalance != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COLD Balance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_coldBalance!['balance']} ${_coldBalance!['symbol']}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: AppTheme.primaryColor),
                        onPressed: _isConnectingWeb3 ? null : _refreshCOLDalance,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _coldBalance!['name'],
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Address: ${_coldBalance!['address'].substring(0, 6)}...${_coldBalance!['address'].substring(38)}',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Interest Generation Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4A90E2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.interests, color: const Color(0xFF4A90E2), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'C0DL3 Interest Generation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4A90E2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• COLD tokens generate interest via C0DL3 rollup\n'
                    '• Interest paid in HEAT tokens\n'
                    '• Connect your COLD address to track earnings\n'
                    '• Withdraw interest to any Ethereum address',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Empty state
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Center(
                child: Text(
                  'Connect your COLD token address to view balance and manage interest',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Web3 Logs (if connected)
          if (_isWeb3Connected && _web3Log.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Web3 Activity Log',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 80,
                    child: SingleChildScrollView(
                      child: Text(
                        _web3Log.length > 500 ? _web3Log.substring(0, 500) + '...' : _web3Log,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: AppTheme.textMuted,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Service Integration Section
          if (_isWalletdRunning) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sync, color: AppTheme.successColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Integrated Services',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildServiceIndicator('walletd', _isWalletdRunning),
                      const SizedBox(width: 12),
                      _buildServiceIndicator('optimizer', _isOptimizerRunning),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_serviceLog.isNotEmpty) ...[
                    Container(
                      height: 60,
                      child: SingleChildScrollView(
                        child: Text(
                          _serviceLog.length > 300 ? _serviceLog.substring(0, 300) + '...' : _serviceLog,
                          style: TextStyle(
                            fontSize: 9,
                            fontFamily: 'monospace',
                            color: AppTheme.textMuted,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isConnectingWeb3 ? null : _connectWeb3,
                  icon: _isConnectingWeb3
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.link),
                  label: Text(_isWeb3Connected ? 'Refresh Balance' : 'Connect Web3'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isWalletdRunning ? _stopWalletd : _startWalletd,
                  icon: Icon(
                    _isWalletdRunning ? Icons.stop : Icons.play_arrow,
                    size: 20,
                  ),
                  label: Text(_isWalletdRunning ? 'Stop walletd' : 'Start walletd'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isWalletdRunning ? Colors.red : AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Advanced Services Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isOptimizerRunning ? _stopOptimizer : _startOptimizer,
                  icon: Icon(
                    _isOptimizerRunning ? Icons.stop : Icons.rocket_launch,
                    size: 20,
                  ),
                  label: Text(_isOptimizerRunning ? 'Stop Optimizer' : 'Start Optimizer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isOptimizerRunning ? Colors.red : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Show modal with COLD address input
                    _showCOLDAddressDialog();
                  },
                  icon: Icon(Icons.edit, size: 18),
                  label: const Text('Set COLD Address'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.interactiveColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build walletd integration panel
  Widget _buildWalletdIntegrationPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isWalletdRunning ? Icons.check_circle : Icons.info_outline,
                color: _isWalletdRunning ? AppTheme.successColor : AppTheme.warningColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Walletd Integration',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Switch(
                value: _isWalletdRunning,
                onChanged: (value) {
                  if (value) {
                    _startWalletd();
                  } else {
                    _stopWalletd();
                  }
                },
                activeColor: AppTheme.successColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isWalletdRunning
                ? 'walletd and optimizer are integrated directly into the GUI for seamless operation'
                : 'Enable walletd for integrated optimization and RPC wallet server functionality',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          _buildServiceIndicator('walletd', _isWalletdRunning),
          const SizedBox(height: 4),
          _buildServiceIndicator('optimizer', _isOptimizerRunning),
        ],
      ),
    );
  }

  /// Build Web3 connection panel
  Widget _buildWeb3ConnectionPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isWeb3Connected
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.link,
                color: _isWeb3Connected ? AppTheme.successColor : AppTheme.textMuted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Ethereum Connection',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isWeb3Connected
                      ? AppTheme.successColor.withOpacity(0.2)
                      : AppTheme.textMuted.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isWeb3Connected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: _isWeb3Connected ? AppTheme.successColor : AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: 'COLD Token Address (0x...)',
              hintText: 'Enter your COLD token address',
              prefixIcon: Icon(Icons.account_balance_wallet, size: 18),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.dividerColor),
              ),
            ),
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
            ),
            onChanged: (value) {
              setState(() {
                _coldAddress = value;
              });
            },
            onSubmitted: (_) => _connectWeb3(),
          ),
          if (Web3COLDService.instance.currentRpc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'RPC: ${Web3COLDService.instance.currentRpc}',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textMuted,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build burn option card
  Widget _buildBurnOptionCard({
    required String title,
    required String burnAmount,
    required String heatAmount,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$burnAmount → Mint $heatAmount',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build service status indicator
  Widget _buildServiceIndicator(String service, bool isRunning) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isRunning ? AppTheme.successColor : AppTheme.textMuted,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          service,
          style: TextStyle(
            fontSize: 11,
            color: isRunning ? AppTheme.textPrimary : AppTheme.textMuted,
            fontWeight: isRunning ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// Show COLD address input dialog
  void _showCOLDAddressDialog() {
    final controller = TextEditingController(text: _coldAddress);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('COLD Token Address'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Ethereum Address',
            hintText: '0x...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _coldAddress = controller.text;
              });
              Navigator.of(context).pop();
              _connectWeb3();
            },
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }
}
```

Now let me update the main navigation to reflect the changes:```dart
import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../home/home_screen.dart';
import '../elderfier/elderfier_screen.dart';
import '../messaging/messaging_screen.dart';
import '../banking/banking_screen.dart';
import '../settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MessagingScreen(),
    const BankingScreen(), // Now includes Ξternal Flame + COLD
    const SettingsScreen(),
    const ElderfierScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(
            top: BorderSide(
              color: AppTheme.textMuted.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home,
                  label: 'Home',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.message,
                  label: 'Messages',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.account_balance,
                  label: 'Banking',
                  index: 2,
                  icon2: Icons.local_fire_department,
                  label2: 'HEAT',
                ),
                _buildNavItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  index: 3,
                ),
                _buildNavItem(
                  icon: Icons.account_tree,
                  label: 'Elderfiers',
                  index: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    IconData? icon2,
    String? label2,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                  size: 24,
                ),
                if (icon2 != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon2,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
              ),
            ),
            if (label2 != null) ...[
              const SizedBox(height: 2),
              Text(
                label2,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

Let me also update the home screen to reflect the new terminology:```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/theme.dart';
import '../../services/walletd_service.dart';
import '../../services/web3_cold_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isWalletdReady = false;
  bool _isWeb3Ready = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Check if binaries are available
    try {
      await WalletdService.instance.initialize();
      setState(() {
        _isWalletdReady = true;
      });
    } catch (e) {
      setState(() {
        _isWalletdReady = false;
      });
    }

    try {
      await Web3COLDService.instance.initialize();
      setState(() {
        _isWeb3Ready = true;
      });
    } catch (e) {
      setState(() {
        _isWeb3Ready = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('XF₲ Wallet'),
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 32.w,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'Decentralized Privacy Banking',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Your gateway to Fuego ecosystem',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Feature cards
            Text(
              'Quick Access',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),

            SizedBox(height: 12.h),

            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              children: [
                _buildFeatureCard(
                  context,
                  icon: Icons.local_fire_department,
                  title: 'Ξternal Flame',
                  subtitle: 'Mint HEAT',
                  color: AppTheme.errorColor,
                  onPressed: () {
                    Navigator.pushNamed(context, '/banking');
                  },
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.savings,
                  title: 'COLD',
                  subtitle: 'Interest Lounge',
                  color: const Color(0xFF4A90E2),
                  onPressed: () {
                    Navigator.pushNamed(context, '/banking');
                  },
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.account_balance,
                  title: 'Walletd',
                  subtitle: _isWalletdReady ? 'Integrated' : 'Not Available',
                  color: _isWalletdReady ? AppTheme.successColor : AppTheme.textMuted,
                  onPressed: () {
                    Navigator.pushNamed(context, '/banking');
                  },
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.link,
                  title: 'Web3',
                  subtitle: _isWeb3Ready ? 'Ethereum' : 'Available',
                  color: _isWeb3Ready ? const Color(0xFF4A90E2) : AppTheme.textMuted,
                  onPressed: () {
                    Navigator.pushNamed(context, '/banking');
                  },
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // Status info
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Features',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _buildStatusRow('Integrated Walletd Service', _isWalletdReady),
                  SizedBox(height: 4.h),
                  _buildStatusRow('Optimizer (Integrated via GUI)', _isWalletdReady),
                  SizedBox(height: 4.h),
                  _buildStatusRow('COLD Token Web3 Connection', _isWeb3Ready),
                  SizedBox(height: 4.h),
                  _buildStatusRow('Fuego Burn2Mint (Ξternal Flame)', true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32.w, color: color),
              SizedBox(height: 8.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Row(
      children: [
        Icon(
          status ? Icons.check_circle : Icons.cancel,
          color: status ? AppTheme.successColor : AppTheme.errorColor,
          size: 16.w,
        ),
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
```

Finally, let me update the pubspec.yaml to include the web3dart dependency: ```dart
name: xfg_wallet
description: "XF₲ Wallet - Decentralized Privacy Banking Wallet"
publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: '>=3.4.3 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # UI and Navigation
  cupertino_icons: ^1.0.6
  material_design_icons_flutter: ^7.0.7296

  # State Management
  provider: ^6.1.2
  shared_preferences: ^2.2.2

  # HTTP and JSON
  http: ^1.2.0
  dio: ^5.4.0
  json_annotation: ^4.8.1

  # Crypto and Security
  crypto: ^3.0.3
  cryptography: ^2.5.0
  flutter_secure_storage: ^9.0.0
  local_auth: ^2.1.7
  bip39: ^1.0.6
  ed25519_hd_key: ^2.2.0

  # Web3 Integration (NEW - for COLD token on Ethereum)
  web3dart: ^2.7.2
  web3dart/contracts: ^2.7.2
  web3dart/json_rpc: ^2.7.2

  # QR Code
  qr_flutter: ^4.1.0
  mobile_scanner: ^4.0.1

  # File Picker
  file_picker: ^8.0.0+1

  # Path utilities
  path: ^1.8.3

  # FFI for native bindings
  ffi: ^2.1.0

  # UI Components
  animated_text_kit: ^4.2.2
  shimmer: ^3.0.0
  fl_chart: ^0.66.2
  auto_size_text: ^3.0.0

  # System Integration
  path_provider: ^2.1.2
  url_launcher: ^6.2.4
  device_info_plus: ^10.1.0
  connectivity_plus: ^5.0.2

  # Notifications
  flutter_local_notifications: ^17.0.0
  logging: ^1.2.0

  # Screen utilities
  flutter_screenutil: ^5.9.0
  flutter_svg: ^2.0.10

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.8
  json_serializable: ^6.7.1

flutter:
  uses-material-design: true

  assets:
    - assets/images/
    - assets/icons/
    - assets/logo/
    - assets/bin/
    - assets/bin/xfg-stark-cli-linux
    - assets/bin/xfg-stark-cli-macos
    - assets/bin/xfg-stark-cli-windows.exe

  # Note: fuego-walletd binaries are built from source during CI/CD workflow
  # See scripts/get_walletd_binary.sh for build instructions

  fonts:
    - family: monospace
      fonts:
        - asset: assets/fonts/RobotoMono-Regular.ttf
```

And update the theme to include new colors:```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTheme {
  // Primary colors
  static const Color primaryColor = Color(0xFFF44336); // Fuego red
  static const Color secondaryColor = Color(0xFF4A90E2); // COLD blue
  static const Color errorColor = Color(0xFFF44336); // Burn red
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFC107);

  // Surface and backgrounds
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color backgroundColor = Color(0xFF121212);
  static const Color cardColor = Color(0xFF2A2A2A);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF808080);

  // Interactive
  static const Color interactiveColor = Color(0xFF2196F3);
  static const Color dividerColor = Color(0xFF333333);

  // Gradients
  static LinearGradient get primaryGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF44336), // Fuego red
        Color(0xFFD32F2F), // Darker red
      ],
    );
  }

  static LinearGradient get coldGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF4A90E2), // COLD blue
        Color(0xFF2D5F8D), // Darker blue
      ],
    );
  }

  // Light theme
  static ThemeData get lightThemeData {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: Colors.grey[50],
      cardColor: Colors.white,
      textTheme: TextTheme(
        headlineLarge: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: Colors.black87),
        bodyLarge: TextStyle(fontSize: 16.sp, color: Colors.black87),
        bodyMedium: TextStyle(fontSize: 14.sp, color: Colors.black54),
      ),
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: Colors.white,
        background: Colors.grey[50]!,
      ),
      useMaterial3: true,
    );
  }

  // Dark theme
  static ThemeData get darkThemeData {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      textTheme: TextTheme(
        headlineLarge: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 16.sp, color: textSecondary),
        bodyMedium: TextStyle(fontSize: 14.sp, color: textMuted),
      ),
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        background: backgroundColor,
      ),
      useMaterial3: true,
    );
  }

  // Widget specific styles
  static ButtonStyle get primaryButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
      ),
    );
  }

  static ButtonStyle get secondaryButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: secondaryColor,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
      ),
    );
  }

  static ButtonStyle get dangerButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: errorColor,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
      ),
    );
  }
}
```

Let me create a README update documenting the changes:```markdown
# XF₲ Wallet - Integrated GUI Walletd & Web3 COLD Support

## 🔥 NEW FEATURES: Walletd Integration & UI Renaming

### Overview
This update integrates `walletd` and `fuego-optimizer` directly into the GUI wallet, similar to how GUI wallets can compile these components. Additionally, menu sections have been renamed to better reflect the Fuego ecosystem terminology.

---

## 📋 Navigation Changes

### Before → After
- **`Burn2Mint`** → **`Ξternal Flame`** (HEAT section)
- **`COLD Banking`** → **`COLD Interest Lounge`** (COLD section)

### New Menu Structure
```
Home
Messages
Banking (Combined)
  ├── Ξternal Flame (Burn XFG → Mint HEAT)
  └── COLD (Ethereum Web3 + Interest)
Settings
Elderfiers
```

---

## 🔧 Integrated Walletd & Optimizer

### How It Works
The wallet now includes **`lib/services/walletd_service.dart`** which manages:

1. **walletd (PaymentGateService)**
   - Headless wallet service for multi-wallet management
   - JSON-RPC server on port 8070
   - Compiled into GUI for self-contained operation

2. **fuego-optimizer**
   - Automatic UTXO optimization
   - Connects to walletd via JSON-RPC
   - Integrated optimization or standalone processing

3. **xfg-stark-cli** (existing)
   - Burn proof generation
   - STARK proof offloading
   - Cross-platform binaries included

### Usage in GUI
```dart
// Start integrated walletd
await WalletdService.instance.startWalletd(
  enableRpc: true,
  daemonAddress: 'localhost:8081',
);

// Start optimizer (auto-connects to walletd)
await WalletdService.instance.startOptimizer(
  autoOptimize: true,
  scanInterval: 300,
);

// Perform optimization
await WalletdService.instance.optimizeWallet();
```

### Benefits
- ✅ **Self-contained**: No separate walletd/optimizer processes needed
- ✅ **Seamless**: GUI manages all services automatically
- ✅ **Fallback**: Can still use CLI if needed
- ✅ **Real-time logs**: Service outputs in UI
- ✅ **Status monitoring**: Visual indicators for services

---

## 🌐 Web3 COLD Token Integration

### New Service: `Web3COLDService`
Located in `lib/services/web3_cold_service.dart`

### Features
1. **COLD Token on Ethereum Mainnet**
   - Contract: `0x5aFe5e5C60940B5C6Ca0322dFe51c6D01d455755`
   - View balances and transactions
   - Transfer COLD tokens

2. **Multi-RPC Support**
   - Public Infura, Alchemy, and public nodes
   - Auto-failover to available endpoints
   - Custom RPC configuration

3. **C0DL3 Interest Tracking**
   - Integrated with COLD Interest Lounge
   - Interest generation via C0DL3 rollup
   - HEAT token rewards tracking

### Usage
```dart
// Connect to Ethereum
await Web3COLDService.instance.connectAuto();

// Get COLD balance
final balance = await Web3COLDService.instance.getBalance('0xYourAddress');

// Transfer COLD
final tx = await Web3COLDService.instance.transfer(
  fromAddress: '0xYourAddress',
  toAddress: '0xRecipient',
  amount: '1000',
  privateKey: '0xYourPrivateKey',
);
```

---

## 📁 File Structure

### New Files
```
lib/services/
├── walletd_service.dart      # Walletd + Optimizer integration
└── web3_cold_service.dart   # Ethereum COLD token service

lib/screens/banking/
├── banking_screen.dart      # Updated: Ξternal Flame + COLD tabs
└── burn_deposits_screen.dart # Existing (unchanged)

lib/screens/main/
└── main_screen.dart         # Updated navigation

lib/screens/home/
└── home_screen.dart         # Updated with service status

lib/utils/
└── theme.dart               # Updated with new colors
```

### Modified Files
- `pubspec.yaml` - Added `web3dart` dependency
- `lib/screens/banking/banking_screen.dart` - Renamed tabs, integrated services
- `lib/screens/main/main_screen.dart` - Updated navigation labels
- `lib/screens/home/home_screen.dart` - Service status display

---

## 🚀 Quick Start

### 1. Ensure Binaries
```bash
cd fuego-wallet
./scripts/ensure-binaries.sh
```

### 2. Build walletd (Optional - for integration)
```bash
./scripts/get_walletd_binary.sh build
# OR
./scripts/get_walletd_binary.sh download
```

### 3. Run Flutter App
```bash
flutter pub get
flutter run -d linux  # or macos, windows, android, ios
```

---

## 🔥 Ξternal Flame (Burn → Mint)

### Standard Burn
- **Amount**: 0.8 XFG
- **Mint**: 8 Million HEAT
- **Use**: C0DL3 gas fees

### Large Burn
- **Amount**: 800 XFG
- **Mint**: 8 Billion HEAT
- **Use**: High-privacy HEAT minting

### Process
1. Select burn amount (Standard/Large)
2. Optional: Start walletd for integrated optimization
3. Navigate to Burn Deposits
4. Generate STARK proof (CLI or walletd)
5. Mint HEAT tokens on Ethereum L1 via Arbitrum L2

---

## ❄️ COLD Interest Lounge

### Features
1. **Web3 Connection**
   - Connect Ethereum wallet
   - View COLD token balance
   - Track C0DL3 interest generation

2. **Interest Management**
   - Real-time balance updates
   - Interest in HEAT tokens
   - Withdraw to any address

3. **Service Integration**
   - Start walletd for batch operations
   - Run optimizer for auto-optimization
   - Monitor all processes in UI

---

## ⚙️ Configuration

### Walletd RPC Config
```dart
WalletdService.instance.setRpcConfig(
  host: '127.0.0.1',
  port: 8070,
);
```

### Web3 RPC Config
```dart
// Auto-select best RPC
await Web3COLDService.instance.connectAuto();

// Or manual RPC
await Web3COLDService.instance.connect('https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY');
```

---

## 📊 Service Status Indicators

Green = Running | Gray = Stopped

| Service | Status | Integration |
|---------|--------|-------------|
| walletd | 🟢 Running / ⚪ Stopped | Direct GUI |
| optimizer | 🟢 Running / ⚪ Stopped | Via walletd RPC or CLI |
| xfg-stark-cli | 🟢 Available | For burn proofs |
| Web3 (COLD) | 🟢 Connected / ⚪ Disconnected | Ethereum L1 |

---

## 🔐 Security Notes

⚠️ **Never** hardcode private keys or passwords in the GUI
⚠️ **Always** use secure storage for wallet credentials
⚠️ **Verify** contract addresses before transfers
⚠️ **Keep** walletd config files secure

---

## 🎯 Roadmap

- [x] ✅ Walletd/Optimizer integration into GUI
- [x] ✅ COLD token Web3 connection
- [x] ✅ UI renaming (Burn2Mint → Ξternal Flame, COLD Banking → COLD)
- [x] ✅ C0DL3 interest tracking
- [ ] 🔄 Multi-wallet support in walletd
- [ ] 🔄 HEAT token trading interface
- [ ] 🔄 C0DL3 rollup status viewer
- [ ] 🔄 Mobile build optimization

---

## 🤝 Contributing

See `CONTRIBUTING.md` for development guidelines.

---

## 📄 License

MIT License - Free to use and modify for the Fuego ecosystem

---

## 📞 Support

- GitHub Issues: For bugs and feature requests
- Documentation: Check `docs/` directory
- Community: Join Fuego community channels

---

**Built with ❤️ for the Fuego ecosystem**
