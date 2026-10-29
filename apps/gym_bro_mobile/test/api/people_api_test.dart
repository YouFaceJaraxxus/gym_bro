import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/people.dart';
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

DateTime _utc(String iso) => DateTime.parse(iso);

// ── Fixtures (shapes captured from the local stack, ids shortened) ───────────

Map<String, dynamic> _rel({
  String following = 'none',
  String followedBy = 'none',
  String friendship = 'none',
  bool blocked = false,
}) =>
    {'following': following, 'followed_by': followedBy, 'friendship': friendship, 'blocked': blocked};

/// A /social list row (search, followers, blocks, …).
Map<String, dynamic> _row(String id, String username, String name, String lastName,
        {String? bio, bool isPrivate = false, Map<String, dynamic>? relationship}) =>
    {
      'id': id,
      'username': username,
      'name': name,
      'last_name': lastName,
      'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=$username&size=256',
      'bio': bio,
      'is_private': isPrivate,
      'relationship': relationship,
    };

final _elenaRow = _row('u-elena', 'elenavasquez', 'Elena', 'Vasquez',
    bio: 'Coach at Ironclad 🏋️‍♀️',
    relationship: _rel(following: 'accepted', followedBy: 'accepted', friendship: 'friends'));

/// GET /social/me (own profile, with settings).
Map<String, dynamic> _meJson() => {
      'id': 'u-liam',
      'username': 'liamoconnor',
      'name': 'Liam',
      'last_name': "O'Connor",
      'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=liamoconnor&size=256',
      'role': 'member',
      'bio': 'Chasing a 200kg deadlift.',
      'interests': ['powerlifting', 'meal prep', 'running'],
      'is_private': false,
      'created_at': '2026-09-15T16:05:42.372Z',
      'is_me': true,
      'counts': {'posts': 2, 'followers': 9, 'following': '10', 'friends': 4},
      'relationship': null,
      'can_view_content': true,
      'message_status': null,
      'mutual_friends': {'count': 0, 'preview': []},
      'gyms': [
        {'id': 'g1', 'name': 'Ironclad Fitness', 'logo': 'https://picsum.photos/seed/gym-logo/800/400'},
      ],
      'last_active_at': '2026-10-28T18:47:22.076Z',
      'settings': {
        'is_private': false,
        'discoverable': true,
        'who_can_message': 'friends',
        'show_activity_status': true,
        'has_location': true,
        'location_updated_at': '2026-10-20T10:00:00.000Z',
      },
    };

/// GET /social/users/:id for a private account I don't follow.
Map<String, dynamic> _ingridJson() => {
      'id': 'u-ingrid',
      'username': 'ingridlarsen',
      'name': 'Ingrid',
      'last_name': 'Larsen',
      'avatar_url': null,
      'role': 'member',
      'bio': 'Cross-country skier turned lifter.',
      'interests': ['running', 'cycling'],
      'is_private': true,
      'created_at': '2026-09-15T17:19:56.469Z',
      'is_me': false,
      'counts': {'posts': 1, 'followers': 3, 'following': 6, 'friends': 1},
      'relationship': _rel(followedBy: 'pending'),
      'can_view_content': false,
      'message_status': 'request',
      'mutual_friends': {
        'count': '2',
        'preview': [_elenaRow],
      },
      'gyms': [],
      'last_active_at': null,
    };

