import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/config.dart';
import 'package:gym_bro_mobile/models/post.dart';
import 'package:gym_bro_mobile/models/reaction.dart';

void main() {
  // Shape from the API's decoratePosts (features_instagram_parity_test.ts).
  Map<String, dynamic> postJson([Map<String, dynamic> extra = const {}]) => {
    'id': 'p1',
    'business_id': null,
    'author_id': 'u-liam',
    'content': 'Leg day #legday',
    'visibility': 'public',
    'created_at': '2026-10-26T13:37:54.327Z',
    'updated_at': '2026-10-26T13:37:54.327Z',
    'images': [],
    ...extra,
  };

  group('Post Instagram-parity fields', () {
    test('parse saved_by_me, pinned, hide_like_count, comments_disabled, location_name', () {
      final p = Post.fromJson(postJson({
        'saved_by_me': true,
        'pinned': true,
        'pinned_at': '2026-10-27T10:00:00Z',
        'hide_like_count': true,
        'comments_disabled': true,
        'location_name': '  Ironclad Fitness, Belgrade ',
      }));
      expect(p.savedByMe, isTrue);
      expect(p.pinned, isTrue);
      expect(p.hideLikeCount, isTrue);
      expect(p.commentsDisabled, isTrue);
      expect(p.locationName, 'Ironclad Fitness, Belgrade');
    });

    test('default safely when absent (older servers)', () {
      final p = Post.fromJson(postJson());
      expect(p.savedByMe, isFalse);
      expect(p.pinned, isFalse);
      expect(p.hideLikeCount, isFalse);
      expect(p.commentsDisabled, isFalse);
      expect(p.locationName, isNull);
    });

    test('pinned_at alone marks a post pinned; a blank location is none', () {
      final p = Post.fromJson(postJson({'pinned_at': '2026-10-27T10:00:00Z', 'location_name': '  '}));
      expect(p.pinned, isTrue);
      expect(p.locationName, isNull);
    });

    test('hidesCountsFrom: everyone but the author when hide_like_count is on', () {
      final hidden = Post.fromJson(postJson({'hide_like_count': true}));
      expect(hidden.hidesCountsFrom('u-liam'), isFalse);
      expect(hidden.hidesCountsFrom('u-other'), isTrue);
      expect(hidden.hidesCountsFrom(null), isTrue);
      expect(Post.fromJson(postJson()).hidesCountsFrom('u-other'), isFalse);
    });

    test('masked reactions keep the top emojis without counts', () {
      final p = Post.fromJson(postJson({
        'hide_like_count': true,
        'reactions': {'counts': {}, 'total': 0, 'top': ['love', 'fire']},
      }));
      expect(p.reactions.total, 0);
      expect(p.reactions.top, [ReactionType.love, ReactionType.fire]);
    });

    test('copyWith keeps, sets and clears the new fields', () {
      final p = Post.fromJson(postJson({'location_name': 'Gym', 'saved_by_me': true}));
      final same = p.copyWith(content: 'x');
      expect(same.locationName, 'Gym');
      expect(same.savedByMe, isTrue);
      final changed = p.copyWith(savedByMe: false, pinned: true, hideLikeCount: true, commentsDisabled: true);
      expect(changed.savedByMe, isFalse);
      expect(changed.pinned, isTrue);
      expect(changed.hideLikeCount, isTrue);
      expect(changed.commentsDisabled, isTrue);
      expect(changed.locationName, 'Gym');
      expect(p.copyWith(clearLocationName: true).locationName, isNull);
      expect(p.withMyReaction(ReactionType.like).savedByMe, isTrue);
    });
  });

  group('SavedOverview', () {
    const signed = '/storage/v1/object/sign/user-media/u/a.jpg?token=T';

    test('parses "All posts", collections and the post_id flags', () {
      final o = SavedOverview.fromJson({
        'saved': {
          'post_count': '3',
          'covers': [
            {'url': signed, 'media_type': 'image'},
            {'url': null, 'media_type': 'video'},
          ],
        },
        'post_saved': true,
        'collections': [
          {
            'id': 'c1',
            'name': 'Gains',
            'post_count': 1,
            'covers': [],
            'contains_post': true,
            'created_at': '2026-10-01T10:00:00Z',
            'updated_at': '2026-10-02T10:00:00Z',
          },
          {'id': 'c2', 'name': 'Cut', 'post_count': 0, 'covers': [], 'contains_post': false},
        ],
      });
      expect(o.saved.postCount, 3);
      expect(o.saved.covers, hasLength(2));
      expect(o.saved.covers.first.url, AppConfig.resolveUrl(signed));
      expect(o.saved.covers.first.isVideo, isFalse);
      expect(o.saved.covers.last.url, isNull);
      expect(o.saved.covers.last.isVideo, isTrue);
      expect(o.postSaved, isTrue);
      expect(o.collections.map((c) => c.name), ['Gains', 'Cut']);
      expect(o.collections.first.containsPost, isTrue);
      expect(o.collections.first.postCount, 1);
      expect(o.collections.first.updatedAt, DateTime.parse('2026-10-02T10:00:00Z').toLocal());
      expect(o.collections.last.containsPost, isFalse);
    });

    test('without post_id the flags are null; missing parts default', () {
      final o = SavedOverview.fromJson({
        'collections': [
          {'id': 'c1', 'name': 'Gains'},
        ],
      });
      expect(o.saved.postCount, 0);
      expect(o.saved.covers, isEmpty);
      expect(o.postSaved, isNull);
      expect(o.collections.single.containsPost, isNull);
      expect(o.collections.single.postCount, 0);
      expect(o.collections.single.covers, isEmpty);
    });

    test('SaveCollection.copyWith', () {
      const c = SaveCollection(id: 'c1', name: 'Gains', postCount: 2);
      final d = c.copyWith(name: 'Cut', containsPost: true);
      expect(d.id, 'c1');
      expect(d.name, 'Cut');
      expect(d.postCount, 2);
      expect(d.containsPost, isTrue);
    });
  });

  group('HashtagInfo', () {
    test('parses tag rows (counts may be strings)', () {
      final h = HashtagInfo.fromJson({'tag': 'legday', 'post_count': '12'});
      expect(h.tag, 'legday');
      expect(h.postCount, 12);
      expect(HashtagInfo.fromJson({'tag': 'x'}).postCount, 0);
    });
  });

  group('hashtag tokenizer', () {
    List<String> tags(String s) => findHashtags(s).map((m) => m.tag).toList();

    test('finds tags with their positions, lowercased', () {
      const text = 'Leg day #LegDay and #pr_2026!';
      final found = findHashtags(text);
      expect(found.map((m) => m.tag), ['legday', 'pr_2026']);
      expect(text.substring(found[0].start, found[0].end), '#LegDay');
      expect(text.substring(found[1].start, found[1].end), '#pr_2026');
    });

    test('a tag needs a letter, and must not be inside a word', () {
      expect(tags('#10 reps'), isEmpty);
      expect(tags('set#3 and abc#def'), isEmpty);
      expect(tags('#10kg'), ['10kg']);
      expect(tags('##double'), isEmpty);
      expect(tags('https://x.com/#frag &#123;'), isEmpty);
      expect(tags('(#inside) "#quoted"'), ['inside', 'quoted']);
    });

    test('unicode letters count', () {
      expect(tags('#čučanj #Übung #тренинг'), ['čučanj', 'übung', 'тренинг']);
    });

    test('tags start at the beginning and after punctuation or newlines', () {
      expect(tags('#first\n#second,#third'), ['first', 'second', 'third']);
    });

    test('before: the character preceding a piece of a longer text', () {
      expect(findHashtags('#tag', before: 'word'), isEmpty);
      final f = findHashtags('#tag', before: 'word ');
      expect(f.single.start, 0);
      expect(f.single.end, 4);
    });

    test('at most 50 characters (the rest is plain text)', () {
      final long = 'a' * 60;
      final f = findHashtags('#$long');
      expect(f.single.tag, 'a' * 50);
      expect(f.single.end, 51);
    });

    test('parseHashtags dedupes; hasHashtags; normalizeHashtag', () {
      expect(parseHashtags('#Gym #gym #legs'), ['gym', 'legs']);
      expect(hasHashtags('no tags here'), isFalse);
      expect(hasHashtags('price #1'), isFalse);
      expect(hasHashtags('#gym'), isTrue);
      expect(normalizeHashtag(' #LegDay '), 'legday');
      expect(normalizeHashtag('leg day'), isNull);
      expect(normalizeHashtag(''), isNull);
    });
  });
}
