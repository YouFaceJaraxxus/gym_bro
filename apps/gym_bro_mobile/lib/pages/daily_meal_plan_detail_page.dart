import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'daily_meal_plan_form_page.dart';
import 'nutrition/nutrition_widgets.dart';
import '../widgets/share_post.dart';

class DailyMealPlanDetailPage extends StatefulWidget {
  final String dailyMealPlanId;

  const DailyMealPlanDetailPage({super.key, required this.dailyMealPlanId});

  @override
  State<DailyMealPlanDetailPage> createState() => _DailyMealPlanDetailPageState();
}

class _DailyMealPlanDetailPageState extends State<DailyMealPlanDetailPage> {
  final _api = ApiService();
  DailyMealPlan? _plan;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final plan = await _api.getDailyMealPlan(token, widget.dailyMealPlanId);
      setState(() {
        _plan = plan;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.nutritionDeleteMealPlanTitle),
        content: Text(ctx.l10n.nutritionRemovePermanently(_plan!.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(ctx.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteDailyMealPlan(token, widget.dailyMealPlanId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorText(e), style: TextStyle(color: cs.onError)),
            backgroundColor: cs.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error ?? l10n.commonSomethingWentWrong, style: TextStyle(color: cs.error)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: Text(l10n.commonRetry)),
          ]),
        ),
      );
    }

    final plan = _plan!;
    final profile = AuthManager.instance.profile;
    final isOwner = profile != null && profile.id == plan.authorId;
    final sortedSlots = [...plan.slots]..sort((a, b) => a.position.compareTo(b.position));

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name),
        actions: [
          SharePostButton(target: dailyMealPlanShareTarget(plan)),
          if (isOwner) ...[
            IconButton(
              tooltip: l10n.commonEdit,
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.push<DailyMealPlan>(
                  context,
                  MaterialPageRoute(builder: (_) => DailyMealPlanFormPage(plan: plan)),
                );
                if (updated != null) setState(() => _plan = updated);
              },
            ),
            IconButton(tooltip: l10n.commonDelete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Header
            if (!plan.isPublic) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(l10n.nutritionPrivate, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (plan.description != null && plan.description!.isNotEmpty) ...[
              Text(plan.description!, style: TextStyle(color: cs.onSurface)),
              const SizedBox(height: 16),
            ],

            // Day macro bar
            _DayMacroBar(plan: plan),
            const SizedBox(height: 20),

            // Slots
            if (sortedSlots.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(l10n.nutritionNoMealsYet, style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              )
            else
              ...sortedSlots.map((slot) => _SlotExpansionTile(slot: slot)),
          ],
        ),
      ),
    );
  }
}

// ── Day macro bar ─────────────────────────────────────────────────────────────

class _DayMacroBar extends StatelessWidget {
  final DailyMealPlan plan;

  const _DayMacroBar({required this.plan});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = MacroColors.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            _MacroCell(label: l10n.nutritionKcal, value: plan.kcalTotal.round().toString(), color: colors.kcal),
            _MacroDivider(),
            _MacroCell(label: l10n.nutritionProtein, value: '${plan.proteinTotal.round()}g', color: colors.protein),
            _MacroDivider(),
            _MacroCell(label: l10n.nutritionCarbsShort, value: '${plan.carbTotal.round()}g', color: colors.carb),
            _MacroDivider(),
            _MacroCell(label: l10n.nutritionFat, value: '${plan.fatTotal.round()}g', color: colors.fat),
          ],
        ),
      ),
    );
  }
}

class _MacroCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroCell({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MergeSemantics(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
        ),
      ),
    );
  }
}

class _MacroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: Theme.of(context).colorScheme.outlineVariant, margin: const EdgeInsets.symmetric(horizontal: 4));
  }
}

// ── Slot expansion tile ───────────────────────────────────────────────────────

class _SlotExpansionTile extends StatelessWidget {
  final DailyMealPlanSlot slot;

  const _SlotExpansionTile({required this.slot});

  @override
  Widget build(BuildContext context) {
    final sortedEntries = [...slot.entries]..sort((a, b) => a.position.compareTo(b.position));
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(slot.slotType.label(l10n), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(l10n.nutritionKcalValue(slot.kcalTotal.round()), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        children: sortedEntries.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(l10n.nutritionNoEntries, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ),
              ]
            : sortedEntries.map((entry) => _EntryListTile(entry: entry)).toList(),
      ),
    );
  }
}

class _EntryListTile extends StatelessWidget {
  final DailyMealPlanSlotEntry entry;

  const _EntryListTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return MergeSemantics(
      child: ListTile(
      dense: true,
      title: Text(entry.displayName(l10n), style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: entry.kcal > 0
          ? Text(
              l10n.nutritionKcalValue(entry.kcal.round()),
              style: TextStyle(fontSize: 11, color: muted),
            )
          : null,
      trailing: Text(
        entry.amountLabel(l10n),
        style: TextStyle(fontSize: 12, color: muted),
      ),
      ),
    );
  }
}
