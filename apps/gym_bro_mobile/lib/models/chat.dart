// Direct and group chat (API: /chat/*).
import '../config.dart';
import 'people.dart';
import 'reaction.dart';

/// Nested maps from a realtime payload may be untyped; normalize them.
Map<String, dynamic>? _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;

enum ConversationKind { direct, group }

enum ParticipantRole {
  owner,
  admin,
  member;

  static ParticipantRole parse(Object? v) => switch (v) {
    'owner' => ParticipantRole.owner,
    'admin' => ParticipantRole.admin,
    _ => ParticipantRole.member,
  };

  bool get isAdmin => this != ParticipantRole.member;
}

/// Which inbox list a conversation is in.
enum ChatBox {
  inbox('inbox'),
  requests('requests'),
  archived('archived');

  const ChatBox(this.apiValue);
  final String apiValue;
}

/// The inbox row's last message.
class LastMessagePreview {
  final String id;
  final String? senderId;
  final String? senderName;
  final String kind;

  /// Text, or the media type ('image', 'video', 'audio', 'file') for an
  /// attachment-only message; null for unsent or system messages.
  final String? preview;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final bool deleted;

  const LastMessagePreview({
    required this.id,
    this.senderId,
    this.senderName,
    required this.kind,
    this.preview,
    this.metadata = const {},
    required this.createdAt,
    this.deleted = false,
  });

  factory LastMessagePreview.fromJson(Map<String, dynamic> json) => LastMessagePreview(
    id: json['id'] as String,
    senderId: json['sender_id'] as String?,
    senderName: json['sender_name'] as String?,
    kind: json['kind'] as String? ?? 'text',
    preview: json['preview'] as String?,
    metadata: _map(json['metadata']) ?? const {},
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    deleted: json['deleted'] as bool? ?? false,
  );
}

/// A participant on the conversation detail (read receipts, roles).
class ConversationMember {
  final PersonSummary person;
  final ParticipantRole role;

  /// 'active' or 'request' (hasn't accepted yet).
  final String status;
  final DateTime? joinedAt;
  final DateTime? lastReadAt;
  final DateTime? lastActiveAt;

  const ConversationMember({
    required this.person,
    required this.role,
    this.status = 'active',
    this.joinedAt,
    this.lastReadAt,
    this.lastActiveAt,
  });

  factory ConversationMember.fromJson(Map<String, dynamic> json) => ConversationMember(
    person: PersonSummary.fromJson(json),
    role: ParticipantRole.parse(json['role']),
    status: json['status'] as String? ?? 'active',
    joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '')?.toLocal(),
    lastReadAt: DateTime.tryParse(json['last_read_at'] as String? ?? '')?.toLocal(),
    lastActiveAt: DateTime.tryParse(json['last_active_at'] as String? ?? '')?.toLocal(),
  );

  ConversationMember withLastRead(DateTime at) => ConversationMember(
    person: person,
    role: role,
    status: status,
    joinedAt: joinedAt,
    lastReadAt: at,
    lastActiveAt: lastActiveAt,
  );
}

class Conversation {
  final String id;
  final ConversationKind kind;
  final String? title;
  final String? description;
  final String? avatarUrl;
  final String? createdBy;
  final DateTime lastMessageAt;
  final ParticipantRole myRole;

  /// 'active' or 'request' (a message request I haven't accepted).
  final String myStatus;
  final bool muted;
  final bool archived;
  final DateTime? lastReadAt;
  final int unreadCount;
  final int participantCount;

  /// Up to five other participants (for titles and avatars).
  final List<PersonSummary> participants;

  /// Direct chats: the other person.
  final PersonSummary? otherUser;
  final DateTime? otherLastActiveAt;
  final LastMessagePreview? lastMessage;

  /// Only on GET /chat/conversations/:id.
  final List<ConversationMember> members;

  const Conversation({
    required this.id,
    required this.kind,
    this.title,
    this.description,
    this.avatarUrl,
    this.createdBy,
    required this.lastMessageAt,
    this.myRole = ParticipantRole.member,
    this.myStatus = 'active',
    this.muted = false,
    this.archived = false,
    this.lastReadAt,
    this.unreadCount = 0,
    this.participantCount = 0,
    this.participants = const [],
    this.otherUser,
    this.otherLastActiveAt,
    this.lastMessage,
    this.members = const [],
  });

  bool get isGroup => kind == ConversationKind.group;
  bool get isRequest => myStatus == 'request';

