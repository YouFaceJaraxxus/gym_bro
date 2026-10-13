import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../models/training.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/exercise_picker_sheet.dart';
import '../widgets/image_upload_field.dart';

/// Create or edit a training program with sets, exercises, and drops.
class TrainingFormPage extends StatefulWidget {
  final Training? training;

  const TrainingFormPage({super.key, this.training});

  @override
  State<TrainingFormPage> createState() => _TrainingFormPageState();
}

class _TrainingFormPageState extends State<TrainingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _notes;

  bool _isPublic = false;
  bool _saving = false;
  String? _thumbnailUrl;

  // Mutable in-memory set list while editing
  final List<_SetDraft> _sets = [];

  bool get _isEditing => widget.training != null;

  @override
  void initState() {
    super.initState();
    final t = widget.training;
    _name = TextEditingController(text: t?.name ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _notes = TextEditingController(text: t?.notes ?? '');
    _isPublic = t?.isPublic ?? false;
    _thumbnailUrl = t?.thumbnailUrl.isNotEmpty == true ? t!.thumbnailUrl : null;
    if (t != null) {
      for (final s in t.sets) {
        _sets.add(_SetDraft.fromModel(s));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cs = Theme.of(context).colorScheme;
    setState(() => _saving = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final data = {
        'name': _name.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'is_public': _isPublic,
        'images': _thumbnailUrl != null
            ? [{'url': _thumbnailUrl, 'is_thumbnail': true, 'position': 0}]
            : <Map<String, dynamic>>[],
        'sets': _sets.map((s) => s.toJson()).toList(),
      };

      final Training result;
      if (_isEditing) {
        result = await _api.updateTraining(token, widget.training!.id, data);
      } else {
        result = await _api.createTraining(token, data);
      }
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      setState(() => _saving = false);
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

  void _addSet() {
    setState(() => _sets.add(_SetDraft()));
  }

  void _removeSet(int index) {
    setState(() => _sets.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.trainingPlanEditTitle : l10n.trainingWorkoutsNewTraining),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(onPressed: _save, child: Text(l10n.commonSave)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ImagePickerField(
              imageUrl: _thumbnailUrl,
              folder: 'trainings',
              label: l10n.trainingPlanAddCoverPhoto,
              onUploaded: (url) => setState(() => _thumbnailUrl = url),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.trainingPlanNameLabel),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              decoration: InputDecoration(labelText: l10n.trainingPlanDescriptionLabel),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notes,
              decoration: InputDecoration(labelText: l10n.trainingPlanNotes),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(l10n.trainingPlanPublic),
              subtitle: Text(l10n.trainingPlanPublicSubtitle),
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
            Text(l10n.trainingPlanSets,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sets.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _sets.removeAt(oldIndex);
                  _sets.insert(newIndex, item);
                });
              },
              itemBuilder: (context, i) {
                return _SetDraftCard(
                  key: ValueKey(_sets[i].id),
                  draft: _sets[i],
                  index: i,
                  onChanged: () => setState(() {}),
                  onRemove: () => _removeSet(i),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addSet,
              icon: const Icon(Icons.add),
              label: Text(l10n.trainingPlanAddSet),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Draft models (mutable, used only in the form) ─────────────────────────────

class _DropDraft {
  final String id = UniqueKey().toString();
  RepType repType;
  int? repCount;
  double? weightKg;
  BodySide side;
  String? note;

  _DropDraft({
    this.repType = RepType.count,
    this.repCount = 10,
    this.weightKg,
    this.side = BodySide.both,
    this.note,
  });

  factory _DropDraft.fromModel(TrainingSetDrop d) => _DropDraft(
        repType: d.repType,
        repCount: d.repCount,
        weightKg: d.weightKg,
        side: d.side,
        note: d.note,
      );

  Map<String, dynamic> toJson() => {
        'rep_type': repType.apiValue,
        'rep_count': repCount,
        'weight_kg': weightKg,
        'side': side.apiValue,
        'note': note,
      };
}

class _ExerciseDraft {
  final String id = UniqueKey().toString();
  Exercise? exercise;
  bool isAlternating;
  int? restBetweenDropsSeconds;
  String? note;
  final List<_DropDraft> drops;

  _ExerciseDraft({
    this.exercise,
    this.isAlternating = false,
    this.restBetweenDropsSeconds,
    this.note,
    List<_DropDraft>? drops,
  }) : drops = drops ?? [_DropDraft()];

  factory _ExerciseDraft.fromModel(TrainingSetExercise e) => _ExerciseDraft(
        exercise: e.exercise,
        isAlternating: e.isAlternating,
        restBetweenDropsSeconds: e.restBetweenDropsSeconds,
        note: e.note,
        drops: e.drops.map(_DropDraft.fromModel).toList(),
      );

  Map<String, dynamic> toJson() => {
        'exercise_id': exercise?.id,
        'is_alternating': isAlternating,
        'rest_between_drops_seconds': restBetweenDropsSeconds,
        'note': note,
        'drops': drops.map((d) => d.toJson()).toList(),
      };
}

class _SetDraft {
  final String id = UniqueKey().toString();
  WorkoutSetType type;
  int? restSeconds;
  String? note;
  final List<_ExerciseDraft> exercises;

  _SetDraft({
    this.type = WorkoutSetType.standard,
    this.restSeconds,
    this.note,
    List<_ExerciseDraft>? exercises,
  }) : exercises = exercises ?? [_ExerciseDraft()];

  factory _SetDraft.fromModel(TrainingSet s) => _SetDraft(
        type: s.type,
        restSeconds: s.restSeconds,
        note: s.note,
        exercises: s.exercises.map(_ExerciseDraft.fromModel).toList(),
      );

  Map<String, dynamic> toJson() => {
        'type': type.apiValue,
        'rest_seconds': restSeconds,
        'note': note,
        'exercises': exercises
            .where((e) => e.exercise != null)
            .map((e) => e.toJson())
            .toList(),
      };
}

// ── Set draft card widget ─────────────────────────────────────────────────────

class _SetDraftCard extends StatefulWidget {
  final _SetDraft draft;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _SetDraftCard({
    super.key,
    required this.draft,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_SetDraftCard> createState() => _SetDraftCardState();
}

class _SetDraftCardState extends State<_SetDraftCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: ReorderableDragStartListener(
              index: widget.index,
              child: Icon(Icons.drag_handle,
                  color: cs.onSurfaceVariant, semanticLabel: l10n.trainingPlanReorderSet),
            ),
            title: Row(
              children: [
                DropdownButton<WorkoutSetType>(
                  value: draft.type,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  items: WorkoutSetType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label(l10n), style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => draft.type = v);
                      widget.onChanged();
                    }
                  },
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: _expanded ? l10n.trainingPlanCollapse : l10n.trainingPlanExpand,
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
                IconButton(
                  tooltip: l10n.trainingPlanRemoveSet,
                  icon: Icon(Icons.close, color: cs.error),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  ...draft.exercises.asMap().entries.map((entry) {
                    final ei = entry.key;
                    final ex = entry.value;
                    return _ExerciseDraftRow(
                      draft: ex,
                      showRemove: draft.exercises.length > 1,
                      onChanged: () {
                        setState(() {});
                        widget.onChanged();
                      },
                      onRemove: () {
                        setState(() => draft.exercises.removeAt(ei));
                        widget.onChanged();
                      },
                    );
                  }),
                  if (draft.type == WorkoutSetType.superset ||
                      draft.type == WorkoutSetType.circuit)
                    TextButton.icon(
                      onPressed: () {
                        setState(() => draft.exercises.add(_ExerciseDraft()));
                        widget.onChanged();
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(l10n.trainingPlanAddExerciseToSuperset),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Exercise draft row ────────────────────────────────────────────────────────

class _ExerciseDraftRow extends StatefulWidget {
  final _ExerciseDraft draft;
  final bool showRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _ExerciseDraftRow({
    required this.draft,
    required this.showRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_ExerciseDraftRow> createState() => _ExerciseDraftRowState();
}

class _ExerciseDraftRowState extends State<_ExerciseDraftRow> {
  Future<void> _pickExercise() async {
    final result = await showExercisePicker(context);
    if (result != null && mounted) {
      setState(() => widget.draft.exercise = result);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.fitness_center, size: 18),
            title: Text(
              draft.exercise?.name ?? l10n.trainingPlanSelectExercise,
              style: TextStyle(
                color: draft.exercise == null ? cs.onSurfaceVariant : null,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  onPressed: _pickExercise,
                  tooltip: l10n.trainingPlanPickExercise,
                ),
                if (widget.showRemove)
                  IconButton(
                    tooltip: l10n.trainingPlanRemoveExercise,
                    icon: Icon(Icons.remove_circle_outline, size: 18, color: cs.error),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            onTap: _pickExercise,
          ),
          // Drops
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: [
                ...draft.drops.asMap().entries.map((entry) {
                  final di = entry.key;
                  final drop = entry.value;
                  return _DropDraftRow(
                    drop: drop,
                    dropIndex: di,
                    showLabel: draft.drops.length > 1,
                    showRemove: draft.drops.length > 1,
                    onChanged: () {
                      setState(() {});
                      widget.onChanged();
                    },
                    onRemove: () {
                      setState(() => draft.drops.removeAt(di));
                      widget.onChanged();
                    },
                  );
                }),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() => draft.drops.add(_DropDraft(
                              weightKg: draft.drops.isNotEmpty
                                  ? (draft.drops.last.weightKg != null
                                      ? (draft.drops.last.weightKg! * 0.8)
                                      : null)
                                  : null,
                            )));
                        widget.onChanged();
                      },
                      icon: const Icon(Icons.add, size: 14),
                      label: Text(
                        draft.drops.length > 1 ? l10n.trainingPlanAddDrop : l10n.trainingPlanMakeDropset,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const Spacer(),
                    MergeSemantics(
                      child: Row(
                        children: [
                          Text(
                            l10n.trainingPlanAlternatingShort,
                            semanticsLabel: l10n.trainingPlanAlternating,
                            style: const TextStyle(fontSize: 12),
                          ),
                          Switch(
                            value: draft.isAlternating,
                            onChanged: (v) {
                              setState(() => draft.isAlternating = v);
                              widget.onChanged();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Drop draft row ────────────────────────────────────────────────────────────

class _DropDraftRow extends StatefulWidget {
  final _DropDraft drop;
  final int dropIndex;
  final bool showLabel;
  final bool showRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _DropDraftRow({
    required this.drop,
    required this.dropIndex,
    required this.showLabel,
    required this.showRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_DropDraftRow> createState() => _DropDraftRowState();
}

class _DropDraftRowState extends State<_DropDraftRow> {
  late final TextEditingController _reps;
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    _reps = TextEditingController(
      text: widget.drop.repCount?.toString() ?? '',
    );
    _weight = TextEditingController(
      text: widget.drop.weightKg?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drop = widget.drop;
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          if (widget.showLabel)
            SizedBox(
              width: 52,
              child: Text(
                l10n.trainingPlanDropNumber(widget.dropIndex + 1),
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ),
          // Rep type selector
          DropdownButton<RepType>(
            value: drop.repType,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: RepType.values
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.label(l10n), style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => drop.repType = v);
                widget.onChanged();
              }
            },
          ),
          const SizedBox(width: 8),
          if (drop.repType == RepType.count)
            SizedBox(
              width: 52,
              child: TextField(
                controller: _reps,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: l10n.trainingRepTypeCount,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onChanged: (v) {
                  drop.repCount = int.tryParse(v);
                  widget.onChanged();
                },
              ),
            ),
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
              onChanged: (v) {
                drop.weightKg = double.tryParse(v);
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 4),
          // Side selector (compact)
          DropdownButton<BodySide>(
            value: drop.side,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: BodySide.values
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.label(l10n), style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => drop.side = v);
                widget.onChanged();
              }
            },
          ),
          if (widget.showRemove)
            IconButton(
              tooltip: l10n.trainingPlanRemoveDrop,
              icon: Icon(Icons.close, size: 16, color: cs.error),
              onPressed: widget.onRemove,
            ),
        ],
      ),
    );
  }
}
