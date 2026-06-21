import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cryptography/cryptography.dart';
import 'package:bip39/bip39.dart' as bip39;

class SecurityService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _pinKey = 'wallet_pin_hash';
  static const String _seedKey = 'wallet_seed';
  static const String _keysKey = 'wallet_keys';
  static const String _biometricKey = 'biometric_enabled';

  // PIN Management
  Future<bool> setPIN(String pin) async {
    try {
      final salt = _generateSalt();
      final hashedPin = await _hashPIN(pin, salt);
      await _storage.write(key: _pinKey, value: '$salt:$hashedPin');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> verifyPIN(String pin) async {
    try {
      final stored = await _storage.read(key: _pinKey);
      if (stored == null) return false;
      
      final parts = stored.split(':');
      if (parts.length != 2) return false;
      
      final salt = parts[0];
      final storedHash = parts[1];
      final inputHash = await _hashPIN(pin, salt);
      
      return storedHash == inputHash;
    } catch (e) {
      return false;
    }
  }

  Future<bool> hasPIN() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<bool> removePIN() async {
    try {
      await _storage.delete(key: _pinKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Biometric Authentication
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  Future<bool> authenticateWithBiometrics({
    String reason = 'Please authenticate to access your wallet',
  }) async {
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      
      return isAuthenticated;
    } catch (e) {
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricKey, value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    final enabled = await _storage.read(key: _biometricKey);
    return enabled == 'true';
  }

  // Wallet Data Security
  String? get walletPath => _walletPath;
  String? get walletPassword => _walletPassword;
  static const String _walletPathKey = 'wallet_file_path';
  static const String _walletPasswordKey = 'wallet_password';

  Future<void> setWalletPath(String path) async {
    _walletPath = path;
    await _storage.write(key: _walletPathKey, value: path);
  }

  Future<void> setWalletPassword(String password) async {
    _walletPassword = password;
    await _storage.write(key: _walletPasswordKey, value: password);
  }

  String? _walletPath;
  String? _walletPassword;

  Future<bool> storeWalletSeed(String mnemonic, String pin) async {
    try {
      final encrypted = await _encryptData(mnemonic, pin);
      await _storage.write(key: _seedKey, value: encrypted);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getWalletSeed(String pin) async {
    try {
      final encrypted = await _storage.read(key: _seedKey);
      if (encrypted == null) return null;
      
      return await _decryptData(encrypted, pin);
    } catch (e) {
      return null;
    }
  }

  Future<bool> storeWalletKeys({
    required String viewKey,
    required String spendKey,
    String? address,
    required String pin,
  }) async {
    try {
      final keysJson = json.encode({
        'viewKey': viewKey,
        'spendKey': spendKey,
        if (address != null) 'address': address,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      final encrypted = await _encryptData(keysJson, pin);
      await _storage.write(key: _keysKey, value: encrypted);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, String>?> getWalletKeys(String pin) async {
    try {
      final encrypted = await _storage.read(key: _keysKey);
      if (encrypted == null) return null;
      
      final decrypted = await _decryptData(encrypted, pin);
      final keysData = json.decode(decrypted) as Map<String, dynamic>;
      
      return {
        'viewKey': keysData['viewKey'] as String,
        'spendKey': keysData['spendKey'] as String,
        if (keysData['address'] != null)
          'address': keysData['address'] as String,
      };
    } catch (e) {
      return null;
    }
  }

  Future<bool> hasWalletData() async {
    final seed = await _storage.read(key: _seedKey);
    final keys = await _storage.read(key: _keysKey);
    return (seed != null && seed.isNotEmpty) || (keys != null && keys.isNotEmpty);
  }

  Future<void> clearWalletData() async {
    await _storage.delete(key: _seedKey);
    await _storage.delete(key: _keysKey);
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _biometricKey);
  }

  // Private helper methods
  String _generateSalt() {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    return base64Encode(bytes);
  }

  Future<String> _hashPIN(String pin, String salt) async {
    final saltBytes = base64Decode(salt);
    final pinBytes = utf8.encode(pin);
    final combined = [...pinBytes, ...saltBytes];
    
    // Use PBKDF2 for key derivation
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac(Sha256()),
      iterations: 100000,
      bits: 256,
    );
    
    final secretKey = await algorithm.deriveKey(
      secretKey: SecretKey(combined),
      nonce: saltBytes.take(12).toList(),
    );
    
    final keyBytes = await secretKey.extractBytes();
    return base64Encode(keyBytes);
  }

  Future<String> _encryptData(String data, String pin) async {
    final algorithm = AesCbc.with256bits(macAlgorithm: Hmac(Sha256()));
    
    // Generate a random salt for this encryption
    final salt = _generateSalt();
    final secretKey = await _deriveKeyFromPIN(pin, salt);
    
    final encrypted = await algorithm.encrypt(
      utf8.encode(data),
      secretKey: secretKey,
    );
    
    final result = {
      'iv': base64Encode(encrypted.nonce),
      'data': base64Encode(encrypted.cipherText),
      'mac': base64Encode(encrypted.mac.bytes),
      'salt': salt, // Store the salt alongside the encrypted data
    };
    
    return base64Encode(utf8.encode(json.encode(result)));
  }

  Future<String> _decryptData(String encryptedData, String pin) async {
    final algorithm = AesCbc.with256bits(macAlgorithm: Hmac(Sha256()));
    
    final decoded = json.decode(utf8.decode(base64Decode(encryptedData))) 
        as Map<String, dynamic>;
        
    // Extract salt, fallback to old static salt behavior if not present
    final salt = decoded.containsKey('salt') ? decoded['salt'] as String : base64Encode(List<int>.filled(16, 42));
    final secretKey = await _deriveKeyFromPIN(pin, salt);
    
    final secretBox = SecretBox(
      base64Decode(decoded['data'] as String),
      nonce: base64Decode(decoded['iv'] as String),
      mac: Mac(base64Decode(decoded['mac'] as String)),
    );
    
    final decrypted = await algorithm.decrypt(secretBox, secretKey: secretKey);
    return utf8.decode(decrypted);
  }

  Future<SecretKey> _deriveKeyFromPIN(String pin, String saltBase64) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac(Sha256()),
      iterations: 100000,
      bits: 256,
    );
    
    final salt = base64Decode(saltBase64);
    
    return await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
  }

  // Utility methods for mnemonic generation
  static String generateMnemonic() {
    // Generate a secure 24-word bip39 mnemonic (256 bits of entropy)
    return bip39.generateMnemonic(strength: 256);
  }

  static bool validateMnemonic(String mnemonic) {
    if (bip39.validateMnemonic(mnemonic)) return true;
    final words = mnemonic.trim().split(RegExp(r'\s+'));
    if (words.length == 25) return true; // Accept 25-word Fuego/Monero seeds
    return false;
  }
}

enum AuthenticationMethod {
  pin,
  biometric,
  both,
}

class AuthenticationResult {
  final bool success;
  final AuthenticationMethod? method;
  final String? error;

  const AuthenticationResult({
    required this.success,
    this.method,
    this.error,
  });

  factory AuthenticationResult.success(AuthenticationMethod method) {
    return AuthenticationResult(success: true, method: method);
  }

  factory AuthenticationResult.failure(String error) {
    return AuthenticationResult(success: false, error: error);
  }
}