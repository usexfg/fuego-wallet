import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'fuego_sdk.dart';

/// Mining service for Fuego mining operations
class MiningService {
  final FuegoSDK _sdk;

  MiningService(this._sdk);

  /// Start mining to [walletAddress]
  Future<FuegoError> start(String walletAddress) async {
    final addressPtr = walletAddress.toNativeUtf8();
    try {
      final result = _sdk.bindings.fuego_mining_start(addressPtr.cast());
      return FuegoError.fromCode(result);
    } finally {
      calloc.free(addressPtr);
    }
  }

  /// Stop mining
  Future<FuegoError> stop() async {
    final result = _sdk.bindings.fuego_mining_stop();
    return FuegoError.fromCode(result);
  }

  /// Check if mining is running
  bool isRunning() {
    return _sdk.bindings.fuego_mining_is_running() != 0;
  }

  /// Get current hashrate (hashes per second)
  Future<double> getHashrate() async {
    final hashratePtr = calloc<Double>();
    try {
      final result = _sdk.bindings.fuego_mining_get_hashrate(hashratePtr);
      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to get hashrate');
      }
      return hashratePtr.value;
    } finally {
      calloc.free(hashratePtr);
    }
  }
}
