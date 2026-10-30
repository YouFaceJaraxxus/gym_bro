import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/draft.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/training.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/drafts.dart';
import '../widgets/exercise_picker_sheet.dart';
import '../widgets/image_upload_field.dart';
import '../widgets/app_bottom_sheet.dart';

/// Create or edit a training program with sets, exercises, and drops, and
/// pick which of the user's routines it belongs to.
///
/// Once a training has logged sessions ([Training.hasSessions]) its sets are
/// read-only — past sessions point at them — and only its details and
/// routines can change; "Save as a new training" copies it instead.
class TrainingFormPage extends StatefulWidget {
  final Training? training;

  /// A saved draft to continue (new trainings only).
  final Draft? draft;

  /// Prefills a new training (e.g. the exercises of a logged workout, or a
  /// copy of a locked training). Ignored when [training] is set.
  final Training? template;

  const TrainingFormPage({super.key, this.training, this.draft, this.template});

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

  /// The caller's routines this training should be in.
  final Set<String> _routineIds = {};

  /// The caller's own routines; null until loaded (or when loading failed,
  /// in which case routine_ids isn't sent so nothing is unassigned).
  List<Routine>? _myRoutines;
  bool _loadingRoutines = true;

  bool get _isEditing => widget.training != null;

  /// Sets are frozen once the training has logged sessions.
  bool get _exercisesLocked => widget.training?.hasSessions ?? false;

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
        'routine_ids': _routineIds.toList(),
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
      final routines = draft['routine_ids'];
      if (routines is List) _routineIds.addAll(routines.whereType<String>());
      _loadRoutines();
      return;
    }
    final t = widget.training ?? widget.template;
    _routineIds.addAll(widget.training?.routineIds ?? const []);
    _loadRoutines();
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

  Future<void> _loadRoutines() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final routines = await _api.getRoutines(token, mine: true, pageSize: 100);
      if (!mounted) return;
      setState(() {
        _myRoutines = routines;
        _loadingRoutines = false;
        // Drafts may name routines deleted since.
        _routineIds.retainAll(routines.map((r) => r.id));
      });
    } catch (_) {
      // Routines are optional here; the section explains it couldn't load.
      if (mounted) setState(() => _loadingRoutines = false);
    }
  }

  Future<void> _pickRoutines() async {
    final routines = _myRoutines;
    if (routines == null) return;
    final picked = await showAppBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RoutinePickerSheet(routines: routines, selected: _routineIds),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _routineIds
        ..clear()
        ..addAll(picked);
    });
  }

  /// Opens a new training prefilled with this one's sets; once it's saved,
  /// leaves this (unchanged) one.
  Future<void> _saveAsCopy() async {
    final t = widget.training!;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final created = await Navigator.push<Training>(
      context,
      MaterialPageRoute(
        builder: (_) => TrainingFormPage(
          template: Training(
            id: '',
            name: context.l10n.workoutTrainingCopyName(t.name),
            description: t.description,
            notes: t.notes,
            isPublic: false,
            images: t.images,
            sets: t.sets,
            thumbnail: t.thumbnail,
          ),
        ),
      ),
    );
    if (created == null || !mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.workoutTrainingCopySaved(created.name))));
    Navigator.pop(context);
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
        if (!_exercisesLocked) 'sets': _sets.map((s) => s.toJson()).toList(),
        if (_myRoutines != null) 'routine_ids': _routineIds.toList(),
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
              const SizedBox(height: 8),
              _buildRoutines(context),
              const SizedBox(height: 20),
              Text(l10n.trainingPlanSets,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (_exercisesLocked) ...[
                _LockedNotice(onSaveAsCopy: _saveAsCopy),
                const SizedBox(height: 10),
                for (final (i, set) in _sets.indexed)
                  _SetDraftCard(
                    key: ValueKey(set.id),
                    draft: set,
                    index: i,
                    locked: true,
                    onChanged: () {},
                    onRemove: () {},
                  ),
              ] else ...[
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
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutines(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final routines = _myRoutines;
    final selected = routines?.where((r) => _routineIds.contains(r.id)).toList() ?? const [];
    final String subtitle;
    if (_loadingRoutines) {
      subtitle = l10n.workoutTrainingRoutinesLoading;
    } else if (routines == null) {
      subtitle = l10n.workoutTrainingRoutinesUnavailable;
    } else if (routines.isEmpty) {
      subtitle = l10n.workoutTrainingNoRoutines;
    } else if (selected.isEmpty) {
      subtitle = l10n.workoutTrainingInNoRoutine;
    } else {
      subtitle = selected.map((r) => r.name).join(', ');
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.event_note_outlined, color: cs.onSurfaceVariant),
      title: Text(l10n.workoutTrainingRoutines),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: routines == null || routines.isEmpty ? null : const Icon(Icons.chevron_right),
      enabled: routines != null && routines.isNotEmpty,
      onTap: _pickRoutines,
    );
  }
}

