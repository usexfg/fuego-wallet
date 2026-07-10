import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../ffi/fuego_native.dart';

/// Manages HD wallet vault via native FFI.
/// Provides local address generation without walletd.
class FuegoVaultService {
  static const _vaultFileName = 'fuego_vault.bin';
  FuegoNative? _native;
  Uint8List? _vaultBytes;
  String? _cachedAddress;
  String? _spendPublicKey;
  String? _viewSecretKey;

  FuegoNative get _ffi {
    _native ??= FuegoNative();
    return _native!;
  }

  /// Initialize: load existing vault or generate new one.
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_vaultFileName');

    if (await file.exists()) {
      _vaultBytes = await file.readAsBytes();
      print('[vault] loaded existing vault (${_vaultBytes!.length} bytes)');
    } else {
      _vaultBytes = _ffi.vaultGenerate();
      await file.writeAsBytes(_vaultBytes!, flush: true);
      print('[vault] generated new vault (${_vaultBytes!.length} bytes)');
    }

    _cachedAddress = _ffi.vaultGetAddress(_vaultBytes!, 0);
    print('[vault] address: $_cachedAddress');

    // Derive and cache keypair info for output scanning
    // Index 0 = spend keypair, Index 1 = view keypair
    final spendKp = _ffi.vaultDeriveKeypair(_vaultBytes!, 0);
    _spendPublicKey = spendKp['public'] as String?;
    final viewKp = _ffi.vaultDeriveKeypair(_vaultBytes!, 1);
    _viewSecretKey = viewKp['secret'] as String?;
    print('[vault] spend_pub: ${_spendPublicKey?.substring(0, 16)}...');
    print('[vault] view_secret: ${_viewSecretKey?.substring(0, 16)}...');
  }

  /// Get wallet address (index 0).
  String get address => _cachedAddress ?? '';

  /// Get raw vault bytes.
  Uint8List? get vaultBytes => _vaultBytes;

  /// Hex-encoded spend public key (32 bytes).
  String? get spendPublicKey => _spendPublicKey;

  /// Hex-encoded view secret key (32 bytes).
  String? get viewSecretKey => _viewSecretKey;

  /// Derive keypair at index.
  Map<String, dynamic> deriveKeypair(int index) {
    return _ffi.vaultDeriveKeypair(_vaultBytes!, index);
  }

  /// Generate address from spend + view public keys.
  String makeAddress(List<int> spendPub, List<int> viewPub) {
    return _ffi.makeAddress(spendPub, viewPub);
  }

  /// Generate key derivation for scanning outputs.
  String generateKeyDerivation(List<int> key1, List<int> secret2) {
    return _ffi.generateKeyDerivation(key1, secret2);
  }

  /// Generate key image for spent detection.
  String generateKeyImage(List<int> pubkey, List<int> secret) {
    return _ffi.generateKeyImage(pubkey, secret);
  }

  /// Reverse key derivation: recover spend public key from output key.
  String underivePublicKey(List<int> derivation, int outputIndex, List<int> outputKey) {
    return _ffi.underivePublicKey(derivation, outputIndex, outputKey);
  }

  /// Sign a message with a 32-byte secret key.
  String sign(List<int> secret, List<int> message) {
    return _ffi.sign(secret, message);
  }

  /// Verify an Ed25519 signature.
  bool verify(List<int> pubkey, List<int> message, List<int> signature) {
    return _ffi.verify(pubkey, message, signature);
  }

  /// Base58-encode data (CryptoNote block-based encoding).
  String base58Encode(List<int> data) {
    return _ffi.base58Encode(data);
  }

  /// Get FuegoNative instance for direct access.
  FuegoNative get ffi => _ffi;
}
