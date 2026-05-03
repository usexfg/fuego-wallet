import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fuego_sdk/fuego_sdk.dart' as sdk;

/// Flutter plugin for Fuego SDK
class FuegoSDKPlugin {
  static const MethodChannel _channel = MethodChannel('fuego_sdk');

  static FuegoSDKPlugin? _instance;
  late sdk.FuegoSDK _sdk;

  FuegoSDKPlugin._internal();

  static FuegoSDKPlugin get instance {
    _instance ??= FuegoSDKPlugin._internal();
    return _instance!;
  }

  /// Initialize the plugin
  Future<sdk.FuegoError> initialize({
    required String dataDir,
    bool testnet = false,
  }) async {
    _sdk = sdk.FuegoSDK.instance;
    return await _sdk.initialize(dataDir: dataDir, testnet: testnet);
  }

  /// Cleanup resources
  void cleanup() {
    _sdk.cleanup();
  }

  /// Node service
  sdk.NodeService get node => sdk.NodeService(_sdk);

  /// Mining service
  sdk.MiningService get mining => sdk.MiningService(_sdk);

  /// CD service
  sdk.CDService get cd => sdk.CDService(_sdk);

  /// Swap service
  sdk.SwapService get swap => sdk.SwapService(_sdk);

  /// HEAT service
  sdk.HEATService get heat => sdk.HEATService(_sdk);

  /// Alias service
  sdk.AliasService get alias => sdk.AliasService(_sdk);

  /// Get SDK version
  String get version => _sdk.version;

  /// Check if initialized
  bool get isInitialized => _sdk.isInitialized;
}
