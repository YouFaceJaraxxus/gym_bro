import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/food_log.dart';
import 'package:gym_bro_mobile/models/meal_plan.dart';
import 'package:gym_bro_mobile/models/plan_entry.dart';
import 'package:gym_bro_mobile/models/training_session.dart';
import 'package:gym_bro_mobile/pages/classes/schedule_items.dart';
import 'package:gym_bro_mobile/widgets/calendar_view.dart';
import 'package:gym_bro_mobile/widgets/plan_enrolment.dart';

FoodLog _log(
  String id, {
  required DateTime date,
  MealSlotType slot = MealSlotType.lunch,
  DateTime? eatenAt,
  String? planEntryId,
  double kcal = 100,
}) => FoodLog(
  id: id,
  userId: 'u',
  logDate: date,
  slotType: slot,
  name: 'Item $id',
  amount: 100,
  unit: LogUnit.g,
  macros: MacroTotals(kcal: kcal),
  eatenAt: eatenAt,
  planEntryId: planEntryId,
  createdAt: date,
);

PlanEntry _entry(
  String id, {
  PlanEntryKind kind = PlanEntryKind.workout,
  PlanEntryStatus status = PlanEntryStatus.planned,
  DateTime? start,
  String? sessionId,
  MealSlotType? slot,
}) {
  final s = start ?? DateTime(2030, 1, 7, 18);
  return PlanEntry(
    id: id,
    userId: 'u',
    kind: kind,
    status: status,
    startsAt: s,
    endsAt: s.add(const Duration(minutes: 60)),
    durationMinutes: 60,
    planDate: dateOnly(s),
    trainingSessionId: sessionId,
    mealSlot: slot,
  );
}

TrainingSession _session(
  String id,
  DateTime start, {
  String? planEntryId,
  int minutes = 50,
}) => TrainingSession(
  id: id,
  userId: 'u',
  startedAt: start.toUtc(),
  endedAt: start.add(Duration(minutes: minutes)).toUtc(),
  planEntryId: planEntryId,
  setLogs: const [],
  createdAt: start,
  updatedAt: start,
);

