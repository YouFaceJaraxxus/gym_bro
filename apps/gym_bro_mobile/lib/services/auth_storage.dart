import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_profile.dart';

class AuthStorage {
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyExpiresAt = 'expires_at';
  static const _keyProfile = 'user_profile';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
    UserProfile? profile,
  }) async {
    final expiresAt =
        DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch;
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
      _storage.write(key: _keyExpiresAt, value: expiresAt.toString()),
      if (profile != null)
        _storage.write(key: _keyProfile, value: jsonEncode(profile.toJson())),
    ]);
  }

  Future<void> saveProfile(UserProfile profile) =>
      _storage.write(key: _keyProfile, value: jsonEncode(profile.toJson()));

  Future<
      ({
        String? accessToken,
        String? refreshToken,
        DateTime? expiresAt,
        UserProfile? profile,
      })> load() async {
    final results = await Future.wait([
      _storage.read(key: _keyAccessToken),
      _storage.read(key: _keyRefreshToken),
      _storage.read(key: _keyExpiresAt),
      _storage.read(key: _keyProfile),
    ]);
    final expiresAtMs = results[2];
    final profileJson = results[3];
    return (
      accessToken: results[0],
      refreshToken: results[1],
      expiresAt: expiresAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(expiresAtMs))
          : null,
      profile: profileJson != null
          ? UserProfile.fromJson(jsonDecode(profileJson) as Map<String, dynamic>)
          : null,
    );
  }

  Future<void> clear() => _storage.deleteAll();
}
