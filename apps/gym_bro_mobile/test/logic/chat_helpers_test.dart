import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/chat.dart';
import 'package:gym_bro_mobile/models/people.dart';
import 'package:gym_bro_mobile/pages/chat/chat_attachments.dart';
import 'package:gym_bro_mobile/pages/chat/chat_widgets.dart';
import 'package:gym_bro_mobile/services/auth_manager.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_fixtures.dart';
import '../helpers/fake_backend.dart';

final en = lookupAppLocalizations(const Locale('en'));

/// A GET /chat/conversations row.
Map<String, dynamic> _conversation({
  String kind = 'group',
  Map<String, dynamic>? lastMessage,
}) =>
    {
      'id': 'conv-1',
      'kind': kind,
      'title': kind == 'group' ? 'Leg Day Crew' : null,
      'description': 'Squats every Monday',
      'avatar_url': null,
      'created_by': 'u-me',
      'last_message_at': '2026-10-27T18:00:00.000Z',
      'my_role': 'owner',
      'my_status': 'active',
      'muted': true,
      'archived': false,
      'last_read_at': '2026-10-27T17:00:00.000Z',
      'unread_count': '3',
      'participant_count': 3,
      'participants': [
        {'id': 'u-me', 'username': 'me', 'name': 'Liam', 'last_name': "O'Connor"},
        {'id': 'u-2', 'username': 'sofia', 'name': 'Sofia', 'last_name': 'Rossi'},
        {'id': 'u-3', 'username': 'ravi', 'name': 'Ravi', 'last_name': 'Deshmukh'},
      ],
      'other_user': null,
      'last_message': lastMessage,
    };

Map<String, dynamic> _msg({
  String? senderId = 'u-2',
  String? senderName = 'Sofia',
  String kind = 'text',
  String? preview = 'See you at 6',
  Map<String, dynamic>? metadata,
  bool deleted = false,
}) =>
    {
      'id': 'msg-1',
      'sender_id': senderId,
      'sender_name': senderName,
      'kind': kind,
      'preview': preview,
      'metadata': metadata,
      'created_at': '2026-10-27T18:00:00.000Z',
      'deleted': deleted,
    };

