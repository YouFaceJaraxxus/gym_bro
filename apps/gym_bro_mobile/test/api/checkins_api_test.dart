import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/check_in.dart';
import 'package:gym_bro_mobile/services/api_service.dart';
import 'package:http/http.dart' as http;

import '../helpers/fake_backend.dart';

const _token = 'tok-123';
const _gym = 'ff453a60-28ca-4cdd-a919-c6ecd344ab65';

void _expectHeaders(http.Request req, {bool json = true}) {
  expect(req.headers['Authorization'], 'Bearer $_token');
  if (json) expect(req.headers['Content-Type'], startsWith('application/json'));
}

/// What every stats / day-list call appends: minutes east of UTC.
String get _tz => '${DateTime.now().timeZoneOffset.inMinutes}';

TypeMatcher<CheckInException> _checkInError(String message, {String? code, required int status}) =>
    isA<CheckInException>()
    .having((e) => e.message, 'message', message)
    .having((e) => e.code, 'code', code)
    .having((e) => e.statusCode, 'statusCode', status);

// Shapes captured from the local stack (GET /check-ins?mine=true, ?gym_id=, POST response).
Map<String, dynamic> _checkInRow({Map<String, dynamic> extra = const {}}) => {
      'id': 'ci1',
      'gym_id': _gym,
      'user_id': 'u-liam',
      'checked_in_at': '2026-10-11T21:25:00.000Z',
      'checked_in_by': 'u-staff',
      'method': 'qr',
      ...extra,
    };

