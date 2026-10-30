import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/pages/archive/archive_calendar.dart';

void main() {
  group('months', () {
    test('monthOf and addMonths roll over years', () {
      expect(monthOf(DateTime(2026, 10, 30, 23, 59)), DateTime(2026, 10));
      expect(addMonths(DateTime(2026, 12), 1), DateTime(2027, 1));
      expect(addMonths(DateTime(2026, 1), -1), DateTime(2025, 12));
    });

    test('the archive stops at the current month', () {
      final now = DateTime(2026, 10, 30);
      expect(canGoToNextMonth(DateTime(2026, 9), now), isTrue);
      expect(canGoToNextMonth(DateTime(2026, 10), now), isFalse);
      expect(canGoToNextMonth(DateTime(2025, 12), now), isTrue);
    });
  });

  group('groupByDay', () {
    test('groups by local day keeping order', () {
      final items = [
        DateTime(2026, 10, 30, 23, 50),
        DateTime(2026, 10, 30, 0, 10),
        DateTime(2026, 10, 29, 12),
      ];
      final byDay = groupByDay(items, (d) => d);
      expect(byDay.keys, [DateTime(2026, 10, 30), DateTime(2026, 10, 29)]);
      expect(byDay[DateTime(2026, 10, 30)], [items[0], items[1]]);
    });

    test('UTC instants land on the local day', () {
      final utc = DateTime.utc(2026, 10, 30, 12);
      final byDay = groupByDay([utc], (d) => d);
      final local = utc.toLocal();
      expect(byDay.keys.single, DateTime(local.year, local.month, local.day));
    });
  });

  group('monthGrid', () {
    test('October 2026 from Monday: Thursday 1st, five weeks', () {
      final weeks = monthGrid(DateTime(2026, 10));
      expect(weeks.length, 5);
      expect(weeks.every((w) => w.length == 7), isTrue);
      expect(weeks.first.take(3), everyElement(isNull));
      expect(weeks.first[3], DateTime(2026, 10, 1));
      expect(weeks.expand((w) => w).whereType<DateTime>().length, 31);
      expect(weeks.last.whereType<DateTime>().last, DateTime(2026, 10, 31));
    });

    test('from Sunday the 1st sits one column later', () {
      final weeks = monthGrid(DateTime(2026, 10), firstWeekday: DateTime.sunday);
      expect(weeks.first[4], DateTime(2026, 10, 1));
    });

    test('February 2027 starting on a Monday fills exactly four rows', () {
      final weeks = monthGrid(DateTime(2027, 2));
      expect(weeks.length, 4);
      expect(weeks.first.first, DateTime(2027, 2, 1));
    });
  });
}
