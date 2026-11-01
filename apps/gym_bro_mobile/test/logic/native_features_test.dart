import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/plan_entry.dart';
import 'package:gym_bro_mobile/models/streak.dart';
import 'package:gym_bro_mobile/models/water.dart';
import 'package:gym_bro_mobile/services/health_sync_service.dart';
import 'package:gym_bro_mobile/services/home_widget_service.dart';
import 'package:gym_bro_mobile/services/rest_activity_service.dart';
import 'package:gym_bro_mobile/widgets/rest_timer.dart';

HealthWeighIn w(String at, double kg) => HealthWeighIn(at: DateTime.parse(at), kg: kg);

PlanEntry workout(String id, {PlanEntryStatus status = PlanEntryStatus.planned, String? name, int hour = 18}) {
  final start = DateTime(2026, 11, 1, hour);
  return PlanEntry(
    id: id,
    userId: 'u1',
    kind: PlanEntryKind.workout,
    status: status,
    startsAt: start,
    endsAt: start.add(const Duration(minutes: 60)),
    durationMinutes: 60,
    planDate: DateTime(2026, 11, 1),
    trainingName: name,
  );
}

StreakStatus streak({int current = 12, bool atRisk = false}) => StreakStatus(
      current: current,
      best: 20,
      freezes: 1,
      tier: StreakTier.forStreak(current),
      today: DateTime(2026, 11, 1),
      week: StreakWeek(start: DateTime(2026, 10, 26), planned: true, target: 3, required: 3, done: 1),
      atRisk: atRisk ? [StreakWeekEntry(id: 'p1', day: DateTime(2026, 11, 1), name: 'Push')] : const [],
    );

