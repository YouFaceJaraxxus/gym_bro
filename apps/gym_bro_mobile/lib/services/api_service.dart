import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/business.dart';
import '../models/shop_item.dart';
import '../models/user_profile.dart';

// Android emulator → host machine is 10.0.2.2
// iOS simulator   → localhost works fine
// Physical device → use your machine's LAN IP (e.g. 192.168.x.x)
final _base =
    'http://${Platform.isAndroid ? '10.0.2.2' : 'localhost'}:54321/functions/v1';

class ApiService {
  final _client = http.Client();

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  void _check(http.Response r) {
    if (r.statusCode >= 400) {
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      throw Exception(d['error'] ?? 'Request failed (${r.statusCode})');
    }
  }

  // ── Businesses ──────────────────────────────────────────────────────────────

  Future<List<Business>> getBusinesses(String token) async {
    final r = await _client.get(
      Uri.parse('$_base/businesses'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => Business.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Business> getBusiness(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/businesses/$id'),
      headers: _headers(token),
    );
    _check(r);
    return Business.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Business> createBusiness(
      String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/businesses'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Business.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Business> updateBusiness(
      String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/businesses/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Business.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ── Users ───────────────────────────────────────────────────────────────────

  Future<List<UserProfile>> getUsers(String token) async {
    final r = await _client.get(
      Uri.parse('$_base/users'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns the user with [email], or null if none exists.
  Future<UserProfile?> getUserByEmail(String token, String email) async {
    final r = await _client.get(
      Uri.parse('$_base/users?email=${Uri.encodeComponent(email)}'),
      headers: _headers(token),
    );
    _check(r);
    final list = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    return UserProfile.fromJson(list.first);
  }

  Future<UserProfile> createUser(
    String token, {
    required String email,
    required String password,
    required String username,
    required String name,
    required String lastName,
    required String role,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/users/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
        'name': name,
        'last_name': lastName,
        'role': role,
      }),
    );
    _check(r);
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    return UserProfile.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<UserProfile> updateUser(
      String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/users/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return UserProfile.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ── Gym / Shop owners ───────────────────────────────────────────────────────

  /// Returns gym_owner rows: [{id, user_id, gym_id}, ...]
  Future<List<Map<String, dynamic>>> getGymOwners(
      String token, {String? userId}) async {
    final q = userId != null ? '?user_id=$userId' : '';
    final r = await _client.get(
      Uri.parse('$_base/gym-owners$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
  }

  /// Returns shop_owner rows: [{id, user_id, shop_id}, ...]
  Future<List<Map<String, dynamic>>> getShopOwners(
      String token, {String? userId}) async {
    final q = userId != null ? '?user_id=$userId' : '';
    final r = await _client.get(
      Uri.parse('$_base/shop-owners$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
  }

  // ── Members ─────────────────────────────────────────────────────────────────

  /// Returns member rows: [{id, user_id, gym_id}, ...]
  Future<List<Map<String, dynamic>>> getMembers(
      String token, {String? gymId, String? userId}) async {
    final params = <String>[];
    if (gymId != null) params.add('gym_id=$gymId');
    if (userId != null) params.add('user_id=$userId');
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final r = await _client.get(
      Uri.parse('$_base/members$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addMember(
      String token, String userId, String gymId) async {
    final r = await _client.post(
      Uri.parse('$_base/members'),
      headers: _headers(token),
      body: jsonEncode({'user_id': userId, 'gym_id': gymId}),
    );
    _check(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> removeMember(String token, String memberId) async {
    final r = await _client.delete(
      Uri.parse('$_base/members/$memberId'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  /// Invite a new member by email (creates the user + member row, sends invite email).
  Future<Map<String, dynamic>> inviteMember(
    String token, {
    required String email,
    required String name,
    required String lastName,
    required String username,
    required String gymId,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/members'),
      headers: _headers(token),
      body: jsonEncode({
        'email': email,
        'name': name,
        'last_name': lastName,
        'username': username,
        'gym_id': gymId,
      }),
    );
    _check(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Re-sends the invite email for a user who hasn't set their password yet.
  Future<void> resendInvite(String token, String email) async {
    final r = await _client.post(
      Uri.parse('$_base/users/resend-invite'),
      headers: _headers(token),
      body: jsonEncode({'email': email}),
    );
    _check(r);
  }

  // ── Employees ───────────────────────────────────────────────────────────────

  /// Returns employee rows: [{id, user_id, gym_id}, ...]
  Future<List<Map<String, dynamic>>> getEmployees(
      String token, {String? gymId, String? userId}) async {
    final params = <String>[];
    if (gymId != null) params.add('gym_id=$gymId');
    if (userId != null) params.add('user_id=$userId');
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final r = await _client.get(
      Uri.parse('$_base/employees$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
  }

  /// Add an employee or employee-trainer to a gym.
  ///
  /// Provide either [userId] (existing user) or [email] + [name] + [lastName]
  /// + [username] (new user to create). [employeeType] must be `"employee"` or
  /// `"employee_trainer"`.
  Future<Map<String, dynamic>> addEmployee(
    String token, {
    String? userId,
    String? email,
    String? name,
    String? lastName,
    String? username,
    required String gymId,
    required String employeeType,
  }) async {
    final body = <String, dynamic>{
      'gym_id': gymId,
      'employee_type': employeeType,
    };
    if (userId != null) {
      body['user_id'] = userId;
    } else {
      body['email'] = email;
      if (name != null) body['name'] = name;
      if (lastName != null) body['last_name'] = lastName;
      if (username != null) body['username'] = username;
    }
    final r = await _client.post(
      Uri.parse('$_base/employees'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    _check(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> removeEmployee(String token, String employeeId) async {
    final r = await _client.delete(
      Uri.parse('$_base/employees/$employeeId'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Employee-trainers ────────────────────────────────────────────────────────

  /// Returns employee_trainer rows with user info embedded:
  /// [{id, user_id, gym_id, email, name, last_name, username, role}, ...]
  Future<List<Map<String, dynamic>>> getEmployeeTrainers(
      String token, {String? gymId, String? userId}) async {
    final params = <String>[];
    if (gymId != null) params.add('gym_id=$gymId');
    if (userId != null) params.add('user_id=$userId');
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final r = await _client.get(
      Uri.parse('$_base/employee-trainers$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
  }

  Future<void> removeEmployeeTrainer(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/employee-trainers/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Shop vendors ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getShopVendors(
      String token, {String? shopId, String? userId}) async {
    final params = <String>[];
    if (shopId != null) params.add('shop_id=$shopId');
    if (userId != null) params.add('user_id=$userId');
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final r = await _client.get(
      Uri.parse('$_base/shop-vendors$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addShopVendor(
    String token, {
    String? userId,
    String? email,
    String? name,
    String? lastName,
    String? username,
    required String shopId,
  }) async {
    final body = <String, dynamic>{'shop_id': shopId};
    if (userId != null) {
      body['user_id'] = userId;
    } else {
      body['email'] = email;
      if (name != null) body['name'] = name;
      if (lastName != null) body['last_name'] = lastName;
      if (username != null) body['username'] = username;
    }
    final r = await _client.post(
      Uri.parse('$_base/shop-vendors'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    _check(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> removeShopVendor(String token, String vendorId) async {
    final r = await _client.delete(
      Uri.parse('$_base/shop-vendors/$vendorId'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Shop items ──────────────────────────────────────────────────────────────

  Future<List<ShopItem>> getShopItems(String token,
      {String? shopId, bool activeOnly = false}) async {
    final params = <String>[];
    if (shopId != null) params.add('shop_id=$shopId');
    if (activeOnly) params.add('active_only=true');
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final r = await _client.get(
      Uri.parse('$_base/shop-items$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => ShopItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShopItem> createShopItem(
      String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/shop-items'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return ShopItem.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<ShopItem> updateShopItem(
      String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/shop-items/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return ShopItem.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteShopItem(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/shop-items/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }
}
