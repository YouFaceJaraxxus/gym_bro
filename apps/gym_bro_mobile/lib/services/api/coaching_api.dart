part of '../api_service.dart';

/// Routine assignments and session comments.
extension CoachingApi on ApiService {
  // ── Routine assignments ────────────────────────────────────────────────────

  /// GET /routine-assignments — filter by target [userId], [routineId] or
  /// [assignedById]. Without filters: rows where I'm the target or assigner.
  Future<List<RoutineAssignment>> getRoutineAssignments(
    String token, {
    String? userId,
    String? routineId,
    String? assignedById,
  }) async {
    final params = <String>[
      if (userId != null) 'user_id=$userId',
      if (routineId != null) 'routine_id=$routineId',
      if (assignedById != null) 'assigned_by_id=$assignedById',
    ];
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final r = await _client.get(
      Uri.parse('$_base/routine-assignments$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => RoutineAssignment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /routine-assignments — {routine_id, user_id, start_date?, end_date?, note?}
  Future<RoutineAssignment> createRoutineAssignment(
      String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/routine-assignments'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return RoutineAssignment.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteRoutineAssignment(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/routine-assignments/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400) _check(r);
  }

  // ── Session comments ───────────────────────────────────────────────────────

  Future<List<SessionComment>> getSessionComments(String token, String sessionId) async {
    final r = await _client.get(
      Uri.parse('$_base/training-sessions/$sessionId/comments'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => SessionComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SessionComment> addSessionComment(String token, String sessionId, String body) async {
    final r = await _client.post(
      Uri.parse('$_base/training-sessions/$sessionId/comments'),
      headers: _headers(token),
      body: jsonEncode({'body': body}),
    );
    _check(r);
    return SessionComment.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<SessionComment> updateSessionComment(String token, String commentId, String body) async {
    final r = await _client.put(
      Uri.parse('$_base/training-sessions/comments/$commentId'),
      headers: _headers(token),
      body: jsonEncode({'body': body}),
    );
    _check(r);
    return SessionComment.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteSessionComment(String token, String commentId) async {
    final r = await _client.delete(
      Uri.parse('$_base/training-sessions/comments/$commentId'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400) _check(r);
  }
}