/// Explains why the sets of a used training can't change, with a way out.
class _LockedNotice extends StatelessWidget {
  const _LockedNotice({required this.onSaveAsCopy});

  final VoidCallback onSaveAsCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, color: cs.onSecondaryContainer, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.workoutTrainingLockedMessage,
                    style: TextStyle(color: cs.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onSaveAsCopy,
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: Text(l10n.workoutTrainingSaveAsCopy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Multi-select of the user's routines; pops with the chosen ids.
class _RoutinePickerSheet extends StatefulWidget {
  const _RoutinePickerSheet({required this.routines, required this.selected});

  final List<Routine> routines;
  final Set<String> selected;

  @override
  State<_RoutinePickerSheet> createState() => _RoutinePickerSheetState();
}

class _RoutinePickerSheetState extends State<_RoutinePickerSheet> {
  late final Set<String> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(l10n.workoutTrainingRoutines, style: Theme.of(context).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l10n.workoutTrainingRoutinesHint,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in widget.routines)
                    CheckboxListTile(
                      value: _selected.contains(r.id),
                      title: Text(r.name),
                      subtitle: Text(r.scheduleLabel(l10n)),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(r.id);
                        } else {
                          _selected.remove(r.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: Text(l10n.workoutTrainingRoutinesDone),
              ),
            ),
          ],
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

  /// Read-only (the training has logged sessions); outside a reorderable list.
  final bool locked;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _SetDraftCard({
    super.key,
    required this.draft,
    required this.index,
    this.locked = false,
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
            leading: widget.locked
                ? Icon(Icons.lock_outline, color: cs.onSurfaceVariant)
                : ReorderableDragStartListener(
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
                  onChanged: widget.locked
                      ? null
                      : (v) {
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
                if (!widget.locked)
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
                      locked: widget.locked,
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
                  if (!widget.locked &&
                      (draft.type == WorkoutSetType.superset ||
                          draft.type == WorkoutSetType.circuit))
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
  final bool locked;
  final bool showRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _ExerciseDraftRow({
    required this.draft,
    this.locked = false,
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
            trailing: widget.locked
                ? null
                : Row(
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
            onTap: widget.locked ? null : _pickExercise,
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
                    locked: widget.locked,
                    showLabel: draft.drops.length > 1,
                    showRemove: !widget.locked && draft.drops.length > 1,
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
                    if (!widget.locked)
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
                            onChanged: widget.locked
                                ? null
                                : (v) {
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
  final bool locked;
  final bool showLabel;
  final bool showRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _DropDraftRow({
    required this.drop,
    required this.dropIndex,
    this.locked = false,
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
            onChanged: widget.locked
                ? null
                : (v) {
                    if (v != null) {
                      setState(() => drop.repType = v);
                      widget.onChanged();
                    }
                  },
          ),
          const SizedBox(width: 8),
          // The fields share what's left, so a labelled row fits on a phone.
          if (drop.repType == RepType.count)
            Expanded(
              child: TextField(
                controller: _reps,
                enabled: !widget.locked,
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
          if (drop.repType != RepType.count) const Spacer(),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _weight,
              enabled: !widget.locked,
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
            onChanged: widget.locked
                ? null
                : (v) {
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
