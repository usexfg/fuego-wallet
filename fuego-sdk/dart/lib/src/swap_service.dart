import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'fuego_sdk.dart';
import 'fuego_sdk_bindings.dart';

/// Atomic swap service
class SwapService {
  final FuegoSDK _sdk;

  SwapService(this._sdk);

  /// Initiate a new atomic swap
  Future<SwapInfo> initiate({
    required String counterpartyAddress,
    required int amount,
    required String walletFile,
    required String walletPassword,
  }) async {
    final counterpartyPtr = counterpartyAddress.toNativeUtf8();
    final walletFilePtr = walletFile.toNativeUtf8();
    final passwordPtr = walletPassword.toNativeUtf8();
    final swapInfoPtr = calloc<FuegoSwapInfo>();

    try {
      final result = _sdk.bindings.fuego_swap_initiate(
        counterpartyPtr.cast(),
        amount,
        walletFilePtr.cast(),
        passwordPtr.cast(),
        swapInfoPtr,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to initiate swap: ${FuegoError.fromCode(result)}');
      }

      return SwapInfo._fromNative(swapInfoPtr.ref);
    } finally {
      calloc.free(counterpartyPtr);
      calloc.free(walletFilePtr);
      calloc.free(passwordPtr);
      calloc.free(swapInfoPtr);
    }
  }

  /// Join an existing swap
  Future<SwapInfo> join({
    required String swapId,
    required String walletFile,
    required String walletPassword,
  }) async {
    final swapIdPtr = swapId.toNativeUtf8();
    final walletFilePtr = walletFile.toNativeUtf8();
    final passwordPtr = walletPassword.toNativeUtf8();
    final swapInfoPtr = calloc<FuegoSwapInfo>();

    try {
      final result = _sdk.bindings.fuego_swap_join(
        swapIdPtr.cast(),
        walletFilePtr.cast(),
        passwordPtr.cast(),
        swapInfoPtr,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to join swap: ${FuegoError.fromCode(result)}');
      }

      return SwapInfo._fromNative(swapInfoPtr.ref);
    } finally {
      calloc.free(swapIdPtr);
      calloc.free(walletFilePtr);
      calloc.free(passwordPtr);
      calloc.free(swapInfoPtr);
    }
  }

  /// Lock funds for a swap
  Future<FuegoError> lockFunds({
    required String swapId,
    required String walletFile,
    required String walletPassword,
  }) async {
    final swapIdPtr = swapId.toNativeUtf8();
    final walletFilePtr = walletFile.toNativeUtf8();
    final passwordPtr = walletPassword.toNativeUtf8();

    try {
      final result = _sdk.bindings.fuego_swap_lock_funds(
        swapIdPtr.cast(),
        walletFilePtr.cast(),
        passwordPtr.cast(),
      );
      return FuegoError.fromCode(result);
    } finally {
      calloc.free(swapIdPtr);
      calloc.free(walletFilePtr);
      calloc.free(passwordPtr);
    }
  }

  /// Complete a swap
  Future<FuegoError> complete({
    required String swapId,
    required String walletFile,
    required String walletPassword,
  }) async {
    final swapIdPtr = swapId.toNativeUtf8();
    final walletFilePtr = walletFile.toNativeUtf8();
    final passwordPtr = walletPassword.toNativeUtf8();

    try {
      final result = _sdk.bindings.fuego_swap_complete(
        swapIdPtr.cast(),
        walletFilePtr.cast(),
        passwordPtr.cast(),
      );
      return FuegoError.fromCode(result);
    } finally {
      calloc.free(swapIdPtr);
      calloc.free(walletFilePtr);
      calloc.free(passwordPtr);
    }
  }

  /// Refund a swap
  Future<FuegoError> refund({
    required String swapId,
    required String walletFile,
    required String walletPassword,
  }) async {
    final swapIdPtr = swapId.toNativeUtf8();
    final walletFilePtr = walletFile.toNativeUtf8();
    final passwordPtr = walletPassword.toNativeUtf8();

    try {
      final result = _sdk.bindings.fuego_swap_refund(
        swapIdPtr.cast(),
        walletFilePtr.cast(),
        passwordPtr.cast(),
      );
      return FuegoError.fromCode(result);
    } finally {
      calloc.free(swapIdPtr);
      calloc.free(walletFilePtr);
      calloc.free(passwordPtr);
    }
  }

  /// Get swap info
  Future<SwapInfo> getInfo(String swapId) async {
    final swapIdPtr = swapId.toNativeUtf8();
    final swapInfoPtr = calloc<FuegoSwapInfo>();

    try {
      final result = _sdk.bindings.fuego_swap_get_info(
        swapIdPtr.cast(),
        swapInfoPtr,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to get swap info: ${FuegoError.fromCode(result)}');
      }

      return SwapInfo._fromNative(swapInfoPtr.ref);
    } finally {
      calloc.free(swapIdPtr);
      calloc.free(swapInfoPtr);
    }
  }
}

/// Swap state enum
enum SwapState {
  initiated,
  participantJoined,
  fundsLocked,
  completed,
  refunded,
  failed,
}

/// Swap information
class SwapInfo {
  final String swapId;
  final SwapState state;
  final String counterpartyAddress;
  final int amount;
  final String txHash;

  SwapInfo({
    required this.swapId,
    required this.state,
    required this.counterpartyAddress,
    required this.amount,
    required this.txHash,
  });

  SwapInfo._fromNative(FuegoSwapInfo native)
      : swapId = _arrayToString(native.swap_id, 128),
        state = SwapState.values[native.state],
        counterpartyAddress = _arrayToString(native.counterparty_address, 128),
        amount = native.amount,
        txHash = _arrayToString(native.tx_hash, 128);
}


String _arrayToString(dynamic arr, int maxLength) {
  final chars = <int>[];
  for (var i = 0; i < maxLength; i++) {
    if (arr[i] == 0) break;
    chars.add(arr[i]);
  }
  return utf8.decode(chars);
}
