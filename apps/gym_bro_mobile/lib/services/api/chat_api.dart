part of '../api_service.dart';

/// Direct and group chat (/chat/*). Live updates come from [RealtimeService].
extension ChatApi on ApiService {
  /// The public anon key the realtime socket needs (apikey param).
  Future<String> getRealtimeAnonKey(String token) async {
    final r = await _client.get(Uri.parse('$_base/chat/realtime'), headers: _headers(token));
    _check(r);
    return (jsonDecode(r.body) as Map<String, dynamic>)['anon_key'] as String;
  }

  Future<List<Conversation>> getConversations(String token, {ChatBox box = ChatBox.inbox, int page = 0, int pageSize = 30}) async {
    final r = await _client.get(
      Uri.parse('$_base/chat/conversations?box=${box.apiValue}&page=$page&page_size=$pageSize'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Conversation _conversation(http.Response r) {
    _check(r);
    return Conversation.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Opens (or creates) the direct chat with [userId].
  Future<Conversation> openDirectChat(String token, String userId) async => _conversation(await _client.post(
    Uri.parse('$_base/chat/conversations'),
    headers: _headers(token),
    body: jsonEncode({'user_ids': [userId]}),
  ));

  Future<Conversation> createGroupChat(String token, {required List<String> userIds, String? title}) async =>
      _conversation(await _client.post(
        Uri.parse('$_base/chat/conversations'),
        headers: _headers(token),
        body: jsonEncode({'user_ids': userIds, 'title': ?title, 'group': true}),
      ));

  /// Detail with every member (roles, read receipts).
  Future<Conversation> getConversation(String token, String id) async =>
      _conversation(await _client.get(Uri.parse('$_base/chat/conversations/$id'), headers: _headers(token)));

  /// Group admins: any of title, description, avatar_url.
  Future<Conversation> updateGroup(String token, String id, Map<String, dynamic> changes) async => _conversation(
    await _client.put(Uri.parse('$_base/chat/conversations/$id'), headers: _headers(token), body: jsonEncode(changes)),
  );

  /// Group owner: deletes the group for everyone.
  Future<void> deleteGroup(String token, String id) async {
    final r = await _client.delete(Uri.parse('$_base/chat/conversations/$id'), headers: _headers(token));
    if (r.statusCode >= 400) _check(r);
  }

  Future<Conversation> updateChatSettings(String token, String id, {bool? muted, bool? archived}) async =>
      _conversation(await _client.put(
        Uri.parse('$_base/chat/conversations/$id/settings'),
        headers: _headers(token),
        body: jsonEncode({'muted': ?muted, 'archived': ?archived}),
      ));

  Future<Conversation> acceptMessageRequest(String token, String id) async =>
      _conversation(await _client.post(Uri.parse('$_base/chat/conversations/$id/accept'), headers: _headers(token)));

  /// Hides the history so far, for me only.
  Future<void> clearChat(String token, String id) async {
    final r = await _client.post(Uri.parse('$_base/chat/conversations/$id/clear'), headers: _headers(token));
    if (r.statusCode >= 400) _check(r);
  }

  Future<void> markChatRead(String token, String id) async {
    final r = await _client.post(Uri.parse('$_base/chat/conversations/$id/read'), headers: _headers(token));
    _check(r);
  }

  Future<Conversation> addGroupMembers(String token, String id, List<String> userIds) async => _conversation(
    await _client.post(
      Uri.parse('$_base/chat/conversations/$id/participants'),
      headers: _headers(token),
      body: jsonEncode({'user_ids': userIds}),
    ),
  );

  /// Group owner: make someone 'admin', 'member', or hand over 'owner'.
  Future<Conversation> setGroupRole(String token, String id, String userId, ParticipantRole role) async =>
      _conversation(await _client.put(
        Uri.parse('$_base/chat/conversations/$id/participants/$userId'),
        headers: _headers(token),
        body: jsonEncode({'role': role.name}),
      ));

  /// Removes [userId] (admins), or — with my own id — leaves the group,
  /// declines a message request, or deletes a direct chat for me.
  Future<void> removeFromChat(String token, String id, String userId) async {
    final r = await _client.delete(Uri.parse('$_base/chat/conversations/$id/participants/$userId'), headers: _headers(token));
    if (r.statusCode >= 400) _check(r);
  }

  /// Newest first. [beforeId] pages back; [afterId] catches up (oldest first).
  Future<List<ChatMessage>> getMessages(String token, String conversationId, {String? beforeId, String? afterId, int limit = 40}) async {
    final params = ['limit=$limit', if (beforeId != null) 'before_id=$beforeId', if (afterId != null) 'after_id=$afterId'];
    final r = await _client.get(
      Uri.parse('$_base/chat/conversations/$conversationId/messages?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [clientId] makes retries safe and matches the realtime echo to the
  /// optimistic bubble.
  Future<ChatMessage> sendMessage(
    String token,
    String conversationId, {
    String? body,
    List<OutgoingAttachment> attachments = const [],
    String? replyToId,
    required String clientId,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/chat/conversations/$conversationId/messages'),
      headers: _headers(token),
      body: jsonEncode({
        'body': ?body,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'reply_to_id': ?replyToId,
        'client_id': clientId,
      }),
    );
    _check(r);
    return ChatMessage.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<ChatMessage> editMessage(String token, String messageId, String body) async {
    final r = await _client.put(Uri.parse('$_base/chat/messages/$messageId'), headers: _headers(token), body: jsonEncode({'body': body}));
    _check(r);
    return ChatMessage.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<ChatMessage> unsendMessage(String token, String messageId) async {
    final r = await _client.delete(Uri.parse('$_base/chat/messages/$messageId'), headers: _headers(token));
    _check(r);
    return ChatMessage.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Sets or switches my reaction; null removes it.
  Future<ChatMessage> reactToMessage(String token, String messageId, ReactionType? reaction) async {
    final uri = Uri.parse('$_base/chat/messages/$messageId/reaction');
    final r = reaction == null
        ? await _client.delete(uri, headers: _headers(token))
        : await _client.put(uri, headers: _headers(token), body: jsonEncode({'reaction': reaction.apiValue}));
    _check(r);
    return ChatMessage.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// [type]: 'media' (photos+videos), 'file' or 'audio'; null for everything.
  Future<List<SharedMedia>> getSharedMedia(String token, String conversationId, {String? type, int page = 0}) async {
    final r = await _client.get(
      Uri.parse('$_base/chat/conversations/$conversationId/media?page=$page${type == null ? '' : '&type=$type'}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => SharedMedia.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Reserves a path for any file type (max 50 MB).
  Future<UploadSlot> requestChatUpload(
    String token,
    String conversationId, {
    required String mimeType,
    required int sizeBytes,
    String? fileName,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/chat/conversations/$conversationId/uploads'),
      headers: _headers(token),
      body: jsonEncode({'mime_type': mimeType, 'size_bytes': sizeBytes, 'file_name': ?fileName}),
    );
    _check(r);
    return UploadSlot.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
