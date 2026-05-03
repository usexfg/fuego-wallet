import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'fuego_sdk.dart';
import 'fuego_sdk_bindings.dart';

/// Node service for managing Fuego node connections
class NodeService {
  final FuegoSDK _sdk;

  NodeService(this._sdk);

  /// Start the node
  /// 
  /// For [mode] = [FuegoNodeMode.embedded], starts a full embedded node
  /// For [mode] = [FuegoNodeMode.remote], connects to [remoteHost]:[remotePort]
  Future<FuegoError> start({
    required FuegoNodeMode mode,
    String? remoteHost,
    int? remotePort,
  }) async {
    if (mode == FuegoNodeMode.remote && (remoteHost == null || remotePort == null)) {
      return FuegoError.FUEGO_ERROR_INVALID_PARAM;
    }

    final hostPtr = remoteHost?.toNativeUtf8();
    try {
      final result = _sdk.bindings.fuego_node_start(
        mode.index,
        hostPtr?.cast() ?? nullptr,
        remotePort ?? 0,
      );
      return FuegoError.fromCode(result);
    } finally {
      if (hostPtr != null) {
        calloc.free(hostPtr);
      }
    }
  }

  /// Stop the node
  Future<FuegoError> stop() async {
    final result = _sdk.bindings.fuego_node_stop();
    return FuegoError.fromCode(result);
  }

  /// Check if node is running
  bool isRunning() {
    return _sdk.bindings.fuego_node_is_running() != 0;
  }

  /// Get peer count
  Future<int> getPeerCount() async {
    final countPtr = calloc<Uint32>();
    try {
      final result = _sdk.bindings.fuego_node_get_peer_count(countPtr);
      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to get peer count');
      }
      return countPtr.value;
    } finally {
      calloc.free(countPtr);
    }
  }

  /// Get current block height
  Future<int> getBlockHeight() async {
    final heightPtr = calloc<Uint32>();
    try {
      final result = _sdk.bindings.fuego_node_get_block_height(heightPtr);
      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to get block height');
      }
      return heightPtr.value;
    } finally {
      calloc.free(heightPtr);
    }
  }

  /// Get sync status
  Future<bool> isSynchronized() async {
    final syncPtr = calloc<Bool>();
    try {
      final result = _sdk.bindings.fuego_node_get_sync_status(syncPtr);
      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to get sync status');
      }
      return syncPtr.value;
    } finally {
      calloc.free(syncPtr);
    }
  }
}