void _expectMe(PublicProfile p) {
  expect(p.id, 'u-liam');
  expect(p.username, 'liamoconnor');
  expect(p.name, 'Liam');
  expect(p.lastName, "O'Connor");
  expect(p.avatarUrl, 'https://api.dicebear.com/9.x/avataaars/png?seed=liamoconnor&size=256');
  expect(p.role, 'member');
  expect(p.bio, 'Chasing a 200kg deadlift.');
  expect(p.interests, ['powerlifting', 'meal prep', 'running']);
  expect(p.isPrivate, isFalse);
  expect(p.isMe, isTrue);
  expect(p.counts.posts, 2);
  expect(p.counts.followers, 9);
  expect(p.counts.following, 10);
  expect(p.counts.friends, 4);
  expect(p.relationship, isNull);
  expect(p.canViewContent, isTrue);
  expect(p.messageStatus, isNull);
  expect(p.mutualFriendCount, 0);
  expect(p.mutualFriendsPreview, isEmpty);
  expect(p.gyms.single.id, 'g1');
  expect(p.gyms.single.name, 'Ironclad Fitness');
  expect(p.gyms.single.logo, 'https://picsum.photos/seed/gym-logo/800/400');
  expect(p.lastActiveAt!.toUtc(), _utc('2026-10-28T18:47:22.076Z'));
  expect(p.createdAt!.toUtc(), _utc('2026-09-15T16:05:42.372Z'));
  final s = p.settings!;
  expect(s.isPrivate, isFalse);
  expect(s.discoverable, isTrue);
  expect(s.whoCanMessage, WhoCanMessage.friends);
  expect(s.showActivityStatus, isTrue);
  expect(s.hasLocation, isTrue);
  expect(s.locationUpdatedAt!.toUtc(), _utc('2026-10-20T10:00:00.000Z'));
}

