import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/food_log.dart';
import '../../models/meal_plan.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'add_food_log_page.dart';
import 'nutrition_widgets.dart';

/// Daily food diary. [userId] null (or the caller's own id) = my diary,
/// editable; anyone else's diary (coach view) is read-only.
class FoodDiaryPage extends StatefulWidget {
  final String? userId;
  final String? displayName;

  const FoodDiaryPage({super.key, this.userId, this.displayName});

  @override
  State<FoodDiaryPage> createState() => _FoodDiaryPageState();
}

/// Slots always shown (others appear once they have entries or are planned).
const _defaultSlots = {
  MealSlotType.breakfast,
  MealSlotType.lunch,
  MealSlotType.afternoonSnack,
  MealSlotType.dinner,
};

class _FoodDiaryPageState extends State<FoodDiaryPage> {
  final _api = ApiService();
  DateTime _date = dateOnly(DateTime.now());
  List<FoodLog> _logs = [];
  FoodLogSummary? _summary;
  bool _loading = true;
  String? _error;
  bool _busy = false;
  int _requestId = 0;

  bool get _readOnly {
    final me = AuthManager.instance.profile?.id;
    return widget.userId != null && widget.userId != me;
  }

  bool get _isToday => _date == dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool quiet = false}) async {
    final id = ++_requestId;
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final token = await AuthManager.instance.getValidToken();
      final userId = _readOnly ? widget.userId : null;
      final results = await Future.wait([
        _api.getFoodLogs(token, date: _date, userId: userId),
        _api.getFoodLogSummary(token, _date, userId: userId),
      ]);
      if (!mounted || id != _requestId) return;
      setState(() {
        _logs = results[0] as List<FoodLog>;
        _summary = results[1] as FoodLogSummary;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  void _setDate(DateTime d) {
    setState(() {
      _date = dateOnly(d);
      _logs = [];
      _summary = null;
    });
    _load();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) _setDate(picked);
  }

  String _dateLabel(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final diff = _date.difference(today).inDays;
    if (diff == 0) return context.l10n.commonToday;
    if (diff == -1) return context.l10n.nutritionYesterday;
    if (diff == 1) return context.l10n.nutritionTomorrow;
    return MaterialLocalizations.of(context).formatMediumDate(_date);
  }

  void _showError(Object e) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(errorText(e), style: TextStyle(color: cs.onError)),
      backgroundColor: cs.error,
    ));
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _add(MealSlotType slot) async {
    final logged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddFoodLogPage(date: _date, initialSlot: slot)),
    );
    if (logged == true) _load(quiet: true);
  }

  Future<void> _edit(FoodLog log) async {
    if (!log.canEditAmount) {
      // Item was deleted: only the meal slot can still change.
      final slot = await showModalBottomSheet<MealSlotType>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(ctx.l10n.nutritionMoveToMeal)),
              for (final s in MealSlotType.values)
                ListTile(
                  title: Text(s.label(ctx.l10n)),
                  trailing: s == log.slotType ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        ),
      );
      if (slot == null || slot == log.slotType) return;
      await _update(log, slotType: slot);
      return;
    }
    final result = await showLogAmountSheet(
      context,
      title: log.name,
      subtitle: context.l10n.nutritionEditAmountOrMeal,
      unit: log.unit,
      perUnit: log.perUnit,
      initialAmount: log.amount,
      initialSlot: log.slotType,
      confirmLabel: context.l10n.commonSave,
    );
    if (result == null) return;
    await _update(
      log,
      amount: result.amount != log.amount ? result.amount : null,
      slotType: result.slot != log.slotType ? result.slot : null,
    );
  }

  Future<void> _update(FoodLog log, {double? amount, MealSlotType? slotType}) async {
    if (amount == null && slotType == null) return;
    setState(() => _busy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.updateFoodLog(token, log.id, amount: amount, slotType: slotType);
      await _load(quiet: true);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Deletes on the server; the row is removed from the list in [_onDismissed].
  Future<bool> _delete(FoodLog log) async {
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteFoodLog(token, log.id);
      return true;
    } catch (e) {
      _showError(e);
      return false;
    }
  }

  void _onDismissed(FoodLog log) {
    setState(() => _logs.removeWhere((l) => l.id == log.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.nutritionRemovedItem(log.name))));
    _load(quiet: true); // refresh totals
  }

  Future<void> _logPlanned({MealSlotType? slot}) async {
    final summary = _summary;
    if (summary == null) return;
    // Avoid accidental duplicates when a slot already has entries.
    final alreadyLogged = slot == null
        ? summary.planned.any((p) => p.entries.isNotEmpty && _logs.any((l) => l.slotType == p.slotType))
        : _logs.any((l) => l.slotType == slot);
    if (alreadyLogged) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.nutritionLogPlannedMealsQuestion),
          content: Text(slot == null
              ? ctx.l10n.nutritionLogPlannedAllDuplicateWarning
              : ctx.l10n.nutritionLogPlannedSlotDuplicateWarning(slot.label(ctx.l10n))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.nutritionLogAnyway)),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final created = await _api.logPlannedMeals(token, _date, slotType: slot);
      await _load(quiet: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.nutritionLoggedPlannedItems(created.length)),
        ));
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = _readOnly
        ? (widget.displayName != null ? l10n.nutritionUsersDiary(widget.displayName!) : l10n.nutritionFoodDiary)
        : l10n.nutritionFoodDiary;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!_isToday)
            TextButton(onPressed: () => _setDate(DateTime.now()), child: Text(l10n.commonToday)),
          IconButton(
            tooltip: l10n.nutritionPickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _pickDate,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Column(
            children: [
              _DateBar(
                label: _dateLabel(context),
                onPrev: () => _setDate(_date.subtract(const Duration(days: 1))),
                onNext: () => _setDate(_date.add(const Duration(days: 1))),
                onTap: _pickDate,
              ),
              SizedBox(height: 4, child: _busy ? const LinearProgressIndicator() : null),
            ],
          ),
        ),
      ),
      floatingActionButton: _readOnly || _summary == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : () => _add(_suggestedSlot()),
              icon: const Icon(Icons.add),
              label: Text(l10n.nutritionAddFoodTitle),
            ),
      body: _buildBody(context),
    );
  }

  MealSlotType _suggestedSlot() {
    if (!_isToday) return MealSlotType.breakfast;
    final h = DateTime.now().hour;
    if (h < 11) return MealSlotType.breakfast;
    if (h < 15) return MealSlotType.lunch;
    if (h < 18) return MealSlotType.afternoonSnack;
    return MealSlotType.dinner;
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _summary == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _summary == null) return NutritionErrorView(message: _error!, onRetry: _load);
    final summary = _summary!;

    final visibleSlots = MealSlotType.values.where((s) =>
        _defaultSlots.contains(s) || _logs.any((l) => l.slotType == s) || summary.plannedFor(s) != null);

    return RefreshIndicator(
      onRefresh: () => _load(quiet: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          _SummaryCard(summary: summary),
          if (summary.plan != null) ...[
            const SizedBox(height: 12),
            _PlanBanner(
              plan: summary.plan!,
              canLog: !_readOnly && summary.hasPlannedMeals && !_busy,
              onLogAll: () => _logPlanned(),
            ),
          ],
          if (_readOnly && _logs.isEmpty)
            NutritionEmptyView(
              icon: Icons.restaurant_menu,
              title: context.l10n.nutritionNothingLogged,
              message: context.l10n.nutritionNothingLoggedThisDay,
            ),
          const SizedBox(height: 4),
          for (final slot in visibleSlots)
            if (!_readOnly || _logs.any((l) => l.slotType == slot))
              _SlotSection(
                slot: slot,
                logs: _logs.where((l) => l.slotType == slot).toList(),
                planned: summary.plannedFor(slot),
                readOnly: _readOnly,
                onAdd: () => _add(slot),
                onEdit: _edit,
                onDelete: _delete,
                onDismissed: _onDismissed,
                onLogPlanned: _busy ? null : () => _logPlanned(slot: slot),
              ),
        ],
      ),
    );
  }
}

