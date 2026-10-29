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

// Shapes captured from the local stack (GET /routine-assignments as elena).
Map<String, dynamic> _assignmentJson({String? note, String? endDate = '2026-10-22'}) => {
      'id': 'ra1',
      'routine_id': 'r1',
      'user_id': 'u-liam',
      'assigned_by_id': 'u-elena',
      'start_date': '2026-09-25',
      'end_date': endDate,
      'note': note,
      'created_at': '2026-09-24T21:10:00.000Z',
      'routine_name': 'Full Body 3x/Week',
      'routine_is_public': true,
      'routine_schedule_label': '4-Week Program',
      'user_name': "Liam O'Connor",
      'assigned_by_name': 'Elena Vasquez',
    };

// fetchComments() in training-sessions/index.ts.
Map<String, dynamic> _commentJson({String body = 'Great depth on those squats', String? updatedAt}) => {
      'id': 'c1',
      'session_id': 's1',
      'author_id': 'u-elena',
      'author_name': 'Elena Vasquez',
      'author_avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=elenavasquez&size=256',
      'body': body,
      'created_at': '2026-10-26T19:30:00.000Z',
      'updated_at': updatedAt ?? '2026-10-26T19:30:00.000Z',
    };

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('getRoutineAssignments', () {
    test('GETs /routine-assignments without a query and parses every field', () async {
      backend.on(
        'GET /routine-assignments',
        ok([
          _assignmentJson(),
          {
            ..._assignmentJson(note: 'Focus on form', endDate: null),
            'id': 'ra2',
            'assigned_by_id': null,
            'routine_is_public': null,
            'routine_schedule_label': null,
            'user_name': null,
            'assigned_by_name': null,
          },
        ]),
      );

      final list = await api.getRoutineAssignments(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/routine-assignments');
      expect(req.url.hasQuery, isFalse);
      _expectHeaders(req);

      expect(list, hasLength(2));
      final a = list[0];
      expect(a.id, 'ra1');
      expect(a.routineId, 'r1');
      expect(a.userId, 'u-liam');
      expect(a.assignedById, 'u-elena');
      // DATE columns become local calendar dates.
      expect(a.startDate, DateTime(2026, 9, 25));
      expect(a.endDate, DateTime(2026, 10, 22));
      expect(a.note, isNull);
      expect(a.createdAt, DateTime.utc(2026, 9, 24, 21, 10));
      expect(a.routineName, 'Full Body 3x/Week');
      expect(a.routineIsPublic, isTrue);
      expect(a.routineScheduleLabel, '4-Week Program');
      expect(a.userName, "Liam O'Connor");
      expect(a.assignedByName, 'Elena Vasquez');
      expect(a.isSelfAssigned, isFalse);

      final b = list[1];
      expect(b.note, 'Focus on form');
      expect(b.endDate, isNull);
      expect(b.assignedById, isNull);
      expect(b.routineIsPublic, isNull);
      expect(b.assignedByName, isNull);
    });

    test('passes every filter that is set, and only those', () async {
      backend.on('GET /routine-assignments', ok([]));

      await api.getRoutineAssignments(_token, userId: 'u1', routineId: 'r1', assignedById: 'u2');
      await api.getRoutineAssignments(_token, routineId: 'r1');

      expect(backend.requests[0].url.queryParameters, {'user_id': 'u1', 'routine_id': 'r1', 'assigned_by_id': 'u2'});
      expect(backend.requests[1].url.queryParameters, {'routine_id': 'r1'});
    });

    test('surfaces the API error message', () async {
      backend.on('GET /routine-assignments', err(403, 'Forbidden'));
      await expectLater(api.getRoutineAssignments(_token), _throwsMessage('Forbidden'));
    });

    test('a non-JSON error body still throws a readable error', () async {
      backend.on('GET /routine-assignments', ok('upstream timeout', 504));
      await expectLater(api.getRoutineAssignments(_token), _throwsMessage('Request failed (504)'));
    });
  });

  group('createRoutineAssignment', () {
    test('POSTs the data as-is and parses the 201 row', () async {
      backend.on('POST /routine-assignments', ok(_assignmentJson(note: 'Start light'), 201));

      final data = {
        'routine_id': 'r1',
        'user_id': 'u-liam',
        'start_date': '2026-09-25',
        'end_date': '2026-10-22',
        'note': 'Start light',
      };
      final a = await api.createRoutineAssignment(_token, data);

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/routine-assignments');
      _expectHeaders(req);
      expect(bodyOf(req), equals(data));
      expect(a.id, 'ra1');
      expect(a.note, 'Start light');
      expect(a.startDate, DateTime(2026, 9, 25));
    });

    test('400 surfaces the message', () async {
      backend.on('POST /routine-assignments', err(400, 'start_date must be YYYY-MM-DD'));
      await expectLater(
        api.createRoutineAssignment(_token, {'routine_id': 'r1', 'user_id': 'u1', 'start_date': '25/09'}),
        _throwsMessage('start_date must be YYYY-MM-DD'),
      );
    });
  });

  group('deleteRoutineAssignment', () {
    test('DELETEs /routine-assignments/:id; 204 with an empty body is fine', () async {
      backend.on('DELETE /routine-assignments/ra1', ok('', 204));

      await api.deleteRoutineAssignment(_token, 'ra1');

      final req = backend.only;
      expect(req.method, 'DELETE');
      expect(pathOf(req), '/routine-assignments/ra1');
      _expectHeaders(req);
      expect(req.body, isEmpty);
    });

    test('404 surfaces the message', () async {
      backend.on('DELETE /routine-assignments/x', err(404, 'Routine assignment not found'));
      await expectLater(api.deleteRoutineAssignment(_token, 'x'), _throwsMessage('Routine assignment not found'));
    });
  });

  group('getSessionComments', () {
    test('GETs /training-sessions/:id/comments and parses every field', () async {
      backend.on(
        'GET /training-sessions/s1/comments',
        ok([
          _commentJson(),
          // Author deleted their account: author fields null.
          {
            ..._commentJson(body: 'Thanks!', updatedAt: '2026-10-26T20:00:00.000Z'),
            'id': 'c2',
            'author_id': null,
            'author_name': null,
            'author_avatar_url': null,
          },
        ]),
      );

      final list = await api.getSessionComments(_token, 's1');

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/training-sessions/s1/comments');
      _expectHeaders(req);

      final c = list[0];
      expect(c.id, 'c1');
      expect(c.sessionId, 's1');
      expect(c.authorId, 'u-elena');
      expect(c.authorName, 'Elena Vasquez');
      expect(c.authorAvatarUrl, 'https://api.dicebear.com/9.x/avataaars/png?seed=elenavasquez&size=256');
      expect(c.body, 'Great depth on those squats');
      expect(c.createdAt, DateTime.utc(2026, 10, 26, 19, 30));
      expect(c.updatedAt, DateTime.utc(2026, 10, 26, 19, 30));
      expect(c.isEdited, isFalse);

      final d = list[1];
      expect(d.authorId, isNull);
      expect(d.authorName, isNull);
      expect(d.authorAvatarUrl, isNull);
      expect(d.isEdited, isTrue);
    });

    test('404 surfaces the message', () async {
      backend.on('GET /training-sessions/x/comments', err(404, 'Session not found'));
      await expectLater(api.getSessionComments(_token, 'x'), _throwsMessage('Session not found'));
    });
  });

  group('addSessionComment', () {
    test('POSTs {body} to /training-sessions/:id/comments', () async {
      backend.on('POST /training-sessions/s1/comments', ok(_commentJson(), 201));

      final c = await api.addSessionComment(_token, 's1', 'Great depth on those squats');

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/training-sessions/s1/comments');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'body': 'Great depth on those squats'}));
      expect(c.id, 'c1');
      expect(c.body, 'Great depth on those squats');
    });

    test('400 surfaces the message', () async {
      backend.on('POST /training-sessions/s1/comments', err(400, 'body is required (max 4000 characters)'));
      await expectLater(api.addSessionComment(_token, 's1', ''), _throwsMessage('body is required'));
    });
  });

  group('updateSessionComment', () {
    test('PUTs {body} to /training-sessions/comments/:commentId', () async {
      backend.on(
        'PUT /training-sessions/comments/c1',
        ok(_commentJson(body: 'Edited', updatedAt: '2026-10-26T21:00:00.000Z')),
      );

      final c = await api.updateSessionComment(_token, 'c1', 'Edited');

      final req = backend.only;
      expect(req.method, 'PUT');
      expect(pathOf(req), '/training-sessions/comments/c1');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'body': 'Edited'}));
      expect(c.body, 'Edited');
      expect(c.updatedAt, DateTime.utc(2026, 10, 26, 21));
      expect(c.isEdited, isTrue);
    });

    test('403 surfaces the message', () async {
      backend.on('PUT /training-sessions/comments/c1', err(403, 'Forbidden'));
      await expectLater(api.updateSessionComment(_token, 'c1', 'x'), _throwsMessage('Forbidden'));
    });
  });

  group('deleteSessionComment', () {
    test('DELETEs /training-sessions/comments/:commentId; 204 is fine', () async {
      backend.on('DELETE /training-sessions/comments/c1', ok('', 204));

      await api.deleteSessionComment(_token, 'c1');

      final req = backend.only;
      expect(req.method, 'DELETE');
      expect(pathOf(req), '/training-sessions/comments/c1');
      _expectHeaders(req);
    });

    test('404 surfaces the message', () async {
      backend.on('DELETE /training-sessions/comments/c1', err(404, 'Comment not found'));
      await expectLater(api.deleteSessionComment(_token, 'c1'), _throwsMessage('Comment not found'));
    });
  });
}
