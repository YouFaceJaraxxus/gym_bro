import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/people.dart';
import 'package:gym_bro_mobile/pages/people/profile_qr_page.dart';
import 'package:gym_bro_mobile/services/recent_searches.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('profile links', () {
    test('round-trip a username', () {
      final link = profileLink('liam.oconnor');
      expect(link.toString(), 'gymbroo://u/liam.oconnor');
      expect(usernameFromProfileLink(link.toString()), 'liam.oconnor');
    });

    test('reject other links and bad usernames', () {
      expect(usernameFromProfileLink('gymbroo://auth/callback'), isNull);
      expect(usernameFromProfileLink('https://u/liam'), isNull);
      expect(usernameFromProfileLink('gymbroo://u/'), isNull);
      expect(usernameFromProfileLink('gymbroo://u/a b'), isNull);
      expect(usernameFromProfileLink('not a link'), isNull);
    });
  });

  group('PublicProfile extras', () {
    test('website, mutes and close friends', () {
      final p = PublicProfile.fromJson({
        'id': 'u1',
        'username': 'liam',
        'website': 'https://ironclad.example.com/liam/',
        'muted': {'posts': true, 'stories': false},
        'is_close_friend': true,
      });
      expect(p.website, 'https://ironclad.example.com/liam/');
      expect(p.websiteLabel, 'ironclad.example.com/liam');
      expect(p.muted?.posts, isTrue);
      expect(p.muted?.stories, isFalse);
      expect(p.muted?.any, isTrue);
      expect(p.isCloseFriend, isTrue);
    });

    test('defaults when the server is older', () {
      final p = PublicProfile.fromJson({'id': 'u1', 'username': 'liam'});
      expect(p.website, isNull);
      expect(p.websiteLabel, isNull);
      expect(p.muted, isNull);
      expect(p.isCloseFriend, isFalse);
    });

    test('muted rows', () {
      final row = MutedPerson.fromJson({
        'id': 'u2',
        'username': 'elena',
        'name': 'Elena',
        'last_name': 'Vasquez',
        'muted': {'posts': false, 'stories': true},
      });
      expect(row.person.username, 'elena');
      expect(row.muted.stories, isTrue);
      expect(row.muted.posts, isFalse);
    });
  });

  group('RecentSearches', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    const elena = PersonSummary(id: 'u2', username: 'elena', name: 'Elena', lastName: 'Vasquez');

    test('newest first, deduplicated, per user', () async {
      final mine = RecentSearches('me');
      await mine.add(const RecentSearch.person(elena));
      await mine.add(const RecentSearch.hashtag('legday'));
      final list = await mine.add(const RecentSearch.person(elena));
      expect(list.map((r) => r.key), ['user:u2', 'tag:legday']);
      expect((await mine.load()).first.person?.fullName, 'Elena Vasquez');
      expect(await RecentSearches('someone else').load(), isEmpty);
    });

    test('remove, clear and the cap', () async {
      final r = RecentSearches('me');
      for (var i = 0; i < RecentSearches.max + 5; i++) {
        await r.add(RecentSearch.hashtag('t$i'));
      }
      expect((await r.load()).length, RecentSearches.max);
      expect((await r.load()).first.tag, 't${RecentSearches.max + 4}');
      final after = await r.remove(const RecentSearch.hashtag('t19'));
      expect(after.any((x) => x.tag == 't19'), isFalse);
      await r.clear();
      expect(await r.load(), isEmpty);
    });
  });
}
