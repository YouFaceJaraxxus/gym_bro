import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/config.dart';
import 'package:gym_bro_mobile/models/chat.dart';
import 'package:gym_bro_mobile/models/reaction.dart';
import 'package:gym_bro_mobile/services/api_service.dart';
import 'package:http/http.dart' as http;

import '../helpers/fake_backend.dart';

const _token = 'tok-123';

void _expectHeaders(http.Request req) {
  expect(req.headers['Authorization'], 'Bearer $_token');
  expect(req.headers['Content-Type'], startsWith('application/json'));
}

void _expectRequest(http.Request req, String method, String path, {Map<String, String>? query}) {
  expect(req.method, method);
  expect(pathOf(req), path);
  if (query == null) {
    expect(req.url.hasQuery, isFalse, reason: 'unexpected query ${req.url.query}');
  } else {
    expect(req.url.queryParameters, query);
  }
  _expectHeaders(req);
}

Matcher _throwsMessage(String message) => throwsA(predicate((e) => e is Exception && '$e'.contains(message)));

/// The instant [iso] (a UTC timestamp) — the models convert to local time.
DateTime _utc(String iso) => DateTime.parse(iso);

// ── Fixtures (shapes captured from the local stack, ids shortened, signed-URL
// tokens replaced) ──────────────────────────────────────────────────────────

Map<String, dynamic> _person(String id, String username, String name, String lastName) => {
      'id': id,
      'username': username,
      'name': name,
      'last_name': lastName,
      'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=$username&size=256',
    };

final _kenji = _person('u-kenji', 'kenjitanaka', 'Kenji', 'Tanaka');
final _liam = _person('u-liam', 'liamoconnor', 'Liam', "O'Connor");

/// GET /chat/conversations row for a direct chat.
Map<String, dynamic> _directJson() => {
      'id': 'c-direct',
      'kind': 'direct',
      'title': null,
      'description': null,
      'avatar_url': null,
      'created_by': 'u-liam',
      'created_at': '2026-10-25T18:20:54.327Z',
      'last_message_at': '2026-10-28T18:40:24.182Z',
      'my_role': 'member',
      'my_status': 'active',
      'muted': false,
      'muted_until': null,
      'archived': false,
      'last_read_at': '2026-10-28T18:40:24.182Z',
      'unread_count': 0,
      'participant_count': 2,
      'participants': [_kenji],
      'other_user': _kenji,
      'other_last_active_at': '2026-10-28T18:40:23.337Z',
      'last_message': {
        'id': 'm-last',
        'sender_id': 'u-kenji',
        'sender_name': 'Kenji',
        'kind': 'text',
        'preview': 'Legend',
        'metadata': {},
        'created_at': '2026-10-27T13:09:30.349+00:00',
        'deleted': false,
      },
    };

/// GET /chat/conversations/:id for a group (with members).
Map<String, dynamic> _groupJson({String myRole = 'owner', bool muted = false, bool archived = false}) => {
      'id': 'c-group',
      'kind': 'group',
      'title': 'Ironclad 6am Crew 🌅',
      'description': 'Early birds only',
      'avatar_url': '/storage/v1/object/sign/chat-media/c-group/avatar.jpg?token=redacted',
      'created_by': 'u-liam',
      'created_at': '2026-10-22T18:20:54.327Z',
      'last_message_at': '2026-10-27T19:05:08.574Z',
      'my_role': myRole,
      'my_status': 'active',
      'muted': muted,
      'muted_until': muted ? '9999-12-31T00:00:00+00:00' : null,
      'archived': archived,
      'last_read_at': '2026-10-27T19:05:09.039Z',
      'unread_count': '3', // count(*) can arrive as a string
      'participant_count': 6,
      'participants': [_kenji, _person('u-grace', 'graceokafor', 'Grace', 'Okafor')],
      'other_user': null,
      'other_last_active_at': null,
      'last_message': null,
      'members': [
        {
          ..._liam,
          'role': 'owner',
          'status': 'active',
          'joined_at': '2026-10-22T18:20:54.327Z',
          'last_read_at': '2026-10-27T19:05:09.039Z',
          'last_active_at': '2026-10-28T18:47:22.076Z',
        },
        {
          ..._kenji,
          'role': 'admin',
          'status': 'active',
          'joined_at': '2026-10-22T18:20:54.327Z',
          'last_read_at': '2026-10-27T19:05:08.574Z',
          'last_active_at': null,
        },
        {
          ..._person('u-ingrid', 'ingridlarsen', 'Ingrid', 'Larsen'),
          'role': 'member',
          'status': 'request',
          'joined_at': '2026-10-23T08:00:00.000Z',
          'last_read_at': null,
          'last_active_at': null,
        },
      ],
    };

