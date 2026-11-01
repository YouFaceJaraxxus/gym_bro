// Smoothed body-weight trend (Happy Scale / MacroFactor style), the weekly
// rate of change and a goal ETA. Pure functions: no Flutter, no units (the
// caller passes kg or lb consistently).
import 'dart:math' as math;

/// One value on a calendar day (local date; the time of day is ignored).
class TrendPoint {
  final DateTime date;
  final double value;
  const TrendPoint(this.date, this.value);

  @override
  String toString() => 'TrendPoint(${date.toIso8601String().split('T').first}, $value)';
}

/// The per-day smoothing factor.
const double kTrendAlpha = 0.1;

/// Whole days between two calendar dates (DST-safe).
int calendarDaysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Exponentially weighted moving average of [raw], one point per weigh-in day
/// (several weigh-ins on one day are averaged first), oldest first.
///
/// Gap-aware: after a gap of `d` days the new weigh-in gets the weight it
/// would have accumulated over `d` daily steps, `1 - (1 - alpha)^d`, so a
/// week without data counts like a week of steady weigh-ins rather than one
/// day. The trend starts at the first weigh-in.
List<TrendPoint> weightTrend(Iterable<TrendPoint> raw, {double alpha = kTrendAlpha}) {
  final byDay = <DateTime, List<double>>{};
  for (final p in raw) {
    if (!p.value.isFinite) continue;
    byDay.putIfAbsent(_day(p.date), () => []).add(p.value);
  }
  final days = byDay.keys.toList()..sort();
  final out = <TrendPoint>[];
  double? trend;
  DateTime? prev;
  for (final day in days) {
    final values = byDay[day]!;
    final v = values.reduce((a, b) => a + b) / values.length;
    if (trend == null) {
      trend = v;
    } else {
      final gap = math.max(1, calendarDaysBetween(prev!, day));
      final a = 1 - math.pow(1 - alpha, gap).toDouble();
      trend += a * (v - trend);
    }
    prev = day;
    out.add(TrendPoint(day, trend));
  }
  return out;
}

/// Change per week of [trend] over the last [windowDays] (least-squares slope
/// of the trend points in that window). Null without at least two points
/// spanning [minSpanDays] days.
double? weeklyRate(List<TrendPoint> trend, {int windowDays = 28, int minSpanDays = 7}) {
  if (trend.length < 2) return null;
  final last = trend.last.date;
  final window = [
    for (final p in trend)
      if (calendarDaysBetween(p.date, last) <= windowDays) p,
  ];
  if (window.length < 2) return null;
  final span = calendarDaysBetween(window.first.date, last);
  if (span < minSpanDays) return null;
  final xs = [for (final p in window) calendarDaysBetween(window.first.date, p.date).toDouble()];
  final ys = [for (final p in window) p.value];
  final n = xs.length;
  final mx = xs.reduce((a, b) => a + b) / n;
  final my = ys.reduce((a, b) => a + b) / n;
  var num = 0.0;
  var den = 0.0;
  for (var i = 0; i < n; i++) {
    num += (xs[i] - mx) * (ys[i] - my);
    den += (xs[i] - mx) * (xs[i] - mx);
  }
  if (den == 0) return null;
  return num / den * 7;
}

enum GoalEtaKind {
  /// No current trend or not enough history for a rate.
  noData,

  /// Already within the tolerance of the goal.
  reached,

  /// The rate is about zero.
  flat,

  /// Moving away from the goal.
  wrongWay,

  /// On the way, but further out than the horizon.
  tooFar,

  /// On the way; [GoalEta.date] is set.
  onTrack,
}

class GoalEta {
  final GoalEtaKind kind;
  final DateTime? date;
  final double? weeks;
  const GoalEta(this.kind, {this.date, this.weeks});
}

/// When [current] reaches [goal] at [ratePerWeek] (same units).
///
/// [tolerance] counts as reached; rates under [minRate] per week are flat;
/// ETAs further than [maxWeeks] are [GoalEtaKind.tooFar].
GoalEta goalEta({
  required double? current,
  required double goal,
  required double? ratePerWeek,
  required DateTime today,
  double tolerance = 0.25,
  double minRate = 0.05,
  double maxWeeks = 156,
}) {
  if (current == null) return const GoalEta(GoalEtaKind.noData);
  final remaining = goal - current;
  if (remaining.abs() <= tolerance) return const GoalEta(GoalEtaKind.reached);
  if (ratePerWeek == null) return const GoalEta(GoalEtaKind.noData);
  if (ratePerWeek.abs() < minRate) return const GoalEta(GoalEtaKind.flat);
  if (remaining.sign != ratePerWeek.sign) return const GoalEta(GoalEtaKind.wrongWay);
  final weeks = remaining / ratePerWeek;
  if (weeks > maxWeeks) return GoalEta(GoalEtaKind.tooFar, weeks: weeks);
  final day = _day(today);
  return GoalEta(
    GoalEtaKind.onTrack,
    weeks: weeks,
    date: DateTime(day.year, day.month, day.day + (weeks * 7).round()),
  );
}