void main() {
  setUpAll(() => initializeDateFormatting());

  group('signed in as u-me', () {
    late FakeBackend backend;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      backend = FakeBackend()..install();
      await AuthManager.instance.setSession(signinJson(), profileData: profileJson(id: 'u-me', name: 'Liam'));
      await pumpEventQueue();
    });

    tearDownAll(() async {
      await AuthManager.instance.clear();
      backend.uninstall();
    });

    test('chatMyId / chatMe come from the signed-in profile', () {
      expect(chatMyId, 'u-me');
      final me = chatMe()!;
      expect((me.id, me.username, me.name, me.lastName), ('u-me', 'liamoconnor', 'Liam', "O'Connor"));
    });

    group('systemEventText', () {
      String sys(Map<String, dynamic> metadata, {String? actorId = 'u-2', String? actorName}) => systemEventText(
            en,
            metadata: metadata,
            actorId: actorId,
            actorName: actorName,
            nameOf: (id) => {'u-2': 'Sofia', 'u-3': 'Ravi', 'u-me': 'Liam'}[id] ?? 'Unknown',
          );

      test('me vs someone else as the actor', () {
        expect(sys({'event': 'created'}, actorId: 'u-me'), 'You created the group');
        expect(sys({'event': 'created'}), 'Sofia created the group');
        expect(sys({'event': 'created'}, actorName: 'Sofia R.'), 'Sofia R. created the group');
        expect(sys({'event': 'created'}, actorId: null), 'Someone created the group');
      });

      test('added lists every target, "you" for me', () {
        expect(
          sys({
            'event': 'added',
            'user_ids': ['u-3', 'u-me'],
          }),
          'Sofia added Ravi, you',
        );
        expect(sys({'event': 'added'}), 'Sofia added Someone');
      });

      test('removed / left / renamed / photo / roles / unknown', () {
        expect(sys({'event': 'removed', 'user_id': 'u-3'}, actorId: 'u-me'), 'You removed Ravi');
        expect(sys({'event': 'removed', 'user_id': null}), 'Sofia removed Someone');
        expect(sys({'event': 'left'}), 'Sofia left the group');
        expect(sys({'event': 'renamed', 'title': 'Push Pull Legs'}), 'Sofia named the group "Push Pull Legs"');
        expect(sys({'event': 'renamed', 'title': ''}), 'Sofia removed the group name');
        expect(sys({'event': 'renamed'}), 'Sofia removed the group name');
        expect(sys({'event': 'photo_changed'}), 'Sofia changed the group photo');
        expect(sys({'event': 'role_changed', 'user_id': 'u-me', 'role': 'admin'}), 'Sofia made you an admin');
        expect(sys({'event': 'role_changed', 'user_id': 'u-3', 'role': 'owner'}), 'Sofia made Ravi the group owner');
        expect(sys({'event': 'role_changed', 'user_id': 'u-3', 'role': 'member'}), 'Sofia removed Ravi as admin');
        expect(sys({'event': 'archived_by_robots'}), 'Sofia updated the group');
        expect(sys(const {}), 'Sofia updated the group');
      });
    });

    group('lastMessagePreview', () {
      ({String text, bool italic}) preview(Map<String, dynamic>? last, {String kind = 'group'}) =>
          lastMessagePreview(en, Conversation.fromJson(_conversation(kind: kind, lastMessage: last)));

      test('no message → empty', () {
        expect(preview(null), (text: '', italic: false));
      });

      test('unsent → italic "Message unsent"', () {
        expect(preview(_msg(deleted: true, preview: null)), (text: 'Message unsent', italic: true));
      });

      test('group text from someone else is prefixed with their name; newlines flattened', () {
        expect(preview(_msg(preview: 'See you\nat 6')), (text: 'Sofia: See you at 6', italic: false));
      });

      test('direct chat text from the other person has no prefix', () {
        expect(preview(_msg(), kind: 'direct'), (text: 'See you at 6', italic: false));
      });

      test('my own message → "You: …"', () {
        expect(preview(_msg(senderId: 'u-me', senderName: 'Liam')), (text: 'You: See you at 6', italic: false));
      });

      test('attachment-only messages show the media label', () {
        expect(preview(_msg(kind: 'media', preview: 'image'), kind: 'direct').text, '📷 Photo');
        expect(preview(_msg(kind: 'media', preview: 'video'), kind: 'direct').text, '🎥 Video');
        expect(preview(_msg(kind: 'media', preview: 'audio'), kind: 'direct').text, '🎤 Audio');
        expect(preview(_msg(kind: 'media', preview: 'file'), kind: 'direct').text, '📎 File');
        expect(preview(_msg(kind: 'media', preview: 'image', senderId: 'u-me')).text, 'You: 📷 Photo');
        // A text caption with media is shown as text.
        expect(preview(_msg(kind: 'media', preview: 'leg day'), kind: 'direct').text, 'leg day');
      });

      test('system messages are italic sentences; names come from participants', () {
        final p = preview(_msg(
          kind: 'system',
          preview: null,
          senderName: null,
          metadata: {
            'event': 'added',
            'user_ids': ['u-3'],
          },
        ));
        expect(p, (text: 'Sofia added Ravi', italic: true));

        final unknown = preview(_msg(kind: 'system', senderId: 'u-gone', senderName: null, preview: null, metadata: {'event': 'left'}));
        expect(unknown.text, 'Someone left the group');
      });
    });
  });

  test('titleInitials', () {
    expect(titleInitials('Leg Day Crew'), 'LD');
    expect(titleInitials('  push   pull '), 'PP');
    expect(titleInitials('solo'), 'S');
    expect(titleInitials('   '), '?');
    expect(titleInitials(''), '?');
    expect(titleInitials('ćevapi ekipa'), 'ĆE');
    expect(titleInitials('🏋️ Lifters'), '🏋️L', reason: 'grapheme clusters, not code units');
  });

  test('isRecentlyActive: within 5 minutes', () {
    final now = DateTime.now();
    expect(isRecentlyActive(null), isFalse);
    expect(isRecentlyActive(now.subtract(const Duration(minutes: 4, seconds: 59))), isTrue);
    expect(isRecentlyActive(now.subtract(const Duration(minutes: 5, seconds: 1))), isFalse);
  });

  test('newChatClientId is unique and URL-safe', () {
    final ids = {for (var i = 0; i < 200; i++) newChatClientId()};
    expect(ids, hasLength(200));
    expect(ids.every((id) => RegExp(r'^[0-9a-z]+-[0-9a-z]+$').hasMatch(id)), isTrue);
  });

  test('chatErrorText strips the Exception prefix', () {
    expect(chatErrorText(Exception('You are not in this chat')), 'You are not in this chat');
    expect(chatErrorText(StateError('x')), 'Bad state: x');
  });

  test('chatMediaLabel / reportReasonLabel cover every value', () {
    expect(AttachmentType.values.map((t) => chatMediaLabel(en, t)), ['📷 Photo', '🎥 Video', '🎤 Audio', '📎 File']);
    for (final r in ReportReason.values) {
      expect(reportReasonLabel(en, r), isNotEmpty);
    }
  });

  group('day / time labels', () {
    final now = DateTime.now();
    DateTime daysAgo(int n, [int hour = 9]) => DateTime(now.year, now.month, now.day - n, hour, 5);

    test('chatDayLabel: Today / Yesterday / weekday / this year / other years', () {
      expect(chatDayLabel(en, daysAgo(0, 0)), 'Today');
      expect(chatDayLabel(en, daysAgo(1, 23)), 'Yesterday');
      expect(chatDayLabel(en, daysAgo(4)), DateFormat.EEEE('en').format(daysAgo(4)));
      final older = daysAgo(10);
      expect(
        chatDayLabel(en, older),
        older.year == now.year ? DateFormat.MMMd('en').format(older) : DateFormat.yMMMd('en').format(older),
      );
      expect(chatDayLabel(en, DateTime(2020, 3, 12)), 'Mar 12, 2020');
    });

    test('chatListTime: clock today, weekday this week, else short date', () {
      expect(chatListTime(en, daysAgo(0, 14)), '14:05');
      expect(chatListTime(en, daysAgo(2)), DateFormat.E('en').format(daysAgo(2)));
      expect(chatListTime(en, DateTime(2020, 3, 12, 8)), 'Mar 12');
      expect(chatClockTime(en, DateTime(2020, 3, 12, 8, 7)), '08:07');
    });
  });

  test('conversationWithMembers keeps every field and swaps the member list', () {
    final c = Conversation.fromJson(_conversation(lastMessage: _msg()));
    final members = [
      ConversationMember.fromJson({'id': 'u-2', 'username': 'sofia', 'name': 'Sofia', 'last_name': 'Rossi', 'role': 'admin'}),
    ];

    final out = conversationWithMembers(c, members);

    expect(out.members.single.person.id, 'u-2');
    expect(out.members.single.role, ParticipantRole.admin);
    expect(out.id, c.id);
    expect(out.kind, c.kind);
    expect(out.title, 'Leg Day Crew');
    expect(out.description, c.description);
    expect(out.createdBy, c.createdBy);
    expect(out.lastMessageAt, c.lastMessageAt);
    expect(out.myRole, ParticipantRole.owner);
    expect(out.muted, isTrue);
    expect(out.archived, isFalse);
    expect(out.lastReadAt, c.lastReadAt);
    expect(out.unreadCount, 3);
    expect(out.participantCount, 3);
    expect(out.participants.map((p) => p.id), ['u-me', 'u-2', 'u-3']);
    expect(out.lastMessage!.id, 'msg-1');
  });

  test('fileIconFor picks by MIME type, then by extension', () {
    expect(fileIconFor('application/pdf', 'plan.pdf'), Icons.picture_as_pdf_outlined);
    expect(fileIconFor('application/octet-stream', 'PLAN.PDF'), Icons.picture_as_pdf_outlined);
    expect(fileIconFor('application/zip', null), Icons.folder_zip_outlined);
    expect(fileIconFor('application/octet-stream', 'photos.rar'), Icons.folder_zip_outlined);
    expect(fileIconFor('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'x.xlsx'), Icons.table_chart_outlined);
    expect(fileIconFor('text/plain', 'log.csv'), Icons.table_chart_outlined, reason: 'extension beats text/*');
    expect(fileIconFor('application/vnd.ms-powerpoint', null), Icons.slideshow_outlined);
    expect(fileIconFor('application/msword', 'cv.doc'), Icons.description_outlined);
    expect(fileIconFor('text/plain', 'notes.txt'), Icons.description_outlined);
    expect(fileIconFor('audio/mpeg', null), Icons.audiotrack_outlined);
    expect(fileIconFor('video/mp4', null), Icons.movie_outlined);
    expect(fileIconFor('image/png', null), Icons.image_outlined);
    expect(fileIconFor('application/octet-stream', 'blob.bin'), Icons.insert_drive_file_outlined);
  });
}
