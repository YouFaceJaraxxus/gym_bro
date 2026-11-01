part of '../api_service.dart';

/// Gyms and shops: profiles, applying and review, following, the team and
/// its invites, and the user's trainer switch.
extension BusinessApi on ApiService {
  // ── Profiles ───────────────────────────────────────────────────────────────

  /// GET /businesses — businesses I'm on the team of, with my roles. Owners
  /// get theirs in any status. [side] is `'gym'` or `'shop'`.
  /// Super users pass [all] for every business on the platform.
  Future<List<Business>> getBusinesses(
    String token, {
    String? side,
    bool all = false,
  }) async {
    final params = [if (side != null) 'side=$side', if (all) 'all=1'];
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final r = await _client.get(
      Uri.parse('$_base/businesses$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => Business.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /businesses/search — approved businesses by name or location.
  Future<List<Business>> searchBusinesses(
    String token, {
    String query = '',
    String? side,
  }) async {
    final params = <String>[
      if (query.isNotEmpty) 'q=${Uri.encodeQueryComponent(query)}',
      if (side != null) 'side=$side',
    ];
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final r = await _client.get(
      Uri.parse('$_base/businesses/search$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => Business.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /businesses/:id — the profile, with my roles and its team.
  Future<Business> getBusiness(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/businesses/$id'),
      headers: _headers(token),
    );
    _check(r);
    return Business.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// POST /businesses — applies for a new business; it starts pending.
  Future<Business> createBusiness(
    String token,
    Map<String, dynamic> data,
  ) async {
    final r = await _client.post(
      Uri.parse('$_base/businesses'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Business.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// PUT /businesses/:id — profile fields (owner/staff); `has_gym` and
  /// `has_shop` are owner only.
  Future<Business> updateBusiness(
    String token,
    String id,
    Map<String, dynamic> data,
  ) async {
    final r = await _client.put(
      Uri.parse('$_base/businesses/$id'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _check(r);
    return Business.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// DELETE /businesses/:id — removes the business and everything under it.
  Future<void> deleteBusiness(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/businesses/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  /// PUT|DELETE /businesses/:id/follow. Returns whether I now follow it.
  Future<bool> setFollowingBusiness(
    String token,
    String id, {
    required bool follow,
  }) async {
    final uri = Uri.parse('$_base/businesses/$id/follow');
    final r = follow
        ? await _client.put(uri, headers: _headers(token))
        : await _client.delete(uri, headers: _headers(token));
    _check(r);
    return (jsonDecode(r.body) as Map<String, dynamic>)['is_following']
            as bool? ??
        follow;
  }

  /// Gyms [me] works with: every gym for a super user; otherwise approved
  /// gyms where they're on the team ([frontDesk]: as owner or staff only).
  Future<List<({String id, String name})>> gymsFor(
    String token,
    UserProfile me, {
    bool frontDesk = false,
  }) async {
    if (me.isSuperUser) {
      final all = await getBusinesses(token, side: 'gym', all: true);
      return [for (final b in all) (id: b.id, name: b.name)];
    }
    final mine = frontDesk ? me.staffedGyms : me.workGyms;
    return [for (final b in mine) (id: b.id, name: b.name)];
  }

  // ── Review (super user) ────────────────────────────────────────────────────

  /// GET /businesses/review?status= — the verification queue.
  Future<List<BusinessApplication>> getBusinessReviewQueue(
    String token, {
    BusinessStatus status = BusinessStatus.pending,
  }) async {
    final r = await _client.get(
      Uri.parse('$_base/businesses/review?status=${status.name}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => BusinessApplication.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /businesses/:id/review — approve, reject or block. A note is
  /// required for anything but approving.
  Future<Business> reviewBusiness(
    String token,
    String id, {
    required BusinessStatus status,
    String? note,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/businesses/$id/review'),
      headers: _headers(token),
      body: jsonEncode({'status': status.name, 'note': ?note}),
    );
    _check(r);
    return Business.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// POST /businesses/:id/resubmit — back to pending after a rejection.
  Future<Business> resubmitBusiness(String token, String id) async {
    final r = await _client.post(
      Uri.parse('$_base/businesses/$id/resubmit'),
      headers: _headers(token),
    );
    _check(r);
    return Business.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ── Team ───────────────────────────────────────────────────────────────────

  /// GET /businesses/:id/team — everyone on it; owners and staff also see
  /// open invites and emails.
  Future<List<TeamMember>> getBusinessTeam(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/businesses/$id/team'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => TeamMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /businesses/:id/team — owner invites someone in [role]: an
  /// existing user by [userId] or [email], or a new person by [email] plus
  /// [name], [lastName] and [username] (they get an account invite too).
  Future<void> inviteToTeam(
    String token,
    String businessId, {
    required BusinessRole role,
    String? userId,
    String? email,
    String? name,
    String? lastName,
    String? username,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/businesses/$businessId/team'),
      headers: _headers(token),
      body: jsonEncode({
        'role': role.apiValue,
        'user_id': ?userId,
        'email': ?email,
        'name': ?name,
        'last_name': ?lastName,
        'username': ?username,
      }),
    );
    _check(r);
  }

  /// DELETE /businesses/:id/team/:userId — removes a role (or all of them
  /// without [role]), cancels an invite, or leaves when it's me.
  Future<void> removeFromTeam(
    String token,
    String businessId,
    String userId, {
    BusinessRole? role,
  }) async {
    final q = role == null ? '' : '?role=${role.apiValue}';
    final r = await _client.delete(
      Uri.parse('$_base/businesses/$businessId/team/$userId$q'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  /// GET /businesses/invites — my unanswered team invites.
  Future<List<BusinessInvite>> getMyBusinessInvites(String token) async {
    final r = await _client.get(
      Uri.parse('$_base/businesses/invites'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => BusinessInvite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /businesses/:id/invites/:role/accept|decline.
  Future<void> answerBusinessInvite(
    String token,
    String businessId,
    BusinessRole role, {
    required bool accept,
  }) async {
    final action = accept ? 'accept' : 'decline';
    final r = await _client.post(
      Uri.parse('$_base/businesses/$businessId/invites/${role.apiValue}/$action'),
      headers: _headers(token),
    );
    _check(r);
  }

  // ── Me ─────────────────────────────────────────────────────────────────────

  /// PUT /users/me/trainer — switches the trainer tools on or off. Off also
  /// leaves every gym I train at. Returns my refreshed profile.
  Future<UserProfile> setTrainer(String token, {required bool enabled}) async {
    final r = await _client.put(
      Uri.parse('$_base/users/me/trainer'),
      headers: _headers(token),
      body: jsonEncode({'enabled': enabled}),
    );
    _check(r);
    return UserProfile.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// GET /users/me — my profile with my businesses and invite count.
  Future<UserProfile> getMe(String token) async {
    final r = await _client.get(
      Uri.parse('$_base/users/me'),
      headers: _headers(token),
    );
    _check(r);
    return UserProfile.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
