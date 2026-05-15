import 'package:flutter/material.dart';
import '../models/routine.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'routine_form_page.dart';

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete routine?'),
        content: Text('Remove "${_routine!.name}" permanently?'),
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
      await _api.deleteRoutine(token, widget.routineId);
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
    if (_error != null || _routine == null) {
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

    final routine = _routine!;
    final profile = AuthManager.instance.profile;
    final isOwner = profile != null && profile.id == routine.authorId;

    return Scaffold(
      appBar: AppBar(
        title: Text(routine.name),
        actions: [
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.push<Routine>(
                  context,
                  MaterialPageRoute(builder: (_) => RoutineFormPage(routine: routine)),
                );
                if (updated != null) setState(() => _routine = updated);
              },
            ),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (routine.thumbnailUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  routine.thumbnailUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
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
                  const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Text('Private', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sticky_note_2_outlined, size: 16, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Expanded(child: Text(routine.notes!)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Text('Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        routine.scheduleLabel,
        style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
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

    return Column(
      children: weeks.map((week) {
        final days = byWeek[week]!;
        return ExpansionTile(
          title: Text('Week $week', style: const TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: week == 1,
          children: List.generate(7, (i) {
            final dow = i + 1;
            final entry = days[dow];
            const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            final dayName = dayNames[i];
            return ListTile(
              dense: true,
              leading: SizedBox(
                width: 36,
                child: Text(dayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              title: entry != null
                  ? Text(entry.training?.name ?? 'Training')
                  : const Text('Rest day', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
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
    if (routine.trainings.isEmpty) {
      return const Text('No trainings assigned yet', style: TextStyle(color: Colors.grey));
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
          title: Text(rt.training?.name ?? 'Training'),
          subtitle: rt.note != null ? Text(rt.note!) : null,
        );
      }).toList(),
    );
  }
}
