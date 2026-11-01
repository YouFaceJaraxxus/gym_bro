// Water tracking (GET/POST/DELETE /water-logs).
//
// The API works out each day's goal: the chosen one (settings), else ~35 ml
// per kg of the latest body weight, plus 500 ml on a day with a finished
// workout. Days are local to the zone the app sends.
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

// Counts may arrive as JSON strings.
int _i(dynamic v, [int fallback = 0]) => v == null ? fallback : (int.tryParse('$v') ?? double.tryParse('$v')?.round() ?? fallback);

/// 'YYYY-MM-DD' → a local date (no UTC shift).
DateTime _day(dynamic v) {
  final parts = '${v ?? ''}'.split('T').first.split('-');
  if (parts.length == 3) {
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y != null && m != null && d != null) return DateTime(y, m, d);
  }
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// "750 ml" below a litre, else "1.25 l" (the app language's decimal mark).
String waterAmount(AppLocalizations l10n, int ml) {
  if (ml.abs() < 1000) return l10n.waterMl('$ml');
  final tag = Intl.canonicalizedLocale(l10n.localeName);
  final lang = tag.split('_').first;
  final locale = NumberFormat.localeExists(tag) ? tag : (NumberFormat.localeExists(lang) ? lang : 'en');
  final format = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 2;
  return l10n.waterLiters(format.format(ml / 1000));
}

/// One drink.
class WaterEntry {
  final String id;
  final int ml;

  /// Local time.
  final DateTime loggedAt;

  const WaterEntry({required this.id, required this.ml, required this.loggedAt});

  factory WaterEntry.fromJson(Map<String, dynamic> json) => WaterEntry(
        id: '${json['id']}',
        ml: _i(json['ml']),
        loggedAt: DateTime.tryParse('${json['logged_at']}')?.toLocal() ?? DateTime.now(),
      );
}

/// Today's water: what was drunk and the goal (GET /water-logs/today).
class WaterDay {
  final DateTime date;
  final String? timezone;
  final int totalMl;

  /// [baseGoalMl] plus [workoutBonusMl].
  final int goalMl;
  final int baseGoalMl;
  final int workoutBonusMl;

  /// True when the goal is worked out from body weight (no custom goal).
  final bool autoGoal;

  /// The latest body weight the goal was worked out from.
  final double? weightKg;
  final bool workedOut;

  /// Newest first.
  final List<WaterEntry> entries;

  const WaterDay({
    required this.date,
    this.timezone,
    required this.totalMl,
    required this.goalMl,
    required this.baseGoalMl,
    this.workoutBonusMl = 0,
    this.autoGoal = true,
    this.weightKg,
    this.workedOut = false,
    this.entries = const [],
  });

  factory WaterDay.fromJson(Map<String, dynamic> json) {
    final base = _i(json['base_goal_ml'], 2500);
    return WaterDay(
      date: _day(json['date']),
      timezone: json['timezone'] as String?,
      totalMl: _i(json['total_ml']),
      goalMl: _i(json['goal_ml'], base),
      baseGoalMl: base,
      workoutBonusMl: _i(json['workout_bonus_ml']),
      autoGoal: json['auto_goal'] as bool? ?? true,
      weightKg: double.tryParse('${json['weight_kg']}'),
      workedOut: json['worked_out'] as bool? ?? false,
      entries: [
        for (final e in json['entries'] as List? ?? const [])
          if (e is Map<String, dynamic>) WaterEntry.fromJson(e),
      ],
    );
  }

  /// Share of the goal drunk, 0..1.
  double get fraction => goalMl <= 0 ? 0 : (totalMl / goalMl).clamp(0.0, 1.0);

  /// Share of the goal drunk as a whole percentage (may pass 100).
  int get percent => goalMl <= 0 ? 0 : (totalMl * 100 / goalMl).round();

  int get remainingMl => (goalMl - totalMl).clamp(0, goalMl);

  bool get reached => goalMl > 0 && totalMl >= goalMl;

  /// The same day with [entry] added (an optimistic update).
  WaterDay adding(WaterEntry entry) => _with(totalMl + entry.ml, [entry, ...entries]);

  /// The same day without the entry [id].
  WaterDay removing(String id) {
    final gone = entries.where((e) => e.id == id).fold<int>(0, (s, e) => s + e.ml);
    return _with(totalMl - gone, entries.where((e) => e.id != id).toList());
  }

  WaterDay _with(int total, List<WaterEntry> list) => WaterDay(
        date: date,
        timezone: timezone,
        totalMl: total < 0 ? 0 : total,
        goalMl: goalMl,
        baseGoalMl: baseGoalMl,
        workoutBonusMl: workoutBonusMl,
        autoGoal: autoGoal,
        weightKg: weightKg,
        workedOut: workedOut,
        entries: list,
      );
}

