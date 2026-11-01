import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/water.dart';
import 'package:gym_bro_mobile/services/api_service.dart';

import '../helpers/fake_backend.dart';

const _token = 'tok-123';

// Shape captured from the local stack (GET /water-logs/today as liam).
Map<String, dynamic> _todayJson() => {
      'date': '2026-11-01',
      'timezone': 'Europe/Belgrade',
      'total_ml': '1580', // counts may arrive as strings
      'goal_ml': 3300,
      'base_goal_ml': 2800,
      'workout_bonus_ml': 500,
      'auto_goal': true,
      'weight_kg': '80.4',
      'worked_out': true,
      'entries': [
        {'id': 'w2', 'ml': 330, 'logged_at': '2026-11-01T13:05:00.000Z'},
        {'id': 'w1', 'ml': '250', 'logged_at': '2026-11-01T08:30:00.000Z'},
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

  group('getWaterToday', () {
    test('sends the device zone and parses every field', () async {
      backend.on('GET /water-logs/today', ok(_todayJson()));
      final day = await api.getWaterToday(_token, tz: 'Europe/Belgrade');

      final req = backend.only;
      expect(req.headers['Authorization'], 'Bearer $_token');
      expect(req.url.queryParameters['tz'], 'Europe/Belgrade');

      expect(day.date, DateTime(2026, 11, 1));
      expect(day.totalMl, 1580);
      expect(day.goalMl, 3300);
      expect(day.baseGoalMl, 2800);
      expect(day.workoutBonusMl, 500);
      expect(day.autoGoal, isTrue);
      expect(day.weightKg, 80.4);
      expect(day.workedOut, isTrue);
      expect(day.entries.map((e) => e.ml), [330, 250]);
      expect(day.entries.first.loggedAt.isUtc, isFalse);
      expect(day.percent, 48);
      expect(day.remainingMl, 1720);
      expect(day.reached, isFalse);
    });

    test('works without a zone', () async {
      backend.on('GET /water-logs/today', ok(_todayJson()));
      await api.getWaterToday(_token);
      expect(backend.only.url.hasQuery, isFalse);
    });

    test('a failure surfaces the API error', () async {
      backend.on('GET /water-logs/today', ok({'error': 'tz must be an IANA zone'}, 400));
      await expectLater(
        api.getWaterToday(_token, tz: 'Mars/Base'),
        throwsA(predicate((e) => '$e'.contains('IANA'))),
      );
    });
  });

  group('getWaterHistory', () {
    test('asks for the days and parses each one', () async {
      backend.on(
        'GET /water-logs/history',
        ok({
          'from': '2026-10-30',
          'to': '2026-11-01',
          'timezone': 'Europe/Belgrade',
          'base_goal_ml': 2800,
          'auto_goal': true,
          'days': [
            {'date': '2026-10-30', 'total_ml': 3000, 'goal_ml': 2800, 'worked_out': false},
            {'date': '2026-10-31', 'total_ml': '3400', 'goal_ml': 3300, 'worked_out': true},
            {'date': '2026-11-01', 'total_ml': 900, 'goal_ml': 2800, 'worked_out': false},
          ],
        }),
      );
      final h = await api.getWaterHistory(_token, days: 3, tz: 'Europe/Belgrade');
      expect(backend.only.url.queryParameters, {'days': '3', 'tz': 'Europe/Belgrade'});
      expect(h.baseGoalMl, 2800);
      expect(h.days, hasLength(3));
      expect(h.days[1].date, DateTime(2026, 10, 31));
      expect(h.days[1].workedOut, isTrue);
      expect(h.days[1].reached, isTrue);
      expect(h.daysReached, 2);
      expect(h.streak, 2); // today isn't met yet, so it doesn't break the run
      expect(h.averageMl, 2433);
      expect(h.peakMl, 3400);
    });
  });

  group('addWater / deleteWater', () {
    test('posts the amount and bumps waterChanges', () async {
      backend.on(
        'POST /water-logs',
        ok({
          'entry': {'id': 'w3', 'ml': 500, 'logged_at': '2026-11-01T15:00:00.000Z'},
          'today': _todayJson()..['total_ml'] = 2080,
        }, 201),
      );
      final before = waterChanges.value;
      final added = await api.addWater(_token, 500, tz: 'Europe/Belgrade');

      final req = backend.only;
      expect(bodyOf(req), {'ml': 500});
      expect(req.url.queryParameters['tz'], 'Europe/Belgrade');
      expect(added.entry.id, 'w3');
      expect(added.today.totalMl, 2080);
      expect(waterChanges.value, before + 1);
    });

    test('sends logged_at in UTC when backdating', () async {
      backend.on(
        'POST /water-logs',
        ok({
          'entry': {'id': 'w4', 'ml': 200, 'logged_at': '2026-10-31T10:00:00.000Z'},
          'today': _todayJson(),
        }, 201),
      );
      await api.addWater(_token, 200, loggedAt: DateTime.utc(2026, 10, 31, 10));
      expect(bodyOf(backend.only), {'ml': 200, 'logged_at': '2026-10-31T10:00:00.000Z'});
    });

    test('a rejected amount throws and leaves waterChanges alone', () async {
      backend.on('POST /water-logs', err(400, 'ml must be between 1 and 3000'));
      final before = waterChanges.value;
      await expectLater(api.addWater(_token, 5000), throwsA(predicate((e) => '$e'.contains('3000'))));
      expect(waterChanges.value, before);
    });

    test('deletes by id and returns today', () async {
      backend.on('DELETE /water-logs/w2', ok({'today': _todayJson()..['total_ml'] = 1250}));
      final before = waterChanges.value;
      final day = await api.deleteWater(_token, 'w2', tz: 'Europe/Belgrade');
      expect(backend.only.method, 'DELETE');
      expect(day.totalMl, 1250);
      expect(waterChanges.value, before + 1);
    });

    test("someone else's entry is not found", () async {
      backend.on('DELETE /water-logs/x', err(404, 'Entry not found'));
      await expectLater(api.deleteWater(_token, 'x'), throwsA(predicate((e) => '$e'.contains('not found'))));
    });
  });

  group('WaterAdded', () {
    test('parses the created entry', () {
      final a = WaterAdded.fromJson({
        'entry': {'id': 'w9', 'ml': '330', 'logged_at': '2026-11-01T09:00:00Z'},
        'today': _todayJson(),
      });
      expect(a.entry.ml, 330);
      expect(a.today.entries, hasLength(2));
    });
  });
}
