import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/chat.dart';
import 'package:gym_bro_mobile/services/api_service.dart';

import 'helpers/fake_backend.dart';

// Shapes from apps/gym_bro_api/tests/integration/features_instagram_parity_test.ts
// ("notes", "pinned chats and forwarding").

Map<String, dynamic> _conversation({Object? pinned}) => {
  'id': 'c1',
  'kind': 'group',
  'title': 'g0',
  'last_message_at': '2026-10-28T18:40:24.182Z',
  'my_role': 'owner',
  'my_status': 'active',
  'muted': false,
  'archived': false,
  'pinned': ?pinned,
  'unread_count': 0,
  'participant_count': 2,
  'participants': [],
  'last_message': null,
};

Map<String, dynamic> _message(Map<String, dynamic> metadata, {String? body = 'hi'}) => {
  'id': 'm1',
  'conversation_id': 'c1',
  'sender_id': 'u-trainer',
  'kind': 'text',
  'body': body,
  'metadata': metadata,
  'created_at': '2026-10-28T18:40:24.182Z',
  'attachments': [],
  'reactions': [],
};

final _notesJson = {
  'mine': {
    'body': 'leg day 🦵',
    'audience': 'close_friends',
    'created_at': '2026-10-30T10:00:00.000Z',
    'expires_at': '2026-10-31T10:00:00.000Z',
  },
  'notes': [
    {
      'user_id': 'u-ana',
      'body': 'PR today!',
      'created_at': '2026-10-30T09:00:00.000Z',
      'expires_at': '2026-10-31T09:00:00.000Z',
      'user': {'id': 'u-ana', 'username': 'ana', 'name': 'Ana', 'last_name': 'Petrović', 'avatar_url': null},
    },
  ],
};

