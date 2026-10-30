import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/food_log.dart';
import '../../models/gym_class.dart';
import '../../models/meal_plan.dart';
import '../../models/plan_entry.dart';
import '../../models/training_session.dart';
import '../../theme.dart';
import '../../widgets/calendar_view.dart';

// What the Schedule calendar shows besides classes: logged workouts, planned
// workouts and meals (plan entries) and logged meals, merged so nothing shows
// twice — a planned entry that's done stands in for the session / food it was
// logged with.

/// One block on the Schedule calendar.
sealed class ScheduleItem {
  const ScheduleItem();
}

final class ClassItem extends ScheduleItem {
  const ClassItem(this.gymClass);
  final GymClass gymClass;
}

/// A workout the caller logged (started live or logged afterwards) that
/// isn't shown through a planned workout.
final class WorkoutItem extends ScheduleItem {
  const WorkoutItem(this.session);
  final TrainingSession session;
}

/// A planned workout or meal. When it's done and the session that logged it
/// is loaded, it sits at the session's actual time.
final class PlanItem extends ScheduleItem {
  const PlanItem(this.entry, {this.session});
  final PlanEntry entry;
  final TrainingSession? session;

  DateTime get start => session?.startedAt.toLocal() ?? entry.startsAt;

  DateTime get end {
    final s = session;
    if (s == null) return entry.endsAt;
    final end =
        s.endedAt?.toLocal() ??
        start.add(Duration(minutes: entry.durationMinutes));
    return end.isAfter(start) ? end : start.add(const Duration(minutes: 1));
  }
}

/// Food logged for one meal slot of one day, outside any planned meal.
final class MealLogItem extends ScheduleItem {
  const MealLogItem({
    required this.date,
    required this.slot,
    required this.logs,
    required this.start,
    required this.end,
  });

  final DateTime date;
  final MealSlotType slot;
  final List<FoodLog> logs;
  final DateTime start;
  final DateTime end;

  MacroTotals get macros =>
      logs.fold(MacroTotals.zero, (sum, l) => sum + l.macros);
}

/// Groups food logs per (date, slot). A group sits at its earliest eaten_at,
/// or the slot's usual time when nothing has one, for the slot's usual length.
List<MealLogItem> groupFoodLogs(List<FoodLog> logs) {
  final groups = <(DateTime, MealSlotType), List<FoodLog>>{};
  for (final l in logs) {
    groups.putIfAbsent((dateOnly(l.logDate), l.slotType), () => []).add(l);
  }
  final items = [
    for (final MapEntry(key: (date, slot), value: group) in groups.entries)
      _mealLogItem(date, slot, group),
  ]..sort((a, b) => a.start.compareTo(b.start));
  return items;
}

MealLogItem _mealLogItem(DateTime date, MealSlotType slot, List<FoodLog> logs) {
  final usual = usualSlotTime(slot);
  final eaten = logs.map((l) => l.eatenAt).whereType<DateTime>().toList()
    ..sort();
  final start = eaten.isNotEmpty
      ? eaten.first
      : DateTime(date.year, date.month, date.day, usual.hour, usual.minute);
  return MealLogItem(
    date: date,
    slot: slot,
    logs: logs,
    start: start,
    end: start.add(Duration(minutes: usual.minutes)),
  );
}

