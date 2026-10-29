// Small pure helpers used across screens: schedule dates and booking
// actions, people labels, rest timer, orders, money, check-in dates.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/business.dart';
import 'package:gym_bro_mobile/models/gym_class.dart';
import 'package:gym_bro_mobile/models/payment.dart';
import 'package:gym_bro_mobile/pages/checkin/check_in_widgets.dart' as checkin;
import 'package:gym_bro_mobile/pages/classes/schedule_widgets.dart' as schedule;
import 'package:gym_bro_mobile/pages/people/people_common.dart' as people;
import 'package:gym_bro_mobile/pages/shop/order_widgets.dart' as orders;
import 'package:gym_bro_mobile/widgets/rest_timer.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../auth/auth_fixtures.dart';

final en = lookupAppLocalizations(const Locale('en'));

/// A GET /classes row as the API sends it.
GymClass _class({
  Duration startsIn = const Duration(hours: 2),
  int capacity = 12,
  int booked = 3,
  String? myStatus,
  bool canCoach = false,
  bool cancelled = false,
}) {
  final start = DateTime.now().add(startsIn).toUtc();
  return GymClass.fromJson({
    'id': 'c-1',
    'gym_id': 'g-1',
    'trainer_id': 'u-trainer',
    'title': 'Morning HIIT',
    'starts_at': start.toIso8601String(),
    'ends_at': start.add(const Duration(minutes: 45)).toIso8601String(),
    'capacity': capacity,
    'cancelled_at': cancelled ? '2026-10-20T10:00:00.000Z' : null,
    'gym_name': 'Iron Temple',
    'booked_count': '$booked', // count(*) arrives as a string
    'waitlist_count': '0',
    'my_booking_id': myStatus == null ? null : 'b-1',
    'my_booking_status': myStatus,
    'can_coach': canCoach,
  });
}

