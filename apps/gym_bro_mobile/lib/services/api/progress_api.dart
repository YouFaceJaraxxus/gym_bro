part of '../api_service.dart';

/// Exercise progress, personal records and body measurements.
extension ProgressApi on ApiService {
  String _progressQuery(Map<String, String?> params) {
    final entries = params.entries
        .where((e) => e.value != null && e.value!.isNotEmpty)
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value!)}')
        .toList();
    return entries.isEmpty ? '' : '?${entries.join('&')}';
  }

  /// GET /progress/summary — null [userId] = me.
  Future<ProgressSummary> getProgressSummary(String token, {String? userId}) async {
    final r = await _client.get(
      Uri.parse('$_base/progress/summary${_progressQuery({'user_id': userId})}'),
      headers: _headers(token),
    );
    _check(r);
    return ProgressSummary.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// GET /progress/exercises — every exercise the user has logged.
  Future<List<ExerciseProgress>> getExerciseProgressList(String token, {String? userId}) async {
    final r = await _client.get(
      Uri.parse('$_base/progress/exercises${_progressQuery({'user_id': userId})}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => ExerciseProgress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /progress/exercises/:id — per-session series (within [from]/[to])
  /// plus all-time records.
  Future<ExerciseProgressDetail> getExerciseProgress(
    String token,
    String exerciseId, {
    String? userId,
    DateTime? from,
    DateTime? to,
  }) async {
    final q = _progressQuery({
      'user_id': userId,
      'from': from?.toUtc().toIso8601String(),
      'to': to?.toUtc().toIso8601String(),
    });
    final r = await _client.get(
      Uri.parse('$_base/progress/exercises/$exerciseId$q'),
      headers: _headers(token),
    );
    _check(r);
    return ExerciseProgressDetail.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ── Body measurements ──────────────────────────────────────────────────────

  /// GET /body-measurements — oldest first.
  Future<List<BodyMeasurement>> getBodyMeasurements(
    String token, {
    String? userId,
    DateTime? from,
    DateTime? to,
  }) async {
    final q = _progressQuery({
      'user_id': userId,
      'from': from == null ? null : trainingApiDate(from),
      'to': to == null ? null : trainingApiDate(to),
    });
    final r = await _client.get(
      Uri.parse('$_base/body-measurements$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => BodyMeasurement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /body-measurements — {measured_on?, weight_kg?, body_fat_pct?, note?}
  Future<BodyMeasurement> createBodyMeasurement(String token, Map<String, dynamic> data) async {
    final r = await _client.post(
      Uri.parse('$_base/body-measurements'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return BodyMeasurement.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<BodyMeasurement> updateBodyMeasurement(
      String token, String id, Map<String, dynamic> data) async {
    final r = await _client.put(
      Uri.parse('$_base/body-measurements/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return BodyMeasurement.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteBodyMeasurement(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/body-measurements/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400) _check(r);
  }
}
