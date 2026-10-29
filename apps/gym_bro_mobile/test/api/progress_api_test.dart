import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/services/api_service.dart';
import 'package:http/http.dart' as http;

import '../helpers/fake_backend.dart';

const _token = 'tok-123';

void _expectHeaders(http.Request req) {
  expect(req.headers['Authorization'], 'Bearer $_token');
  expect(req.headers['Content-Type'], startsWith('application/json'));
}

Matcher _throwsMessage(String m) => throwsA(predicate((e) => e is Exception && '$e'.contains(m)));

// Shapes captured from the local stack (GET /progress/*, /body-measurements as liam).
Map<String, dynamic> _measurementJson({
  String id = 'bm1',
  Object? weight = 75.2,
  Object? bodyFat,
  String? note,
  String measuredOn = '2026-08-11',
}) =>
    {
      'id': id,
      'user_id': 'u-liam',
      'measured_on': measuredOn,
      'weight_kg': weight,
      'body_fat_pct': bodyFat,
      'note': note,
      'created_at': '2026-08-11T11:49:00.000Z',
    };

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('getProgressSummary', () {
    test('GETs /progress/summary without a query for me and parses every field', () async {
      backend.on(
        'GET /progress/summary',
        ok({
          'user_id': 'u-liam',
          'sessions_7d': 2,
          'sessions_30d': '8', // count(*) can arrive as a string
          'sessions_total': 20,
          'last_session_at': '2026-10-26T19:05:00.000Z',
          'volume_30d_kg': '61765.50',
          'streak_weeks': 11,
          'trained_this_week': true,
          'recent_prs': [
            {
              'exercise_id': 'ex-dl',
              'exercise_name': 'Conventional Deadlift',
              'session_id': 's1',
              'date': '2026-10-26T19:05:00.000Z',
              'e1rm': 134.12,
              'previous_e1rm': '129.83',
              'weight_kg': '108.75',
              'reps': 7,
            },
            {
              'exercise_id': 'ex-fp',
              'exercise_name': 'Face Pull',
              'session_id': 's1',
              'date': '2026-10-26T19:05:00.000Z',
              'e1rm': 30,
              'previous_e1rm': null,
              'weight_kg': null,
              'reps': '15',
            },
          ],
        }),
      );

      final s = await api.getProgressSummary(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/progress/summary');
      expect(req.url.hasQuery, isFalse);
      _expectHeaders(req);

      expect(s.userId, 'u-liam');
      expect(s.sessions7d, 2);
      expect(s.sessions30d, 8);
      expect(s.sessionsTotal, 20);
      expect(s.lastSessionAt, DateTime.utc(2026, 10, 26, 19, 5));
      expect(s.volume30dKg, 61765.5);
      expect(s.streakWeeks, 11);
      expect(s.trainedThisWeek, isTrue);
      expect(s.recentPrs, hasLength(2));
      final pr = s.recentPrs[0];
      expect(pr.exerciseId, 'ex-dl');
      expect(pr.exerciseName, 'Conventional Deadlift');
      expect(pr.sessionId, 's1');
      expect(pr.date, DateTime.utc(2026, 10, 26, 19, 5));
      expect(pr.e1rm, 134.12);
      expect(pr.previousE1rm, 129.83);
      expect(pr.weightKg, 108.75);
      expect(pr.reps, 7);
      expect(pr.gainKg, closeTo(4.29, 1e-9));
      final pr2 = s.recentPrs[1];
      expect(pr2.e1rm, 30.0);
      expect(pr2.previousE1rm, isNull);
      expect(pr2.weightKg, isNull);
      expect(pr2.reps, 15);
      expect(pr2.gainKg, isNull);
    });

    test('passes user_id for someone else', () async {
      backend.on('GET /progress/summary', ok({'user_id': 'u2'}));
      final s = await api.getProgressSummary(_token, userId: 'u2');
      expect(backend.only.url.queryParameters, {'user_id': 'u2'});
      expect(s.recentPrs, isEmpty);
      expect(s.lastSessionAt, isNull);
    });

    test('403 surfaces the message', () async {
      backend.on('GET /progress/summary', err(403, 'Forbidden'));
      await expectLater(api.getProgressSummary(_token, userId: 'u2'), _throwsMessage('Forbidden'));
    });

    test('a non-JSON error body still throws a readable error', () async {
      backend.on('GET /progress/summary', ok('Internal Server Error', 500));
      await expectLater(api.getProgressSummary(_token), _throwsMessage('Request failed (500)'));
    });
  });

  group('getExerciseProgressList', () {
    test('GETs /progress/exercises and parses rows, muscles and the trend', () async {
      backend.on(
        'GET /progress/exercises',
        ok([
          {
            'id': 'ex-dl',
            'name': 'Conventional Deadlift',
            'primary_muscles': ['hamstrings', 'glutes_maximus', 'back_lower'],
            'session_count': 4,
            'last_performed': '2026-10-26T19:05:00.000Z',
            'best_weight_kg': 108.75,
            'best_e1rm': '134.12',
            'trend': [118.75, '126.42', 129.83, 134.12],
          },
          {
            'id': 'ex-plank',
            'name': 'Plank',
            'primary_muscles': null,
            'session_count': '1',
            'last_performed': null,
            'best_weight_kg': null,
            'best_e1rm': null,
            'trend': [null],
          },
        ]),
      );

      final list = await api.getExerciseProgressList(_token, userId: 'u-liam');

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/progress/exercises');
      expect(req.url.queryParameters, {'user_id': 'u-liam'});
      _expectHeaders(req);

      final a = list[0];
      expect(a.id, 'ex-dl');
      expect(a.name, 'Conventional Deadlift');
      expect(a.primaryMuscles, ['hamstrings', 'glutes_maximus', 'back_lower']);
      expect(a.sessionCount, 4);
      expect(a.lastPerformed, DateTime.utc(2026, 10, 26, 19, 5));
      expect(a.bestWeightKg, 108.75);
      expect(a.bestE1rm, 134.12);
      expect(a.trend, [118.75, 126.42, 129.83, 134.12]);
      final b = list[1];
      expect(b.primaryMuscles, isEmpty);
      expect(b.sessionCount, 1);
      expect(b.lastPerformed, isNull);
      expect(b.bestWeightKg, isNull);
      expect(b.bestE1rm, isNull);
      expect(b.trend, isEmpty);
    });

    test('omits an empty user_id', () async {
      backend.on('GET /progress/exercises', ok([]));
      await api.getExerciseProgressList(_token, userId: '');
      expect(backend.only.url.hasQuery, isFalse);
    });
  });

  group('getExerciseProgress', () {
    test('GETs /progress/exercises/:id and parses series and PRs', () async {
      backend.on(
        'GET /progress/exercises/ex-dl',
        ok({
          'exercise': {
            'id': 'ex-dl',
            'name': 'Conventional Deadlift',
            'primary_muscles': ['hamstrings', 'glutes_maximus', 'back_lower'],
          },
          'series': [
            {
              'session_id': 's0',
              'date': '2026-08-27T10:00:00.000Z',
              'best_weight_kg': 95,
              'best_e1rm': 118.75,
              'volume_kg': '2617.5',
              'total_reps': 28,
            },
            {
              'session_id': 's1',
              'date': '2026-10-26T19:05:00.000Z',
              'best_weight_kg': null,
              'best_e1rm': null,
              'volume_kg': null,
              'total_reps': '29',
            },
          ],
          'prs': {
            'best_weight_kg': {'value': 108.75, 'session_id': 's1', 'date': '2026-10-26T19:05:00+00:00'},
            'best_e1rm': {'value': '134.12', 'session_id': 's1', 'date': '2026-10-26T19:05:00+00:00'},
            'best_volume_kg': null,
          },
        }),
      );

      final d = await api.getExerciseProgress(_token, 'ex-dl');

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/progress/exercises/ex-dl');
      expect(req.url.hasQuery, isFalse);
      _expectHeaders(req);

      expect(d.exerciseId, 'ex-dl');
      expect(d.exerciseName, 'Conventional Deadlift');
      expect(d.primaryMuscles, ['hamstrings', 'glutes_maximus', 'back_lower']);
      expect(d.series, hasLength(2));
      final p = d.series[0];
      expect(p.sessionId, 's0');
      expect(p.date, DateTime.utc(2026, 8, 27, 10));
      expect(p.bestWeightKg, 95.0);
      expect(p.bestE1rm, 118.75);
      expect(p.volumeKg, 2617.5);
      expect(p.totalReps, 28);
      final q = d.series[1];
      expect(q.bestWeightKg, isNull);
      expect(q.bestE1rm, isNull);
      expect(q.volumeKg, 0);
      expect(q.totalReps, 29);
      expect(d.bestWeight!.value, 108.75);
      expect(d.bestWeight!.sessionId, 's1');
      expect(d.bestWeight!.date, DateTime.utc(2026, 10, 26, 19, 5));
      expect(d.bestE1rm!.value, 134.12);
      expect(d.bestVolume, isNull);
    });

    test('sends user_id and from/to as UTC ISO-8601 (encoded)', () async {
      backend.on('GET /progress/exercises/ex-dl', ok({'exercise': {}, 'series': [], 'prs': {}}));
      final from = DateTime(2026, 8, 1);
      final to = DateTime(2026, 10, 31, 23, 59, 59);

      await api.getExerciseProgress(_token, 'ex-dl', userId: 'u2', from: from, to: to);

      final req = backend.only;
      expect(req.url.queryParameters, {
        'user_id': 'u2',
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      });
      expect(req.url.queryParameters['from'], endsWith('Z'));
      expect(req.url.query, contains('from=${Uri.encodeQueryComponent(from.toUtc().toIso8601String())}'));
    });

    test('404 surfaces the message', () async {
      backend.on('GET /progress/exercises/nope', err(404, 'Exercise not found'));
      await expectLater(api.getExerciseProgress(_token, 'nope'), _throwsMessage('Exercise not found'));
    });
  });

  group('getBodyMeasurements', () {
    test('GETs /body-measurements and parses rows (numeric strings, local dates)', () async {
      backend.on(
        'GET /body-measurements',
        ok([
          _measurementJson(),
          _measurementJson(id: 'bm2', weight: '76.80', bodyFat: '18.5', note: 'Morning', measuredOn: '2026-09-15'),
          _measurementJson(id: 'bm3', weight: null),
        ]),
      );

      final list = await api.getBodyMeasurements(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/body-measurements');
      expect(req.url.hasQuery, isFalse);
      _expectHeaders(req);

      expect(list, hasLength(3));
      final a = list[0];
      expect(a.id, 'bm1');
      expect(a.userId, 'u-liam');
      expect(a.measuredOn, DateTime(2026, 8, 11));
      expect(a.measuredOn.isUtc, isFalse);
      expect(a.weightKg, 75.2);
      expect(a.bodyFatPct, isNull);
      expect(a.note, isNull);
      expect(a.createdAt, DateTime.utc(2026, 8, 11, 11, 49));
      final b = list[1];
      expect(b.measuredOn, DateTime(2026, 9, 15));
      expect(b.weightKg, 76.8);
      expect(b.bodyFatPct, 18.5);
      expect(b.note, 'Morning');
      expect(list[2].weightKg, isNull);
    });

    test('sends from/to as YYYY-MM-DD local dates and user_id', () async {
      backend.on('GET /body-measurements', ok([]));

      await api.getBodyMeasurements(_token, userId: 'u2', from: DateTime(2026, 8, 1, 23, 30), to: DateTime(2026, 10, 5));

      expect(backend.only.url.queryParameters, {'user_id': 'u2', 'from': '2026-08-01', 'to': '2026-10-05'});
    });

    test('400 surfaces the message', () async {
      backend.on('GET /body-measurements', err(400, 'from/to must be YYYY-MM-DD'));
      await expectLater(api.getBodyMeasurements(_token), _throwsMessage('from/to must be YYYY-MM-DD'));
    });
  });

  group('createBodyMeasurement', () {
    test('POSTs the data as-is and parses the 201 row', () async {
      backend.on(
        'POST /body-measurements',
        ok(_measurementJson(id: 'bm9', weight: '77.10', bodyFat: '17.9', note: 'After holidays', measuredOn: '2026-10-27'),
            201),
      );
      final data = {'measured_on': '2026-10-27', 'weight_kg': 77.1, 'body_fat_pct': 17.9, 'note': 'After holidays'};

      final m = await api.createBodyMeasurement(_token, data);

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/body-measurements');
      _expectHeaders(req);
      expect(bodyOf(req), equals(data));
      expect(m.id, 'bm9');
      expect(m.measuredOn, DateTime(2026, 10, 27));
      expect(m.weightKg, 77.1);
      expect(m.bodyFatPct, 17.9);
      expect(m.note, 'After holidays');
    });

    test('400 surfaces the message', () async {
      backend.on('POST /body-measurements', err(400, 'weight_kg or body_fat_pct is required'));
      await expectLater(api.createBodyMeasurement(_token, {}), _throwsMessage('weight_kg or body_fat_pct is required'));
    });
  });

  group('updateBodyMeasurement', () {
    test('PUTs the changes to /body-measurements/:id', () async {
      backend.on('PUT /body-measurements/bm1', ok(_measurementJson(weight: '74.90')));

      final m = await api.updateBodyMeasurement(_token, 'bm1', {'weight_kg': 74.9, 'body_fat_pct': null});

      final req = backend.only;
      expect(req.method, 'PUT');
      expect(pathOf(req), '/body-measurements/bm1');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'weight_kg': 74.9, 'body_fat_pct': null}));
      expect(m.weightKg, 74.9);
    });

    test('400 surfaces the message', () async {
      backend.on('PUT /body-measurements/bm1', err(400, 'Nothing to update'));
      await expectLater(api.updateBodyMeasurement(_token, 'bm1', {}), _throwsMessage('Nothing to update'));
    });
  });

  group('deleteBodyMeasurement', () {
    test('DELETEs /body-measurements/:id; 204 is fine', () async {
      backend.on('DELETE /body-measurements/bm1', ok('', 204));

      await api.deleteBodyMeasurement(_token, 'bm1');

      final req = backend.only;
      expect(req.method, 'DELETE');
      expect(pathOf(req), '/body-measurements/bm1');
      _expectHeaders(req);
    });

    test('404 surfaces the message', () async {
      backend.on('DELETE /body-measurements/bm1', err(404, 'Measurement not found'));
      await expectLater(api.deleteBodyMeasurement(_token, 'bm1'), _throwsMessage('Measurement not found'));
    });
  });
}
