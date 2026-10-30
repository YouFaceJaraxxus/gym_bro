import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/food_log.dart';
import '../../models/meal_plan.dart';
import '../../models/plan_entry.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/link_access_note.dart';
import '../../widgets/training_picker_sheet.dart';
import '../classes/schedule_items.dart';
import '../daily_meal_plan_detail_page.dart';
import '../log_workout_page.dart';
import '../meal_plan_detail_page.dart';
import '../nutrition/add_food_log_page.dart';
import '../nutrition/food_diary_page.dart';
import '../routine_detail_page.dart';
import '../session_detail_page.dart';
import '../training_detail_page.dart';
import '../../widgets/app_bottom_sheet.dart';

// Sheets the Schedule calendar opens: an empty hour (log a workout or a meal
// there), a planned workout or meal (details, confirm, log differently, edit,
// skip) and a logged meal. Each completes with whether something changed, so
// the calendar knows to reload.

String _errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

void _showError(
  ScaffoldMessengerState messenger,
  BuildContext context,
  Object e,
) {
  final cs = Theme.of(context).colorScheme;
  messenger.showSnackBar(
    SnackBar(
      content: Text(_errorText(e), style: TextStyle(color: cs.onError)),
      backgroundColor: cs.error,
    ),
  );
}

String _dayLabel(BuildContext context, DateTime d) {
  final locale = Localizations.localeOf(context).toString();
  return (d.year == DateTime.now().year
          ? DateFormat.MMMEd(locale)
          : DateFormat.yMMMEd(locale))
      .format(d);
}

Future<bool> _logMeal(
  BuildContext context, {
  required DateTime date,
  required MealSlotType slot,
  required DateTime eatenAt,
  String? planEntryId,
}) async {
  final logged = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => AddFoodLogPage(
        date: dateOnly(date),
        initialSlot: slot,
        eatenAt: eatenAt,
        planEntryId: planEntryId,
      ),
    ),
  );
  return logged == true;
}

// ── Empty hour ────────────────────────────────────────────────────────────────

