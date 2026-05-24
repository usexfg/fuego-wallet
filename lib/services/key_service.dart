import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart' as crypto;

class KeyService {
  static const _networkPrefix = [0x1a, 0xc0, 0x67];
  static const _addressPrefix = 'fire';

  static const _base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  /// Derive all keys and address from a BIP39 mnemonic
  static Future<FuegoKeyPair> deriveFromMnemonic(String mnemonic) async {
    final seed = bip39.mnemonicToSeed(mnemonic);
    return deriveFromSeed(seed);
  }

  /// Derive keys and address from a seed (64 bytes from BIP39)
  static Future<FuegoKeyPair> deriveFromSeed(String seedHex) async {
    final seed = Uint8List.fromList(
      List.generate(seedHex.length ~/ 2, (i) =>
        int.parse(seedHex.substring(i * 2, i * 2 + 2), radix: 16)),
    );
    return _derive(seed);
  }

  /// Core derivation
  static Future<FuegoKeyPair> _derive(Uint8List seed) async {
    final ed25519 = Ed25519();

    final spendPrivateBytes = crypto.sha512
        .convert(utf8.encode('fuego_spend_key') + seed)
        .bytes
        .sublist(0, 32);

    final viewPrivateBytes = crypto.sha512
        .convert(utf8.encode('fuego_view_key') + spendPrivateBytes)
        .bytes
        .sublist(0, 32);

    final spendKeyPair = await ed25519.newKeyPairFromSeed(
      SecretKey(spendPrivateBytes),
    );
    final spendPub = await spendKeyPair.extractPublicKey();

    final viewKeyPair = await ed25519.newKeyPairFromSeed(
      SecretKey(viewPrivateBytes),
    );
    final viewPub = await viewKeyPair.extractPublicKey();

    final spendPubBytes = spendPub.bytes;
    final viewPubBytes = viewPub.bytes;

    final address = _buildAddress(spendPubBytes, viewPubBytes);

    return FuegoKeyPair(
      spendPrivateKey: _bytesToHex(spendPrivateBytes),
      viewPrivateKey: _bytesToHex(viewPrivateBytes),
      spendPublicKey: _bytesToHex(spendPubBytes),
      viewPublicKey: _bytesToHex(viewPubBytes),
      address: address,
    );
  }

  /// Build a Fuego address from public keys
  static String _buildAddress(List<int> spendPub, List<int> viewPub) {
    final data = <int>[
      ..._networkPrefix,
      ...spendPub,
      ...viewPub,
    ];

    final hash = crypto.sha256.convert(data).bytes;
    final checksum = hash.sublist(0, 4);

    final withChecksum = [...data, ...checksum];
    final base58 = _base58Encode(withChecksum);

    return '$_addressPrefix$base58';
  }

  /// Validate a Fuego address format
  static bool validateAddress(String address) {
    if (address.length != 100) return false;
    if (!address.startsWith(_addressPrefix)) return false;

    final base58Part = address.substring(4);
    if (base58Part.length != 96) return false;

    try {
      final decoded = _base58Decode(base58Part);
      if (decoded.length < 5) return false;

      final data = decoded.sublist(0, decoded.length - 4);
      final expectedChecksum = decoded.sublist(decoded.length - 4);

      final hash = crypto.sha256.convert(data).bytes;
      final actualChecksum = hash.sublist(0, 4);

      for (int i = 0; i < 4; i++) {
        if (expectedChecksum[i] != actualChecksum[i]) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _base58Encode(List<int> bytes) {
    final zeroCount = bytes.takeWhile((b) => b == 0).length;

    BigInt number = BigInt.zero;
    for (int i = 0; i < bytes.length; i++) {
      number = number * BigInt.from(256) + BigInt.from(bytes[i]);
    }

    final result = StringBuffer();
    while (number > BigInt.zero) {
      final remainder = number % BigInt.from(58);
      number = number ~/ BigInt.from(58);
      result.write(_base58Alphabet[remainder.toInt()]);
    }

    for (int i = 0; i < zeroCount; i++) {
      result.write('1');
    }

    return result.toString().split('').reversed.join();
  }

  static List<int> _base58Decode(String encoded) {
    BigInt number = BigInt.zero;
    for (int i = 0; i < encoded.length; i++) {
      final digit = _base58Alphabet.indexOf(encoded[i]);
      if (digit < 0) throw FormatException('Invalid base58 character');
      number = number * BigInt.from(58) + BigInt.from(digit);
    }

    final bytes = <int>[];
    while (number > BigInt.zero) {
      bytes.insert(0, (number % BigInt.from(256)).toInt());
      number = number ~/ BigInt.from(256);
    }

    final ones = encoded.takeWhile((c) => c == '1').length;
    bytes.insertAll(0, List.filled(ones, 0));

    return bytes;
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }
}

class FuegoKeyPair {
  final String spendPrivateKey;
  final String viewPrivateKey;
  final String spendPublicKey;
  final String viewPublicKey;
  final String address;

  FuegoKeyPair({
    required this.spendPrivateKey,
    required this.viewPrivateKey,
    required this.spendPublicKey,
    required this.viewPublicKey,
    required this.address,
  });

  Map<String, dynamic> toJson() => {
        'spendPrivateKey': spendPrivateKey,
        'viewPrivateKey': viewPrivateKey,
        'spendPublicKey': spendPublicKey,
        'viewPublicKey': viewPublicKey,
        'address': address,
      };
}
