import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Dart EventBus mirroring the xfgo dashboard's unified daemon monitoring.
///
/// Polls all 3 daemons (fuegod, walletd, xfg-swapd) on independent timers,
/// broadcasts typed events to all listeners. Single source of truth for
/// daemon health, chain state, and swap status.
class DaemonEventBus {
  // ── Event types (matches xfgo dashboard) ─────────────────────────
  static const String eventHealth = 'health';
  static const String eventBlock = 'block';
  static const String eventHeat = 'heat_metric';
  static const String eventPool = 'pool_info';
  static const String eventSwap = 'swap_update';
  static const String eventSpv = 'spv_status';
  static const String eventOrderbook = 'orderbook';
  static const String eventError = 'error';

  // ── State ────────────────────────────────────────────────────────
  final StreamController<DaemonEvent> _controller =
      StreamController<DaemonEvent>.broadcast();
  Stream<DaemonEvent> get stream => _controller.stream;

  /// Current health snapshot — always最新 state.
  final ValueNotifier<DaemonHealthSnapshot> health =
      ValueNotifier(const DaemonHealthSnapshot());

  /// Latest block info from fuegod.
  final ValueNotifier<Map<String, dynamic>?> blockInfo =
      ValueNotifier(null);

  /// Latest HEAT metrics.
  final ValueNotifier<Map<String, dynamic>?> heatMetrics =
      ValueNotifier(null);

  /// Latest pool info.
  final ValueNotifier<Map<String, dynamic>?> poolInfo =
      ValueNotifier(null);

  // ── Timers ───────────────────────────────────────────────────────
  Timer? _fuegodTimer;
  Timer? _walletdTimer;
  Timer? _swapdTimer;

  // ── Config ───────────────────────────────────────────────────────
  String fuegodHost = '127.0.0.1';
  int fuegodPort = 18180;
  int walletdPort = 18189;
  int swapdPort = 18902;

  // ── Lifecycle ────────────────────────────────────────────────────

