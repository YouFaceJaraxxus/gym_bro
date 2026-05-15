import 'dart:async';
import 'package:flutter/material.dart';
import '../models/training.dart';
import '../models/training_session.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

/// Active workout logging screen.
/// Pass [training] for a structured session following a program,
/// or null for a free-form ad-hoc session.
class SessionLogPage extends StatefulWidget {
  final Training? training;

  const SessionLogPage({super.key, this.training});

  @override
  State<SessionLogPage> createState() => _SessionLogPageState();
}

class _SessionLogPageState extends State<SessionLogPage> {
  final _api = ApiService();

  TrainingSession? _session;
  bool _starting = true;
  bool _finishing = false;
  String? _error;

  // Live elapsed time
  late final Timer _timer;
  Duration _elapsed = Duration.zero;

  // Per-set logging state
  // Key: set index (or ad-hoc counter), value: list of logged drops
  final Map<int, List<_LoggedDrop>> _loggedDrops = {};

  @override
  void initState() {
    super.initState();
    _startSession();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _startSession() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final session = await _api.startTrainingSession(
        token,
        trainingId: widget.training?.id,
      );
      setState(() {
        _session = session;
        _starting = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _starting = false;
      });
    }
  }

  Future<void> _finishSession() async {
    if (_session == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish session?'),
        content: const Text('This will record the end time of your workout.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finish')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _finishing = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.updateTrainingSession(token, _session!.id, {
        'ended_at': DateTime.now().toIso8601String(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _finishing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  String get _elapsedLabel {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_starting) {
      return Scaffold(
        appBar: AppBar(title: const Text('Starting session…')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go back')),
          ]),
        ),
      );
    }

    final sets = widget.training?.sets ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.training?.name ?? 'Free Session'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                _elapsedLabel,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
              ),
            ),
          ),
          if (_finishing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _finishSession,
              child: const Text('Finish', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: sets.isEmpty
          ? _FreeFormLogger(session: _session!, api: _api)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: sets.length,
              itemBuilder: (context, i) {
                final set = sets[i];
                return _SetLogger(
                  set: set,
                  setIndex: i,
                  session: _session!,
                  api: _api,
                  loggedDrops: _loggedDrops[i] ?? [],
                  onLogged: (drops) {
                    setState(() => _loggedDrops[i] = drops);
                  },
                );
              },
            ),
    );
  }
}

// ── Structured set logger ─────────────────────────────────────────────────────

class _SetLogger extends StatefulWidget {
  final TrainingSet set;
  final int setIndex;
  final TrainingSession session;
  final ApiService api;
  final List<_LoggedDrop> loggedDrops;
  final ValueChanged<List<_LoggedDrop>> onLogged;

  const _SetLogger({
    required this.set,
    required this.setIndex,
    required this.session,
    required this.api,
    required this.loggedDrops,
    required this.onLogged,
  });

  @override
  State<_SetLogger> createState() => _SetLoggerState();
}

class _SetLoggerState extends State<_SetLogger> {
  bool _logging = false;
  bool _done = false;

  // Build editing state from planned drops
  late final List<_LoggedDrop> _drops;

  @override
  void initState() {
    super.initState();
    _drops = widget.loggedDrops.isNotEmpty
        ? List.from(widget.loggedDrops)
        : _buildFromPlan();
    _done = widget.loggedDrops.isNotEmpty;
  }

  List<_LoggedDrop> _buildFromPlan() {
    final result = <_LoggedDrop>[];
    for (final ex in widget.set.exercises) {
      for (final drop in ex.drops) {
        result.add(_LoggedDrop(
          trainingSetDropId: drop.id,
          exerciseId: ex.exerciseId,
          exerciseName: ex.exercise?.name ?? 'Exercise',
          dropNumber: drop.dropNumber,
          repType: drop.repType,
          repCount: drop.repCount,
          weightKg: drop.weightKg,
          side: drop.side,
        ));
      }
    }
    return result;
  }

