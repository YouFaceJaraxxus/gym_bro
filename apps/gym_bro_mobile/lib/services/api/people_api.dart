part of '../api_service.dart';

/// Thrown when a private account's posts or lists are requested by someone
/// who doesn't follow them (API 403 `private_account`).
class PrivateAccountException implements Exception {
  const PrivateAccountException();
  @override
  String toString() => 'This account is private';
}

/// Thrown by [PeopleApi.getNearby] until the user shares a location.
class LocationRequiredException implements Exception {
  const LocationRequiredException();
}

/// Profiles, follows, friends, blocks, reports and discovery (/social/*).
extension PeopleApi on ApiService {
  void _throwIfPrivate(http.Response r) {
    if (r.statusCode == 403 && r.body.contains('private_account')) throw const PrivateAccountException();
  }

  List<PersonSummary> _people(http.Response r) =>
      (jsonDecode(r.body) as List).map((e) => PersonSummary.fromJson(e as Map<String, dynamic>)).toList();

  Future<PublicProfile> getMyProfile(String token) async {
    final r = await _client.get(Uri.parse('$_base/social/me'), headers: _headers(token));
    _check(r);
    return PublicProfile.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Any of: bio, interests, is_private, discoverable, who_can_message,
  /// show_activity_status, name, last_name, username, avatar_url.
  Future<PublicProfile> updateMyProfile(String token, Map<String, dynamic> changes) async {
    final r = await _client.put(Uri.parse('$_base/social/me'), headers: _headers(token), body: jsonEncode(changes));
    _check(r);
    return PublicProfile.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Stored rounded to ~1 km; only ever used for distances.
  Future<void> setMyLocation(String token, double lat, double lng) async {
    final r = await _client.put(
      Uri.parse('$_base/social/me/location'),
      headers: _headers(token),
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
    _check(r);
  }

  Future<void> clearMyLocation(String token) async {
    final r = await _client.delete(Uri.parse('$_base/social/me/location'), headers: _headers(token));
    if (r.statusCode >= 400) _check(r);
  }

  Future<SocialBadges> getSocialBadges(String token) async {
    final r = await _client.get(Uri.parse('$_base/social/badges'), headers: _headers(token));
    _check(r);
    return SocialBadges.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<PublicProfile> getProfile(String token, String userId) async {
    final r = await _client.get(Uri.parse('$_base/social/users/$userId'), headers: _headers(token));
    _check(r);
    return PublicProfile.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<PublicProfile> getProfileByUsername(String token, String username) async {
    final r = await _client.get(
      Uri.parse('$_base/social/users/by-username/${Uri.encodeComponent(username)}'),
      headers: _headers(token),
    );
    _check(r);
    return PublicProfile.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// [list]: 'followers', 'following', 'friends' or 'mutual-friends'.
  Future<List<PersonSummary>> getPeopleList(
    String token,
    String userId,
    String list, {
    String query = '',
    int page = 0,
    int pageSize = 30,
  }) async {
    final r = await _client.get(
      Uri.parse('$_base/social/users/$userId/$list?page=$page&page_size=$pageSize&q=${Uri.encodeComponent(query)}'),
      headers: _headers(token),
    );
    _throwIfPrivate(r);
    _check(r);
    return _people(r);
  }

  Future<Relationship?> _relationshipAction(String token, String userId, String action, {required bool add}) async {
    final uri = Uri.parse('$_base/social/users/$userId/$action');
    final r = add ? await _client.post(uri, headers: _headers(token)) : await _client.delete(uri, headers: _headers(token));
    _check(r);
    return Relationship.maybeFromJson((jsonDecode(r.body) as Map<String, dynamic>)['relationship']);
  }

  /// Follows (or requests to follow a private account). Returns the new relationship.
  Future<Relationship?> follow(String token, String userId) => _relationshipAction(token, userId, 'follow', add: true);

  /// Unfollows or cancels a pending request.
  Future<Relationship?> unfollow(String token, String userId) => _relationshipAction(token, userId, 'follow', add: false);

  /// Removes them from my followers.
  Future<Relationship?> removeFollower(String token, String userId) =>
      _relationshipAction(token, userId, 'follower', add: false);

  /// Sends a friend request, or accepts theirs.
  Future<Relationship?> addFriend(String token, String userId) => _relationshipAction(token, userId, 'friend', add: true);

  /// Unfriends, cancels my request or declines theirs.
  Future<Relationship?> removeFriend(String token, String userId) =>
      _relationshipAction(token, userId, 'friend', add: false);

  Future<Relationship?> block(String token, String userId) => _relationshipAction(token, userId, 'block', add: true);
  Future<Relationship?> unblock(String token, String userId) => _relationshipAction(token, userId, 'block', add: false);

  Future<List<PersonSummary>> getBlockedUsers(String token) async {
    final r = await _client.get(Uri.parse('$_base/social/blocks'), headers: _headers(token));
    _check(r);
    return _people(r);
  }

  /// Incoming follow requests (I'm private).
  Future<List<PersonSummary>> getFollowRequests(String token) async {
    final r = await _client.get(Uri.parse('$_base/social/follow-requests'), headers: _headers(token));
    _check(r);
    return _people(r);
  }

  Future<void> respondToFollowRequest(String token, String userId, {required bool accept}) async {
    final uri = Uri.parse('$_base/social/follow-requests/$userId${accept ? '/accept' : ''}');
    final r = accept ? await _client.post(uri, headers: _headers(token)) : await _client.delete(uri, headers: _headers(token));
    _check(r);
  }

  Future<List<FriendRequest>> getFriendRequests(String token, {bool outgoing = false}) async {
    final r = await _client.get(
      Uri.parse('$_base/social/friend-requests?direction=${outgoing ? 'outgoing' : 'incoming'}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => FriendRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> report(String token, {String? userId, String? messageId, required ReportReason reason, String? details}) async {
    final r = await _client.post(
      Uri.parse('$_base/social/reports'),
      headers: _headers(token),
      body: jsonEncode({'user_id': ?userId, 'message_id': ?messageId, 'reason': reason.apiValue, 'details': ?details}),
    );
    _check(r);
  }

  Future<List<PersonSummary>> searchPeople(String token, String query, {int page = 0}) async {
    final r = await _client.get(
      Uri.parse('$_base/social/search?q=${Uri.encodeComponent(query)}&page=$page'),
      headers: _headers(token),
    );
    _check(r);
    return _people(r);
  }

  Future<List<Suggestion>> getSuggestions(String token, {int page = 0, int pageSize = 20}) async {
    final r = await _client.get(
      Uri.parse('$_base/social/suggestions?page=$page&page_size=$pageSize'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => Suggestion.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Throws [LocationRequiredException] until [setMyLocation] was called.
  Future<List<NearbyPerson>> getNearby(String token, {int radiusKm = 25, int page = 0}) async {
    final r = await _client.get(
      Uri.parse('$_base/social/nearby?radius_km=$radiusKm&page=$page'),
      headers: _headers(token),
    );
    if (r.statusCode == 409) throw const LocationRequiredException();
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => NearbyPerson.fromJson(e as Map<String, dynamic>)).toList();
  }
}
