import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

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
