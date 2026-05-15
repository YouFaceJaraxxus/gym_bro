import 'package:flutter/material.dart';
import '../models/routine.dart';
import '../models/training.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

class RoutineFormPage extends StatefulWidget {
  final Routine? routine;

  const RoutineFormPage({super.key, this.routine});

  @override
  State<RoutineFormPage> createState() => _RoutineFormPageState();
}

class _RoutineFormPageState extends State<RoutineFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  late final TextEditingController _numWeeks;

  bool _isPublic = false;
  RoutineScheduleType _scheduleType = RoutineScheduleType.wildcard;
  bool _saving = false;

  final List<_RoutineTrainingDraft> _entries = [];

  bool get _isEditing => widget.routine != null;

  @override
  void initState() {
    super.initState();
    final r = widget.routine;
    _name = TextEditingController(text: r?.name ?? '');
    _description = TextEditingController(text: r?.description ?? '');
    _notes = TextEditingController(text: r?.notes ?? '');
    _numWeeks = TextEditingController(text: r?.numWeeks?.toString() ?? '');
    _isPublic = r?.isPublic ?? false;
    _scheduleType = r?.scheduleType ?? RoutineScheduleType.wildcard;
    if (r != null) {
      for (final t in r.trainings) {
        _entries.add(_RoutineTrainingDraft(
          trainingId: t.trainingId,
          trainingName: t.training?.name ?? 'Training',
          weekNumber: t.weekNumber,
          dayOfWeek: t.dayOfWeek,
          position: t.position,
          note: t.note,
        ));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _notes.dispose();
    _numWeeks.dispose();
    super.dispose();
  }

  Future<void> _pickTraining() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TrainingPickerSheet(),
    );
    if (result != null && mounted) {
      setState(() => _entries.add(_RoutineTrainingDraft(
            trainingId: result['id'] as String,
            trainingName: result['name'] as String,
          )));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scheduleType == RoutineScheduleType.fixedWeeks) {
      final weeks = int.tryParse(_numWeeks.text.trim());
      if (weeks == null || weeks < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid number of weeks')),
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final numWeeks = _scheduleType == RoutineScheduleType.fixedWeeks
          ? int.tryParse(_numWeeks.text.trim())
          : null;

      final data = {
        'name': _name.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'is_public': _isPublic,
        'schedule_type': _scheduleType.apiValue,
        'num_weeks': numWeeks,
        'images': <Map<String, dynamic>>[],
        'trainings': _entries.asMap().entries.map((e) => e.value.toJson(e.key)).toList(),
      };

      final Routine result;
      if (_isEditing) {
        result = await _api.updateRoutine(token, widget.routine!.id, data);
      } else {
        result = await _api.createRoutine(token, data);
      }
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Routine' : 'New Routine'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Routine name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              title: const Text('Public'),
              subtitle: const Text('Visible to all users'),
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Schedule type
            const Text('Schedule Type', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<RoutineScheduleType>(
              segments: const [
                ButtonSegment(value: RoutineScheduleType.wildcard, label: Text('Wildcard')),
                ButtonSegment(value: RoutineScheduleType.fixedWeeks, label: Text('Fixed Weeks')),
              ],
              selected: {_scheduleType},
              onSelectionChanged: (s) => setState(() => _scheduleType = s.first),
            ),

            if (_scheduleType == RoutineScheduleType.fixedWeeks) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _numWeeks,
                decoration: const InputDecoration(
                  labelText: 'Number of weeks *',
                  hintText: 'e.g. 12',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (_scheduleType != RoutineScheduleType.fixedWeeks) return null;
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return 'Enter a valid number';
                  return null;
                },
              ),
            ],

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Trainings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _pickTraining,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text('No trainings added yet', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _entries.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _entries.removeAt(oldIndex);
                    _entries.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, i) {
                  final entry = _entries[i];
                  return _TrainingEntryTile(
                    key: ValueKey('${entry.trainingId}_$i'),
                    entry: entry,
                    index: i,
                    scheduleType: _scheduleType,
                    numWeeks: int.tryParse(_numWeeks.text) ?? 1,
                    onChanged: () => setState(() {}),
                    onRemove: () => setState(() => _entries.removeAt(i)),
                  );
                },
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _RoutineTrainingDraft {
  final String trainingId;
  final String trainingName;
  int? weekNumber;
  int? dayOfWeek;
  int position;
  String? note;

  _RoutineTrainingDraft({
    required this.trainingId,
    required this.trainingName,
    this.weekNumber,
    this.dayOfWeek,
    this.position = 0,
    this.note,
  });

  Map<String, dynamic> toJson(int index) => {
        'training_id': trainingId,
        'week_number': weekNumber,
        'day_of_week': dayOfWeek,
        'position': index,
        'note': note,
      };
}

class _TrainingEntryTile extends StatelessWidget {
  final _RoutineTrainingDraft entry;
  final int index;
  final RoutineScheduleType scheduleType;
  final int numWeeks;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _TrainingEntryTile({
    super.key,
    required this.entry,
    required this.index,
    required this.scheduleType,
    required this.numWeeks,
    required this.onChanged,
    required this.onRemove,
  });

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle, color: Colors.grey),
        ),
        title: Text(entry.trainingName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: scheduleType == RoutineScheduleType.fixedWeeks
            ? Row(
                children: [
                  // Week picker
                  DropdownButton<int>(
                    value: entry.weekNumber,
                    hint: const Text('Wk', style: TextStyle(fontSize: 12)),
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: List.generate(numWeeks, (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('Wk ${i + 1}', style: const TextStyle(fontSize: 12)),
                    )),
                    onChanged: (v) {
                      entry.weekNumber = v;
                      onChanged();
                    },
                  ),
                  const SizedBox(width: 8),
                  // Day picker
                  DropdownButton<int>(
                    value: entry.dayOfWeek,
                    hint: const Text('Day', style: TextStyle(fontSize: 12)),
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: List.generate(7, (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(_dayNames[i], style: const TextStyle(fontSize: 12)),
                    )),
                    onChanged: (v) {
                      entry.dayOfWeek = v;
                      onChanged();
                    },
                  ),
                ],
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

// ── Training picker sheet ─────────────────────────────────────────────────────

class _TrainingPickerSheet extends StatefulWidget {
  const _TrainingPickerSheet();

  @override
  State<_TrainingPickerSheet> createState() => _TrainingPickerSheetState();
}

class _TrainingPickerSheetState extends State<_TrainingPickerSheet> {
  final _api = ApiService();
  final _search = TextEditingController();
  List<Training> _trainings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await _api.getTrainings(token, name: _search.text.trim().isEmpty ? null : _search.text.trim(), pageSize: 50);
      setState(() {
        _trainings = results;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search trainings…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: _trainings.length,
                itemBuilder: (context, i) {
                  final t = _trainings[i];
                  return ListTile(
                    title: Text(t.name),
                    subtitle: t.description != null
                        ? Text(t.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                    onTap: () => Navigator.pop(context, {'id': t.id, 'name': t.name}),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
