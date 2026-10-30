import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/business.dart';
import '../models/meal_plan.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'plan_enrolment.dart';
import 'app_bottom_sheet.dart';

// Shared meal-plan assignment flows used by MealPlanDetailPage,
// MealPlansPage and MemberProgressPage.

/// A gym member the current user can coach (assign meal plans to, view
/// sessions of).
class CoachableMember {
  final String userId;
  final String name;
  final String email;
  final List<String> gymNames;

  const CoachableMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.gymNames,
  });
}

/// Formats a date-only value for [locale] ("Oct 13, 2026" / "13. okt 2026.").
String formatPlanDate(DateTime d, String locale) => DateFormat.yMMMd(locale).format(d);

/// Members of every gym where [me] is a gym owner, employee,
/// employee-trainer or trainer (super users: every gym). Excludes [me].
Future<List<CoachableMember>> loadCoachableMembers(
  ApiService api,
  String token,
  UserProfile me,
) async {
  final isSuper = me.role == UserRole.superUser;
  final results = await Future.wait([
    api.getBusinesses(token),
    if (!isSuper) ...[
      api.getGymOwners(token, userId: me.id),
      api.getEmployees(token, userId: me.id),
      api.getEmployeeTrainers(token, userId: me.id),
      api.getTrainers(token, userId: me.id),
    ],
  ]);
  final businesses = results[0] as List<Business>;
  final gyms = {
    for (final b in businesses)
      if (b.type == 'gym') b.id: b.name,
  };

  final Set<String> gymIds;
  if (isSuper) {
    gymIds = gyms.keys.toSet();
  } else {
    gymIds = <String>{};
    for (final rows in results.skip(1)) {
      for (final r in rows as List<Map<String, dynamic>>) {
        final gymId = r['gym_id'] as String?;
        if (gymId != null && gyms.containsKey(gymId)) gymIds.add(gymId);
      }
    }
  }
  if (gymIds.isEmpty) return [];

  final ids = gymIds.toList();
  final memberLists =
      await Future.wait(ids.map((g) => api.getMembers(token, gymId: g)));

  final byUser = <String, CoachableMember>{};
  for (var i = 0; i < ids.length; i++) {
    final gymName = gyms[ids[i]] ?? 'Gym';
    for (final row in memberLists[i]) {
      final uid = row['user_id'] as String?;
      if (uid == null || uid == me.id) continue;
      final u = UserProfile.fromRoleRow(row);
      final existing = byUser[uid];
      if (existing != null) {
        if (!existing.gymNames.contains(gymName)) {
          existing.gymNames.add(gymName);
        }
      } else {
        byUser[uid] = CoachableMember(
          userId: uid,
          name: u.fullName.isEmpty ? u.username : u.fullName,
          email: u.email,
          gymNames: [gymName],
        );
      }
    }
  }
  final list = byUser.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
}

/// From a meal plan: choose "Myself" (the self-enrol dialog) or a coached
/// member, pick an optional start date, then create the assignment. Returns
/// true when one was created.
Future<bool> showAssignMealPlanFlow(
  BuildContext context, {
  required MealPlan plan,
}) async {
  final target = await showAppBottomSheet<_AssignTarget>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AssignTargetSheet(),
  );
  if (target == null || !context.mounted) return false;
  if (target.name == null) return showSelfEnrolMealPlan(context, plan: plan);
  return _confirmAndAssign(
    context,
    planId: plan.id,
    planName: plan.name,
    userId: target.userId,
    targetName: target.name,
  );
}

/// For a member: pick one of the caller's own or a public meal plan, an
/// optional start date, then create the assignment. Returns true on success.
Future<bool> showAssignPlanToMemberFlow(
  BuildContext context, {
  required String userId,
  required String displayName,
}) async {
  final plan = await showAppBottomSheet<MealPlan>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const MealPlanPickerSheet(),
  );
  if (plan == null || !context.mounted) return false;
  return _confirmAndAssign(
    context,
    planId: plan.id,
    planName: plan.name,
    userId: userId,
    targetName: displayName,
  );
}

/// [targetName] null means the current user assigns the plan to themself.
Future<bool> _confirmAndAssign(
  BuildContext context, {
  required String planId,
  required String planName,
  required String userId,
  required String? targetName,
}) async {
  final result = await showDialog<_AssignConfirmResult>(
    context: context,
    builder: (_) =>
        _AssignConfirmDialog(planName: planName, targetName: targetName),
  );
  if (result == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final cs = Theme.of(context).colorScheme;
  try {
    final token = await AuthManager.instance.getValidToken();
    await ApiService().createMealPlanAssignment(token, {
      'meal_plan_id': planId,
      'user_id': userId,
      if (result.startDate != null)
        'start_date': _dateOnly(result.startDate!),
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(targetName == null
            ? l10n.nutritionPlanAssignedToSelf(planName)
            : l10n.nutritionPlanAssignedTo(planName, targetName)),
      ),
    );
    return true;
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', ''), style: TextStyle(color: cs.onError)),
        backgroundColor: cs.error,
      ),
    );
    return false;
  }
}

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ── Target picker ─────────────────────────────────────────────────────────────

class _AssignTarget {
  final String userId;

  /// Null when assigning to oneself.
  final String? name;
  const _AssignTarget(this.userId, this.name);
}

