import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../ffi/fuego_native.dart';
import 'security_service.dart';

/// HD wallet vault via native FFI.
///
/// Vault bytes are encrypted at rest with a PIN-derived key. Secrets are only
/// available after [unlockWithPin] or [unlockWithBiometricKey]. Never auto-creates
/// an unlocked vault on cold start.
class FuegoVaultService {
  static const _vaultFileName = 'fuego_vault.enc';
  static const _legacyVaultFileName = 'fuego_vault.bin';
  static const _metaFileName = 'fuego_vault.meta';

  final SecurityService _security;
  FuegoNative? _native;
  Uint8List? _vaultBytes;
  String? _cachedAddress;
  String? _spendPublicKey;
  String? _viewSecretKey;
  bool _unlocked = false;
  bool _existsOnDisk = false;

  FuegoVaultService({SecurityService? security})
      : _security = security ?? SecurityService();

  FuegoNative get _ffi {
    _native ??= FuegoNative();
    return _native!;
  }

  bool get isUnlocked => _unlocked && _vaultBytes != null;
  bool get existsOnDisk => _existsOnDisk;
  String get address => _unlocked ? (_cachedAddress ?? '') : '';
  Uint8List? get vaultBytes => _unlocked ? _vaultBytes : null;
  String? get spendPublicKey => _unlocked ? _spendPublicKey : null;
  String? get viewSecretKey => _unlocked ? _viewSecretKey : null;