/// Asks whether to log a workout or a meal at [slot] (past or future) and
/// opens that flow. A meal goes to the slot its hour suggests, eaten at [slot].
Future<bool> showLogSlotSheet(BuildContext context, DateTime slot) async {
  final l10n = context.l10n;
  final mealSlot = mealSlotForHour(slot.hour);
  final time = DateFormat.jm(
    Localizations.localeOf(context).toString(),
  ).format(slot);
  final choice = await showAppBottomSheet<PlanEntryKind>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Semantics(
              header: true,
              child: Text(
                '${_dayLabel(ctx, slot)} · $time',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
          ),
          _KindTile(
            kind: PlanEntryKind.workout,
            title: l10n.planLogWorkout,
            subtitle: l10n.planLogWorkoutHint,
            onTap: () => Navigator.pop(ctx, PlanEntryKind.workout),
          ),
          _KindTile(
            kind: PlanEntryKind.meal,
            title: l10n.planLogMeal,
            subtitle: l10n.planLogMealHint(mealSlot.label(l10n)),
            onTap: () => Navigator.pop(ctx, PlanEntryKind.meal),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return false;
  if (choice == PlanEntryKind.meal) {
    return _logMeal(context, date: slot, slot: mealSlot, eatenAt: slot);
  }
  final logged = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LogWorkoutPage(start: slot),
    ),
  );
  return logged == true;
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final PlanEntryKind kind;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = kind == PlanEntryKind.workout
        ? scheduleWorkoutColor(context)
        : scheduleMealColor(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.18),
        foregroundColor: color,
        child: Icon(
          kind == PlanEntryKind.workout
              ? scheduleWorkoutIcon
              : scheduleMealIcon,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// ── Planned workout / meal ────────────────────────────────────────────────────

enum _PlanAction {
  confirm,
  logDifferently,
  edit,
  skip,
  unskip,
  openSession,
  addFood,
  openDiary,
}

/// Details of a planned workout or meal with what can be done with it.
/// A done workout opens the session that logged it instead.
Future<bool> showPlanEntrySheet(BuildContext context, PlanEntry entry) async {
  if (entry.isWorkout &&
      entry.status == PlanEntryStatus.done &&
      entry.trainingSessionId != null) {
    return _runPlanAction(context, entry, _PlanAction.openSession);
  }
  final action = await showAppBottomSheet<_PlanAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _PlanEntrySheet(entry: entry),
  );
  if (action == null || !context.mounted) return false;
  return _runPlanAction(context, entry, action);
}

Future<bool> _runPlanAction(
  BuildContext context,
  PlanEntry entry,
  _PlanAction action,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final api = ApiService();
  final mealSlot = entry.mealSlot ?? mealSlotForHour(entry.startsAt.hour);
  try {
    switch (action) {
      case _PlanAction.confirm:
        final token = await AuthManager.instance.getValidToken();
        await api.confirmPlanEntry(token, entry.id);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              entry.isWorkout
                  ? l10n.planConfirmedWorkout
                  : l10n.planConfirmedMeal,
            ),
          ),
        );
        return true;
      case _PlanAction.logDifferently when entry.isWorkout:
        final logged = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => LogWorkoutPage(
              start: entry.startsAt,
              planEntryId: entry.id,
              initialTrainingId: entry.trainingId,
              initialMinutes: entry.durationMinutes,
            ),
          ),
        );
        return logged == true;
      case _PlanAction.logDifferently || _PlanAction.addFood:
        return _logMeal(
          context,
          date: entry.planDate,
          slot: mealSlot,
          eatenAt: entry.startsAt,
          planEntryId: entry.id,
        );
      case _PlanAction.edit:
        final updated = await Navigator.push<PlanEntry>(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => PlanEntryEditPage(entry: entry),
          ),
        );
        return updated != null;
      case _PlanAction.skip:
        final token = await AuthManager.instance.getValidToken();
        await api.skipPlanEntry(token, entry.id);
        messenger.showSnackBar(SnackBar(content: Text(l10n.planSkippedSnack)));
        return true;
      case _PlanAction.unskip:
        final token = await AuthManager.instance.getValidToken();
        await api.updatePlanEntry(token, entry.id, skipped: false);
        messenger.showSnackBar(SnackBar(content: Text(l10n.planRestoredSnack)));
        return true;
      case _PlanAction.openSession:
        final id = entry.trainingSessionId;
        if (id == null) return false;
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: id)),
        );
        // It may have been edited or deleted there.
        return true;
      case _PlanAction.openDiary:
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => FoodDiaryPage(initialDate: entry.planDate),
          ),
        );
        return true;
    }
  } catch (e) {
    if (context.mounted) _showError(messenger, context, e);
    return false;
  }
}

class _PlanEntrySheet extends StatefulWidget {
  const _PlanEntrySheet({required this.entry});

  final PlanEntry entry;

  @override
  State<_PlanEntrySheet> createState() => _PlanEntrySheetState();
}

