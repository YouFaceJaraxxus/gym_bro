import '../models/exercise.dart';
import '../models/last_sets.dart';
import '../models/training.dart' show RepType;
import 'plate_calculator.dart';

// Progressive-overload suggestions: plain double progression, no AI.
//
//  * Every working set hit the target reps last time → add one weight step,
//    same reps.
//  * Otherwise → same weight, one more rep than the weakest working set (up
//    to the target).
//  * Bodyweight / no-weight exercises progress reps the same way.
//  * More than [longBreakDays] since last time → back off ~10 %.
//
// Pure functions: no Flutter. Weights come in as kilograms; suggestions are
// worked out in the user's unit (so they land on plate-friendly numbers)
// and carry both the display value and the kilograms to store.

/// Days off after which the suggestion is a deload.
const longBreakDays = 21;

/// How much a deload takes off.
const deloadFactor = 0.9;

/// Sets lighter than this share of the top weight are warm-ups / back-offs.
const workingSetShare = 0.9;

const double lbPerKg = 2.2046226218;

/// Why a suggestion is what it is (so the UI can explain itself).
enum OverloadReason {
  /// Hit all reps last time → heavier, same reps.
  addWeight,

  /// Missed some reps → same weight, one more rep.
  addRep,

  /// No weight → one more rep.
  bodyweightReps,

  /// Long break → about 10 % lighter (fewer reps without weight).
  deload,
}

class OverloadSuggestion {
  /// Kilograms to store; null without weight.
  final double? weightKg;

  /// The same weight in the user's unit, plate-rounded; null without weight.
  final double? displayWeight;
  final int reps;
  final OverloadReason reason;

  /// The step added (user's unit), for [OverloadReason.addWeight].
  final double? increment;

  /// Calendar days since last time.
  final int daysSince;

  const OverloadSuggestion({
    this.weightKg,
    this.displayWeight,
    required this.reps,
    required this.reason,
    this.increment,
    required this.daysSince,
  });

  bool get hasWeight => weightKg != null;
}

/// The smallest sensible jump in the user's unit: a pair of the smallest
/// plates (2.5 kg / 5 lb), halved for isolation work (1.25 kg / 2.5 lb).
double weightStep({required bool usesPounds, bool isolation = false}) {
  final pair = 2 * (usesPounds ? lbPlates.last : kgPlates.last);
  return isolation ? pair / 2 : pair;
}

/// Muscles small enough that their exercises are usually isolation work.
const _isolationMuscles = {
  MuscleGroup.biceps,
  MuscleGroup.tricepsAll,
  MuscleGroup.tricepsLong,
  MuscleGroup.tricepsLateral,
  MuscleGroup.tricepsMedial,
  MuscleGroup.forearmsAll,
  MuscleGroup.forearmsTop,
  MuscleGroup.forearmsBottom,
  MuscleGroup.deltsMedial,
  MuscleGroup.deltsRear,
  MuscleGroup.calves,
  MuscleGroup.absUpper,
  MuscleGroup.absLower,
  MuscleGroup.absObliques,
  MuscleGroup.neck,
};

/// Best guess from the primary muscles: only small muscles → isolation
/// (curls, raises, extensions). Unknown → false (the regular step).
bool isIsolationExercise(Exercise? e) {
  final primary = e?.primaryMuscles ?? const <MuscleGroup>[];
  return primary.isNotEmpty && primary.every(_isolationMuscles.contains);
}

/// Last time's working sets: counted reps, and (when anything was weighted)
/// within [workingSetShare] of the top weight. In logged order.
List<LastSet> workingSets(List<LastSet> sets) {
  final counted = sets.where((s) => s.repType == RepType.count && (s.reps ?? 0) > 0).toList();
  final top = counted.fold<double>(0, (m, s) => (s.weightKg ?? 0) > m ? s.weightKg! : m);
  if (top <= 0) return counted;
  return counted.where((s) => (s.weightKg ?? 0) >= top * workingSetShare).toList();
}

/// Whole calendar days between [from] and [to] (local dates).
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Nearest multiple of [step]; a tie goes to the lighter one.
double _round(double v, double step) => (v / step - 0.5 - 1e-9).ceil() * step;
double _floor(double v, double step) => (v / step + 1e-9).floor() * step;
double _clean(double v) => double.parse(v.toStringAsFixed(2));

/// The next target for an exercise given [last] time, or null when there's
/// nothing to go on (no counted sets).
///
/// [targetReps] is the planned rep count (the top of the range); without
/// one, the best working set's reps are the target. [now] is when the new
/// workout happens (the logged date for a back-dated one).
OverloadSuggestion? suggestOverload(
  LastPerformance last, {
  int? targetReps,
  required DateTime now,
  bool usesPounds = false,
  bool isolation = false,
}) {
  final working = workingSets(last.sets);
  if (working.isEmpty) return null;
  final reps = [for (final s in working) s.reps!];
  final minReps = reps.reduce((a, b) => a < b ? a : b);
  final maxReps = reps.reduce((a, b) => a > b ? a : b);
  final target = targetReps != null && targetReps > 0 ? targetReps : maxReps;
  final hitAll = minReps >= target;
  final days = calendarDaysBetween(last.startedAt, now);
  final longBreak = days > longBreakDays;

  final topKg = working.fold<double>(0, (m, s) => (s.weightKg ?? 0) > m ? s.weightKg! : m);
  if (topKg <= 0) {
    if (longBreak) {
      final eased = (maxReps * deloadFactor).round();
      return OverloadSuggestion(
        reps: eased < 1 ? 1 : eased,
        reason: OverloadReason.deload,
        daysSince: days,
      );
    }
    return OverloadSuggestion(
      reps: hitAll ? target + 1 : (minReps + 1 > target ? target : minReps + 1),
      reason: OverloadReason.bodyweightReps,
      daysSince: days,
    );
  }

  double toDisplay(double kg) => usesPounds ? kg * lbPerKg : kg;
  double toKg(double display) => usesPounds ? display / lbPerKg : display;
  final step = weightStep(usesPounds: usesPounds, isolation: isolation);
  final top = toDisplay(topKg);

  if (longBreak) {
    var eased = _floor(top * deloadFactor, step);
    if (eased <= 0) eased = step < top ? step : top;
    return OverloadSuggestion(
      weightKg: _clean(toKg(eased)),
      displayWeight: _clean(eased),
      reps: target,
      reason: OverloadReason.deload,
      daysSince: days,
    );
  }

  if (hitAll) {
    var next = _round(top + step, step);
    if (next <= top + 1e-6) next += step;
    return OverloadSuggestion(
      weightKg: _clean(toKg(next)),
      displayWeight: _clean(next),
      reps: target,
      reason: OverloadReason.addWeight,
      increment: step,
      daysSince: days,
    );
  }

  return OverloadSuggestion(
    // Same weight as last time, exactly as logged.
    weightKg: _clean(topKg),
    displayWeight: _clean(top),
    reps: minReps + 1 > target ? target : minReps + 1,
    reason: OverloadReason.addRep,
    daysSince: days,
  );
}

/// "8, 8, 7" — the reps of [sets].
String formatRepsList(List<LastSet> sets) =>
    [for (final s in sets) if (s.reps != null) '${s.reps}'].join(', ');

/// A weight in the user's unit without needless decimals: 82.5, 80, 1.25;
/// odd values (a converted 176.37 lb) get one decimal (176.4).
String formatDisplayNumber(double v) {
  final quarter = (v * 4).round() / 4;
  final n = (quarter - v).abs() < 0.02 ? quarter : double.parse(v.toStringAsFixed(1));
  return n.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}
