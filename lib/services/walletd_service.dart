import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
