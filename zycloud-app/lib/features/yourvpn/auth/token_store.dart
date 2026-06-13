// lib/features/yourvpn/auth/token_store.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  static const _keyToken = 'yourvpn_token';
  static const _keyExpires = 'yourvpn_token_expires';

  final FlutterSecureStorage _storage;

  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<void> save(String token, DateTime expires) async {
    await Future.wait([
      _storage.write(key: _keyToken, value: token),
      _storage.write(key: _keyExpires, value: expires.toIso8601String()),
    ]);
  }

  Future<String?> readToken() => _storage.read(key: _keyToken);

  Future<DateTime?> readExpiry() async {
    final raw = await _storage.read(key: _keyExpires);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> delete() async {
    await Future.wait([
      _storage.delete(key: _keyToken),
      _storage.delete(key: _keyExpires),
    ]);
  }

  Future<bool> get isLoggedIn async {
    final token = await readToken();
    if (token == null || token.isEmpty) return false;
    final expiry = await readExpiry();
    if (expiry == null) return false;
    return expiry.isAfter(DateTime.now());
  }
}
