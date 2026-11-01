part of '../api_service.dart';

/// Bumped whenever a workout is finished, logged or deleted: the streak may
/// have moved, so what shows it reloads.
final streakChanges = ValueNotifier<int>(0);

/// Workout streaks and gym boards.
extension StreaksApi on ApiService {
  /// GET /streaks — my streak, brought up to date. [tz] is the device zone
  /// (streak days are counted in it).
  Future<StreakStatus> getStreak(String token, {String? tz}) async {
    final q = tz == null ? '' : '?tz=${Uri.encodeQueryComponent(tz)}';
    final r = await _client.get(Uri.parse('$_base/streaks$q'), headers: _headers(token));
    _check(r);
    return StreakStatus.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// GET /streaks?user_id= — someone's public streak.
  Future<StreakSummary> getUserStreak(String token, String userId) async {
    final r = await _client.get(
      Uri.parse('$_base/streaks?user_id=${Uri.encodeQueryComponent(userId)}'),
      headers: _headers(token),
    );
    _check(r);
    return StreakSummary.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// GET /streaks/boards/:gymId — the gym's board (top 50 + me).
  Future<GymBoard> getGymBoard(String token, String gymId, GymBoardKind kind, {String? tz}) async {
    final q = 'board=${kind.apiValue}${tz == null ? '' : '&tz=${Uri.encodeQueryComponent(tz)}'}';
    final r = await _client.get(Uri.parse('$_base/streaks/boards/$gymId?$q'), headers: _headers(token));
    _check(r);
    return GymBoard.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
