import 'dart:convert';
import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/admin_db.dart';
import '../models/app_notification.dart';
import '../models/business.dart';
import '../models/exercise.dart';
import '../models/meal_plan.dart';
import '../models/mention.dart';
import '../models/membership.dart';
import '../models/post.dart';
import '../models/routine.dart';
import '../models/shop_item.dart';
import '../models/training.dart';
import '../models/training_session.dart';
import '../models/user_profile.dart';
import '../models/user_search_result.dart';
import '../models/user_settings.dart';
import '../models/payment.dart';
import '../models/order.dart';
import '../models/gym_class.dart';
import '../models/class_series.dart';
import '../models/staff_shift.dart';
import '../models/progress.dart';
import '../models/coaching.dart';
import '../models/social.dart';
import '../models/check_in.dart';
import '../models/food_log.dart';
import '../models/chat.dart';
import '../models/draft.dart';
import '../models/people.dart';
import '../models/plan_entry.dart';
import '../models/reaction.dart';
import '../models/shared_content.dart';
import '../models/story.dart';
import '../models/streak.dart';
import '../models/water.dart';
import '../models/last_sets.dart';
import '../models/challenge.dart';
import '../models/wrapped.dart';
import '../config.dart';
import 'auth_manager.dart';
import 'health_sync_service.dart';
import 'offline/offline_support.dart';

part 'api/account_api.dart';
part 'api/admin_api.dart';
part 'api/business_api.dart';
part 'api/payments_api.dart';
part 'api/orders_api.dart';
part 'api/classes_api.dart';
part 'api/class_series_api.dart';
part 'api/shifts_api.dart';
part 'api/progress_api.dart';
part 'api/coaching_api.dart';
part 'api/social_api.dart';
part 'api/checkins_api.dart';
part 'api/food_logs_api.dart';
part 'api/people_api.dart';
part 'api/chat_api.dart';
part 'api/drafts_api.dart';
part 'api/plans_api.dart';
part 'api/post_tags_api.dart';
part 'api/stories_api.dart';
part 'api/streaks_api.dart';
part 'api/water_api.dart';
part 'api/suggestions_api.dart';
part 'api/challenges_api.dart';
part 'api/wrapped_api.dart';

// Set with --dart-define=API_BASE_URL=... (see lib/config.dart / README.md).
final _base = AppConfig.apiBaseUrl;

class ApiService {
  ApiService() {
    if (debugClientOverride == null) {
      OfflineSupport.ensureStarted(tokenProvider: _sessionToken);
    }
  }

  /// Token for replaying queued offline writes; null when signed out.
  static Future<String?> _sessionToken() async =>
      AuthManager.instance.hasSession ? AuthManager.instance.getValidToken() : null;

  /// Replaces the HTTP client of every ApiService (tests: a `MockClient`).
  /// Read on each request, so long-lived services pick it up too. While set,
  /// the offline machinery (connectivity, outbox replay) isn't started.
  @visibleForTesting
  static http.Client? debugClientOverride;

  /// Shared by every ApiService: 20 s timeouts, on-disk GET cache used as an
  /// offline fallback (responses carry `x-gymbro-offline: 1`), connectivity
  /// reporting. See lib/services/offline/caching_client.dart.
  http.Client get _client => debugClientOverride ?? CachingClient.shared;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Sends a JSON write; if the device is offline (network error), queues it
  /// in the outbox for replay and throws [QueuedOfflineException]. Use for
  /// writes that are safe to apply later, in order.
  Future<http.Response> _sendOrQueue(
    String method,
    Uri url,
    String token,
    Map<String, dynamic> data,
  ) async {
    final body = jsonEncode(data);
    final req = http.Request(method, url)
      ..headers.addAll(_headers(token))
      ..body = body;
    try {
      return await http.Response.fromStream(await _client.send(req));
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      await OfflineSupport.outbox.enqueue(
        method: method,
        url: url,
        headers: const {'Content-Type': 'application/json'},
        body: body,
      );
      throw const QueuedOfflineException();
    }
  }

