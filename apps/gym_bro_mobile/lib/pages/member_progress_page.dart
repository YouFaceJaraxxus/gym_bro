import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import '../models/training_session.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/meal_plan_assign.dart';
import 'meal_plan_detail_page.dart';
import 'meal_plans_page.dart' show AssignmentCard;
import 'session_detail_page.dart';

/// A coach's view of one member: recent training sessions, assigned meal
/// plans, and an "Assign meal plan" action.
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

  static const _sessionCount = 20;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() => Future.wait([_loadSessions(), _loadAssignments()]);

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
        _sessionsError = e.toString().replaceFirst('Exception: ', '');
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
      final items =
          await _api.getMealPlanAssignments(token, userId: widget.userId);
      if (!mounted) return;
      setState(() {
        _assignments = items;
        _assignmentsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assignmentsError = e.toString().replaceFirst('Exception: ', '');
        _assignmentsLoading = false;
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

  Future<void> _removeAssignment(MealPlanAssignment a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove assignment?'),
        content: Text(
            '"${a.planName}" will no longer be assigned to ${widget.displayName}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteMealPlanAssignment(token, a.id);
      _loadAssignments();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.displayName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _assignPlan,
        icon: const Icon(Icons.restaurant_menu),
        label: const Text('Assign meal plan'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _SectionHeader(
              title: 'Recent sessions',
              trailing: _sessionsLoading || _sessionsError != null
                  ? null
                  : '${_sessions.length}${_sessions.length == _sessionCount ? '+' : ''}',
            ),
            ..._buildSessions(),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Meal plans',
              trailing: _assignmentsLoading || _assignmentsError != null
                  ? null
                  : '${_assignments.length}',
            ),
            ..._buildAssignments(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSessions() {
    if (_sessionsLoading) {
      return const [_SectionSpinner()];
    }
    if (_sessionsError != null) {
      return [_SectionError(error: _sessionsError!, onRetry: _loadSessions)];
    }
    if (_sessions.isEmpty) {
      return const [_SectionEmpty(text: 'No training sessions logged yet')];
    }
    return _sessions.map((s) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: s.isActive
                ? Colors.orange.withValues(alpha: 0.15)
                : Colors.green.withValues(alpha: 0.15),
            child: Icon(
              s.isActive ? Icons.timer_outlined : Icons.fitness_center,
              color: s.isActive ? Colors.orange : Colors.green,
              size: 20,
            ),
          ),
          title: Text(_formatDate(s.startedAt.toLocal())),
          subtitle: Text(
            [
              s.trainingId != null ? 'Program workout' : 'Free session',
              s.isActive ? 'In progress' : s.durationLabel,
              if (s.notes != null && s.notes!.isNotEmpty) s.notes!,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SessionDetailPage(sessionId: s.id),
              ),
            );
          },
        ),
      );
    }).toList();
  }

  List<Widget> _buildAssignments() {
    if (_assignmentsLoading) {
      return const [_SectionSpinner()];
    }
    if (_assignmentsError != null) {
      return [
        _SectionError(error: _assignmentsError!, onRetry: _loadAssignments),
      ];
    }
    if (_assignments.isEmpty) {
      return [
        const _SectionEmpty(text: 'No meal plans assigned'),
        Center(
          child: TextButton.icon(
            onPressed: _assignPlan,
            icon: const Icon(Icons.add),
            label: const Text('Assign meal plan'),
          ),
        ),
      ];
    }
    final me = AuthManager.instance.profile;
    final isSuper = me?.role == UserRole.superUser;
    return _assignments.map((a) {
      final byMe = me != null && a.assignedById == me.id;
      final String who;
      if (byMe) {
        who = 'Assigned by you';
      } else if (a.assignedById != null && a.assignedById == a.userId) {
        who = 'Self-assigned';
      } else {
        who = 'Assigned by ${a.assignedByName ?? 'another coach'}';
      }
      return AssignmentCard(
        assignment: a,
        subtitle: who,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MealPlanDetailPage(mealPlanId: a.mealPlanId),
          ),
        ),
        // DELETE is allowed for the assigner, the member or a super user.
        onRemove: byMe || isSuper ? () => _removeAssignment(a) : null,
      );
    }).toList();
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (trailing != null)
            Text(trailing!, style: const TextStyle(color: Colors.grey)),
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
          child: Text(text, style: const TextStyle(color: Colors.grey)),
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
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}
