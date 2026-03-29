import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyExpiresAt = 'expires_at';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    final expiresAt =
        DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch;
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
      _storage.write(key: _keyExpiresAt, value: expiresAt.toString()),
    ]);
  }

  Future<
      ({
        String? accessToken,
        String? refreshToken,
        DateTime? expiresAt,
      })> load() async {
    final results = await Future.wait([
      _storage.read(key: _keyAccessToken),
      _storage.read(key: _keyRefreshToken),
      _storage.read(key: _keyExpiresAt),
    ]);
    final expiresAtMs = results[2];
    return (
      accessToken: results[0],
      refreshToken: results[1],
      expiresAt: expiresAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(expiresAtMs))
          : null,
    );
  }

  Future<void> clear() => _storage.deleteAll();
}