class _AssignTargetSheet extends StatefulWidget {
  const _AssignTargetSheet();

  @override
  State<_AssignTargetSheet> createState() => _AssignTargetSheetState();
}

class _AssignTargetSheetState extends State<_AssignTargetSheet> {
  final _api = ApiService();
  final _search = TextEditingController();
  List<CoachableMember> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      await AuthManager.instance.ensureProfile();
      final me = AuthManager.instance.profile;
      if (me == null) throw Exception('Not signed in');
      final members = await loadCoachableMembers(_api, token, me);
      if (!mounted) return;
      setState(() {
        _members = members;
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

  List<CoachableMember> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _members;
    return _members
        .where((m) =>
            m.name.toLowerCase().contains(q) ||
            m.email.toLowerCase().contains(q) ||
            m.gymNames.any((g) => g.toLowerCase().contains(q)))
        .toList();
  }

  Widget _buildMembers(ScrollController scroll) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                style: TextStyle(color: cs.error),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _members.isEmpty
                ? l10n.nutritionNoMembersToCoach
                : l10n.nutritionNoMembersMatch,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: scroll,
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        return ListTile(
          leading: ExcludeSemantics(
            child: CircleAvatar(
              child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase()),
            ),
          ),
          title: Text(m.name),
          subtitle: Text(
            m.gymNames.join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.pop(context, _AssignTarget(m.userId, m.name)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthManager.instance.profile;
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.nutritionAssignTo,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          if (me != null)
            ListTile(
              leading: const ExcludeSemantics(child: CircleAvatar(child: Icon(Icons.person))),
              title: Text(l10n.nutritionMyself),
              onTap: () => Navigator.pop(context, _AssignTarget(me.id, null)),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.nutritionSearchMembersHint,
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(child: _buildMembers(scroll)),
        ],
      ),
    );
  }
}

// ── Confirm dialog (optional start date) ──────────────────────────────────────

class _AssignConfirmResult {
  final DateTime? startDate;
  const _AssignConfirmResult(this.startDate);
}

class _AssignConfirmDialog extends StatefulWidget {
  final String planName;

  /// Null when assigning to oneself.
  final String? targetName;

  const _AssignConfirmDialog(
      {required this.planName, required this.targetName});

  @override
  State<_AssignConfirmDialog> createState() => _AssignConfirmDialogState();
}

class _AssignConfirmDialogState extends State<_AssignConfirmDialog> {
  DateTime? _startDate;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    return AlertDialog(
      title: Text(l10n.nutritionAssignMealPlanTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.targetName == null
              ? l10n.nutritionAssignPlanToSelfQuestion(widget.planName)
              : l10n.nutritionAssignPlanToQuestion(widget.planName, widget.targetName!)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(_startDate == null
                ? l10n.nutritionStartDateOptional
                : l10n.nutritionStartsOn(formatPlanDate(_startDate!, locale))),
          ),
          if (_startDate != null)
            TextButton(
              onPressed: () => setState(() => _startDate = null),
              child: Text(l10n.nutritionClearStartDate),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _AssignConfirmResult(_startDate)),
          child: Text(l10n.nutritionAssign),
        ),
      ],
    );
  }
}

// ── Meal plan picker (own + public) ───────────────────────────────────────────

class MealPlanPickerSheet extends StatefulWidget {
  const MealPlanPickerSheet({super.key});

  @override
  State<MealPlanPickerSheet> createState() => _MealPlanPickerSheetState();
}

class _MealPlanPickerSheetState extends State<MealPlanPickerSheet> {
  final _api = ApiService();
  final _search = TextEditingController();
  List<MealPlan> _plans = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final name = _search.text.trim().isEmpty ? null : _search.text.trim();
      final results = await Future.wait([
        _api.getMealPlans(token, name: name, mine: true, pageSize: 50),
        _api.getMealPlans(token, name: name, pageSize: 50),
      ]);
      final seen = <String>{};
      final merged = <MealPlan>[];
      for (final p in [...results[0], ...results[1]]) {
        if (seen.add(p.id)) merged.add(p);
      }
      if (!mounted) return;
      setState(() {
        _plans = merged;
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

  Widget _buildList(ScrollController scroll) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                style: TextStyle(color: cs.error),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    if (_plans.isEmpty) {
      return Center(
        child: Text(l10n.nutritionNoMealPlansFound, style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    final myId = AuthManager.instance.profile?.id;
    return ListView.builder(
      controller: scroll,
      itemCount: _plans.length,
      itemBuilder: (context, i) {
        final p = _plans[i];
        final mine = myId != null && p.authorId == myId;
        return ListTile(
          leading: p.thumbnailUrlOrNull != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    p.thumbnailUrlOrNull!,
                    excludeFromSemantics: true,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.restaurant_menu_outlined),
                  ),
                )
              : const Icon(Icons.restaurant_menu_outlined),
          title: Text(p.name),
          subtitle: Text(
            [p.weeksLabel(l10n), if (mine) l10n.nutritionMine, if (!p.isPublic) l10n.nutritionPrivate]
                .join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () => Navigator.pop(context, p),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.l10n.nutritionSearchMealPlansHint,
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(child: _buildList(scroll)),
        ],
      ),
    );
  }
}
