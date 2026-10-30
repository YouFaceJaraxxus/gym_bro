import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/coaching.dart';
import '../models/food_log.dart' show apiDate, dateOnly;
import '../models/meal_plan.dart';
import '../models/routine.dart';
import '../models/user_profile.dart';
import '../pages/classes/class_schedule_page.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../utils/device_timezone.dart';

// Enrolling yourself in a routine or meal plan ("Start this routine"): the
// same for every role. Its planned workouts / meals then show on the Schedule
// calendar. Used by RoutineDetailPage and MealPlanDetailPage, and by the
// "Myself" option of the coach assign flows.

/// Roles that can also assign routines and meal plans to members they coach.
bool isCoachRole(UserRole? role) => const {
  UserRole.owner,
  UserRole.trainer,
  UserRole.employee,
  UserRole.employeeTrainer,
  UserRole.superUser,
}.contains(role);

enum EnrolKind { routine, mealPlan }

String _errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

void _showError(ScaffoldMessengerState messenger, ColorScheme cs, Object e) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(_errorText(e), style: TextStyle(color: cs.onError)),
      backgroundColor: cs.error,
    ),
  );
}

/// "18:00" → 18:00; anything unparsable → null.
TimeOfDay? parseTimeOfDay(String? hhmm) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmm ?? '');
  if (m == null) return null;
  final h = int.parse(m[1]!);
  final min = int.parse(m[2]!);
  if (h > 23 || min > 59) return null;
  return TimeOfDay(hour: h, minute: min);
}

/// 18:05 → "18:05" (the API's format).
String formatTimeOfDay(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Someone's enrolment in a routine or meal plan, whichever it is.
class Enrolment {
  final String id;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? note;
  final String? workoutTime;
  final bool selfAssigned;
  final String? assignedByName;
  final DateTime createdAt;

  const Enrolment({
    required this.id,
    this.startDate,
    this.endDate,
    this.note,
    this.workoutTime,
    this.selfAssigned = true,
    this.assignedByName,
    required this.createdAt,
  });

  factory Enrolment.ofRoutine(RoutineAssignment a) => Enrolment(
    id: a.id,
    startDate: a.startDate,
    endDate: a.endDate,
    note: a.note,
    workoutTime: a.workoutTime,
    selfAssigned: a.assignedById == null || a.isSelfAssigned,
    assignedByName: a.assignedByName,
    createdAt: a.createdAt,
  );

  // Date-only values may come as UTC midnight; keep the calendar date.
  static DateTime? _day(DateTime? d) =>
      d == null ? null : DateTime(d.year, d.month, d.day);

  factory Enrolment.ofMealPlan(MealPlanAssignment a) => Enrolment(
    id: a.id,
    startDate: _day(a.startDate),
    endDate: _day(a.endDate),
    note: a.note,
    selfAssigned: a.assignedById == null || a.isSelfAssigned,
    assignedByName: a.assignedByName,
    createdAt: a.createdAt,
  );

  /// Not over yet on [today].
  bool isActiveOn(DateTime today) =>
      endDate == null || !endDate!.isBefore(dateOnly(today));
}

/// The enrolment to show: the most recently started one that isn't over.
Enrolment? currentEnrolment(List<Enrolment> all, DateTime today) {
  final active = all.where((e) => e.isActiveOn(today)).toList()
    ..sort(
      (a, b) =>
          (b.startDate ?? b.createdAt).compareTo(a.startDate ?? a.createdAt),
    );
  return active.firstOrNull;
}

// ── Flows ─────────────────────────────────────────────────────────────────────

/// Enrols me in [routine] (dates, workout time, note). True when enrolled.
Future<bool> showSelfEnrolRoutine(
  BuildContext context, {
  required Routine routine,
}) => _enrol(
  context,
  kind: EnrolKind.routine,
  targetId: routine.id,
  name: routine.name,
  scheduled: routine.scheduleType == RoutineScheduleType.fixedWeeks,
);

/// Enrols me in [plan] (dates, note). True when enrolled.
Future<bool> showSelfEnrolMealPlan(
  BuildContext context, {
  required MealPlan plan,
}) => _enrol(
  context,
  kind: EnrolKind.mealPlan,
  targetId: plan.id,
  name: plan.name,
  scheduled: true,
);

Future<bool> _enrol(
  BuildContext context, {
  required EnrolKind kind,
  required String targetId,
  required String name,
  required bool scheduled,
}) async {
  final options = await showDialog<EnrolOptions>(
    context: context,
    builder: (_) => EnrolDialog(kind: kind, name: name, scheduled: scheduled),
  );
  if (options == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  final cs = Theme.of(context).colorScheme;
  final l10n = context.l10n;
  try {
    final token = await AuthManager.instance.getValidToken();
    await AuthManager.instance.ensureProfile();
    final me = AuthManager.instance.profile;
    if (me == null) throw Exception(l10n.commonSomethingWentWrong);
    final tz = await deviceTimezone();
    final api = ApiService();
    final body = {
      'user_id': me.id,
      'start_date': apiDate(options.startDate),
      if (options.endDate != null) 'end_date': apiDate(options.endDate!),
      if (options.note.isNotEmpty) 'note': options.note,
      'timezone': ?tz,
    };
    if (kind == EnrolKind.routine) {
      await api.createRoutineAssignment(token, {
        'routine_id': targetId,
        ...body,
        if (scheduled) 'workout_time': formatTimeOfDay(options.workoutTime),
      });
    } else {
      await api.createMealPlanAssignment(token, {
        'meal_plan_id': targetId,
        ...body,
      });
    }
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.planEnrolStarted(name))),
    );
    return true;
  } catch (e) {
    _showError(messenger, cs, e);
    return false;
  }
}

