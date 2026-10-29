import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import 'auth_service.dart';
import 'auth_storage.dart';
import 'offline/offline_support.dart';
import 'push_service.dart';
import 'realtime_service.dart';
import 'settings_service.dart';

/// Manages the current auth session and user profile across all sign-in providers.
///
/// Also owns super-user impersonation: [startImpersonation] keeps the admin's
/// own session aside (persisted, so it survives an app restart) and
/// [stopImpersonation] / [logout] bring it back.
class AuthManager {
  static final instance = AuthManager._();
  AuthManager._();

  final _storage = AuthStorage();
  final _authService = AuthService();

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  UserProfile? _profile;
  _KeptSession? _admin;

  bool get hasSession => _accessToken != null && _refreshToken != null;
  UserProfile? get profile => _profile;

  /// True while a super user is signed in as someone else.
  bool get isImpersonating => _admin != null;

  /// The super user behind an impersonated session.
  UserProfile? get adminProfile => _admin?.profile;

  /// Called on app start. Loads persisted tokens + profile and refreshes if expired.
  /// Returns true if a usable session was restored.
  Future<bool> tryRestoreSession() async {
    final stored = await _storage.load();
    if (stored.accessToken == null || stored.refreshToken == null) return false;

    _accessToken = stored.accessToken;
    _refreshToken = stored.refreshToken;
    _expiresAt = stored.expiresAt;
    _profile = stored.profile;
    final admin = await _storage.loadAdminSession();
    _admin = admin == null ? null : _KeptSession.fromJson(admin);

    if (_isExpired()) {
      try {
        await _doRefresh();
      } catch (e) {
        // Offline (or the server is down) at startup: keep the session and
        // show cached data. The refresh is retried on the next API call.
        if (_isTransient(e)) {
          _onSignedIn();
          return true;
        }
        // An impersonated session that can't refresh falls back to the admin.
        if (isImpersonating) return _restoreAdmin(revokeCurrent: false);
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

    _onSignedIn();
    return true;
  }

  /// Returns a valid access token, silently refreshing if it is about to expire.
  Future<String> getValidToken() async {
    if (!hasSession) throw Exception('No active session');
    if (_isExpired()) {
      try {
        await _doRefresh();
      } catch (e) {
        // Offline or a server outage: hand back the stale token so the request
        // can still be answered from the offline cache. Real auth failures
        // (the refresh token was rejected) propagate.
        if (!_isTransient(e)) rethrow;
      }
    }
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
    _onSignedIn();
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

  // ── Impersonation ───────────────────────────────────────────────────────────

  /// Switches to the session returned by `POST /users/impersonate` (tokens +
  /// `profile`), keeping the current (admin) session aside.
  Future<void> startImpersonation(Map<String, dynamic> data) async {
    if (!hasSession) throw Exception('No active session');
    if (isImpersonating) throw Exception('Return to your own account first');

    // Pushes for the impersonated user must not reach the admin's phone.
    await PushService.instance.unregister();

    _admin = _KeptSession(
      accessToken: _accessToken!,
      refreshToken: _refreshToken!,
      expiresAt: _expiresAt ?? DateTime.now(),
      profile: _profile,
    );
    await _storage.saveAdminSession(_admin!.toJson());
    await setSession(data, profileData: data['profile'] as Map<String, dynamic>?);
  }

  /// Ends impersonation: revokes the impersonated session and restores the
  /// admin's. Returns false if the admin session couldn't be restored (the
  /// user is then fully signed out).
  Future<bool> stopImpersonation() async {
    if (!isImpersonating) return hasSession;
    return _restoreAdmin(revokeCurrent: true);
  }

  Future<bool> _restoreAdmin({required bool revokeCurrent}) async {
    final admin = _admin!;
    if (revokeCurrent && _accessToken != null) {
      try {
        await _authService.logout(_accessToken!);
      } catch (_) {}
    }
    _accessToken = admin.accessToken;
    _refreshToken = admin.refreshToken;
    _expiresAt = admin.expiresAt;
    _profile = admin.profile;
    _admin = null;
    await _storage.clearAdminSession();
    try {
      if (_isExpired()) {
        await _doRefresh();
      } else {
        await _persist();
      }
    } catch (_) {
      await clear();
      return false;
    }
    _onSignedIn();
    return true;
  }

  // ── Sign out ────────────────────────────────────────────────────────────────

  /// Best-effort server-side logout (unregisters this device's push token and
  /// revokes the refresh tokens), then clears the local session regardless of
  /// whether the API calls succeeded.
  ///
  /// While impersonating, this only ends the impersonation. Returns true when
  /// a session remains (back to the admin) so callers can go home instead of
  /// to the sign-in screen.
  Future<bool> logout() async {
    if (isImpersonating) return stopImpersonation();
    if (hasSession) {
      await PushService.instance.unregister();
      try {
        final token = await getValidToken();
        await _authService.logout(token);
      } catch (_) {
        // Ignore — the local session is cleared either way.
      }
    }
    await clear();
    return false;
  }

  /// Forgets the local session (and a kept-aside admin session) and resets
  /// per-user state. Prefer [logout], which also tells the server.
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _profile = null;
    _admin = null;
    await RealtimeService.instance.disconnect();
    await _storage.clear();
    await SettingsService.instance.reset();
    // Cached responses and queued writes belong to the user who signed out.
    await OfflineSupport.clearOnLogout();
  }

  // ── Internals ───────────────────────────────────────────────────────────────

  /// Loads the signed-in user's settings and registers this device for push.
  /// Runs in the background; neither blocks navigation.
  void _onSignedIn() {
    unawaited(SettingsService.instance.syncFromServer());
    // Reconnects as whoever is signed in now (also after impersonation switches).
    unawaited(RealtimeService.instance.disconnect().then((_) => RealtimeService.instance.connect()));
    unawaited(PushService.instance.registerCurrentUser().catchError((Object e) {
      debugPrint('Push registration failed: $e');
    }));
  }

  /// Failures that say nothing about the session itself: no network, or the
  /// server / its gateway failing (5xx).
  bool _isTransient(Object e) =>
      isNetworkError(e) || (e is AuthRequestException && e.isServerError);

  bool _isExpired() {
    if (_expiresAt == null) return true;
    return DateTime.now().isAfter(_expiresAt!.subtract(const Duration(seconds: 60)));
  }

  Future<void> _persist() => _storage.save(
        accessToken: _accessToken!,
        refreshToken: _refreshToken!,
        expiresIn: (_expiresAt ?? DateTime.now()).difference(DateTime.now()).inSeconds,
        profile: _profile,
      );

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

/// A session parked while impersonating.
class _KeptSession {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final UserProfile? profile;

  const _KeptSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.profile,
  });

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.millisecondsSinceEpoch,
        if (profile != null) 'profile': profile!.toJson(),
      };

  factory _KeptSession.fromJson(Map<String, dynamic> json) => _KeptSession(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
            (json['expires_at'] as num).toInt()),
        profile: json['profile'] == null
            ? null
            : UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      );
}
