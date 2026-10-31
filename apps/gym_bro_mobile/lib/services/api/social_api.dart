part of '../api_service.dart';

/// Which ranked feed GET /posts/feed returns.
enum FeedMode {
  /// People I follow, my gyms, popular public posts.
  home('home'),

  /// Only public posts from people I don't follow.
  explore('explore'),

  /// Personal posts that open with a video (the vertical player).
  reels('reels');

  const FeedMode(this.apiValue);
  final String apiValue;
}

/// Thrown by [SocialApi.pinPost] when three posts are already pinned (API
/// 409 `pin_limit`).
class PostPinLimitException implements Exception {
  const PostPinLimitException();
  @override
  String toString() => 'Up to 3 posts can be pinned';
}

/// Posts beyond the business feed: personal posts, the ranked feed,
/// reactions and threaded comments.
extension SocialApi on ApiService {
  Future<Post> getPost(String token, String postId) async {
    final r = await _client.get(
      Uri.parse('$_base/posts/$postId'),
      headers: _headers(token),
    );
    _check(r);
    return Post.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Ranked home feed (people I follow, my gyms, popular public posts), or
  /// [explore] = only public posts from people I don't follow. [mode] wins
  /// over [explore] when given (e.g. [FeedMode.reels]).
  Future<List<Post>> getFeed(
    String token, {
    bool explore = false,
    FeedMode? mode,
    int page = 0,
    int pageSize = 20,
  }) async {
    final m = mode ?? (explore ? FeedMode.explore : FeedMode.home);
    final r = await _client.get(
      Uri.parse('$_base/posts/feed?mode=${m.apiValue}&page=$page&page_size=$pageSize'),
      headers: _headers(token),
    );
    _check(r);
    return _posts(r);
  }

  List<Post> _posts(http.Response r) =>
      (jsonDecode(r.body) as List).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();

  /// A person's own posts, newest first. Throws [PrivateAccountException]
  /// for a private account I don't follow. [mediaOnly] = the profile grid.
  Future<List<Post>> getUserPosts(
    String token,
    String userId, {
    bool mediaOnly = false,
    int page = 0,
    int pageSize = 30,
  }) async {
    final r = await _client.get(
      Uri.parse('$_base/posts?author_id=$userId&page=$page&page_size=$pageSize${mediaOnly ? '&media=only' : ''}'),
      headers: _headers(token),
    );
    _throwIfPrivate(r);
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Reserves a path for a photo/video and returns where to upload it.
  Future<UploadSlot> requestPostUpload(String token, {required String mimeType, required int sizeBytes, String? fileName}) async {
    final r = await _client.post(
      Uri.parse('$_base/posts/uploads'),
      headers: _headers(token),
      body: jsonEncode({'mime_type': mimeType, 'size_bytes': sizeBytes, 'file_name': ?fileName}),
    );
    _check(r);
    return UploadSlot.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Creates a personal post from uploaded media (see [requestPostUpload] and
  /// [uploadFileToSlot]). [tags] are the people pinned on each media item (by
  /// index); [share] makes it a typed post sharing a workout, meal or item.
  /// [hideLikeCount], [commentsDisabled] and [locationName] are sent only
  /// when set (a blank location is left out).
  /// Throws [FutureActivityException] when [share] hasn't happened yet.
  Future<Post> createPersonalPost(
    String token, {
    required String caption,
    required PostVisibility visibility,
    List<OutgoingAttachment> media = const [],
    List<List<PhotoTag>> tags = const [],
    ShareTarget? share,
    bool? hideLikeCount,
    bool? commentsDisabled,
    String? locationName,
  }) async {
    final location = locationName?.trim();
    final r = await _client.post(
      Uri.parse('$_base/posts'),
      headers: _headers(token),
      body: jsonEncode({
        'content': caption,
        'visibility': visibility.apiValue,
        'media': [
          for (final (i, m) in media.indexed)
            {
              ...m.toJson(),
              if (i < tags.length && tags[i].isNotEmpty) 'tags': [for (final t in tags[i]) t.toRequestJson()],
            },
        ],
        ...?share?.toRequestJson(),
        'hide_like_count': ?hideLikeCount,
        'comments_disabled': ?commentsDisabled,
        if (location != null && location.isNotEmpty) 'location_name': location,
      }),
    );
    _throwIfFutureActivity(r);
    _check(r);
    return Post.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Edits a post: caption and (personal posts) visibility, hidden like
  /// count, comments off and location. Null leaves a field as it is; a blank
  /// [locationName] clears the location (sends `location_name: null`).
  Future<Post> updatePost(
    String token,
    String postId, {
    String? content,
    PostVisibility? visibility,
    bool? hideLikeCount,
    bool? commentsDisabled,
    String? locationName,
  }) async {
    final location = locationName?.trim();
    final r = await _client.put(
      Uri.parse('$_base/posts/$postId'),
      headers: _headers(token),
      body: jsonEncode({
        'content': ?content,
        'visibility': ?visibility?.apiValue,
        'hide_like_count': ?hideLikeCount,
        'comments_disabled': ?commentsDisabled,
        if (location != null) 'location_name': location.isEmpty ? null : location,
      }),
    );
    _check(r);
    return Post.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ── Reactions ─────────────────────────────────────────────────────────────

  /// Sets or switches my reaction; null removes it.
  Future<ReactionResult> reactToPost(String token, String postId, ReactionType? reaction) async {
    final uri = Uri.parse('$_base/posts/$postId/reaction');
    final r = reaction == null
        ? await _client.delete(uri, headers: _headers(token))
        : await _client.put(uri, headers: _headers(token), body: jsonEncode({'reaction': reaction.apiValue}));
    _check(r);
    return ReactionResult.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Who reacted, optionally only with [reaction].
  Future<List<Reactor>> getPostReactions(String token, String postId, {ReactionType? reaction, int page = 0}) async {
    final r = await _client.get(
      Uri.parse('$_base/posts/$postId/reactions?page=$page${reaction == null ? '' : '&reaction=${reaction.apiValue}'}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => Reactor.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Idempotent; same as reacting with 👍.
  Future<ReactionResult> likePost(String token, String postId) => reactToPost(token, postId, ReactionType.like);

  /// Idempotent; removes my reaction whatever it was.
  Future<ReactionResult> unlikePost(String token, String postId) => reactToPost(token, postId, null);

  // ── Comments ──────────────────────────────────────────────────────────────

  /// One page of top-level comments ([sort]: 'top', 'new' or 'old') plus
  /// every reply under them, flat (build the tree from parentId/depth).
  Future<List<PostComment>> getPostComments(
    String token,
    String postId, {
    String sort = 'top',
    int page = 0,
    int pageSize = 20,
  }) async {
    final r = await _client.get(
      Uri.parse('$_base/posts/$postId/comments?sort=$sort&page=$page&page_size=$pageSize'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => PostComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// A comment, or a reply when [parentId] is set (up to ten levels deep).
  Future<PostComment> createPostComment(String token, String postId, String body, {String? parentId}) async {
    final r = await _client.post(
      Uri.parse('$_base/posts/$postId/comments'),
      headers: _headers(token),
      body: jsonEncode({'body': body, 'parent_id': ?parentId}),
    );
    _check(r);
    return PostComment.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<PostComment> updatePostComment(
      String token, String commentId, String body) async {
    final r = await _client.put(
      Uri.parse('$_base/posts/comments/$commentId'),
      headers: _headers(token),
      body: jsonEncode({'body': body}),
    );
    _check(r);
    return PostComment.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// A comment with replies stays as a "deleted" placeholder.
  Future<void> deletePostComment(String token, String commentId) async {
    final r = await _client.delete(
      Uri.parse('$_base/posts/comments/$commentId'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400) _check(r);
  }

  /// Sets or switches my reaction on a comment; null removes it.
  Future<PostComment> reactToComment(String token, String commentId, ReactionType? reaction) async {
    final uri = Uri.parse('$_base/posts/comments/$commentId/reaction');
    final r = reaction == null
        ? await _client.delete(uri, headers: _headers(token))
        : await _client.put(uri, headers: _headers(token), body: jsonEncode({'reaction': reaction.apiValue}));
    _check(r);
    return PostComment.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ── Pins ──────────────────────────────────────────────────────────────────

  /// Pins my post to the top of my profile. Throws [PostPinLimitException] when
  /// three are pinned already.
  Future<Post> pinPost(String token, String postId) async {
    final r = await _client.put(Uri.parse('$_base/posts/$postId/pin'), headers: _headers(token));
    if (r.statusCode == 409 && r.body.contains('pin_limit')) throw const PostPinLimitException();
    _check(r);
    return Post.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Post> unpinPost(String token, String postId) async {
    final r = await _client.delete(Uri.parse('$_base/posts/$postId/pin'), headers: _headers(token));
    _check(r);
    return Post.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ── Saved posts & collections ─────────────────────────────────────────────

  /// Saves a post (idempotent), also filing it into [collectionId] when given.
  Future<void> savePost(String token, String postId, {String? collectionId}) async {
    final r = await _client.put(
      Uri.parse('$_base/posts/$postId/save'),
      headers: _headers(token),
      body: jsonEncode({'collection_id': ?collectionId}),
    );
    _check(r);
  }

  /// Unsaves a post everywhere (all my collections too).
  Future<void> unsavePost(String token, String postId) async {
    final r = await _client.delete(Uri.parse('$_base/posts/$postId/save'), headers: _headers(token));
    _check(r);
  }

  /// Saved posts I can still see, newest save first; only [collectionId]'s
  /// when given.
  Future<List<Post>> getSavedPosts(String token, {String? collectionId, int page = 0, int pageSize = 30}) async {
    final c = collectionId == null ? '' : '&collection_id=${Uri.encodeQueryComponent(collectionId)}';
    final r = await _client.get(
      Uri.parse('$_base/posts/saved?page=$page&page_size=$pageSize$c'),
      headers: _headers(token),
    );
    _check(r);
    return _posts(r);
  }

  /// "All posts" and my collections; with [postId], whether it's saved and
  /// which collections hold it.
  Future<SavedOverview> getSaveCollections(String token, {String? postId}) async {
    final q = postId == null ? '' : '?post_id=${Uri.encodeQueryComponent(postId)}';
    final r = await _client.get(Uri.parse('$_base/posts/collections$q'), headers: _headers(token));
    _check(r);
    return SavedOverview.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// A new collection, optionally starting with [postIds] (saved too).
  Future<SaveCollection> createSaveCollection(String token, String name, {List<String> postIds = const []}) async {
    final r = await _client.post(
      Uri.parse('$_base/posts/collections'),
      headers: _headers(token),
      body: jsonEncode({'name': name, if (postIds.isNotEmpty) 'post_ids': postIds}),
    );
    _check(r);
    return SaveCollection.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<SaveCollection> renameSaveCollection(String token, String collectionId, String name) async {
    final r = await _client.put(
      Uri.parse('$_base/posts/collections/$collectionId'),
      headers: _headers(token),
      body: jsonEncode({'name': name}),
    );
    _check(r);
    return SaveCollection.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Deletes the collection; its posts stay saved.
  Future<void> deleteSaveCollection(String token, String collectionId) async {
    final r = await _client.delete(Uri.parse('$_base/posts/collections/$collectionId'), headers: _headers(token));
    _check(r);
  }

  /// Files a post into a collection (saving it too).
  Future<void> addToSaveCollection(String token, String collectionId, String postId) async {
    final r = await _client.put(
      Uri.parse('$_base/posts/collections/$collectionId/posts/$postId'),
      headers: _headers(token),
    );
    _check(r);
  }

  /// Takes a post out of a collection (it stays saved).
  Future<void> removeFromSaveCollection(String token, String collectionId, String postId) async {
    final r = await _client.delete(
      Uri.parse('$_base/posts/collections/$collectionId/posts/$postId'),
      headers: _headers(token),
    );
    _check(r);
  }

  /// Posts I reacted to, most recent reaction first.
  Future<List<Post>> getLikedPosts(String token, {int page = 0, int pageSize = 30}) async {
    final r = await _client.get(Uri.parse('$_base/posts/liked?page=$page&page_size=$pageSize'), headers: _headers(token));
    _check(r);
    return _posts(r);
  }

  // ── Hashtags ──────────────────────────────────────────────────────────────

  /// Tags starting with [query] ("#" optional), most used first.
  Future<List<HashtagInfo>> searchHashtags(String token, String query) async {
    final r = await _client.get(
      Uri.parse('$_base/posts/hashtags?q=${Uri.encodeQueryComponent(query)}'),
      headers: _headers(token),
    );
    _check(r);
    return [
      for (final e in jsonDecode(r.body) as List) HashtagInfo.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// A tag and how many posts use it.
  Future<HashtagInfo> getHashtag(String token, String tag) async {
    final r = await _client.get(
      Uri.parse('$_base/posts/hashtags/${Uri.encodeComponent(tag)}'),
      headers: _headers(token),
    );
    _check(r);
    return HashtagInfo.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Posts with [tag] I can see; [sort] is 'top' or 'recent'.
  Future<List<Post>> getHashtagPosts(String token, String tag, {String sort = 'top', int page = 0, int pageSize = 30}) async {
    final r = await _client.get(
      Uri.parse(
        '$_base/posts?hashtag=${Uri.encodeQueryComponent(tag)}&sort=$sort&page=$page&page_size=$pageSize',
      ),
      headers: _headers(token),
    );
    _check(r);
    return _posts(r);
  }
}
