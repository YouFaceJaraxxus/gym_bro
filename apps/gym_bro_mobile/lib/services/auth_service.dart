import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Android emulator → host machine is 10.0.2.2
// iOS simulator   → localhost works fine
// Physical device → use your machine's LAN IP (e.g. 192.168.x.x)
final _baseUrl = 'http://${Platform.isAndroid ? '10.0.2.2' : 'localhost'}:54321/functions/v1/users';

class AuthService {
  final _client = http.Client();

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