/// One day of GET /water-logs/history.
class WaterHistoryDay {
  final DateTime date;
  final int totalMl;
  final int goalMl;
  final bool workedOut;

  const WaterHistoryDay({required this.date, required this.totalMl, required this.goalMl, this.workedOut = false});

  factory WaterHistoryDay.fromJson(Map<String, dynamic> json) => WaterHistoryDay(
        date: _day(json['date']),
        totalMl: _i(json['total_ml']),
        goalMl: _i(json['goal_ml'], 2500),
        workedOut: json['worked_out'] as bool? ?? false,
      );

  bool get reached => goalMl > 0 && totalMl >= goalMl;
}

/// Daily totals, oldest first, ending today.
class WaterHistory {
  final int baseGoalMl;
  final List<WaterHistoryDay> days;

  const WaterHistory({required this.baseGoalMl, required this.days});

  factory WaterHistory.fromJson(Map<String, dynamic> json) => WaterHistory(
        baseGoalMl: _i(json['base_goal_ml'], 2500),
        days: [
          for (final d in json['days'] as List? ?? const [])
            if (d is Map<String, dynamic>) WaterHistoryDay.fromJson(d),
        ],
      );

  /// Average over the days with any water logged (0 without any).
  int get averageMl {
    final logged = days.where((d) => d.totalMl > 0).toList();
    if (logged.isEmpty) return 0;
    return (logged.fold<int>(0, (s, d) => s + d.totalMl) / logged.length).round();
  }

  int get daysReached => days.where((d) => d.reached).length;

  /// Goal met this many days in a row, counting back from yesterday (today
  /// still counts when it's already met).
  int get streak {
    var n = 0;
    for (var i = days.length - 1; i >= 0; i--) {
      final d = days[i];
      if (d.reached) {
        n++;
      } else if (i != days.length - 1) {
        break;
      }
    }
    return n;
  }

  /// The highest bar to scale a chart to: the largest total or goal.
  int get peakMl => days.fold<int>(baseGoalMl, (m, d) => [m, d.totalMl, d.goalMl].reduce((a, b) => a > b ? a : b));
}

/// What POST /water-logs answers: the new drink and today with it.
class WaterAdded {
  final WaterEntry entry;
  final WaterDay today;

  const WaterAdded({required this.entry, required this.today});

  factory WaterAdded.fromJson(Map<String, dynamic> json) => WaterAdded(
        entry: WaterEntry.fromJson(json['entry'] as Map<String, dynamic>),
        today: WaterDay.fromJson(json['today'] as Map<String, dynamic>),
      );
}

// ── Reminders ───────────────────────────────────────────────────────────────

/// Local hours a water reminder goes out at: every two hours, 09:00–21:00.
const waterReminderHours = [9, 11, 13, 15, 17, 19, 21];

/// How many days of reminders are scheduled ahead (today included). Each
/// visit to the app reschedules, so they only run out for someone who stops
/// opening it.
const waterReminderDays = 4;

/// One scheduled reminder: [dayOffset] 0 = today.
class WaterReminderSlot {
  final int dayOffset;
  final int hourIndex;
  final DateTime at;

  const WaterReminderSlot({required this.dayOffset, required this.hourIndex, required this.at});

  /// A stable notification id (the same slot always reuses it).
  int get id => waterReminderBaseId + dayOffset * 10 + hourIndex;
}

/// Notification ids [waterReminderBaseId] .. +[waterReminderDays]*10 belong
/// to water reminders.
const waterReminderBaseId = 7100;

/// Every id a water reminder may use (to cancel them all).
Iterable<int> get waterReminderIds sync* {
  for (var d = 0; d < waterReminderDays; d++) {
    for (var h = 0; h < waterReminderHours.length; h++) {
      yield waterReminderBaseId + d * 10 + h;
    }
  }
}

/// The reminders to schedule from [now] (local): today's still-to-come hours
/// unless today's goal is reached, then every hour of the following days.
List<WaterReminderSlot> waterReminderSchedule(DateTime now, {required bool goalReachedToday}) {
  final out = <WaterReminderSlot>[];
  for (var d = 0; d < waterReminderDays; d++) {
    if (d == 0 && goalReachedToday) continue;
    for (var h = 0; h < waterReminderHours.length; h++) {
      // Calendar days (DateTime handles month ends and DST).
      final at = DateTime(now.year, now.month, now.day + d, waterReminderHours[h]);
      if (!at.isAfter(now.add(const Duration(minutes: 1)))) continue;
      out.add(WaterReminderSlot(dayOffset: d, hourIndex: h, at: at));
    }
  }
  return out;
}
