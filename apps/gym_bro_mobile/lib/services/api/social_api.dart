part of '../api_service.dart';

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
  /// [explore] = only public posts from people I don't follow.
  Future<List<Post>> getFeed(String token, {bool explore = false, int page = 0, int pageSize = 20}) async {
    final r = await _client.get(
      Uri.parse('$_base/posts/feed?mode=${explore ? 'explore' : 'home'}&page=$page&page_size=$pageSize'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

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
  /// [uploadFileToSlot]).
  Future<Post> createPersonalPost(
    String token, {
    required String caption,
    required PostVisibility visibility,
    List<OutgoingAttachment> media = const [],
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/posts'),
      headers: _headers(token),
      body: jsonEncode({
        'content': caption,
        'visibility': visibility.apiValue,
        'media': media.map((m) => m.toJson()).toList(),
      }),
    );
    _check(r);
    return Post.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Edits a post: caption and (personal posts) visibility.
  Future<Post> updatePost(String token, String postId, {String? content, PostVisibility? visibility}) async {
    final r = await _client.put(
      Uri.parse('$_base/posts/$postId'),
      headers: _headers(token),
      body: jsonEncode({'content': ?content, 'visibility': ?visibility?.apiValue}),
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
}