/// A media message that replies to another and carries a reaction.
Map<String, dynamic> _messageJson({
  String id = 'm1',
  String? body = 'View from the treadmill this morning',
  String? clientId,
  String? editedAt,
  String? deletedAt,
  List<Map<String, dynamic>>? reactions,
  List<Map<String, dynamic>>? attachments,
}) =>
    {
      'id': id,
      'conversation_id': 'c-group',
      'sender_id': 'u-grace',
      'kind': 'media',
      'body': body,
      'reply_to_id': 'm0',
      'client_id': clientId,
      'metadata': {},
      'created_at': '2026-10-25T20:22:04.951Z',
      'edited_at': editedAt,
      'deleted_at': deletedAt,
      'sender': _person('u-grace', 'graceokafor', 'Grace', 'Okafor'),
      'attachments': attachments ??
          [
            {
              'id': 'a1',
              'url': '/storage/v1/object/sign/chat-media/c-group/sunrise.jpg?token=redacted',
              'mime_type': 'image/jpeg',
              'media_type': 'image',
              'size_bytes': 56313,
              'file_name': 'sunrise-gym.jpg',
              'width': 1080,
              'height': 1080,
              'duration_ms': null,
            },
          ],
      'reactions': reactions ??
          [
            {'user_id': 'u-liam', 'reaction': 'love'},
            {'user_id': 'u-kenji', 'reaction': 'not-a-reaction'},
          ],
      'reply_to': {
        'id': 'm0',
        'sender_id': 'u-kenji',
        'sender_name': 'Kenji Tanaka',
        'body': null,
        'media_type': 'video',
        'deleted': false,
      },
    };

Map<String, dynamic> _systemMessageJson() => {
      'id': 'm-sys',
      'conversation_id': 'c-group',
      'sender_id': 'u-liam',
      'kind': 'system',
      'body': null,
      'reply_to_id': null,
      'client_id': null,
      'metadata': {'event': 'created', 'title': 'Ironclad 6am Crew 🌅'},
      'created_at': '2026-10-22T18:21:54.327Z',
      'edited_at': null,
      'deleted_at': null,
      'sender': _liam,
      'attachments': [],
      'reactions': [],
      'reply_to': null,
    };

void _expectGroup(Conversation c) {
  expect(c.id, 'c-group');
  expect(c.kind, ConversationKind.group);
  expect(c.isGroup, isTrue);
  expect(c.title, 'Ironclad 6am Crew 🌅');
  expect(c.description, 'Early birds only');
  expect(c.avatarUrl, '/storage/v1/object/sign/chat-media/c-group/avatar.jpg?token=redacted');
  expect(c.createdBy, 'u-liam');
  expect(c.lastMessageAt.toUtc(), _utc('2026-10-27T19:05:08.574Z'));
  expect(c.myStatus, 'active');
  expect(c.isRequest, isFalse);
  expect(c.lastReadAt!.toUtc(), _utc('2026-10-27T19:05:09.039Z'));
  expect(c.unreadCount, 3);
  expect(c.participantCount, 6);
  expect(c.participants.map((p) => p.username), ['kenjitanaka', 'graceokafor']);
  expect(c.otherUser, isNull);
  expect(c.otherLastActiveAt, isNull);
  expect(c.lastMessage, isNull);
  expect(c.members, hasLength(3));
  final owner = c.members[0];
  expect(owner.person.id, 'u-liam');
  expect(owner.person.fullName, "Liam O'Connor");
  expect(owner.role, ParticipantRole.owner);
  expect(owner.status, 'active');
  expect(owner.joinedAt!.toUtc(), _utc('2026-10-22T18:20:54.327Z'));
  expect(owner.lastReadAt!.toUtc(), _utc('2026-10-27T19:05:09.039Z'));
  expect(owner.lastActiveAt!.toUtc(), _utc('2026-10-28T18:47:22.076Z'));
  expect(c.members[1].role, ParticipantRole.admin);
  expect(c.members[1].lastActiveAt, isNull);
  expect(c.members[2].role, ParticipantRole.member);
  expect(c.members[2].status, 'request');
  expect(c.members[2].lastReadAt, isNull);
}

