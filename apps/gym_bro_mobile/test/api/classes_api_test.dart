import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/gym_class.dart';
import 'package:gym_bro_mobile/services/api_service.dart';
import 'package:http/http.dart' as http;

import '../helpers/fake_backend.dart';

const _token = 'tok-123';
const _gym = 'ff453a60-28ca-4cdd-a919-c6ecd344ab65';

void _expectHeaders(http.Request req, {bool json = true}) {
  expect(req.headers['Authorization'], 'Bearer $_token');
  if (json) expect(req.headers['Content-Type'], startsWith('application/json'));
}

Matcher _throwsMessage(String message) => throwsA(predicate((e) => e is Exception && '$e'.contains(message)));

// Captured from the local stack (GET /classes as Liam, GET /classes/:id as the owner).
Map<String, dynamic> _classJson({Map<String, dynamic> extra = const {}}) => {
      'id': 'c1',
      'gym_id': _gym,
      'trainer_id': 't-jamal',
      'title': 'Barbell Basics',
      'description': 'Small-group coaching on the squat, bench and deadlift.',
      'location': 'Platform Area',
      'starts_at': '2026-09-29T22:00:00.000Z',
      'ends_at': '2026-09-29T23:00:00.000Z',
      'capacity': 5,
      'series_id': 'series-1',
      'cancelled_at': null,
      'reminder_sent_at': '2026-09-29T21:00:00.000Z',
      'created_by': 't-jamal',
      'created_at': '2026-09-22T22:00:00.000Z',
      'updated_at': '2026-09-22T22:00:00.000Z',
      'gym_name': 'Ironclad Fitness',
      'trainer_name': 'Jamal Carter',
      'trainer_avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=jamalcarter&size=256',
      'booked_count': 4,
      'waitlist_count': 0,
      'my_booking_id': 'b-liam',
      'my_booking_status': 'attended',
      'my_waitlist_position': null,
      'can_coach': false,
      ...extra,
    };

