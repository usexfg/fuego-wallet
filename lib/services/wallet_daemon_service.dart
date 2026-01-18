// Copyright (c) 2025 Fuego Developers
// Copyright (c) 2025 Elderfire Privacy Group

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/network_config.dart';

class WalletDaemonService {
  static Process? _walletdProcess;
  static bool _isRunning = false;
  static NetworkConfig _networkConfig = NetworkConfig.mainnet;
  static String? _walletdPath;
  static String? _walletPath;
  static String? _daemonAddress;
  static int? _daemonPort;

  /// Initialize the wallet daemon service
  static Future<void> initialize({
    required String daemonAddress,
    required int daemonPort,
    String? walletPath,
    NetworkConfig? networkConfig,
  }) async {
    _daemonAddress = daemonAddress;
    _daemonPort = daemonPort;
    _walletPath = walletPath;
    _networkConfig = networkConfig ?? NetworkConfig.mainnet;

    // Extract walletd binary
    _walletdPath = await _extractWalletdBinary();

    debugPrint('WalletDaemonService initialized');
    debugPrint('Network: ${_networkConfig.name}');
    debugPrint('Daemon: $_daemonAddress:$_daemonPort');
    debugPrint('Walletd port: ${_networkConfig.walletRpcPort}');
    debugPrint('Walletd binary: $_walletdPath');
    debugPrint('Wallet path: $_walletPath');
  }

