// Planned workouts and meals on the calendar (GET /plan-entries), generated
// from the routines and meal plans someone is enrolled in.
import 'food_log.dart';
import 'link_access.dart';
import 'meal_plan.dart';

// Postgres numeric / count columns may arrive as JSON strings.
double _d(dynamic v) => v == null ? 0 : double.parse(v.toString());
int _i(dynamic v, [int fallback = 0]) =>
    v == null ? fallback : (int.tryParse(v.toString()) ?? fallback);

DateTime? _instant(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

enum PlanEntryKind {
  workout,
  meal;

  static PlanEntryKind fromApiValue(String? v) => v == 'meal' ? meal : workout;
}

/// planned → still to do; done → logged (a session, or food linked to it);
/// skipped → the user skipped it.
enum PlanEntryStatus {
  planned,
  done,
  skipped;

  static PlanEntryStatus fromApiValue(String? v) => switch (v) {
    'done' => done,
    'skipped' => skipped,
    _ => planned,
  };
}

/// The enrolment an entry came from: still on, left by the user, taken off
/// it by whoever assigned it, ended some other way, or the routine / meal plan
/// itself deleted. Entries (and what was logged) outlive all of these.
enum PlanSourceStatus {
  active,
  left,
  removed,
  ended,
  deleted;

  static PlanSourceStatus fromApiValue(String? v) => switch (v) {
    'left' => left,
    'removed' => removed,
    'ended' => ended,
    'deleted' => deleted,
    _ => active,
  };
}

/// One planned workout or meal. Times are local.
class PlanEntry {
  final String id;
  final String userId;
  final PlanEntryKind kind;
  final PlanEntryStatus status;
  final DateTime startsAt;
  final DateTime endsAt;
  final int durationMinutes;

  /// The day it was generated for (local date at midnight).
  final DateTime planDate;
  final String? note;
  final bool edited;
  final bool skipped;

  // Workouts
  final String? trainingId;
  final String? trainingName;
  final String? routineAssignmentId;
  final String? routineId;
  final String? routineName;

  /// The latest session logged against it, if any.
  final String? trainingSessionId;

  // Meals
  final String? mealPlanAssignmentId;
  final String? mealPlanId;
  final String? mealPlanName;
  final String? dailyMealPlanId;
  final String? dailyMealPlanName;
  final MealSlotType? mealSlot;

  /// Food log entries linked to it.
  final int loggedCount;

  final PlanSourceStatus sourceStatus;

  /// When the enrolment ended (left or removed).
  final DateTime? leftAt;

  /// Whether the viewer can open the routine / meal plan, the training (workouts)
  /// and the day plan (meals); null when the entry has no such link.
  final LinkAccess? sourceAccess;
  final LinkAccess? trainingAccess;
  final LinkAccess? dailyMealPlanAccess;

  const PlanEntry({
    required this.id,
    required this.userId,
    required this.kind,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.durationMinutes,
    required this.planDate,
    this.note,
    this.edited = false,
    this.skipped = false,
    this.trainingId,
    this.trainingName,
    this.routineAssignmentId,
    this.routineId,
    this.routineName,
    this.trainingSessionId,
    this.mealPlanAssignmentId,
    this.mealPlanId,
    this.mealPlanName,
    this.dailyMealPlanId,
    this.dailyMealPlanName,
    this.mealSlot,
    this.loggedCount = 0,
    this.sourceStatus = PlanSourceStatus.active,
    this.leftAt,
    this.sourceAccess,
    this.trainingAccess,
    this.dailyMealPlanAccess,
  });

  factory PlanEntry.fromJson(Map<String, dynamic> json) {
    final start = _instant(json['starts_at']) ?? DateTime.now();
    final minutes = _i(json['duration_minutes'], 60);
    final slot = json['meal_slot'] as String?;
    return PlanEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      kind: PlanEntryKind.fromApiValue(json['kind'] as String?),
      status: PlanEntryStatus.fromApiValue(json['status'] as String?),
      startsAt: start,
      endsAt:
          _instant(json['ends_at']) ?? start.add(Duration(minutes: minutes)),
      durationMinutes: minutes,
      planDate: json['plan_date'] != null
          ? parseApiDate(json['plan_date'] as String)
          : dateOnly(start),
      note: json['note'] as String?,
      edited: json['edited'] as bool? ?? false,
      skipped: json['skipped'] as bool? ?? false,
      trainingId: json['training_id'] as String?,
      trainingName: json['training_name'] as String?,
      routineAssignmentId: json['routine_assignment_id'] as String?,
      routineId: json['routine_id'] as String?,
      routineName: json['routine_name'] as String?,
      trainingSessionId: json['training_session_id'] as String?,
      mealPlanAssignmentId: json['meal_plan_assignment_id'] as String?,
      mealPlanId: json['meal_plan_id'] as String?,
      mealPlanName: json['meal_plan_name'] as String?,
      dailyMealPlanId: json['daily_meal_plan_id'] as String?,
      dailyMealPlanName: json['daily_meal_plan_name'] as String?,
      mealSlot: slot == null ? null : MealSlotType.fromApiValue(slot),
      loggedCount: _i(json['logged_count']),
      sourceStatus: PlanSourceStatus.fromApiValue(
        json['source_status'] as String?,
      ),
      leftAt: _instant(json['left_at']),
      sourceAccess: LinkAccess.tryParse(json['source_access']),
      trainingAccess: LinkAccess.tryParse(json['training_access']),
      dailyMealPlanAccess: LinkAccess.tryParse(json['daily_meal_plan_access']),
    );
  }

  bool get isWorkout => kind == PlanEntryKind.workout;
  bool get isMeal => kind == PlanEntryKind.meal;

  /// The routine or meal plan it comes from.
  String? get sourceName => isWorkout ? routineName : mealPlanName;
}

