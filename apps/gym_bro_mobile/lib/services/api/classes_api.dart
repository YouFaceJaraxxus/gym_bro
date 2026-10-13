part of '../api_service.dart';

/// Gym classes and bookings.
extension ClassesApi on ApiService {
  /// GET /classes. Without [gymId]: classes at every gym the caller belongs
  /// to. [mine] = only classes the caller has booked. Times go out as UTC.
  Future<List<GymClass>> getClasses(
    String token, {
    String? gymId,
    DateTime? from,
    DateTime? to,
    String? trainerId,
    bool mine = false,
    bool includeCancelled = false,
  }) async {
    final params = <String, String>{
      'gym_id': ?gymId,
      'trainer_id': ?trainerId,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
      if (mine) 'mine': 'true',
      if (includeCancelled) 'include_cancelled': 'true',
    };
    final r = await _client.get(
      Uri.parse('$_base/classes')
          .replace(queryParameters: params.isEmpty ? null : params),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => GymClass.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /classes/:id — includes the roster when the caller coaches there.
  Future<GymClass> getClass(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/classes/$id'),
      headers: _headers(token),
    );
    _check(r);
    return GymClass.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// GET /classes/coaching-gyms — gyms where the caller can create classes.
  Future<List<CoachingGym>> getCoachingGyms(String token) async {
    final r = await _client.get(
      Uri.parse('$_base/classes/coaching-gyms'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => CoachingGym.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /classes — {gym_id, title, description?, location?, starts_at,
  /// ends_at, capacity, trainer_id?, repeat_weeks?}. Returns every class
  /// created (one per week for a series).
  Future<List<GymClass>> createClass(
      String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/classes'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => GymClass.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PUT /classes/:id — any of the create fields plus `apply_to_series`.
  Future<GymClass> updateClass(
      String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/classes/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return GymClass.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// DELETE /classes/:id — cancels the class ([series]: and every later class
  /// in its series). Booked and waitlisted people are notified.
  Future<void> cancelClass(String token, String id,
      {bool series = false}) async {
    final r = await _client.delete(
      Uri.parse('$_base/classes/$id${series ? '?series=true' : ''}'),
      headers: _headers(token),
    );
    _check(r);
  }

  /// POST /classes/:id/book — books a seat or joins the waitlist when full.
  /// Staff can pass [userId] to book on a member's behalf.
  Future<ClassBooking> bookClass(String token, String classId,
      {String? userId}) async {
    final r = await _client.post(
      Uri.parse('$_base/classes/$classId/book'),
      headers: _headers(token),
      body: jsonEncode({'user_id': ?userId}),
    );
    _check(r);
    return ClassBooking.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// POST /classes/:id/cancel-booking — cancels a booking or leaves the
  /// waitlist. Staff can pass [userId] to cancel for someone else.
  Future<ClassBooking> cancelClassBooking(String token, String classId,
      {String? userId}) async {
    final r = await _client.post(
      Uri.parse('$_base/classes/$classId/cancel-booking'),
      headers: _headers(token),
      body: jsonEncode({'user_id': ?userId}),
    );
    _check(r);
    return ClassBooking.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// PUT /classes/:id/bookings/:bookingId — attendance: attended, no-show or
  /// back to booked.
  Future<ClassBooking> setClassBookingStatus(String token, String classId,
      String bookingId, BookingStatus status) async {
    final r = await _client.put(
      Uri.parse('$_base/classes/$classId/bookings/$bookingId'),
      headers: _headers(token),
      body: jsonEncode({'status': status.apiValue}),
    );
    _check(r);
    return ClassBooking.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
