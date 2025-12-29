import 'dart:io';
import '../models/wallet.dart';
import '../models/network_config.dart';

class FuegoWalletAdapterNative {
  static FuegoWalletAdapterNative? _instance;

  static FuegoWalletAdapterNative get instance {
    _instance ??= FuegoWalletAdapterNative._internal();
    return _instance!;
  }

  bool _isSynchronized = false;
  bool _isOpen = false;

  FuegoWalletAdapterNative._internal();

  Future<bool> initNativeCrypto() async => false;

  static bool get isAvailable => false;

  bool get isOpen => _isOpen;
  bool get isSynchronized => _isSynchronized;

  Wallet? get wallet => null;

  Future<bool> createWalletNative({String? password, Function(WalletEvent)? onEvent}) async {
    _isOpen = true;
    _isSynchronized = true;
    onEvent?.call(WalletEvent(WalletEventType.created));
    return true;
  }

  Future<bool> createWithKeysNative({required String viewKey, required String spendKey, String? password, Function(WalletEvent)? onEvent}) async {
    _isOpen = true;
    _isSynchronized = true;
    onEvent?.call(WalletEvent(WalletEventType.opened));
    return true;
  }

  Future<String> sendTransactionNative({required Map<String, int> destinations, int? fee, String? paymentId, int mixin = 4}) async {
    return 'fallback_tx_${DateTime.now().millisecondsSinceEpoch}';
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
