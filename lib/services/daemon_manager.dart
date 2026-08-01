import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'daemon_event_bus.dart';

/// Unified process manager for all backend daemons.
///
/// Manages the unified daemon (fuegod + walletd + xfg-swapd in one process).
/// Default ports: fuegod=18180, walletd=8070, swapd=18902.
class DaemonManager {
  // ── Ports ────────────────────────────────────────────────────────
  static const int fuegodPort = 18180;
  static const int walletdPort = 8070;
  static const int swapdPort = 18902;

  // ── Process handles ──────────────────────────────────────────────
  Process? _unified;
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

  /// Unified event bus — single source of truth for daemon health.
  final DaemonEventBus eventBus = DaemonEventBus();

  /// Human-readable error from last `startAll()` call.
  String? _lastStartError;
  String? get lastStartError => _lastStartError;

  /// Detailed per-daemon startup error messages.
  final Map<String, String> daemonErrors = {};

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

  String? _findUnifiedBinary() {
    final exe = File(Platform.resolvedExecutable);
    final candidates = [
      '${exe.parent.path}/unified',
      if (Platform.isMacOS) '${exe.parent.parent.parent.path}/Resources/bin/unified',
      '${Directory.current.path}/xfgo/build/src/unified',
      '${Directory.current.path}/xfgo/build/release/src/unified',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  String? _findFuegodBinary() {
    if (_fuegodBin != null && File(_fuegodBin!).existsSync()) return _fuegodBin;
    final exe = File(Platform.resolvedExecutable);
    final candidates = [
      '${exe.parent.path}/fuegod',
      if (Platform.isMacOS) '${exe.parent.parent.parent.path}/Resources/bin/fuegod',
      '${Directory.current.path}/rust-fuego-wallet/target/debug/fuegod',
      '${Directory.current.path}/rust-fuego-wallet/target/release/fuegod',
      '${Directory.current.path}/xfgo/build/src/fuegod',
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
      '${Directory.current.path}/xfgo/build/src/walletd',
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
      '${Directory.current.path}/xfgo/build/src/xfg-swapd',
      '${Directory.current.path}/xfgo/build/release/src/xfg-swapd',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) { _swapdBin = path; return path; }
    }
    return null;
  }

  // ── Health checks ────────────────────────────────────────────────

  Future<bool> _checkHealth(String url, {Duration timeout = const Duration(seconds: 3)}) async {
    final result = await _checkHealthDetailed(url, timeout: timeout);
    return result.ok;
  }

  Future<_HealthResult> _checkHealthDetailed(String url, {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final client = HttpClient()..connectionTimeout = timeout;
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close().timeout(timeout);
      await resp.drain<void>();
      client.close(force: true);
      if (resp.statusCode == 200) return _HealthResult.ok();
      return _HealthResult.error('HTTP ${resp.statusCode}');
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 61 || e.message.contains('Connection refused')) {
        return _HealthResult.error('Connection refused');
      }
      if (e.osError?.errorCode == 60 || e.message.contains('ETIMEDOUT') || e.message.contains('timed out')) {
        return _HealthResult.error('Connection timed out');
      }
      return _HealthResult.error(e.message.length > 80 ? '${e.message.substring(0, 77)}...' : e.message);
    } on TimeoutException {
      return _HealthResult.error('Connection timed out');
    } catch (e) {
      final msg = e.toString();
      return _HealthResult.error(msg.length > 80 ? '${msg.substring(0, 77)}...' : msg);
    }
  }