/// Everything for one week of the Schedule. Sessions and food logs linked to
/// a loaded plan entry are folded into it; links to entries outside the
/// window show on their own.
List<ScheduleItem> buildScheduleItems({
  List<GymClass> classes = const [],
  List<TrainingSession> sessions = const [],
  List<PlanEntry> entries = const [],
  List<FoodLog> foodLogs = const [],
}) {
  final entryIds = {for (final e in entries) e.id};
  final sessionsById = {for (final s in sessions) s.id: s};
  final sessionByEntry = <String, TrainingSession>{};
  for (final s in sessions) {
    final id = s.planEntryId;
    if (id == null || !entryIds.contains(id)) continue;
    final current = sessionByEntry[id];
    // The latest one, as the API reports.
    if (current == null || s.startedAt.isAfter(current.startedAt)) {
      sessionByEntry[id] = s;
    }
  }
  return [
    for (final c in classes) ClassItem(c),
    for (final s in sessions)
      if (s.planEntryId == null || !entryIds.contains(s.planEntryId))
        WorkoutItem(s),
    for (final e in entries)
      PlanItem(
        e,
        session: e.isWorkout && e.status == PlanEntryStatus.done
            ? (sessionsById[e.trainingSessionId] ?? sessionByEntry[e.id])
            : null,
      ),
    ...groupFoodLogs([
      for (final l in foodLogs)
        if (l.planEntryId == null || !entryIds.contains(l.planEntryId)) l,
    ]),
  ];
}

/// How a plan entry's status looks on the calendar.
CalendarEntryState planEntryCalendarState(PlanEntryStatus status) =>
    switch (status) {
      PlanEntryStatus.planned => CalendarEntryState.upcoming,
      PlanEntryStatus.done => CalendarEntryState.done,
      PlanEntryStatus.skipped => CalendarEntryState.cancelled,
    };

// ── Looks ─────────────────────────────────────────────────────────────────────

/// Workouts are green with a dumbbell, meals amber with a plate.
Color scheduleWorkoutColor(BuildContext context) => context.appColors.success;
Color scheduleMealColor(BuildContext context) => context.appColors.warning;

const scheduleWorkoutIcon = Icons.fitness_center;
const scheduleMealIcon = Icons.restaurant;

/// A planned workout or meal: outlined while planned (it hasn't happened),
/// muted with a check once done, struck through when skipped.
CalendarEntry planCalendarEntry(BuildContext context, PlanItem item) {
  final l10n = context.l10n;
  final e = item.entry;
  final title = e.isWorkout
      ? (e.trainingName ?? l10n.planWorkoutFallback)
      : (e.mealSlot?.label(l10n) ?? l10n.planMealFallback);
  final status = switch (e.status) {
    PlanEntryStatus.planned => l10n.planCalendarPlanned,
    PlanEntryStatus.done => l10n.planCalendarDone,
    PlanEntryStatus.skipped => l10n.planCalendarSkipped,
  };
  final source = e.isWorkout
      ? e.routineName
      : (e.dailyMealPlanName ?? e.mealPlanName);
  final lines = [
    [status, ?source].join(' · '),
    if (e.note != null && e.note!.isNotEmpty) e.note!,
  ];
  final start = item.start;
  final end = item.end;
  return CalendarEntry(
    start: start,
    end: end,
    title: title,
    lines: lines,
    state: planEntryCalendarState(e.status),
    highlighted: false,
    color: e.isWorkout
        ? scheduleWorkoutColor(context)
        : scheduleMealColor(context),
    icon: e.isWorkout ? scheduleWorkoutIcon : scheduleMealIcon,
    semanticLabel: [
      e.isWorkout
          ? l10n.planCalendarWorkoutSemantics(title)
          : l10n.planCalendarMealSemantics(title),
      calendarTimeRange(context, start, end),
      ...lines,
    ].join(', '),
  );
}

/// Food logged for a meal, filled like a logged workout.
CalendarEntry mealLogCalendarEntry(BuildContext context, MealLogItem item) {
  final l10n = context.l10n;
  final title = item.slot.label(l10n);
  final lines = [
    l10n.planMealItemsKcal(item.logs.length, item.macros.kcal.round()),
    item.logs.map((l) => l.name).join(', '),
  ];
  return CalendarEntry(
    start: item.start,
    end: item.end,
    title: title,
    lines: lines,
    color: scheduleMealColor(context),
    icon: scheduleMealIcon,
    semanticLabel: [
      l10n.planCalendarMealSemantics(title),
      calendarTimeRange(context, item.start, item.end),
      ...lines,
    ].join(', '),
  );
}