/// Changes dates, workout time or note of [enrolment]. True when saved.
Future<bool> showManageEnrolment(
  BuildContext context, {
  required EnrolKind kind,
  required Enrolment enrolment,
  required String name,
  required bool scheduled,
}) async {
  final options = await showDialog<EnrolOptions>(
    context: context,
    builder: (_) => EnrolDialog(
      kind: kind,
      name: name,
      scheduled: scheduled,
      existing: enrolment,
    ),
  );
  if (options == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  final cs = Theme.of(context).colorScheme;
  final l10n = context.l10n;
  try {
    final token = await AuthManager.instance.getValidToken();
    final tz = await deviceTimezone();
    final api = ApiService();
    final body = {
      'start_date': apiDate(options.startDate),
      'end_date': options.endDate == null ? null : apiDate(options.endDate!),
      'note': options.note,
      'timezone': ?tz,
    };
    if (kind == EnrolKind.routine) {
      await api.updateRoutineAssignment(token, enrolment.id, {
        ...body,
        if (scheduled) 'workout_time': formatTimeOfDay(options.workoutTime),
      });
    } else {
      await api.updateMealPlanAssignment(token, enrolment.id, body);
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.planEnrolUpdated)));
    return true;
  } catch (e) {
    _showError(messenger, cs, e);
    return false;
  }
}

/// Confirms and ends [enrolment] (DELETE). True when left.
Future<bool> confirmLeaveEnrolment(
  BuildContext context, {
  required EnrolKind kind,
  required Enrolment enrolment,
  required String name,
}) async {
  final l10n = context.l10n;
  final cs = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.planEnrolLeaveTitle(name)),
      content: Text(
        kind == EnrolKind.routine
            ? l10n.planEnrolLeaveRoutineBody
            : l10n.planEnrolLeavePlanBody,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: cs.error),
          child: Text(l10n.planEnrolLeave),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final token = await AuthManager.instance.getValidToken();
    final api = ApiService();
    if (kind == EnrolKind.routine) {
      await api.deleteRoutineAssignment(token, enrolment.id);
    } else {
      await api.deleteMealPlanAssignment(token, enrolment.id);
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.planEnrolLeft(name))));
    return true;
  } catch (e) {
    _showError(messenger, cs, e);
    return false;
  }
}