  Future<void> _updateStatus() async {
    final fuegodHealth = await _checkHealthDetailed('http://127.0.0.1:$fuegodPort/getinfo');
    final walletdHealth = await _checkHealthDetailed('http://127.0.0.1:$walletdPort/health');
    final swapdHealth = await _checkHealthDetailed('http://127.0.0.1:$swapdPort/health');

    final fuegodOk = fuegodHealth.ok;
    final walletdOk = walletdHealth.ok;
    final swapdOk = swapdHealth.ok;

    // In local mode, walletd manages fuegod internally — fuegod is healthy if walletd is running
    final fuegodManagedByWalletd = _fuegod == null && _walletd != null && fuegodOk;

    status.value = DaemonStatus(
      fuegodRunning: (_fuegod != null && fuegodOk) || fuegodManagedByWalletd,
      walletdRunning: _walletd != null && walletdOk,
      swapdRunning: _swapd != null && swapdOk,
      fuegodError: _fuegod != null && !fuegodOk ? fuegodHealth.error : (daemonErrors['fuegod']),
      walletdError: _walletd != null && !walletdOk ? walletdHealth.error : daemonErrors['walletd'],
      swapdError: _swapd != null && !swapdOk ? swapdHealth.error : daemonErrors['swapd'],
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
    daemonErrors.clear();
    _lastStartError = null;
    _updateStatus();

    // ── 0. Try unified daemon first ──
    final unifiedBin = _findUnifiedBinary();
    if (unifiedBin != null) {
      debugPrint('[daemon] Found unified daemon: $unifiedBin');
      final unifiedErr = await _startUnified(unifiedBin, useLocalNode: useLocalNode, useTestnet: useTestnet);
      if (unifiedErr == null) {
        _updateStatus();
        eventBus.start();
        return null;
      }
      debugPrint('[daemon] Unified daemon failed, falling back to separate processes: $unifiedErr');
    }

    // ── 1. Fuegod ──
    if (useLocalNode) {
      // When local, walletd --local manages fuegod internally.
      // Only start fuegod separately for non-local (remote walletd connecting to local fuegod).
      // Skip separate fuegod — walletd --local will handle it.
    } else {
      final fuegodErr = await _startFuegod(useTestnet: useTestnet);
      if (fuegodErr != null) {
        errors.add('fuegod: $fuegodErr');
        daemonErrors['fuegod'] = fuegodErr;
        _lastStartError = 'fuegod: $fuegodErr';
        _updateStatus();
        return _lastStartError;
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
      daemonErrors['walletd'] = walletdErr;
      _lastStartError = 'walletd: $walletdErr';
      _updateStatus();
      return _lastStartError;
    }

    // ── 3. xfg-swapd (optional) ──
    if (swapConfigPath != null) {
      final swapdErr = await _startSwapd(swapConfigPath);
      if (swapdErr != null) {
        errors.add('xfg-swapd: $swapdErr');
        daemonErrors['swapd'] = swapdErr;
        // swapd is non-critical — log but don't fail
        debugPrint('[daemon] xfg-swapd failed (non-fatal): $swapdErr');
      }
    }

    _updateStatus();

    // Start unified event bus for continuous health monitoring.
    eventBus.start();

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

  Future<String?> _startUnified(String binary, {bool useLocalNode = true, bool useTestnet = false}) async {
    // Kill stale process on port
    final portErr = await _freePort(walletdPort);
    if (portErr != null) return portErr;

    final args = <String>[
      '--bind-port', walletdPort.toString(),
    ];
    if (useLocalNode) args.add('--local');
    if (useTestnet) args.add('--testnet');

    try {
      debugPrint('[daemon] Starting unified daemon: $binary');
      _unified = await Process.start(binary, args);
      if (kDebugMode) {
        _unified!.stdout.transform<String>(utf8.decoder).listen((l) => debugPrint('[unified:out] $l'));
        _unified!.stderr.transform<String>(utf8.decoder).listen((l) => debugPrint('[unified:err] $l'));
      } else {
        _unified!.stdout.drain<void>();
        _unified!.stderr.drain<void>();
      }
      _unified!.exitCode.then((code) {
        debugPrint('[daemon] unified daemon exited with code $code');
        _unified = null;
      });
    } catch (e) {
      return 'Failed to spawn: $e';
    }

    // Wait for ready — unified daemon exposes /json_rpc with getHealth
    // Blockchain rescan + wallet scan can take up to ~150s on mainnet
    for (var i = 0; i < 90; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
        final req = await client.postUrl(Uri.parse('http://127.0.0.1:$walletdPort/json_rpc'));
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getHealth',
          'params': <String, dynamic>{},
        }));
        final resp = await req.close().timeout(const Duration(seconds: 2));
        await resp.drain<void>();
        client.close(force: true);
        if (resp.statusCode == 200) {
          debugPrint('[daemon] unified daemon ready on port $walletdPort');
          return null;
        }
      } catch (_) {}
    }
    return 'unified daemon not ready after 180s';
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
    eventBus.stop();
    await _stopProcess(_unified, 'unified');
    _unified = null;
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

  bool get fuegodRunning => _unified != null || _fuegod != null || (_walletd != null && status.value.fuegodRunning);
  bool get walletdRunning => _unified != null || _walletd != null;
  bool get swapdRunning => _unified != null || _swapd != null;

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

  /// Human-readable status summary for UI display.
  String get displayText {
    final parts = <String>[];
    if (!fuegodRunning) parts.add('Node: ${fuegodError ?? "offline"}');
    if (!walletdRunning) parts.add('Wallet: ${walletdError ?? "offline"}');
    if (!swapdRunning) parts.add('Swap: ${swapdError ?? "offline"}');
    return parts.join(' \u2022 ');
  }

  String? get summary {
    final running = [if (fuegodRunning) 'fuegod', if (walletdRunning) 'walletd', if (swapdRunning) 'swapd'];
    final stopped = [if (!fuegodRunning) 'fuegod', if (!walletdRunning) 'walletd', if (!swapdRunning) 'swapd'];
    if (running.isEmpty) return 'All daemons stopped';
    if (stopped.isEmpty) return 'All daemons running';
    return '${running.join(", ")} running, ${stopped.join(", ")} stopped';
  }
}

class _HealthResult {
  final bool ok;
  final String? error;
  _HealthResult.ok() : ok = true, error = null;
  _HealthResult.error(this.error) : ok = false;
}
