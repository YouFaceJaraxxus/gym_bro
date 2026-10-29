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

// Shape captured from the local stack (GET /shifts?mine=true as elena).
Map<String, dynamic> _shiftJson({String id = 'sh1', String? note = 'Floor coaching'}) => {
      'id': id,
      'gym_id': 'g1',
      'user_id': 'u-elena',
      'starts_at': '2026-10-30T10:00:00.000Z',
      'ends_at': '2026-10-30T16:00:00.000Z',
      'note': note,
      'created_by': 'u-marcus',
      'created_at': '2026-10-21T14:00:00.000Z',
      'gym_name': 'Ironclad Fitness',
      'name': 'Elena',
      'last_name': 'Vasquez',
      'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=elenavasquez&size=256',
      'user_name': 'Elena Vasquez',
    };

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('getGymShifts', () {
    test('GETs /shifts?gym_id= and parses every field (times to local)', () async {
      backend.on(
        'GET /shifts',
        ok([
          _shiftJson(),
          {
            ..._shiftJson(id: 'sh2', note: null),
            'gym_name': null,
            'name': null,
            'last_name': null,
            'avatar_url': null,
          },
        ]),
      );

      final shifts = await api.getGymShifts(_token, 'g1');

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/shifts');
      expect(req.url.queryParameters, {'gym_id': 'g1'});
      _expectHeaders(req);

      final s = shifts[0];
      expect(s.id, 'sh1');
      expect(s.gymId, 'g1');
      expect(s.userId, 'u-elena');
      expect(s.startsAt, DateTime.utc(2026, 10, 30, 10).toLocal());
      expect(s.startsAt.isUtc, isFalse);
      expect(s.endsAt, DateTime.utc(2026, 10, 30, 16).toLocal());
      expect(s.duration, const Duration(hours: 6));
      expect(s.note, 'Floor coaching');
      expect(s.gymName, 'Ironclad Fitness');
      expect(s.name, 'Elena');
      expect(s.lastName, 'Vasquez');
      expect(s.fullName, 'Elena Vasquez');
      expect(s.avatarUrl, 'https://api.dicebear.com/9.x/avataaars/png?seed=elenavasquez&size=256');

      final t = shifts[1];
      expect(t.note, isNull);
      expect(t.gymName, '');
      expect(t.name, '');
      expect(t.lastName, '');
      expect(t.avatarUrl, isNull);
    });

    test('sends from/to as UTC ISO-8601', () async {
      backend.on('GET /shifts', ok([]));
      final from = DateTime(2026, 10, 27, 0, 0);
      final to = DateTime(2026, 11, 3, 23, 59);

      await api.getGymShifts(_token, 'g1', from: from, to: to);
      await api.getGymShifts(_token, 'g1', from: DateTime.utc(2026, 10, 27, 6, 30));

      final q = backend.requests[0].url.queryParameters;
      expect(q, {
        'gym_id': 'g1',
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      });
      expect(q['from'], endsWith('Z'));
      expect(DateTime.parse(q['from']!).isAtSameMomentAs(from), isTrue);
      expect(backend.requests[1].url.queryParameters, {'gym_id': 'g1', 'from': '2026-10-27T06:30:00.000Z'});
    });

    test('403 surfaces the message', () async {
      backend.on('GET /shifts', err(403, 'Forbidden'));
      await expectLater(api.getGymShifts(_token, 'g1'), _throwsMessage('Forbidden'));
    });

    test('a non-JSON error body still throws a readable error', () async {
      backend.on('GET /shifts', ok('<html>502</html>', 502));
      await expectLater(api.getGymShifts(_token, 'g1'), _throwsMessage('Request failed (502)'));
    });
  });

  group('getMyShifts', () {
    test('GETs /shifts?mine=true; from/to only when given', () async {
      backend.on('GET /shifts', ok([_shiftJson()]));

      final shifts = await api.getMyShifts(_token);
      final from = DateTime(2026, 11, 1);
      await api.getMyShifts(_token, from: from, to: DateTime.utc(2026, 11, 30, 23));

      expect(shifts.single.id, 'sh1');
      expect(backend.requests[0].method, 'GET');
      _expectHeaders(backend.requests[0]);
      expect(backend.requests[0].url.queryParameters, {'mine': 'true'});
      expect(backend.requests[1].url.queryParameters, {
        'mine': 'true',
        'from': from.toUtc().toIso8601String(),
        'to': '2026-11-30T23:00:00.000Z',
      });
    });
  });

  group('getShiftStaff', () {
    test('GETs /shifts/staff?gym_id= and parses can_manage and staff', () async {
      backend.on(
        'GET /shifts/staff',
        ok({
          'can_manage': true,
          'staff': [
            {
              'user_id': 'u-aisha',
              'name': 'Aisha',
              'last_name': 'Mohammed',
              'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=aishamohammed&size=256',
              'roles': ['employee_trainer'],
            },
            {
              'user_id': 'u-priya',
              'name': 'Priya',
              'last_name': 'Nair',
              'avatar_url': null,
              'roles': ['employee', 'trainer'],
            },
          ],
        }),
      );

      final s = await api.getShiftStaff(_token, 'g1');

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/shifts/staff');
      expect(req.url.queryParameters, {'gym_id': 'g1'});
      _expectHeaders(req);

      expect(s.canManage, isTrue);
      expect(s.staff, hasLength(2));
      expect(s.staff[0].userId, 'u-aisha');
      expect(s.staff[0].name, 'Aisha');
      expect(s.staff[0].lastName, 'Mohammed');
      expect(s.staff[0].fullName, 'Aisha Mohammed');
      expect(s.staff[0].avatarUrl, startsWith('https://api.dicebear.com/'));
      expect(s.staff[0].roles, ['employee_trainer']);
      expect(s.staff[1].avatarUrl, isNull);
      expect(s.staff[1].roles, ['employee', 'trainer']);
    });

    test('a viewer (can_manage false) parses', () async {
      backend.on('GET /shifts/staff', ok({'can_manage': false, 'staff': []}));
      final s = await api.getShiftStaff(_token, 'g1');
      expect(s.canManage, isFalse);
      expect(s.staff, isEmpty);
    });
  });

  group('createShift', () {
    test('POSTs the data as-is and parses the 201 row', () async {
      backend.on('POST /shifts', ok(_shiftJson(), 201));
      final data = {
        'gym_id': 'g1',
        'user_id': 'u-elena',
        'starts_at': '2026-10-30T10:00:00.000Z',
        'ends_at': '2026-10-30T16:00:00.000Z',
        'note': 'Floor coaching',
      };

      final s = await api.createShift(_token, data);

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/shifts');
      _expectHeaders(req);
      expect(bodyOf(req), equals(data));
      expect(s.id, 'sh1');
      expect(s.gymName, 'Ironclad Fitness');
    });

    test('409 (overlap) surfaces the message', () async {
      backend.on('POST /shifts', err(409, 'This shift overlaps another shift for the same person'));
      await expectLater(
        api.createShift(_token, {'gym_id': 'g1'}),
        _throwsMessage('This shift overlaps another shift'),
      );
    });
  });

  group('updateShift', () {
    test('PUTs the changes (an explicit null note clears it)', () async {
      backend.on('PUT /shifts/sh1', ok(_shiftJson(note: null)));

      final s = await api.updateShift(_token, 'sh1', {'ends_at': '2026-10-30T17:00:00.000Z', 'note': null});

      final req = backend.only;
      expect(req.method, 'PUT');
      expect(pathOf(req), '/shifts/sh1');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'ends_at': '2026-10-30T17:00:00.000Z', 'note': null}));
      expect((bodyOf(req) as Map).containsKey('note'), isTrue);
      expect(s.note, isNull);
    });

    test('400 surfaces the message', () async {
      backend.on('PUT /shifts/sh1', err(400, 'ends_at must be after starts_at'));
      await expectLater(api.updateShift(_token, 'sh1', {}), _throwsMessage('ends_at must be after starts_at'));
    });
  });

  group('deleteShift', () {
    test('DELETEs /shifts/:id; 204 is fine', () async {
      backend.on('DELETE /shifts/sh1', ok('', 204));

      await api.deleteShift(_token, 'sh1');

      final req = backend.only;
      expect(req.method, 'DELETE');
      expect(pathOf(req), '/shifts/sh1');
      _expectHeaders(req);
    });

    test('404 surfaces the message', () async {
      backend.on('DELETE /shifts/sh1', err(404, 'Shift not found'));
      await expectLater(api.deleteShift(_token, 'sh1'), _throwsMessage('Shift not found'));
    });
  });
}
