part of '../api_service.dart';

/// Classes as trainers manage them (timetables, /class-series), class invites,
/// and a trainer's customers (/customers).
extension ClassSeriesApi on ApiService {
  ClassSeries _series(http.Response r) => ClassSeries.fromJson(jsonDecode(r.body) as Map<String, dynamic>);

  List<ClassSeries> _seriesList(http.Response r) =>
      (jsonDecode(r.body) as List).map((e) => ClassSeries.fromJson(e as Map<String, dynamic>)).toList();

  /// GET /class-series — the caller's classes (as trainer or creator), or with
  /// [gymId] every class at that gym (coaches only).
  Future<List<ClassSeries>> getClassSeries(String token, {String? gymId}) async {
    final r = await _client.get(
      Uri.parse('$_base/class-series').replace(queryParameters: gymId == null ? null : {'gym_id': gymId}),
      headers: _headers(token),
    );
    _check(r);
    return _seriesList(r);
  }

  /// GET /class-series/:id — with enrollments when the caller coaches there.
  Future<ClassSeries> getClassSeriesDetail(String token, String id) async {
    final r = await _client.get(Uri.parse('$_base/class-series/$id'), headers: _headers(token));
    _check(r);
    return _series(r);
  }

  /// POST /class-series. [fields]: gym_id, title, description?, location?,
  /// capacity, duration_minutes, repeat ('none' | 'daily' | 'weekly'),
  /// weekdays? (ISO 1–7), times ("HH:MM"), timezone (IANA), starts_on?
  /// ("YYYY-MM-DD"), ends_on?, trainer_id?.
  Future<ClassSeries> createClassSeries(String token, Map<String, dynamic> fields) async {
    final r = await _client.post(Uri.parse('$_base/class-series'), headers: _headers(token), body: jsonEncode(fields));
    _check(r);
    return _series(r);
  }

  /// PUT /class-series/:id — any create field, plus `active`. Timetable
  /// changes cancel sessions that no longer fit and add the new ones.
  Future<ClassSeries> updateClassSeries(String token, String id, Map<String, dynamic> fields) async {
    final r = await _client.put(Uri.parse('$_base/class-series/$id'), headers: _headers(token), body: jsonEncode(fields));
    _check(r);
    return _series(r);
  }

  /// POST /class-series/:id/enrollments — invites someone (they accept or decline).
  Future<List<SeriesEnrollment>> inviteToClassSeries(String token, String seriesId, String userId) async {
    final r = await _client.post(
      Uri.parse('$_base/class-series/$seriesId/enrollments'),
      headers: _headers(token),
      body: jsonEncode({'user_id': userId}),
    );
    _check(r);
    return ((jsonDecode(r.body) as Map<String, dynamic>)['enrollments'] as List)
        .map((e) => SeriesEnrollment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// DELETE /class-series/:id/enrollments/:userId — a coach removes someone,
  /// or the caller leaves (their upcoming bookings are cancelled).
  Future<void> removeClassSeriesEnrollment(String token, String seriesId, String userId) async {
    final r = await _client.delete(
      Uri.parse('$_base/class-series/$seriesId/enrollments/$userId'),
      headers: _headers(token),
    );
    _check(r);
  }

  /// GET /class-series/invites — classes the caller is invited to (pending).
  Future<List<ClassSeries>> getClassInvites(String token) async {
    final r = await _client.get(Uri.parse('$_base/class-series/invites'), headers: _headers(token));
    _check(r);
    return _seriesList(r);
  }

  /// POST /class-series/:id/accept|decline. Accepting books every upcoming session.
  Future<ClassSeries> answerClassInvite(String token, String seriesId, {required bool accept}) async {
    final r = await _client.post(
      Uri.parse('$_base/class-series/$seriesId/${accept ? 'accept' : 'decline'}'),
      headers: _headers(token),
    );
    _check(r);
    return _series(r);
  }

  // ── Customers ──────────────────────────────────────────────────────────────

  /// GET /customers — the caller's customers with their classes of the caller's.
  Future<List<Customer>> getCustomers(String token) async {
    final r = await _client.get(Uri.parse('$_base/customers'), headers: _headers(token));
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /customers/eligible — followers, members of gyms where the caller
  /// coaches, and existing customers, filtered by name/username [query].
  Future<List<EligibleCustomer>> getEligibleCustomers(String token, {String query = ''}) async {
    final q = query.trim();
    final r = await _client.get(
      Uri.parse('$_base/customers/eligible').replace(queryParameters: q.isEmpty ? null : {'q': q}),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => EligibleCustomer.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /customers — adds a customer, optionally inviting them to some of
  /// the caller's classes ([seriesIds] can be empty).
  Future<Customer> addCustomer(String token, String userId, {List<String> seriesIds = const []}) async {
    final r = await _client.post(
      Uri.parse('$_base/customers'),
      headers: _headers(token),
      body: jsonEncode({'user_id': userId, 'series_ids': seriesIds}),
    );
    _check(r);
    return Customer.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// DELETE /customers/:userId — also takes them off the caller's classes.
  Future<void> removeCustomer(String token, String userId) async {
    final r = await _client.delete(Uri.parse('$_base/customers/$userId'), headers: _headers(token));
    _check(r);
  }

  /// GET /customers/invites — trainers who asked to train the caller.
  Future<List<PersonSummary>> getCustomerInvites(String token) async {
    final r = await _client.get(Uri.parse('$_base/customers/invites'), headers: _headers(token));
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => PersonSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /customers/invites/:trainerId/accept|decline. Declining also
  /// declines that trainer's pending class invites.
  Future<void> answerCustomerInvite(String token, String trainerId, {required bool accept}) async {
    final r = await _client.post(
      Uri.parse('$_base/customers/invites/$trainerId/${accept ? 'accept' : 'decline'}'),
      headers: _headers(token),
    );
    _check(r);
  }

  /// GET /customers/trainers — trainers the caller is a customer of.
  Future<List<PersonSummary>> getMyTrainers(String token) async {
    final r = await _client.get(Uri.parse('$_base/customers/trainers'), headers: _headers(token));
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => PersonSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// DELETE /customers/trainers/:trainerId — stops being their customer and
  /// leaves their classes.
  Future<void> leaveTrainer(String token, String trainerId) async {
    final r = await _client.delete(Uri.parse('$_base/customers/trainers/$trainerId'), headers: _headers(token));
    _check(r);
  }
}