void _expectMediaMessage(ChatMessage m) {
  expect(m.id, 'm1');
  expect(m.conversationId, 'c-group');
  expect(m.senderId, 'u-grace');
  expect(m.sender!.fullName, 'Grace Okafor');
  expect(m.kind, 'media');
  expect(m.isSystem, isFalse);
  expect(m.body, 'View from the treadmill this morning');
  expect(m.metadata, isEmpty);
  expect(m.createdAt.toUtc(), _utc('2026-10-25T20:22:04.951Z'));
  expect(m.editedAt, isNull);
  expect(m.deletedAt, isNull);
  expect(m.isDeleted, isFalse);
  final a = m.attachments.single;
  expect(a.id, 'a1');
  // Relative signed URLs are resolved against the Supabase origin.
  expect(a.url, '${AppConfig.supabaseOrigin}/storage/v1/object/sign/chat-media/c-group/sunrise.jpg?token=redacted');
  expect(a.mimeType, 'image/jpeg');
  expect(a.type, AttachmentType.image);
  expect(a.sizeBytes, 56313);
  expect(a.fileName, 'sunrise-gym.jpg');
  expect(a.width, 1080);
  expect(a.height, 1080);
  expect(a.durationMs, isNull);
  // Unknown reaction types are dropped.
  expect(m.reactions, hasLength(1));
  expect(m.reactionOf('u-liam'), ReactionType.love);
  expect(m.reactionOf('u-kenji'), isNull);
  final reply = m.replyTo!;
  expect(reply.id, 'm0');
  expect(reply.senderId, 'u-kenji');
  expect(reply.senderName, 'Kenji Tanaka');
  expect(reply.body, isNull);
  expect(reply.mediaType, AttachmentType.video);
  expect(reply.deleted, isFalse);
}

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('getRealtimeAnonKey', () {
    test('GETs /chat/realtime and returns anon_key', () async {
      backend.on('GET /chat/realtime', ok({'anon_key': 'public-anon', 'user_topic': 'user:u-liam'}));
      expect(await api.getRealtimeAnonKey(_token), 'public-anon');
      _expectRequest(backend.only, 'GET', '/chat/realtime');
    });

    test('401 surfaces the message', () async {
      backend.on('GET /chat/realtime', err(401, 'Invalid or expired token'));
      await expectLater(api.getRealtimeAnonKey(_token), _throwsMessage('Invalid or expired token'));
    });
  });

  group('getConversations', () {
    test('defaults to the inbox, page 0, 30 per page; parses a direct chat row', () async {
      backend.on('GET /chat/conversations', ok([_directJson()]));

      final list = await api.getConversations(_token);

      _expectRequest(backend.only, 'GET', '/chat/conversations', query: {'box': 'inbox', 'page': '0', 'page_size': '30'});
      final c = list.single;
      expect(c.id, 'c-direct');
      expect(c.kind, ConversationKind.direct);
      expect(c.title, isNull);
      expect(c.description, isNull);
      expect(c.avatarUrl, isNull);
      expect(c.createdBy, 'u-liam');
      expect(c.lastMessageAt.toUtc(), _utc('2026-10-28T18:40:24.182Z'));
      expect(c.myRole, ParticipantRole.member);
      expect(c.myStatus, 'active');
      expect(c.muted, isFalse);
      expect(c.archived, isFalse);
      expect(c.lastReadAt!.toUtc(), _utc('2026-10-28T18:40:24.182Z'));
      expect(c.unreadCount, 0);
      expect(c.participantCount, 2);
      expect(c.participants.single.id, 'u-kenji');
      expect(c.otherUser!.id, 'u-kenji');
      expect(c.otherUser!.username, 'kenjitanaka');
      expect(c.otherUser!.avatarUrl, 'https://api.dicebear.com/9.x/avataaars/png?seed=kenjitanaka&size=256');
      expect(c.otherLastActiveAt!.toUtc(), _utc('2026-10-28T18:40:23.337Z'));
      expect(c.displayTitle('Chat'), 'Kenji Tanaka');
      expect(c.members, isEmpty);
      final last = c.lastMessage!;
      expect(last.id, 'm-last');
      expect(last.senderId, 'u-kenji');
      expect(last.senderName, 'Kenji');
      expect(last.kind, 'text');
      expect(last.preview, 'Legend');
      expect(last.metadata, isEmpty);
      // Postgres timestamptz with a +00:00 offset.
      expect(last.createdAt.toUtc(), _utc('2026-10-27T13:09:30.349Z'));
      expect(last.deleted, isFalse);
    });

    test('passes the box and paging', () async {
      backend.on('GET /chat/conversations', ok([]));
      await api.getConversations(_token, box: ChatBox.requests, page: 2, pageSize: 10);
      await api.getConversations(_token, box: ChatBox.archived);
      expect(backend.requests[0].url.queryParameters, {'box': 'requests', 'page': '2', 'page_size': '10'});
      expect(backend.requests[1].url.queryParameters['box'], 'archived');
    });

    test('400 surfaces the message; non-JSON errors still throw', () async {
      backend.on('GET /chat/conversations', err(400, 'box must be inbox, requests or archived'));
      await expectLater(api.getConversations(_token), _throwsMessage('box must be inbox, requests or archived'));
      backend.on('GET /chat/conversations', ok('upstream timeout', 504));
      await expectLater(api.getConversations(_token), _throwsMessage('Request failed (504)'));
    });
  });

  group('openDirectChat', () {
    test('POSTs {user_ids: [id]} without group/title', () async {
      backend.on('POST /chat/conversations', ok(_directJson()));

      final c = await api.openDirectChat(_token, 'u-kenji');

      final req = backend.only;
      _expectRequest(req, 'POST', '/chat/conversations');
      expect(bodyOf(req), equals({'user_ids': ['u-kenji']}));
      expect(c.id, 'c-direct');
      expect(c.otherUser!.id, 'u-kenji');
    });

    test('blocked user (400) surfaces the message', () async {
      backend.on('POST /chat/conversations', err(400, "You can't add someone who blocked you or whom you blocked"));
      await expectLater(api.openDirectChat(_token, 'u-x'), _throwsMessage("You can't add someone who blocked you"));
    });
  });

  group('createGroupChat', () {
    test('POSTs user_ids, title and group: true; parses the detail', () async {
      backend.on('POST /chat/conversations', ok(_groupJson(), 201));

      final c = await api.createGroupChat(_token, userIds: ['u-kenji', 'u-grace'], title: 'Ironclad 6am Crew 🌅');

      final req = backend.only;
      _expectRequest(req, 'POST', '/chat/conversations');
      expect(
        bodyOf(req),
        equals({
          'user_ids': ['u-kenji', 'u-grace'],
          'title': 'Ironclad 6am Crew 🌅',
          'group': true,
        }),
      );
      _expectGroup(c);
      expect(c.myRole, ParticipantRole.owner);
    });

    test('omits a null title', () async {
      backend.on('POST /chat/conversations', ok(_groupJson(), 201));
      await api.createGroupChat(_token, userIds: ['u-kenji']);
      expect(bodyOf(backend.only), equals({'user_ids': ['u-kenji'], 'group': true}));
    });

    test('400 surfaces the message', () async {
      backend.on('POST /chat/conversations', err(400, 'Groups are limited to 50 people'));
      await expectLater(api.createGroupChat(_token, userIds: ['a']), _throwsMessage('Groups are limited to 50 people'));
    });
  });

  group('getConversation', () {
    test('GETs /chat/conversations/:id with every member', () async {
      backend.on('GET /chat/conversations/c-group', ok(_groupJson()));
      final c = await api.getConversation(_token, 'c-group');
      _expectRequest(backend.only, 'GET', '/chat/conversations/c-group');
      _expectGroup(c);
    });

    test('404 surfaces the message', () async {
      backend.on('GET /chat/conversations/nope', err(404, 'Conversation not found'));
      await expectLater(api.getConversation(_token, 'nope'), _throwsMessage('Conversation not found'));
    });
  });

  group('updateGroup', () {
    test('PUTs the changes as-is (null clears the avatar)', () async {
      backend.on('PUT /chat/conversations/c-group', ok(_groupJson()));

      final c = await api.updateGroup(_token, 'c-group', {'title': 'Dawn Patrol', 'description': 'x', 'avatar_url': null});

      final req = backend.only;
      _expectRequest(req, 'PUT', '/chat/conversations/c-group');
      expect(bodyOf(req), equals({'title': 'Dawn Patrol', 'description': 'x', 'avatar_url': null}));
      expect(c.id, 'c-group');
    });

    test('403 surfaces the message', () async {
      backend.on('PUT /chat/conversations/c-group', err(403, 'Only group admins can change the group'));
      await expectLater(api.updateGroup(_token, 'c-group', {'title': 't'}), _throwsMessage('Only group admins'));
    });
  });

  group('deleteGroup', () {
    test('DELETEs the conversation and accepts an empty 204', () async {
      backend.on('DELETE /chat/conversations/c-group', ok('', 204));
      await api.deleteGroup(_token, 'c-group');
      final req = backend.only;
      _expectRequest(req, 'DELETE', '/chat/conversations/c-group');
      expect(req.body, isEmpty);
    });

    test('403 surfaces the message', () async {
      backend.on('DELETE /chat/conversations/c-group', err(403, 'Only the group owner can delete the group'));
      await expectLater(api.deleteGroup(_token, 'c-group'), _throwsMessage('Only the group owner'));
    });
  });

  group('updateChatSettings', () {
    test('PUTs only the flags that are set', () async {
      backend.on('PUT /chat/conversations/c-group/settings', ok(_groupJson(muted: true, archived: true)));

      final c = await api.updateChatSettings(_token, 'c-group', muted: true, archived: true);
      await api.updateChatSettings(_token, 'c-group', archived: false);
      await api.updateChatSettings(_token, 'c-group', muted: false);

      _expectRequest(backend.requests[0], 'PUT', '/chat/conversations/c-group/settings');
      expect(bodyOf(backend.requests[0]), equals({'muted': true, 'archived': true}));
      expect(bodyOf(backend.requests[1]), equals({'archived': false}));
      expect(bodyOf(backend.requests[2]), equals({'muted': false}));
      expect(c.muted, isTrue);
      expect(c.archived, isTrue);
    });

    test('400 surfaces the message', () async {
      backend.on('PUT /chat/conversations/c-group/settings', err(400, 'Nothing to update'));
      await expectLater(api.updateChatSettings(_token, 'c-group'), _throwsMessage('Nothing to update'));
      expect(bodyOf(backend.only), equals({}));
    });
  });

  group('acceptMessageRequest', () {
    test('POSTs /accept without a body and parses the conversation', () async {
      backend.on('POST /chat/conversations/c-direct/accept', ok(_directJson()));
      final c = await api.acceptMessageRequest(_token, 'c-direct');
      final req = backend.only;
      _expectRequest(req, 'POST', '/chat/conversations/c-direct/accept');
      expect(req.body, isEmpty);
      expect(c.myStatus, 'active');
    });

    test('404 surfaces the message', () async {
      backend.on('POST /chat/conversations/c-x/accept', err(404, 'Conversation not found'));
      await expectLater(api.acceptMessageRequest(_token, 'c-x'), _throwsMessage('Conversation not found'));
    });
  });

  group('clearChat', () {
    test('POSTs /clear and accepts an empty 204', () async {
      backend.on('POST /chat/conversations/c-direct/clear', ok('', 204));
      await api.clearChat(_token, 'c-direct');
      final req = backend.only;
      _expectRequest(req, 'POST', '/chat/conversations/c-direct/clear');
      expect(req.body, isEmpty);
    });

    test('404 surfaces the message', () async {
      backend.on('POST /chat/conversations/c-x/clear', err(404, 'Conversation not found'));
      await expectLater(api.clearChat(_token, 'c-x'), _throwsMessage('Conversation not found'));
    });
  });

  group('markChatRead', () {
    test('POSTs /read', () async {
      backend.on('POST /chat/conversations/c-direct/read', ok({'last_read_at': '2026-10-28T18:50:00.000Z'}));
      await api.markChatRead(_token, 'c-direct');
      final req = backend.only;
      _expectRequest(req, 'POST', '/chat/conversations/c-direct/read');
      expect(req.body, isEmpty);
    });

    test('non-JSON error still throws', () async {
      backend.on('POST /chat/conversations/c-direct/read', ok('<html>502</html>', 502));
      await expectLater(api.markChatRead(_token, 'c-direct'), _throwsMessage('Request failed (502)'));
    });
  });

  group('addGroupMembers', () {
    test('POSTs {user_ids} to /participants', () async {
      backend.on('POST /chat/conversations/c-group/participants', ok(_groupJson()));
      final c = await api.addGroupMembers(_token, 'c-group', ['u-ingrid', 'u-dan']);
      final req = backend.only;
      _expectRequest(req, 'POST', '/chat/conversations/c-group/participants');
      expect(bodyOf(req), equals({'user_ids': ['u-ingrid', 'u-dan']}));
      expect(c.members, hasLength(3));
    });

    test('400 surfaces the message', () async {
      backend.on('POST /chat/conversations/c-direct/participants',
          err(400, "You can't add people to a direct chat — start a group"));
      await expectLater(api.addGroupMembers(_token, 'c-direct', ['u']), _throwsMessage("You can't add people"));
    });
  });

  group('setGroupRole', () {
    test('PUTs {role} for each role', () async {
      backend.on('PUT /chat/conversations/c-group/participants/u-kenji', ok(_groupJson(myRole: 'admin')));

      final c = await api.setGroupRole(_token, 'c-group', 'u-kenji', ParticipantRole.owner);
      await api.setGroupRole(_token, 'c-group', 'u-kenji', ParticipantRole.admin);
      await api.setGroupRole(_token, 'c-group', 'u-kenji', ParticipantRole.member);

      _expectRequest(backend.requests[0], 'PUT', '/chat/conversations/c-group/participants/u-kenji');
      expect(backend.requests.map(bodyOf), [
        {'role': 'owner'},
        {'role': 'admin'},
        {'role': 'member'},
      ]);
      expect(c.myRole, ParticipantRole.admin);
    });

    test('403 surfaces the message', () async {
      backend.on('PUT /chat/conversations/c-group/participants/u-kenji', err(403, 'Only the group owner can change roles'));
      await expectLater(api.setGroupRole(_token, 'c-group', 'u-kenji', ParticipantRole.admin),
          _throwsMessage('Only the group owner can change roles'));
    });
  });

  group('removeFromChat', () {
    test('DELETEs the participant and accepts an empty 204', () async {
      backend.on('DELETE /chat/conversations/c-group/participants/u-kenji', ok('', 204));
      await api.removeFromChat(_token, 'c-group', 'u-kenji');
      final req = backend.only;
      _expectRequest(req, 'DELETE', '/chat/conversations/c-group/participants/u-kenji');
      expect(req.body, isEmpty);
    });

    test('403 surfaces the message', () async {
      backend.on('DELETE /chat/conversations/c-group/participants/u-kenji', err(403, 'Only the owner can remove admins'));
      await expectLater(api.removeFromChat(_token, 'c-group', 'u-kenji'), _throwsMessage('Only the owner can remove admins'));
    });
  });

  group('getMessages', () {
    test('defaults to limit=40 and parses media, replies, reactions and system messages', () async {
      backend.on('GET /chat/conversations/c-group/messages', ok([_messageJson(), _systemMessageJson()]));

      final list = await api.getMessages(_token, 'c-group');

      _expectRequest(backend.only, 'GET', '/chat/conversations/c-group/messages', query: {'limit': '40'});
      expect(list, hasLength(2));
      _expectMediaMessage(list[0]);
      final sys = list[1];
      expect(sys.isSystem, isTrue);
      expect(sys.body, isNull);
      expect(sys.metadata, {'event': 'created', 'title': 'Ironclad 6am Crew 🌅'});
      expect(sys.attachments, isEmpty);
      expect(sys.reactions, isEmpty);
      expect(sys.replyTo, isNull);
    });

    test('pages back with before_id and catches up with after_id', () async {
      backend.on('GET /chat/conversations/c-group/messages', ok([]));
      await api.getMessages(_token, 'c-group', beforeId: 'm-old', limit: 20);
      await api.getMessages(_token, 'c-group', afterId: 'm-new');
      expect(backend.requests[0].url.queryParameters, {'limit': '20', 'before_id': 'm-old'});
      expect(backend.requests[1].url.queryParameters, {'limit': '40', 'after_id': 'm-new'});
    });

    test('404 (bad cursor) surfaces the message', () async {
      backend.on('GET /chat/conversations/c-group/messages', err(404, 'Cursor message not found'));
      await expectLater(api.getMessages(_token, 'c-group', beforeId: 'x'), _throwsMessage('Cursor message not found'));
    });
  });

  group('sendMessage', () {
    test('POSTs body, attachments, reply_to_id and client_id', () async {
      backend.on('POST /chat/conversations/c-group/messages', ok(_messageJson(clientId: 'cid-1'), 201));

      final m = await api.sendMessage(
        _token,
        'c-group',
        body: 'View from the treadmill this morning',
        attachments: const [
          OutgoingAttachment(
              path: 'c-group/u-grace/sunrise.jpg', fileName: 'sunrise-gym.jpg', sizeBytes: 56313, width: 1080, height: 1080),
          OutgoingAttachment(path: 'c-group/u-grace/voice.m4a', sizeBytes: 2048, durationMs: 4200),
        ],
        replyToId: 'm0',
        clientId: 'cid-1',
      );

      final req = backend.only;
      _expectRequest(req, 'POST', '/chat/conversations/c-group/messages');
      expect(
        bodyOf(req),
        equals({
          'body': 'View from the treadmill this morning',
          'attachments': [
            {
              'path': 'c-group/u-grace/sunrise.jpg',
              'file_name': 'sunrise-gym.jpg',
              'size_bytes': 56313,
              'width': 1080,
              'height': 1080,
            },
            {'path': 'c-group/u-grace/voice.m4a', 'size_bytes': 2048, 'duration_ms': 4200},
          ],
          'reply_to_id': 'm0',
          'client_id': 'cid-1',
        }),
      );
      _expectMediaMessage(m);
      expect(m.clientId, 'cid-1');
    });

    test('text only: omits body/reply_to_id when null, always sends attachments + client_id', () async {
      backend.on('POST /chat/conversations/c-group/messages', ok(_messageJson(), 201));
      await api.sendMessage(_token, 'c-group', body: 'hi', clientId: 'cid-2');
      await api.sendMessage(_token, 'c-group', clientId: 'cid-3');
      expect(bodyOf(backend.requests[0]), equals({'body': 'hi', 'attachments': [], 'client_id': 'cid-2'}));
      expect(bodyOf(backend.requests[1]), equals({'attachments': [], 'client_id': 'cid-3'}));
    });

    test('400 surfaces the message', () async {
      backend.on('POST /chat/conversations/c-group/messages', err(400, 'A message needs text or an attachment'));
      await expectLater(api.sendMessage(_token, 'c-group', clientId: 'c'), _throwsMessage('A message needs text or an attachment'));
    });
  });

  group('editMessage', () {
    test('PUTs {body} to /chat/messages/:id and parses edited_at', () async {
      backend.on('PUT /chat/messages/m1', ok(_messageJson(body: 'Edited', editedAt: '2026-10-25T20:30:00.000Z')));
      final m = await api.editMessage(_token, 'm1', 'Edited');
      final req = backend.only;
      _expectRequest(req, 'PUT', '/chat/messages/m1');
      expect(bodyOf(req), equals({'body': 'Edited'}));
      expect(m.body, 'Edited');
      expect(m.editedAt!.toUtc(), _utc('2026-10-25T20:30:00.000Z'));
    });

    test('403 surfaces the message', () async {
      backend.on('PUT /chat/messages/m1', err(403, 'You can only edit your own messages'));
      await expectLater(api.editMessage(_token, 'm1', 'x'), _throwsMessage('You can only edit your own messages'));
    });
  });

  group('unsendMessage', () {
    test('DELETEs /chat/messages/:id and parses the tombstone', () async {
      backend.on(
        'DELETE /chat/messages/m1',
        ok(_messageJson(body: null, deletedAt: '2026-10-25T21:00:00.000Z', attachments: [], reactions: [])),
      );
      final m = await api.unsendMessage(_token, 'm1');
      final req = backend.only;
      _expectRequest(req, 'DELETE', '/chat/messages/m1');
      expect(req.body, isEmpty);
      expect(m.isDeleted, isTrue);
      expect(m.deletedAt!.toUtc(), _utc('2026-10-25T21:00:00.000Z'));
      expect(m.body, isNull);
      expect(m.attachments, isEmpty);
    });

    test('404 surfaces the message', () async {
      backend.on('DELETE /chat/messages/m1', err(404, 'Message not found'));
      await expectLater(api.unsendMessage(_token, 'm1'), _throwsMessage('Message not found'));
    });
  });

  group('reactToMessage', () {
    test('PUTs {reaction} to set or switch', () async {
      backend.on('PUT /chat/messages/m1/reaction', ok(_messageJson(reactions: [{'user_id': 'u-liam', 'reaction': 'fire'}])));
      final m = await api.reactToMessage(_token, 'm1', ReactionType.fire);
      final req = backend.only;
      _expectRequest(req, 'PUT', '/chat/messages/m1/reaction');
      expect(bodyOf(req), equals({'reaction': 'fire'}));
      expect(m.reactionOf('u-liam'), ReactionType.fire);
    });

    test('null DELETEs the reaction (no body)', () async {
      backend.on('DELETE /chat/messages/m1/reaction', ok(_messageJson(reactions: [])));
      final m = await api.reactToMessage(_token, 'm1', null);
      final req = backend.only;
      _expectRequest(req, 'DELETE', '/chat/messages/m1/reaction');
      expect(req.body, isEmpty);
      expect(m.reactions, isEmpty);
    });

    test('400 surfaces the message', () async {
      backend.on('PUT /chat/messages/m1/reaction', err(400, "System messages can't be changed"));
      await expectLater(api.reactToMessage(_token, 'm1', ReactionType.like), _throwsMessage("System messages can't be changed"));
    });
  });

  group('getSharedMedia', () {
    test('GETs /media?page=0 without a type and parses rows', () async {
      backend.on(
        'GET /chat/conversations/c-group/media',
        ok([
          {
            'id': 'a1',
            'mime_type': 'image/jpeg',
            'size_bytes': 56313,
            'file_name': 'sunrise-gym.jpg',
            'width': 1080,
            'height': 1080,
            'duration_ms': null,
            'message_id': 'm1',
            'sender_id': 'u-grace',
            'created_at': '2026-10-25T20:22:04.951Z',
            'media_type': 'image',
            'url': '/storage/v1/object/sign/chat-media/c-group/sunrise.jpg?token=redacted',
          },
          {
            'id': 'a2',
            'mime_type': 'audio/mp4',
            'size_bytes': '2048',
            'file_name': null,
            'width': null,
            'height': null,
            'duration_ms': 4200,
            'message_id': 'm2',
            'sender_id': null,
            'created_at': '2026-10-26T08:00:00.000Z',
            'media_type': 'audio',
            'url': null,
          },
        ]),
      );

      final list = await api.getSharedMedia(_token, 'c-group');

      _expectRequest(backend.only, 'GET', '/chat/conversations/c-group/media', query: {'page': '0'});
      final a = list[0];
      expect(a.id, 'a1');
      expect(a.messageId, 'm1');
      expect(a.senderId, 'u-grace');
      expect(a.url, '${AppConfig.supabaseOrigin}/storage/v1/object/sign/chat-media/c-group/sunrise.jpg?token=redacted');
      expect(a.mimeType, 'image/jpeg');
      expect(a.type, AttachmentType.image);
      expect(a.sizeBytes, 56313);
      expect(a.fileName, 'sunrise-gym.jpg');
      expect(a.width, 1080);
      expect(a.height, 1080);
      expect(a.durationMs, isNull);
      expect(a.createdAt.toUtc(), _utc('2026-10-25T20:22:04.951Z'));
      final b = list[1];
      expect(b.type, AttachmentType.audio);
      expect(b.sizeBytes, 2048);
      expect(b.durationMs, 4200);
      expect(b.url, isNull);
      expect(b.senderId, isNull);
    });

    test('passes type and page', () async {
      backend.on('GET /chat/conversations/c-group/media', ok([]));
      await api.getSharedMedia(_token, 'c-group', type: 'file', page: 3);
      expect(backend.only.url.queryParameters, {'page': '3', 'type': 'file'});
    });

    test('404 surfaces the message', () async {
      backend.on('GET /chat/conversations/c-x/media', err(404, 'Conversation not found'));
      await expectLater(api.getSharedMedia(_token, 'c-x'), _throwsMessage('Conversation not found'));
    });
  });

  group('requestChatUpload', () {
    test('POSTs mime_type, size_bytes, file_name; resolves the upload URL', () async {
      backend.on(
        'POST /chat/conversations/c-group/uploads',
        ok({
          'path': 'c-group/u-liam/abc.pdf',
          'upload_url': '/storage/v1/object/upload/sign/chat-media/c-group/u-liam/abc.pdf?token=redacted',
          'token': 'redacted',
          'mime_type': 'application/pdf',
          'expires_in': 7200,
        }, 201),
      );

      final slot = await api.requestChatUpload(_token, 'c-group',
          mimeType: 'application/pdf', sizeBytes: 123456, fileName: 'program.pdf');

      final req = backend.only;
      _expectRequest(req, 'POST', '/chat/conversations/c-group/uploads');
      expect(bodyOf(req), equals({'mime_type': 'application/pdf', 'size_bytes': 123456, 'file_name': 'program.pdf'}));
      expect(slot.path, 'c-group/u-liam/abc.pdf');
      expect(slot.uploadUrl,
          '${AppConfig.supabaseOrigin}/storage/v1/object/upload/sign/chat-media/c-group/u-liam/abc.pdf?token=redacted');
      expect(slot.mimeType, 'application/pdf');
    });

    test('omits a null file_name', () async {
      backend.on(
        'POST /chat/conversations/c-group/uploads',
        ok({'path': 'p', 'upload_url': 'https://cdn.example.com/u', 'mime_type': 'image/png'}, 201),
      );
      final slot = await api.requestChatUpload(_token, 'c-group', mimeType: 'image/png', sizeBytes: 10);
      expect(bodyOf(backend.only), equals({'mime_type': 'image/png', 'size_bytes': 10}));
      expect(slot.uploadUrl, 'https://cdn.example.com/u');
    });

    test('413 surfaces the message', () async {
      backend.on('POST /chat/conversations/c-group/uploads', err(413, 'Files are limited to 50 MB'));
      await expectLater(api.requestChatUpload(_token, 'c-group', mimeType: 'video/mp4', sizeBytes: 999999999),
          _throwsMessage('Files are limited to 50 MB'));
    });
  });
}