  Future<void> _logSet() async {
    setState(() => _logging = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final data = {
        'training_set_id': widget.set.id,
        'position': widget.setIndex,
        'drops': _drops.map((d) => d.toJson()).toList(),
      };
      await widget.api.logSessionSet(token, widget.session.id, data);
      setState(() {
        _done = true;
        _logging = false;
      });
      widget.onLogged(List.from(_drops));
    } catch (e) {
      setState(() => _logging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _done ? Colors.green.shade300 : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Set ${widget.setIndex + 1} · ${widget.set.type.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_done)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20)
                else if (_logging)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  TextButton(onPressed: _logSet, child: const Text('Log Set')),
              ],
            ),
            const SizedBox(height: 8),
            ..._drops.asMap().entries.map((entry) {
              final i = entry.key;
              final d = entry.value;
              return _DropLogRow(
                drop: d,
                onChange: (updated) => setState(() => _drops[i] = updated),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Free-form logger (no training plan) ───────────────────────────────────────

class _FreeFormLogger extends StatefulWidget {
  final TrainingSession session;
  final ApiService api;

  const _FreeFormLogger({required this.session, required this.api});

  @override
  State<_FreeFormLogger> createState() => _FreeFormLoggerState();
}

class _FreeFormLoggerState extends State<_FreeFormLogger> {
  final List<Map<String, dynamic>> _logged = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _logged.isEmpty
              ? const Center(
                  child: Text(
                    'Tap below to log your first set',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logged.length,
                  itemBuilder: (context, i) {
                    final entry = _logged[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade100,
                        child: const Icon(Icons.check, color: Colors.green, size: 18),
                      ),
                      title: Text(entry['exercise'] as String? ?? 'Exercise'),
                      subtitle: Text(entry['summary'] as String? ?? ''),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await showModalBottomSheet<Map<String, dynamic>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _AdHocSetSheet(session: widget.session, api: widget.api),
                );
                if (result != null && mounted) {
                  setState(() => _logged.add(result));
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Log a Set'),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Ad-hoc set sheet ──────────────────────────────────────────────────────────

class _AdHocSetSheet extends StatefulWidget {
  final TrainingSession session;
  final ApiService api;

  const _AdHocSetSheet({required this.session, required this.api});

  @override
  State<_AdHocSetSheet> createState() => _AdHocSetSheetState();
}

class _AdHocSetSheetState extends State<_AdHocSetSheet> {
  final _reps = TextEditingController();
  final _weight = TextEditingController();
  RepType _repType = RepType.count;
  bool _saving = false;
  String _exerciseName = 'Exercise';
  String? _exerciseId;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final data = {
        'exercise_id': _exerciseId,
        'position': 0,
        'drops': [
          {
            'drop_number': 0,
            'rep_type_actual': _repType.apiValue,
            'rep_count_actual': int.tryParse(_reps.text),
            'weight_kg_actual': double.tryParse(_weight.text),
            'side': 'both',
          }
        ],
      };
      await widget.api.logSessionSet(token, widget.session.id, data);
      final repsLabel = _repType == RepType.count
          ? '${_reps.text} reps'
          : _repType.displayName;
      final weightLabel = _weight.text.isNotEmpty ? ' @ ${_weight.text}kg' : '';
      if (mounted) {
        Navigator.pop(context, {
          'exercise': _exerciseName,
          'summary': '$repsLabel$weightLabel',
        });
      }
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Log Set', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(labelText: 'Exercise name'),
            onChanged: (v) => _exerciseName = v,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<RepType>(
            initialValue: _repType,
            decoration: const InputDecoration(labelText: 'Rep type'),
            items: RepType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.displayName)))
                .toList(),
            onChanged: (v) => setState(() => _repType = v ?? _repType),
          ),
          if (_repType == RepType.count) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _reps,
              decoration: const InputDecoration(labelText: 'Reps'),
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _weight,
            decoration: const InputDecoration(labelText: 'Weight (kg)', hintText: 'Leave blank for bodyweight'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: _saving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(onPressed: _save, child: const Text('Log')),
          ),
        ],
      ),
    );
  }
}

// ── Drop log row ──────────────────────────────────────────────────────────────

class _DropLogRow extends StatefulWidget {
  final _LoggedDrop drop;
  final ValueChanged<_LoggedDrop> onChange;

  const _DropLogRow({required this.drop, required this.onChange});

  @override
  State<_DropLogRow> createState() => _DropLogRowState();
}

class _DropLogRowState extends State<_DropLogRow> {
  late final TextEditingController _reps;
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    _reps = TextEditingController(text: widget.drop.repCount?.toString() ?? '');
    _weight = TextEditingController(text: widget.drop.weightKg?.toString() ?? '');
  }

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.drop;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              d.exerciseName,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (d.repType == RepType.count)
            SizedBox(
              width: 56,
              child: TextField(
                controller: _reps,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Reps',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onChanged: (v) => widget.onChange(d.copyWith(repCount: int.tryParse(v))),
              ),
            )
          else
            Text(d.repType.displayName, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'kg',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              onChanged: (v) => widget.onChange(d.copyWith(weightKg: double.tryParse(v))),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _LoggedDrop {
  final String? trainingSetDropId;
  final String? exerciseId;
  final String exerciseName;
  final int dropNumber;
  final RepType repType;
  final int? repCount;
  final double? weightKg;
  final BodySide side;

  const _LoggedDrop({
    this.trainingSetDropId,
    this.exerciseId,
    required this.exerciseName,
    required this.dropNumber,
    required this.repType,
    this.repCount,
    this.weightKg,
    required this.side,
  });

  _LoggedDrop copyWith({int? repCount, double? weightKg}) => _LoggedDrop(
        trainingSetDropId: trainingSetDropId,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        dropNumber: dropNumber,
        repType: repType,
        repCount: repCount ?? this.repCount,
        weightKg: weightKg ?? this.weightKg,
        side: side,
      );

  Map<String, dynamic> toJson() => {
        'training_set_drop_id': trainingSetDropId,
        'drop_number': dropNumber,
        'rep_type_actual': repType.apiValue,
        'rep_count_actual': repCount,
        'weight_kg_actual': weightKg,
        'side': side.apiValue,
      };
}
