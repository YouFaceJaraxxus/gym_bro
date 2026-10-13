import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/coaching.dart';
import '../models/meal_plan.dart';
import '../models/training_session.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/meal_plan_assign.dart';
import '../widgets/routine_assign.dart';
import 'meal_plan_detail_page.dart';
import 'meal_plans_page.dart' show AssignmentCard;
import 'nutrition/food_diary_page.dart';
import 'progress/progress_page.dart';
import 'routine_detail_page.dart';
import 'session_detail_page.dart';

/// A coach's view of one member: progress + food diary shortcuts, assigned
/// routines and meal plans (with assign actions), and recent sessions.
class MemberProgressPage extends StatefulWidget {
  const MemberProgressPage({
    super.key,
    required this.userId,
    required this.displayName,
    this.gymId,
  });

  final String userId;
  final String displayName;
  final String? gymId;

  @override
  State<MemberProgressPage> createState() => _MemberProgressPageState();
}

class _MemberProgressPageState extends State<MemberProgressPage> {
  final _api = ApiService();

  List<TrainingSession> _sessions = [];
  bool _sessionsLoading = true;
  String? _sessionsError;

  List<MealPlanAssignment> _assignments = [];
  bool _assignmentsLoading = true;
  String? _assignmentsError;

  List<RoutineAssignment> _routines = [];
  bool _routinesLoading = true;
  String? _routinesError;

  static const _sessionCount = 20;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() =>
      Future.wait([_loadSessions(), _loadAssignments(), _loadRoutines()]);

