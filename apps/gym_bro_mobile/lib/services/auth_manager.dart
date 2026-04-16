import '../models/user_profile.dart';
import 'auth_service.dart';
import 'auth_storage.dart';

/// Manages the current auth session and user profile across all sign-in providers.
class AuthManager {
  static final instance = AuthManager._();
  AuthManager._();

  final _storage = AuthStorage();
  final _authService = AuthService();

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  UserProfile? _profile;

  bool get hasSession => _accessToken != null && _refreshToken != null;
  UserProfile? get profile => _profile;

  /// Called on app start. Loads persisted tokens + profile and refreshes if expired.
  /// Returns true if a usable session was restored.
  Future<bool> tryRestoreSession() async {
    final stored = await _storage.load();
    if (stored.accessToken == null || stored.refreshToken == null) return false;

    _accessToken = stored.accessToken;
    _refreshToken = stored.refreshToken;
    _expiresAt = stored.expiresAt;
    _profile = stored.profile;

    if (_isExpired()) {
      try {
        await _doRefresh();
      } catch (_) {
        await clear();
        return false;
      }
    }

    // If profile wasn't in storage (e.g. session created before this version),
    // fetch it from the API. Non-fatal if it fails.
    if (_profile == null) {
      try {
        await _fetchAndStoreProfile();
      } catch (_) {}
    }

    return true;
  }

  /// Returns a valid access token, silently refreshing if it is about to expire.
  Future<String> getValidToken() async {
    if (!hasSession) throw Exception('No active session');
    if (_isExpired()) await _doRefresh();
    return _accessToken!;
  }

  /// Store a new session returned by any sign-in method.
  /// Pass [profileData] (the `profile` map from the API response) to persist
  /// the user profile alongside the session tokens.
  Future<void> setSession(
    Map<String, dynamic> data, {
    Map<String, dynamic>? profileData,
  }) async {
    _accessToken = data['access_token'] as String;
    _refreshToken = data['refresh_token'] as String;
    final expiresIn = (data['expires_in'] as num).toInt();
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    if (profileData != null) {
      _profile = UserProfile.fromJson(profileData);
    }
    await _storage.save(
      accessToken: _accessToken!,
      refreshToken: _refreshToken!,
      expiresIn: expiresIn,
      profile: _profile,
    );
  }

  /// Fetches the user profile from the API if it isn't already loaded.
  /// Call this after establishing a session from a deep link or any path
  /// that doesn't return profile data alongside the tokens.
  Future<void> ensureProfile() async {
    if (_profile == null && hasSession) {
      try {
        await _fetchAndStoreProfile();
      } catch (_) {}
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    _profile = profile;
    await _storage.saveProfile(profile);
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _profile = null;
    await _storage.clear();
  }

  bool _isExpired() {
    if (_expiresAt == null) return true;
    return DateTime.now().isAfter(_expiresAt!.subtract(const Duration(seconds: 60)));
  }

  Future<void> _doRefresh() async {
    final data = await _authService.refresh(_refreshToken!);
    _accessToken = data['access_token'] as String;
    _refreshToken = data['refresh_token'] as String;
    final expiresIn = (data['expires_in'] as num).toInt();
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    await _storage.save(
      accessToken: _accessToken!,
      refreshToken: _refreshToken!,
      expiresIn: expiresIn,
      profile: _profile,
    );
  }

  Future<void> _fetchAndStoreProfile() async {
    final data = await _authService.testEndpoint(_accessToken!);
    final profileData = data['profile'] as Map<String, dynamic>?;
    if (profileData != null) {
      _profile = UserProfile.fromJson(profileData);
      await _storage.saveProfile(_profile!);
    }
  }
}