// Booking rows as POST /classes/:id/book returns them (returningAll + waitlist_position).
Map<String, dynamic> _bookingJson({String status = 'booked', Object? waitlistPosition}) => {
      'id': 'b1',
      'class_id': 'c1',
      'user_id': 'u-liam',
      'status': status,
      'created_at': '2026-09-25T08:19:41.726Z',
      'updated_at': '2026-09-25T08:19:41.726Z',
      'waitlist_position': waitlistPosition,
    };

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('getClasses', () {
    test('without filters GETs /classes with no query and parses every field', () async {
      backend.on(
        'GET /classes',
        ok([
          _classJson(),
          _classJson(extra: {
            'id': 'c2',
            'trainer_id': null,
            'description': null,
            'location': null,
            'series_id': null,
            'cancelled_at': '2026-10-01T10:00:00.000Z',
            'trainer_name': null,
            'trainer_avatar_url': null,
            'booked_count': '5', // count(*) can arrive as a string
            'waitlist_count': '2',
            'my_booking_id': 'b2',
            'my_booking_status': 'waitlisted',
            'my_waitlist_position': 2,
            'can_coach': true,
          }),
        ]),
      );

      final classes = await api.getClasses(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/classes');
      expect(req.url.hasQuery, isFalse);
      expect(req.url.toString(), isNot(contains('?')));
      _expectHeaders(req);

      expect(classes, hasLength(2));
      final c = classes[0];
      expect(c.id, 'c1');
      expect(c.gymId, _gym);
      expect(c.trainerId, 't-jamal');
      expect(c.title, 'Barbell Basics');
      expect(c.description, 'Small-group coaching on the squat, bench and deadlift.');
      expect(c.location, 'Platform Area');
      expect(c.startsAt.toUtc(), DateTime.utc(2026, 9, 29, 22));
      expect(c.startsAt.isUtc, isFalse);
      expect(c.endsAt.toUtc(), DateTime.utc(2026, 9, 29, 23));
      expect(c.duration, const Duration(hours: 1));
      expect(c.capacity, 5);
      expect(c.seriesId, 'series-1');
      expect(c.isSeries, isTrue);
      expect(c.cancelledAt, isNull);
      expect(c.createdBy, 't-jamal');
      expect(c.gymName, 'Ironclad Fitness');
      expect(c.trainerName, 'Jamal Carter');
      expect(c.trainerAvatarUrl, contains('jamalcarter'));
      expect(c.bookedCount, 4);
      expect(c.waitlistCount, 0);
      expect(c.spotsLeft, 1);
      expect(c.myBookingId, 'b-liam');
      expect(c.myBookingStatus, BookingStatus.attended);
      expect(c.myWaitlistPosition, isNull);
      expect(c.canCoach, isFalse);
      expect(c.bookings, isNull);

      final d = classes[1];
      expect(d.trainerId, isNull);
      expect(d.description, isNull);
      expect(d.seriesId, isNull);
      expect(d.cancelledAt!.toUtc(), DateTime.utc(2026, 10, 1, 10));
      expect(d.isCancelled, isTrue);
      expect(d.bookedCount, 5);
      expect(d.waitlistCount, 2);
      expect(d.isFull, isTrue);
      expect(d.myBookingStatus, BookingStatus.waitlisted);
      expect(d.myWaitlistPosition, 2);
      expect(d.hasActiveBooking, isTrue);
      expect(d.canCoach, isTrue);
    });

    test('sends every filter, times as UTC ISO-8601', () async {
      backend.on('GET /classes', ok([]));
      final from = DateTime(2026, 10, 1, 8, 30); // local
      final to = DateTime.utc(2026, 10, 15);

      await api.getClasses(_token,
          gymId: _gym, from: from, to: to, trainerId: 't-jamal', mine: true, includeCancelled: true);

      expect(backend.only.url.queryParameters, {
        'gym_id': _gym,
        'trainer_id': 't-jamal',
        'from': from.toUtc().toIso8601String(),
        'to': '2026-10-15T00:00:00.000Z',
        'mine': 'true',
        'include_cancelled': 'true',
      });
      expect(backend.only.url.queryParameters['from'], endsWith('Z'));
    });

    test('400 surfaces the message', () async {
      backend.on('GET /classes', err(400, 'Invalid gym_id'));
      await expectLater(api.getClasses(_token, gymId: 'nope'), _throwsMessage('Invalid gym_id'));
    });

    test('a non-JSON error body still throws a readable error', () async {
      backend.on('GET /classes', ok('<html>Bad gateway</html>', 502));
      await expectLater(api.getClasses(_token), _throwsMessage('Request failed (502)'));
    });
  });

  group('getClass', () {
    test('GETs /classes/:id and parses the coach roster', () async {
      backend.on(
        'GET /classes/c1',
        ok(_classJson(extra: {
          'my_booking_id': null,
          'my_booking_status': null,
          'can_coach': true,
          'bookings': [
            {
              'id': 'b-ingrid',
              'user_id': 'u-ingrid',
              'name': 'Ingrid',
              'last_name': 'Larsen',
              'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=ingridlarsen&size=256',
              'status': 'attended',
              'created_at': '2026-09-24T02:48:07.883Z',
            },
            {
              'id': 'b-x',
              'user_id': 'u-x',
              'name': null,
              'last_name': null,
              'avatar_url': null,
              'status': 'no_show',
              'created_at': '2026-09-25T08:19:41.726Z',
            },
          ],
        })),
      );

      final c = await api.getClass(_token, 'c1');

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/classes/c1');
      _expectHeaders(req);
      expect(c.myBookingId, isNull);
      expect(c.myBookingStatus, isNull);
      expect(c.canCoach, isTrue);
      expect(c.bookings, hasLength(2));
      final b = c.bookings![0];
      expect(b.id, 'b-ingrid');
      expect(b.classId, isNull);
      expect(b.userId, 'u-ingrid');
      expect(b.name, 'Ingrid');
      expect(b.lastName, 'Larsen');
      expect(b.fullName, 'Ingrid Larsen');
      expect(b.avatarUrl, contains('ingridlarsen'));
      expect(b.status, BookingStatus.attended);
      expect(b.createdAt.toUtc(), DateTime.utc(2026, 9, 24, 2, 48, 7, 883));
      expect(b.waitlistPosition, isNull);
      expect(c.bookings![1].status, BookingStatus.noShow);
      expect(c.bookings![1].initials, '?');
    });

    test('404 surfaces the message', () async {
      backend.on('GET /classes/c9', err(404, 'Class not found'));
      await expectLater(api.getClass(_token, 'c9'), _throwsMessage('Class not found'));
    });
  });

  group('getCoachingGyms', () {
    test('GETs /classes/coaching-gyms and parses trainers', () async {
      backend.on(
        'GET /classes/coaching-gyms',
        ok([
          {
            'gym_id': _gym,
            'gym_name': 'Ironclad Fitness',
            'trainers': [
              {'user_id': 't-aisha', 'name': 'Aisha', 'last_name': 'Mohammed'},
              {'user_id': 't-elena', 'name': 'Elena', 'last_name': 'Vasquez'},
            ],
            'can_staff': false,
          },
          {'gym_id': 'g2', 'gym_name': 'Phoenix Gym', 'trainers': [], 'can_staff': true},
        ]),
      );

      final gyms = await api.getCoachingGyms(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/classes/coaching-gyms');
      _expectHeaders(req);
      expect(gyms, hasLength(2));
      expect(gyms[0].gymId, _gym);
      expect(gyms[0].gymName, 'Ironclad Fitness');
      expect(gyms[0].canStaff, isFalse);
      expect(gyms[0].trainers.map((t) => (t.userId, t.fullName)),
          [('t-aisha', 'Aisha Mohammed'), ('t-elena', 'Elena Vasquez')]);
      expect(gyms[1].canStaff, isTrue);
      expect(gyms[1].trainers, isEmpty);
    });
  });

  group('createClass', () {
    test('POSTs the data as given and parses every created class', () async {
      backend.on(
        'POST /classes',
        ok([
          _classJson(extra: {'my_booking_id': null, 'my_booking_status': null, 'booked_count': 0, 'can_coach': true}),
          _classJson(extra: {
            'id': 'c1b',
            'starts_at': '2026-10-06T22:00:00.000Z',
            'ends_at': '2026-10-06T23:00:00.000Z',
            'my_booking_id': null,
            'my_booking_status': null,
            'booked_count': 0,
            'can_coach': true,
          }),
        ], 201),
      );
      final data = {
        'gym_id': _gym,
        'title': 'Barbell Basics',
        'description': null,
        'location': 'Platform Area',
        'starts_at': '2026-09-29T22:00:00.000Z',
        'ends_at': '2026-09-29T23:00:00.000Z',
        'capacity': 5,
        'trainer_id': 't-jamal',
        'repeat_weeks': 2,
      };

      final created = await api.createClass(_token, data);

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/classes');
      _expectHeaders(req);
      expect(bodyOf(req), equals(data));
      expect(created.map((c) => c.id), ['c1', 'c1b']);
      expect(created[1].startsAt.toUtc(), DateTime.utc(2026, 10, 6, 22));
      expect(created.every((c) => c.canCoach && c.bookedCount == 0), isTrue);
    });

    test('400 surfaces the message', () async {
      backend.on('POST /classes', err(400, 'ends_at must be after starts_at'));
      await expectLater(api.createClass(_token, {'gym_id': _gym}), _throwsMessage('ends_at must be after starts_at'));
    });
  });

  group('updateClass', () {
    test('PUTs the changes to /classes/:id and parses the class', () async {
      backend.on('PUT /classes/c1', ok(_classJson(extra: {'location': 'Studio B', 'capacity': 8, 'can_coach': true})));
      final changes = {'location': 'Studio B', 'capacity': 8, 'trainer_id': null, 'apply_to_series': true};

      final c = await api.updateClass(_token, 'c1', changes);

      final req = backend.only;
      expect(req.method, 'PUT');
      expect(pathOf(req), '/classes/c1');
      _expectHeaders(req);
      expect(bodyOf(req), equals(changes));
      expect(c.location, 'Studio B');
      expect(c.capacity, 8);
    });

    test('400 (cancelled) surfaces the message', () async {
      backend.on('PUT /classes/c1', err(400, 'This class has been cancelled'));
      await expectLater(api.updateClass(_token, 'c1', {'title': 'x'}), _throwsMessage('This class has been cancelled'));
    });
  });

  group('cancelClass', () {
    test('DELETEs /classes/:id without a query by default', () async {
      backend.on('DELETE /classes/c1', ok({'cancelled': ['c1']}));

      await api.cancelClass(_token, 'c1');

      final req = backend.only;
      expect(req.method, 'DELETE');
      expect(pathOf(req), '/classes/c1');
      expect(req.url.hasQuery, isFalse);
      expect(req.body, isEmpty);
      _expectHeaders(req);
    });

    test('series=true cancels the rest of the series', () async {
      backend.on('DELETE /classes/c1', ok({'cancelled': ['c1', 'c1b']}));
      await api.cancelClass(_token, 'c1', series: true);
      expect(backend.only.url.queryParameters, {'series': 'true'});
    });

    test('403 surfaces the message', () async {
      backend.on('DELETE /classes/c1', err(403, 'Trainers can only cancel their own classes'));
      await expectLater(api.cancelClass(_token, 'c1'), _throwsMessage('Trainers can only cancel their own classes'));
    });
  });

  group('bookClass', () {
    test('POSTs an empty object for myself and parses the booking', () async {
      backend.on('POST /classes/c1/book', ok(_bookingJson(), 201));

      final b = await api.bookClass(_token, 'c1');

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/classes/c1/book');
      _expectHeaders(req);
      expect(bodyOf(req), equals({}));
      expect(b.id, 'b1');
      expect(b.classId, 'c1');
      expect(b.userId, 'u-liam');
      expect(b.status, BookingStatus.booked);
      expect(b.createdAt.toUtc(), DateTime.utc(2026, 9, 25, 8, 19, 41, 726));
      expect(b.waitlistPosition, isNull);
      expect(b.name, isNull);
    });

    test('staff book on behalf of a member; a full class waitlists', () async {
      backend.on('POST /classes/c1/book', ok(_bookingJson(status: 'waitlisted', waitlistPosition: 3), 201));

      final b = await api.bookClass(_token, 'c1', userId: 'u-sofia');

      expect(bodyOf(backend.only), equals({'user_id': 'u-sofia'}));
      expect(b.status, BookingStatus.waitlisted);
      expect(b.waitlistPosition, 3);
    });

    test('409 surfaces the message', () async {
      backend.on('POST /classes/c1/book', err(409, 'Already booked for this class'));
      await expectLater(api.bookClass(_token, 'c1'), _throwsMessage('Already booked for this class'));
    });
  });

  group('cancelClassBooking', () {
    test('POSTs to /classes/:id/cancel-booking and parses the cancelled booking', () async {
      backend.on('POST /classes/c1/cancel-booking', ok(_bookingJson(status: 'cancelled')..remove('waitlist_position')));

      final b = await api.cancelClassBooking(_token, 'c1');

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/classes/c1/cancel-booking');
      _expectHeaders(req);
      expect(bodyOf(req), equals({}));
      expect(b.status, BookingStatus.cancelled);
    });

    test('staff cancel for someone else', () async {
      backend.on('POST /classes/c1/cancel-booking', ok(_bookingJson(status: 'cancelled')));
      await api.cancelClassBooking(_token, 'c1', userId: 'u-sofia');
      expect(bodyOf(backend.only), equals({'user_id': 'u-sofia'}));
    });

    test('400 surfaces the message', () async {
      backend.on('POST /classes/c1/cancel-booking', err(400, 'This class has already started'));
      await expectLater(api.cancelClassBooking(_token, 'c1'), _throwsMessage('This class has already started'));
    });
  });

  group('setClassBookingStatus', () {
    for (final (status, api_) in [
      (BookingStatus.attended, 'attended'),
      (BookingStatus.noShow, 'no_show'),
      (BookingStatus.booked, 'booked'),
    ]) {
      test('PUTs {status: $api_} to /classes/:id/bookings/:bookingId', () async {
        backend.on('PUT /classes/c1/bookings/b1', ok(_bookingJson(status: api_)..remove('waitlist_position')));

        final b = await api.setClassBookingStatus(_token, 'c1', 'b1', status);

        final req = backend.only;
        expect(req.method, 'PUT');
        expect(pathOf(req), '/classes/c1/bookings/b1');
        _expectHeaders(req);
        expect(bodyOf(req), equals({'status': api_}));
        expect(b.status, status);
      });
    }

    test('409 surfaces the message', () async {
      backend.on('PUT /classes/c1/bookings/b1', err(409, "A cancelled booking can't be marked; only booked members can"));
      await expectLater(
        api.setClassBookingStatus(_token, 'c1', 'b1', BookingStatus.attended),
        _throwsMessage("A cancelled booking can't be marked"),
      );
    });
  });
}