class _PlanEntrySheetState extends State<_PlanEntrySheet> {
  PlanEntryDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final token = await AuthManager.instance.getValidToken();
      final d = await ApiService().getPlanEntry(token, widget.entry.id);
      if (mounted) setState(() => _detail = d);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final e = _detail?.entry ?? widget.entry;
    final color = e.isWorkout
        ? scheduleWorkoutColor(context)
        : scheduleMealColor(context);
    final title = e.isWorkout
        ? (e.trainingName ?? l10n.planWorkoutFallback)
        : (e.mealSlot?.label(l10n) ?? l10n.planMealFallback);
    final status = switch (e.status) {
      PlanEntryStatus.planned => l10n.planCalendarPlanned,
      PlanEntryStatus.done => l10n.planCalendarDone,
      PlanEntryStatus.skipped => l10n.planCalendarSkipped,
    };

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.18),
                foregroundColor: color,
                child: Icon(
                  e.isWorkout ? scheduleWorkoutIcon : scheduleMealIcon,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: ts.titleLarge),
                    ),
                    Text(
                      '${_dayLabel(context, e.startsAt)} · ${calendarTimeRange(context, e.startsAt, e.endsAt)}',
                      style: ts.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(
                avatar: Icon(switch (e.status) {
                  PlanEntryStatus.planned => Icons.schedule,
                  PlanEntryStatus.done => Icons.check_circle,
                  PlanEntryStatus.skipped => Icons.event_busy,
                }, size: 18),
                label: Text(status),
                visualDensity: VisualDensity.compact,
              ),
              if (e.edited)
                Chip(
                  avatar: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l10n.planEditedBadge),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (e.note != null && e.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(e.note!, style: ts.bodyMedium),
          ],
          if (_sourceStatusText(context, e) case final text?) ...[
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(child: Text(text, style: ts.bodyMedium)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          ..._buildLinks(context, e),
          const SizedBox(height: 8),
          ..._buildDetail(context, e),
          const SizedBox(height: 20),
          ..._buildActions(context, e),
        ],
      ),
    );
  }

  /// Why the routine / meal plan no longer drives this entry, if it doesn't.
  String? _sourceStatusText(BuildContext context, PlanEntry e) {
    final l10n = context.l10n;
    final date = e.leftAt == null ? '' : _dayLabel(context, e.leftAt!);
    return switch (e.sourceStatus) {
      PlanSourceStatus.active => null,
      PlanSourceStatus.left =>
        e.isWorkout ? l10n.planLeftRoutine(date) : l10n.planLeftMealPlan(date),
      PlanSourceStatus.removed =>
        e.isWorkout ? l10n.planRemovedRoutine(date) : l10n.planRemovedMealPlan(date),
      PlanSourceStatus.deleted =>
        e.isWorkout ? l10n.planDeletedRoutine : l10n.planDeletedMealPlan,
      PlanSourceStatus.ended => l10n.planEndedSource,
    };
  }

  /// The routine / meal plan and the workout / day plan this entry is from:
  /// each opens its page while the viewer has access, otherwise says why not.
  List<Widget> _buildLinks(BuildContext context, PlanEntry e) {
    final l10n = context.l10n;
    final links = e.isWorkout
        ? [
            (l10n.planLinkRoutine, e.routineName, e.sourceAccess, e.routineId,
                (String id) => RoutineDetailPage(routineId: id)),
            (l10n.planLinkWorkout, e.trainingName, e.trainingAccess, e.trainingId,
                (String id) => TrainingDetailPage(trainingId: id)),
          ]
        : [
            (l10n.planLinkMealPlan, e.mealPlanName, e.sourceAccess, e.mealPlanId,
                (String id) => MealPlanDetailPage(mealPlanId: id)),
            (l10n.planLinkDayPlan, e.dailyMealPlanName, e.dailyMealPlanAccess, e.dailyMealPlanId,
                (String id) => DailyMealPlanDetailPage(dailyMealPlanId: id)),
          ];
    return [
      for (final (label, name, access, id, page) in links)
        if (name != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(name),
            subtitle: access == null || access.canOpen
                ? Text(label)
                : LinkAccessNote(access: access, dense: true),
            trailing: id != null && (access?.canOpen ?? false)
                ? const Icon(Icons.chevron_right)
                : null,
            onTap: id != null && (access?.canOpen ?? false)
                ? () => Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => page(id)),
                  )
                : null,
          ),
    ];
  }

  List<Widget> _buildDetail(BuildContext context, PlanEntry e) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final d = _detail;
    if (d == null) {
      return [
        if (_error != null)
          Row(
            children: [
              Expanded(
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
              TextButton(onPressed: _load, child: Text(l10n.commonRetry)),
            ],
          )
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
      ];
    }
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: ts.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );

    if (e.isWorkout) {
      return [
        heading(l10n.planExercises),
        if (d.exercises.isEmpty)
          Text(
            l10n.planNoExercises,
            style: TextStyle(color: cs.onSurfaceVariant),
          )
        else
          for (final (i, x) in d.exercises.indexed)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 12,
                child: Text('${i + 1}', style: ts.labelSmall),
              ),
              title: Text(x.name),
            ),
      ];
    }

    final planned = d.plannedMacros;
    return [
      heading(l10n.planPlannedItems),
      if (d.items.isEmpty)
        Text(l10n.planNoItems, style: TextStyle(color: cs.onSurfaceVariant))
      else ...[
        for (final item in d.items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(item.name),
            subtitle: Text(
              '${item.amountLabel(l10n)} · ${item.macros.pcfLabel(l10n)}',
            ),
            trailing: Text(l10n.nutritionKcalValue(item.macros.kcal.round())),
          ),
        Text(
          '${l10n.planTotal}: ${l10n.nutritionKcalValue(planned.kcal.round())} · ${planned.pcfLabel(l10n)}',
          style: ts.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
      if (d.slotNote != null && d.slotNote!.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          d.slotNote!,
          style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
      if (d.logs.isNotEmpty) ...[
        const SizedBox(height: 16),
        heading(l10n.planLoggedItems),
        for (final log in d.logs)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(log.name),
            subtitle: Text(log.macros.pcfLabel(l10n)),
            trailing: Text(l10n.nutritionKcalValue(log.macros.kcal.round())),
          ),
      ],
    ];
  }

  List<Widget> _buildActions(BuildContext context, PlanEntry e) {
    final l10n = context.l10n;
    void pop(_PlanAction a) => Navigator.pop(context, a);
    final edit = TextButton.icon(
      onPressed: () => pop(_PlanAction.edit),
      icon: const Icon(Icons.edit_outlined),
      label: Text(l10n.commonEdit),
    );
    switch (e.status) {
      case PlanEntryStatus.planned:
        return [
          FilledButton.icon(
            onPressed: () => pop(_PlanAction.confirm),
            icon: const Icon(Icons.check),
            label: Text(l10n.planConfirm),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => pop(_PlanAction.logDifferently),
            icon: const Icon(Icons.edit_note),
            label: Text(l10n.planLogDifferently),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              edit,
              TextButton.icon(
                onPressed: () => pop(_PlanAction.skip),
                icon: const Icon(Icons.event_busy_outlined),
                label: Text(l10n.planSkip),
              ),
            ],
          ),
        ];
      case PlanEntryStatus.skipped:
        return [
          FilledButton.tonalIcon(
            onPressed: () => pop(_PlanAction.unskip),
            icon: const Icon(Icons.undo),
            label: Text(l10n.planUnskip),
          ),
          const SizedBox(height: 4),
          Align(alignment: AlignmentDirectional.centerStart, child: edit),
        ];
      case PlanEntryStatus.done:
        return [
          if (e.isWorkout)
            FilledButton.tonalIcon(
              onPressed: e.trainingSessionId == null
                  ? null
                  : () => pop(_PlanAction.openSession),
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.planOpenWorkout),
            )
          else ...[
            FilledButton.tonalIcon(
              onPressed: () => pop(_PlanAction.addFood),
              icon: const Icon(Icons.add),
              label: Text(l10n.planAddFood),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => pop(_PlanAction.openDiary),
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(l10n.planOpenDiary),
            ),
          ],
        ];
    }
  }
}