  /// Start polling all daemons.
  ///
  /// [fuegodHost] is `127.0.0.1` in local mode, or the remote seed host
  /// when the wallet proxy is in remote mode.
  void start({
    String fuegodHost = '127.0.0.1',
    int fuegodPort = 18180,
    int walletdPort = 18189,
    int swapdPort = 18902,
  }) {
    stop();
    this.fuegodHost = fuegodHost;
    this.fuegodPort = fuegodPort;
    this.walletdPort = walletdPort;
    this.swapdPort = swapdPort;

    // Immediate first poll
    _pollFuegod();
    _pollWalletd();
    _pollSwapd();

    // Then on timers (matches xfgo dashboard intervals)
    _fuegodTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _pollFuegod());
    _walletdTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _pollWalletd());
    _swapdTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _pollSwapd());
  }

  /// Stop all polling.
  void stop() {
    _fuegodTimer?.cancel();
    _walletdTimer?.cancel();
    _swapdTimer?.cancel();
    _fuegodTimer = null;
    _walletdTimer = null;
    _swapdTimer = null;
  }

  void dispose() {
    stop();
    _controller.close();
    health.dispose();
    blockInfo.dispose();
    heatMetrics.dispose();
    poolInfo.dispose();
  }

  // ── Pollers (mirrors xfgo dashboard pollDaemon/pollWallet/pollSwapd) ──

  String get _fuegodBase => 'http://$fuegodHost:$fuegodPort';

  Future<void> _pollFuegod() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);

      // Block height + chain info (matches xfgo pollDaemon line 189)
      try {
        final req = await client.getUrl(
            Uri.parse('$_fuegodBase/getinfo'));
        final resp = await req.close().timeout(const Duration(seconds: 3));
        final body = await resp.transform(utf8.decoder).join();
        client.close(force: true);

        if (resp.statusCode == 200) {
          final data = jsonDecode(body) as Map<String, dynamic>;
          blockInfo.value = data;
          _emit(eventBlock, data);
          _updateHealth(fuegodOk: true);
        } else {
          _updateHealth(fuegodOk: false, fuegodError: 'HTTP ${resp.statusCode}');
        }
      } catch (_) {
        client.close(force: true);
        _updateHealth(fuegodOk: false, fuegodError: 'Connection refused');
      }

      // HEAT metrics (matches xfgo pollDaemon line 195)
      try {
        final heatClient = HttpClient()
          ..connectionTimeout = const Duration(seconds: 3);
        final req = await heatClient.getUrl(
            Uri.parse('$_fuegodBase/heat_metrics'));
        final resp = await req.close().timeout(const Duration(seconds: 3));
        final body = await resp.transform(utf8.decoder).join();
        heatClient.close(force: true);

        if (resp.statusCode == 200) {
          final data = jsonDecode(body) as Map<String, dynamic>;
          heatMetrics.value = data;
          _emit(eventHeat, data);
        }
      } catch (_) {}

      // Pool info (matches xfgo pollDaemon line 200)
      try {
        final poolClient = HttpClient()
          ..connectionTimeout = const Duration(seconds: 3);
        final req = await poolClient.getUrl(
            Uri.parse('$_fuegodBase/amm_pool_info'));
        final resp = await req.close().timeout(const Duration(seconds: 3));
        final body = await resp.transform(utf8.decoder).join();
        poolClient.close(force: true);

        if (resp.statusCode == 200) {
          final data = jsonDecode(body) as Map<String, dynamic>;
          poolInfo.value = data;
          _emit(eventPool, data);
        }
      } catch (_) {}
    } catch (_) {}
  }

   Future<void> _pollWalletd() async {
     try {
       final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);

        // Health check — try JSON-RPC getHealth first (unified daemon on port 8070)
        // then fall back to GET /health (Rust proxy on port 18189)
        try {
          final req = await client.postUrl(
              Uri.parse('http://127.0.0.1:$walletdPort/json_rpc'));
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'getHealth',
            'params': <String, dynamic>{},
          }));
          final resp = await req.close().timeout(const Duration(seconds: 3));
         final body = await resp.transform(utf8.decoder).join();
         client.close(force: true);

         if (resp.statusCode == 200) {
           final data = jsonDecode(body) as Map<String, dynamic>;
           final result = data['result'] as Map<String, dynamic>? ?? {};
           final walletOk = result['wallet'] is bool
               ? result['wallet'] as bool
               : true;
           _updateHealth(walletdOk: walletOk, walletdData: result);
           return;
         }
       } catch (_) {}

       // Fall back to GET /health (Rust proxy)
       try {
         final req2 = await client.getUrl(
             Uri.parse('http://127.0.0.1:$walletdPort/health'));
         final resp = await req2.close().timeout(const Duration(seconds: 3));
         final body = await resp.transform(utf8.decoder).join();
         client.close(force: true);

         if (resp.statusCode == 200) {
           final Map<String, dynamic> data;
           try {
             data = jsonDecode(body) as Map<String, dynamic>;
           } catch (_) {
             _updateHealth(walletdOk: false, walletdError: 'invalid health response');
             return;
           }
           _updateHealth(walletdOk: true, walletdData: data);
           return;
         } else {
           _updateHealth(walletdOk: false, walletdError: 'HTTP ${resp.statusCode}');
           return;
         }
       } catch (_) {}

       client.close(force: true);
       _updateHealth(walletdOk: false, walletdError: 'Connection refused');
     } catch (_) {}
   }

   Future<void> _pollSwapd() async {
     try {
       final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);

        // For unified daemon, swapd health is part of getHealth on walletd port
        // For standalone xfg-swapd, use GET /health on swapd port
        try {
          final req = await client.postUrl(
              Uri.parse('http://127.0.0.1:$walletdPort/json_rpc'));
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'getHealth',
            'params': <String, dynamic>{},
          }));
          final resp = await req.close().timeout(const Duration(seconds: 3));
         final body = await resp.transform(utf8.decoder).join();
         client.close(force: true);

         if (resp.statusCode == 200) {
           final data = jsonDecode(body) as Map<String, dynamic>;
           final result = data['result'] as Map<String, dynamic>? ?? {};
           if (result['swap'] is bool) {
             final swapOk = result['swap'] as bool;
             _updateHealth(swapdOk: swapOk);
             if (swapOk) {
               _emit(eventSwap, result);
             }
             return;
           }
         }
       } catch (_) {}

       // Fall back to GET /health for standalone xfg-swapd
       try {
         final req2 = await client.getUrl(
             Uri.parse('http://127.0.0.1:$swapdPort/health'));
         final resp = await req2.close().timeout(const Duration(seconds: 3));
         final body = await resp.transform(utf8.decoder).join();
         client.close(force: true);

         if (resp.statusCode == 200) {
           final Map<String, dynamic> data;
           try {
             data = jsonDecode(body) as Map<String, dynamic>;
           } catch (_) {
             _updateHealth(swapdOk: false, swapdError: 'invalid health response');
             return;
           }
           _updateHealth(swapdOk: true);
           _emit(eventSwap, data);
           return;
         } else {
           _updateHealth(swapdOk: false, swapdError: 'HTTP ${resp.statusCode}');
           return;
         }
       } catch (_) {}

       client.close(force: true);
       _updateHealth(swapdOk: false, swapdError: 'Connection refused');
     } catch (_) {}
   }

  // ── Health state management ──────────────────────────────────────

  void _updateHealth({
    bool? fuegodOk,
    bool? walletdOk,
    bool? swapdOk,
    String? fuegodError,
    String? walletdError,
    String? swapdError,
    Map<String, dynamic>? walletdData,
  }) {
    final prev = health.value;
    health.value = DaemonHealthSnapshot(
      fuegodRunning: fuegodOk ?? prev.fuegodRunning,
      walletdRunning: walletdOk ?? prev.walletdRunning,
      swapdRunning: swapdOk ?? prev.swapdRunning,
      fuegodError: fuegodOk == false
          ? (fuegodError ?? prev.fuegodError)
          : (fuegodOk == true ? null : prev.fuegodError),
      walletdError: walletdOk == false
          ? (walletdError ?? prev.walletdError)
          : (walletdOk == true ? null : prev.walletdError),
      swapdError: swapdOk == false
          ? (swapdError ?? prev.swapdError)
          : (swapdOk == true ? null : prev.swapdError),
      walletdData: walletdData ?? prev.walletdData,
    );

    _emit(eventHealth, health.value.toJson());
  }

  // ── Event emission ───────────────────────────────────────────────

  void _emit(String type, Map<String, dynamic> payload) {
    if (_controller.isClosed) return;
    _controller.add(DaemonEvent(
      type: type,
      payload: payload,
      time: DateTime.now(),
    ));
  }
}

