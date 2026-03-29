import 'auth_service.dart';
import 'auth_storage.dart';

/// Manages the current auth session across all sign-in providers.
///
/// Supabase returns the same session shape (access_token, refresh_token,
/// expires_in) regardless of provider (email/password, Google, Apple, OAuth),
/// so [setSession] and [getValidToken] work identically for all of them.
class AuthManager {
  static final instance = AuthManager._();
  AuthManager._();

  final _storage = AuthStorage();
  final _authService = AuthService();

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;

  bool get hasSession => _accessToken != null && _refreshToken != null;

  /// Called on app start. Loads persisted tokens and refreshes them if expired.
  /// Returns true if a usable session was restored.
  Future<bool> tryRestoreSession() async {
    final stored = await _storage.load();
    if (stored.accessToken == null || stored.refreshToken == null) return false;

    _accessToken = stored.accessToken;
    _refreshToken = stored.refreshToken;
    _expiresAt = stored.expiresAt;

    if (_isExpired()) {
      try {
        await _doRefresh();
      } catch (_) {
        await clear();
        return false;
      }
    }
    return true;
  }

  /// Returns a valid access token, silently refreshing if it is about to expire.
  Future<String> getValidToken() async {
    if (!hasSession) throw Exception('No active session');
    if (_isExpired()) await _doRefresh();
    return _accessToken!;
  }

  /// Store a new session returned by any sign-in method (email, Google, etc.).
  void setSession(Map<String, dynamic> data) {
    _accessToken = data['access_token'] as String;
    _refreshToken = data['refresh_token'] as String;
    final expiresIn = (data['expires_in'] as num).toInt();
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    _storage.save(
      accessToken: _accessToken!,
      refreshToken: _refreshToken!,
      expiresIn: expiresIn,
    );
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    await _storage.clear();
  }

  // Treat tokens as expired 60 s early to avoid sending a stale token.
  bool _isExpired() {
    if (_expiresAt == null) return true;
    return DateTime.now().isAfter(_expiresAt!.subtract(const Duration(seconds: 60)));
  }

  Future<void> _doRefresh() async {
    final data = await _authService.refresh(_refreshToken!);
    setSession(data);
  }
}