  /// Group title, else the other person's name, else the first few names.
  String displayTitle(String fallback) {
    if (title != null && title!.isNotEmpty) return title!;
    if (otherUser != null) return otherUser!.fullName;
    final names = participants.map((p) => p.name).where((n) => n.isNotEmpty).toList();
    return names.isEmpty ? fallback : names.join(', ');
  }

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    kind: json['kind'] == 'group' ? ConversationKind.group : ConversationKind.direct,
    title: json['title'] as String?,
    description: json['description'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    createdBy: json['created_by'] as String?,
    lastMessageAt: DateTime.parse(json['last_message_at'] as String).toLocal(),
    myRole: ParticipantRole.parse(json['my_role']),
    myStatus: json['my_status'] as String? ?? 'active',
    muted: json['muted'] as bool? ?? false,
    archived: json['archived'] as bool? ?? false,
    lastReadAt: DateTime.tryParse(json['last_read_at'] as String? ?? '')?.toLocal(),
    unreadCount: int.parse((json['unread_count'] ?? 0).toString()),
    participantCount: int.parse((json['participant_count'] ?? 0).toString()),
    participants: (json['participants'] as List<dynamic>? ?? [])
        .map((e) => PersonSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
    otherUser: PersonSummary.maybeFromJson(_map(json['other_user'])),
    otherLastActiveAt: DateTime.tryParse(json['other_last_active_at'] as String? ?? '')?.toLocal(),
    lastMessage: _map(json['last_message']) == null ? null : LastMessagePreview.fromJson(_map(json['last_message'])!),
    members: (json['members'] as List<dynamic>? ?? [])
        .map((e) => ConversationMember.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

enum AttachmentType {
  image,
  video,
  audio,
  file;

  static AttachmentType parse(Object? v) => switch (v) {
    'image' => AttachmentType.image,
    'video' => AttachmentType.video,
    'audio' => AttachmentType.audio,
    _ => AttachmentType.file,
  };

  static AttachmentType fromMime(String mime) => mime.startsWith('image/')
      ? AttachmentType.image
      : mime.startsWith('video/')
          ? AttachmentType.video
          : mime.startsWith('audio/')
              ? AttachmentType.audio
              : AttachmentType.file;
}

class ChatAttachment {
  final String id;

  /// Signed, short-lived and already absolute (see [AppConfig.resolveUrl]).
  final String? url;
  final String mimeType;
  final AttachmentType type;
  final int sizeBytes;
  final String? fileName;
  final int? width;
  final int? height;
  final int? durationMs;

  const ChatAttachment({
    required this.id,
    this.url,
    required this.mimeType,
    required this.type,
    this.sizeBytes = 0,
    this.fileName,
    this.width,
    this.height,
    this.durationMs,
  });

  double? get aspectRatio => (width != null && height != null && width! > 0 && height! > 0) ? width! / height! : null;

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String?;
    return ChatAttachment(
      id: json['id'] as String,
      url: url == null ? null : AppConfig.resolveUrl(url),
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      type: AttachmentType.parse(json['media_type']),
      sizeBytes: int.parse((json['size_bytes'] ?? 0).toString()),
      fileName: json['file_name'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      durationMs: json['duration_ms'] as int?,
    );
  }
}

class MessageReaction {
  final String userId;
  final ReactionType reaction;

  const MessageReaction({required this.userId, required this.reaction});
}

class ReplyPreview {
  final String id;
  final String? senderId;
  final String? senderName;
  final String? body;
  final AttachmentType? mediaType;
  final bool deleted;

  const ReplyPreview({required this.id, this.senderId, this.senderName, this.body, this.mediaType, this.deleted = false});

  factory ReplyPreview.fromJson(Map<String, dynamic> json) => ReplyPreview(
    id: json['id'] as String,
    senderId: json['sender_id'] as String?,
    senderName: json['sender_name'] as String?,
    body: json['body'] as String?,
    mediaType: json['media_type'] == null ? null : AttachmentType.parse(json['media_type']),
    deleted: json['deleted'] as bool? ?? false,
  );
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String? senderId;
  final PersonSummary? sender;

  /// 'text', 'media' or 'system'.
  final String kind;
  final String? body;
  final ReplyPreview? replyTo;
  final String? clientId;

  /// System messages: {event: created|added|removed|left|renamed|photo_changed|role_changed, ...}.
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final List<ChatAttachment> attachments;
  final List<MessageReaction> reactions;

  /// Local-only: an optimistic message still being sent / that failed.
  final bool pending;
  final bool failed;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    this.senderId,
    this.sender,
    this.kind = 'text',
    this.body,
    this.replyTo,
    this.clientId,
    this.metadata = const {},
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.attachments = const [],
    this.reactions = const [],
    this.pending = false,
    this.failed = false,
  });

  bool get isSystem => kind == 'system';
  bool get isDeleted => deletedAt != null;

  ReactionType? reactionOf(String userId) {
    for (final r in reactions) {
      if (r.userId == userId) return r.reaction;
    }
    return null;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    conversationId: json['conversation_id'] as String,
    senderId: json['sender_id'] as String?,
    sender: PersonSummary.maybeFromJson(_map(json['sender'])),
    kind: json['kind'] as String? ?? 'text',
    body: json['body'] as String?,
    replyTo: _map(json['reply_to']) == null ? null : ReplyPreview.fromJson(_map(json['reply_to'])!),
    clientId: json['client_id'] as String?,
    metadata: _map(json['metadata']) ?? const {},
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    editedAt: DateTime.tryParse(json['edited_at'] as String? ?? '')?.toLocal(),
    deletedAt: DateTime.tryParse(json['deleted_at'] as String? ?? '')?.toLocal(),
    attachments: (json['attachments'] as List<dynamic>? ?? [])
        .map((e) => ChatAttachment.fromJson(_map(e)!))
        .toList(),
    reactions: (json['reactions'] as List<dynamic>? ?? [])
        .map((e) {
          final m = _map(e)!;
          final type = ReactionType.tryParse(m['reaction']);
          return type == null ? null : MessageReaction(userId: m['user_id'] as String, reaction: type);
        })
        .whereType<MessageReaction>()
        .toList(),
  );

  ChatMessage copyWith({bool? pending, bool? failed, List<MessageReaction>? reactions}) => ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    sender: sender,
    kind: kind,
    body: body,
    replyTo: replyTo,
    clientId: clientId,
    metadata: metadata,
    createdAt: createdAt,
    editedAt: editedAt,
    deletedAt: deletedAt,
    attachments: attachments,
    reactions: reactions ?? this.reactions,
    pending: pending ?? this.pending,
    failed: failed ?? this.failed,
  );
}

/// Where to PUT a file before attaching it (POST …/uploads).
class UploadSlot {
  final String path;

