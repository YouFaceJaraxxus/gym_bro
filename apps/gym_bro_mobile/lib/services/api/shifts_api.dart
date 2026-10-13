part of '../api_service.dart';

/// Staff shifts.
extension ShiftsApi on ApiService {
  /// GET /shifts?gym_id= — every shift at a gym (staff of that gym only).
  Future<List<StaffShift>> getGymShifts(
    String token,
    String gymId, {
    DateTime? from,
    DateTime? to,
  }) =>
      _getShifts(token, {
        'gym_id': gymId,
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      });

  /// GET /shifts?mine=true — the caller's shifts across gyms (default: now →
  /// +30 days).
  Future<List<StaffShift>> getMyShifts(
    String token, {
    DateTime? from,
    DateTime? to,
  }) =>
      _getShifts(token, {
        'mine': 'true',
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      });

  Future<List<StaffShift>> _getShifts(
      String token, Map<String, String> params) async {
    final r = await _client.get(
      Uri.parse('$_base/shifts').replace(queryParameters: params),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => StaffShift.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /shifts/staff?gym_id= — who can be scheduled + whether the caller
  /// can manage shifts at this gym.
  Future<GymShiftStaff> getShiftStaff(String token, String gymId) async {
    final r = await _client.get(
      Uri.parse('$_base/shifts/staff')
          .replace(queryParameters: {'gym_id': gymId}),
      headers: _headers(token),
    );
    _check(r);
    return GymShiftStaff.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// POST /shifts — {gym_id, user_id, starts_at, ends_at, note?}.
  Future<StaffShift> createShift(
      String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/shifts'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return StaffShift.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// PUT /shifts/:id — {user_id?, starts_at?, ends_at?, note?}.
  Future<StaffShift> updateShift(
      String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/shifts/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return StaffShift.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteShift(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/shifts/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400) _check(r);
  }
}
