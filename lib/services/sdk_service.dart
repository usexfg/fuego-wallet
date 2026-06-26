import 'dart:async';
import 'package:fuego_defi_sdk/fuego_defi_sdk.dart';
import 'package:logging/logging.dart';

final _log = Logger('SdkService');

class SdkService {
  SdkService({IKdfHostConfig? hostConfig}) {
    _sdk = FuegoDefiSdk(
      host: hostConfig,
      config: const FuegoDefiSdkConfig(
        preActivateHistoricalAssets: false,
        preActivateDefaultAssets: false,
      ),
      onLog: _handleSdkLog,
    );
  }

  late final FuegoDefiSdk _sdk;
  bool _isInitializing = false;
  final Completer<FuegoDefiSdk> _initCompleter = Completer<FuegoDefiSdk>();

  FuegoDefiSdk get sdk => _sdk;

  Future<bool> isSignedIn() => _sdk.auth.isSignedIn();

  Future<FuegoDefiSdk> initialize() async {
    if (_initCompleter.isCompleted) return _sdk;
    if (_isInitializing) return _initCompleter.future;

    try {
      _isInitializing = true;
      await _sdk.initialize();
      _initCompleter.complete(_sdk);
      return _sdk;
    } catch (e) {
      _initCompleter.completeError(e);
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> dispose() async {
    try {
      await _sdk.dispose();
    } catch (e) {
      _log.warning('Error disposing SDK: $e');
    }
  }

  void _handleSdkLog(String message) {
    _log.fine(message);
  }
}