// ── Edit a planned entry ──────────────────────────────────────────────────────

/// Moves a planned workout or meal, changes its length, swaps the training
/// (workouts) or sets a note. Pops with the updated entry.
class PlanEntryEditPage extends StatefulWidget {
  const PlanEntryEditPage({super.key, required this.entry});

  final PlanEntry entry;

  @override
  State<PlanEntryEditPage> createState() => _PlanEntryEditPageState();
}

class _PlanEntryEditPageState extends State<PlanEntryEditPage> {
  static const _durations = [15, 30, 45, 60, 75, 90, 105, 120, 150, 180];

  late DateTime _start = widget.entry.startsAt;
  late int _minutes = widget.entry.durationMinutes;
  late final List<int> _durationChoices = {..._durations, _minutes}.toList()
    ..sort();
  late String? _trainingId = widget.entry.trainingId;
  late String? _trainingName = widget.entry.trainingName;
  late final _note = TextEditingController(text: widget.entry.note ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _start = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _start.hour,
        _start.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _start = DateTime(
        _start.year,
        _start.month,
        _start.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  Future<void> _pickTraining() async {
    final pick = await showTrainingPicker(
      context,
      title: context.l10n.planEditTraining,
    );
    final t = pick?.training;
    if (t == null || !mounted) return;
    setState(() {
      _trainingId = t.id;
      _trainingName = t.name;
    });
  }

  Future<void> _save() async {
    final e = widget.entry;
    final note = _note.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final updated = await ApiService().updatePlanEntry(
        token,
        e.id,
        startsAt: _start == e.startsAt ? null : _start,
        durationMinutes: _minutes == e.durationMinutes ? null : _minutes,
        trainingId: e.isWorkout && _trainingId != e.trainingId
            ? _trainingId
            : null,
        note: note == (e.note ?? '') ? null : note,
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _errorText(err);
      });
    }
  }

