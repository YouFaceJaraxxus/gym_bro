part of '../api_service.dart';

/// Gym check-ins.
extension CheckInsApi on ApiService {
  /// Minutes east of UTC, so the API buckets visits into the device's days.
  String get _tzOffset => 'tz_offset=${DateTime.now().timeZoneOffset.inMinutes}';

  /// Like [_check], but throws [CheckInException] carrying the API's `code`.
  void _checkCheckIn(http.Response r) {
    if (r.statusCode < 400) return;
    String message = 'Request failed (${r.statusCode})';
    String? code;
    try {
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      message = d['error'] as String? ?? message;
      code = d['code'] as String?;
    } catch (_) {}
    throw CheckInException(message, code: code, statusCode: r.statusCode);
  }

  /// Gyms where the caller is a member (or staff, flagged).
  Future<List<CheckInGym>> getCheckInGyms(String token) async {
    final r = await _client.get(
      Uri.parse('$_base/check-ins/gyms'),
      headers: _headers(token),
    );
    _checkCheckIn(r);
    return (jsonDecode(r.body) as List)
        .map((e) => CheckInGym.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CheckInToken> getCheckInToken(String token, String gymId) async {
    final r = await _client.get(
      Uri.parse('$_base/check-ins/token?gym_id=$gymId'),
      headers: _headers(token),
    );
    _checkCheckIn(r);
    return CheckInToken.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Staff: check in the member whose QR [qrToken] was scanned at [gymId].
  Future<CheckInResult> checkInWithToken(
      String token, String qrToken, {String? gymId}) async {
    final r = await _client.post(
      Uri.parse('$_base/check-ins'),
      headers: _headers(token),
      body: jsonEncode({'token': qrToken, 'gym_id': ?gymId}),
    );
    _checkCheckIn(r);
    return CheckInResult.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Staff: manual check-in.
  Future<CheckInResult> manualCheckIn(
      String token, String gymId, String userId) async {
    final r = await _client.post(
      Uri.parse('$_base/check-ins'),
      headers: _headers(token),
      body: jsonEncode({'gym_id': gymId, 'user_id': userId}),
    );
    _checkCheckIn(r);
    return CheckInResult.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Staff: members of [gymId] matching [query] (name or email), max 50.
  Future<List<CheckInPerson>> searchCheckInMembers(
      String token, String gymId, String query) async {
    final r = await _client.get(
      Uri.parse('$_base/check-ins/members').replace(
          queryParameters: {'gym_id': gymId, if (query.isNotEmpty) 'q': query}),
      headers: _headers(token),
    );
    _checkCheckIn(r);
    return (jsonDecode(r.body) as List)
        .map((e) => CheckInPerson.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Staff: the gym's check-ins on [date] (device-local day, default today).
  Future<List<CheckIn>> getGymCheckIns(
      String token, String gymId, {DateTime? date}) async {
    final d = date == null
        ? ''
        : '&date=${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
    final r = await _client.get(
      Uri.parse('$_base/check-ins?gym_id=$gymId$d&$_tzOffset'),
      headers: _headers(token),
    );
    _checkCheckIn(r);
    return (jsonDecode(r.body) as List)
        .map((e) => CheckIn.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Own visit history, newest first.
  Future<List<CheckIn>> getMyCheckIns(
    String token, {
    String? gymId,
    int page = 0,
    int pageSize = 30,
  }) async {
    final g = gymId == null ? '' : '&gym_id=$gymId';
    final r = await _client.get(
      Uri.parse(
          '$_base/check-ins?mine=true$g&page=$page&page_size=$pageSize'),
      headers: _headers(token),
    );
    _checkCheckIn(r);
    return (jsonDecode(r.body) as List)
        .map((e) => CheckIn.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MyCheckInStats> getMyCheckInStats(String token) async {
    final r = await _client.get(
      Uri.parse('$_base/check-ins/stats?mine=true&$_tzOffset'),
      headers: _headers(token),
    );
    _checkCheckIn(r);
    return MyCheckInStats.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Staff: attendance stats for the last [days] days.
  Future<GymAttendanceStats> getGymCheckInStats(
      String token, String gymId, {int days = 30}) async {
    final r = await _client.get(
      Uri.parse('$_base/check-ins/stats?gym_id=$gymId&days=$days&$_tzOffset'),
      headers: _headers(token),
    );
    _checkCheckIn(r);
    return GymAttendanceStats.fromJson(
        jsonDecode(r.body) as Map<String, dynamic>);
  }
}
