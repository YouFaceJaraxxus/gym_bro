part of '../api_service.dart';

/// Settings, devices (push tokens), email change, impersonation.
extension AccountApi on ApiService {
  // ── Settings ────────────────────────────────────────────────────────────────

  /// GET /users/me/settings — defaults when the user never saved any.
  Future<UserSettings> getSettings(String token) async {
    final r = await _client.get(
      Uri.parse('$_base/users/me/settings'),
      headers: _headers(token),
    );
    _check(r);
    return UserSettings.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// PUT /users/me/settings — partial update; returns the saved settings.
  /// Keys: push_enabled, muted_types, weight_unit, theme_mode, locale.
  Future<UserSettings> updateSettings(
      String token, Map<String, dynamic> changes) async {
    final r = await _client.put(
      Uri.parse('$_base/users/me/settings'),
      headers: _headers(token),
      body: jsonEncode(changes),
    );
    _check(r);
    return UserSettings.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ── Push devices ────────────────────────────────────────────────────────────

  /// POST /devices — registers (or moves to this user) an FCM token.
  /// [platform] is 'android', 'ios', 'web' or 'macos'.
  Future<void> registerDevice(
    String token, {
    required String deviceToken,
    required String platform,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/devices'),
      headers: _headers(token),
      body: jsonEncode({'token': deviceToken, 'platform': platform}),
    );
    _check(r);
  }

  /// DELETE /devices — removes one of the caller's FCM tokens.
  Future<void> unregisterDevice(String token, String deviceToken) async {
    final r = await _client.delete(
      Uri.parse('$_base/devices'),
      headers: _headers(token),
      body: jsonEncode({'token': deviceToken}),
    );
    _check(r);
  }

  // ── Account ─────────────────────────────────────────────────────────────────

  /// POST /users/change-email — verifies [password] and emails a confirmation
  /// link to [newEmail]. Returns the API's message to show the user. The
  /// profile's email changes once the link is opened (picked up on the next
  /// profile fetch).
  Future<String> changeEmail(
    String token, {
    required String newEmail,
    required String password,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/users/change-email'),
      headers: _headers(token),
      body: jsonEncode({'new_email': newEmail, 'password': password}),
    );
    _check(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return data['message'] as String? ??
        'Check $newEmail for a confirmation link.';
  }

  /// POST /users/impersonate — super users only. Returns a session map
  /// (access_token, refresh_token, expires_in, …) plus `profile` for [userId].
  Future<Map<String, dynamic>> impersonate(String token, String userId) async {
    final r = await _client.post(
      Uri.parse('$_base/users/impersonate'),
      headers: _headers(token),
      body: jsonEncode({'user_id': userId}),
    );
    _check(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