  /// Probe disk only — does not load or generate secrets.
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final enc = File('${dir.path}/$_vaultFileName');
    final legacy = File('${dir.path}/$_legacyVaultFileName');
    _existsOnDisk = await enc.exists() || await legacy.exists();
  }

  /// Create a new vault from secure entropy, encrypt with [pin], store keys.
  Future<String> createNew({required String pin, String? mnemonic}) async {
    final phrase = mnemonic ?? SecurityService.generateMnemonic();
    if (!SecurityService.validateMnemonic(phrase)) {
      throw ArgumentError('Invalid BIP39 mnemonic');
    }
    await _security.setPIN(pin);
    await _security.storeWalletSeed(phrase, pin);

    final seed32 = SecurityService.mnemonicToVaultSeed(phrase);
    final bytes = _ffi.vaultFromSeed(seed32);
    if (bytes.isEmpty) {
      // Fallback if FFI seed path fails — generate and require backup of seed
      throw StateError('Failed to create vault from seed via FFI');
    }
    await _persistEncrypted(bytes, pin);
    await _loadInMemory(bytes);
    await _storeDerivedKeys(pin);
    await _maybeStoreBiometricUnwrap(pin);
    _existsOnDisk = true;
    return phrase;
  }

  /// Restore vault from BIP39 mnemonic.
  Future<void> restoreFromMnemonic({
    required String mnemonic,
    required String pin,
  }) async {
    if (!SecurityService.validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid BIP39 mnemonic');
    }
    await createNew(pin: pin, mnemonic: mnemonic.trim());
  }

  /// Unlock encrypted vault with PIN.
  Future<bool> unlockWithPin(String pin) async {
    final ok = await _security.verifyPIN(pin);
    if (!ok) return false;

    final dir = await getApplicationDocumentsDirectory();
    final encFile = File('${dir.path}/$_vaultFileName');
    final legacy = File('${dir.path}/$_legacyVaultFileName');

    Uint8List plain;
    if (await encFile.exists()) {
      final payload = await encFile.readAsString();
      plain = await _security.decryptBytesWithPin(payload, pin);
    } else if (await legacy.exists()) {
      // One-time migration of plaintext legacy vault
      plain = await legacy.readAsBytes();
      await _persistEncrypted(plain, pin);
      try {
        await legacy.delete();
      } catch (_) {}
    } else {
      throw StateError('No vault on disk');
    }

    await _loadInMemory(plain);
    await _maybeStoreBiometricUnwrap(pin);
    return true;
  }

  /// Unlock using biometric-gated unwrap key (after [authenticateWithBiometrics]).
  Future<bool> unlockWithBiometricKey() async {
    final key = await _security.getVaultUnwrapKey();
    if (key == null) return false;

    final dir = await getApplicationDocumentsDirectory();
    final encFile = File('${dir.path}/$_vaultFileName');
    if (!await encFile.exists()) return false;

    final payload = await encFile.readAsString();
    // Payload is PIN-encrypted; for biometric we store a second envelope.
    final bioFile = File('${dir.path}/$_vaultFileName.bio');
    if (await bioFile.exists()) {
      final bioPayload = await bioFile.readAsString();
      final plain = await _security.decryptBytesWithKey(bioPayload, key);
      await _loadInMemory(plain);
      return true;
    }

    // Fallback: unwrap key is the PIN-derived data key — re-decrypt pin payload
    try {
      final decoded =
          json.decode(utf8.decode(base64Decode(payload))) as Map<String, dynamic>;
      // Reconstruct SecretKey path via raw AES with stored unwrap key
      final plain = await _security.decryptBytesWithKey(
        // rebuild rawkey-shaped blob from pin blob fields
        base64Encode(utf8.encode(json.encode({
          'v': 1,
          'iv': decoded['iv'],
          'data': decoded['data'],
          'mac': decoded['mac'],
          'mode': 'rawkey',
        }))),
        key,
      );
      await _loadInMemory(plain);
      return true;
    } catch (e) {
      debugPrint('Vault biometric unlock failed');
      return false;
    }
  }

  /// Wipe secrets from memory (does not delete disk).
  void lock() {
    _vaultBytes = null;
    _cachedAddress = null;
    _spendPublicKey = null;
    _viewSecretKey = null;
    _unlocked = false;
  }

  /// Delete vault from disk and clear secure wallet material.
  Future<void> wipe() async {
    lock();
    final dir = await getApplicationDocumentsDirectory();
    for (final name in [
      _vaultFileName,
      '$_vaultFileName.bio',
      _legacyVaultFileName,
      _metaFileName,
    ]) {
      final f = File('${dir.path}/$name');
      if (await f.exists()) {
        await f.delete();
      }
    }
    await _security.clearWalletData();
    _existsOnDisk = false;
  }

  /// Mnemonic / seed hex — only when unlocked. Requires prior auth by caller.
  String? getSeed() {
    if (!isUnlocked || _vaultBytes == null) return null;
    return _ffi.vaultGetSeed(_vaultBytes!);
  }

  Map<String, dynamic> deriveKeypair(int index) {
    _requireUnlocked();
    return _ffi.vaultDeriveKeypair(_vaultBytes!, index);
  }

  String makeAddress(List<int> spendPub, List<int> viewPub) {
    return _ffi.makeAddress(spendPub, viewPub);
  }

  String generateKeyDerivation(List<int> key1, List<int> secret2) {
    _requireUnlocked();
    return _ffi.generateKeyDerivation(key1, secret2);
  }

  String generateKeyImage(List<int> pubkey, List<int> secret) {
    _requireUnlocked();
    return _ffi.generateKeyImage(pubkey, secret);
  }

  String underivePublicKey(
    List<int> derivation,
    int outputIndex,
    List<int> outputKey,
  ) {
    _requireUnlocked();
    return _ffi.underivePublicKey(derivation, outputIndex, outputKey);
  }

  String sign(List<int> secret, List<int> message) {
    _requireUnlocked();
    return _ffi.sign(secret, message);
  }

  bool verify(List<int> pubkey, List<int> message, List<int> signature) {
    return _ffi.verify(pubkey, message, signature);
  }

  String base58Encode(List<int> data) => _ffi.base58Encode(data);

  FuegoNative get ffi => _ffi;

  // ── Internals ────────────────────────────────────────────────────────

  void _requireUnlocked() {
    if (!isUnlocked || _vaultBytes == null) {
      throw StateError('Vault is locked');
    }
  }

  Future<void> _persistEncrypted(Uint8List plain, String pin) async {
    final dir = await getApplicationDocumentsDirectory();
    final enc = await _security.encryptBytesWithPin(plain, pin);
    await File('${dir.path}/$_vaultFileName').writeAsString(enc, flush: true);

    // Biometric re-entry envelope using PIN-derived key bytes as unwrap key
    final keyBytes = await _security.extractDataKeyBytes(pin);
    final bio = await _security.encryptBytesWithKey(plain, keyBytes);
    await File('${dir.path}/$_vaultFileName.bio').writeAsString(bio, flush: true);
  }

  Future<void> _loadInMemory(Uint8List bytes) async {
    _vaultBytes = bytes;
    _cachedAddress = _ffi.vaultGetAddress(bytes, 0);
    final spendKp = _ffi.vaultDeriveKeypair(bytes, 0);
    _spendPublicKey = spendKp['public'] as String?;
    final viewKp = _ffi.vaultDeriveKeypair(bytes, 1);
    _viewSecretKey = viewKp['secret'] as String?;
    _unlocked = true;
    // Intentionally no logging of address/keys
  }

  Future<void> _storeDerivedKeys(String pin) async {
    final spend = deriveKeypair(0);
    final view = deriveKeypair(1);
    final spendSecret = spend['secret'] as String? ?? '';
    final viewSecret = view['secret'] as String? ?? '';
    if (spendSecret.isEmpty || viewSecret.isEmpty) {
      throw StateError('Failed to derive vault keys');
    }
    await _security.storeWalletKeys(
      viewKey: viewSecret,
      spendKey: spendSecret,
      pin: pin,
    );
  }

  Future<void> _maybeStoreBiometricUnwrap(String pin) async {
    if (await _security.isBiometricEnabled()) {
      final keyBytes = await _security.extractDataKeyBytes(pin);
      await _security.storeVaultUnwrapKey(keyBytes);
    }
  }
}
