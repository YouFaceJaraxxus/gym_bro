part of '../api_service.dart';

/// Planned workouts and meals on the calendar (plan-entries), and changes to
/// the enrolments (routine / meal plan assignments) they come from.
extension PlansApi on ApiService {
  // ── Plan entries ───────────────────────────────────────────────────────────

  /// GET /plan-entries?from=&to=&tz= — entries starting in [from, to) (at most
  /// 62 days), generated as needed. [timezone] is the device's IANA zone (used
  /// for enrolments that don't name their own).
  Future<List<PlanEntry>> getPlanEntries(
    String token, {
    required DateTime from,
    required DateTime to,
    String? timezone,
    String? userId,
  }) async {
    final params = <String, String>{
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      'tz': ?timezone,
      'user_id': ?userId,
    };
    final r = await _client.get(
      Uri.parse('$_base/plan-entries').replace(queryParameters: params),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => PlanEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /plan-entries/:id — with the planned items (meals) or the training's
  /// exercises (workouts), and what was logged against it.
  Future<PlanEntryDetail> getPlanEntry(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/plan-entries/$id'),
      headers: _headers(token),
    );
    _check(r);
    return PlanEntryDetail.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// PUT /plan-entries/:id — only the given fields change. [note] '' clears
  /// it; [trainingId] is for workouts only.
  Future<PlanEntry> updatePlanEntry(
    String token,
    String id, {
    DateTime? startsAt,
    int? durationMinutes,
    String? trainingId,
    String? note,
    bool? skipped,
  }) async {
    final r = await _client.put(
      Uri.parse('$_base/plan-entries/$id'),
      headers: _headers(token),
      body: jsonEncode({
        if (startsAt != null) 'starts_at': startsAt.toUtc().toIso8601String(),
        'duration_minutes': ?durationMinutes,
        'training_id': ?trainingId,
        'note': ?note,
        'skipped': ?skipped,
      }),
    );
    _check(r);
    return PlanEntry.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// DELETE /plan-entries/:id — skips it (entries can't be removed; they'd
  /// be generated again). Undo with [updatePlanEntry] `skipped: false`.
  Future<void> skipPlanEntry(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/plan-entries/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400) _check(r);
  }

  /// POST /plan-entries/:id/confirm — logs it as planned: a finished session
  /// with the training's sets (workouts), or the slot's planned items in the
  /// food diary (meals). [startedAt] defaults to the planned start.
  Future<PlanEntry> confirmPlanEntry(
    String token,
    String id, {
    DateTime? startedAt,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/plan-entries/$id/confirm'),
      headers: _headers(token),
      body: jsonEncode({
        if (startedAt != null)
          'started_at': startedAt.toUtc().toIso8601String(),
      }),
    );
    _check(r);
    return PlanEntry.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ── Enrolments ────────────────────────────────────────────────────────────

  /// PUT /routine-assignments/:id — any of start_date, end_date (null
  /// clears), note, timezone, workout_time ('HH:MM'). Upcoming planned
  /// workouts that weren't touched are regenerated.
  Future<RoutineAssignment> updateRoutineAssignment(
    String token,
    String id,
    Map<String, dynamic> data,
  ) async {
    final r = await _client.put(
      Uri.parse('$_base/routine-assignments/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return RoutineAssignment.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  }

  /// PUT /meal-plan-assignments/:id — any of start_date, end_date (null
  /// clears), note, timezone. Upcoming planned meals that weren't touched are
  /// regenerated.
  Future<MealPlanAssignment> updateMealPlanAssignment(
    String token,
    String id,
    Map<String, dynamic> data,
  ) async {
    final r = await _client.put(
      Uri.parse('$_base/meal-plan-assignments/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return MealPlanAssignment.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  }
}
