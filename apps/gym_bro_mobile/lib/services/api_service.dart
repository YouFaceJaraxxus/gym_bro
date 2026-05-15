import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/app_notification.dart';
import '../models/business.dart';
import '../models/exercise.dart';
import '../models/meal_plan.dart';
import '../models/routine.dart';
import '../models/shop_item.dart';
import '../models/training.dart';
import '../models/training_session.dart';
import '../models/user_profile.dart';
import '../models/user_search_result.dart';

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
  Future<List<UserSearchResult>> searchUsers(
    String token, {
    String query = '',
    int page = 0,
    int pageSize = 10,
  }) async {
    final params = [
      'q=${Uri.encodeComponent(query)}',
      'page=$page',
      'page_size=$pageSize',
    ];
    final r = await _client.get(
      Uri.parse('$_base/search-users?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>))
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

  // ── Notifications ────────────────────────────────────────────────────────────

  Future<NotificationPage> getNotifications(
    String token, {
    required String userId,
    int page = 0,
    int pageSize = 20,
    bool unreadOnly = false,
  }) async {
    final params = [
      'user_id=${Uri.encodeComponent(userId)}',
      'page=$page',
      'page_size=$pageSize',
      if (unreadOnly) 'unread_only=true',
    ];
    final r = await _client.get(
      Uri.parse('$_base/notifications?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return NotificationPage.fromJson(
        jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<AppNotification> markNotificationRead(
      String token, String notificationId) async {
    final r = await _client.post(
      Uri.parse('$_base/notifications/$notificationId/read'),
      headers: _headers(token),
    );
    _check(r);
    return AppNotification.fromJson(
        jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<AppNotification> acceptInvite(
      String token, String notificationId) async {
    final r = await _client.post(
      Uri.parse('$_base/notifications/$notificationId/accept'),
      headers: _headers(token),
    );
    _check(r);
    return AppNotification.fromJson(
        jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<AppNotification> declineInvite(
      String token, String notificationId) async {
    final r = await _client.post(
      Uri.parse('$_base/notifications/$notificationId/decline'),
      headers: _headers(token),
    );
    _check(r);
    return AppNotification.fromJson(
        jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> markAllNotificationsRead(String token) async {
    final r = await _client.post(
      Uri.parse('$_base/notifications/mark-all-read'),
      headers: _headers(token),
    );
    _check(r);
  }

  Future<void> deleteNotification(String token, String notificationId) async {
    final r = await _client.delete(
      Uri.parse('$_base/notifications/$notificationId'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Exercises ────────────────────────────────────────────────────────────────

  Future<List<Exercise>> getExercises(
    String token, {
    String? name,
    MuscleGroup? muscle,
    String? authorId,
    bool? isPublic,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String>[
      'page=$page',
      'page_size=$pageSize',
    ];
    if (name != null) params.add('name=${Uri.encodeComponent(name)}');
    if (muscle != null) params.add('muscle=${muscle.apiValue}');
    if (authorId != null) params.add('author_id=$authorId');
    if (isPublic != null) params.add('is_public=$isPublic');
    final r = await _client.get(
      Uri.parse('$_base/exercises?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Exercise> getExercise(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/exercises/$id'),
      headers: _headers(token),
    );
    _check(r);
    return Exercise.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Exercise> createExercise(String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/exercises'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Exercise.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Exercise> updateExercise(String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/exercises/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Exercise.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteExercise(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/exercises/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Trainings ────────────────────────────────────────────────────────────────

  Future<List<Training>> getTrainings(
    String token, {
    String? name,
    String? authorId,
    bool mine = false,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String>[
      'page=$page',
      'page_size=$pageSize',
    ];
    if (name != null) params.add('name=${Uri.encodeComponent(name)}');
    if (authorId != null) params.add('author_id=$authorId');
    if (mine) params.add('mine=true');
    final r = await _client.get(
      Uri.parse('$_base/trainings?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => Training.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Training> getTraining(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/trainings/$id'),
      headers: _headers(token),
    );
    _check(r);
    return Training.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Training> createTraining(String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/trainings'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Training.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Training> updateTraining(String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/trainings/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Training.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteTraining(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/trainings/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Routines ─────────────────────────────────────────────────────────────────

  Future<List<Routine>> getRoutines(
    String token, {
    String? name,
    String? authorId,
    bool mine = false,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String>[
      'page=$page',
      'page_size=$pageSize',
    ];
    if (name != null) params.add('name=${Uri.encodeComponent(name)}');
    if (authorId != null) params.add('author_id=$authorId');
    if (mine) params.add('mine=true');
    final r = await _client.get(
      Uri.parse('$_base/routines?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => Routine.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Routine> getRoutine(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/routines/$id'),
      headers: _headers(token),
    );
    _check(r);
    return Routine.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Routine> createRoutine(String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/routines'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Routine.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Routine> updateRoutine(String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/routines/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Routine.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteRoutine(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/routines/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Training sessions ────────────────────────────────────────────────────────

  Future<List<TrainingSession>> getTrainingSessions(
    String token, {
    String? userId,
    String? trainingId,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String>[
      'page=$page',
      'page_size=$pageSize',
    ];
    if (userId != null) params.add('user_id=$userId');
    if (trainingId != null) params.add('training_id=$trainingId');
    final r = await _client.get(
      Uri.parse('$_base/training-sessions?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => TrainingSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TrainingSession> getTrainingSession(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/training-sessions/$id'),
      headers: _headers(token),
    );
    _check(r);
    return TrainingSession.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<TrainingSession> startTrainingSession(
    String token, {
    String? trainingId,
    String? trainerId,
    String? notes,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/training-sessions'),
      headers: _headers(token),
      body: jsonEncode({
        'training_id': trainingId,
        'trainer_id': trainerId,
        'notes': notes,
      }),
    );
    _check(r);
    return TrainingSession.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<TrainingSession> updateTrainingSession(
    String token,
    String id,
    Map<String, dynamic> data,
  ) async {
    final r = await _client.put(
      Uri.parse('$_base/training-sessions/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return TrainingSession.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<SessionSetLog> logSessionSet(
    String token,
    String sessionId,
    Map<String, dynamic> data,
  ) async {
    final r = await _client.post(
      Uri.parse('$_base/training-sessions/$sessionId/sets'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return SessionSetLog.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteTrainingSession(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/training-sessions/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Food Items ───────────────────────────────────────────────────────────────

  Future<List<FoodItem>> getFoodItems(
    String token, {
    String? name,
    FoodItemType? type,
    bool mine = false,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String>['page=$page', 'page_size=$pageSize'];
    if (name != null) params.add('name=${Uri.encodeComponent(name)}');
    if (type != null) params.add('type=${type.apiValue}');
    if (mine) params.add('mine=true');
    final r = await _client.get(
      Uri.parse('$_base/food-items?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FoodItem> getFoodItem(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/food-items/$id'),
      headers: _headers(token),
    );
    _check(r);
    return FoodItem.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<FoodItem> createFoodItem(String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/food-items'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return FoodItem.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<FoodItem> updateFoodItem(String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/food-items/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return FoodItem.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteFoodItem(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/food-items/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Recipes ──────────────────────────────────────────────────────────────────

  Future<List<Recipe>> getRecipes(
    String token, {
    String? name,
    bool mine = false,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String>['page=$page', 'page_size=$pageSize'];
    if (name != null) params.add('name=${Uri.encodeComponent(name)}');
    if (mine) params.add('mine=true');
    final r = await _client.get(
      Uri.parse('$_base/recipes?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Recipe> getRecipe(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/recipes/$id'),
      headers: _headers(token),
    );
    _check(r);
    return Recipe.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Recipe> createRecipe(String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/recipes'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Recipe.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Recipe> updateRecipe(String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/recipes/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Recipe.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteRecipe(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/recipes/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Daily Meal Plans ──────────────────────────────────────────────────────────

  Future<List<DailyMealPlan>> getDailyMealPlans(
    String token, {
    String? name,
    bool mine = false,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String>['page=$page', 'page_size=$pageSize'];
    if (name != null) params.add('name=${Uri.encodeComponent(name)}');
    if (mine) params.add('mine=true');
    final r = await _client.get(
      Uri.parse('$_base/daily-meal-plans?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => DailyMealPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DailyMealPlan> getDailyMealPlan(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/daily-meal-plans/$id'),
      headers: _headers(token),
    );
    _check(r);
    return DailyMealPlan.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<DailyMealPlan> createDailyMealPlan(String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/daily-meal-plans'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return DailyMealPlan.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<DailyMealPlan> updateDailyMealPlan(String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/daily-meal-plans/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return DailyMealPlan.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteDailyMealPlan(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/daily-meal-plans/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Meal Plans ────────────────────────────────────────────────────────────────

  Future<List<MealPlan>> getMealPlans(
    String token, {
    String? name,
    bool mine = false,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String>['page=$page', 'page_size=$pageSize'];
    if (name != null) params.add('name=${Uri.encodeComponent(name)}');
    if (mine) params.add('mine=true');
    final r = await _client.get(
      Uri.parse('$_base/meal-plans?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => MealPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MealPlan> getMealPlan(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/meal-plans/$id'),
      headers: _headers(token),
    );
    _check(r);
    return MealPlan.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<MealPlan> createMealPlan(String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/meal-plans'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return MealPlan.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<MealPlan> updateMealPlan(String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/meal-plans/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return MealPlan.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteMealPlan(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/meal-plans/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Meal Plan Assignments ─────────────────────────────────────────────────────

  Future<List<MealPlanAssignment>> getMealPlanAssignments(
    String token, {
    String? userId,
    String? mealPlanId,
  }) async {
    final params = <String>[];
    if (userId != null) params.add('user_id=$userId');
    if (mealPlanId != null) params.add('meal_plan_id=$mealPlanId');
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final r = await _client.get(
      Uri.parse('$_base/meal-plan-assignments$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => MealPlanAssignment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MealPlanAssignment> createMealPlanAssignment(
      String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/meal-plan-assignments'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return MealPlanAssignment.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteMealPlanAssignment(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/meal-plan-assignments/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }
}