  String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _loadSessions() async {
    setState(() {
      _sessionsLoading = true;
      _sessionsError = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final sessions = await _api.getTrainingSessions(
        token,
        userId: widget.userId,
        pageSize: _sessionCount,
      );
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _sessionsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sessionsError = _err(e);
        _sessionsLoading = false;
      });
    }
  }

  Future<void> _loadAssignments() async {
    setState(() {
      _assignmentsLoading = true;
      _assignmentsError = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final items = await _api.getMealPlanAssignments(token, userId: widget.userId);
      if (!mounted) return;
      setState(() {
        _assignments = items;
        _assignmentsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assignmentsError = _err(e);
        _assignmentsLoading = false;
      });
    }
  }

  Future<void> _loadRoutines() async {
    setState(() {
      _routinesLoading = true;
      _routinesError = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final items = await _api.getRoutineAssignments(token, userId: widget.userId);
      if (!mounted) return;
      setState(() {
        _routines = items;
        _routinesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routinesError = _err(e);
        _routinesLoading = false;
      });
    }
  }

  Future<void> _assignPlan() async {
    final ok = await showAssignPlanToMemberFlow(
      context,
      userId: widget.userId,
      displayName: widget.displayName,
    );
    if (ok) _loadAssignments();
  }

  Future<void> _assignRoutine() async {
    final ok = await showAssignRoutineToMemberFlow(
      context,
      userId: widget.userId,
      displayName: widget.displayName,
    );
    if (ok) _loadRoutines();
  }

  Future<void> _showAssignMenu() async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: Text(l10n.trainingMemberAssignRoutine),
              onTap: () => Navigator.pop(ctx, 'routine'),
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: Text(l10n.trainingMemberAssignMealPlan),
              onTap: () => Navigator.pop(ctx, 'meal'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'routine') _assignRoutine();
    if (choice == 'meal') _assignPlan();
  }

  Future<void> _removeAssignment(MealPlanAssignment a) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trainingMemberRemoveAssignmentTitle),
        content: Text(l10n.trainingMemberRemoveAssignmentMessage(a.planName, widget.displayName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: Text(l10n.trainingMemberRemove),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteMealPlanAssignment(token, a.id);
      _loadAssignments();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(_err(e), style: TextStyle(color: cs.onError)),
        backgroundColor: cs.error,
      ));
    }
  }

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(widget.displayName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAssignMenu,
        icon: const Icon(Icons.add),
        label: Text(l10n.trainingMemberAssign),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: _ShortcutCard(
                    icon: Icons.insights_outlined,
                    title: l10n.trainingProgressTitle,
                    subtitle: l10n.trainingMemberProgressSubtitle,
                    onTap: () => _push(
                      ProgressPage(userId: widget.userId, displayName: widget.displayName),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShortcutCard(
                    icon: Icons.restaurant_outlined,
                    title: l10n.trainingMemberFoodDiary,
                    subtitle: l10n.trainingMemberFoodDiarySubtitle,
                    onTap: () => _push(
                      FoodDiaryPage(userId: widget.userId, displayName: widget.displayName),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: l10n.trainingMemberRoutines,
              trailing: _routinesLoading || _routinesError != null ? null : '${_routines.length}',
            ),
            ..._buildRoutines(),
            const SizedBox(height: 24),
            _SectionHeader(
              title: l10n.trainingMemberMealPlans,
              trailing:
                  _assignmentsLoading || _assignmentsError != null ? null : '${_assignments.length}',
            ),
            ..._buildAssignments(),
            const SizedBox(height: 24),
            _SectionHeader(
              title: l10n.trainingMemberRecentSessions,
              trailing: _sessionsLoading || _sessionsError != null
                  ? null
                  : '${_sessions.length}${_sessions.length == _sessionCount ? '+' : ''}',
            ),
            ..._buildSessions(),
          ],
        ),
      ),
    );
  }

  String _whoAssigned({required String? assignedById, required String userId, String? name}) {
    final l10n = context.l10n;
    final me = AuthManager.instance.profile;
    if (me != null && assignedById == me.id) return l10n.trainingMemberAssignedByYou;
    if (assignedById != null && assignedById == userId) return l10n.trainingMemberSelfAssigned;
    return name == null
        ? l10n.trainingMemberAssignedByAnotherCoach
        : l10n.trainingMemberAssignedBy(name);
  }

  List<Widget> _buildRoutines() {
    if (_routinesLoading) return const [_SectionSpinner()];
    if (_routinesError != null) {
      return [_SectionError(error: _routinesError!, onRetry: _loadRoutines)];
    }
    final l10n = context.l10n;
    if (_routines.isEmpty) {
      return [
        _SectionEmpty(text: l10n.trainingMemberNoRoutines),
        Center(
          child: TextButton.icon(
            onPressed: _assignRoutine,
            icon: const Icon(Icons.add),
            label: Text(l10n.trainingMemberAssignRoutine),
          ),
        ),
      ];
    }
    final me = AuthManager.instance.profile;
    final isSuper = me?.role == UserRole.superUser;
    return [
      ..._routines.map((a) {
        final byMe = me != null && a.assignedById == me.id;
        return RoutineAssignmentCard(
          assignment: a,
          subtitle: _whoAssigned(
            assignedById: a.assignedById,
            userId: a.userId,
            name: a.assignedByName,
          ),
          onTap: () => _push(RoutineDetailPage(routineId: a.routineId)),
          onRemove: byMe || isSuper
              ? () async {
                  if (await confirmRemoveRoutineAssignment(context, a)) _loadRoutines();
                }
              : null,
        );
      }),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _assignRoutine,
          icon: const Icon(Icons.add),
          label: Text(l10n.trainingMemberAssignRoutine),
        ),
      ),
    ];
  }

  List<Widget> _buildSessions() {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    if (_sessionsLoading) return const [_SectionSpinner()];
    if (_sessionsError != null) {
      return [_SectionError(error: _sessionsError!, onRetry: _loadSessions)];
    }
    if (_sessions.isEmpty) {
      return [_SectionEmpty(text: l10n.trainingMemberNoSessions)];
    }
    return _sessions.map((s) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: s.isActive ? cs.tertiaryContainer : cs.primaryContainer,
            child: Icon(
              s.isActive ? Icons.timer_outlined : Icons.fitness_center,
              color: s.isActive ? cs.onTertiaryContainer : cs.onPrimaryContainer,
              size: 20,
            ),
          ),
          title: Text(DateFormat.yMMMd(locale).add_Hm().format(s.startedAt.toLocal())),
          subtitle: Text(
            [
              s.trainingId != null ? l10n.trainingMemberProgramWorkout : l10n.trainingSessionFree,
              s.isActive ? l10n.trainingSessionInProgress : s.durationLabel,
              if (s.commentCount > 0) l10n.trainingSessionCommentCount(s.commentCount),
              if (s.notes != null && s.notes!.isNotEmpty) s.notes!,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: s.id)),
            );
            _loadSessions();
          },
        ),
      );
    }).toList();
  }

  List<Widget> _buildAssignments() {
    final l10n = context.l10n;
    if (_assignmentsLoading) return const [_SectionSpinner()];
    if (_assignmentsError != null) {
      return [_SectionError(error: _assignmentsError!, onRetry: _loadAssignments)];
    }
    if (_assignments.isEmpty) {
      return [
        _SectionEmpty(text: l10n.trainingMemberNoMealPlans),
        Center(
          child: TextButton.icon(
            onPressed: _assignPlan,
            icon: const Icon(Icons.add),
            label: Text(l10n.trainingMemberAssignMealPlan),
          ),
        ),
      ];
    }
    final me = AuthManager.instance.profile;
    final isSuper = me?.role == UserRole.superUser;
    return _assignments.map((a) {
      final byMe = me != null && a.assignedById == me.id;
      return AssignmentCard(
        assignment: a,
        subtitle: _whoAssigned(
          assignedById: a.assignedById,
          userId: a.userId,
          name: a.assignedByName,
        ),
        onTap: () => _push(MealPlanDetailPage(mealPlanId: a.mealPlanId)),
        // DELETE is allowed for the assigner, the member or a super user.
        onRemove: byMe || isSuper ? () => _removeAssignment(a) : null,
      );
    }).toList();
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: cs.onSecondaryContainer),
              const SizedBox(height: 10),
              Text(title, style: text.titleSmall?.copyWith(color: cs.onSecondaryContainer)),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: cs.onSecondaryContainer)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (trailing != null) Text(trailing!, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SectionSpinner extends StatelessWidget {
  const _SectionSpinner();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _SectionEmpty extends StatelessWidget {
  final String text;
  const _SectionEmpty({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(text,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
}

class _SectionError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _SectionError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
          ],
        ),
      );
}
