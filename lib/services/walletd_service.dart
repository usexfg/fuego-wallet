import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class WalletdService {
  Process? _process;
  String? _walletDir;
  String? _walletFile;
  bool _running = false;

  bool get isRunning => _running;
  int get rpcPort => 8070;

  Future<void> start({
    String daemonHost = '207.244.247.64',
    int daemonPort = 18180,
  }) async {
    if (_running) return;

    final binary = await _findBinary();
    if (binary == null) {
      throw Exception('walletd binary not found');
    }

    _walletDir = await _getWalletDir();
    _walletFile = p.join(_walletDir!, 'fuego_wallet');

    // Generate wallet if it doesn't exist
    if (!await File(_walletFile!).exists()) {
      await _generateWallet(binary);
    }

    // Start walletd
    debugPrint('WalletdService: starting $binary');
    _process = await Process.start(binary, [
      '--daemon-address', daemonHost,
      '--daemon-port', daemonPort.toString(),
      '--container-file', _walletFile!,
      '--container-password', 'fuego',
      '--bind-port', rpcPort.toString(),
      '--bind-address', '127.0.0.1',
      '--log-level', '1',
    ]);

    _process!.stdout.transform(utf8.decoder).listen((line) {
      if (line.contains('Started server')) {
        debugPrint('WalletdService: RPC server started on port $rpcPort');
      }
    });

    _process!.stderr.transform(utf8.decoder).listen((line) {
      debugPrint('WalletdService stderr: $line');
    });

    _process!.exitCode.then((code) {
      debugPrint('WalletdService: exited with code $code');
      _running = false;
    });

    _running = true;

    // Wait for RPC to be ready
    await _waitForReady();
    debugPrint('WalletdService: ready on port $rpcPort');
  }

  Future<void> stop() async {
    if (_process != null) {
      _process!.kill(ProcessSignal.sigterm);
      await _process!.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _process!.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      _process = null;
    }
    _running = false;
    debugPrint('WalletdService: stopped');
  }

  Future<void> _generateWallet(String binary) async {
    debugPrint('WalletdService: generating wallet at $_walletFile');
    final result = await Process.run(binary, [
      '--generate-container',
      '--container-file', _walletFile!,
      '--container-password', 'fuego',
      '--daemon-address', '127.0.0.1',
      '--daemon-port', '18180',
    ]);

    if (result.exitCode != 0) {
      throw Exception('Failed to generate wallet: ${result.stderr}');
    }
    debugPrint('WalletdService: wallet generated');
    debugPrint('WalletdService stdout: ${result.stdout}');
  }

  Future<String?> _findBinary() async {
    // Try app bundle Resources first (macOS .app)
    final appDir = await getApplicationSupportDirectory();
    final bundled = p.join(appDir.parent.path, 'Resources', 'bin', 'walletd');
    if (await File(bundled).exists()) return bundled;

    // Try macos/bin/ relative to project (dev mode)
    final devPath = p.join(Directory.current.path, 'macos', 'bin', 'walletd');
    if (await File(devPath).exists()) return devPath;

    // Try absolute dev path
    const absDev = '/Users/aejt/fuego-flutter-wallet/macos/bin/walletd';
    if (await File(absDev).exists()) return absDev;

    // Try PATH
    final which = await Process.run('which', ['walletd']);
    if (which.exitCode == 0) {
      return (which.stdout as String).trim();
    }

    return null;
  }

  Future<String> _getWalletDir() async {
    final dir = await getApplicationSupportDirectory();
    final walletDir = p.join(dir.path, 'wallet');
    await Directory(walletDir).create(recursive: true);
    return walletDir;
  }

  Future<void> _waitForReady({int maxAttempts = 30}) async {
    for (var i = 0; i < maxAttempts; i++) {
      try {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse('http://127.0.0.1:$rpcPort/status'));
        final resp = await req.close().timeout(const Duration(seconds: 2));
        await resp.drain();
        client.close();
        if (resp.statusCode == 200) return;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));
    }
    throw Exception('walletd failed to start within ${maxAttempts}s');
  }
}
