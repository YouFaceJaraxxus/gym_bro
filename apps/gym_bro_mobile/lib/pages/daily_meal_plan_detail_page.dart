import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'daily_meal_plan_form_page.dart';

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
        title: const Text('Delete meal plan?'),
        content: Text('Remove "${_plan!.name}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error ?? 'Unknown error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
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
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.push<DailyMealPlan>(
                  context,
                  MaterialPageRoute(builder: (_) => DailyMealPlanFormPage(plan: plan)),
                );
                if (updated != null) setState(() => _plan = updated);
              },
            ),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
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
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('Private', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (plan.description != null && plan.description!.isNotEmpty) ...[
              Text(plan.description!, style: const TextStyle(color: Colors.black87)),
              const SizedBox(height: 16),
            ],

            // Day macro bar
            _DayMacroBar(plan: plan),
            const SizedBox(height: 20),

            // Slots
            if (sortedSlots.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('No meals added yet', style: TextStyle(color: Colors.grey)),
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            _MacroCell(label: 'kcal', value: plan.kcalTotal.round().toString(), color: Colors.orange.shade700),
            _MacroDivider(),
            _MacroCell(label: 'protein', value: '${plan.proteinTotal.round()}g', color: Colors.red.shade400),
            _MacroDivider(),
            _MacroCell(label: 'carbs', value: '${plan.carbTotal.round()}g', color: Colors.amber.shade700),
            _MacroDivider(),
            _MacroCell(label: 'fat', value: '${plan.fatTotal.round()}g', color: Colors.blue.shade400),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _MacroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 4));
  }
}

// ── Slot expansion tile ───────────────────────────────────────────────────────

class _SlotExpansionTile extends StatelessWidget {
  final DailyMealPlanSlot slot;

  const _SlotExpansionTile({required this.slot});

  @override
  Widget build(BuildContext context) {
    final sortedEntries = [...slot.entries]..sort((a, b) => a.position.compareTo(b.position));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(slot.slotType.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${slot.kcalTotal.round()} kcal', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        children: sortedEntries.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text('No entries', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
    return ListTile(
      dense: true,
      title: Text(entry.displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: entry.kcal > 0
          ? Text(
              '${entry.kcal.round()} kcal',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            )
          : null,
      trailing: Text(
        entry.amountLabel,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }
}
