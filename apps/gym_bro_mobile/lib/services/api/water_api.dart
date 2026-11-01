part of '../api_service.dart';

/// Bumped whenever a drink is added or deleted, so anything showing water
/// (Home, the food diary, home-screen widgets, Health sync) can reload.
final waterChanges = ValueNotifier<int>(0);

/// Water tracking. [tz] is the device's IANA zone (days are counted in it).
extension WaterApi on ApiService {
  String _waterQuery(Map<String, String?> params) {
    final q = {
      for (final e in params.entries)
        if (e.value != null) e.key: e.value!,
    };
    return q.isEmpty ? '' : '?${Uri(queryParameters: q).query}';
  }

  /// GET /water-logs/today — today's drinks, total and goal.
  Future<WaterDay> getWaterToday(String token, {String? tz}) async {
    final r = await _client.get(
      Uri.parse('$_base/water-logs/today${_waterQuery({'tz': tz})}'),
      headers: _headers(token),
    );
    _check(r);
    return WaterDay.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// GET /water-logs/history — one row per day for the last [days] (1–90),
  /// oldest first.
  Future<WaterHistory> getWaterHistory(String token, {int days = 30, String? tz}) async {
    final r = await _client.get(
      Uri.parse('$_base/water-logs/history${_waterQuery({'days': '$days', 'tz': tz})}'),
      headers: _headers(token),
    );
    _check(r);
    return WaterHistory.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// POST /water-logs — logs a drink of [ml] (1–3000) now, or at [loggedAt].
  Future<WaterAdded> addWater(String token, int ml, {DateTime? loggedAt, String? tz}) async {
    final r = await _client.post(
      Uri.parse('$_base/water-logs${_waterQuery({'tz': tz})}'),
      headers: _headers(token),
      body: jsonEncode({
        'ml': ml,
        if (loggedAt != null) 'logged_at': loggedAt.toUtc().toIso8601String(),
      }),
    );
    _check(r);
    waterChanges.value++;
    return WaterAdded.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// DELETE /water-logs/:id — removes one of my drinks (undo); returns today.
  Future<WaterDay> deleteWater(String token, String id, {String? tz}) async {
    final r = await _client.delete(
      Uri.parse('$_base/water-logs/$id${_waterQuery({'tz': tz})}'),
      headers: _headers(token),
    );
    _check(r);
    waterChanges.value++;
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    return WaterDay.fromJson(body['today'] as Map<String, dynamic>);
  }
}
