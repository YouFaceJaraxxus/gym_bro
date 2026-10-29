part of '../api_service.dart';

/// Drafts: the caller's own unfinished posts, exercises, trainings, …
/// Writes go straight to the API (never the offline outbox): a draft that
/// silently failed to save would be lost.
extension DraftsApi on ApiService {
  Future<List<DraftSummary>> getDrafts(String token, DraftKind kind, {String? scopeId}) async {
    final query = 'kind=${kind.apiValue}${scopeId == null ? '' : '&scope_id=$scopeId'}';
    final r = await _client.get(Uri.parse('$_base/drafts?$query'), headers: _headers(token));
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => DraftSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Draft> getDraft(String token, String id) async {
    final r = await _client.get(Uri.parse('$_base/drafts/$id'), headers: _headers(token));
    _check(r);
    return Draft.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Creates a draft, or replaces draft [id]'s title, data and media.
  Future<Draft> saveDraft(
    String token, {
    String? id,
    required DraftKind kind,
    String? scopeId,
    String? title,
    String? thumbnailUrl,
    required Map<String, dynamic> data,
    List<DraftMedia> media = const [],
  }) async {
    final body = jsonEncode({
      if (id == null) 'kind': kind.apiValue,
      if (id == null) 'scope_id': ?scopeId,
      'title': ?title,
      'thumbnail_url': ?thumbnailUrl,
      'data': data,
      'media': media.map((m) => m.toJson()).toList(),
    });
    final r = id == null
        ? await _client.post(Uri.parse('$_base/drafts'), headers: _headers(token), body: body)
        : await _client.put(Uri.parse('$_base/drafts/$id'), headers: _headers(token), body: body);
    _check(r);
    return Draft.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteDraft(String token, String id) async {
    final r = await _client.delete(Uri.parse('$_base/drafts/$id'), headers: _headers(token));
    if (r.statusCode >= 400 && r.statusCode != 404) _check(r);
  }
}