void _expectElena(PersonSummary p) {
  expect(p.id, 'u-elena');
  expect(p.username, 'elenavasquez');
  expect(p.name, 'Elena');
  expect(p.lastName, 'Vasquez');
  expect(p.avatarUrl, 'https://api.dicebear.com/9.x/avataaars/png?seed=elenavasquez&size=256');
  expect(p.bio, 'Coach at Ironclad 🏋️‍♀️');
  expect(p.isPrivate, isFalse);
  expect(p.relationship!.following, FollowState.accepted);
  expect(p.relationship!.followedBy, FollowState.accepted);
  expect(p.relationship!.friendship, FriendState.friends);
  expect(p.relationship!.blocked, isFalse);
}

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('getMyProfile', () {
    test('GETs /social/me and parses the profile with settings', () async {
      backend.on('GET /social/me', ok(_meJson()));
      final p = await api.getMyProfile(_token);
      _expectRequest(backend.only, 'GET', '/social/me');
      _expectMe(p);
    });

    test('401 surfaces the message; non-JSON errors still throw', () async {
      backend.on('GET /social/me', err(401, 'Invalid or expired token'));
      await expectLater(api.getMyProfile(_token), _throwsMessage('Invalid or expired token'));
      backend.on('GET /social/me', ok('Internal Server Error', 500));
      await expectLater(api.getMyProfile(_token), _throwsMessage('Request failed (500)'));
    });
  });

  group('updateMyProfile', () {
    test('PUTs the changes as-is', () async {
      backend.on('PUT /social/me', ok(_meJson()));
      final changes = {
        'bio': null,
        'interests': ['running'],
        'is_private': true,
        'discoverable': false,
        'who_can_message': 'friends',
        'show_activity_status': false,
        'username': 'liam.o',
      };

      final p = await api.updateMyProfile(_token, changes);

      final req = backend.only;
      _expectRequest(req, 'PUT', '/social/me');
      expect(bodyOf(req), equals(changes));
      expect(p.id, 'u-liam');
    });

    test('409 (username taken) surfaces the message', () async {
      backend.on('PUT /social/me', err(409, 'That username is taken'));
      await expectLater(api.updateMyProfile(_token, {'username': 'x'}), _throwsMessage('That username is taken'));
    });
  });

  group('setMyLocation', () {
    test('PUTs {lat, lng}', () async {
      backend.on('PUT /social/me/location', ok({'has_location': true}));
      await api.setMyLocation(_token, 40.6943, -73.9249);
      final req = backend.only;
      _expectRequest(req, 'PUT', '/social/me/location');
      expect(bodyOf(req), equals({'lat': 40.6943, 'lng': -73.9249}));
    });

    test('400 surfaces the message', () async {
      backend.on('PUT /social/me/location', err(400, 'lat and lng must be valid coordinates'));
      await expectLater(api.setMyLocation(_token, 91, 0), _throwsMessage('lat and lng must be valid coordinates'));
    });
  });

  group('clearMyLocation', () {
    test('DELETEs /social/me/location and accepts an empty 204', () async {
      backend.on('DELETE /social/me/location', ok('', 204));
      await api.clearMyLocation(_token);
      final req = backend.only;
      _expectRequest(req, 'DELETE', '/social/me/location');
      expect(req.body, isEmpty);
    });

    test('non-JSON error still throws', () async {
      backend.on('DELETE /social/me/location', ok('<html>oops</html>', 503));
      await expectLater(api.clearMyLocation(_token), _throwsMessage('Request failed (503)'));
    });
  });

  group('getSocialBadges', () {
    test('GETs /social/badges and parses counts (strings too)', () async {
      backend.on(
        'GET /social/badges',
        ok({
          'follow_requests': 1,
          'friend_requests': '2',
          'unread_conversations': 3,
          'message_requests': 0,
          'unread_notifications': 11,
        }),
      );
      final b = await api.getSocialBadges(_token);
      _expectRequest(backend.only, 'GET', '/social/badges');
      expect(b.followRequests, 1);
      expect(b.friendRequests, 2);
      expect(b.unreadConversations, 3);
      expect(b.messageRequests, 0);
      expect(b.unreadNotifications, 11);
      expect(b.requests, 3);
    });

    test('500 surfaces the message', () async {
      backend.on('GET /social/badges', err(500, 'boom'));
      await expectLater(api.getSocialBadges(_token), _throwsMessage('boom'));
    });
  });

  group('getProfile', () {
    test("GETs /social/users/:id and parses someone else's private profile", () async {
      backend.on('GET /social/users/u-ingrid', ok(_ingridJson()));

      final p = await api.getProfile(_token, 'u-ingrid');

      _expectRequest(backend.only, 'GET', '/social/users/u-ingrid');
      expect(p.id, 'u-ingrid');
      expect(p.avatarUrl, isNull);
      expect(p.isPrivate, isTrue);
      expect(p.isMe, isFalse);
      expect(p.canViewContent, isFalse);
      expect(p.messageStatus, 'request');
      expect(p.relationship!.following, FollowState.none);
      expect(p.relationship!.followedBy, FollowState.pending);
      expect(p.relationship!.friendship, FriendState.none);
      expect(p.counts.followers, 3);
      expect(p.mutualFriendCount, 2);
      _expectElena(p.mutualFriendsPreview.single);
      expect(p.gyms, isEmpty);
      expect(p.lastActiveAt, isNull);
      expect(p.settings, isNull);
      expect(p.createdAt!.toUtc(), _utc('2026-09-15T17:19:56.469Z'));
    });

    test('404 surfaces the message', () async {
      backend.on('GET /social/users/u-x', err(404, 'User not found'));
      await expectLater(api.getProfile(_token, 'u-x'), _throwsMessage('User not found'));
    });
  });

  group('getProfileByUsername', () {
    test('GETs /social/users/by-username/:name (encoded)', () async {
      backend.on('GET /social/users/by-username/ingridlarsen', ok(_ingridJson()));
      final p = await api.getProfileByUsername(_token, 'ingridlarsen');
      _expectRequest(backend.only, 'GET', '/social/users/by-username/ingridlarsen');
      expect(p.username, 'ingridlarsen');

      // Characters that would break the path are percent-encoded.
      backend.on('GET /social/users/by-username/a%20b%2Fc', ok(_ingridJson()));
      await api.getProfileByUsername(_token, 'a b/c');
      expect(pathOf(backend.requests.last), '/social/users/by-username/a%20b%2Fc');
    });

    test('404 surfaces the message', () async {
      backend.on('GET /social/users/by-username/nobody', err(404, 'User not found'));
      await expectLater(api.getProfileByUsername(_token, 'nobody'), _throwsMessage('User not found'));
    });
  });

  group('getPeopleList', () {
    test('GETs /social/users/:id/:list with paging and an empty q', () async {
      backend.on('GET /social/users/u-liam/followers', ok([_elenaRow]));

      final list = await api.getPeopleList(_token, 'u-liam', 'followers');

      _expectRequest(backend.only, 'GET', '/social/users/u-liam/followers',
          query: {'page': '0', 'page_size': '30', 'q': ''});
      _expectElena(list.single);
    });

    test('every list name, with an encoded query', () async {
      for (final l in ['following', 'friends', 'mutual-friends']) {
        backend.on('GET /social/users/u-1/$l', ok([]));
      }
      await api.getPeopleList(_token, 'u-1', 'following', query: 'el & co', page: 1, pageSize: 10);
      await api.getPeopleList(_token, 'u-1', 'friends');
      await api.getPeopleList(_token, 'u-1', 'mutual-friends');
      expect(backend.requests[0].url.queryParameters, {'page': '1', 'page_size': '10', 'q': 'el & co'});
      expect(backend.requests.map(pathOf),
          ['/social/users/u-1/following', '/social/users/u-1/friends', '/social/users/u-1/mutual-friends']);
    });

    test('403 private_account throws PrivateAccountException', () async {
      backend.on('GET /social/users/u-ingrid/followers', err(403, 'This account is private', code: 'private_account'));
      await expectLater(api.getPeopleList(_token, 'u-ingrid', 'followers'), throwsA(isA<PrivateAccountException>()));
    });

    test('other 403s surface the message', () async {
      backend.on('GET /social/users/u-ingrid/followers', err(403, 'Forbidden'));
      await expectLater(api.getPeopleList(_token, 'u-ingrid', 'followers'), _throwsMessage('Forbidden'));
    });
  });

  group('relationship actions', () {
    final cases = <String, (String, String, Future<Relationship?> Function(ApiService, String))>{
      'follow': ('POST', 'follow', (a, id) => a.follow(_token, id)),
      'unfollow': ('DELETE', 'follow', (a, id) => a.unfollow(_token, id)),
      'removeFollower': ('DELETE', 'follower', (a, id) => a.removeFollower(_token, id)),
      'addFriend': ('POST', 'friend', (a, id) => a.addFriend(_token, id)),
      'removeFriend': ('DELETE', 'friend', (a, id) => a.removeFriend(_token, id)),
      'block': ('POST', 'block', (a, id) => a.block(_token, id)),
      'unblock': ('DELETE', 'block', (a, id) => a.unblock(_token, id)),
    };

    for (final MapEntry(key: name, value: (method, action, call)) in cases.entries) {
      test('$name → $method /social/users/:id/$action, parses the relationship', () async {
        backend.on(
          '$method /social/users/u-ingrid/$action',
          ok({
            'user_id': 'u-ingrid',
            'relationship': _rel(following: 'pending', followedBy: 'accepted', friendship: 'outgoing', blocked: action == 'block'),
          }),
        );

        final rel = await call(api, 'u-ingrid');

        final req = backend.only;
        _expectRequest(req, method, '/social/users/u-ingrid/$action');
        expect(req.body, isEmpty);
        expect(rel!.following, FollowState.pending);
        expect(rel.followedBy, FollowState.accepted);
        expect(rel.friendship, FriendState.outgoing);
        expect(rel.blocked, action == 'block');
      });
    }

    test('a null relationship (they blocked me) parses as null', () async {
      backend.on('POST /social/users/u-x/follow', ok({'user_id': 'u-x', 'relationship': null}));
      expect(await api.follow(_token, 'u-x'), isNull);
    });

    test('incoming friend request accepted → friends', () async {
      backend.on(
        'POST /social/users/u-n/friend',
        ok({'user_id': 'u-n', 'relationship': _rel(following: 'accepted', followedBy: 'accepted', friendship: 'friends')}),
      );
      final rel = await api.addFriend(_token, 'u-n');
      expect(rel!.isFriend, isTrue);
    });

    test('errors surface the message', () async {
      backend.on('POST /social/users/u-liam/follow', err(400, "That's you"));
      await expectLater(api.follow(_token, 'u-liam'), _throwsMessage("That's you"));
      backend.on('DELETE /social/users/u-x/block', err(404, 'User not found'));
      await expectLater(api.unblock(_token, 'u-x'), _throwsMessage('User not found'));
    });
  });

  group('getBlockedUsers', () {
    test('GETs /social/blocks', () async {
      backend.on(
        'GET /social/blocks',
        ok([
          _row('u-troll', 'troll', 'Some', 'One', relationship: _rel(blocked: true)),
        ]),
      );
      final list = await api.getBlockedUsers(_token);
      _expectRequest(backend.only, 'GET', '/social/blocks');
      expect(list.single.id, 'u-troll');
      expect(list.single.relationship!.blocked, isTrue);
      expect(list.single.bio, isNull);
    });

    test('500 surfaces the message', () async {
      backend.on('GET /social/blocks', err(500, 'boom'));
      await expectLater(api.getBlockedUsers(_token), _throwsMessage('boom'));
    });
  });

  group('getFollowRequests', () {
    test('GETs /social/follow-requests', () async {
      backend.on(
        'GET /social/follow-requests',
        ok([
          _row('u-gab', 'gabrielsantos', 'Gabriel', 'Santos',
              bio: 'Muscle-up or bust.', isPrivate: true, relationship: _rel(followedBy: 'pending')),
        ]),
      );
      final list = await api.getFollowRequests(_token);
      _expectRequest(backend.only, 'GET', '/social/follow-requests');
      final p = list.single;
      expect(p.fullName, 'Gabriel Santos');
      expect(p.isPrivate, isTrue);
      expect(p.relationship!.followedBy, FollowState.pending);
    });

    test('500 surfaces the message', () async {
      backend.on('GET /social/follow-requests', err(500, 'boom'));
      await expectLater(api.getFollowRequests(_token), _throwsMessage('boom'));
    });
  });

  group('respondToFollowRequest', () {
    test('accept → POST /social/follow-requests/:id/accept', () async {
      backend.on('POST /social/follow-requests/u-gab/accept',
          ok({'user_id': 'u-gab', 'relationship': _rel(followedBy: 'accepted')}));
      await api.respondToFollowRequest(_token, 'u-gab', accept: true);
      final req = backend.only;
      _expectRequest(req, 'POST', '/social/follow-requests/u-gab/accept');
      expect(req.body, isEmpty);
    });

    test('decline → DELETE /social/follow-requests/:id', () async {
      backend.on('DELETE /social/follow-requests/u-gab', ok({'user_id': 'u-gab', 'relationship': _rel()}));
      await api.respondToFollowRequest(_token, 'u-gab', accept: false);
      final req = backend.only;
      _expectRequest(req, 'DELETE', '/social/follow-requests/u-gab');
      expect(req.body, isEmpty);
    });

    test('404 surfaces the message', () async {
      backend.on('POST /social/follow-requests/u-x/accept', err(404, 'Request not found'));
      await expectLater(api.respondToFollowRequest(_token, 'u-x', accept: true), _throwsMessage('Request not found'));
    });
  });

  group('getFriendRequests', () {
    test('incoming by default; parses mutual_count and created_at', () async {
      backend.on(
        'GET /social/friend-requests',
        ok([
          {
            ..._row('u-nat', 'nataliapetrova', 'Natalia', 'Petrova',
                bio: 'Former gymnast.', relationship: _rel(following: 'accepted', followedBy: 'accepted', friendship: 'incoming')),
            'created_at': '2026-10-26T15:25:54.327Z',
            'mutual_count': 3,
          },
          {
            ..._row('u-gab', 'gabrielsantos', 'Gabriel', 'Santos', relationship: _rel(friendship: 'incoming')),
            'created_at': null,
            'mutual_count': '0',
          },
        ]),
      );

      final list = await api.getFriendRequests(_token);

      _expectRequest(backend.only, 'GET', '/social/friend-requests', query: {'direction': 'incoming'});
      final a = list[0];
      expect(a.person.id, 'u-nat');
      expect(a.person.bio, 'Former gymnast.');
      expect(a.person.relationship!.friendship, FriendState.incoming);
      expect(a.mutualCount, 3);
      expect(a.createdAt!.toUtc(), _utc('2026-10-26T15:25:54.327Z'));
      expect(list[1].mutualCount, 0);
      expect(list[1].createdAt, isNull);
    });

    test('outgoing', () async {
      backend.on('GET /social/friend-requests', ok([]));
      expect(await api.getFriendRequests(_token, outgoing: true), isEmpty);
      expect(backend.only.url.queryParameters, {'direction': 'outgoing'});
    });

    test('500 surfaces the message', () async {
      backend.on('GET /social/friend-requests', err(500, 'boom'));
      await expectLater(api.getFriendRequests(_token), _throwsMessage('boom'));
    });
  });

  group('report', () {
    test('reports a user with details', () async {
      backend.on('POST /social/reports', ok({'id': 'r1', 'created_at': '2026-10-28T19:00:00.000Z'}, 201));
      await api.report(_token, userId: 'u-troll', reason: ReportReason.harassment, details: 'Rude DMs');
      final req = backend.only;
      _expectRequest(req, 'POST', '/social/reports');
      expect(bodyOf(req), equals({'user_id': 'u-troll', 'reason': 'harassment', 'details': 'Rude DMs'}));
    });

    test('reports a message; omits null user_id/details', () async {
      backend.on('POST /social/reports', ok({'id': 'r2', 'created_at': '2026-10-28T19:00:00.000Z'}, 201));
      await api.report(_token, messageId: 'm1', reason: ReportReason.spam);
      expect(bodyOf(backend.only), equals({'message_id': 'm1', 'reason': 'spam'}));
    });

    test('every reason maps to the API value', () async {
      backend.on('POST /social/reports', ok({'id': 'r', 'created_at': '2026-10-28T19:00:00.000Z'}, 201));
      for (final r in ReportReason.values) {
        await api.report(_token, userId: 'u', reason: r);
      }
      expect(backend.requests.map((r) => (bodyOf(r) as Map)['reason']),
          ['spam', 'harassment', 'inappropriate', 'impersonation', 'other']);
    });

    test('404 surfaces the message', () async {
      backend.on('POST /social/reports', err(404, 'Message not found'));
      await expectLater(api.report(_token, messageId: 'm-x', reason: ReportReason.other), _throwsMessage('Message not found'));
    });
  });

  group('searchPeople', () {
    test('GETs /social/search with an encoded q and page', () async {
      backend.on('GET /social/search', ok([_elenaRow]));

      final list = await api.searchPeople(_token, '@elena v');
      await api.searchPeople(_token, 'x', page: 2);

      _expectRequest(backend.requests[0], 'GET', '/social/search', query: {'q': '@elena v', 'page': '0'});
      expect(backend.requests[0].url.query, 'q=%40elena%20v&page=0');
      expect(backend.requests[1].url.queryParameters, {'q': 'x', 'page': '2'});
      _expectElena(list.single);
    });

    test('500 surfaces the message', () async {
      backend.on('GET /social/search', err(500, 'boom'));
      await expectLater(api.searchPeople(_token, 'x'), _throwsMessage('boom'));
    });
  });

  group('getSuggestions', () {
    test('GETs /social/suggestions and parses score + every reason type', () async {
      backend.on(
        'GET /social/suggestions',
        ok([
          {
            ..._row('u-grace', 'graceokafor', 'Grace', 'Okafor',
                bio: 'Marathoner learning to love the barbell.', relationship: _rel(followedBy: 'accepted')),
            'score': 147,
            'reasons': [
              {'type': 'follows_you'},
              {'type': 'mutual', 'count': 8},
              {'type': 'same_gym', 'gyms': ['Ironclad Fitness']},
              {'type': 'same_time', 'days': 4},
              {'type': 'same_class', 'count': 9},
              {'type': 'nearby', 'km': 3},
              {'type': 'interests', 'interests': ['running']},
              {'type': 'something_new'},
            ],
          },
          {
            ..._row('u-ingrid', 'ingridlarsen', 'Ingrid', 'Larsen', isPrivate: true, relationship: _rel()),
            'score': 37.5,
            'reasons': [],
          },
        ]),
      );

      final list = await api.getSuggestions(_token);

      _expectRequest(backend.only, 'GET', '/social/suggestions', query: {'page': '0', 'page_size': '20'});
      final s = list[0];
      expect(s.person.id, 'u-grace');
      expect(s.person.relationship!.followedBy, FollowState.accepted);
      expect(s.score, 147.0);
      expect(s.reasons, hasLength(7)); // unknown type dropped
      expect(s.reasons[0], isA<FollowsYouReason>());
      expect((s.reasons[1] as MutualReason).count, 8);
      expect((s.reasons[2] as SameGymReason).gyms, ['Ironclad Fitness']);
      expect((s.reasons[3] as SameTimeReason).days, 4);
      expect((s.reasons[4] as SameClassReason).count, 9);
      expect((s.reasons[5] as NearbyReason).km, 3);
      expect((s.reasons[6] as InterestsReason).interests, ['running']);
      expect(list[1].score, 37.5);
      expect(list[1].person.isPrivate, isTrue);
      expect(list[1].reasons, isEmpty);
    });

    test('passes paging', () async {
      backend.on('GET /social/suggestions', ok([]));
      await api.getSuggestions(_token, page: 3, pageSize: 5);
      expect(backend.only.url.queryParameters, {'page': '3', 'page_size': '5'});
    });

    test('500 surfaces the message', () async {
      backend.on('GET /social/suggestions', err(500, 'boom'));
      await expectLater(api.getSuggestions(_token), _throwsMessage('boom'));
    });
  });

  group('getNearby', () {
    test('GETs /social/nearby with radius and page; parses distance', () async {
      backend.on(
        'GET /social/nearby',
        ok([
          {..._elenaRow, 'distance_km': 0},
          {..._row('u-gab', 'gabrielsantos', 'Gabriel', 'Santos'), 'distance_km': '12'},
        ]),
      );

      final list = await api.getNearby(_token);
      await api.getNearby(_token, radiusKm: 100, page: 1);

      _expectRequest(backend.requests[0], 'GET', '/social/nearby', query: {'radius_km': '25', 'page': '0'});
      expect(backend.requests[1].url.queryParameters, {'radius_km': '100', 'page': '1'});
      _expectElena(list[0].person);
      expect(list[0].distanceKm, 0);
      expect(list[1].distanceKm, 12);
      expect(list[1].person.relationship, isNull);
    });

    test('409 location_required throws LocationRequiredException', () async {
      backend.on('GET /social/nearby', err(409, 'Share your location to see people nearby', code: 'location_required'));
      await expectLater(api.getNearby(_token), throwsA(isA<LocationRequiredException>()));
    });

    test('other errors surface the message', () async {
      backend.on('GET /social/nearby', err(500, 'boom'));
      await expectLater(api.getNearby(_token), _throwsMessage('boom'));
    });
  });
}