// ── Date bar ──────────────────────────────────────────────────────────────────

class _DateBar extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTap;

  const _DateBar({required this.label, required this.onPrev, required this.onNext, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(tooltip: context.l10n.nutritionPreviousDay, icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Center(
                child: Text(label, style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
          ),
          IconButton(tooltip: context.l10n.nutritionNextDay, icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final FoodLogSummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final colors = MacroColors.of(context);
    final t = summary.totals;
    final target = summary.targets;
    final l10n = context.l10n;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                KcalRing(eaten: t.kcal, target: target?.kcal, size: 116),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      MacroBar(label: l10n.nutritionProtein, value: t.protein, target: target?.protein, color: colors.protein),
                      const SizedBox(height: 10),
                      MacroBar(label: l10n.nutritionCarbs, value: t.carb, target: target?.carb, color: colors.carb),
                      const SizedBox(height: 10),
                      MacroBar(label: l10n.nutritionFat, value: t.fat, target: target?.fat, color: colors.fat),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              target == null
                  ? l10n.nutritionFiberNoTargets(t.fiber.round())
                  : l10n.nutritionFiberWithTargets(t.fiber.round(), target.fiber.round()),
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanBanner extends StatelessWidget {
  final DiaryPlanInfo plan;
  final bool canLog;
  final VoidCallback onLogAll;

  const _PlanBanner({required this.plan, required this.canLog, required this.onLogAll});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.secondaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.event_note, color: cs.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.mealPlanName,
                      style: text.titleSmall?.copyWith(color: cs.onSecondaryContainer)),
                  Text(
                    plan.dailyMealPlanName != null
                        ? '${plan.dayLabel(l10n)} · ${plan.dailyMealPlanName}'
                        : '${plan.dayLabel(l10n)} · ${l10n.nutritionNothingPlanned}',
                    style: text.bodySmall?.copyWith(color: cs.onSecondaryContainer),
                  ),
                ],
              ),
            ),
            if (canLog)
              TextButton(onPressed: onLogAll, child: Text(l10n.nutritionLogPlannedMeals)),
          ],
        ),
      ),
    );
  }
}

