// Sharing in chat (/chat/share, /chat/messages/:id, /chat/story-replies,
// share on POST …/messages) and the share models: per-viewer previews
// (available / private / unavailable / expired / unresolved), story replies,
// inbox previews.
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/chat.dart';
import 'package:gym_bro_mobile/models/post.dart';
import 'package:gym_bro_mobile/models/reaction.dart';
import 'package:gym_bro_mobile/models/shared_content.dart';
import 'package:gym_bro_mobile/services/api_service.dart';

import '../helpers/fake_backend.dart';
import 'api_test_utils.dart';

// ── Fixtures (shapes from the local stack, ids shortened) ────────────────────

final _author = {'id': 'u-liam', 'username': 'liamoconnor', 'name': 'Liam', 'last_name': "O'Connor", 'avatar_url': null};

Map<String, dynamic> _postShare({bool? available = true, String? reason}) => {
  'kind': 'post',
  'ref_id': 'p-1',
  'available': available,
  'reason': ?reason,
  if (available == true)
    'preview': {
      'id': 'p-1',
      'author': _author,
      'business': null,
      'caption': 'Leg day @Elena Vasquez',
      'post_type': 'generic',
      'attachment': null,
      'thumbnail_url': '/storage/v1/object/sign/user-media/u-liam/a.png?token=t',
      'media_type': 'image',
      'media_count': 2,
      'created_at': '2026-10-30T07:00:00.000Z',
    },
};

Map<String, dynamic> _message({Map<String, dynamic>? share, Map<String, dynamic>? storyReply, String? body = 'look'}) => {
  'id': 'm-1',
  'conversation_id': 'c-1',
  'sender_id': 'u-liam',
  'sender': _author,
  'kind': 'text',
  'body': body,
  'reply_to_id': null,
  'client_id': 'cid-1',
  'metadata': {},
  'created_at': '2026-10-30T07:05:00.000Z',
  'edited_at': null,
  'deleted_at': null,
  'attachments': [],
  'reactions': [],
  'reply_to': null,
  'share': share,
  'story_reply': storyReply,
};

