import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Android emulator → host machine is 10.0.2.2
// iOS simulator   → localhost works fine
// Physical device → use your machine's LAN IP (e.g. 192.168.x.x)
final _baseUrl = 'http://${Platform.isAndroid ? '10.0.2.2' : 'localhost'}:54321/functions/v1/users';

class AuthService {
  final _client = http.Client();

  /// Signs up a new user. Returns the raw API response.
  ///
  /// Two possible shapes:
  ///   - Normal signup (201): `{ message, user, role_assignment }` — no session yet,
  ///     user must confirm their email.
  ///   - Invited signup (200): `{ access_token, refresh_token, expires_in, ..., profile }`
  ///     — the email was already pre-registered by an owner; a live session is returned
  ///     so the app can navigate straight to home.
  ///
  /// Callers should check `data.containsKey('access_token')` to distinguish the two.
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
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['error'] ?? 'Signup failed');
    }
    return data;
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