/// Typed event from the daemon event bus.
class DaemonEvent {
  final String type;
  final Map<String, dynamic> payload;
  final DateTime time;

  const DaemonEvent({
    required this.type,
    required this.payload,
    required this.time,
  });
}

/// Snapshot of all daemon health states.
class DaemonHealthSnapshot {
  final bool fuegodRunning;
  final bool walletdRunning;
  final bool swapdRunning;
  final String? fuegodError;
  final String? walletdError;
  final String? swapdError;
  final Map<String, dynamic>? walletdData;

  const DaemonHealthSnapshot({
    this.fuegodRunning = false,
    this.walletdRunning = false,
    this.swapdRunning = false,
    this.fuegodError,
    this.walletdError,
    this.swapdError,
    this.walletdData,
  });

  bool get allHealthy => fuegodRunning && walletdRunning && swapdRunning;
  bool get anyRunning => fuegodRunning || walletdRunning || swapdRunning;

  String get displayText {
    final parts = <String>[];
    if (!fuegodRunning) parts.add('Node: ${fuegodError ?? "offline"}');
    if (!walletdRunning) parts.add('Wallet: ${walletdError ?? "offline"}');
    if (!swapdRunning) parts.add('Swap: ${swapdError ?? "offline"}');
    if (parts.isEmpty) return 'All daemons running';
    return parts.join(' \u2022 ');
  }

  Map<String, dynamic> toJson() => {
        'daemon': fuegodRunning,
        'wallet': walletdRunning,
        'swapd': swapdRunning,
        if (fuegodError != null) 'daemon_error': fuegodError,
        if (walletdError != null) 'wallet_error': walletdError,
        if (swapdError != null) 'swapd_error': swapdError,
      };
}
