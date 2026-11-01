import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/services/api_service.dart';
import 'package:gym_bro_mobile/services/overload_history.dart';

import '../helpers/fake_backend.dart';

const _token = 'tok-123';

// Shape captured from the local stack (GET /training-sessions/last-sets as liam).
List<Map<String, dynamic>> _rows() => [
      {
        'exercise_id': 'ex-bench',
        'session_id': 'sess-1',
        'started_at': '2026-10-29T16:56:00.000Z',
        'sets': [
          {'weight_kg': 106.25, 'reps': 7, 'rep_type': 'count', 'side': 'both'},
          {'weight_kg': '105', 'reps': 8, 'rep_type': 'count', 'side': 'both'},
        ],
      },
    ];

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('getLastSets', () {
    test('sends the ids, client and cutoff; parses the rows', () async {
      backend.on('GET /training-sessions/last-sets', ok(_rows()));
      final rows = await api.getLastSets(
        _token,
        ['ex-bench', 'ex-row', 'ex-bench'],
        userId: 'u-client',
        before: DateTime.utc(2026, 10, 30, 9),
      );
      final req = backend.only;
      expect(req.headers['Authorization'], 'Bearer $_token');
      expect(req.url.queryParameters['exercise_ids'], 'ex-bench,ex-row');
      expect(req.url.queryParameters['user_id'], 'u-client');
      expect(req.url.queryParameters['before'], '2026-10-30T09:00:00.000Z');
      expect(rows.single.exerciseId, 'ex-bench');
      expect(rows.single.sets.map((s) => s.weightKg), [106.25, 105]);
    });

    test('no ids → no request', () async {
      expect(await api.getLastSets(_token, const []), isEmpty);
      expect(backend.requests, isEmpty);
    });

    test('errors surface as exceptions', () async {
      backend.on('GET /training-sessions/last-sets', err(403, 'Forbidden'));
      expect(api.getLastSets(_token, ['ex']), throwsA(isA<Exception>()));
    });
  });

  group('OverloadHistory', () {
    test('batches missing ids, caches, and notifies', () async {
      backend.on('GET /training-sessions/last-sets', ok(_rows()));
      final history = OverloadHistory(api: api, token: () async => _token);
      var notified = 0;
      history.addListener(() => notified++);
      await history.load(['ex-bench', 'ex-row', null]);
      await history.load(['ex-bench', 'ex-row']);
      expect(backend.requests, hasLength(1));
      expect(history['ex-bench']?.sessionId, 'sess-1');
      expect(history['ex-row'], isNull);
      expect(notified, 1);
    });

    test('fails soft and can ask again later', () async {
      backend.on('GET /training-sessions/last-sets', err(500, 'boom'));
      final history = OverloadHistory(api: api, token: () async => _token);
      await history.load(['ex-bench']);
      expect(history['ex-bench'], isNull);
      backend.on('GET /training-sessions/last-sets', ok(_rows()));
      await history.load(['ex-bench']);
      expect(history['ex-bench'], isNotNull);
    });
  });
}
