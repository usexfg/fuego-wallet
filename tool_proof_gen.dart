import 'dart:convert';
import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';

void main() {
  // Deterministic test key (privkey = 1) + fixed offerId
  const privHex = '0000000000000000000000000000000000000000000000000000000000000001';
  final credentials = EthPrivateKey.fromHex(privHex);
  final offerId = 'test-offer-1';
  final msg = Uint8List.fromList(utf8.encode(offerId));
  final sig = credentials.signPersonalMessageToUint8List(msg);
  final v = sig[64];
  final nv = (v < 27) ? (v + 27) : v;
  final hex = sig.sublist(0, 64).map((b) => b.toRadixString(16).padLeft(2, '0')).join() + nv.toRadixString(16).padLeft(2, '0');
  print('${credentials.address.hex}:$hex:$offerId');
  // Also print raw r/s/v for the C++ verifier
  print('SIG ${hex.substring(0,64)} ${hex.substring(64,128)} ${hex.substring(128)}');
}
