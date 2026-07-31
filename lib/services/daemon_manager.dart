import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Unified process manager for all backend daemons.
///
/// Manages fuegod (port 18180), fuego_walletd (port 18189), and xfg-swapd (port 18902).
/// Handles port conflict detection, process lifecycle, and health monitoring.
class DaemonManager {
  // ── Ports ────────────────────────────────────────────────────────
  static const int fuegodPort = 18180;
  static const int walletdPort = 18189;
  static const int swapdPort = 18902;

  // ── Process handles ──────────────────────────────────────────────
  Process? _fuegod;
  Process? _walletd;
  Process? _swapd;

  // ── Binary paths ─────────────────────────────────────────────────
  String? _fuegodBin;
  String? _walletdBin;
  String? _swapdBin;

  // ── State ────────────────────────────────────────────────────────
  final List<String> errors = [];
  final ValueNotifier<DaemonStatus> status = ValueNotifier(DaemonStatus());

  // ── Lifecycle ────────────────────────────────────────────────────

  /// Kill any process occupying [port], then return the freed port.
  /// Returns error message if port is occupied and cannot be freed.
  Future<String?> _freePort(int port) async {
    final pid = await _findPidOnPort(port);
    if (pid == null) return null;

    debugPrint('[daemon] Port $port in use by PID $pid — killing');
    final killed = await _killPid(pid);
    if (!killed) return 'Port $port is occupied by PID $pid and could not be killed';

    // Wait for port to be released
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (await _findPidOnPort(port) == null) return null;
    }
    return 'Port $port was occupied by PID $pid — killed but port not yet released';
  }

  /// Find PID of process listening on [port].
  Future<int?> _findPidOnPort(int port) async {
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final result = await Process.run('lsof', ['-ti', ':$port', '-sTCP:LISTEN']);
        final output = (result.stdout as String).trim();
        if (output.isNotEmpty) {
          final pid = int.tryParse(output.split('\n').first);
          if (pid != null && pid > 0) return pid;
        }
      } else if (Platform.isWindows) {
        final result = await Process.run('netstat', ['-ano']);
        final lines = (result.stdout as String).split('\n');
        for (final line in lines) {
          if (line.contains(':$port') && line.contains('LISTENING')) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.isNotEmpty) {
              final pid = int.tryParse(parts.last);
              if (pid != null && pid > 0) return pid;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Kill a process by PID.
  Future<bool> _killPid(int pid) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('taskkill', ['/F', '/PID', pid.toString()]);
        return result.exitCode == 0;
      } else {
        Process.killPid(pid, ProcessSignal.sigkill);
        // Wait briefly and verify
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return !Process.killPid(pid); // returns false if process is gone
      }
    } catch (_) {
      return false;
    }
  }

  // ── Binary discovery ─────────────────────────────────────────────

  String? _findFuegodBinary() {
    if (_fuegodBin != null && File(_fuegodBin!).existsSync()) return _fuegodBin;
    final exe = File(Platform.resolvedExecutable);
    final candidates = [
      '${exe.parent.path}/fuegod',
      if (Platform.isMacOS) '${exe.parent.parent.parent.path}/Resources/bin/fuegod',
      '${Directory.current.path}/rust-fuego-wallet/target/debug/fuegod',
      '${Directory.current.path}/rust-fuego-wallet/target/release/fuegod',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) { _fuegodBin = path; return path; }
    }
    return null;
  }

  String? _findWalletdBinary() {
    if (_walletdBin != null && File(_walletdBin!).existsSync()) return _walletdBin;
    final exe = File(Platform.resolvedExecutable);
    final candidates = [
      '${exe.parent.path}/fuego_walletd',
      if (Platform.isMacOS) '${exe.parent.parent.parent.path}/Resources/bin/fuego_walletd',
      '${Directory.current.path}/rust-fuego-wallet/target/debug/fuego_walletd',
      '${Directory.current.path}/rust-fuego-wallet/target/release/fuego_walletd',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) { _walletdBin = path; return path; }
    }
    return null;
  }

  String? _findSwapdBinary() {
    if (_swapdBin != null && File(_swapdBin!).existsSync()) return _swapdBin;
    final exe = File(Platform.resolvedExecutable);
    final candidates = [
      '${exe.parent.path}/xfg-swapd',
      if (Platform.isMacOS) '${exe.parent.parent.parent.path}/Resources/bin/xfg-swapd',
      '${Directory.current.path}/build/release/src/xfg-swapd',
      '${Directory.current.path}/xfg-swapd',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) { _swapdBin = path; return path; }
    }
    return null;
  }

  // ── Health checks ────────────────────────────────────────────────

  Future<bool> _checkHealth(String url, {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final client = HttpClient()..connectionTimeout = timeout;
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close().timeout(timeout);
      await resp.drain<void>();
      client.close(force: true);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _updateStatus() async {
    final fuegodOk = await _checkHealth('http://127.0.0.1:$fuegodPort/getinfo');
    final walletdOk = await _checkHealth('http://127.0.0.1:$walletdPort/health');
    final swapdOk = await _checkHealth('http://127.0.0.1:$swapdPort/health');

    // In local mode, walletd manages fuegod internally — fuegod is healthy if walletd is running
    final fuegodManagedByWalletd = _fuegod == null && _walletd != null && fuegodOk;

    status.value = DaemonStatus(
      fuegodRunning: (_fuegod != null && fuegodOk) || fuegodManagedByWalletd,
      walletdRunning: _walletd != null && walletdOk,
      swapdRunning: _swapd != null && swapdOk,
      fuegodError: _fuegod != null && !fuegodOk ? 'Not responding' : null,
      walletdError: _walletd != null && !walletdOk ? 'Not responding' : null,
      swapdError: _swapd != null && !swapdOk ? 'Not responding' : null,
    );
  }

  // ── Start all daemons ────────────────────────────────────────────

  /// Start all backend daemons. Order: fuegod → walletd → xfg-swapd.
  /// [useLocalNode] controls whether fuegod runs embedded.
  /// [swapConfigPath] is the path to xfg-swapd JSON config (optional — skips swapd if null).
  /// Returns error message if critical daemon fails, null on success.
  Future<String?> startAll({
    bool useLocalNode = true,
    bool useTestnet = false,
    String? swapConfigPath,
    String daemonHost = '127.0.0.1',
    int daemonPort = 18180,
  }) async {
    errors.clear();
    _updateStatus();

    // ── 1. Fuegod ──
    if (useLocalNode) {
      // When local, walletd --local manages fuegod internally.
      // Only start fuegod separately for non-local (remote walletd connecting to local fuegod).
      // Skip separate fuegod — walletd --local will handle it.
    } else {
      final fuegodErr = await _startFuegod(useTestnet: useTestnet);
      if (fuegodErr != null) {
        errors.add('fuegod: $fuegodErr');
        _updateStatus();
        return 'Failed to start fuegod: $fuegodErr';
      }
    }

    // ── 2. Fuego_walletd ──
    final walletdErr = await _startWalletd(
      useLocalNode: useLocalNode,
      useTestnet: useTestnet,
      daemonHost: daemonHost,
      daemonPort: daemonPort,
    );
    if (walletdErr != null) {
      errors.add('fuego_walletd: $walletdErr');
      _updateStatus();
      return 'Failed to start fuego_walletd: $walletdErr';
    }

    // ── 3. xfg-swapd (optional) ──
    if (swapConfigPath != null) {
      final swapdErr = await _startSwapd(swapConfigPath);
      if (swapdErr != null) {
        errors.add('xfg-swapd: $swapdErr');
        // swapd is non-critical — log but don't fail
        debugPrint('[daemon] xfg-swapd failed (non-fatal): $swapdErr');
      }
    }

    _updateStatus();
    return null;
  }

  Future<String?> _startFuegod({bool useTestnet = false}) async {
    final binary = _findFuegodBinary();
    if (binary == null) return 'fuegod binary not found';

    // Kill stale process on port
    final portErr = await _freePort(fuegodPort);
    if (portErr != null) return portErr;

    final dataDir = '${Directory.current.path}/fuegod_data';
    await Directory(dataDir).create(recursive: true);

    final args = [
      '--data-dir', dataDir,
      '--rpc-bind-port', fuegodPort.toString(),
      '--rpc-bind-ip', '127.0.0.1',
      '--log-level', '1',
    ];
    if (useTestnet) args.add('--testnet');

    try {
      debugPrint('[daemon] Starting fuegod: $binary');
      _fuegod = await Process.start(binary, args);
      _fuegod!.stdout.drain<void>();
      _fuegod!.stderr.drain<void>();
      _fuegod!.exitCode.then((code) {
        debugPrint('[daemon] fuegod exited with code $code');
        _fuegod = null;
      });
    } catch (e) {
      return 'Failed to spawn: $e';
    }

    // Wait for ready
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (await _checkHealth('http://127.0.0.1:$fuegodPort/getinfo', timeout: const Duration(seconds: 2))) {
        debugPrint('[daemon] fuegod ready on port $fuegodPort');
        return null;
      }
    }
    return 'fuegod not ready after 60s';
  }

  Future<String?> _startWalletd({
    bool useLocalNode = true,
    bool useTestnet = false,
    String daemonHost = '127.0.0.1',
    int daemonPort = 18180,
  }) async {
    final binary = _findWalletdBinary();
    if (binary == null) return 'fuego_walletd binary not found';

    // Kill stale process on port
    final portErr = await _freePort(walletdPort);
    if (portErr != null) return portErr;

    final args = [
      '--port', walletdPort.toString(),
      'serve',
      '--daemon-host', daemonHost,
      '--daemon-port', daemonPort.toString(),
    ];
    if (useTestnet) args.add('--testnet');
    if (useLocalNode) args.add('--local');

    try {
      debugPrint('[daemon] Starting fuego_walletd: $binary');
      _walletd = await Process.start(binary, args);
      if (kDebugMode) {
        _walletd!.stdout.transform<String>(utf8.decoder).listen((l) => debugPrint('[walletd:out] $l'));
        _walletd!.stderr.transform<String>(utf8.decoder).listen((l) => debugPrint('[walletd:err] $l'));
      } else {
        _walletd!.stdout.drain<void>();
        _walletd!.stderr.drain<void>();
      }
      _walletd!.exitCode.then((code) {
        debugPrint('[daemon] fuego_walletd exited with code $code');
        _walletd = null;
      });
    } catch (e) {
      return 'Failed to spawn: $e';
    }

    // Wait for ready
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (await _checkHealth('http://127.0.0.1:$walletdPort/health', timeout: const Duration(seconds: 2))) {
        debugPrint('[daemon] fuego_walletd ready on port $walletdPort');
        return null;
      }
    }
    return 'fuego_walletd not ready after 120s';
  }

  Future<String?> _startSwapd(String configPath) async {
    final binary = _findSwapdBinary();
    if (binary == null) return 'xfg-swapd binary not found';
    if (!File(configPath).existsSync()) return 'Config file not found: $configPath';

    // Kill stale process on port
    final portErr = await _freePort(swapdPort);
    if (portErr != null) return portErr;

    try {
      debugPrint('[daemon] Starting xfg-swapd: $binary');
      _swapd = await Process.start(binary, ['--swap-config', configPath, '--service']);
      _swapd!.stdout.drain<void>();
      _swapd!.stderr.drain<void>();
      _swapd!.exitCode.then((code) {
        debugPrint('[daemon] xfg-swapd exited with code $code');
        _swapd = null;
      });
    } catch (e) {
      return 'Failed to spawn: $e';
    }

    // Wait for ready
    for (var i = 0; i < 15; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (await _checkHealth('http://127.0.0.1:$swapdPort/health', timeout: const Duration(seconds: 2))) {
        debugPrint('[daemon] xfg-swapd ready on port $swapdPort');
        return null;
      }
    }
    return 'xfg-swapd not ready after 15s';
  }

  // ── Stop all daemons ─────────────────────────────────────────────

  Future<void> stopAll() async {
    await _stopProcess(_swapd, 'xfg-swapd');
    _swapd = null;
    await _stopProcess(_walletd, 'fuego_walletd');
    _walletd = null;
    await _stopProcess(_fuegod, 'fuegod');
    _fuegod = null;
    _updateStatus();
  }

  Future<void> stopSwapd() async {
    await _stopProcess(_swapd, 'xfg-swapd');
    _swapd = null;
    _updateStatus();
  }

  Future<void> _stopProcess(Process? process, String name) async {
    if (process == null) return;
    try {
      process.kill(ProcessSignal.sigterm);
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    } catch (_) {}
    debugPrint('[daemon] $name stopped');
  }

  // ── Convenience getters ──────────────────────────────────────────

  bool get fuegodRunning => _fuegod != null || (_walletd != null && status.value.fuegodRunning);
  bool get walletdRunning => _walletd != null;
  bool get swapdRunning => _swapd != null;

  bool get allRunning => fuegodRunning && walletdRunning;
  bool get anyRunning => fuegodRunning || walletdRunning || _swapd != null;
}

/// Snapshot of daemon health status.
class DaemonStatus {
  final bool fuegodRunning;
  final bool walletdRunning;
  final bool swapdRunning;
  final String? fuegodError;
  final String? walletdError;
  final String? swapdError;

  const DaemonStatus({
    this.fuegodRunning = false,
    this.walletdRunning = false,
    this.swapdRunning = false,
    this.fuegodError,
    this.walletdError,
    this.swapdError,
  });

  bool get hasErrors => fuegodError != null || walletdError != null || swapdError != null;
  bool get allHealthy => fuegodRunning && walletdRunning && swapdRunning;

  String? get summary {
    final running = [if (fuegodRunning) 'fuegod', if (walletdRunning) 'walletd', if (swapdRunning) 'swapd'];
    final stopped = [if (!fuegodRunning) 'fuegod', if (!walletdRunning) 'walletd', if (!swapdRunning) 'swapd'];
    if (running.isEmpty) return 'All daemons stopped';
    if (stopped.isEmpty) return 'All daemons running';
    return '${running.join(", ")} running, ${stopped.join(", ")} stopped';
  }
}
