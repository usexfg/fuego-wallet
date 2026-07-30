import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages xfg-swapd configuration and process lifecycle.
class SwapConfigService {
  Process? _swapDaemon;
  String? _configPath;
  String? _swapdPath;

  Future<String> _dataDir() async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  Future<String> configPath() async {
    if (_configPath != null) return _configPath!;
    final dir = await _dataDir();
    _configPath = '$dir/swap_config.json';
    return _configPath!;
  }

  String configPathSync() {
    if (_configPath != null) return _configPath!;
    _configPath = '${Directory.systemTemp.path}/swap_config.json';
    return _configPath!;
  }

  String? findSwapdBinary() {
    if (_swapdPath != null && File(_swapdPath!).existsSync()) return _swapdPath;

    final exe = File(Platform.resolvedExecutable);
    final candidates = [
      '${exe.parent.path}/xfg-swapd',
      if (Platform.isMacOS) '${exe.parent.parent.parent.path}/Resources/bin/xfg-swapd',
      '${Directory.current.path}/build/release/src/xfg-swapd',
      '${Directory.current.path}/xfg-swapd',
    ];

    for (final path in candidates) {
      if (File(path).existsSync()) {
        _swapdPath = path;
        return path;
      }
    }
    return null;
  }

  Future<String> generateConfig({
    required Map<String, SwapChainConfig> chains,
    String? xfgSecretKey,
  }) async {
    final config = <String, dynamic>{};

    for (final entry in chains.entries) {
      final chain = entry.key.toLowerCase();
      final cfg = entry.value;
      if (cfg.wif.isEmpty) continue;

      final isEvmOrSol = const {'eth', 'arb', 'base', 'bsc', 'poly', 'sol'}.contains(chain);

      if (isEvmOrSol && cfg.rpcUrl != null && cfg.rpcUrl!.isNotEmpty) {
        config['${chain}_mode'] = 'rpc';
        if (chain == 'sol') {
          config['${chain}_keypair_path'] = cfg.wif;
        } else {
          config['${chain}_priv_key'] = cfg.wif;
        }
        final uri = Uri.tryParse(cfg.rpcUrl!);
        if (uri != null) {
          config['${chain}_rpc_host'] = uri.host;
          config['${chain}_rpc_port'] = uri.port;
        }
      } else if (!isEvmOrSol) {
        config['${chain}_mode'] = 'spv';
        config['${chain}_wif'] = cfg.wif;
        if (cfg.servers.isNotEmpty) {
          for (var i = 0; i < cfg.servers.length && i < 16; i++) {
            config['${chain}_spv_server_$i'] = cfg.servers[i];
          }
        }
        if (cfg.minServers != null) config['${chain}_spv_min_servers'] = cfg.minServers!;
        if (cfg.checkpointHeight != null && cfg.checkpointHeight! > 0) {
          config['${chain}_spv_checkpoint_height'] = cfg.checkpointHeight!;
        }
        if (cfg.checkpointHash != null && cfg.checkpointHash!.isNotEmpty) {
          config['${chain}_spv_checkpoint_hash'] = cfg.checkpointHash!;
        }
      }
    }

    if (xfgSecretKey != null && xfgSecretKey.isNotEmpty) {
      config['xfg_secret_key'] = xfgSecretKey;
    }

    final path = await configPath();
    await File(path).writeAsString(const JsonEncoder.withIndent('  ').convert(config));
    return path;
  }

  static String? validateWif(String wif, String chain) {
    if (wif.isEmpty) return 'WIF is required';
    if (wif.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(wif)) return null;
    if (wif.length < 50 || wif.length > 60) return 'Invalid WIF length';
    if (!RegExp(r'^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]+$').hasMatch(wif)) {
      return 'WIF contains invalid Base58 characters';
    }
    switch (chain.toLowerCase()) {
      case 'btc':
      case 'bch':
        if (!wif.startsWith('5') && !wif.startsWith('K') && !wif.startsWith('L')) return 'Must start with 5, K, or L';
        break;
      case 'ltc':
        if (!wif.startsWith('6') && !wif.startsWith('T')) return 'Must start with 6 or T';
        break;
      case 'kmd':
        if (!wif.startsWith('7') && !wif.startsWith('U')) return 'Must start with 7 or U';
        break;
    }
    return null;
  }

  Future<bool> startDaemon({String? configPath}) async {
    final binary = findSwapdBinary();
    if (binary == null) return false;
    final cfgPath = configPath ?? await this.configPath();
    if (!File(cfgPath).existsSync()) return false;
    try {
      _swapDaemon = await Process.start(binary, ['--swap-config', cfgPath, '--service']);
      _swapDaemon!.stdout.drain<void>();
      _swapDaemon!.stderr.drain<void>();
      _swapDaemon!.exitCode.then((code) {
        debugPrint('[swapd] Exited with code $code');
        _swapDaemon = null;
      });
      return true;
    } catch (e) {
      debugPrint('[swapd] Failed to start: $e');
      return false;
    }
  }

  Future<void> stopDaemon() async {
    final p = _swapDaemon;
    _swapDaemon = null;
    if (p == null) return;
    try {
      p.kill(ProcessSignal.sigterm);
      await p.exitCode.timeout(const Duration(seconds: 5), onTimeout: () { p.kill(ProcessSignal.sigkill); return -1; });
    } catch (_) {}
  }

  bool get isRunning => _swapDaemon != null && _swapDaemon!.pid > 0;

  static String addressFromWif(String wif, String chain) => '(derive from $chain WIF)';
}

class SwapChainConfig {
  final String wif;
  final List<String> servers;
  final int? minServers;
  final int? checkpointHeight;
  final String? checkpointHash;
  final String? rpcUrl;

  const SwapChainConfig({
    required this.wif,
    this.servers = const [],
    this.minServers,
    this.checkpointHeight,
    this.checkpointHash,
    this.rpcUrl,
  });

  Map<String, dynamic> toJson() => {
        'wif': wif,
        if (servers.isNotEmpty) 'servers': servers,
        if (minServers != null) 'minServers': minServers,
        if (checkpointHeight != null) 'checkpointHeight': checkpointHeight,
        if (checkpointHash != null) 'checkpointHash': checkpointHash,
        if (rpcUrl != null) 'rpcUrl': rpcUrl,
      };

  factory SwapChainConfig.fromJson(Map<String, dynamic> j) => SwapChainConfig(
        wif: j['wif'] as String? ?? '',
        servers: (j['servers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        minServers: j['minServers'] as int?,
        checkpointHeight: j['checkpointHeight'] as int?,
        checkpointHash: j['checkpointHash'] as String?,
        rpcUrl: j['rpcUrl'] as String?,
      );
}
