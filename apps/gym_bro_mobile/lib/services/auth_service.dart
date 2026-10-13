import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

// Set with --dart-define=API_BASE_URL=... (see lib/config.dart / README.md).
final _baseUrl = '${AppConfig.apiBaseUrl}/users';

class AuthService {
  final _client = http.Client();

  /// Signs up a new user. Returns `{ message, user }` on success (201); the
  /// user must confirm their email before signing in — no session is returned.
  ///
  /// Throws [SignupException] carrying the API's `code` on failure, e.g.
  /// `invite_pending` (the account was invited and the invite email was
  /// re-sent) or `email_taken`.
  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String username,
    required String name,
    required String lastName,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
        'name': name,
        'last_name': lastName,
      }),
    );
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      data = {};
    }
    if (response.statusCode >= 400) {
      throw SignupException(
        data['error'] as String? ?? 'Signup failed (${response.statusCode})',
        code: data['code'] as String?,
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  /// Revokes the session's refresh tokens on the server (POST /users/logout).
  Future<void> logout(String accessToken) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/logout'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode >= 400) {
      throw Exception('Logout failed (${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> signin({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/signin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['error'] ?? 'Sign in failed');
    }
    return data;
  }

  /// Verifies the 6-digit OTP from an invite email and sets the user's password.
  /// Returns a session + profile map identical to [signin].
  Future<Map<String, dynamic>> verifyInvite({
    required String email,
    required String token,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/verify-invite'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'token': token, 'password': password}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['error'] ?? 'Verification failed');
    }
    return data;
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['error'] ?? 'Token refresh failed');
    }
    return data;
  }

  Future<void> forgotPassword(String email) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode >= 400) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['error'] ?? 'Failed to send reset email');
    }
  }

  Future<void> resetPassword({
    required String accessToken,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/reset-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'password': password}),
    );
    if (response.statusCode >= 400) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['error'] ?? 'Password reset failed');
    }
  }

  /// Exchanges a Google ID token for a session (POST /users/google). Creates
  /// the profile on first sign-in. Returns a session + profile map like
  /// [signin].
  Future<Map<String, dynamic>> signInWithGoogle(String idToken) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      data = {};
    }
    if (response.statusCode >= 400) {
      throw Exception(data['error'] ?? 'Google sign-in failed (${response.statusCode})');
    }
    return data;
  }

  Future<Map<String, dynamic>> testEndpoint(String accessToken) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/test'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['error'] ?? 'Request failed (${response.statusCode})');
    }
    return data;
  }
}

/// Signup failure with the API's machine-readable `code`
/// (`invite_pending`, `email_taken`, …) when one was returned.
class SignupException implements Exception {
  final String message;
  final String? code;
  final int statusCode;

  const SignupException(this.message, {this.code, required this.statusCode});

  @override
  String toString() => message;
}