void main() {
  final ctx = useFakeBackend();

  group('shareToChats', () {
    test('POSTs the share, people, chats and note; parses each outcome', () async {
      ctx.backend().on('POST /chat/share', ok({
        'sent': 1,
        'results': [
          {'user_id': 'u-elena', 'conversation_id': 'c-1', 'status': 201, 'message_id': 'm-1'},
          {'user_id': 'u-sofia', 'status': 403, 'error': 'This person only takes messages from their followers'},
        ],
      }, 201));
      final results = await ctx.api().shareToChats(
        token,
        const ShareRequest.of(ShareKind.post, 'p-1'),
        userIds: ['u-elena', 'u-sofia'],
        conversationIds: ['c-group'],
        body: '  look at this  ',
      );
      expectJson(ctx.backend().only, 'POST', '/chat/share', {
        'share': {'kind': 'post', 'ref_id': 'p-1'},
        'user_ids': ['u-elena', 'u-sofia'],
        'conversation_ids': ['c-group'],
        'body': 'look at this',
      });
      expect(results.map((r) => (r.userId, r.sent)), [('u-elena', true), ('u-sofia', false)]);
      expect(results[1].error, contains('followers'));
    });

    test('a meal is shared by day + slot, without a ref; a blank note is left out', () async {
      ctx.backend().on('POST /chat/share', ok({'sent': 1, 'results': []}, 201));
      await ctx.api().shareToChats(
        token,
        const ShareRequest(kind: ShareKind.meal, mealDate: '2026-10-29', mealSlot: 'lunch'),
        userIds: ['u-elena'],
        body: '   ',
      );
      expect(bodyOf(ctx.backend().only), {
        'share': {
          'kind': 'meal',
          'meal': {'log_date': '2026-10-29', 'slot_type': 'lunch'},
        },
        'user_ids': ['u-elena'],
      });
    });

    test('nothing sent → the API error', () async {
      ctx.backend().on('POST /chat/share', err(404, 'Post not found', code: 'share_not_found'));
      await expectLater(
        ctx.api().shareToChats(token, const ShareRequest.of(ShareKind.post, 'p-x'), userIds: ['u-elena']),
        throwsApiError('Post not found'),
      );
    });
  });

  test('getChatMessage resolves a share for me', () async {
    ctx.backend().on('GET /chat/messages/m-1', ok(_message(share: _postShare(available: false, reason: 'private'))));
    final m = await ctx.api().getChatMessage(token, 'm-1');
    expectGet(ctx.backend().only, '/chat/messages/m-1');
    expect(m.share!.available, isFalse);
    expect(m.share!.reason, ShareUnavailableReason.private);
    expect(m.share!.preview, isEmpty, reason: 'nothing of a private post reaches the viewer');
    expect(m.needsResolve, isFalse);
  });

  test('replyToStory sends a reaction or text with the story id', () async {
    ctx.backend().on('POST /chat/story-replies', ok(_message(body: '🔥', storyReply: {
      'mode': 'reaction',
      'story_id': 's-1',
      'owner_id': 'u-elena',
      'reaction': 'fire',
      'story': {'kind': 'story', 'ref_id': 's-1', 'available': true, 'preview': {'id': 's-1', 'author': _author}},
    }), 201));
    final m = await ctx.api().replyToStory(token, 's-1', reaction: ReactionType.fire, clientId: 'cid-9');
    expectJson(ctx.backend().last('POST /chat/story-replies'), 'POST', '/chat/story-replies', {
      'story_id': 's-1',
      'reaction': 'fire',
      'client_id': 'cid-9',
    });
    expect(m.storyReply!.isReaction, isTrue);
    expect(m.storyReply!.ownerId, 'u-elena');
    expect(m.storyReply!.story.isAvailable, isTrue);

    await ctx.api().replyToStory(token, 's-1', body: 'Strong!');
    expect(bodyOf(ctx.backend().last('POST /chat/story-replies')), {'story_id': 's-1', 'body': 'Strong!'});
  });

  test('sendMessage can carry a share', () async {
    ctx.backend().on('POST /chat/conversations/c-1/messages', ok(_message(share: _postShare()), 201));
    final m = await ctx.api().sendMessage(
      token,
      'c-1',
      share: const ShareRequest.of(ShareKind.exercise, 'x-1'),
      clientId: 'cid-1',
    );
    expect(bodyOf(ctx.backend().only), {
      'attachments': [],
      'share': {'kind': 'exercise', 'ref_id': 'x-1'},
      'client_id': 'cid-1',
    });
    expect(m.share!.isAvailable, isTrue);
  });

  group('models', () {
    test('an available post share: author, caption, signed thumbnail, media count', () {
      final s = SharedContent.maybeFromJson(_postShare())!;
      expect(s.kind, ShareKind.post);
      expect(s.isAvailable, isTrue);
      expect(s.author!.username, 'liamoconnor');
      expect(s.caption, 'Leg day @Elena Vasquez');
      expect(s.mediaUrl, startsWith('/storage/v1/'));
      expect(s.mediaCount, 2);
      expect(s.title, "Liam O'Connor");
    });

    test('reasons parse; unknown ones fall back to unavailable; unknown kinds are dropped', () {
      for (final (raw, reason) in [
        ('private', ShareUnavailableReason.private),
        ('expired', ShareUnavailableReason.expired),
        ('unavailable', ShareUnavailableReason.unavailable),
        ('gone-fishing', ShareUnavailableReason.unavailable),
      ]) {
        expect(SharedContent.maybeFromJson(_postShare(available: false, reason: raw))!.reason, reason);
      }
      expect(SharedContent.maybeFromJson({'kind': 'spaceship', 'available': true}), isNull);
      expect(SharedContent.maybeFromJson(null), isNull);
    });

    test('a realtime payload (available: null) needs resolving; a deleted message never does', () {
      final live = ChatMessage.fromJson(_message(share: _postShare(available: null)));
      expect(live.share!.isResolved, isFalse);
      expect(live.needsResolve, isTrue);
      final gone = ChatMessage.fromJson({..._message(share: _postShare(available: null)), 'deleted_at': '2026-10-30T08:00:00Z'});
      expect(gone.needsResolve, isFalse);
      final story = ChatMessage.fromJson(_message(storyReply: {
        'mode': 'reply',
        'story_id': 's-1',
        'owner_id': 'u-elena',
        'story': {'kind': 'story', 'ref_id': 's-1', 'available': null},
      }));
      expect(story.needsResolve, isTrue);
      expect(story.copyWith(pending: true).share, isNull);
      expect(story.copyWith(pending: true).storyReply, isNotNull, reason: 'copyWith keeps the story reply');
    });

    test('a deleted story leaves the reply with an unavailable story', () {
      final m = ChatMessage.fromJson(_message(storyReply: {'mode': 'reaction', 'story_id': null, 'owner_id': 'u-me'}));
      expect(m.storyReply!.story.available, isFalse);
      expect(m.storyReply!.story.reason, ShareUnavailableReason.unavailable);
    });

    test('workout / library shares read as post attachments', () {
      final s = SharedContent.maybeFromJson({
        'kind': 'workout',
        'ref_id': 'sess-1',
        'available': true,
        'preview': {'title': 'Leg day', 'duration_minutes': 30, 'volume_kg': 300},
      })!;
      expect(s.kind.postType, PostType.workout);
      expect(s.attachment.durationMinutes, 30);
      expect(s.title, 'Leg day');
    });

    test('ShareKind: stories take neither people, businesses nor stories', () {
      expect(ShareKind.values.where((k) => !k.storyable), [ShareKind.story, ShareKind.user, ShareKind.business]);
      for (final t in PostType.values.where((t) => t != PostType.generic)) {
        expect(ShareKind.fromPostType(t).postType, t, reason: 'round-trips ${t.apiValue}');
      }
    });

    test('ShareRequest from a "share as post" target and back', () {
      final target = ShareTarget.meal(DateTime(2026, 10, 29), 'lunch');
      final r = ShareRequest.fromTarget(target);
      expect(r.toJson(), {
        'kind': 'meal',
        'meal': {'log_date': '2026-10-29', 'slot_type': 'lunch'},
      });
      expect(r.postTarget!.toRequestJson(), target.toRequestJson());
      expect(const ShareRequest.of(ShareKind.user, 'u-1').postTarget, isNull);
      final tomorrow = ShareRequest.fromTarget(
        ShareTarget.workout('s-2', startedAt: DateTime.now().add(const Duration(days: 1))),
      );
      expect(tomorrow.isFuture(), isTrue);
    });

    test('inbox rows carry share_kind / story_mode', () {
      final last = LastMessagePreview.fromJson({
        'id': 'm-1',
        'kind': 'text',
        'preview': null,
        'share_kind': 'routine',
        'story_mode': null,
        'created_at': '2026-10-30T07:05:00.000Z',
      });
      expect(last.shareKind, ShareKind.routine);
      expect(last.storyMode, isNull);
    });
  });
}