// ── Dialog ────────────────────────────────────────────────────────────────────

class EnrolOptions {
  final DateTime startDate;
  final DateTime? endDate;
  final TimeOfDay workoutTime;
  final String note;

  const EnrolOptions({
    required this.startDate,
    this.endDate,
    required this.workoutTime,
    required this.note,
  });
}

/// Start (or, with [existing], change) an enrolment: start date, optional
/// end date, workout time for scheduled routines, note.
class EnrolDialog extends StatefulWidget {
  const EnrolDialog({
    super.key,
    required this.kind,
    required this.name,
    required this.scheduled,
    this.existing,
  });

  final EnrolKind kind;
  final String name;

  /// Fixed-weeks routines and meal plans put entries on the calendar;
  /// wildcard routines don't.
  final bool scheduled;
  final Enrolment? existing;

  @override
  State<EnrolDialog> createState() => _EnrolDialogState();
}

class _EnrolDialogState extends State<EnrolDialog> {
  late DateTime _start = widget.existing?.startDate ?? dateOnly(DateTime.now());
  late DateTime? _end = widget.existing?.endDate;
  late TimeOfDay _time =
      parseTimeOfDay(widget.existing?.workoutTime) ??
      const TimeOfDay(hour: 18, minute: 0);
  late final _note = TextEditingController(text: widget.existing?.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(d);

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _start = picked;
      if (_end != null && _end!.isBefore(picked)) _end = null;
    });
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? _start,
      firstDate: _start,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) setState(() => _end = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final routine = widget.kind == EnrolKind.routine;
    final hint = !widget.scheduled
        ? l10n.planEnrolWildcardHint
        : routine
        ? l10n.planEnrolRoutineHint
        : l10n.planEnrolMealHint;
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? l10n.planEnrolDialogTitle(widget.name)
            : l10n.planEnrolManageTitle(widget.name),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  widget.scheduled
                      ? Icons.event_available_outlined
                      : Icons.info_outline,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hint,
                    style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l10n.planEnrolStartDate),
              subtitle: Text(_fmt(_start)),
              onTap: _pickStart,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy_outlined),
              title: Text(l10n.planEnrolEndDate),
              subtitle: Text(_end == null ? l10n.planEnrolNoEnd : _fmt(_end!)),
              onTap: _pickEnd,
              trailing: _end == null
                  ? null
                  : IconButton(
                      tooltip: l10n.planEnrolClearEnd,
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _end = null),
                    ),
            ),
            if (routine && widget.scheduled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(l10n.planEnrolWorkoutTime),
                subtitle: Text(_time.format(context)),
                onTap: _pickTime,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(labelText: l10n.planEnrolNote),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            EnrolOptions(
              startDate: _start,
              endDate: _end,
              workoutTime: _time,
              note: _note.text.trim(),
            ),
          ),
          child: Text(
            widget.existing == null ? l10n.planEnrolStart : l10n.commonSave,
          ),
        ),
      ],
    );
  }
}

// ── Card on the detail pages ──────────────────────────────────────────────────

/// "Start this routine / meal plan" for whoever may follow it, or — once I'm
/// enrolled — that state with Manage, Leave and a shortcut to the Schedule.
/// Hidden when I'm not enrolled and can't enrol (someone else's private one).
class EnrolmentCard extends StatefulWidget {
  const EnrolmentCard({
    super.key,
    required this.kind,
    required this.targetId,
    required this.name,
    required this.canEnrol,
    required this.scheduled,
    this.onChanged,
  });

  final EnrolKind kind;
  final String targetId;
  final String name;
  final bool canEnrol;
  final bool scheduled;

  /// After starting, changing or leaving.
  final VoidCallback? onChanged;