// ── Slot section ──────────────────────────────────────────────────────────────

class _SlotSection extends StatelessWidget {
  final MealSlotType slot;
  final List<FoodLog> logs;
  final PlannedSlot? planned;
  final bool readOnly;
  final VoidCallback onAdd;
  final void Function(FoodLog) onEdit;
  final Future<bool> Function(FoodLog) onDelete;
  final void Function(FoodLog) onDismissed;
  final VoidCallback? onLogPlanned;

  const _SlotSection({
    required this.slot,
    required this.logs,
    required this.planned,
    required this.readOnly,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onDismissed,
    required this.onLogPlanned,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final total = logs.fold(MacroTotals.zero, (s, l) => s + l.macros);
    final l10n = context.l10n;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
              children: [
                Expanded(child: Text(slot.label(l10n), style: text.titleMedium)),
                if (logs.isNotEmpty)
                  Text(l10n.nutritionKcalValue(total.kcal.round()),
                      style: text.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                if (!readOnly)
                  IconButton(
                    tooltip: l10n.nutritionAddToSlot(slot.label(l10n)),
                    icon: const Icon(Icons.add),
                    onPressed: onAdd,
                  )
                else
                  const SizedBox(width: 12, height: 48),
              ],
            ),
          ),
          if (logs.isEmpty && planned == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(l10n.nutritionNothingLogged, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ),
          for (final log in logs)
            readOnly
                ? _LogTile(log: log)
                : Dismissible(
                    key: ValueKey(log.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: cs.errorContainer,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
                    ),
                    confirmDismiss: (_) => onDelete(log),
                    onDismissed: (_) => onDismissed(log),
                    child: _LogTile(log: log, onTap: () => onEdit(log)),
                  ),
          if (logs.isEmpty && planned != null) _PlannedHint(planned: planned!, readOnly: readOnly, onLog: onLogPlanned),
          if (logs.isNotEmpty) const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final FoodLog log;
  final VoidCallback? onTap;

  const _LogTile({required this.log, this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return MergeSemantics(
      child: ListTile(
      onTap: onTap,
      title: Text(log.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(log.amountLabel(l10n)),
          MacroLine(macros: log.macros),
        ],
      ),
      isThreeLine: true,
      trailing: Text(l10n.nutritionKcalValue(log.macros.kcal.round()), style: text.titleSmall),
      ),
    );
  }
}

class _PlannedHint extends StatelessWidget {
  final PlannedSlot planned;
  final bool readOnly;
  final VoidCallback? onLog;

  const _PlannedHint({required this.planned, required this.readOnly, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
      child: Row(
        children: [
          Icon(Icons.event_note_outlined, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.nutritionPlannedSummary(
                planned.entries.map((e) => '${e.name} (${e.amountLabel(l10n)})').join(', '),
                planned.macros.kcal.round(),
              ),
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          if (!readOnly) TextButton(onPressed: onLog, child: Text(l10n.nutritionLogAction)),
        ],
      ),
    );
  }
}
