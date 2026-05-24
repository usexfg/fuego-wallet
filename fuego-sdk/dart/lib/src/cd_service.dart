import 'dart:ffi';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

import 'fuego_sdk.dart';
import 'fuego_sdk_bindings.dart';

String _array8ToStr(ffi.Array<ffi.Int8> arr) {
  final bytes = <int>[];
  for (int i = 0; i < arr.length; i++) {
    final byte = arr[i];
    if (byte == 0) break;
    bytes.add(byte);
  }
  return String.fromCharCodes(bytes);
}

/// Certificate of Deposit service
class CDService {
  final FuegoSDK _sdk;

  CDService(this._sdk);

  /// Create a new CD
  /// 
  /// [amount] - Amount to deposit in atomic units
  /// [lockTime] - Lock time in seconds
  /// [walletFile] - Path to wallet file
  /// [walletPassword] - Wallet password
  Future<CDInfo> create({
    required int amount,
    required int lockTime,
    required String walletFile,
    required String walletPassword,
  }) async {
    final walletFilePtr = walletFile.toNativeUtf8();
    final passwordPtr = walletPassword.toNativeUtf8();
    final cdInfoPtr = calloc<FuegoCDInfo>();

    try {
      final result = _sdk.bindings.fuego_cd_create(
        amount,
        lockTime,
        walletFilePtr.cast(),
        passwordPtr.cast(),
        cdInfoPtr,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to create CD: ${FuegoError.fromCode(result)}');
      }

      return CDInfo._fromNative(cdInfoPtr.ref);
    } finally {
      calloc.free(walletFilePtr);
      calloc.free(passwordPtr);
      calloc.free(cdInfoPtr);
    }
  }

  /// Redeem a CD
  Future<int> redeem({
    required String txHash,
    required String walletFile,
    required String walletPassword,
  }) async {
    final txHashPtr = txHash.toNativeUtf8();
    final walletFilePtr = walletFile.toNativeUtf8();
    final passwordPtr = walletPassword.toNativeUtf8();
    final redeemedAmountPtr = calloc<Uint64>();

    try {
      final result = _sdk.bindings.fuego_cd_redeem(
        txHashPtr.cast(),
        walletFilePtr.cast(),
        passwordPtr.cast(),
        redeemedAmountPtr,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to redeem CD: ${FuegoError.fromCode(result)}');
      }

      return redeemedAmountPtr.value;
    } finally {
      calloc.free(txHashPtr);
      calloc.free(walletFilePtr);
      calloc.free(passwordPtr);
      calloc.free(redeemedAmountPtr);
    }
  }

  /// Get CD info
  Future<CDInfo> getInfo(String txHash) async {
    final txHashPtr = txHash.toNativeUtf8();
    final cdInfoPtr = calloc<FuegoCDInfo>();

    try {
      final result = _sdk.bindings.fuego_cd_get_info(
        txHashPtr.cast(),
        cdInfoPtr,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to get CD info: ${FuegoError.fromCode(result)}');
      }

      return CDInfo._fromNative(cdInfoPtr.ref);
    } finally {
      calloc.free(txHashPtr);
      calloc.free(cdInfoPtr);
    }
  }
}

/// CD information
class CDInfo {
  final int amount;
  final int interest;
  final int unlockTime;
  final String txHash;

  CDInfo({
    required this.amount,
    required this.interest,
    required this.unlockTime,
    required this.txHash,
  });

  CDInfo._fromNative(FuegoCDInfo native)
      : amount = native.amount,
        interest = native.interest,
        unlockTime = native.unlock_time,
        txHash = _array8ToStr(native.tx_hash);
}
