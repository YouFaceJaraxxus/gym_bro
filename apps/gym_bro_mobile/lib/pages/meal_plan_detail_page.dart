import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'meal_plan_form_page.dart';

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
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Unknown error',
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final plan = _plan!;
    final profile = AuthManager.instance.profile;
    final isOwner = profile != null && profile.id == plan.authorId;

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name),
        actions: [
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.push<MealPlan>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MealPlanFormPage(plan: plan),
                  ),
                );
                if (updated != null) setState(() => _plan = updated);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Hero image
            if (plan.thumbnailUrlOrNull != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  plan.thumbnailUrlOrNull!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Meta row
            Row(
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
                if (!plan.isPublic) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('Private',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            // Description
            if (plan.description != null && plan.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(plan.description!),
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
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _WeekTile extends StatelessWidget {
  final int weekNumber;
  final List<MealPlanDay> days;

  const _WeekTile({required this.weekNumber, required this.days});

  static const _dayLabels = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        title: Text(
          'Week $weekNumber',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: List.generate(7, (di) {
          final dayOfWeek = di + 1;
          final label = _dayLabels[di];
          final assigned = days
              .where((d) =>
                  d.weekNumber == weekNumber && d.dayOfWeek == dayOfWeek)
              .firstOrNull;

          final hasPlan =
              assigned != null && assigned.dailyMealPlan != null;
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
            title: hasPlan
                ? Text(dmp!.name)
                : const Text(
                    'Rest / Free',
                    style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic),
                  ),
            subtitle: hasPlan
                ? Text(
                    '${dmp!.kcalTotal.round()} kcal',
                    style: const TextStyle(fontSize: 11),
                  )
                : null,
            onTap: null, // future: navigate to daily plan detail
          );
        }),
      ),
    );
  }
}