  /// Absolute signed upload URL.
  final String uploadUrl;
  final String mimeType;

  const UploadSlot({required this.path, required this.uploadUrl, required this.mimeType});

  factory UploadSlot.fromJson(Map<String, dynamic> json) => UploadSlot(
    path: json['path'] as String,
    uploadUrl: AppConfig.resolveUrl(json['upload_url'] as String),
    mimeType: json['mime_type'] as String,
  );
}

/// A file attached to a message being sent.
class OutgoingAttachment {
  final String path;
  final String? fileName;
  final int sizeBytes;
  final int? width;
  final int? height;
  final int? durationMs;

  const OutgoingAttachment({required this.path, this.fileName, required this.sizeBytes, this.width, this.height, this.durationMs});

  Map<String, dynamic> toJson() => {
    'path': path,
    'file_name': ?fileName,
    'size_bytes': sizeBytes,
    'width': ?width,
    'height': ?height,
    'duration_ms': ?durationMs,
  };
}

/// GET /chat/conversations/:id/media row.
class SharedMedia {
  final String id;
  final String messageId;
  final String? senderId;
  final String? url;
  final String mimeType;
  final AttachmentType type;
  final int sizeBytes;
  final String? fileName;
  final int? width;
  final int? height;
  final int? durationMs;
  final DateTime createdAt;

  const SharedMedia({
    required this.id,
    required this.messageId,
    this.senderId,
    this.url,
    required this.mimeType,
    required this.type,
    this.sizeBytes = 0,
    this.fileName,
    this.width,
    this.height,
    this.durationMs,
    required this.createdAt,
  });

  ChatAttachment get asAttachment => ChatAttachment(
    id: id,
    url: url,
    mimeType: mimeType,
    type: type,
    sizeBytes: sizeBytes,
    fileName: fileName,
    width: width,
    height: height,
    durationMs: durationMs,
  );

  factory SharedMedia.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String?;
    return SharedMedia(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      senderId: json['sender_id'] as String?,
      url: url == null ? null : AppConfig.resolveUrl(url),
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      type: AttachmentType.parse(json['media_type']),
      sizeBytes: int.parse((json['size_bytes'] ?? 0).toString()),
      fileName: json['file_name'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      durationMs: json['duration_ms'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
