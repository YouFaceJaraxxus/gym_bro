import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/coaching.dart';
import 'package:gym_bro_mobile/models/food_log.dart';
import 'package:gym_bro_mobile/models/meal_plan.dart';
import 'package:gym_bro_mobile/models/plan_entry.dart';
import 'package:gym_bro_mobile/models/training_session.dart';
import 'package:gym_bro_mobile/services/api_service.dart';

import '../helpers/fake_backend.dart';
import 'api_test_utils.dart';

// Rows captured from the local stack (GET /plan-entries as liam).
Map<String, dynamic> _workoutJson({
  String status = 'planned',
  String? sessionId,
}) => {
  'id': 'pe-w',
  'user_id': 'u-liam',
  'kind': 'workout',
  'starts_at': '2026-10-26T10:30:00.000Z',
  'ends_at': '2026-10-26T11:30:00.000Z',
  'duration_minutes': 60,
  'plan_date': '2026-10-26',
  'note': null,
  'edited': false,
  'skipped': status == 'skipped',
  'training_id': 't-leg',
  'training_name': 'Leg Day',
  'routine_assignment_id': 'ra1',
  'routine_id': 'r1',
  'routine_name': 'Deadlift Focus Block',
  'meal_plan_assignment_id': null,
  'meal_plan_id': null,
  'meal_plan_name': null,
  'daily_meal_plan_id': null,
  'daily_meal_plan_name': null,
  'meal_slot': null,
  'training_session_id': sessionId,
  'logged_count': 0,
  'status': status,
};

Map<String, dynamic> _mealJson() => {
  'id': 'pe-m',
  'user_id': 'u-liam',
  'kind': 'meal',
  'starts_at': '2026-10-26T07:00:00.000Z',
  'ends_at': '2026-10-26T07:30:00.000Z',
  'duration_minutes': '30',
  'plan_date': '2026-10-26',
  'note': 'Before the gym',
  'edited': true,
  'skipped': false,
  'training_id': null,
  'training_name': null,
  'routine_assignment_id': null,
  'routine_id': null,
  'routine_name': null,
  'meal_plan_assignment_id': 'ma1',
  'meal_plan_id': 'mp1',
  'meal_plan_name': '4-Week Lean Bulk',
  'daily_meal_plan_id': 'dmp1',
  'daily_meal_plan_name': 'Lean Bulk Fuel Day',
  'meal_slot': 'breakfast',
  'training_session_id': null,
  'logged_count': '2',
  'status': 'done',
};

