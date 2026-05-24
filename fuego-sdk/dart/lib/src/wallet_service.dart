import 'fuego_sdk.dart';

/// High-level wallet service wrapping FuegoSDK wallet operations
class WalletService {
  final FuegoSDK _sdk;

  WalletService(this._sdk);

  /// Open a wallet file
  FuegoError open(String path, String password) {
    return _sdk.walletOpen(path, password);
  }

  /// Close the current wallet
  void close() => _sdk.walletClose();

  /// Check if a wallet is open
  bool get isOpen => _sdk.walletIsOpen();

  /// Get XFG balance in atomic units
  ({int available, int locked}) getXfgBalance() {
    return _sdk.walletGetBalance();
  }

  /// Get XFG balance as double (XFG units)
  double get xfgAvailable => getXfgBalance().available / 10000000.0;
  double get xfgLocked => getXfgBalance().locked / 10000000.0;

  /// Get HEAT balance in atomic units
  ({int available, int locked}) getHeatBalance() {
    return _sdk.walletGetHEATBalance();
  }

  /// Get HEAT balance as double (HEAT units)
  double get heatAvailable => getHeatBalance().available / 10000000.0;
  double get heatLocked => getHeatBalance().locked / 10000000.0;

  /// Send XFG or HEAT
  ({String txHash, FuegoError error}) send({
    required String address,
    required double amount,
    String? assetId,
    double fee = 0.01,
    String? paymentId,
  }) {
    final atomicAmount = (amount * 10000000).round();
    final atomicFee = (fee * 10000000).round();
    return _sdk.walletSend(
      address: address,
      amount: atomicAmount,
      assetId: assetId,
      fee: atomicFee,
      paymentId: paymentId,
    );
  }
}
