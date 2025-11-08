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
    final String binaryName = Platform.isWindows
        ? 'fuego-walletd-windows.exe'
        : Platform.isMacOS
            ? 'fuego-walletd-macos'
            : 'fuego-walletd-linux';

    final File binaryFile = File(path.join(tempDir.path, 'fuego-walletd'));

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
      throw Exception('WalletDaemonService not initialized');
    }

    try {
      // Prepare command arguments
      final List<String> args = [
        '--daemon-address', '$_daemonAddress',
        '--daemon-port', '$_daemonPort.toString()',
        '--rpc-bind-port', '${_networkConfig.walletRpcPort}',
        '--log-level', '1', // Info level
        '--non-interactive',
      ];

      // Add wallet path if provided
      if (walletPath != null) {
        args.addAll(['--wallet-file', walletPath]);
      }

      // Add password if provided
      if (password != null) {
        args.addAll(['--password', password]);
      }

      debugPrint('Starting walletd with args: $args');

      // Start the process
      _walletdProcess = await Process.start(_walletdPath!, args);

      // Listen to stdout and stderr
      _walletdProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('Walletd stdout: $data');
      });

      _walletdProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('Walletd stderr: $data');
      });

      // Wait a moment for startup
      await Future.delayed(const Duration(seconds: 2));

      // Check if process is still running
      if (_walletdProcess!.exitCode == null) {
        _isRunning = true;
        debugPrint('Walletd started successfully on port ${_networkConfig.walletRpcPort}');
        return true;
      } else {
        debugPrint('Walletd failed to start');
        return false;
      }
    } catch (e) {
      debugPrint('Error starting walletd: $e');
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
      throw Exception('WalletDaemonService not initialized');
    }

    try {
      final List<String> args = [
        '--daemon-address', '$_daemonAddress',
        '--daemon-port', '$_daemonPort.toString()',
        '--wallet-file', walletPath,
        '--password', password,
        '--generate-new-wallet',
        '--non-interactive',
      ];

      debugPrint('Creating wallet with args: $args');

      final ProcessResult result = await Process.run(_walletdPath!, args);

      if (result.exitCode == 0) {
        debugPrint('Wallet created successfully');
        return true;
      } else {
        debugPrint('Wallet creation failed: ${result.stderr}');
        return false;
      }
    } catch (e) {
      debugPrint('Error creating wallet: $e');
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
}