void main() {
  final ctx = useFakeBackend();
  FakeBackend backend() => ctx.backend();
  ApiService api() => ctx.api();

  group('getPlanEntries', () {
    test(
      'GETs /plan-entries with UTC from/to and tz, and parses both kinds',
      () async {
        backend().on('GET /plan-entries', ok([_workoutJson(), _mealJson()]));

        final from = DateTime.utc(2026, 10, 26);
        final list = await api().getPlanEntries(
          token,
          from: from,
          to: from.add(const Duration(days: 7)),
          timezone: 'Europe/Belgrade',
        );

        expectGet(backend().only, '/plan-entries', {
          'from': '2026-10-26T00:00:00.000Z',
          'to': '2026-11-02T00:00:00.000Z',
          'tz': 'Europe/Belgrade',
        });

        final w = list[0];
        expect(w.kind, PlanEntryKind.workout);
        expect(w.status, PlanEntryStatus.planned);
        expect(w.startsAt, DateTime.utc(2026, 10, 26, 10, 30).toLocal());
        expect(w.startsAt.isUtc, isFalse, reason: 'shown in local time');
        expect(w.endsAt, DateTime.utc(2026, 10, 26, 11, 30).toLocal());
        expect(w.durationMinutes, 60);
        expect(w.planDate, DateTime(2026, 10, 26));
        expect(w.trainingId, 't-leg');
        expect(w.trainingName, 'Leg Day');
        expect(w.routineName, 'Deadlift Focus Block');
        expect(w.sourceName, 'Deadlift Focus Block');
        expect(w.mealSlot, isNull);
        expect(w.trainingSessionId, isNull);

        final m = list[1];
        expect(m.kind, PlanEntryKind.meal);
        expect(m.status, PlanEntryStatus.done);
        expect(m.durationMinutes, 30, reason: 'numeric strings parse');
        expect(m.loggedCount, 2);
        expect(m.mealSlot, MealSlotType.breakfast);
        expect(m.note, 'Before the gym');
        expect(m.edited, isTrue);
        expect(m.dailyMealPlanName, 'Lean Bulk Fuel Day');
        expect(m.sourceName, '4-Week Lean Bulk');
      },
    );

    test('another user and no zone: user_id, no tz', () async {
      backend().on('GET /plan-entries', ok([]));
      final from = DateTime.utc(2026, 1, 5);
      await api().getPlanEntries(
        token,
        from: from,
        to: from.add(const Duration(days: 1)),
        userId: 'u-client',
      );
      expect(backend().only.url.queryParameters, {
        'from': '2026-01-05T00:00:00.000Z',
        'to': '2026-01-06T00:00:00.000Z',
        'user_id': 'u-client',
      });
    });
  });

  group('getPlanEntry', () {
    test('a meal: planned items with macros, slot note and logs', () async {
      backend().on(
        'GET /plan-entries/pe-m',
        ok({
          ..._mealJson(),
          'items': [
            {
              'food_item_id': 'fi1',
              'recipe_id': null,
              'name': 'Oats',
              'amount': '80.00',
              'unit': 'g',
              'note': null,
              'kcal': '311.2',
              'protein': '10.5',
              'carb': '53',
              'fat': '5.6',
              'fiber': '8.0',
            },
            {
              'food_item_id': null,
              'recipe_id': 'rc1',
              'name': 'Protein Pancakes',
              'amount': 1,
              'unit': 'serving',
              'note': null,
              'kcal': 400,
              'protein': 30,
              'carb': 40,
              'fat': 10,
              'fiber': 3,
            },
          ],
          'slot_note': 'Add berries',
          'logs': [
            {
              'id': 'fl1',
              'name': 'Oats',
              'amount': '80.00',
              'kcal': '311.20',
              'protein': '10.50',
              'carb': '53.00',
              'fat': '5.60',
              'fiber': '8.00',
              'eaten_at': '2026-10-26T07:05:00.000Z',
            },
          ],
        }),
      );

      final d = await api().getPlanEntry(token, 'pe-m');

      expectGet(backend().only, '/plan-entries/pe-m');
      expect(d.entry.id, 'pe-m');
      expect(d.items, hasLength(2));
      expect(d.items[0].amount, 80);
      expect(d.items[0].unit, LogUnit.g);
      expect(d.items[1].unit, LogUnit.serving);
      expect(d.plannedMacros.kcal, closeTo(711.2, 1e-9));
      expect(d.slotNote, 'Add berries');
      expect(d.logs.single.macros.protein, 10.5);
      expect(d.logs.single.eatenAt, DateTime.utc(2026, 10, 26, 7, 5).toLocal());
      expect(d.loggedMacros.kcal, closeTo(311.2, 1e-9));
      expect(d.exercises, isEmpty);
    });

    test('a workout: exercises in order and sessions', () async {
      backend().on(
        'GET /plan-entries/pe-w',
        ok({
          ..._workoutJson(status: 'done', sessionId: 's1'),
          'exercises': [
            {
              'id': 'x1',
              'name': 'Back Squat',
              'set_type': 'normal',
              'drop_count': 3,
            },
            {
              'id': 'x2',
              'name': 'Romanian Deadlift',
              'set_type': 'superset',
              'drop_count': '1',
            },
          ],
          'sessions': [
            {
              'id': 's1',
              'started_at': '2026-10-26T10:40:00.000Z',
              'ended_at': null,
            },
          ],
        }),
      );

      final d = await api().getPlanEntry(token, 'pe-w');

      expect(d.entry.trainingSessionId, 's1');
      expect(d.exercises.map((x) => x.name), [
        'Back Squat',
        'Romanian Deadlift',
      ]);
      expect(d.exercises[0].dropCount, 3);
      expect(d.exercises[1].dropCount, 1);
      expect(d.exercises[1].setType, 'superset');
      expect(d.sessions.single.id, 's1');
      expect(d.sessions.single.endedAt, isNull);
      expect(d.items, isEmpty);
    });
  });

  group('writes', () {
    test('updatePlanEntry PUTs only the given fields', () async {
      backend().on(
        'PUT /plan-entries/pe-w',
        ok({..._workoutJson(), 'edited': true}),
      );

      final e = await api().updatePlanEntry(
        token,
        'pe-w',
        startsAt: DateTime.utc(2026, 10, 27, 17),
        durationMinutes: 45,
        trainingId: 't-push',
        note: '',
      );

      expectJson(backend().only, 'PUT', '/plan-entries/pe-w', {
        'starts_at': '2026-10-27T17:00:00.000Z',
        'duration_minutes': 45,
        'training_id': 't-push',
        'note': '',
      });
      expect(e.edited, isTrue);
    });

    test('un-skipping sends just skipped: false', () async {
      backend().on('PUT /plan-entries/pe-w', ok(_workoutJson()));
      await api().updatePlanEntry(token, 'pe-w', skipped: false);
      expectJson(backend().only, 'PUT', '/plan-entries/pe-w', {
        'skipped': false,
      });
    });

    test('skipPlanEntry DELETEs the entry (204)', () async {
      backend().on('DELETE /plan-entries/pe-w', ok(null, 204));
      await api().skipPlanEntry(token, 'pe-w');
      expectDelete(backend().only, '/plan-entries/pe-w');
    });

    test(
      'confirmPlanEntry POSTs confirm, with started_at only when given',
      () async {
        backend().on(
          'POST /plan-entries/pe-w/confirm',
          ok(_workoutJson(status: 'done', sessionId: 's9'), 201),
        );

        final e = await api().confirmPlanEntry(token, 'pe-w');
        expectJson(
          backend().last('POST /plan-entries/pe-w/confirm'),
          'POST',
          '/plan-entries/pe-w/confirm',
          {},
        );
        expect(e.status, PlanEntryStatus.done);
        expect(e.trainingSessionId, 's9');

        await api().confirmPlanEntry(
          token,
          'pe-w',
          startedAt: DateTime.utc(2026, 10, 26, 11),
        );
        expect(bodyOf(backend().last('POST /plan-entries/pe-w/confirm')), {
          'started_at': '2026-10-26T11:00:00.000Z',
        });
      },
    );

    test(
      'updateRoutineAssignment PUTs the body and parses zone and time',
      () async {
        backend().on(
          'PUT /routine-assignments/ra1',
          ok({
            'id': 'ra1',
            'routine_id': 'r1',
            'user_id': 'u-liam',
            'assigned_by_id': 'u-liam',
            'start_date': '2026-10-26',
            'end_date': null,
            'note': null,
            'timezone': 'America/New_York',
            'workout_time': '06:30',
            'created_at': '2026-10-26T01:00:00.000Z',
            'routine_name': 'Deadlift Focus Block',
          }),
        );

        final body = {
          'start_date': '2026-10-26',
          'end_date': null,
          'workout_time': '06:30',
          'timezone': 'America/New_York',
        };
        final a = await api().updateRoutineAssignment(token, 'ra1', body);

        expectJson(backend().only, 'PUT', '/routine-assignments/ra1', body);
        expect(a, isA<RoutineAssignment>());
        expect(a.timezone, 'America/New_York');
        expect(a.workoutTime, '06:30');
        expect(a.isSelfAssigned, isTrue);
        expect(a.startDate, DateTime(2026, 10, 26));
      },
    );

    test(
      'updateMealPlanAssignment PUTs the body and parses the zone',
      () async {
        backend().on(
          'PUT /meal-plan-assignments/ma1',
          ok({
            'id': 'ma1',
            'meal_plan_id': 'mp1',
            'user_id': 'u-liam',
            'assigned_by_id': 'u-liam',
            'start_date': '2026-09-15T00:00:00.000Z',
            'end_date': null,
            'note': null,
            'timezone': 'Europe/Belgrade',
            'created_at': '2026-09-15T16:06:25.275Z',
            'meal_plan_name': '4-Week Lean Bulk',
          }),
        );

        final a = await api().updateMealPlanAssignment(token, 'ma1', {
          'timezone': 'Europe/Belgrade',
        });

        expectJson(backend().only, 'PUT', '/meal-plan-assignments/ma1', {
          'timezone': 'Europe/Belgrade',
        });
        expect(a.timezone, 'Europe/Belgrade');
        expect(a.mealPlanName, '4-Week Lean Bulk');
      },
    );
  });

  group('logging against a plan', () {
    final foodLogRow = {
      'id': 'fl9',
      'user_id': 'u-liam',
      'log_date': '2026-11-02',
      'slot_type': 'dinner',
      'food_item_id': 'fi1',
      'recipe_id': null,
      'name': 'Rice',
      'amount': '150.00',
      'unit': 'g',
      'kcal': '195.00',
      'protein': '4',
      'carb': '42',
      'fat': '0.4',
      'fiber': '0.6',
      'note': null,
      'eaten_at': '2026-11-02T19:00:00.000Z',
      'plan_entry_id': 'pe-m',
      'created_at': '2026-10-30T10:00:00.000Z',
    };

    test(
      'createFoodLog sends eaten_at (may be in the future) and plan_entry_id',
      () async {
        backend().on('POST /food-logs', ok(foodLogRow, 201));

        final log = await api().createFoodLog(
          token,
          date: DateTime(2026, 11, 2),
          slotType: MealSlotType.dinner,
          foodItemId: 'fi1',
          amount: 150,
          eatenAt: DateTime.utc(2026, 11, 2, 19),
          planEntryId: 'pe-m',
        );

        expectJson(backend().only, 'POST', '/food-logs', {
          'log_date': '2026-11-02',
          'slot_type': 'dinner',
          'food_item_id': 'fi1',
          'amount': 150.0,
          'eaten_at': '2026-11-02T19:00:00.000Z',
          'plan_entry_id': 'pe-m',
        });
        expect(log.eatenAt, DateTime.utc(2026, 11, 2, 19).toLocal());
        expect(log.planEntryId, 'pe-m');
      },
    );

    test('without them the body is unchanged and older rows parse', () async {
      final legacy = {...foodLogRow}
        ..remove('eaten_at')
        ..remove('plan_entry_id');
      backend().on('POST /food-logs', ok(legacy, 201));

      final log = await api().createFoodLog(
        token,
        date: DateTime(2026, 11, 2),
        slotType: MealSlotType.dinner,
        recipeId: 'rc1',
        amount: 1,
      );

      expect(bodyOf(backend().only), {
        'log_date': '2026-11-02',
        'slot_type': 'dinner',
        'recipe_id': 'rc1',
        'amount': 1.0,
      });
      expect(log.eatenAt, isNull);
      expect(log.planEntryId, isNull);
    });

    test('logPlannedMeals can target a plan entry', () async {
      backend().on('POST /food-logs/from-plan', ok([foodLogRow], 201));
      await api().logPlannedMeals(
        token,
        DateTime(2026, 11, 2),
        eatenAt: DateTime.utc(2026, 11, 2, 19),
        planEntryId: 'pe-m',
      );
      expectJson(backend().only, 'POST', '/food-logs/from-plan', {
        'date': '2026-11-02',
        'eaten_at': '2026-11-02T19:00:00.000Z',
        'plan_entry_id': 'pe-m',
      });
    });

    test('sessions carry plan_entry_id', () {
      final s = TrainingSession.fromJson({
        'id': 's1',
        'user_id': 'u-liam',
        'training_id': 't-leg',
        'started_at': '2026-11-03T17:00:00.000Z',
        'ended_at': '2026-11-03T18:00:00.000Z',
        'plan_entry_id': 'pe-w',
        'created_at': '2026-10-30T10:00:00.000Z',
        'updated_at': '2026-10-30T10:00:00.000Z',
      });
      expect(s.planEntryId, 'pe-w');
    });
  });

  errorTests(ctx, {
    'getPlanEntries': (
      'GET /plan-entries',
      (a) => a.getPlanEntries(
        token,
        from: DateTime.utc(2026),
        to: DateTime.utc(2026, 1, 2),
      ),
    ),
    'getPlanEntry': ('GET /plan-entries/x', (a) => a.getPlanEntry(token, 'x')),
    'updatePlanEntry': (
      'PUT /plan-entries/x',
      (a) => a.updatePlanEntry(token, 'x', note: 'n'),
    ),
    'skipPlanEntry': (
      'DELETE /plan-entries/x',
      (a) => a.skipPlanEntry(token, 'x'),
    ),
    'confirmPlanEntry': (
      'POST /plan-entries/x/confirm',
      (a) => a.confirmPlanEntry(token, 'x'),
    ),
    'updateRoutineAssignment': (
      'PUT /routine-assignments/x',
      (a) => a.updateRoutineAssignment(token, 'x', {'note': 'n'}),
    ),
    'updateMealPlanAssignment': (
      'PUT /meal-plan-assignments/x',
      (a) => a.updateMealPlanAssignment(token, 'x', {'note': 'n'}),
    ),
  });
}
