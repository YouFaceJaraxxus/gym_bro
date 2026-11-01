part of '../api_service.dart';

/// Progressive-overload history while logging.
extension SuggestionsApi on ApiService {
  /// GET /training-sessions/last-sets — per exercise, the sets of the most
  /// recent finished session with it. [userId]: a coach logging for a client.
  /// [before]: only sessions that started before then (a back-dated log).
  /// Exercises never logged are missing from the result.
  Future<List<LastPerformance>> getLastSets(
    String token,
    Iterable<String> exerciseIds, {
    String? userId,
    DateTime? before,
  }) async {
    final ids = exerciseIds.toSet().toList();
    if (ids.isEmpty) return const [];
    final query = {
      'exercise_ids': ids.join(','),
      'user_id': ?userId,
      if (before != null) 'before': before.toUtc().toIso8601String(),
    };
    final r = await _client.get(
      Uri.parse('$_base/training-sessions/last-sets').replace(queryParameters: query),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(LastPerformance.fromJson)
        .toList();
  }
}
