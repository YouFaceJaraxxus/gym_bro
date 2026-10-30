import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/meal_plan.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/meal_plan_assign.dart';
import '../widgets/plan_enrolment.dart';
import '../widgets/share_post.dart';
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

  /// Bumped to reload the enrolment card (e.g. a coach assigned it to themself).
  int _enrolVersion = 0;

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
        title: Text(ctx.l10n.nutritionDeleteMealPlanTitle),
        content: Text(ctx.l10n.nutritionDeleteMealPlanMessage(_plan!.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
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
      await _api.deleteMealPlan(token, widget.mealPlanId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''), style: TextStyle(color: cs.onError)),
            backgroundColor: cs.error,
          ),
        );
      }
    }
  }

  Future<void> _assign() async {
    final plan = _plan;
    if (plan == null) return;
    final ok = await showAssignMealPlanFlow(context, plan: plan);
    if (ok && mounted) {
      setState(() {
        _changed = true;
        _enrolVersion++;
      });
    }
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
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
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
                Text(_error ?? l10n.commonSomethingWentWrong,
                    style: TextStyle(color: cs.error),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _load, child: Text(l10n.commonRetry)),
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
    // Anyone can start a public plan (or their own) themselves; coaches can
    // also assign it to members they coach.
    final canEnrol = plan.isPublic || isAuthor || isSuper;
    final canAssign = canEnrol && isCoachRole(profile?.role);

    final plannedDays = plan.days.where((d) => d.dailyMealPlan != null).toList();
    double avg(double Function(DailyMealPlan d) f) => plannedDays.isEmpty
        ? 0
        : plannedDays.map((d) => f(d.dailyMealPlan!)).reduce((a, b) => a + b) /
            plannedDays.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name),
        actions: [
          SharePostButton(target: mealPlanShareTarget(plan)),
          if (canAssign)
            IconButton(
              tooltip: l10n.planEnrolAssignMember,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: _assign,
            ),
          if (canEdit) ...[
            IconButton(
              tooltip: l10n.commonEdit,
              icon: const Icon(Icons.edit),
              onPressed: _edit,
            ),
            IconButton(
              tooltip: l10n.commonDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      floatingActionButton: canAssign
          ? FloatingActionButton.extended(
              onPressed: _assign,
              icon: const Icon(Icons.assignment_ind_outlined),
              label: Text(l10n.planEnrolAssignMember),
            )
          : null,
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
                  semanticLabel: l10n.nutritionPhotoOf(plan.name),
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
                                semanticLabel: l10n.nutritionPhotoOf(plan.name),
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
                    plan.weeksLabel(l10n),
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: cs.primary,
                  side: BorderSide.none,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                if (!plan.isPublic) _Badge(icon: Icons.lock_outline, label: l10n.nutritionPrivate),
                if (plan.isSystem) _Badge(icon: Icons.verified_outlined, label: l10n.nutritionSystem),
                if (isAuthor) _Badge(icon: Icons.person_outline, label: l10n.nutritionYours),
              ],
            ),

            // Description
            if (plan.description != null && plan.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(plan.description!),
            ],

            EnrolmentCard(
              key: ValueKey('enrol-$_enrolVersion'),
              kind: EnrolKind.mealPlan,
              targetId: plan.id,
              name: plan.name,
              canEnrol: canEnrol,
              scheduled: true,
              onChanged: () => _changed = true,
            ),

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
                        l10n.nutritionDailyAveragePlannedDays(plannedDays.length),
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Macro(
                              label: l10n.nutritionKcal,
                              value: avg((d) => d.kcalTotal).round().toString()),
                          _Macro(
                              label: l10n.nutritionProtein,
                              value:
                                  '${avg((d) => d.proteinTotal).toStringAsFixed(0)}g'),
                          _Macro(
                              label: l10n.nutritionCarbsShort,
                              value:
                                  '${avg((d) => d.carbTotal).toStringAsFixed(0)}g'),
                          _Macro(
                              label: l10n.nutritionFat,
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
            Text(
              l10n.nutritionSchedule,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    return MergeSemantics(
      child: Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final weekDays = days.where((d) => d.weekNumber == weekNumber).toList();
    final planned = weekDays.where((d) => d.dailyMealPlan != null).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(
          l10n.nutritionWeekNumber(weekNumber),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(l10n.nutritionDaysPlannedOfSeven(planned),
            style: const TextStyle(fontSize: 12)),
        children: List.generate(7, (di) {
          final dayOfWeek = di + 1;
          final label = shortWeekdayName(dayOfWeek, locale);
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
                : Text(
                    l10n.nutritionRestFree,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                  ),
            subtitle: dmp != null
                ? Text(
                    '${l10n.nutritionKcalValue(dmp.kcalTotal.round())} · '
                    '${l10n.nutritionPcfGrams(dmp.proteinTotal.round(), dmp.carbTotal.round(), dmp.fatTotal.round())}'
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