/// A food log linked to a planned meal (GET /plan-entries/:id).
class PlanEntryLog {
  final String id;
  final String name;
  final double amount;
  final MacroTotals macros;
  final DateTime? eatenAt;

  const PlanEntryLog({
    required this.id,
    required this.name,
    required this.amount,
    required this.macros,
    this.eatenAt,
  });

  factory PlanEntryLog.fromJson(Map<String, dynamic> json) => PlanEntryLog(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Item',
    amount: _d(json['amount']),
    macros: MacroTotals.fromJson(json),
    eatenAt: _instant(json['eaten_at']),
  );
}

/// An exercise of a planned workout's training, in order.
class PlanEntryExercise {
  final String id;
  final String name;

  /// training_set.type ('normal', 'superset', …).
  final String? setType;
  final int dropCount;

  const PlanEntryExercise({
    required this.id,
    required this.name,
    this.setType,
    this.dropCount = 0,
  });

  factory PlanEntryExercise.fromJson(Map<String, dynamic> json) =>
      PlanEntryExercise(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        setType: json['set_type'] as String?,
        dropCount: _i(json['drop_count']),
      );
}

/// A session logged against a planned workout.
class PlanEntrySession {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;

  const PlanEntrySession({
    required this.id,
    required this.startedAt,
    this.endedAt,
  });

  factory PlanEntrySession.fromJson(Map<String, dynamic> json) =>
      PlanEntrySession(
        id: json['id'] as String,
        startedAt: _instant(json['started_at']) ?? DateTime.now(),
        endedAt: _instant(json['ended_at']),
      );
}

/// GET /plan-entries/:id — the entry plus what's planned and what was logged.
class PlanEntryDetail {
  final PlanEntry entry;

  /// Meals: the slot's planned items (with macros) and its note.
  final List<PlannedEntry> items;
  final String? slotNote;
  final List<PlanEntryLog> logs;

  /// Workouts: the training's exercises and the sessions logged against it.
  final List<PlanEntryExercise> exercises;
  final List<PlanEntrySession> sessions;

  const PlanEntryDetail({
    required this.entry,
    this.items = const [],
    this.slotNote,
    this.logs = const [],
    this.exercises = const [],
    this.sessions = const [],
  });

  factory PlanEntryDetail.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        (json[key] as List<dynamic>? ?? [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();
    return PlanEntryDetail(
      entry: PlanEntry.fromJson(json),
      items: list('items', PlannedEntry.fromJson),
      slotNote: json['slot_note'] as String?,
      logs: list('logs', PlanEntryLog.fromJson),
      exercises: list('exercises', PlanEntryExercise.fromJson),
      sessions: list('sessions', PlanEntrySession.fromJson),
    );
  }

  MacroTotals get plannedMacros =>
      items.fold(MacroTotals.zero, (sum, e) => sum + e.macros);

  MacroTotals get loggedMacros =>
      logs.fold(MacroTotals.zero, (sum, e) => sum + e.macros);
}

// ── Meal slot times ───────────────────────────────────────────────────────────

/// When a meal slot usually happens (the server plans meals at these times)
/// and how long it lasts.
({int hour, int minute, int minutes}) usualSlotTime(MealSlotType slot) =>
    switch (slot) {
      MealSlotType.breakfast => (hour: 8, minute: 0, minutes: 30),
      MealSlotType.morningSnack => (hour: 10, minute: 30, minutes: 15),
      MealSlotType.lunch => (hour: 13, minute: 0, minutes: 45),
      MealSlotType.afternoonSnack => (hour: 16, minute: 0, minutes: 15),
      MealSlotType.preWorkout => (hour: 17, minute: 0, minutes: 15),
      MealSlotType.postWorkout => (hour: 19, minute: 30, minutes: 15),
      MealSlotType.dinner => (hour: 20, minute: 0, minutes: 45),
      MealSlotType.eveningSnack => (hour: 21, minute: 30, minutes: 15),
    };

/// The meal slot a meal eaten at [hour] most likely belongs to (pre/post
/// workout are never guessed).
MealSlotType mealSlotForHour(int hour) => switch (hour) {
  >= 5 && < 10 => MealSlotType.breakfast,
  >= 10 && < 12 => MealSlotType.morningSnack,
  >= 12 && < 15 => MealSlotType.lunch,
  >= 15 && < 18 => MealSlotType.afternoonSnack,
  >= 18 && < 21 => MealSlotType.dinner,
  _ => MealSlotType.eveningSnack,
};
