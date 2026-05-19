import 'dart:ffi';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'fuego_sdk_bindings.dart';

/// Fuego SDK - Main entry point for Fuego blockchain functionality
class FuegoSDK {
  static FuegoSDK? _instance;
  late final FuegoSDKBindings _bindings;
  bool _initialized = false;

  FuegoSDK._internal();

  /// Get singleton instance
  static FuegoSDK get instance {
    _instance ??= FuegoSDK._internal();
    return _instance!;
  }

  /// Initialize the SDK
  /// 
  /// [dataDir] - Directory for blockchain data storage
  /// [testnet] - Use testnet if true
  Future<FuegoError> initialize({
    required String dataDir,
    bool testnet = false,
  }) async {
    if (_initialized) {
      return FuegoError.FUEGO_ERROR_INTERNAL;
    }

    _loadLibrary();

    final dataDirPtr = dataDir.toNativeUtf8();
    try {
      final result = _bindings.fuego_sdk_init(dataDirPtr.cast(), testnet ? 1 : 0);
      if (result == FuegoError.FUEGO_OK) {
        _initialized = true;
      }
      return result;
    } finally {
      calloc.free(dataDirPtr);
    }
  }

  /// Cleanup and release resources
  void cleanup() {
    if (_initialized) {
      _bindings.fuego_sdk_cleanup();
      _initialized = false;
    }
  }

  /// Get SDK version
  String get version {
    final versionPtr = _bindings.fuego_sdk_version();
    return versionPtr.cast<Utf8>().toDartString();
  }

  /// Load the native library based on platform
  void _loadLibrary() {
    String libraryPath;

    if (Platform.isAndroid) {
      libraryPath = 'libfuego_sdk.so';
    } else if (Platform.isIOS) {
      libraryPath = 'FuegoSDK.framework/FuegoSDK';
    } else if (Platform.isLinux) {
      libraryPath = 'libfuego_sdk.so';
    } else if (Platform.isMacOS) {
      libraryPath = 'libfuego_sdk.dylib';
    } else if (Platform.isWindows) {
      libraryPath = 'fuego_sdk.dll';
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }

    try {
      final lib = ffi.DynamicLibrary.open(libraryPath);
      _bindings = FuegoSDKBindings(lib);
    } catch (e) {
      throw Exception('Failed to load Fuego SDK library: $e');
    }
  }

  /// Check if SDK is initialized
  bool get isInitialized => _initialized;

  /// Get the bindings
  FuegoSDKBindings get bindings => _bindings;

  // ── Wallet Operations ────────────────────────────────────────

  /// Open a wallet file with password
  FuegoError walletOpen(String path, String password) {
    final pathPtr = path.toNativeUtf8();
    final passPtr = password.toNativeUtf8();
    try {
      return FuegoError.fromCode(_bindings.fuego_wallet_open(pathPtr, passPtr));
    } finally {
      calloc.free(pathPtr);
      calloc.free(passPtr);
    }
  }

  /// Close the open wallet
  void walletClose() => _bindings.fuego_wallet_close();

  /// Check if a wallet is currently open
  bool walletIsOpen() => _bindings.fuego_wallet_is_open() != 0;

  /// Get XFG balance (available, locked in atomic units)
  ({int available, int locked}) walletGetBalance() {
    final avail = calloc<ffi.Uint64>();
    final locked = calloc<ffi.Uint64>();
    try {
      _bindings.fuego_wallet_get_balance(avail, locked);
      return (available: avail.value, locked: locked.value);
    } finally {
      calloc.free(avail);
      calloc.free(locked);
    }
  }

  /// Get HEAT balance (available, locked in atomic units)
  ({int available, int locked}) walletGetHEATBalance() {
    final avail = calloc<ffi.Uint64>();
    final locked = calloc<ffi.Uint64>();
    try {
      _bindings.fuego_wallet_get_heat_balance(avail, locked);
      return (available: avail.value, locked: locked.value);
    } finally {
      calloc.free(avail);
      calloc.free(locked);
    }
  }

  /// Send a transaction (XFG or HEAT colored coin)
  ({FuegoError error, String txHash}) walletSend({
    required String address,
    required int amount,
    String? assetId,
    int fee = 0,
    String? paymentId,
  }) {
    final addrPtr = address.toNativeUtf8();
    final assetPtr = (assetId ?? '').toNativeUtf8();
    final payIdPtr = (paymentId ?? '').toNativeUtf8();
    final txHash = calloc<ffi.Char>(65);
    try {
      final err = _bindings.fuego_wallet_send(addrPtr, amount, assetPtr, fee, payIdPtr, txHash, 65);
      final hashStr = txHash.cast<Utf8>().toDartString();
      return (error: FuegoError.fromCode(err), txHash: hashStr);
    } finally {
      calloc.free(addrPtr);
      calloc.free(assetPtr);
      calloc.free(payIdPtr);
      calloc.free(txHash);
    }
  }

  /// Create a CD (HEAT deposit)
  ({FuegoError error, FuegoCDInfo info}) cdCreate({
    required int amount,
    required int lockTime,
    required String walletFile,
    required String walletPassword,
  }) {
    final wfPtr = walletFile.toNativeUtf8();
    final wpPtr = walletPassword.toNativeUtf8();
    final info = calloc<FuegoCDInfo>();
    try {
      final err = _bindings.fuego_cd_create(amount, lockTime, wfPtr, wpPtr, info);
      return (error: FuegoError.fromCode(err), info: info.ref);
    } finally {
      calloc.free(wfPtr);
      calloc.free(wpPtr);
      calloc.free(info);
    }
  }

  /// Redeem a CD
  ({FuegoError error, int redeemedAmount}) cdRedeem({
    required String txHash,
    required String walletFile,
    required String walletPassword,
  }) {
    final thPtr = txHash.toNativeUtf8();
    final wfPtr = walletFile.toNativeUtf8();
    final wpPtr = walletPassword.toNativeUtf8();
    final amount = calloc<ffi.Uint64>();
    try {
      final err = _bindings.fuego_cd_redeem(thPtr, wfPtr, wpPtr, amount);
      return (error: FuegoError.fromCode(err), redeemedAmount: amount.value);
    } finally {
      calloc.free(thPtr);
      calloc.free(wfPtr);
      calloc.free(wpPtr);
      calloc.free(amount);
    }
  }
}

/// Error codes from Fuego SDK
enum FuegoError {
  FUEGO_OK(0),
  FUEGO_ERROR_INTERNAL(1),
  FUEGO_ERROR_INVALID_PARAM(2),
  FUEGO_ERROR_NETWORK(3),
  FUEGO_ERROR_WALLET(4),
  FUEGO_ERROR_NODE(5),
  FUEGO_ERROR_MINING(6),
  FUEGO_ERROR_CD(7),
  FUEGO_ERROR_SWAP(8),
  FUEGO_ERROR_HEAT(9),
  FUEGO_ERROR_ALIAS(10),
  FUEGO_ERROR_MEMORY(11),
  FUEGO_ERROR_NOT_INITIALIZED(12);

  final int code;
  const FuegoError(this.code);

  static FuegoError fromCode(int code) {
    return FuegoError.values.firstWhere(
      (e) => e.code == code,
      orElse: () => FuegoError.FUEGO_ERROR_INTERNAL,
    );
  }

  bool get isSuccess => this == FuegoError.FUEGO_OK;
}

/// Node mode: embedded or remote
enum FuegoNodeMode {
  embedded,
  remote,
}
