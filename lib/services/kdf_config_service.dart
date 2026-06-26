import 'package:shared_preferences/shared_preferences.dart';

/// Persists KDF server connection settings so the app can connect
/// to a remote KDF instance for DEX functionality.
class KdfConfigService {
  static const _kHostKey = 'kdf_host';
  static const _kPortKey = 'kdf_port';
  static const _kHttpsKey = 'kdf_https';
  static const _kPasswordKey = 'kdf_rpc_password';

  static const defaultHost = '';
  static const defaultPort = 7783;
  static const defaultHttps = false;

  Future<String> getHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kHostKey) ?? defaultHost;
  }

  Future<int> getPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kPortKey) ?? defaultPort;
  }

  Future<bool> getHttps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kHttpsKey) ?? defaultHttps;
  }

  Future<String> getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPasswordKey) ?? '';
  }

  Future<bool> isConfigured() async {
    final host = await getHost();
    return host.isNotEmpty;
  }

  Future<void> save({
    required String host,
    required int port,
    required bool https,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHostKey, host);
    await prefs.setInt(_kPortKey, port);
    await prefs.setBool(_kHttpsKey, https);
    await prefs.setString(_kPasswordKey, password);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHostKey);
    await prefs.remove(_kPortKey);
    await prefs.remove(_kHttpsKey);
    await prefs.remove(_kPasswordKey);
  }
}