  void _check(http.Response r) {
    if (r.statusCode >= 400) {
      try {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        throw Exception(d['error'] ?? 'Request failed (${r.statusCode})');
      } on FormatException {
        throw Exception('Request failed (${r.statusCode})');
      }
    }
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
  }) async {
    // A super user's Bearer token gets the account confirmed straight away.
    final r = await _client.post(
      Uri.parse('$_base/users/signup'),
      headers: _headers(token),
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
        'name': name,
        'last_name': lastName,
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

  // ── Uploads ─────────────────────────────────────────────────────────────────

  /// Uploads an image to Supabase Storage via the `uploads` edge function and
  /// returns its public URL. [bucket] is 'avatars' or 'media'; [folder] groups
  /// uploads within a bucket (e.g. 'exercises', 'recipes', 'businesses',
  /// 'shop-items', 'posts') and may be omitted.
  Future<String> uploadImage(
    String token, {
    required List<int> bytes,
    required String filename,
    required String bucket,
    String? folder,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/uploads'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['bucket'] = bucket;
    if (folder != null) request.fields['folder'] = folder;
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: _mimeTypeFor(filename),
    ));
    final streamed = await _client.send(request);
    final r = await http.Response.fromStream(streamed);
    _check(r);
    return (jsonDecode(r.body) as Map<String, dynamic>)['url'] as String;
  }

  MediaType _mimeTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
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

  /// What to offer when logging a workout; [name] filters every section.
  Future<TrainingSuggestions> getTrainingSuggestions(
    String token, {
    String? name,
    int limit = 10,
  }) async {
    final params = <String>['limit=$limit'];
    if (name != null && name.isNotEmpty) params.add('name=${Uri.encodeComponent(name)}');
    final r = await _client.get(
      Uri.parse('$_base/trainings/suggestions?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return TrainingSuggestions.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
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
    String? trainerId,
    String? trainingId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String>[
      'page=$page',
      'page_size=$pageSize',
    ];
    if (userId != null) params.add('user_id=$userId');
    if (trainerId != null) params.add('trainer_id=$trainerId');
    if (trainingId != null) params.add('training_id=$trainingId');
    if (from != null) params.add('from=${Uri.encodeComponent(from.toUtc().toIso8601String())}');
    if (to != null) params.add('to=${Uri.encodeComponent(to.toUtc().toIso8601String())}');
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

  /// POST /training-sessions — starts one now. A trainer passes [userId] to
  /// run it for someone they coach (they become its trainer); [planEntryId]
  /// is the planned workout it confirms.
  Future<TrainingSession> startTrainingSession(
    String token, {
    String? trainingId,
    String? trainerId,
    String? notes,
    String? userId,
    String? planEntryId,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/training-sessions'),
      headers: _headers(token),
      body: jsonEncode({
        'training_id': trainingId,
        'trainer_id': trainerId,
        'notes': notes,
        'user_id': ?userId,
        'plan_entry_id': ?planEntryId,
      }),
    );
    _check(r);
    return TrainingSession.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Logs a finished session in one go (e.g. from a calendar slot): [data]
  /// has started_at, ended_at, training_id?, notes? and sets (each with
  /// training_set_id? / exercise_id and drops). Returns the full detail.
  Future<TrainingSession> logPastTrainingSession(
    String token,
    Map<String, dynamic> data,
  ) async {
    final r = await _client.post(
      Uri.parse('$_base/training-sessions'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    streakChanges.value++;
    final session = TrainingSession.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    // Opt-in Apple Health / Health Connect copy; never throws.
    HealthSyncService.instance.writeWorkout(session, logged: true);
    return session;
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
    // Queued offline (throws QueuedOfflineException) when there's no network.
    final r = await _sendOrQueue(
      'POST',
      Uri.parse('$_base/training-sessions/$sessionId/sets'),
      token,
      data,
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
    streakChanges.value++;
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
    if (r.statusCode == 404) return [];
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
    if (r.statusCode == 404) return [];
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
    if (r.statusCode == 404) return [];
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
    if (r.statusCode == 404) return [];
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
    if (r.statusCode == 404) return [];
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

  // ── Gym Membership Types ───────────────────────────────────────────────────────

  Future<List<GymMembershipType>> getGymMembershipTypes(
    String token, {
    String? gymId,
    bool? isActive,
  }) async {
    final params = <String>[];
    if (gymId != null) params.add('gym_id=$gymId');
    if (isActive != null) params.add('is_active=$isActive');
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final r = await _client.get(
      Uri.parse('$_base/gym-membership-types$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => GymMembershipType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GymMembershipType> createGymMembershipType(
      String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/gym-membership-types'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return GymMembershipType.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<GymMembershipType> updateGymMembershipType(
      String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/gym-membership-types/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return GymMembershipType.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteGymMembershipType(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/gym-membership-types/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Memberships ─────────────────────────────────────────────────────────────

  Future<List<Membership>> getMemberships(
    String token, {
    String? userId,
    String? gymId,
    bool? isActive,
  }) async {
    final params = <String>[];
    if (userId != null) params.add('user_id=$userId');
    if (gymId != null) params.add('gym_id=$gymId');
    if (isActive != null) params.add('is_active=$isActive');
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final r = await _client.get(
      Uri.parse('$_base/memberships$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => Membership.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Membership> createMembership(
      String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/memberships'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Membership.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Membership> updateMembership(
      String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/memberships/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Membership.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteMembership(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/memberships/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Membership Invoices ────────────────────────────────────────────────────

  Future<List<MembershipInvoice>> getMembershipInvoices(
    String token, {
    String? membershipId,
    String? gymId,
    String? userId,
    InvoiceStatus? status,
  }) async {
    final params = <String>[];
    if (membershipId != null) params.add('membership_id=$membershipId');
    if (gymId != null) params.add('gym_id=$gymId');
    if (userId != null) params.add('user_id=$userId');
    if (status != null) params.add('status=${status.apiValue}');
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final r = await _client.get(
      Uri.parse('$_base/membership-invoices$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => MembershipInvoice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MembershipInvoice> createMembershipInvoice(
      String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/membership-invoices'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return MembershipInvoice.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ── Posts ───────────────────────────────────────────────────────────────────

  Future<List<Post>> getPosts(
    String token, {
    required String businessId,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = [
      'business_id=$businessId',
      'page=$page',
      'page_size=$pageSize',
    ];
    final r = await _client.get(
      Uri.parse('$_base/posts?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => Post.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Post> createPost(String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/posts'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Post.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deletePost(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/posts/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  // ── Added: accounts, businesses, billing ──────────────────────────────────

  /// GET /users/:id
  Future<UserProfile> getUser(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/users/$id'),
      headers: _headers(token),
    );
    _check(r);
    return UserProfile.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// POST /users/change-password — 400 if [currentPassword] is wrong.
  Future<void> changePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/users/change-password'),
      headers: _headers(token),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    _check(r);
  }

  /// DELETE /users/:id — 409 (message surfaced) if the user owns a business.
  Future<void> deleteUser(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/users/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  /// GET /businesses/stats — aggregates over the gyms the caller manages.
  Future<BusinessStats> getBusinessStats(String token) async {
    final r = await _client.get(
      Uri.parse('$_base/businesses/stats'),
      headers: _headers(token),
    );
    _check(r);
    return BusinessStats.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// PUT /membership-invoices/:id — mark an invoice paid / unpaid / void.
  Future<MembershipInvoice> updateMembershipInvoiceStatus(
      String token, String id, InvoiceStatus status) async {
    final r = await _client.put(
      Uri.parse('$_base/membership-invoices/$id'),
      headers: _headers(token),
      body: jsonEncode({'status': status.apiValue}),
    );
    _check(r);
    return MembershipInvoice.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ── Added: training & nutrition ────────────────────────────────────────────

  /// POST /training-sessions/:id/end — sets ended_at = now() (if not set yet).
  Future<TrainingSession> endTrainingSession(String token, String id) async {
    final r = await _client.post(
      Uri.parse('$_base/training-sessions/$id/end'),
      headers: _headers(token),
    );
    _check(r);
    streakChanges.value++;
    final session = TrainingSession.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    // Opt-in Apple Health / Health Connect copy; never throws.
    HealthSyncService.instance.writeWorkout(session);
    return session;
  }

  /// PUT /training-sessions/sets/:setLogId — same editable fields as
  /// POST /training-sessions/:id/sets (exercise_id, position, note, drops).
  Future<SessionSetLog> updateSessionSet(
    String token,
    String setLogId,
    Map<String, dynamic> data,
  ) async {
    final r = await _client.put(
      Uri.parse('$_base/training-sessions/sets/$setLogId'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return SessionSetLog.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// DELETE /training-sessions/sets/:setLogId (cascades its drop logs).
  Future<void> deleteSessionSet(String token, String setLogId) async {
    final r = await _client.delete(
      Uri.parse('$_base/training-sessions/sets/$setLogId'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  /// PUT /posts/:id — {content?, images?: [{url, position}]} (author or super).
  Future<Post> updatePost(
      String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/posts/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Post.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