void main() {
  group('weighInsToImport', () {
    test('keeps the last reading of each day, oldest first', () {
      final out = weighInsToImport([
        w('2026-10-20T07:00:00', 82.4),
        w('2026-10-20T21:00:00', 83.1),
        w('2026-10-18T08:00:00', 82.0),
      ], {});
      expect(out, [w('2026-10-18T08:00:00', 82.0), w('2026-10-20T21:00:00', 83.1)]);
    });

    test('skips days that already have a measurement', () {
      final out = weighInsToImport([
        w('2026-10-20T07:00:00', 82.4),
        w('2026-10-21T07:00:00', 82.2),
      ], {DateTime(2026, 10, 20)});
      expect(out, [w('2026-10-21T07:00:00', 82.2)]);
    });

    test('collapses the same weigh-in from several sources', () {
      final out = weighInsToImport([
        w('2026-10-20T07:00:00', 82.4),
        w('2026-10-20T07:00:00', 82.4),
      ], {});
      expect(out, hasLength(1));
    });

    test('drops implausible values and rounds to 0.01 kg', () {
      final out = weighInsToImport([
        w('2026-10-19T07:00:00', 0),
        w('2026-10-20T07:00:00', 1200),
        w('2026-10-21T07:00:00', 81.23456),
      ], {});
      expect(out, [w('2026-10-21T07:00:00', 81.23)]);
    });

    test('existing days count by calendar day, whatever their time', () {
      final out = weighInsToImport([w('2026-10-20T07:00:00', 82.4)], {DateTime(2026, 10, 20, 15, 30)});
      expect(out, isEmpty);
    });
  });

  group('sleep', () {
    test('asleepMinutes counts overlapping intervals once', () {
      final m = asleepMinutes([
        (DateTime(2026, 10, 31, 23), DateTime(2026, 11, 1, 3)),
        (DateTime(2026, 11, 1, 2), DateTime(2026, 11, 1, 6, 30)),
        (DateTime(2026, 11, 1, 4), DateTime(2026, 11, 1, 5)),
      ]);
      expect(m, 7 * 60 + 30);
    });

    test('asleepMinutes adds separate stretches and ignores empty ones', () {
      final m = asleepMinutes([
        (DateTime(2026, 11, 1, 1), DateTime(2026, 11, 1, 2)),
        (DateTime(2026, 11, 1, 3), DateTime(2026, 11, 1, 3, 45)),
        (DateTime(2026, 11, 1, 5), DateTime(2026, 11, 1, 5)),
      ]);
      expect(m, 105);
      expect(asleepMinutes([]), 0);
    });

    test('sleepWindow runs from 18:00 yesterday to noon (or now)', () {
      final morning = sleepWindow(DateTime(2026, 11, 1, 8));
      expect(morning.start, DateTime(2026, 10, 31, 18));
      expect(morning.end, DateTime(2026, 11, 1, 8));
      final evening = sleepWindow(DateTime(2026, 11, 1, 20));
      expect(evening.end, DateTime(2026, 11, 1, 12));
    });
  });

  test('HealthSyncSettings survive a JSON round trip', () {
    final s = HealthSyncSettings(
      connected: true,
      userId: 'u1',
      showActivity: false,
      writeWater: false,
      lastWeightImport: DateTime(2026, 11, 1, 9, 30),
      writtenWorkouts: const ['a', 'b'],
    );
    final back = HealthSyncSettings.fromJson(s.toJson());
    expect(back.connected, isTrue);
    expect(back.userId, 'u1');
    expect(back.importWeight, isTrue);
    expect(back.showActivity, isFalse);
    expect(back.writeWorkouts, isTrue);
    expect(back.writeWater, isFalse);
    expect(back.lastWeightImport, DateTime(2026, 11, 1, 9, 30));
    expect(back.writtenWorkouts, ['a', 'b']);
    expect(HealthSyncSettings.fromJson(const {}).connected, isFalse);
  });

  group('homeWidgetPayload', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final now = DateTime(2026, 11, 1, 9);
    final water = WaterDay(date: DateTime(2026, 11, 1), totalMl: 1500, goalMl: 2500, baseGoalMl: 2500);

    test('signed out shows the sign-in state', () {
      final p = homeWidgetPayload(l10n, now: now, signedIn: false);
      expect(p['gb_signed_in'], isFalse);
      expect(p['gb_streak'], 0);
      expect(p['gb_day'], '2026-11-01');
      expect(p['gb_signed_out_label'], l10n.nativeWidgetSignedOut);
      expect(p['gb_workout_name'], '');
    });

    test('streak, water and the next planned workout', () {
      final p = homeWidgetPayload(
        l10n,
        now: now,
        signedIn: true,
        streak: streak(atRisk: true),
        water: water,
        workouts: [workout('1', status: PlanEntryStatus.done, name: 'Legs', hour: 7), workout('2', name: 'Push day')],
      );
      expect(p['gb_streak'], 12);
      expect(p['gb_streak_lit'], isTrue);
      expect(p['gb_streak_risk'], isTrue);
      expect(p['gb_streak_tier'], l10n.streakTierBronze);
      expect(p['gb_water_pct'], 60);
      expect(p['gb_water_goal_ml'], 2500);
      expect(p['gb_water_text'], l10n.waterProgress(waterAmount(l10n, 1500), waterAmount(l10n, 2500)));
      expect(p['gb_workout_name'], 'Push day');
      expect(p['gb_workout_status'], l10n.todayWorkoutWhen('18:00', 60));
      expect(p['gb_workout_done'], isFalse);
    });

    test('free day and all done', () {
      final free = homeWidgetPayload(l10n, now: now, signedIn: true, workouts: const []);
      expect(free['gb_workout_name'], l10n.todayFreeDay);
      expect(free['gb_workout_free'], isTrue);
      final done = homeWidgetPayload(l10n, now: now, signedIn: true, workouts: [
        workout('1', status: PlanEntryStatus.done, name: 'Legs'),
      ]);
      expect(done['gb_workout_name'], 'Legs');
      expect(done['gb_workout_done'], isTrue);
      expect(done['gb_workout_status'], l10n.todayAllDone);
    });

    test('an unknown streak leaves the saved one alone; unknown water is blank', () {
      final p = homeWidgetPayload(l10n, now: now, signedIn: true);
      expect(p.containsKey('gb_streak'), isFalse);
      expect(p['gb_water_pct'], 0);
      expect(p['gb_water_text'], '');
    });

    test('every widget names its Android provider', () {
      expect(GymBroWidget.water.qualifiedAndroidName, 'com.example.gym_bro_mobile.widgets.WaterWidgetProvider');
      expect(kAppGroupId, 'group.com.example.gymBroMobile');
    });
  });

  group('rest activity', () {
    test('notification buttons reach the running rest', () {
      final c = RestTimerController(defaultSeconds: 60)..exercise = 'Bench press';
      addTearDown(c.dispose);
      c.start();
      expect(c.total, 60);
      RestActivityService.instance.handleAction(RestActivityService.actionAdd);
      expect(c.total, 60 + RestActivityService.addSeconds);
      RestActivityService.instance.handleAction(RestActivityService.actionSkip);
      expect(c.isRunning, isFalse);
      // Once it's over, the buttons do nothing.
      RestActivityService.instance.handleAction(RestActivityService.actionAdd);
      expect(c.isRunning, isFalse);
    });
  });
}
