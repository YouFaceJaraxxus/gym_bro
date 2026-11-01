import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/exercise.dart';
import 'package:gym_bro_mobile/models/last_sets.dart';
import 'package:gym_bro_mobile/models/training.dart';
import 'package:gym_bro_mobile/utils/overload.dart';

final _now = DateTime(2026, 11, 1, 18);

LastPerformance _last(List<(double?, int?)> sets, {int daysAgo = 3, List<RepType>? types}) => LastPerformance(
      exerciseId: 'ex',
      sessionId: 's',
      startedAt: _now.subtract(Duration(days: daysAgo)),
      sets: [
        for (final (i, (w, r)) in sets.indexed)
          LastSet(weightKg: w, reps: r, repType: types?[i] ?? RepType.count),
      ],
    );

Exercise _exercise(List<MuscleGroup> primary) => Exercise(
      id: 'e',
      name: 'x',
      primaryMuscles: primary,
      secondaryMuscles: const [],
      isPublic: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('suggestOverload (kg)', () {
    test('every working set hit the target → +2.5 kg, same reps', () {
      final s = suggestOverload(_last([(80, 8), (80, 8), (80, 8)]), targetReps: 8, now: _now)!;
      expect(s.reason, OverloadReason.addWeight);
      expect(s.weightKg, 82.5);
      expect(s.displayWeight, 82.5);
      expect(s.reps, 8);
      expect(s.increment, 2.5);
      expect(s.daysSince, 3);
    });

    test('missed reps → same weight, one more rep than the weakest set', () {
      final s = suggestOverload(_last([(80, 8), (80, 8), (80, 7)]), targetReps: 8, now: _now)!;
      expect(s.reason, OverloadReason.addRep);
      expect(s.weightKg, 80);
      expect(s.reps, 8);
    });

    test('+1 rep never passes the top of the range', () {
      final s = suggestOverload(_last([(60, 9), (60, 9)]), targetReps: 12, now: _now)!;
      expect((s.reason, s.reps, s.weightKg), (OverloadReason.addRep, 10, 60));
    });

    test('without a plan the best working set is the target', () {
      expect(suggestOverload(_last([(80, 8), (80, 8), (80, 7)]), now: _now)!.reason, OverloadReason.addRep);
      final s = suggestOverload(_last([(100, 5), (100, 5)]), now: _now)!;
      expect((s.reason, s.weightKg, s.reps), (OverloadReason.addWeight, 102.5, 5));
    });

    test('warm-ups and failure sets are not working sets', () {
      final last = _last(
        [(40, 10), (60, 5), (80, 8), (80, 8), (80, null)],
        types: [RepType.count, RepType.count, RepType.count, RepType.count, RepType.failure],
      );
      expect(workingSets(last.sets).map((s) => s.weightKg), [80, 80]);
      expect(suggestOverload(last, targetReps: 8, now: _now)!.weightKg, 82.5);
    });

    test('an off-grid weight rounds to the next plate-friendly one', () {
      final s = suggestOverload(_last([(81, 6), (81, 6)]), targetReps: 6, now: _now)!;
      expect(s.weightKg, 82.5);
      final t = suggestOverload(_last([(18.75, 15), (18.75, 15)]), targetReps: 15, now: _now)!;
      expect(t.weightKg, 20);
    });

    test('isolation work moves in 1.25 kg steps', () {
      final s = suggestOverload(_last([(12.5, 12), (12.5, 12)]), targetReps: 12, now: _now, isolation: true)!;
      expect((s.weightKg, s.increment), (13.75, 1.25));
    });

    test('a long break deloads about 10 %, rounded down to the step', () {
      final s = suggestOverload(_last([(100, 5), (100, 5)], daysAgo: 30), targetReps: 5, now: _now)!;
      expect(s.reason, OverloadReason.deload);
      expect(s.weightKg, 90);
      expect(s.reps, 5);
      expect(s.daysSince, 30);
      // 21 days is not a long break yet.
      expect(suggestOverload(_last([(100, 5)], daysAgo: 21), targetReps: 5, now: _now)!.reason, OverloadReason.addWeight);
      final odd = suggestOverload(_last([(82.5, 8)], daysAgo: 40), now: _now)!;
      expect(odd.weightKg, 72.5); // 74.25 → 72.5
    });

    test('no counted sets → no suggestion', () {
      expect(suggestOverload(_last([(80, null)], types: [RepType.failure]), now: _now), isNull);
      expect(suggestOverload(_last([]), now: _now), isNull);
    });
  });

  group('suggestOverload (lb)', () {
    test('adds 5 lb in pound plates and stores kilograms', () {
      // 100 kg ≈ 220.46 lb → 225 lb.
      final s = suggestOverload(_last([(100, 5), (100, 5)]), targetReps: 5, now: _now, usesPounds: true)!;
      expect(s.displayWeight, 225);
      expect(s.increment, 5);
      expect(s.weightKg, closeTo(102.06, 0.01));
    });

    test('isolation steps are 2.5 lb', () {
      expect(weightStep(usesPounds: true, isolation: true), 2.5);
      expect(weightStep(usesPounds: false), 2.5);
    });
  });

  group('bodyweight', () {
    test('hit every set → one more rep', () {
      final s = suggestOverload(_last([(null, 12), (0, 12)]), now: _now)!;
      expect((s.reason, s.reps, s.weightKg), (OverloadReason.bodyweightReps, 13, null));
    });

    test('uneven sets → the weakest set plus one', () {
      final s = suggestOverload(_last([(null, 12), (null, 10), (null, 9)]), now: _now)!;
      expect((s.reason, s.reps), (OverloadReason.bodyweightReps, 10));
    });

    test('a long break eases the reps back', () {
      final s = suggestOverload(_last([(null, 20)], daysAgo: 60), now: _now)!;
      expect((s.reason, s.reps), (OverloadReason.deload, 18));
    });
  });

  test('isolation is guessed from small primary muscles only', () {
    expect(isIsolationExercise(_exercise([MuscleGroup.biceps])), isTrue);
    expect(isIsolationExercise(_exercise([MuscleGroup.deltsMedial, MuscleGroup.deltsRear])), isTrue);
    expect(isIsolationExercise(_exercise([MuscleGroup.chestAll, MuscleGroup.tricepsAll])), isFalse);
    expect(isIsolationExercise(_exercise(const [])), isFalse);
    expect(isIsolationExercise(null), isFalse);
  });

  test('formatting helpers', () {
    expect(formatRepsList([const LastSet(reps: 8), const LastSet(reps: 8), const LastSet(reps: 7)]), '8, 8, 7');
    expect(formatDisplayNumber(82.5), '82.5');
    expect(formatDisplayNumber(80), '80');
    expect(formatDisplayNumber(1.25), '1.25');
    expect(formatDisplayNumber(176.37), '176.4');
    expect(calendarDaysBetween(DateTime(2026, 10, 31, 23), DateTime(2026, 11, 1, 1)), 1);
  });

  test('LastPerformance.fromJson takes numbers sent as strings', () {
    final p = LastPerformance.fromJson({
      'exercise_id': 'ex',
      'session_id': 's',
      'started_at': '2026-10-29T16:56:00.000Z',
      'sets': [
        {'weight_kg': '106.25', 'reps': 7, 'rep_type': 'count', 'side': 'both'},
        {'weight_kg': null, 'reps': '12', 'rep_type': 'count', 'side': 'both'},
        {'weight_kg': 80, 'reps': null, 'rep_type': 'failure', 'side': 'both'},
      ],
    });
    expect(p.sets.map((s) => s.weightKg), [106.25, null, 80]);
    expect(p.sets.map((s) => s.reps), [7, 12, null]);
    expect(p.sets.last.repType, RepType.failure);
    expect(p.startedAt.toUtc(), DateTime.utc(2026, 10, 29, 16, 56));
  });
}
