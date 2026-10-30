import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/routine.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../theme.dart';
import '../widgets/routine_assign.dart';
import 'routine_form_page.dart';
import '../widgets/share_post.dart';

class RoutineDetailPage extends StatefulWidget {
  final String routineId;

  const RoutineDetailPage({super.key, required this.routineId});

  @override
  State<RoutineDetailPage> createState() => _RoutineDetailPageState();
}

class _RoutineDetailPageState extends State<RoutineDetailPage> {
  final _api = ApiService();
  Routine? _routine;
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
      final r = await _api.getRoutine(token, widget.routineId);
      setState(() {
        _routine = r;
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
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trainingRoutineDeleteTitle),
        content: Text(l10n.trainingPlanDeleteBody(_routine!.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteRoutine(token, widget.routineId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString(), style: TextStyle(color: cs.onError)),
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
    final app = context.appColors;
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _routine == null) {
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

    final routine = _routine!;
    final profile = AuthManager.instance.profile;
    final isOwner = profile != null && profile.id == routine.authorId;
    const coachRoles = {
      UserRole.owner,
      UserRole.trainer,
      UserRole.employee,
      UserRole.employeeTrainer,
      UserRole.superUser,
    };
    final isCoach = profile != null && coachRoles.contains(profile.role);
    // The API lets anyone assign public routines (or their own) to themselves
    // or to members they coach.
    final canAssign = isOwner ||
        (isCoach && (routine.isPublic || profile.role == UserRole.superUser));

    return Scaffold(
      floatingActionButton: canAssign
          ? FloatingActionButton.extended(
              onPressed: () => showAssignRoutineFlow(context, routine: routine),
              icon: const Icon(Icons.assignment_ind_outlined),
              label: Text(l10n.trainingAssignAction),
            )
          : null,
      appBar: AppBar(
        title: Text(routine.name),
        actions: [
          SharePostButton(target: routineShareTarget(routine)),
          if (isOwner) ...[
            IconButton(
              tooltip: l10n.trainingRoutineEditTooltip,
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.push<Routine>(
                  context,
                  MaterialPageRoute(builder: (_) => RoutineFormPage(routine: routine)),
                );
                if (updated != null) setState(() => _routine = updated);
              },
            ),
            IconButton(
              tooltip: l10n.trainingRoutineDeleteTooltip,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, canAssign ? 96 : 16),
          children: [
            if (routine.thumbnailUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  routine.thumbnailUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Meta row
            Row(
              children: [
                _ScheduleBadge(routine: routine),
                const SizedBox(width: 8),
                if (!routine.isPublic) ...[
                  Icon(Icons.lock_outline, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(l10n.trainingRoutinePrivate,
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ],
            ),

            if (routine.description != null && routine.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(routine.description!),
            ],

            if (routine.notes != null && routine.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: app.warningContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: app.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sticky_note_2_outlined,
                        size: 16,
                        color: app.onWarningContainer,
                        semanticLabel: l10n.trainingPlanNotes),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(routine.notes!,
                          style: TextStyle(color: app.onWarningContainer)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            Text(l10n.trainingRoutineSchedule,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            if (routine.scheduleType == RoutineScheduleType.fixedWeeks)
              _FixedWeeksSchedule(routine: routine)
            else
              _WildcardSchedule(routine: routine),
          ],
        ),
      ),
    );
  }
}

class _ScheduleBadge extends StatelessWidget {
  final Routine routine;

  const _ScheduleBadge({required this.routine});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        routine.scheduleLabel(context.l10n),
        style: TextStyle(
            fontSize: 12, color: cs.onSecondaryContainer, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FixedWeeksSchedule extends StatelessWidget {
  final Routine routine;

  const _FixedWeeksSchedule({required this.routine});

  @override
  Widget build(BuildContext context) {
    final byWeek = <int, Map<int, RoutineTrainingEntry>>{};
    for (final rt in routine.trainings) {
      if (rt.weekNumber == null) continue;
      byWeek.putIfAbsent(rt.weekNumber!, () => {})[rt.dayOfWeek ?? 1] = rt;
    }
    final weeks = byWeek.keys.toList()..sort();
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final dayFmt = DateFormat.E(Localizations.localeOf(context).toString());

    return Column(
      children: weeks.map((week) {
        final days = byWeek[week]!;
        return ExpansionTile(
          title: Text(l10n.trainingRoutineWeek(week),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: week == 1,
          children: List.generate(7, (i) {
            final dow = i + 1;
            final entry = days[dow];
            // 2024-01-01 was a Monday.
            final dayName = dayFmt.format(DateTime(2024, 1, dow));
            return ListTile(
              dense: true,
              leading: SizedBox(
                width: 36,
                child: Text(dayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              title: entry != null
                  ? Text(entry.training?.name ?? l10n.trainingRoutineTrainingFallback)
                  : Text(l10n.trainingRoutineRestDay,
                      style: TextStyle(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
            );
          }),
        );
      }).toList(),
    );
  }
}

class _WildcardSchedule extends StatelessWidget {
  final Routine routine;

  const _WildcardSchedule({required this.routine});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (routine.trainings.isEmpty) {
      return Text(l10n.trainingRoutineNoTrainings,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
    }
    return Column(
      children: routine.trainings.asMap().entries.map((entry) {
        final i = entry.key;
        final rt = entry.value;
        return ListTile(
          leading: CircleAvatar(
            radius: 14,
            child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
          ),
          title: Text(rt.training?.name ?? l10n.trainingRoutineTrainingFallback),
          subtitle: rt.note != null ? Text(rt.note!) : null,
        );
      }).toList(),
    );
  }
}
