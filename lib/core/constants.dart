/// Inlined from fuego_core — only what the wallet actually uses.

/// Default RPC port for Fuego daemon.
const int defaultRpcPort = 18180;

/// Atomic units per XFG coin (10^7).
const int atomicPerCoin = 10000000;

/// Decimal places for XFG display.
const int decimalPlaces = 7;

/// Average block time in seconds.
const int avgBlockTime = 480;

/// Default transaction fee in atomic units.
const int txFee = 8000;

/// Format atomic units to XFG string.
String formatXfg(int atomic) {
  return (atomic / atomicPerCoin).toStringAsFixed(decimalPlaces);
}
