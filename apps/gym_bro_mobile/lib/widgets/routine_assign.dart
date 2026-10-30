import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/coaching.dart';
import '../models/progress.dart' show trainingApiDate;
import '../models/routine.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'coachable_members.dart';
import 'plan_enrolment.dart';
import 'app_bottom_sheet.dart';

// Routine assignment flows used by RoutineDetailPage, WorkoutsPage and
// MemberProgressPage.

String _fmtDate(BuildContext context, DateTime d) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(d);

/// From a routine: pick "Myself" (the self-enrol dialog, with workout time and
/// zone) or a coached member, confirm (dates, note), then create the
/// assignment. Returns true when one was created.
Future<bool> showAssignRoutineFlow(BuildContext context, {required Routine routine}) async {
  final target = await showCoachedMemberPicker(
    context,
    title: context.l10n.trainingAssignPickerTitle(routine.name),
  );
  if (target == null || !context.mounted) return false;
  if (target.isSelf) return showSelfEnrolRoutine(context, routine: routine);
  return _confirmAndAssign(
    context,
    routineId: routine.id,
    routineName: routine.name,
    userId: target.userId,
    targetName: target.name,
    isSelf: target.isSelf,
  );
}

/// For a member: pick one of my routines or a public one, confirm, assign.
Future<bool> showAssignRoutineToMemberFlow(
  BuildContext context, {
  required String userId,
  required String displayName,
}) async {
  final routine = await showAppBottomSheet<Routine>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const RoutinePickerSheet(),
  );
  if (routine == null || !context.mounted) return false;
  return _confirmAndAssign(
    context,
    routineId: routine.id,
    routineName: routine.name,
    userId: userId,
    targetName: displayName,
  );
}

Future<bool> _confirmAndAssign(
  BuildContext context, {
  required String routineId,
  required String routineName,
  required String userId,
  required String targetName,
  bool isSelf = false,
}) async {
  final result = await showDialog<_AssignOptions>(
    context: context,
    builder: (_) => _AssignRoutineDialog(
      routineName: routineName,
      targetName: targetName,
      isSelf: isSelf,
    ),
  );
  if (result == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  final cs = Theme.of(context).colorScheme;
  final l10n = context.l10n;
  try {
    final token = await AuthManager.instance.getValidToken();
    await ApiService().createRoutineAssignment(token, {
      'routine_id': routineId,
      'user_id': userId,
      if (result.startDate != null) 'start_date': trainingApiDate(result.startDate!),
      if (result.endDate != null) 'end_date': trainingApiDate(result.endDate!),
      if (result.note.isNotEmpty) 'note': result.note,
    });
    messenger.showSnackBar(SnackBar(
      content: Text(isSelf
          ? l10n.trainingAssignDoneSelf(routineName)
          : l10n.trainingAssignDone(routineName, targetName)),
    ));
    return true;
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e.toString().replaceFirst('Exception: ', ''),
          style: TextStyle(color: cs.onError),
        ),
        backgroundColor: cs.error,
      ),
    );
    return false;
  }
}

// ── Confirm dialog ────────────────────────────────────────────────────────────

class _AssignOptions {
  final DateTime? startDate;
  final DateTime? endDate;
  final String note;
  const _AssignOptions(this.startDate, this.endDate, this.note);
}

class _AssignRoutineDialog extends StatefulWidget {
  final String routineName;
  final String targetName;
  final bool isSelf;

  const _AssignRoutineDialog({
    required this.routineName,
    required this.targetName,
    required this.isSelf,
  });

  @override
  State<_AssignRoutineDialog> createState() => _AssignRoutineDialogState();
}

class _AssignRoutineDialogState extends State<_AssignRoutineDialog> {
  final _note = TextEditingController();
  DateTime? _start;
  DateTime? _end;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final now = DateTime.now();
    final initial = (start ? _start : _end) ?? _start ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: start ? DateTime(now.year - 1) : (_start ?? DateTime(now.year - 1)),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = null;
      } else {
        _end = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.trainingAssignDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isSelf
                ? l10n.trainingAssignConfirmSelf(widget.routineName)
                : l10n.trainingAssignConfirm(widget.routineName, widget.targetName)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(start: true),
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(_start == null
                        ? l10n.trainingAssignStart
                        : _fmtDate(context, _start!)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(start: false),
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: Text(_end == null
                        ? l10n.trainingAssignEnd
                        : _fmtDate(context, _end!)),
                  ),
                ),
              ],
            ),
            if (_start != null || _end != null)
              TextButton(
                onPressed: () => setState(() {
                  _start = null;
                  _end = null;
                }),
                child: Text(l10n.trainingAssignClearDates),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.trainingAssignNoteLabel,
                hintText: l10n.trainingAssignNoteHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _AssignOptions(_start, _end, _note.text.trim())),
          child: Text(l10n.trainingAssignAction),
        ),
      ],
    );
  }
}

