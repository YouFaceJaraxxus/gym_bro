part of '../api_service.dart';

/// Bumped whenever I join, leave, create, edit or delete a challenge, so
/// what lists them (the Gym tab card, the challenges page) reloads.
final challengeChanges = ValueNotifier<int>(0);

/// Challenges: time-boxed goals people join together.
extension ChallengesApi on ApiService {
  String _tzQuery(String? tz) => tz == null ? '' : 'tz=${Uri.encodeQueryComponent(tz)}';

  /// GET /challenges — visible challenges with my progress. [past] lists
  /// the ones that ended; otherwise active and upcoming ones.
  Future<ChallengeList> getChallenges(String token, {bool past = false, String? gymId, bool joinedOnly = false, String? tz}) async {
    final q = [
      if (past) 'status=past',
      if (gymId != null) 'gym_id=${Uri.encodeQueryComponent(gymId)}',
      if (joinedOnly) 'joined=1',
      if (tz != null) _tzQuery(tz),
    ].join('&');
    final r = await _client.get(Uri.parse('$_base/challenges${q.isEmpty ? '' : '?$q'}'), headers: _headers(token));
    _check(r);
    return ChallengeList.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// GET /challenges/:id — with the leaderboard.
  Future<Challenge> getChallenge(String token, String id, {String? tz}) async {
    final q = tz == null ? '' : '?${_tzQuery(tz)}';
    final r = await _client.get(Uri.parse('$_base/challenges/$id$q'), headers: _headers(token));
    _check(r);
    return Challenge.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// POST /challenges.
  Future<Challenge> createChallenge(String token, ChallengeDraft draft, {String? tz}) async {
    final q = tz == null ? '' : '?${_tzQuery(tz)}';
    final r = await _client.post(Uri.parse('$_base/challenges$q'), headers: _headers(token), body: jsonEncode(draft.toJson()));
    _check(r);
    challengeChanges.value++;
    return Challenge.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// PATCH /challenges/:id — only the fields in [changes].
  Future<Challenge> updateChallenge(String token, String id, Map<String, dynamic> changes, {String? tz}) async {
    final q = tz == null ? '' : '?${_tzQuery(tz)}';
    final r = await _client.patch(Uri.parse('$_base/challenges/$id$q'), headers: _headers(token), body: jsonEncode(changes));
    _check(r);
    challengeChanges.value++;
    return Challenge.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// DELETE /challenges/:id.
  Future<void> deleteChallenge(String token, String id) async {
    final r = await _client.delete(Uri.parse('$_base/challenges/$id'), headers: _headers(token));
    _check(r);
    challengeChanges.value++;
  }

  /// POST /challenges/:id/join — returns it with my progress (workouts
  /// earlier in its dates count).
  Future<Challenge> joinChallenge(String token, String id, {String? tz}) async {
    final q = tz == null ? '' : '?${_tzQuery(tz)}';
    final r = await _client.post(Uri.parse('$_base/challenges/$id/join$q'), headers: _headers(token));
    _check(r);
    challengeChanges.value++;
    return Challenge.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// DELETE /challenges/:id/join.
  Future<void> leaveChallenge(String token, String id) async {
    final r = await _client.delete(Uri.parse('$_base/challenges/$id/join'), headers: _headers(token));
    _check(r);
    challengeChanges.value++;
  }

  /// GET /challenges/completed?user_id= — someone's medals (mine without [userId]).
  Future<ChallengeMedals> getChallengeMedals(String token, {String? userId}) async {
    final q = userId == null ? '' : '?user_id=${Uri.encodeQueryComponent(userId)}';
    final r = await _client.get(Uri.parse('$_base/challenges/completed$q'), headers: _headers(token));
    _check(r);
    return ChallengeMedals.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