void main() {
  setUpAll(() => initializeDateFormatting());

  group('schedule dates', () {
    test('dateOnly / sameDay', () {
      expect(schedule.dateOnly(DateTime(2026, 10, 28, 23, 59, 59)), DateTime(2026, 10, 28));
      expect(schedule.sameDay(DateTime(2026, 10, 28, 0, 0), DateTime(2026, 10, 28, 23, 59)), isTrue);
      expect(schedule.sameDay(DateTime(2026, 10, 28, 23, 59), DateTime(2026, 10, 29, 0, 0)), isFalse);
      expect(schedule.sameDay(DateTime(2025, 10, 28), DateTime(2026, 10, 28)), isFalse);
    });

    test('startOfWeek is Monday 00:00', () {
      // 2026-10-28 is a Wednesday.
      expect(schedule.startOfWeek(DateTime(2026, 10, 28, 15, 30)), DateTime(2026, 10, 26));
      expect(schedule.startOfWeek(DateTime(2026, 10, 26, 0, 0)), DateTime(2026, 10, 26));
      expect(schedule.startOfWeek(DateTime(2026, 11, 1, 23, 0)), DateTime(2026, 10, 26), reason: 'Sunday belongs to the week before');
      expect(schedule.startOfWeek(DateTime(2027, 1, 2)), DateTime(2026, 12, 28), reason: 'across a year boundary');
    });

    test('groupByDay groups by local day and keeps order', () {
      final items = [
        DateTime(2026, 10, 28, 18),
        DateTime(2026, 10, 27, 7),
        DateTime(2026, 10, 28, 6),
        DateTime(2026, 10, 27, 20),
      ];
      final grouped = schedule.groupByDay(items, (d) => d);
      expect(grouped.keys, [DateTime(2026, 10, 28), DateTime(2026, 10, 27)]);
      expect(grouped[DateTime(2026, 10, 28)], [DateTime(2026, 10, 28, 18), DateTime(2026, 10, 28, 6)]);
      expect(grouped[DateTime(2026, 10, 27)], [DateTime(2026, 10, 27, 7), DateTime(2026, 10, 27, 20)]);
      expect(schedule.groupByDay(<DateTime>[], (d) => d), isEmpty);
    });

    testWidgets('formatDuration / formatTimeRange / formatDayLabel / formatTime in English', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));

      expect(schedule.formatDuration(ctx, const Duration(minutes: 45)), '45 min');
      expect(schedule.formatDuration(ctx, const Duration(hours: 1)), '1 h');
      expect(schedule.formatDuration(ctx, const Duration(minutes: 90)), '1 h 30 min');
      expect(schedule.formatDuration(ctx, Duration.zero), '0 min');

      expect(schedule.formatTime(ctx, DateTime(2026, 10, 28, 18, 30)), '6:30 PM');
      expect(schedule.formatTimeRange(ctx, DateTime(2026, 10, 28, 18, 30), DateTime(2026, 10, 28, 19, 15)), '6:30 PM – 7:15 PM');
      expect(schedule.formatTimeRange(ctx, DateTime(2026, 10, 28, 23), DateTime(2026, 10, 29, 1)), '11:00 PM – 1:00 AM (+1 day)');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 9);
      expect(schedule.formatDayLabel(ctx, today), 'Today');
      expect(schedule.formatDayLabel(ctx, DateTime(now.year, now.month, now.day + 1, 23)), 'Tomorrow');
      expect(schedule.formatDayLabel(ctx, DateTime(now.year, now.month, now.day - 1, 1)), 'Yesterday');
      final inFive = DateTime(now.year, now.month, now.day + 5);
      expect(
        schedule.formatDayLabel(ctx, inFive),
        inFive.year == now.year ? DateFormat.MMMEd('en').format(inFive) : DateFormat.yMMMEd('en').format(inFive),
      );
      expect(schedule.formatDayLabel(ctx, DateTime(2020, 10, 15)), 'Thu, Oct 15, 2020');

      // Check-in screens use 24 h clock and their own day labels.
      expect(checkin.formatTime(ctx, DateTime(2026, 10, 28, 18, 5)), '18:05');
      expect(checkin.formatDay(ctx, today), 'Today');
      expect(checkin.formatDay(ctx, DateTime(now.year, now.month, now.day - 1, 22)), en.businessCheckInYesterday);
      expect(checkin.formatDay(ctx, DateTime(2020, 3, 2)), 'Mar 2, 2020');
      expect(checkin.formatYmd(ctx, '2026-11-15'), 'Nov 15, 2026');
      expect(checkin.formatYmd(ctx, 'not-a-date'), 'not-a-date');
    });
  });

  group('bookingActionFor', () {
    test('open class, not booked → book; full → join waitlist', () {
      expect(schedule.bookingActionFor(_class()), schedule.BookingAction.book);
      expect(schedule.bookingActionFor(_class(booked: 12)), schedule.BookingAction.joinWaitlist);
      expect(schedule.bookingActionFor(_class(booked: 13)), schedule.BookingAction.joinWaitlist);
    });

    test('my booking status decides', () {
      expect(schedule.bookingActionFor(_class(myStatus: 'booked')), schedule.BookingAction.cancelBooking);
      expect(schedule.bookingActionFor(_class(myStatus: 'waitlisted', booked: 12)), schedule.BookingAction.leaveWaitlist);
      expect(schedule.bookingActionFor(_class(myStatus: 'attended')), schedule.BookingAction.none);
      expect(schedule.bookingActionFor(_class(myStatus: 'no_show')), schedule.BookingAction.none);
      expect(schedule.bookingActionFor(_class(myStatus: 'cancelled')), schedule.BookingAction.book, reason: 'can re-book');
      expect(schedule.bookingActionFor(_class(myStatus: 'cancelled', booked: 12)), schedule.BookingAction.joinWaitlist);
    });

    test('coaches don\'t book: nothing, or "full"', () {
      expect(schedule.bookingActionFor(_class(canCoach: true)), schedule.BookingAction.none);
      expect(schedule.bookingActionFor(_class(canCoach: true, booked: 12)), schedule.BookingAction.full);
    });

    test('cancelled or already started classes → none', () {
      expect(schedule.bookingActionFor(_class(cancelled: true)), schedule.BookingAction.none);
      expect(schedule.bookingActionFor(_class(cancelled: true, myStatus: 'booked')), schedule.BookingAction.none);
      expect(schedule.bookingActionFor(_class(startsIn: const Duration(minutes: -1))), schedule.BookingAction.none);
      expect(schedule.bookingActionFor(_class(startsIn: const Duration(minutes: -1), myStatus: 'booked')), schedule.BookingAction.none);
    });
  });

  group('people labels', () {
    test('isActiveNow / lastActiveText', () {
      final now = DateTime.now();
      expect(people.isActiveNow(null), isFalse);
      expect(people.isActiveNow(now.subtract(const Duration(minutes: 4))), isTrue);
      expect(people.isActiveNow(now.subtract(const Duration(minutes: 5))), isFalse);
      expect(people.lastActiveText(en, null), isNull);
      expect(people.lastActiveText(en, now.subtract(const Duration(minutes: 1))), 'Active now');
      expect(people.lastActiveText(en, now.subtract(const Duration(hours: 2, minutes: 5))), 'Active 2h ago');
    });

    test('distanceLabel', () {
      expect(people.distanceLabel(en, 0), '< 1 km');
      expect(people.distanceLabel(en, -3), '< 1 km');
      expect(people.distanceLabel(en, 12), '~12 km');
    });

    test('interestLabel localizes known interests (case/space-insensitive), keeps free text', () {
      expect(people.interestLabel(en, ' HIIT '), 'HIIT');
      expect(people.interestLabel(en, 'olympic lifting'), 'Olympic lifting');
      expect(people.interestLabel(en, 'Underwater basket weaving'), 'Underwater basket weaving');
    });

    test('peopleErrorText strips the Exception prefix', () {
      expect(people.peopleErrorText(Exception('Blocked')), 'Blocked');
    });
  });

  test('formatRestTime', () {
    expect(formatRestTime(0), '0:00');
    expect(formatRestTime(5), '0:05');
    expect(formatRestTime(90), '1:30');
    expect(formatRestTime(600), '10:00');
  });

  group('orders & money', () {
    test('shortOrderId: "#" + first 8 chars upper-cased', () {
      expect(orders.shortOrderId('3f2a9c1e-77b0-4d2e-9a51-0c3c1b2d4e5f'), '#3F2A9C1E');
    });

    test('formatDate / formatDateTime convert UTC to local', () {
      final utc = DateTime.utc(2026, 3, 12, 8, 30);
      final local = utc.toLocal();
      expect(orders.formatDate(utc, 'en'), DateFormat.yMMMd('en').format(local));
      expect(orders.formatDateTime(utc, 'en'), DateFormat.yMMMd('en').add_Hm().format(local));
      expect(orders.formatDate(DateTime(2026, 3, 12, 12), 'en'), 'Mar 12, 2026');
      expect(orders.errorText(Exception('Out of stock')), 'Out of stock');
    });

    test('formatMoney uses the currency symbol for the locale', () {
      expect(formatMoney(19.99, 'usd', 'en'), r'$19.99');
      expect(formatMoney(1234.5, 'eur', 'en'), '€1,234.50');
      expect(formatMoney(0, 'usd', 'en'), r'$0.00');
    });
  });

  test('weekdayLabel (ISO weekday)', () {
    expect(weekdayLabel(1, 'en'), 'Mon');
    expect(weekdayLabel(7, 'en'), 'Sun');
    expect(weekdayLabel(3, 'en', abbreviated: false), 'Wednesday');
  });
}
