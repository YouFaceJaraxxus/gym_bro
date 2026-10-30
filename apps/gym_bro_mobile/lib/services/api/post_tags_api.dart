part of '../api_service.dart';

/// Thrown when sharing a workout or meal that hasn't happened yet (API 400
/// `future_activity`).
class FutureActivityException implements Exception {
  const FutureActivityException();
  @override
  String toString() => 'You can share this once it has happened';
}

/// Post types, mentions and photo tags.
extension PostTagsApi on ApiService {
  void _throwIfFutureActivity(http.Response r) {
    if (r.statusCode == 400 && r.body.contains('future_activity')) throw const FutureActivityException();
  }

  /// Suggestions for "@" in a caption or comment: people (the ones I follow
  /// first; all of them for an empty [query]), then gyms/shops, then products.
  Future<List<MentionSuggestion>> searchMentions(
    String token,
    String query, {
    Set<MentionKind> kinds = const {MentionKind.user, MentionKind.business, MentionKind.shopItem},
  }) async {
    final q = Uri.encodeQueryComponent(query);
    final k = kinds.map((k) => k.apiValue).join(',');
    final r = await _client.get(Uri.parse('$_base/posts/mention-search?q=$q&kinds=$k'), headers: _headers(token));
    _check(r);
    return [
      for (final e in jsonDecode(r.body) as List) ?MentionSuggestion.maybeFromJson(e as Map<String, dynamic>),
    ];
  }

  /// Posts [userId] is pinned in or mentioned in the caption of, newest
  /// first (the profile's "Tagged" tab). Throws [PrivateAccountException].
  Future<List<Post>> getTaggedPosts(String token, String userId, {int page = 0, int pageSize = 30}) async {
    final r = await _client.get(
      Uri.parse('$_base/posts?tagged_user_id=$userId&page=$page&page_size=$pageSize'),
      headers: _headers(token),
    );
    _throwIfPrivate(r);
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Replaces the people pinned on the given photos of my post
  /// (post_image id → pins).
  Future<Post> updatePhotoTags(String token, String postId, Map<String, List<PhotoTag>> tagsByImage) async {
    final r = await _client.put(
      Uri.parse('$_base/posts/$postId'),
      headers: _headers(token),
      body: jsonEncode({
        'photo_tags': [
          for (final e in tagsByImage.entries)
            {'post_image_id': e.key, 'tags': [for (final t in e.value) t.toRequestJson()]},
        ],
      }),
    );
    _check(r);
    return Post.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Takes me off the photos of a post I'm tagged in.
  Future<void> removeMyPhotoTags(String token, String postId) async {
    final r = await _client.delete(Uri.parse('$_base/posts/$postId/tags/me'), headers: _headers(token));
    if (r.statusCode >= 400) _check(r);
  }

  /// One product (public), for opening a mentioned product.
  Future<ShopItem> getShopItem(String token, String id) async {
    final r = await _client.get(Uri.parse('$_base/shop-items/$id'), headers: _headers(token));
    _check(r);
    return ShopItem.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