Map<String, dynamic> _resultJson({
  bool duplicate = false,
  Object? membership = const {'is_active': true, 'to_date': '2026-12-31', 'type_name': 'Monthly Unlimited'},
  String? warning,
  String method = 'qr',
}) =>
    {
      'check_in': _checkInRow(extra: {'method': method}),
      'duplicate': duplicate,
      'member': {
        'id': 'u-liam',
        'name': 'Liam',
        'last_name': "O'Connor",
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=liamoconnor&size=256',
      },
      'membership': membership,
      'warning': warning,
    };

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('getCheckInGyms', () {
    test('GETs /check-ins/gyms and parses member and staff gyms', () async {
      backend.on(
        'GET /check-ins/gyms',
        ok([
          {
            'gym_id': _gym,
            'name': 'Ironclad Fitness',
            'logo': 'https://picsum.photos/seed/gym-logo/800/400',
            'is_member': true,
            'is_staff': false,
          },
          {'gym_id': 'g2', 'name': 'Phoenix Gym', 'logo': null, 'is_member': false, 'is_staff': true},
        ]),
      );

      final gyms = await api.getCheckInGyms(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/check-ins/gyms');
      expect(req.url.hasQuery, isFalse);
      _expectHeaders(req);
      expect(gyms, hasLength(2));
      expect(gyms[0].gymId, _gym);
      expect(gyms[0].name, 'Ironclad Fitness');
      expect(gyms[0].logo, 'https://picsum.photos/seed/gym-logo/800/400');
      expect(gyms[0].isMember, isTrue);
      expect(gyms[0].isStaff, isFalse);
      expect(gyms[1].logo, isNull);
      expect(gyms[1].isMember, isFalse);
      expect(gyms[1].isStaff, isTrue);
    });

    test('503 not_configured throws CheckInException with code and status', () async {
      backend.on('GET /check-ins/gyms', err(503, 'Check-ins are not configured on this server', code: 'not_configured'));
      await expectLater(
        api.getCheckInGyms(_token),
        throwsA(_checkInError('Check-ins are not configured on this server', code: 'not_configured', status: 503)
            .having((e) => e.isNotConfigured, 'isNotConfigured', isTrue)),
      );
    });

    test('a non-JSON error body throws CheckInException without a code', () async {
      backend.on('GET /check-ins/gyms', ok('<html>Bad gateway</html>', 502));
      await expectLater(api.getCheckInGyms(_token), throwsA(_checkInError('Request failed (502)', status: 502)));
    });
  });

  group('getCheckInToken', () {
    test('GETs /check-ins/token?gym_id= and parses the QR payload', () async {
      backend.on(
        'GET /check-ins/token',
        ok({
          'token': 'qr-payload', // real tokens are signed; never stored in fixtures
          'expires_at': '2026-10-28T18:52:15.000Z',
          'ttl_seconds': 300,
          'gym_id': _gym,
          'gym_name': 'Ironclad Fitness',
        }),
      );

      final t = await api.getCheckInToken(_token, _gym);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/check-ins/token');
      expect(req.url.queryParameters, {'gym_id': _gym});
      _expectHeaders(req);
      expect(t.token, 'qr-payload');
      expect(t.expiresAt.toUtc(), DateTime.utc(2026, 10, 28, 18, 52, 15));
      expect(t.expiresAt.isUtc, isFalse); // shown in local time
      expect(t.ttlSeconds, 300);
      expect(t.gymId, _gym);
      expect(t.gymName, 'Ironclad Fitness');
    });

    test('403 for a non-member surfaces the message', () async {
      backend.on('GET /check-ins/token', err(403, 'Forbidden'));
      await expectLater(api.getCheckInToken(_token, _gym), throwsA(_checkInError('Forbidden', status: 403)));
    });
  });

  group('checkInWithToken', () {
    test('POSTs {token, gym_id} and parses the result', () async {
      backend.on('POST /check-ins', ok(_resultJson(), 201));

      final res = await api.checkInWithToken(_token, 'scanned-qr', gymId: _gym);

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/check-ins');
      expect(req.url.hasQuery, isFalse);
      _expectHeaders(req);
      expect(bodyOf(req), equals({'token': 'scanned-qr', 'gym_id': _gym}));

      expect(res.duplicate, isFalse);
      expect(res.warning, isNull);
      expect(res.outcome, CheckInOutcome.checkedIn);
      final c = res.checkIn;
      expect(c.id, 'ci1');
      expect(c.gymId, _gym);
      expect(c.userId, 'u-liam');
      expect(c.checkedInAt.toUtc(), DateTime.utc(2026, 10, 11, 21, 25));
      expect(c.checkedInBy, 'u-staff');
      expect(c.method, 'qr');
      expect(c.isManual, isFalse);
      expect(res.member.id, 'u-liam');
      expect(res.member.name, 'Liam');
      expect(res.member.lastName, "O'Connor");
      expect(res.member.email, isNull);
      expect(res.member.avatarUrl, 'https://api.dicebear.com/9.x/avataaars/png?seed=liamoconnor&size=256');
      expect(res.membership!.isActive, isTrue);
      expect(res.membership!.toDate, '2026-12-31');
      expect(res.membership!.typeName, 'Monthly Unlimited');
    });

    test('omits gym_id when not given; duplicate (200) with no membership parses', () async {
      backend.on('POST /check-ins', ok(_resultJson(duplicate: true, membership: null, warning: 'no_active_membership')));

      final res = await api.checkInWithToken(_token, 'scanned-qr');

      expect(bodyOf(backend.only), equals({'token': 'scanned-qr'}));
      expect(res.duplicate, isTrue);
      expect(res.membership, isNull);
      expect(res.warning, 'no_active_membership');
      expect(res.outcome, CheckInOutcome.duplicate);
    });

    for (final (code, message) in [
      ('token_expired', 'This QR code has expired. Ask the member to refresh it.'),
      ('token_invalid', 'Invalid check-in code'),
      ('wrong_gym', 'This code is for a different gym'),
    ]) {
      test('400 $code carries the code', () async {
        backend.on('POST /check-ins', err(400, message, code: code));
        await expectLater(
          api.checkInWithToken(_token, 'scanned-qr', gymId: _gym),
          throwsA(_checkInError(message, code: code, status: 400)),
        );
      });
    }
  });

  group('manualCheckIn', () {
    test('POSTs {gym_id, user_id} and parses the result', () async {
      backend.on('POST /check-ins', ok(_resultJson(method: 'manual'), 201));

      final res = await api.manualCheckIn(_token, _gym, 'u-liam');

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/check-ins');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'gym_id': _gym, 'user_id': 'u-liam'}));
      expect(res.checkIn.method, 'manual');
      expect(res.checkIn.isManual, isTrue);
    });

    test('400 (not a member) surfaces the message without a code', () async {
      backend.on('POST /check-ins', err(400, 'User is not a member of this gym'));
      await expectLater(
        api.manualCheckIn(_token, _gym, 'u-x'),
        throwsA(_checkInError('User is not a member of this gym', status: 400)),
      );
    });
  });

  group('searchCheckInMembers', () {
    final people = [
      {
        'id': 'u-liam',
        'name': 'Liam',
        'last_name': "O'Connor",
        'email': 'liam.oconnor@example.com',
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=liamoconnor&size=256',
      },
      {'id': 'u-n', 'name': 'Natalia', 'last_name': 'Petrova', 'email': null, 'avatar_url': null},
    ];

    test('GETs /check-ins/members with gym_id and an encoded q', () async {
      backend.on('GET /check-ins/members', ok(people));

      final res = await api.searchCheckInMembers(_token, _gym, "o'connor & co");

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/check-ins/members');
      expect(req.url.queryParameters, {'gym_id': _gym, 'q': "o'connor & co"});
      expect(req.url.query, isNot(contains('& co'))); // encoded, not a second param
      _expectHeaders(req);
      expect(res, hasLength(2));
      expect(res[0].id, 'u-liam');
      expect(res[0].name, 'Liam');
      expect(res[0].lastName, "O'Connor");
      expect(res[0].email, 'liam.oconnor@example.com');
      expect(res[0].avatarUrl, contains('liamoconnor'));
      expect(res[0].fullName, "Liam O'Connor");
      expect(res[1].email, isNull);
      expect(res[1].avatarUrl, isNull);
    });

    test('an empty query omits q', () async {
      backend.on('GET /check-ins/members', ok([]));
      expect(await api.searchCheckInMembers(_token, _gym, ''), isEmpty);
      expect(backend.only.url.queryParameters, {'gym_id': _gym});
    });
  });

  group('getGymCheckIns', () {
    test('GETs /check-ins?gym_id=&date=&tz_offset= and parses member names', () async {
      backend.on(
        'GET /check-ins',
        ok([
          _checkInRow(extra: {
            'name': 'Liam',
            'last_name': "O'Connor",
            'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=liamoconnor&size=256',
          }),
          {
            'id': 'ci2',
            'gym_id': _gym,
            'user_id': 'u-s',
            'checked_in_at': '2026-10-11T19:35:00.000Z',
            'checked_in_by': null,
            'method': 'manual',
            'name': 'Sofia',
            'last_name': 'Rossi',
            'avatar_url': null,
          },
        ]),
      );

      final list = await api.getGymCheckIns(_token, _gym, date: DateTime(2026, 3, 7, 23, 59));

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/check-ins');
      expect(req.url.queryParameters, {'gym_id': _gym, 'date': '2026-03-07', 'tz_offset': _tz});
      _expectHeaders(req);
      expect(list, hasLength(2));
      expect(list[0].memberName, "Liam O'Connor");
      expect(list[0].avatarUrl, contains('liamoconnor'));
      expect(list[0].gymName, isNull);
      expect(list[1].checkedInBy, isNull);
      expect(list[1].isManual, isTrue);
      expect(list[1].checkedInAt.toUtc(), DateTime.utc(2026, 10, 11, 19, 35));
      expect(list[1].memberName, 'Sofia Rossi');
    });

    test('without a date sends only gym_id and tz_offset', () async {
      backend.on('GET /check-ins', ok([]));
      await api.getGymCheckIns(_token, _gym);
      expect(backend.only.url.queryParameters, {'gym_id': _gym, 'tz_offset': _tz});
    });
  });

  group('getMyCheckIns', () {
    test('GETs /check-ins?mine=true with paging and parses gym names', () async {
      backend.on(
        'GET /check-ins',
        ok([
          _checkInRow(extra: {'gym_name': 'Ironclad Fitness'}),
          _checkInRow(extra: {'id': 'ci0', 'checked_in_at': '2026-10-07T10:55:00.000Z', 'gym_name': 'Ironclad Fitness'}),
        ]),
      );

      final list = await api.getMyCheckIns(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/check-ins');
      expect(req.url.queryParameters, {'mine': 'true', 'page': '0', 'page_size': '30'});
      _expectHeaders(req);
      expect(list.map((c) => c.id), ['ci1', 'ci0']);
      expect(list[0].gymName, 'Ironclad Fitness');
      expect(list[0].name, isNull);
      expect(list[1].checkedInAt.toUtc(), DateTime.utc(2026, 10, 7, 10, 55));
    });

    test('passes gym_id, page and page_size', () async {
      backend.on('GET /check-ins', ok([]));
      await api.getMyCheckIns(_token, gymId: _gym, page: 2, pageSize: 10);
      expect(backend.only.url.queryParameters, {'mine': 'true', 'gym_id': _gym, 'page': '2', 'page_size': '10'});
    });
  });

  group('getMyCheckInStats', () {
    test('GETs /check-ins/stats?mine=true&tz_offset= and parses counts', () async {
      backend.on(
        'GET /check-ins/stats',
        ok({'total': 17, 'this_month': 6, 'this_week': 0, 'last_check_in_at': '2026-10-11T21:25:00.000Z'}),
      );

      final s = await api.getMyCheckInStats(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/check-ins/stats');
      expect(req.url.queryParameters, {'mine': 'true', 'tz_offset': _tz});
      _expectHeaders(req);
      expect(s.total, 17);
      expect(s.thisMonth, 6);
      expect(s.thisWeek, 0);
      expect(s.lastCheckInAt!.toUtc(), DateTime.utc(2026, 10, 11, 21, 25));
    });

    test('never checked in: null last check-in, string counts', () async {
      backend.on('GET /check-ins/stats', ok({'total': '0', 'this_month': '0', 'this_week': '0', 'last_check_in_at': null}));
      final s = await api.getMyCheckInStats(_token);
      expect(s.total, 0);
      expect(s.lastCheckInAt, isNull);
    });
  });

  group('getGymCheckInStats', () {
    test('GETs /check-ins/stats?gym_id=&days=&tz_offset= and parses everything', () async {
      backend.on(
        'GET /check-ins/stats',
        ok({
          'gym_id': _gym,
          'days': 30,
          'today': 0,
          'this_week': 0,
          'total': 49,
          'unique_members': 7,
          'per_day': [
            {'date': '2026-09-29', 'count': 4},
            {'date': '2026-09-30', 'count': 5},
          ],
          'busiest_hours': [
            {'hour': 0, 'count': 1},
            {'hour': 18, 'count': 9},
          ],
          'top_members': [
            {
              'id': 'u-s',
              'name': 'Sofia',
              'last_name': 'Rossi',
              'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=sofiarossi&size=256',
              'visits': 9,
              'last_check_in_at': '2026-10-12T17:23:00.000Z',
            },
          ],
        }),
      );

      final s = await api.getGymCheckInStats(_token, _gym);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/check-ins/stats');
      expect(req.url.queryParameters, {'gym_id': _gym, 'days': '30', 'tz_offset': _tz});
      _expectHeaders(req);
      expect(s.days, 30);
      expect(s.today, 0);
      expect(s.thisWeek, 0);
      expect(s.total, 49);
      expect(s.uniqueMembers, 7);
      expect(s.perDay.map((d) => (d.date, d.count)), [(DateTime(2026, 9, 29), 4), (DateTime(2026, 9, 30), 5)]);
      expect(s.busiestHours, hasLength(24));
      expect(s.busiestHours[0], 1);
      expect(s.busiestHours[18], 9);
      final top = s.topMembers.single;
      expect(top.person.id, 'u-s');
      expect(top.person.fullName, 'Sofia Rossi');
      expect(top.person.avatarUrl, contains('sofiarossi'));
      expect(top.visits, 9);
      expect(top.lastCheckInAt!.toUtc(), DateTime.utc(2026, 10, 12, 17, 23));
    });

    test('passes a custom days window', () async {
      backend.on('GET /check-ins/stats', ok({'days': 7}));
      final s = await api.getGymCheckInStats(_token, _gym, days: 7);
      expect(backend.only.url.queryParameters['days'], '7');
      expect(s.perDay, isEmpty);
      expect(s.topMembers, isEmpty);
    });

    test('403 for non-staff surfaces the message', () async {
      backend.on('GET /check-ins/stats', err(403, 'Forbidden'));
      await expectLater(api.getGymCheckInStats(_token, _gym), throwsA(_checkInError('Forbidden', status: 403)));
    });
  });
}