// ── Routine picker (mine + public) ────────────────────────────────────────────

class RoutinePickerSheet extends StatefulWidget {
  const RoutinePickerSheet({super.key});

  @override
  State<RoutinePickerSheet> createState() => _RoutinePickerSheetState();
}

class _RoutinePickerSheetState extends State<RoutinePickerSheet> {
  final _api = ApiService();
  final _search = TextEditingController();
  List<Routine> _routines = [];
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
        _api.getRoutines(token, name: name, mine: true, pageSize: 50),
        _api.getRoutines(token, name: name, pageSize: 50),
      ]);
      final seen = <String>{};
      final merged = <Routine>[
        for (final r in [...results[0], ...results[1]])
          if (seen.add(r.id)) r,
      ];
      if (!mounted) return;
      setState(() {
        _routines = merged;
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
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: cs.error), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _load, child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    if (_routines.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined, size: 40, color: cs.outline),
            const SizedBox(height: 8),
            Text(l10n.trainingAssignNoRoutines, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }
    final myId = AuthManager.instance.profile?.id;
    return ListView.builder(
      controller: scroll,
      itemCount: _routines.length,
      itemBuilder: (context, i) {
        final r = _routines[i];
        final mine = myId != null && r.authorId == myId;
        return ListTile(
          leading: ExcludeSemantics(
            child: CircleAvatar(
              backgroundColor: cs.secondaryContainer,
              foregroundColor: cs.onSecondaryContainer,
              child: const Icon(Icons.event_note_outlined),
            ),
          ),
          title: Text(r.name),
          subtitle: Text(
            [
              r.scheduleLabel(l10n),
              l10n.trainingRoutineTrainingCount(r.trainings.length),
              if (mine) l10n.trainingRoutineMine,
              if (!r.isPublic) l10n.trainingRoutinePrivate,
            ].join(' · '),
          ),
          onTap: () => Navigator.pop(context, r),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.l10n.trainingAssignSearchRoutinesHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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

// ── Assignment card ───────────────────────────────────────────────────────────

class RoutineAssignmentCard extends StatelessWidget {
  final RoutineAssignment assignment;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const RoutineAssignmentCard({
    super.key,
    required this.assignment,
    required this.subtitle,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final a = assignment;
    final dates = [
      if (a.startDate != null) l10n.trainingAssignStarts(_fmtDate(context, a.startDate!)),
      if (a.endDate != null) l10n.trainingAssignEnds(_fmtDate(context, a.endDate!)),
    ];
    if (dates.isEmpty) {
      dates.add(l10n.trainingAssignAssignedOn(_fmtDate(context, a.createdAt.toLocal())));
    }
    final lines = [
      subtitle,
      [if (a.routineScheduleLabel != null) a.routineScheduleLabel!, ...dates].join(' · '),
      if (a.note != null && a.note!.isNotEmpty) a.note!,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ExcludeSemantics(child: Icon(Icons.event_note, color: cs.onPrimaryContainer)),
        ),
        title: Text(a.routineName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(lines.join('\n'), style: const TextStyle(fontSize: 12)),
        isThreeLine: true,
        trailing: onRemove == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: l10n.trainingAssignRemoveTooltip,
                icon: Icon(Icons.close, color: cs.error),
                onPressed: onRemove,
              ),
        onTap: onTap,
      ),
    );
  }
}

/// Confirms and deletes [a]. Returns true when removed.
Future<bool> confirmRemoveRoutineAssignment(BuildContext context, RoutineAssignment a) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = context.l10n;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.trainingAssignRemoveTitle),
      content: Text(a.userName != null
          ? l10n.trainingAssignRemoveBodyUser(a.routineName, a.userName!)
          : l10n.trainingAssignRemoveBody(a.routineName)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: cs.error),
          child: Text(l10n.trainingAssignRemoveAction),
        ),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final token = await AuthManager.instance.getValidToken();
    await ApiService().deleteRoutineAssignment(token, a.id);
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(
        e.toString().replaceFirst('Exception: ', ''),
        style: TextStyle(color: cs.onError),
      ),
      backgroundColor: cs.error,
    ));
    return false;
  }
}
