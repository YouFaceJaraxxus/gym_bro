// Parsing of the /stories/* responses (shapes from the API's stories
// function) and the helpers built on them.
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/reaction.dart';
import 'package:gym_bro_mobile/models/shared_content.dart';
import 'package:gym_bro_mobile/models/story.dart';

Map<String, dynamic> _author() => {
  'id': 'u-1',
  'username': 'liamoconnor',
  'name': 'Liam',
  'last_name': "O'Connor",
  'avatar_url': null,
};

Map<String, dynamic> storyJson({
  String id = 's-1',
  String? mediaUrl,
  String? mediaType,
  int? durationMs,
  String? background,
  Map<String, dynamic>? share,
  bool isMine = false,
}) => {
  'id': id,
  'author_id': 'u-1',
  'media_type': mediaType,
  'mime_type': mediaType == null ? null : '$mediaType/x',
  'width': 1080,
  'height': 1920,
  'duration_ms': durationMs,
  'caption': 'Leg day',
  'background': background,
  'share_kind': share?['kind'],
  'share_ref_id': share?['ref_id'],
  'created_at': '2026-10-30T08:00:00.000Z',
  'expires_at': '2026-10-31T08:00:00.000Z',
  'media_url': mediaUrl,
  'author': _author(),
  'share': share,
  'is_live': true,
  'seen': false,
  'my_reaction': 'fire',
  'liked': true,
  'is_mine': isMine,
  'view_count': isMine ? 3 : null,
  'reaction_count': isMine ? 1 : null,
};