void main() {
  group('Conversation.pinned', () {
    test('reads pinned and defaults to false when absent', () {
      expect(Conversation.fromJson(_conversation(pinned: true)).pinned, isTrue);
      expect(Conversation.fromJson(_conversation(pinned: false)).pinned, isFalse);
      expect(Conversation.fromJson(_conversation()).pinned, isFalse);
    });

    test('withPinned switches only pinned', () {
      final c = Conversation.fromJson(_conversation()).withPinned(true);
      expect(c.pinned, isTrue);
      expect(c.id, 'c1');
      expect(c.title, 'g0');
      expect(c.myRole, ParticipantRole.owner);
    });
  });

  group('ChatMessage metadata', () {
    test('forwarded', () {
      final m = ChatMessage.fromJson(_message({'forwarded': true}));
      expect(m.isForwarded, isTrue);
      expect(m.noteReply, isNull);
      expect(ChatMessage.fromJson(_message({})).isForwarded, isFalse);
    });

    test('note_reply', () {
      final m = ChatMessage.fromJson(_message({
        'note_reply': {'owner_id': 'u-member', 'body': 'cf only'},
      }));
      expect(m.isForwarded, isFalse);
      expect(m.noteReply?.ownerId, 'u-member');
      expect(m.noteReply?.body, 'cf only');
    });

    test('canForward: text, shares or files; not system / unsent / empty', () {
      expect(ChatMessage.fromJson(_message({})).canForward, isTrue);
      expect(ChatMessage.fromJson(_message({}, body: null)).canForward, isFalse);
      expect(ChatMessage.fromJson({..._message({}), 'kind': 'system'}).canForward, isFalse);
      expect(ChatMessage.fromJson({..._message({}), 'deleted_at': '2026-10-28T19:00:00Z'}).canForward, isFalse);
      final voice = ChatMessage.fromJson({
        ..._message({}, body: null),
        'kind': 'media',
        'attachments': [
          {
            'id': 'a1',
            'url': '/storage/v1/object/sign/chat-media/c1/v.m4a?token=x',
            'mime_type': 'audio/mp4',
            'media_type': 'audio',
            'size_bytes': '1200',
            'file_name': 'voice.m4a',
            'duration_ms': 1500,
          },
        ],
      });
      expect(voice.canForward, isTrue);
      expect(voice.attachments.single.type, AttachmentType.audio);
      expect(voice.attachments.single.durationMs, 1500);
    });
  });

  group('NotesFeed', () {
    test('parses mine and others\' notes', () {
      final feed = NotesFeed.fromJson(_notesJson);
      expect(feed.mine?.body, 'leg day 🦵');
      expect(feed.mine?.audience, NoteAudience.closeFriends);
      expect(feed.mine!.expiresAt!.isAtSameMomentAs(DateTime.parse('2026-10-31T10:00:00.000Z')), isTrue);
      final n = feed.notes.single;
      expect(n.userId, 'u-ana');
      expect(n.body, 'PR today!');
      expect(n.user.fullName, 'Ana Petrović');
      expect(n.createdAt!.isAtSameMomentAs(DateTime.parse('2026-10-30T09:00:00.000Z')), isTrue);
    });

    test('no note of mine; unknown audience falls back to mutuals', () {
      final feed = NotesFeed.fromJson({'mine': null, 'notes': []});
      expect(feed.mine, isNull);
      expect(feed.notes, isEmpty);
      expect(NotesFeed.fromJson({}).notes, isEmpty);
      expect(MyNote.maybeFromJson({'body': 'x', 'audience': 'whatever'})?.audience, NoteAudience.mutuals);
      expect(NoteAudience.closeFriends.apiValue, 'close_friends');
    });
  });

  test('ForwardResult', () {
    final r = ForwardResult.fromJson({
      'sent': 2,
      'results': [
        {'conversation_id': 'c2', 'status': 201, 'message_id': 'm2'},
        {'user_id': 'u-x', 'status': 403, 'error': 'Not allowed'},
      ],
    });
    expect(r.sent, 2);
    expect(r.results.first.sent, isTrue);
    expect(r.results.last.sent, isFalse);
    expect(r.results.last.userId, 'u-x');
  });

  group('ChatApi', () {
    late FakeBackend backend;
    late ApiService api;

    setUp(() {
      backend = FakeBackend()..install();
      api = ApiService();
    });
    tearDown(() => backend.uninstall());

    test('setConversationPinned sends {pinned} and maps pin_limit', () async {
      backend.on('PUT /chat/conversations/c1/settings', ok(_conversation(pinned: true)));
      final c = await api.setConversationPinned('t', 'c1', true);
      expect(c.pinned, isTrue);
      expect(jsonDecode(backend.only.body), {'pinned': true});

      backend.on('PUT /chat/conversations/c1/settings', err(409, 'Up to 3 chats can be pinned', code: 'pin_limit'));
      await expectLater(api.setConversationPinned('t', 'c1', true), throwsA(isA<PinLimitException>()));
    });

    test('notes: get, set with audience, delete, reply', () async {
      backend.on('GET /chat/notes', ok(_notesJson));
      backend.on('PUT /chat/notes', ok(_notesJson));
      backend.on('DELETE /chat/notes', ok({'mine': null, 'notes': []}));
      backend.on('POST /chat/notes/u-ana/replies', ok({
        ..._message({'note_reply': {'owner_id': 'u-ana', 'body': 'PR today!'}}, body: 'nice'),
        'conversation_id': 'c-ana',
      }, 201));

      expect((await api.getNotes('t')).notes, hasLength(1));
      await api.setNote('t', ' leg day ', audience: NoteAudience.closeFriends);
      expect(jsonDecode(backend.requests.last.body), {'body': 'leg day', 'audience': 'close_friends'});
      expect((await api.deleteNote('t')).mine, isNull);
      final sent = await api.replyToNote('t', 'u-ana', 'nice', clientId: 'cid');
      expect(jsonDecode(backend.requests.last.body), {'body': 'nice', 'client_id': 'cid'});
      expect(sent.conversationId, 'c-ana');
      expect(sent.noteReply?.body, 'PR today!');
    });

    test('forwardMessage sends targets and parses results', () async {
      backend.on('POST /chat/messages/m1/forward', ok({
        'sent': 1,
        'results': [{'conversation_id': 'c2', 'status': 201, 'message_id': 'm2'}],
      }, 201));
      final r = await api.forwardMessage('t', 'm1', conversationIds: ['c2']);
      expect(r.sent, 1);
      expect(jsonDecode(backend.only.body), {'conversation_ids': ['c2']});
    });
  });
}
