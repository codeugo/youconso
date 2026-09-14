import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _storage = FlutterSecureStorage();
  static const _kToken = 'user_token';
  static const _kPublicKey = 'public_key';
  static const _kUsername = 'username';
  static const _kPassword = 'password';

  Future<String?> get token => _storage.read(key: _kToken);
  Future<String?> get publicKey => _storage.read(key: _kPublicKey);
  Future<String?> get username => _storage.read(key: _kUsername);
  Future<String?> get password => _storage.read(key: _kPassword);

  Future<void> saveSession({
    required String token,
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kUsername, value: username);
    await _storage.write(key: _kPassword, value: password);
  }

  Future<void> setPublicKey(String publicKey) =>
      _storage.write(key: _kPublicKey, value: publicKey);

  Future<void> clearSession() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kPassword);
  }
}
