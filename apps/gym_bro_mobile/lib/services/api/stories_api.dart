part of '../api_service.dart';

/// Stories (/stories/*), sharing to chats (/chat/share, /chat/story-replies)
/// and the post archive (/posts/:id/archive, /posts/archive).
extension StoriesApi on ApiService {
  // ── Stories ─────────────────────────────────────────────────────────────────

  /// The tray: me first (when I have live stories), then the people I follow
  /// — unwatched first.
  Future<List<StoryTrayEntry>> getStoryTray(String token) async {
    final r = await _client.get(Uri.parse('$_base/stories/feed'), headers: _headers(token));
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => StoryTrayEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Someone's live stories I can see, oldest first (empty when none / not allowed).
  Future<List<Story>> getUserStories(String token, String userId) async {
    final r = await _client.get(Uri.parse('$_base/stories?user_id=$userId'), headers: _headers(token));
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => Story.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// One story (mine: also after it expired).
  Future<Story> getStory(String token, String storyId) async {
    final r = await _client.get(Uri.parse('$_base/stories/$storyId'), headers: _headers(token));
    _check(r);
    return Story.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// My stories created in [from, to) — live and expired — newest first.
  Future<List<Story>> getStoryArchive(String token, {DateTime? from, DateTime? to, int pageSize = 500}) async {
    final r = await _client.get(Uri.parse('$_base/stories/archive?${_range(from, to)}page_size=$pageSize'), headers: _headers(token));
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => Story.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UploadSlot> requestStoryUpload(String token, {required String mimeType, required int sizeBytes, String? fileName}) async {
    final r = await _client.post(
      Uri.parse('$_base/stories/uploads'),
      headers: _headers(token),
      body: jsonEncode({'mime_type': mimeType, 'size_bytes': sizeBytes, 'file_name': ?fileName}),
    );
    _check(r);
    return UploadSlot.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Posts a story: uploaded [media] (see [requestStoryUpload]), text on a
  /// [background] colour, and/or something shared. Throws
  /// [FutureActivityException] for a workout/meal that hasn't happened yet.
  Future<Story> createStory(
    String token, {
    OutgoingAttachment? media,
    String? caption,
    String? background,
    ShareRequest? share,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/stories'),
      headers: _headers(token),
      body: jsonEncode({
        if (media != null)
          'media': {
            'path': media.path,
            'width': ?media.width,
            'height': ?media.height,
            'duration_ms': ?media.durationMs,
          },
        if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
        'background': ?background,
        'share': ?share?.toJson(),
      }),
    );
    if (r.statusCode == 400 && r.body.contains('future_activity')) throw const FutureActivityException();
    _check(r);
    return Story.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteStory(String token, String storyId) async {
    final r = await _client.delete(Uri.parse('$_base/stories/$storyId'), headers: _headers(token));
    if (r.statusCode >= 400) _check(r);
  }

  /// Records that I watched it (no-op for my own).
  Future<void> markStoryViewed(String token, String storyId) async {
    final r = await _client.post(Uri.parse('$_base/stories/$storyId/view'), headers: _headers(token));
    if (r.statusCode >= 400) _check(r);
  }

  /// Likes ([ReactionType.like]) or reacts; null takes it back. The first
  /// one notifies the author.
  Future<StoryReactionResult> reactToStory(String token, String storyId, ReactionType? reaction) async {
    final uri = Uri.parse('$_base/stories/$storyId/reaction');
    final r = reaction == null
        ? await _client.delete(uri, headers: _headers(token))
        : await _client.put(uri, headers: _headers(token), body: jsonEncode({'reaction': reaction.apiValue}));
    _check(r);
    return StoryReactionResult.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// My story's viewers, those who reacted first.
  Future<List<StoryViewer>> getStoryViewers(String token, String storyId, {int page = 0}) async {
    final r = await _client.get(Uri.parse('$_base/stories/$storyId/viewers?page=$page'), headers: _headers(token));
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => StoryViewer.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Replies to someone's story with text, or a quick [reaction] — sent to
  /// their DMs with the story attached.
  Future<ChatMessage> replyToStory(String token, String storyId, {String? body, ReactionType? reaction, String? clientId}) async {
    final r = await _client.post(
      Uri.parse('$_base/chat/story-replies'),
      headers: _headers(token),
      body: jsonEncode({
        'story_id': storyId,
        'body': ?body,
        'reaction': ?reaction?.apiValue,
        'client_id': ?clientId,
      }),
    );
    _check(r);
    return ChatMessage.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ── Sharing in chat ─────────────────────────────────────────────────────────

  /// Sends [share] to each person (their direct chat) and each chat, with an
  /// optional [body]. Throws when nothing could be sent; otherwise returns
  /// each target's outcome.
  Future<List<ShareSendResult>> shareToChats(
    String token,
    ShareRequest share, {
    List<String> userIds = const [],
    List<String> conversationIds = const [],
    String? body,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/chat/share'),
      headers: _headers(token),
      body: jsonEncode({
        'share': share.toJson(),
        if (userIds.isNotEmpty) 'user_ids': userIds,
        if (conversationIds.isNotEmpty) 'conversation_ids': conversationIds,
        if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
      }),
    );
    if (r.statusCode == 400 && r.body.contains('future_activity')) throw const FutureActivityException();
    _check(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return (data['results'] as List<dynamic>? ?? [])
        .map((e) => ShareSendResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// One message, its share resolved for me (realtime payloads carry them
  /// unresolved — see [ChatMessage.needsResolve]).
  Future<ChatMessage> getChatMessage(String token, String messageId) async {
    final r = await _client.get(Uri.parse('$_base/chat/messages/$messageId'), headers: _headers(token));
    _check(r);
    return ChatMessage.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ── Post archive ────────────────────────────────────────────────────────────

  /// Hides my post from everyone else (profile, feed, shares) until
  /// [unarchivePost].
  Future<Post> archivePost(String token, String postId) async {
    final r = await _client.put(Uri.parse('$_base/posts/$postId/archive'), headers: _headers(token));
    _check(r);
    return Post.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Post> unarchivePost(String token, String postId) async {
    final r = await _client.delete(Uri.parse('$_base/posts/$postId/archive'), headers: _headers(token));
    _check(r);
    return Post.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// My archived posts created in [from, to), newest first.
  Future<List<Post>> getArchivedPosts(String token, {DateTime? from, DateTime? to, int pageSize = 500}) async {
    final r = await _client.get(Uri.parse('$_base/posts/archive?${_range(from, to)}page_size=$pageSize'), headers: _headers(token));
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  String _range(DateTime? from, DateTime? to) => [
    if (from != null) 'from=${Uri.encodeQueryComponent(from.toUtc().toIso8601String())}&',
    if (to != null) 'to=${Uri.encodeQueryComponent(to.toUtc().toIso8601String())}&',
  ].join();
}
