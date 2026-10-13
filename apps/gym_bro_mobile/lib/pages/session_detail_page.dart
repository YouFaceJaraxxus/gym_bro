import 'package:flutter/material.dart';
import '../models/training.dart';
import '../models/training_session.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

class SessionDetailPage extends StatefulWidget {
  final String sessionId;

  const SessionDetailPage({super.key, required this.sessionId});

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  final _api = ApiService();
  TrainingSession? _session;
  bool _loading = true;
  String? _error;
  // exercise_id → name, resolved after load for free-session set logs.
  final Map<String, String> _exerciseNames = {};
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
      final s = await _api.getTrainingSession(token, widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = s;
        _loading = false;
      });
      _resolveExerciseNames(token, s);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _resolveExerciseNames(String token, TrainingSession s) async {
    final ids = s.setLogs
        .map((l) => l.exerciseId)
        .whereType<String>()
        .where((id) => !_exerciseNames.containsKey(id))
        .toSet();
    if (ids.isEmpty) return;
    final results = await Future.wait(
      ids.map((id) async {
        try {
          final ex = await _api.getExercise(token, id);
          return MapEntry(id, ex.name);
        } catch (_) {
          return null;
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      for (final e in results.whereType<MapEntry<String, String>>()) {
        _exerciseNames[e.key] = e.value;
      }
    });
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
    );
  }

  Future<void> _editSet(SessionSetLog setLog, String title) async {
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSetSheet(setLog: setLog, title: title),
    );
    if (data == null || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.updateSessionSet(token, setLog.id, data);
      _changed = true;
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteSet(SessionSetLog setLog) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete set?'),
        content: const Text('This logged set will be permanently removed.'),
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
      await _api.deleteSessionSet(token, setLog.id);
      _changed = true;
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text('This log entry will be permanently removed.'),
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
      await _api.deleteTrainingSession(token, widget.sessionId);
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
    if (_error != null || _session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? 'Unknown error',
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final session = _session!;
    final profile = AuthManager.instance.profile;
    final isOwner = profile != null && profile.id == session.userId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Session Detail'),
          actions: [
            if (isOwner)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SummaryRow(
                        icon: Icons.calendar_today,
                        label: 'Date',
                        value: _formatDate(session.startedAt),
                      ),
                      _SummaryRow(
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value: session.isActive
                            ? 'In progress'
                            : session.durationLabel,
                      ),
                      if (session.trainerId != null)
                        _SummaryRow(
                          icon: Icons.person_outline,
                          label: 'Trainer',
                          value: session.trainerId!,
                        ),
                      if (session.notes != null && session.notes!.isNotEmpty)
                        _SummaryRow(
                          icon: Icons.notes,
                          label: 'Notes',
                          value: session.notes!,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (session.setLogs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No sets logged',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else ...[
                Text(
                  '${session.setLogs.length} Set${session.setLogs.length == 1 ? '' : 's'} Logged',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                if (isOwner)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Tap a set to edit it.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ...session.setLogs.asMap().entries.map((entry) {
                  final setLog = entry.value;
                  final exName = setLog.exerciseId != null
                      ? _exerciseNames[setLog.exerciseId]
                      : null;
                  final title = exName != null
                      ? 'Set ${entry.key + 1} · $exName'
                      : 'Set ${entry.key + 1}';
                  return _SetLogCard(
                    title: title,
                    setLog: setLog,
                    onEdit: isOwner ? () => _editSet(setLog, title) : null,
                    onDelete: isOwner ? () => _deleteSet(setLog) : null,
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SetLogCard extends StatelessWidget {
  final String title;
  final SessionSetLog setLog;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _SetLogCard({
    required this.title,
    required this.setLog,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Edit set',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: onEdit,
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Delete set',
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red,
                      ),
                      onPressed: onDelete,
                    ),
                  if (onEdit == null && onDelete == null)
                    const SizedBox(height: 32),
                ],
              ),
              if (setLog.note != null && setLog.note!.isNotEmpty) ...[
                Text(
                  setLog.note!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
              ],
              if (setLog.dropLogs.isEmpty)
                const Text(
                  'No reps recorded',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                )
              else
                ...setLog.dropLogs.map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.arrow_right,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(d.label, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit set sheet ────────────────────────────────────────────────────────────

class _DropDraft {
  final String? trainingSetDropId;
  final int dropNumber;
  RepType repType;
  final TextEditingController reps;
  final TextEditingController weight;
  BodySide side;

  _DropDraft({
    this.trainingSetDropId,
    required this.dropNumber,
    required this.repType,
    int? repCount,
    double? weightKg,
    required this.side,
  }) : reps = TextEditingController(text: repCount?.toString() ?? ''),
       weight = TextEditingController(
         text: weightKg == null ? '' : _fmtWeight(weightKg),
       );

  static String _fmtWeight(double w) =>
      w == w.truncateToDouble() ? w.toInt().toString() : w.toString();

  void dispose() {
    reps.dispose();
    weight.dispose();
  }
}

/// Returns the PUT body ({note, drops}) or null when cancelled.
class _EditSetSheet extends StatefulWidget {
  final SessionSetLog setLog;
  final String title;

  const _EditSetSheet({required this.setLog, required this.title});

  @override
  State<_EditSetSheet> createState() => _EditSetSheetState();
}

class _EditSetSheetState extends State<_EditSetSheet> {
  late final TextEditingController _note;
  final List<_DropDraft> _drops = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.setLog.note ?? '');
    for (final d in widget.setLog.dropLogs) {
      _drops.add(
        _DropDraft(
          trainingSetDropId: d.trainingSetDropId,
          dropNumber: d.dropNumber,
          repType: d.repTypeActual,
          repCount: d.repCountActual,
          weightKg: d.weightKgActual,
          side: d.side,
        ),
      );
    }
    if (_drops.isEmpty) _addDrop();
  }

  @override
  void dispose() {
    _note.dispose();
    for (final d in _drops) {
      d.dispose();
    }
    super.dispose();
  }

  void _addDrop() {
    setState(() {
      final last = _drops.isEmpty ? null : _drops.last;
      _drops.add(
        _DropDraft(
          dropNumber: _drops.length,
          repType: last?.repType ?? RepType.count,
          side: last?.side ?? BodySide.both,
        ),
      );
    });
  }

  void _removeDrop(int i) {
    setState(() {
      _drops.removeAt(i).dispose();
    });
  }

  void _submit() {
    final drops = <Map<String, dynamic>>[];
    for (var i = 0; i < _drops.length; i++) {
      final d = _drops[i];
      final repsText = d.reps.text.trim();
      final weightText = d.weight.text.trim().replaceAll(',', '.');
      final reps = int.tryParse(repsText);
      final weight = double.tryParse(weightText);
      if (d.repType == RepType.count && repsText.isNotEmpty && reps == null) {
        setState(() => _error = 'Reps must be a whole number');
        return;
      }
      if (weightText.isNotEmpty && weight == null) {
        setState(() => _error = 'Weight must be a number');
        return;
      }
      drops.add({
        'training_set_drop_id': d.trainingSetDropId,
        'drop_number': i,
        'rep_type_actual': d.repType.apiValue,
        'rep_count_actual': d.repType == RepType.count ? reps : null,
        'weight_kg_actual': weight,
        'side': d.side.apiValue,
      });
    }
    Navigator.pop(context, {
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      'drops': drops,
    });
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit ${widget.title}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._drops.asMap().entries.map((entry) {
              final i = entry.key;
              final d = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<RepType>(
                        initialValue: d.repType,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: _drops.length > 1
                              ? 'Drop ${i + 1}'
                              : 'Type',
                          isDense: true,
                        ),
                        items: RepType.values
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => d.repType = v ?? d.repType),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (d.repType == RepType.count) ...[
                      Expanded(
                        child: TextField(
                          controller: d.reps,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Reps',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: TextField(
                        controller: d.weight,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'kg',
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_drops.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeDrop(i),
                      ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: _addDrop,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add drop'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note'),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
