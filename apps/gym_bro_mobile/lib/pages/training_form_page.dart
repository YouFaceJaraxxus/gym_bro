import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/draft.dart';
import '../models/exercise.dart';
import '../models/training.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/drafts.dart';
import '../widgets/exercise_picker_sheet.dart';
import '../widgets/image_upload_field.dart';

/// Create or edit a training program with sets, exercises, and drops.
class TrainingFormPage extends StatefulWidget {
  final Training? training;

  /// A saved draft to continue (new trainings only).
  final Draft? draft;

  const TrainingFormPage({super.key, this.training, this.draft});

  @override
  State<TrainingFormPage> createState() => _TrainingFormPageState();
}

class _TrainingFormPageState extends State<TrainingFormPage> with DraftableForm {
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

  // ── Drafts ──────────────────────────────────────────────────────────────────

  @override
  DraftKind get draftKind => DraftKind.training;
  @override
  Draft? get initialDraft => widget.draft;
  @override
  bool get draftsEnabled => !_isEditing;
  @override
  bool get hasDraftContent =>
      [_name, _description, _notes].any((c) => c.text.trim().isNotEmpty) ||
      _thumbnailUrl != null ||
      _sets.isNotEmpty;
  @override
  String? draftTitle() => _name.text;
  @override
  String? draftThumbnailUrl() => _thumbnailUrl;
  @override
  Map<String, dynamic> draftData() => {
        'name': _name.text,
        'description': _description.text,
        'notes': _notes.text,
        'is_public': _isPublic,
        'thumbnail_url': _thumbnailUrl,
        'sets': _sets.map((s) => s.toDraftJson()).toList(),
      };

  @override
  void initState() {
    super.initState();
    final draft = widget.draft?.data;
    if (draft != null && !_isEditing) {
      _name = TextEditingController(text: _draftStr(draft['name']) ?? '');
      _description = TextEditingController(text: _draftStr(draft['description']) ?? '');
      _notes = TextEditingController(text: _draftStr(draft['notes']) ?? '');
      _isPublic = draft['is_public'] == true;
      final thumb = _draftStr(draft['thumbnail_url']);
      _thumbnailUrl = thumb?.isNotEmpty == true ? thumb : null;
      _sets.addAll(_draftMaps(draft['sets']).map(_SetDraft.fromDraftJson));
      return;
    }
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
        await draftPublished();
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
    final banner = draftBanner(context);
    return draftPopScope(
      busy: _saving,
      child: Scaffold(
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
              if (banner != null) ...[banner, const SizedBox(height: 16)],
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
      ),
    );
  }
}

// ── Saved-draft JSON (drafts may come from an older app version) ─────────────

String? _draftStr(Object? v) => v is String ? v : null;

int? _draftInt(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

double? _draftDouble(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

List<Map<String, dynamic>> _draftMaps(Object? v) => [
      if (v is List)
        for (final m in v)
          if (m is Map) Map<String, dynamic>.from(m),
    ];

/// The picked exercise as saved on a draft ([Exercise.toJson] plus dates);
/// null when there's no usable id.
Exercise? _exerciseFromDraft(Object? raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final id = _draftStr(m['id']);
  if (id == null || id.isEmpty) return null;
  final name = _draftStr(m['name']) ?? '';
  try {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
    return Exercise.fromJson({
      ...m,
      'name': name,
      'created_at': _draftStr(m['created_at']) ?? epoch,
      'updated_at': _draftStr(m['updated_at']) ?? epoch,
    });
  } catch (_) {
    // Odd optional fields: the id and name are all this form needs.
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return Exercise(
      id: id,
      name: name,
      primaryMuscles: const [],
      secondaryMuscles: const [],
      isPublic: true,
      createdAt: epoch,
      updatedAt: epoch,
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

  factory _DropDraft.fromDraftJson(Map<String, dynamic> m) => _DropDraft(
        repType: RepType.fromApiValue(_draftStr(m['rep_type']) ?? ''),
        repCount: m.containsKey('rep_count') ? _draftInt(m['rep_count']) : 10,
        weightKg: _draftDouble(m['weight_kg']),
        side: BodySide.fromApiValue(_draftStr(m['side']) ?? ''),
        note: _draftStr(m['note']),
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

  factory _ExerciseDraft.fromDraftJson(Map<String, dynamic> m) {
    final drops = _draftMaps(m['drops']).map(_DropDraft.fromDraftJson).toList();
    return _ExerciseDraft(
      exercise: _exerciseFromDraft(m['exercise']),
      isAlternating: m['is_alternating'] == true,
      restBetweenDropsSeconds: _draftInt(m['rest_between_drops_seconds']),
      note: _draftStr(m['note']),
      drops: drops.isEmpty ? null : drops,
    );
  }

  Map<String, dynamic> toJson() => {
        'exercise_id': exercise?.id,
        'is_alternating': isAlternating,
        'rest_between_drops_seconds': restBetweenDropsSeconds,
        'note': note,
        'drops': drops.map((d) => d.toJson()).toList(),
      };

  /// Like [toJson], but keeps rows with no exercise picked yet and the
  /// exercise itself, so the form can be restored without fetching it.
  Map<String, dynamic> toDraftJson() {
    final ex = exercise;
    return {
      'exercise': ex == null
          ? null
          : {
              ...ex.toJson(),
              'created_at': ex.createdAt.toIso8601String(),
              'updated_at': ex.updatedAt.toIso8601String(),
            },
      'is_alternating': isAlternating,
      'rest_between_drops_seconds': restBetweenDropsSeconds,
      'note': note,
      'drops': drops.map((d) => d.toJson()).toList(),
    };
  }
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

  factory _SetDraft.fromDraftJson(Map<String, dynamic> m) {
    final exercises = _draftMaps(m['exercises']).map(_ExerciseDraft.fromDraftJson).toList();
    return _SetDraft(
      type: WorkoutSetType.fromApiValue(_draftStr(m['type']) ?? ''),
      restSeconds: _draftInt(m['rest_seconds']),
      note: _draftStr(m['note']),
      exercises: exercises.isEmpty ? null : exercises,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.apiValue,
        'rest_seconds': restSeconds,
        'note': note,
        'exercises': exercises
            .where((e) => e.exercise != null)
            .map((e) => e.toJson())
            .toList(),
      };

  Map<String, dynamic> toDraftJson() => {
        'type': type.apiValue,
        'rest_seconds': restSeconds,
        'note': note,
        'exercises': exercises.map((e) => e.toDraftJson()).toList(),
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
