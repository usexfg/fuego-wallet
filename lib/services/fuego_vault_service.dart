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
  }

  /// Get wallet address (index 0).
  String get address => _cachedAddress ?? '';

  /// Get raw vault bytes.
  Uint8List? get vaultBytes => _vaultBytes;

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
}
