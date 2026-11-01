import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/user_settings.dart';
import 'package:gym_bro_mobile/models/water.dart';

WaterDay _day({int total = 1000, int goal = 2500, List<WaterEntry> entries = const []}) => WaterDay(
      date: DateTime(2026, 11, 1),
      totalMl: total,
      goalMl: goal,
      baseGoalMl: goal,
      entries: entries,
    );

void main() {
  group('waterAmount', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final sr = lookupAppLocalizations(const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'));

    test('ml below a litre, litres above', () {
      expect(waterAmount(en, 250), '250 ml');
      expect(waterAmount(en, 999), '999 ml');
      expect(waterAmount(en, 1000), '1 l');
      expect(waterAmount(en, 1250), '1.25 l');
      expect(waterAmount(en, 2800), '2.8 l');
    });

    test("uses the app language's decimal mark", () {
      expect(waterAmount(sr, 2500), '2,5 l');
      expect(waterAmount(sr, 330), '330 ml');
    });
  });

  group('WaterDay', () {
    test('progress clamps but the percentage may pass 100', () {
      expect(_day(total: 1250).fraction, 0.5);
      expect(_day(total: 1250).percent, 50);
      expect(_day(total: 3000).fraction, 1.0);
      expect(_day(total: 3000).percent, 120);
      expect(_day(total: 3000).remainingMl, 0);
      expect(_day(total: 2500).reached, isTrue);
      expect(_day(total: 100, goal: 0).fraction, 0);
    });

    test('adding and removing entries keeps the total right', () {
      final now = DateTime(2026, 11, 1, 12);
      final day = _day(total: 250, entries: [WaterEntry(id: 'a', ml: 250, loggedAt: now)]);
      final more = day.adding(WaterEntry(id: 'b', ml: 500, loggedAt: now));
      expect(more.totalMl, 750);
      expect(more.entries.first.id, 'b');
      final less = more.removing('a');
      expect(less.totalMl, 500);
      expect(less.entries.map((e) => e.id), ['b']);
      expect(less.removing('missing').totalMl, 500);
    });
  });

  group('WaterHistory', () {
    WaterHistoryDay d(int total, [int goal = 2000]) =>
        WaterHistoryDay(date: DateTime(2026, 10, 1), totalMl: total, goalMl: goal);

    test('streak counts back from yesterday, or today once met', () {
      expect(WaterHistory(baseGoalMl: 2000, days: [d(0), d(2000), d(2100), d(500)]).streak, 2);
      expect(WaterHistory(baseGoalMl: 2000, days: [d(0), d(2000), d(2100), d(2000)]).streak, 3);
      expect(WaterHistory(baseGoalMl: 2000, days: [d(2000), d(100), d(500)]).streak, 0);
    });

    test('average skips days without water', () {
      final h = WaterHistory(baseGoalMl: 2000, days: [d(0), d(1000), d(3000)]);
      expect(h.averageMl, 2000);
      expect(h.daysReached, 1);
      expect(const WaterHistory(baseGoalMl: 2000, days: []).averageMl, 0);
    });
  });

  group('waterGoalFor (settings)', () {
    test('custom, from body weight, or 2.5 l', () {
      expect(const UserSettings(waterGoalMl: 3200).waterGoalFor(80), 3200);
      expect(const UserSettings().waterGoalFor(80), 2800);
      expect(const UserSettings().waterGoalFor(null), 2500);
      expect(const UserSettings().waterGoalFor(30), 1500);
    });
  });

  group('waterReminderSchedule', () {
    test("today's remaining hours, then every hour of the next days", () {
      final slots = waterReminderSchedule(DateTime(2026, 11, 1, 14, 30), goalReachedToday: false);
      final today = slots.where((s) => s.dayOffset == 0).map((s) => s.at.hour).toList();
      expect(today, [15, 17, 19, 21]);
      expect(slots.where((s) => s.dayOffset == 1).map((s) => s.at.hour), waterReminderHours);
      expect(slots.map((s) => s.dayOffset).toSet(), {0, 1, 2, 3});
      expect(slots.where((s) => s.dayOffset == 3).first.at, DateTime(2026, 11, 4, 9));
    });

    test('nothing more today once the goal is reached', () {
      final slots = waterReminderSchedule(DateTime(2026, 11, 1, 8), goalReachedToday: true);
      expect(slots.where((s) => s.dayOffset == 0), isEmpty);
      expect(slots.first.at, DateTime(2026, 11, 2, 9));
    });

    test('after 21:00 today is done; months roll over', () {
      final slots = waterReminderSchedule(DateTime(2026, 11, 30, 21, 30), goalReachedToday: false);
      expect(slots.first.at, DateTime(2026, 12, 1, 9));
    });

    test('ids are stable, unique and inside the reserved range', () {
      final slots = waterReminderSchedule(DateTime(2026, 11, 1, 6), goalReachedToday: false);
      final ids = slots.map((s) => s.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(waterReminderIds.toSet().containsAll(ids), isTrue);
      expect(waterReminderIds.length, waterReminderDays * waterReminderHours.length);
      expect(waterReminderSchedule(DateTime(2026, 11, 1, 6), goalReachedToday: false).first.id, ids.first);
    });
  });
}