void main() {
  final monday = DateTime(2030, 1, 7);

  group('planEntryCalendarState', () {
    test('planned is upcoming, done is done, skipped is cancelled', () {
      expect(
        planEntryCalendarState(PlanEntryStatus.planned),
        CalendarEntryState.upcoming,
      );
      expect(
        planEntryCalendarState(PlanEntryStatus.done),
        CalendarEntryState.done,
      );
      expect(
        planEntryCalendarState(PlanEntryStatus.skipped),
        CalendarEntryState.cancelled,
      );
    });

    test('API status strings map to the enum (unknown → planned)', () {
      expect(PlanEntryStatus.fromApiValue('done'), PlanEntryStatus.done);
      expect(PlanEntryStatus.fromApiValue('skipped'), PlanEntryStatus.skipped);
      expect(PlanEntryStatus.fromApiValue('planned'), PlanEntryStatus.planned);
      expect(PlanEntryStatus.fromApiValue(null), PlanEntryStatus.planned);
    });
  });

  group('meal slot times', () {
    test('usual times match the server', () {
      expect(usualSlotTime(MealSlotType.breakfast), (
        hour: 8,
        minute: 0,
        minutes: 30,
      ));
      expect(usualSlotTime(MealSlotType.morningSnack), (
        hour: 10,
        minute: 30,
        minutes: 15,
      ));
      expect(usualSlotTime(MealSlotType.lunch), (
        hour: 13,
        minute: 0,
        minutes: 45,
      ));
      expect(usualSlotTime(MealSlotType.afternoonSnack), (
        hour: 16,
        minute: 0,
        minutes: 15,
      ));
      expect(usualSlotTime(MealSlotType.preWorkout), (
        hour: 17,
        minute: 0,
        minutes: 15,
      ));
      expect(usualSlotTime(MealSlotType.postWorkout), (
        hour: 19,
        minute: 30,
        minutes: 15,
      ));
      expect(usualSlotTime(MealSlotType.dinner), (
        hour: 20,
        minute: 0,
        minutes: 45,
      ));
      expect(usualSlotTime(MealSlotType.eveningSnack), (
        hour: 21,
        minute: 30,
        minutes: 15,
      ));
    });

    test('an hour suggests a slot; never pre/post workout', () {
      expect(mealSlotForHour(7), MealSlotType.breakfast);
      expect(mealSlotForHour(10), MealSlotType.morningSnack);
      expect(mealSlotForHour(13), MealSlotType.lunch);
      expect(mealSlotForHour(16), MealSlotType.afternoonSnack);
      expect(mealSlotForHour(19), MealSlotType.dinner);
      expect(mealSlotForHour(22), MealSlotType.eveningSnack);
      expect(mealSlotForHour(2), MealSlotType.eveningSnack);
      for (var h = 0; h < 24; h++) {
        expect(
          mealSlotForHour(h),
          isNot(anyOf(MealSlotType.preWorkout, MealSlotType.postWorkout)),
        );
      }
    });
  });

  group('groupFoodLogs', () {
    test('one block per (date, slot), sorted by time, with summed macros', () {
      final tuesday = monday.add(const Duration(days: 1));
      final items = groupFoodLogs([
        _log('a', date: monday, slot: MealSlotType.dinner, kcal: 300),
        _log('b', date: monday, slot: MealSlotType.lunch, kcal: 200),
        _log('c', date: monday, slot: MealSlotType.dinner, kcal: 150),
        _log('d', date: tuesday, slot: MealSlotType.lunch),
      ]);

      expect(items.map((i) => (i.date, i.slot, i.logs.length)), [
        (monday, MealSlotType.lunch, 1),
        (monday, MealSlotType.dinner, 2),
        (tuesday, MealSlotType.lunch, 1),
      ]);
      expect(items[1].macros.kcal, 450);
    });

    test(
      "without eaten_at a block sits at the slot's usual time for its usual length",
      () {
        final item = groupFoodLogs([
          _log('a', date: monday, slot: MealSlotType.lunch),
        ]).single;
        expect(item.start, DateTime(2030, 1, 7, 13));
        expect(item.end, DateTime(2030, 1, 7, 13, 45));
      },
    );

    test('with eaten_at it sits at the earliest one', () {
      final item = groupFoodLogs([
        _log(
          'a',
          date: monday,
          slot: MealSlotType.breakfast,
          eatenAt: DateTime(2030, 1, 7, 9, 15),
        ),
        _log('b', date: monday, slot: MealSlotType.breakfast),
        _log(
          'c',
          date: monday,
          slot: MealSlotType.breakfast,
          eatenAt: DateTime(2030, 1, 7, 7, 40),
        ),
      ]).single;
      expect(item.start, DateTime(2030, 1, 7, 7, 40));
      expect(
        item.end,
        DateTime(2030, 1, 7, 8, 10),
        reason: 'breakfast lasts 30 min',
      );
      expect(item.logs, hasLength(3));
    });
  });

  group('buildScheduleItems', () {
    test(
      'a done workout replaces its session and sits at the session time',
      () {
        final entry = _entry(
          'pe1',
          status: PlanEntryStatus.done,
          sessionId: 's1',
        );
        final logged = DateTime(2030, 1, 7, 18, 20);
        final items = buildScheduleItems(
          sessions: [
            _session('s1', logged, planEntryId: 'pe1'),
            _session('s2', DateTime(2030, 1, 8, 7)),
          ],
          entries: [entry],
        );

        expect(
          items.whereType<WorkoutItem>().map((w) => w.session.id),
          ['s2'],
          reason: 'only the session without a plan shows on its own',
        );
        final plan = items.whereType<PlanItem>().single;
        expect(plan.session?.id, 's1');
        expect(plan.start, logged);
        expect(plan.end, logged.add(const Duration(minutes: 50)));
      },
    );

    test("a session linked to an entry outside the window still shows", () {
      final items = buildScheduleItems(
        sessions: [
          _session('s1', DateTime(2030, 1, 7, 18), planEntryId: 'elsewhere'),
        ],
      );
      expect(items.single, isA<WorkoutItem>());
    });

    test('a planned (not done) entry keeps its own time', () {
      final entry = _entry('pe1', start: DateTime(2030, 1, 7, 6, 30));
      final plan = buildScheduleItems(
        entries: [entry],
      ).whereType<PlanItem>().single;
      expect(plan.session, isNull);
      expect(plan.start, DateTime(2030, 1, 7, 6, 30));
      expect(plan.end, DateTime(2030, 1, 7, 7, 30));
    });

    test('food logged against a loaded planned meal folds into it', () {
      final meal = _entry(
        'pm1',
        kind: PlanEntryKind.meal,
        status: PlanEntryStatus.done,
        slot: MealSlotType.lunch,
        start: DateTime(2030, 1, 7, 13),
      );
      final items = buildScheduleItems(
        entries: [meal],
        foodLogs: [
          _log('a', date: monday, planEntryId: 'pm1'),
          _log('b', date: monday, planEntryId: 'pm1'),
          _log('c', date: monday, slot: MealSlotType.dinner),
          _log('d', date: monday, planEntryId: 'not-loaded'),
        ],
      );

      expect(items.whereType<PlanItem>().single.entry.id, 'pm1');
      final meals = items.whereType<MealLogItem>().toList();
      expect(meals.map((m) => (m.slot, m.logs.map((l) => l.id).join(','))), [
        (MealSlotType.lunch, 'd'),
        (MealSlotType.dinner, 'c'),
      ]);
    });
  });

  group('enrolments', () {
    Enrolment e(String id, {DateTime? start, DateTime? end}) => Enrolment(
      id: id,
      startDate: start,
      endDate: end,
      createdAt: DateTime(2030),
    );

    test('the current one is the latest started that is not over', () {
      final today = DateTime(2030, 3, 10, 15);
      final all = [
        e('ended', start: DateTime(2030, 1, 1), end: DateTime(2030, 2, 1)),
        e('older', start: DateTime(2030, 2, 1)),
        e('newer', start: DateTime(2030, 3, 1), end: DateTime(2030, 3, 10)),
      ];
      expect(
        currentEnrolment(all, today)?.id,
        'newer',
        reason: 'ends today, so still on',
      );
      expect(currentEnrolment([all.first], today), isNull);
    });

    test('workout time round-trips through HH:MM', () {
      expect(parseTimeOfDay('06:30'), const TimeOfDay(hour: 6, minute: 30));
      expect(parseTimeOfDay('18:00:00'), const TimeOfDay(hour: 18, minute: 0));
      expect(parseTimeOfDay('25:00'), isNull);
      expect(parseTimeOfDay(null), isNull);
      expect(formatTimeOfDay(const TimeOfDay(hour: 7, minute: 5)), '07:05');
    });
  });
}