  bool get _changed {
    final e = widget.entry;
    return _start != e.startsAt ||
        _minutes != e.durationMinutes ||
        _trainingId != e.trainingId ||
        _note.text.trim() != (e.note ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final e = widget.entry;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          e.isWorkout ? l10n.planEditWorkoutTitle : l10n.planEditMealTitle,
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _changed ? _save : null,
              child: Text(l10n.commonSave),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Row(
              children: [
                Expanded(
                  child: _FieldButton(
                    label: l10n.planEditDate,
                    value: _dayLabel(context, _start),
                    icon: Icons.calendar_today_outlined,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FieldButton(
                    label: l10n.planEditTime,
                    value: DateFormat.jm(locale).format(_start),
                    icon: Icons.schedule,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _minutes,
              decoration: InputDecoration(
                labelText: l10n.planEditDuration,
                prefixIcon: const Icon(Icons.timer_outlined),
              ),
              items: [
                for (final m in _durationChoices)
                  DropdownMenuItem(
                    value: m,
                    child: Text(l10n.workoutLogMinutes(m)),
                  ),
              ],
              onChanged: (v) => setState(() => _minutes = v ?? _minutes),
            ),
            if (e.isWorkout) ...[
              const SizedBox(height: 12),
              _FieldButton(
                label: l10n.planEditTraining,
                value: _trainingName ?? l10n.planWorkoutFallback,
                icon: scheduleWorkoutIcon,
                trailing: const Icon(Icons.swap_horiz),
                onTap: _pickTraining,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(labelText: l10n.planEditNote),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
          ],
        ),
      ),
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: trailing,
        ),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

// ── Logged meal ───────────────────────────────────────────────────────────────

/// What was logged for one meal, with shortcuts to add to it or open the
/// food diary on that day.
Future<bool> showMealLogsSheet(BuildContext context, MealLogItem item) async {
  final l10n = context.l10n;
  final add = await showAppBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final ts = Theme.of(ctx).textTheme;
      final total = item.macros;
      final color = scheduleMealColor(ctx);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.18),
                  foregroundColor: color,
                  child: const Icon(scheduleMealIcon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          item.slot.label(l10n),
                          style: ts.titleLarge,
                        ),
                      ),
                      Text(
                        '${_dayLabel(ctx, item.date)} · ${DateFormat.jm(Localizations.localeOf(ctx).toString()).format(item.start)}',
                        style: ts.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final log in item.logs)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(log.name),
                subtitle: Text(
                  '${log.amountLabel(l10n)} · ${log.macros.pcfLabel(l10n)}',
                ),
                trailing: Text(
                  l10n.nutritionKcalValue(log.macros.kcal.round()),
                ),
              ),
            Text(
              '${l10n.planTotal}: ${l10n.nutritionKcalValue(total.kcal.round())} · ${total.pcfLabel(l10n)}',
              style: ts.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add),
              label: Text(l10n.planAddFood),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, false),
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(l10n.planOpenDiary),
            ),
          ],
        ),
      );
    },
  );
  if (add == null || !context.mounted) return false;
  if (add) {
    return _logMeal(
      context,
      date: item.date,
      slot: item.slot,
      eatenAt: item.start,
    );
  }
  await Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => FoodDiaryPage(initialDate: item.date)),
  );
  return true;
}
