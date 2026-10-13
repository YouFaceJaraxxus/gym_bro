import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/meal_plan_assign.dart';
import 'daily_meal_plan_detail_page.dart';
import 'meal_plan_form_page.dart';

/// Full meal plan: weeks → days → daily plans. Pops with `true` when the plan
/// was edited or deleted so lists can refresh.
class MealPlanDetailPage extends StatefulWidget {
  final String mealPlanId;

  const MealPlanDetailPage({super.key, required this.mealPlanId});

  @override
  State<MealPlanDetailPage> createState() => _MealPlanDetailPageState();
}

class _MealPlanDetailPageState extends State<MealPlanDetailPage> {
  final _api = ApiService();
  MealPlan? _plan;
  bool _loading = true;
  String? _error;
  bool _changed = false;

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
      final plan = await _api.getMealPlan(token, widget.mealPlanId);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<MealPlan>(
      context,
      MaterialPageRoute(builder: (_) => MealPlanFormPage(plan: _plan)),
    );
    if (updated != null && mounted) {
      setState(() {
        _plan = updated;
        _changed = true;
      });
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete meal plan?'),
        content: Text(
            'Remove "${_plan!.name}" permanently? Any assignments of this plan are removed too.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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
      await _api.deleteMealPlan(token, widget.mealPlanId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assign() async {
    final plan = _plan;
    if (plan == null) return;
    final ok = await showAssignMealPlanFlow(context, plan: plan);
    if (ok) _changed = true;
  }

  void _openDay(MealPlanDay day) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DailyMealPlanDetailPage(dailyMealPlanId: day.dailyMealPlanId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    if (_loading && _plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Unknown error',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final plan = _plan!;
    final profile = AuthManager.instance.profile;
    final isSuper = profile?.role == UserRole.superUser;
    final isAuthor =
        profile != null && plan.authorId != null && profile.id == plan.authorId;
    final canEdit = isSuper || (isAuthor && !plan.isSystem);

    final plannedDays = plan.days.where((d) => d.dailyMealPlan != null).toList();
    double avg(double Function(DailyMealPlan d) f) => plannedDays.isEmpty
        ? 0
        : plannedDays.map((d) => f(d.dailyMealPlan!)).reduce((a, b) => a + b) /
            plannedDays.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name),
        actions: [
          IconButton(
            tooltip: 'Assign',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: _assign,
          ),
          if (canEdit) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit),
              onPressed: _edit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _assign,
        icon: const Icon(Icons.assignment_ind_outlined),
        label: const Text('Assign'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            // Images
            if (plan.images.length == 1)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  plan.images.first.url,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                ),
              )
            else if (plan.images.length > 1)
              SizedBox(
                height: 200,
                child: PageView(
                  controller: PageController(viewportFraction: 0.92),
                  children: ([...plan.images]
                        ..sort((a, b) => a.position.compareTo(b.position)))
                      .map((img) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                img.url,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            if (plan.images.isNotEmpty) const SizedBox(height: 20),

            // Meta row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(
                    plan.weeksLabel,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: Colors.blue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                if (!plan.isPublic) const _Badge(icon: Icons.lock_outline, label: 'Private'),
                if (plan.isSystem) const _Badge(icon: Icons.verified_outlined, label: 'System'),
                if (isAuthor) const _Badge(icon: Icons.person_outline, label: 'Yours'),
              ],
            ),

            // Description
            if (plan.description != null && plan.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(plan.description!),
            ],

            // Average macros
            if (plannedDays.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily average · ${plannedDays.length} planned day${plannedDays.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Macro(
                              label: 'kcal',
                              value: avg((d) => d.kcalTotal).round().toString()),
                          _Macro(
                              label: 'Protein',
                              value:
                                  '${avg((d) => d.proteinTotal).toStringAsFixed(0)}g'),
                          _Macro(
                              label: 'Carbs',
                              value:
                                  '${avg((d) => d.carbTotal).toStringAsFixed(0)}g'),
                          _Macro(
                              label: 'Fat',
                              value:
                                  '${avg((d) => d.fatTotal).toStringAsFixed(0)}g'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Week schedule
            const SizedBox(height: 24),
            const Text(
              'Schedule',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...List.generate(plan.numWeeks, (wi) {
              final weekNum = wi + 1;
              return _WeekTile(
                weekNumber: weekNum,
                days: plan.days,
                initiallyExpanded: wi == 0,
                onDayTap: _openDay,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final String value;

  const _Macro({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _WeekTile extends StatelessWidget {
  final int weekNumber;
  final List<MealPlanDay> days;
  final bool initiallyExpanded;
  final ValueChanged<MealPlanDay> onDayTap;

  const _WeekTile({
    required this.weekNumber,
    required this.days,
    required this.initiallyExpanded,
    required this.onDayTap,
  });

  static const _dayLabels = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final weekDays = days.where((d) => d.weekNumber == weekNumber).toList();
    final planned = weekDays.where((d) => d.dailyMealPlan != null).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(
          'Week $weekNumber',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('$planned of 7 days planned',
            style: const TextStyle(fontSize: 12)),
        children: List.generate(7, (di) {
          final dayOfWeek = di + 1;
          final label = _dayLabels[di];
          final assigned =
              weekDays.where((d) => d.dayOfWeek == dayOfWeek).firstOrNull;
          final dmp = assigned?.dailyMealPlan;

          return ListTile(
            dense: true,
            leading: SizedBox(
              width: 36,
              child: Text(
                label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            title: dmp != null
                ? Text(dmp.name)
                : const Text(
                    'Rest / Free',
                    style: TextStyle(
                        color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
            subtitle: dmp != null
                ? Text(
                    '${dmp.kcalTotal.round()} kcal · '
                    'P ${dmp.proteinTotal.round()}g · '
                    'C ${dmp.carbTotal.round()}g · '
                    'F ${dmp.fatTotal.round()}g'
                    '${assigned?.note != null && assigned!.note!.isNotEmpty ? '\n${assigned.note}' : ''}',
                    style: const TextStyle(fontSize: 11),
                  )
                : null,
            trailing:
                dmp != null ? const Icon(Icons.chevron_right, size: 18) : null,
            onTap: dmp != null ? () => onDayTap(assigned!) : null,
          );
        }),
      ),
    );
  }
}