  @override
  State<EnrolmentCard> createState() => _EnrolmentCardState();
}

class _EnrolmentCardState extends State<EnrolmentCard> {
  final _api = ApiService();
  Enrolment? _current;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      await AuthManager.instance.ensureProfile();
      final me = AuthManager.instance.profile;
      if (me == null) return;
      final all = widget.kind == EnrolKind.routine
          ? (await _api.getRoutineAssignments(
              token,
              userId: me.id,
              routineId: widget.targetId,
            )).map(Enrolment.ofRoutine).toList()
          : (await _api.getMealPlanAssignments(
              token,
              userId: me.id,
              mealPlanId: widget.targetId,
            )).map(Enrolment.ofMealPlan).toList();
      if (!mounted) return;
      setState(() => _current = currentEnrolment(all, DateTime.now()));
    } catch (_) {
      // Without it the page still works; the card just offers to start.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _after(Future<bool> action) async {
    if (!await action || !mounted) return;
    widget.onChanged?.call();
    await _load();
  }

  Future<void> _start() async {
    final kind = widget.kind;
    await _after(
      _enrol(
        context,
        kind: kind,
        targetId: widget.targetId,
        name: widget.name,
        scheduled: widget.scheduled,
      ),
    );
  }

  void _openSchedule() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClassSchedulePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final routine = widget.kind == EnrolKind.routine;
    final current = _current;
    if (_loading) return const SizedBox.shrink();
    if (current == null && !widget.canEnrol) return const SizedBox.shrink();

    if (current == null) {
      return Card(
        margin: const EdgeInsets.only(top: 16),
        color: cs.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                !widget.scheduled
                    ? l10n.planEnrolWildcardHint
                    : routine
                    ? l10n.planEnrolRoutineHint
                    : l10n.planEnrolMealHint,
                style: ts.bodyMedium?.copyWith(color: cs.onSecondaryContainer),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  routine
                      ? l10n.planEnrolStartRoutine
                      : l10n.planEnrolStartPlan,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final fmt = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    final time = parseTimeOfDay(current.workoutTime);
    final lines = [
      [
        if (current.startDate != null)
          l10n.planEnrolSince(fmt.format(current.startDate!)),
        if (current.endDate != null)
          l10n.planEnrolUntil(fmt.format(current.endDate!)),
      ].join(' · '),
      if (routine && widget.scheduled && time != null)
        l10n.planEnrolWorkoutsAt(time.format(context)),
      if (routine && !widget.scheduled) l10n.planEnrolNoCalendar,
      if (!current.selfAssigned && current.assignedByName != null)
        l10n.planEnrolAssignedBy(current.assignedByName!),
      if (current.note != null && current.note!.isNotEmpty) current.note!,
    ].where((s) => s.isNotEmpty).toList();

    return Card(
      margin: const EdgeInsets.only(top: 16),
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: cs.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    routine ? l10n.planEnrolledRoutine : l10n.planEnrolledPlan,
                    style: ts.titleSmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 2),
                child: Text(
                  line,
                  style: ts.bodySmall?.copyWith(color: cs.onPrimaryContainer),
                ),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (widget.scheduled)
                  TextButton.icon(
                    onPressed: _openSchedule,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(l10n.planEnrolOpenSchedule),
                  ),
                TextButton.icon(
                  onPressed: () => _after(
                    showManageEnrolment(
                      context,
                      kind: widget.kind,
                      enrolment: current,
                      name: widget.name,
                      scheduled: widget.scheduled,
                    ),
                  ),
                  icon: const Icon(Icons.tune),
                  label: Text(l10n.planEnrolManage),
                ),
                TextButton.icon(
                  onPressed: () => _after(
                    confirmLeaveEnrolment(
                      context,
                      kind: widget.kind,
                      enrolment: current,
                      name: widget.name,
                    ),
                  ),
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.planEnrolLeave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
