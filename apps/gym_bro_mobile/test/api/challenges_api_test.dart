import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/challenge.dart';
import 'package:gym_bro_mobile/services/api_service.dart';

import '../helpers/fake_backend.dart';

const _token = 'tok-123';

// Shapes captured from the local stack (GET /challenges, /challenges/:id as liam).
Map<String, dynamic> _challengeJson({Map<String, dynamic>? me, String status = 'active'}) => {
      'id': 'c-iron',
      'title': 'Iron Month: 10 workouts',
      'description': 'Ten workouts in thirty days.',
      'metric': 'workouts',
      'target': '10', // ints may arrive as strings
      'starts_on': '2026-10-20',
      'ends_on': '2026-11-18',
      'auto_key': null,
      'created_by': 'u-elena',
      'created_at': '2026-10-18T18:50:54.889Z',
      'business': {'id': 'g-iron', 'name': 'Ironclad Fitness', 'logo': null},
      'status': status,
      'days_left': 18,
      'participants': 7,
      'me': me ?? {'joined': true, 'joined_at': '2026-10-22T18:50:54.889Z', 'progress': '3', 'completed_at': null},
      'can_edit': false,
    };

Map<String, dynamic> _monthlyJson() => {
      ..._challengeJson(me: {'joined': false, 'joined_at': null, 'progress': 0, 'completed_at': null}),
      'id': 'c-nov',
      'title': 'November Grind: 12 workouts',
      'auto_key': 'monthly:2026-11:workouts',
      'target': 12,
      'business': null,
      'starts_on': '2026-11-01',
      'ends_on': '2026-11-30',
      'days_left': 30,
    };

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('getChallenges', () {
    test('sends the filters and splits mine from joinable', () async {
      backend.on(
        'GET /challenges',
        ok({
          'today': '2026-11-01',
          'items': [_challengeJson(), _monthlyJson()],
          'can_create_platform': false,
          'creatable_gyms': [
            {'id': 'g-iron', 'name': 'Ironclad Fitness', 'logo': null},
          ],
        }),
      );
      final list = await api.getChallenges(_token, gymId: 'g-iron', tz: 'Europe/Belgrade');

      final req = backend.only;
      expect(req.headers['Authorization'], 'Bearer $_token');
      expect(req.url.queryParameters['gym_id'], 'g-iron');
      expect(req.url.queryParameters['tz'], 'Europe/Belgrade');
      expect(req.url.queryParameters.containsKey('status'), isFalse);

      expect(list.today, DateTime(2026, 11, 1));
      expect(list.items, hasLength(2));
      expect(list.mine.single.id, 'c-iron');
      expect(list.joinable.single.id, 'c-nov');
      expect(list.canCreate, isTrue);
      expect(list.creatableGyms.single.name, 'Ironclad Fitness');

      final c = list.items.first;
      expect(c.target, 10);
      expect(c.me.progress, 3);
      expect(c.fraction, closeTo(0.3, 1e-9));
      expect(c.metric, ChallengeMetric.workouts);
      expect(c.status, ChallengeStatus.active);
      expect(c.startsOn, DateTime(2026, 10, 20));
      expect(c.lengthDays, 30);
      expect(c.isPlatform, isFalse);
      expect(c.canLeave, isTrue);

      final m = list.items.last;
      expect(m.isPlatform, isTrue);
      expect(m.isMonthly, isTrue);
      expect(m.month, DateTime(2026, 11));
      expect(m.canJoin, isTrue);
    });

    test('past challenges', () async {
      backend.on('GET /challenges', ok({'today': '2026-11-01', 'items': []}));
      await api.getChallenges(_token, past: true, joinedOnly: true);
      expect(backend.only.url.queryParameters, {'status': 'past', 'joined': '1'});
    });
  });

  group('one challenge', () {
    test('detail parses the leaderboard and my rank', () async {
      backend.on(
        'GET /challenges/c-iron',
        ok({
          ..._challengeJson(),
          'creator': {'id': 'u-elena', 'username': 'elena', 'name': 'Elena', 'last_name': 'Vasquez', 'avatar_url': null, 'streak_tier': null},
          'leaderboard': [
            {
              'rank': 1,
              'progress': 5,
              'completed_at': null,
              'user': {'id': 'u-1', 'username': 'a', 'name': 'Ana', 'last_name': 'B', 'avatar_url': null, 'streak_tier': 'bronze'},
            },
            {
              'rank': 2,
              'progress': '3',
              'completed_at': '2026-10-29T00:00:00.000Z',
              'user': {'id': 'u-liam', 'username': 'liam', 'name': 'Liam', 'last_name': "O'Connor", 'avatar_url': null},
            },
          ],
          'my_rank': 2,
        }),
      );
      final c = await api.getChallenge(_token, 'c-iron', tz: 'Europe/Belgrade');
      expect(c.creator?.fullName, 'Elena Vasquez');
      expect(c.leaderboard, hasLength(2));
      expect(c.leaderboard.last.progress, 3);
      expect(c.leaderboard.last.completedAt, isNotNull);
      expect(c.leaderboard.first.user?.streakTier?.name, 'bronze');
      expect(c.myRank, 2);
    });

    test('join, leave and delete bump challengeChanges', () async {
      backend.on('POST /challenges/c-iron/join', ok(_challengeJson()));
      backend.on('DELETE /challenges/c-iron/join', ok(null, 204));
      backend.on('DELETE /challenges/c-iron', ok(null, 204));
      final before = challengeChanges.value;
      final joined = await api.joinChallenge(_token, 'c-iron');
      expect(joined.me.joined, isTrue);
      await api.leaveChallenge(_token, 'c-iron');
      await api.deleteChallenge(_token, 'c-iron');
      expect(challengeChanges.value, before + 3);
      expect(backend.requests.map((r) => r.method), ['POST', 'DELETE', 'DELETE']);
    });

    test('a refused join surfaces the error', () async {
      backend.on('POST /challenges/c-old/join', err(400, 'This challenge is over', code: 'challenge_over'));
      await expectLater(api.joinChallenge(_token, 'c-old'), throwsA(predicate((e) => '$e'.contains('over'))));
    });
  });

  group('create and edit', () {
    final draft = ChallengeDraft(
      gymId: 'g-iron',
      title: '  Squat-a-thon ',
      description: '  ',
      metric: ChallengeMetric.volumeKg,
      target: 50000,
      startsOn: DateTime(2026, 11, 2),
      endsOn: DateTime(2026, 11, 30),
    );

    test('create sends the whole draft', () async {
      backend.on('POST /challenges', ok(_challengeJson(), 201));
      await api.createChallenge(_token, draft);
      expect(bodyOf(backend.only), {
        'business_id': 'g-iron',
        'title': 'Squat-a-thon',
        'description': null,
        'metric': 'volume_kg',
        'target': 50000,
        'starts_on': '2026-11-02',
        'ends_on': '2026-11-30',
      });
    });

    test('a platform draft has no business_id', () {
      final platform = ChallengeDraft(
        title: 'x',
        metric: ChallengeMetric.workouts,
        target: 1,
        startsOn: DateTime(2026, 11, 1),
        endsOn: DateTime(2026, 11, 1),
      );
      expect(platform.toJson().containsKey('business_id'), isFalse);
    });

    test('edit sends only what changed', () async {
      final original = Challenge.fromJson(_challengeJson());
      final edited = ChallengeDraft(
        gymId: 'g-iron',
        title: original.title,
        description: original.description,
        metric: original.metric,
        target: 8,
        startsOn: original.startsOn,
        endsOn: DateTime(2026, 11, 25),
      );
      backend.on('PATCH /challenges/c-iron', ok(_challengeJson()));
      await api.updateChallenge(_token, 'c-iron', edited.changesFrom(original));
      expect(bodyOf(backend.only), {'target': 8, 'ends_on': '2026-11-25'});
    });
  });

  group('medals', () {
    test("someone's completed challenges", () async {
      backend.on(
        'GET /challenges/completed',
        ok({
          'user_id': 'u-liam',
          'count': 1,
          'items': [
            {
              'id': 'c-fall',
              'title': 'Fall Kickoff: 3 workouts',
              'metric': 'workouts',
              'target': 3,
              'starts_on': '2026-10-02',
              'ends_on': '2026-10-28',
              'auto_key': null,
              'business': {'id': 'g-iron', 'name': 'Ironclad Fitness', 'logo': null},
              'completed_at': '2026-10-29T00:00:00.000Z',
            },
          ],
          'private': false,
        }),
      );
      final m = await api.getChallengeMedals(_token, userId: 'u-liam');
      expect(backend.only.url.queryParameters['user_id'], 'u-liam');
      expect(m.count, 1);
      expect(m.items.single.gym?.name, 'Ironclad Fitness');
      expect(m.items.single.completedAt, isNotNull);
      expect(m.isPrivate, isFalse);
    });

    test('a private account shows only the count', () {
      final m = ChallengeMedals.fromJson({'user_id': 'u-sofia', 'count': '4', 'items': [], 'private': true});
      expect(m.count, 4);
      expect(m.items, isEmpty);
      expect(m.isPrivate, isTrue);
    });
  });

  test('unknown metrics fall back to workouts; recently completed', () {
    final c = Challenge.fromJson({
      ..._challengeJson(me: {'joined': true, 'progress': 10, 'completed_at': DateTime.now().toUtc().toIso8601String()}),
      'metric': 'pushups',
    });
    expect(c.metric, ChallengeMetric.workouts);
    expect(c.me.completed, isTrue);
    expect(c.completedRecently(DateTime.now()), isTrue);
    expect(c.completedRecently(DateTime.now().add(const Duration(days: 8))), isFalse);
  });
}
