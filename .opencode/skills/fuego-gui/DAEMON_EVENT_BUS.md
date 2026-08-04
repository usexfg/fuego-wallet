# Daemon Event Bus Reference

## Overview

The `DaemonEventBus` class provides continuous health monitoring for all daemons with independent polling timers and typed event streams.

## Class Structure

```dart
class DaemonEventBus {
  static const String eventHealth = 'health';
  static const String eventBlock = 'block';
  static const String eventHeat = 'heat_metric';
  static const String eventPool = 'pool_info';
  static const String eventSwap = 'swap_update';
  static const String eventSpv = 'spv_status';
  static const String eventOrderbook = 'orderbook';
  static const String eventError = 'error';

  final ValueNotifier<DaemonHealthSnapshot> health;
  final ValueNotifier<Map<String, dynamic>?> blockInfo;
  final ValueNotifier<Map<String, dynamic>?> heatMetrics;
  final ValueNotifier<Map<String, dynamic>?> poolInfo;

  int fuegodPort = 18180;
  int walletdPort = 18189;
  int swapdPort = 18902;
}
```

## Polling

| Daemon | Interval | Method | Endpoint |
|--------|----------|--------|----------|
| fuegod | 5s | GET | `/getinfo` |
| walletd | 10s | POST | `/json_rpc` (getHealth) |
| xfg-swapd | 5s | POST | `/json_rpc` (getHealth) |

Also polls: `/heat_metrics`, `/amm_pool_info`

## Health Check Flow

### Unified Daemon
1. POST `/json_rpc` with `getHealth` on port 18189
2. Response: `{result: {fuegod: bool, wallet: bool, swap: bool}}`

### Separate Daemons
1. fuegod: GET `/getinfo` on port 18180
2. walletd: GET `/health` on port 18902
3. xfg-swapd: GET `/health` on port 18902

## DaemonHealthSnapshot

```dart
class DaemonHealthSnapshot {
  final bool fuegodRunning;
  final bool walletdRunning;
  final bool swapdRunning;
  final String? fuegodError;
  final String? walletdError;
  final String? swapdError;
  final Map<String, dynamic>? walletdData;

  bool get allHealthy;
  bool get anyRunning;
  String get displayText; // "Node: offline • Wallet: offline" etc
}
```

## UI Integration

```dart
ValueListenableBuilder<DaemonHealthSnapshot>(
  valueListenable: app.daemonManager.eventBus.health,
  builder: (context, health, _) {
    if (health.allHealthy) return SizedBox.shrink();
    return ErrorBanner(health: health);
  },
)
```

## Error Handling

- 3-second timeout per request
- Graceful fallback: unified → separate
- Errors preserved in snapshot
- No exceptions thrown to UI

---

**Reference Status:** COMPLETE
**Last Updated:** 2026-08-03
