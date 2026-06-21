import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import '../models/wallet.dart';

/// Stub for native crypto FFI bindings.
/// When the fuego native library is available, these functions call through FFI.
/// For now they throw UnsupportedError — the wallet uses the SDK/RPC path instead.
class NativeCrypto {
  NativeCrypto._();

  static bool get isAvailable => false;

  static Future<bool> init() async => false;

  static Map<String, Uint8List>? generateKeys() => null;

  static String? generateAddress(Uint8List publicSpendKey, Uint8List publicViewKey, String prefix) => null;

  static Uint8List? generatePublicKey(Uint8List privateKey) => null;
}

class FuegoWalletAdapterNative {
  static FuegoWalletAdapterNative? _instance;

  static FuegoWalletAdapterNative get instance {
    _instance ??= FuegoWalletAdapterNative._internal();
    return _instance!;
  }

  bool _isSynchronized = false;
  bool _isOpen = false;
  Wallet? _wallet;

  FuegoWalletAdapterNative._internal();

  /// Attempt to load the native crypto library. Returns true if available.
  Future<bool> initNativeCrypto() async {
    try {
      final result = await NativeCrypto.init();
      return result;
    } catch (e) {
      debugPrint('initNativeCrypto failed: $e');
      return false;
    }
  }

  static bool get isAvailable => NativeCrypto.isAvailable;

  bool get isOpen => _isOpen;
  bool get isSynchronized => _isSynchronized;

  Wallet? get wallet => _wallet;

  /// Create a new wallet using native key generation.
  Future<bool> createWalletNative({String? password, Function(WalletEvent)? onEvent}) async {
    if (!isAvailable) {
      onEvent?.call(WalletEvent(WalletEventType.creationFailed, message: 'Native crypto library not available'));
      return false;
    }

    try {
      final keys = NativeCrypto.generateKeys();
      if (keys == null) {
        onEvent?.call(WalletEvent(WalletEventType.creationFailed, message: 'Key generation failed'));
        return false;
      }

      final address = NativeCrypto.generateAddress(
        keys['public_spend_key']!,
        keys['public_view_key']!,
        'fg',
      );
      if (address == null) {
        onEvent?.call(WalletEvent(WalletEventType.creationFailed, message: 'Address generation failed'));
        return false;
      }

      _wallet = Wallet(
        address: address,
        viewKey: String.fromCharCodes(keys['private_view_key']!),
        spendKey: String.fromCharCodes(keys['private_spend_key']!),
        balance: 0,
        unlockedBalance: 0,
        blockchainHeight: 0,
        localHeight: 0,
        synced: false,
      );
      _isOpen = true;
      _isSynchronized = false;
      onEvent?.call(WalletEvent(WalletEventType.created));
      return true;
    } catch (e) {
      debugPrint('createWalletNative failed: $e');
      onEvent?.call(WalletEvent(WalletEventType.creationFailed, message: 'Creation failed: $e'));
      return false;
    }
  }

  /// Import a wallet from existing view and spend keys.
  Future<bool> createWithKeysNative({required String viewKey, required String spendKey, String? password, Function(WalletEvent)? onEvent}) async {
    if (!isAvailable) {
      onEvent?.call(WalletEvent(WalletEventType.openFailed, message: 'Native crypto library not available'));
      return false;
    }

    try {
      // Derive public keys from private keys
      final viewPrivBytes = Uint8List.fromList(viewKey.codeUnits);
      final spendPrivBytes = Uint8List.fromList(spendKey.codeUnits);

      final viewPubBytes = NativeCrypto.generatePublicKey(viewPrivBytes);
      final spendPubBytes = NativeCrypto.generatePublicKey(spendPrivBytes);

      if (viewPubBytes == null || spendPubBytes == null) {
        onEvent?.call(WalletEvent(WalletEventType.openFailed, message: 'Failed to derive public keys'));
        return false;
      }

      final address = NativeCrypto.generateAddress(spendPubBytes, viewPubBytes, 'fg');
      if (address == null) {
        onEvent?.call(WalletEvent(WalletEventType.openFailed, message: 'Address generation failed'));
        return false;
      }

      _wallet = Wallet(
        address: address,
        viewKey: viewKey,
        spendKey: spendKey,
        balance: 0,
        unlockedBalance: 0,
        blockchainHeight: 0,
        localHeight: 0,
        synced: false,
      );
      _isOpen = true;
      _isSynchronized = false;
      onEvent?.call(WalletEvent(WalletEventType.opened));
      return true;
    } catch (e) {
      debugPrint('createWithKeysNative failed: $e');
      onEvent?.call(WalletEvent(WalletEventType.openFailed, message: 'Import failed: $e'));
      return false;
    }
  }

  /// Send a transaction. Native signing is not yet implemented — delegates to SDK.
  Future<String> sendTransactionNative({required Map<String, int> destinations, int? fee, String? paymentId, int mixin = 4}) async {
    throw UnsupportedError(
      'Native transaction signing is not yet implemented. '
      'Use FuegoSDKService.send() or the wallet RPC adapter instead.',
    );
  }

  Future<void> close() async {
    _isOpen = false;
    _isSynchronized = false;
  }

  void dispose() {
    _instance = null;
  }
}

class WalletEvent {
  final WalletEventType type;
  final String? message;
  final Map<String, dynamic>? data;

  WalletEvent(this.type, {this.message, this.data});

  factory WalletEvent.created() => WalletEvent(WalletEventType.created);
  factory WalletEvent.opened() => WalletEvent(WalletEventType.opened);
  factory WalletEvent.closed() => WalletEvent(WalletEventType.closed);
  factory WalletEvent.creationFailed(String message) => WalletEvent(WalletEventType.creationFailed, message: message);
  factory WalletEvent.openFailed(String message) => WalletEvent(WalletEventType.openFailed, message: message);
  factory WalletEvent.synchronizationProgress(int current, int total) =>
    WalletEvent(WalletEventType.synchronizationProgress, data: {'current': current, 'total': total});
}

enum WalletEventType {
  opened,
  openFailed,
  created,
  creationFailed,
  closed,
  transactionCreated,
  depositCreated,
  depositWithdrawalCreated,
  synchronizationProgress,
}