  /// Extract the walletd binary from assets
  static Future<String> _extractWalletdBinary() async {
    final Directory tempDir = await getTemporaryDirectory();
    // Check what binaries are actually available
    String binaryName;
    if (Platform.isWindows) {
      binaryName = 'fuego-walletd-windows.exe';
    } else if (Platform.isMacOS) {
      // Check if macOS binary exists, fallback to linux if not
      try {
        await rootBundle.load('assets/bin/fuego-walletd-macos');
        binaryName = 'fuego-walletd-macos';
      } catch (e) {
        debugPrint('macOS binary not found, using linux binary as fallback');
        binaryName = 'fuego-walletd-linux';
      }
    } else {
      binaryName = 'fuego-walletd-linux';
    }

    final File binaryFile = File(path.join(tempDir.path, 'fuego-walletd'));

    try {
      // Extract from assets if not already extracted
      if (!await binaryFile.exists()) {
        await binaryFile.create(recursive: true);
        await binaryFile.writeAsBytes(
          await rootBundle.load('assets/bin/$binaryName').then((data) => data.buffer.asUint8List())
        );
      }

      // Set executable permissions for non-Windows platforms
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', binaryFile.path]);
      }

      return binaryFile.path;
    } catch (e) {
      debugPrint('Failed to extract walletd binary: $e');

      // If we can't extract the binary, try to find system installed version
      final systemBinary = await _findSystemWalletd();
      if (systemBinary != null) {
        return systemBinary;
      }

      rethrow;
    }
  }

  /// Try to find walletd binary in system PATH
  static Future<String?> _findSystemWalletd() async {
    try {
      final result = await Process.run('which', ['fuego-walletd']);
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        debugPrint('Found system walletd at: $path');
        return path;
      }
    } catch (e) {
      debugPrint('Failed to find system walletd: $e');
    }
    return null;
  }

  /// Start the wallet daemon
  static Future<bool> startWalletd({
    String? walletPath,
    String? password,
  }) async {
    if (_isRunning) {
      debugPrint('Walletd is already running');
      return true;
    }

    if (_walletdPath == null) {
      debugPrint('WalletDaemonService not initialized - walletd path is null');
      return false;
    }

    try {
      // Validate password is not empty
      if (password != null && password.isEmpty) {
        debugPrint('Error: Empty password provided for wallet daemon');
        return false;
      }

      // Prepare command arguments based on fuego-walletd help
      final List<String> args = [
        '--daemon-address', '$_daemonAddress',
        '--daemon-port', '$_daemonPort',
        '--bind-port', '${_networkConfig.walletRpcPort}',
        '--log-level', '3', // Debug level for more output
      ];

      // Add wallet path if provided
      if (walletPath != null) {
        args.addAll(['--container-file', walletPath]);
      }

      // Add password if provided
      if (password != null) {
        args.addAll(['--container-password', password]);
      }

      debugPrint('Starting walletd with args: $args');
      debugPrint('Walletd binary path: $_walletdPath');

      // Start the process
      _walletdProcess = await Process.start(_walletdPath!, args);

      // Capture process ID immediately
      final pid = _walletdProcess!.pid;
      debugPrint('Walletd process started with PID: $pid');

      // Listen to stdout and stderr
      _walletdProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('Walletd stdout: $data');
      }, onError: (error) {
        debugPrint('Walletd stdout error: $error');
      });

      _walletdProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('Walletd stderr: $data');
      }, onError: (error) {
        debugPrint('Walletd stderr error: $error');
      });

      // Wait a moment for startup and capture any immediate output
      await Future.delayed(const Duration(seconds: 2));

      // Wait a bit more for full startup
      await Future.delayed(const Duration(seconds: 3));

      // Check if process is still running
      if (_walletdProcess != null && _walletdProcess!.pid > 0) {
        _isRunning = true;
        debugPrint('Walletd started successfully on port ${_networkConfig.walletRpcPort}');

        // Check if the process is still running after the delay
        try {
          final exitCode = await _walletdProcess!.exitCode.timeout(const Duration(milliseconds: 100), onTimeout: () => -1);
          if (exitCode != -1) {
            debugPrint('Walletd exited early with code: $exitCode');
            _isRunning = false;
            return false;
          }
        } catch (e) {
          // Process is still running, which is what we want
          debugPrint('Walletd process is still running as expected');
        }

        // Verify walletd is responding on its RPC port
        if (await _verifyWalletdConnection()) {
          debugPrint('Walletd RPC service is responding');
          return true;
        } else {
          debugPrint('Walletd started but RPC service is not responding');
          // Try to get more info about why it's not responding
          await _debugWalletdNotResponding();
          return false;
        }
      } else {
        debugPrint('Walletd failed to start or exited immediately');
        // Check exit code if available
        try {
          final exitCode = await _walletdProcess?.exitCode.timeout(const Duration(milliseconds: 100));
          debugPrint('Walletd exit code: $exitCode');
        } catch (e) {
          debugPrint('Could not get walletd exit code: $e');
        }
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('Error starting walletd: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Stop the wallet daemon
  static Future<void> stopWalletd() async {
    if (!_isRunning || _walletdProcess == null) {
      return;
    }

    try {
      _walletdProcess!.kill();
      await _walletdProcess!.exitCode;
      _walletdProcess = null;
      _isRunning = false;
      debugPrint('Walletd stopped');
    } catch (e) {
      debugPrint('Error stopping walletd: $e');
    }
  }

  /// Check if walletd is running
  static bool get isRunning => _isRunning;

  /// Get the walletd port
  static int get port => _networkConfig.walletRpcPort;

  /// Get the walletd URL
  static String get url => 'http://localhost:${_networkConfig.walletRpcPort}';

  /// Get current network configuration
  static NetworkConfig get networkConfig => _networkConfig;

  /// Restart walletd with new parameters
  static Future<bool> restartWalletd({
    String? walletPath,
    String? password,
  }) async {
    await stopWalletd();
    await Future.delayed(const Duration(seconds: 1));
    return await startWalletd(walletPath: walletPath, password: password);
  }

  /// Create a new wallet
  static Future<bool> createWallet({
    required String walletPath,
    required String password,
  }) async {
    if (_walletdPath == null) {
      debugPrint('WalletDaemonService not initialized - walletd path is null');
      return false;
    }

    try {
      // Ensure the directory exists and remove existing file if it exists
      final file = File(walletPath);
      if (await file.exists()) {
        debugPrint('Deleting existing wallet file: $walletPath');
        try {
          await file.delete();
          debugPrint('Successfully deleted existing wallet file: $walletPath');
        } catch (deleteError) {
          debugPrint('Failed to delete existing wallet file: $deleteError');
          // If we can't delete it, try a different approach
          final newPath = '${walletPath}_${DateTime.now().millisecondsSinceEpoch}';
          debugPrint('Using alternative path: $newPath');
          return await createWallet(walletPath: newPath, password: password);
        }
      }
      await file.create(recursive: true);

      final List<String> args = [
        '--daemon-address', '$_daemonAddress',
        '--daemon-port', '$_daemonPort',
        '--container-file', walletPath,
        '--container-password', password,
        '--generate-container',
      ];

      debugPrint('Creating wallet with args: $args');
      debugPrint('Walletd binary path: $_walletdPath');

      final ProcessResult result = await Process.run(_walletdPath!, args);

      debugPrint('Wallet creation process completed with exit code: ${result.exitCode}');
      if (result.stdout != null && result.stdout.toString().isNotEmpty) {
        debugPrint('Wallet creation stdout: ${result.stdout}');
      }
      if (result.stderr != null && result.stderr.toString().isNotEmpty) {
        debugPrint('Wallet creation stderr: ${result.stderr}');
        // Check for specific error messages
        final stderr = result.stderr.toString();
        if (stderr.contains('passCODE') || stderr.contains('password') || stderr.contains('Passcode')) {
          debugPrint('Wallet creation failed due to password/passcode issue');
        }
      }

      if (result.exitCode == 0) {
        debugPrint('Wallet created successfully at: $walletPath');
        return true;
      } else {
        debugPrint('Wallet creation failed with exit code: ${result.exitCode}');
        debugPrint('Wallet creation error: ${result.stderr}');
        // Check for specific error messages
        final stderr = result.stderr.toString();
        if (stderr.contains('MemoryMappedFile::create: File exists')) {
          debugPrint('Wallet creation failed due to file conflict. This should not happen after deletion.');
        }
        if (stderr.contains('passCODE') || stderr.contains('password') || stderr.contains('Passcode')) {
          debugPrint('Wallet creation failed due to password/passcode issue');
        }
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('Error creating wallet: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Open an existing wallet
  static Future<bool> openWallet({
    required String walletPath,
    required String password,
  }) async {
    return await startWalletd(
      walletPath: walletPath,
      password: password,
    );
  }

  /// Verify that walletd RPC service is responding
  static Future<bool> _verifyWalletdConnection() async {
    try {
      // Simple HTTP request to check if walletd RPC is responding
      final url = 'http://localhost:${_networkConfig.walletRpcPort}/json_rpc';
      debugPrint('Verifying walletd connection at: $url');

      // Give it a moment to start up
      await Future.delayed(const Duration(seconds: 2));

      // Try to connect with a short timeout
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('Content-Type', 'application/json');
      request.write(json.encode({
        'jsonrpc': '2.0',
        'id': 'connection_test',
        'method': 'get_status', // Simple method to test connection
      }));

      final response = await request.close();
      await response.drain();
      client.close();

      debugPrint('Walletd connection verification response code: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 404; // 404 might be ok if method doesn't exist
    } catch (e) {
      debugPrint('Walletd connection verification failed: $e');
      return false;
    }
  }

  /// Debug why walletd is not responding
  static Future<void> _debugWalletdNotResponding() async {
    debugPrint('Debugging walletd not responding issue...');

    try {
      // Check if the port is actually listening
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);

      try {
        final request = await client.get('localhost', _networkConfig.walletRpcPort, '/json_rpc');
        final response = await request.close();
        await response.drain();
        debugPrint('Port is listening, response status: ${response.statusCode}');
      } catch (portError) {
        debugPrint('Port not listening or connection failed: $portError');
      } finally {
        client.close();
      }

      // Check if process is still running
      if (_walletdProcess != null) {
        debugPrint('Walletd process PID: ${_walletdProcess!.pid}');
        // Try to get some info about the process
        try {
          final result = await Process.run('ps', ['-p', _walletdProcess!.pid.toString(), '-o', 'pid,ppid,cmd']);
          debugPrint('Process info:\n${result.stdout}');
        } catch (e) {
          debugPrint('Could not get process info: $e');
        }

      }
    } catch (e) {
      debugPrint('Debug error: $e');
    }
  }

  /// Check if wallet RPC service is available
  static Future<bool> isWalletRpcAvailable() async {
    try {
      final url = 'http://localhost:${_networkConfig.walletRpcPort}/json_rpc';
      debugPrint('Checking wallet RPC availability at: $url');

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);

      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('Content-Type', 'application/json');
      request.write(json.encode({
        'jsonrpc': '2.0',
        'id': 'availability_check',
        'method': 'get_status',
      }));

      final response = await request.close();
      await response.drain();
      client.close();

      debugPrint('Wallet RPC availability check result: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Wallet RPC availability check failed: $e');
      return false;
    }
  }
}
