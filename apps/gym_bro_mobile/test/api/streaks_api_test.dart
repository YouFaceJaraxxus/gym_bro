import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/streak.dart';
import 'package:gym_bro_mobile/models/training_session.dart';
import 'package:gym_bro_mobile/services/api_service.dart';

import '../helpers/fake_backend.dart';

const _token = 'tok-123';

// Shapes captured from the local stack (GET /streaks, /streaks/boards/:gym as ethan).
Map<String, dynamic> _statusJson() => {
      'user_id': 'u-ethan',
      'current': 12,
      'since': '2026-09-01',
      'best': '54', // ints may arrive as strings
      'freezes': 1,
      'tier': 'bronze',
      'best_tier': 'silver',
      'timezone': 'Europe/Belgrade',
      'today': '2026-11-01',
      'next_tier': {'tier': 'silver', 'at': 50},
      'week': {
        'start': '2026-10-26',
        'planned': true,
        'target': 3,
        'required': 3,
        'done': 2,
        'entries': [
          {'id': 'e1', 'day': '2026-10-26', 'name': 'Full Body', 'done': true, 'skipped': false},
          {'id': 'e2', 'day': '2026-10-28', 'name': 'Pull Day', 'done': true, 'skipped': false},
          {'id': 'e3', 'day': '2026-11-01', 'name': 'Legs', 'done': false, 'skipped': false},
        ],
      },
      'at_risk': [
        {'id': 'e3', 'day': '2026-11-01', 'name': 'Legs'},
      ],
      'week_remaining': 0,
      'max_freezes': 2,
      'tiers': [
        {'tier': 'bronze', 'at': 10},
      ],
      'events': [
        {'kind': 'freeze_used', 'on_date': '2026-10-18', 'streak': 3, 'tier': null, 'created_at': '2026-11-01T15:15:54.097Z'},
        {'kind': 'tier', 'on_date': '2026-10-02', 'streak': 50, 'tier': 'silver', 'created_at': '2026-11-01T15:15:54.097Z'},
      ],
      'ranks': [
        {'gym_id': 'g1', 'gym_name': 'Summit Strength Collective', 'rank': 1, 'total': 4, 'value': 12},
      ],
    };

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('StreakTier', () {
    test('follows the ladder', () {
      expect(StreakTier.forStreak(9), isNull);
      expect(StreakTier.forStreak(10), StreakTier.bronze);
      expect(StreakTier.forStreak(364), StreakTier.ruby);
      expect(StreakTier.forStreak(1000), StreakTier.diamond);
      expect(StreakTier.nextAbove(100), StreakTier.ruby);
      expect(StreakTier.nextAbove(1000), isNull);
      expect(StreakTier.fromApi('emerald'), StreakTier.emerald);
      expect(StreakTier.fromApi('plutonium'), isNull);
    });
  });

  group('getStreak', () {
    test('sends the device zone and parses every field', () async {
      backend.on('GET /streaks', ok(_statusJson()));
      final s = await api.getStreak(_token, tz: 'Europe/Belgrade');

      final req = backend.only;
      expect(req.headers['Authorization'], 'Bearer $_token');
      expect(req.url.queryParameters['tz'], 'Europe/Belgrade');

      expect(s.current, 12);
      expect(s.best, 54);
      expect(s.tier, StreakTier.bronze);
      expect(s.bestTier, StreakTier.silver);
      expect(s.nextTier, StreakTier.silver);
      expect(s.today, DateTime(2026, 11, 1));
      expect(s.week.planned, isTrue);
      expect(s.week.entries, hasLength(3));
      expect(s.week.remaining, 1);
      expect(s.atRisk.single.name, 'Legs');
      expect(s.needsWorkoutToday, isTrue);
      expect(s.events.first.kind, 'freeze_used');
      expect(s.events.last.tier, StreakTier.silver);
      expect(s.ranks.single.gymName, 'Summit Strength Collective');
    });

    test('a weekly target that needs every day left is at risk', () {
      final j = _statusJson()
        ..['at_risk'] = []
        ..['today'] = '2026-10-31' // Saturday: two days left
        ..['week_remaining'] = 2
        ..['week'] = {'start': '2026-10-26', 'planned': false, 'target': 3, 'required': 3, 'done': 1, 'entries': []};
      final s = StreakStatus.fromJson(j);
      expect(s.week.remaining, 2);
      expect(s.needsWorkoutToday, isTrue);
      expect(StreakStatus.fromJson(j..['week_remaining'] = 1).needsWorkoutToday, isFalse);
    });

    test('a failure surfaces the API error', () async {
      backend.on('GET /streaks', ok({'error': 'tz must be an IANA zone'}, 400));
      await expectLater(
        api.getStreak(_token, tz: 'Mars/Base'),
        throwsA(predicate((e) => '$e'.contains('IANA'))),
      );
    });
  });

  group('getGymBoard', () {
    test('asks for the board kind and parses entries and my row', () async {
      backend.on(
        'GET /streaks/boards/g1',
        ok({
          'gym': {'id': 'g1', 'name': 'Summit', 'logo': null},
          'board': 'check_ins',
          'since': '2026-10-02T15:00:00.000Z',
          'total': 2,
          'entries': [
            {
              'rank': 1,
              'value': 12,
              'user': {'id': 'u1', 'username': 'maya', 'name': 'Maya', 'last_name': 'Flores', 'avatar_url': null, 'streak_tier': 'gold'},
            },
            {
              'rank': 2,
              'value': 10,
              'user': {'id': 'u2', 'username': 'ethan', 'name': 'Ethan', 'last_name': 'Brooks', 'avatar_url': null, 'streak_tier': null},
            },
          ],
          'me': {
            'rank': 2,
            'value': 10,
            'gap': 3,
            'user': {'id': 'u2', 'username': 'ethan', 'name': 'Ethan', 'last_name': 'Brooks'},
          },
        }),
      );
      final b = await api.getGymBoard(_token, 'g1', GymBoardKind.checkIns, tz: 'Europe/Belgrade');
      expect(backend.only.url.queryParameters['board'], 'check_ins');
      expect(b.kind, GymBoardKind.checkIns);
      expect(b.entries.first.user?.streakTier, StreakTier.gold);
      expect(b.me?.gap, 3);
      expect(b.me?.rank, 2);
    });
  });

  group('StreakUpdate', () {
    test('reads how a finished workout moved the streak', () {
      final session = TrainingSession.fromJson({
        'id': 's1',
        'user_id': 'u-ethan',
        'started_at': '2026-11-01T10:00:00.000Z',
        'ended_at': '2026-11-01T11:00:00.000Z',
        'created_at': '2026-11-01T10:00:00.000Z',
        'updated_at': '2026-11-01T11:00:00.000Z',
        'set_logs': [],
        'streak': {
          'previous': 49,
          'current': 50,
          'best': 50,
          'freezes': 2,
          'tier': 'silver',
          'previous_tier': 'bronze',
          'ranks': [
            {'gym_id': 'g1', 'gym_name': 'Summit', 'rank': 2, 'total': 9, 'value': 50, 'previous_rank': 4},
          ],
        },
      });
      final u = session.streak!;
      expect(u.grew, isTrue);
      expect(u.newTier, StreakTier.silver);
      expect(u.milestone, isTrue);
      expect(u.bestClimb?.climbed, 2);
    });

    test('is absent on plain session responses', () {
      final session = TrainingSession.fromJson({
        'id': 's1',
        'user_id': 'u',
        'started_at': '2026-11-01T10:00:00.000Z',
        'created_at': '2026-11-01T10:00:00.000Z',
        'updated_at': '2026-11-01T10:00:00.000Z',
      });
      expect(session.streak, isNull);
    });
  });
}