void main() {
  group('Story', () {
    test('a photo story', () {
      final s = Story.fromJson(storyJson(mediaUrl: '/storage/v1/object/sign/user-media/u-1/a.png?token=x', mediaType: 'image'));
      expect(s.hasMedia, isTrue);
      expect(s.mediaUrl, endsWith('/storage/v1/object/sign/user-media/u-1/a.png?token=x'));
      expect(s.mediaUrl, startsWith('http'), reason: 'relative signed URLs are made absolute');
      expect(s.isVideo, isFalse);
      expect(s.author?.username, 'liamoconnor');
      expect(s.myReaction, ReactionType.fire);
      expect(s.liked, isTrue);
      expect(s.viewCount, isNull, reason: 'only the author gets counts');
      expect(s.displayDuration, kStoryPhotoDuration);
      expect(s.expiresAt.difference(s.createdAt), kStoryLifetime);
    });

    test('videos last their length, capped at a minute', () {
      expect(Story.fromJson(storyJson(mediaUrl: '/v.mp4', mediaType: 'video', durationMs: 12000)).displayDuration,
          const Duration(seconds: 12));
      expect(Story.fromJson(storyJson(mediaUrl: '/v.mp4', mediaType: 'video', durationMs: 180000)).displayDuration,
          const Duration(minutes: 1));
      expect(Story.fromJson(storyJson(mediaUrl: '/v.mp4', mediaType: 'video')).displayDuration, kStoryPhotoDuration,
          reason: 'unknown length → the photo time');
    });

    test('a text story on a colour, and my own story with counts', () {
      final s = Story.fromJson(storyJson(background: '#ff5500', isMine: true));
      expect(s.hasMedia, isFalse);
      expect(s.backgroundColor, const Color(0xFFFF5500));
      expect(s.isMine, isTrue);
      expect(s.viewCount, 3);
      expect(s.reactionCount, 1);
    });

    test('a shared post, unavailable to me', () {
      final s = Story.fromJson(storyJson(share: {'kind': 'post', 'ref_id': 'p-1', 'available': false, 'reason': 'private'}));
      expect(s.share?.kind, ShareKind.post);
      expect(s.share?.isAvailable, isFalse);
      expect(s.share?.reason, ShareUnavailableReason.private);
    });

    test('copyWith toggles the like', () {
      final s = Story.fromJson(storyJson());
      expect(s.copyWith(clearMyReaction: true).liked, isFalse);
      expect(s.copyWith(seen: true).seen, isTrue);
      expect(s.copyWith(seen: true).myReaction, ReactionType.fire);
    });
  });

  test('parseHexColor', () {
    expect(parseHexColor('#2a9d8f'), const Color(0xFF2A9D8F));
    expect(parseHexColor('red'), isNull);
    expect(parseHexColor('#fff'), isNull);
    expect(parseHexColor(null), isNull);
    for (final hex in kStoryBackgrounds) {
      expect(parseHexColor(hex), isNotNull, reason: hex);
    }
  });

  test('StoryTrayEntry', () {
    final e = StoryTrayEntry.fromJson({
      'user': _author(),
      'is_me': false,
      'story_count': 3,
      'unseen_count': 2,
      'has_unseen': true,
      'latest_at': '2026-10-30T09:00:00.000Z',
    });
    expect(e.hasUnseen, isTrue);
    expect(e.storyCount, 3);
    expect(e.seenAll().hasUnseen, isFalse);
    expect(e.seenAll().user.id, 'u-1');
  });

  test('StoryViewer and StoryReactionResult', () {
    final v = StoryViewer.fromJson({'user': _author(), 'viewed_at': '2026-10-30T09:00:00.000Z', 'reaction': 'like'});
    expect(v.reaction, ReactionType.like);
    expect(StoryViewer.fromJson({'user': _author(), 'viewed_at': null, 'reaction': null}).reaction, isNull);
    final r = StoryReactionResult.fromJson({'story_id': 's-1', 'my_reaction': null, 'liked': false, 'reaction_count': null});
    expect(r.myReaction, isNull);
  });

  test('quick reactions are distinct', () {
    expect(kStoryQuickReactions.toSet(), hasLength(kStoryQuickReactions.length));
  });

  group('close friends, polls and highlights', () {
    test('audience: close friends, and the default for older servers', () {
      expect(Story.fromJson({...storyJson(), 'audience': 'close_friends', 'close_friends': true}).closeFriends, isTrue);
      expect(Story.fromJson({...storyJson(), 'close_friends': true}).closeFriends, isTrue);
      final plain = Story.fromJson(storyJson());
      expect(plain.closeFriends, isFalse);
      expect(plain.audience, kStoryAudienceEveryone);
      expect(plain.poll, isNull);
    });

    test('a poll before I vote: no results', () {
      final s = Story.fromJson({
        ...storyJson(),
        'poll': {'question': 'Squat or deadlift?', 'options': ['Squat', 'Deadlift'], 'my_vote': null, 'total': null, 'counts': null},
      });
      final p = s.poll!;
      expect(p.question, 'Squat or deadlift?');
      expect(p.options, ['Squat', 'Deadlift']);
      expect(p.voted, isFalse);
      expect(p.hasResults, isFalse);
      expect(p.percent(0), 0);
    });

    test('a poll after voting: counts, percentages, numbers as strings', () {
      final p = StoryPoll.fromJson({'question': '', 'options': ['A', 'B', 'C'], 'my_vote': '1', 'total': 3, 'counts': [1, '2', 0]});
      expect(p.myVote, 1);
      expect(p.hasResults, isTrue);
      expect(p.counts, [1, 2, 0]);
      expect(p.percent(0), 33);
      expect(p.percent(1), 67);
      expect(p.percent(2), 0);
      expect(p.percent(9), 0);
      expect(StoryPoll.fromJson({'options': ['A', 'B'], 'total': 0, 'counts': [0, 0]}).percent(0), 0);
    });

    test('a malformed poll is ignored; toJson trims', () {
      expect(StoryPoll.maybeFromJson({'options': ['only']}), isNull);
      expect(StoryPoll.maybeFromJson('nope'), isNull);
      expect(const StoryPoll(question: ' Q ', options: [' a ', 'b']).toJson(), {'question': 'Q', 'options': ['a', 'b']});
    });

    test('copyWith keeps the audience and replaces the poll', () {
      final s = Story.fromJson({...storyJson(), 'audience': 'close_friends', 'poll': {'question': 'Q', 'options': ['a', 'b']}});
      final voted = s.copyWith(poll: const StoryPoll(question: 'Q', options: ['a', 'b'], myVote: 0, total: 1, counts: [1, 0]));
      expect(voted.closeFriends, isTrue);
      expect(voted.poll!.myVote, 0);
      expect(s.copyWith(seen: true).poll!.question, 'Q');
    });

    test('tray entries and viewers', () {
      final e = StoryTrayEntry.fromJson({'user': _author(), 'unseen_count': 1, 'close_friends': true, 'latest_at': null});
      expect(e.closeFriends, isTrue);
      expect(e.seenAll().closeFriends, isTrue);
      expect(StoryTrayEntry.fromJson({'user': _author()}).closeFriends, isFalse);
      final v = StoryViewer.fromJson({'user': _author(), 'viewed_at': null, 'reaction': null, 'poll_vote': 1});
      expect(v.pollVote, 1);
      expect(StoryViewer.fromJson({'user': _author()}).pollVote, isNull);
    });

    Map<String, dynamic> highlightJson({Map<String, dynamic>? cover}) => {
      'id': 'h-1',
      'user_id': 'u-1',
      'title': 'Gym',
      'cover_story_id': null,
      'story_count': 2,
      'cover': cover ??
          {
            'story_id': 's-2',
            'media_url': '/storage/v1/object/sign/user-media/u-1/b.jpg?token=y',
            'media_type': 'image',
            'background': null,
            'caption': null,
          },
      'created_at': '2026-10-30T08:00:00.000Z',
      'updated_at': '2026-10-30T08:00:00.000Z',
    };

    test('a highlight summary with a photo cover', () {
      final h = StoryHighlight.fromJson(highlightJson());
      expect(h.id, 'h-1');
      expect(h.userId, 'u-1');
      expect(h.title, 'Gym');
      expect(h.coverStoryId, isNull);
      expect(h.storyCount, 2);
      expect(h.cover!.storyId, 's-2');
      expect(h.cover!.hasMedia, isTrue);
      expect(h.cover!.mediaUrl, startsWith('http'));
      expect(h.cover!.isVideo, isFalse);
    });

    test('a text cover', () {
      final h = StoryHighlight.fromJson(highlightJson(
        cover: {'story_id': 's-3', 'media_url': null, 'media_type': null, 'background': '#ff5500', 'caption': 'Hi'},
      ));
      expect(h.cover!.hasMedia, isFalse);
      expect(h.cover!.backgroundColor, const Color(0xFFFF5500));
      expect(h.cover!.caption, 'Hi');
    });

    test('a highlight with its stories', () {
      final d = StoryHighlightDetail.fromJson({
        ...highlightJson(),
        'cover_story_id': 's-1',
        'user': _author(),
        'stories': [
          {...storyJson(id: 's-1'), 'is_live': false},
          storyJson(id: 's-2'),
        ],
      });
      expect(d.id, 'h-1');
      expect(d.title, 'Gym');
      expect(d.highlight.coverStoryId, 's-1');
      expect(d.user?.username, 'liamoconnor');
      expect(d.stories.map((s) => s.id), ['s-1', 's-2']);
      expect(d.stories.first.isLive, isFalse);
      expect(StoryHighlightDetail.fromJson(highlightJson()).stories, isEmpty);
    });
  });
}
