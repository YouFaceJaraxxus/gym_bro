import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../models/training.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../services/settings_service.dart';
import '../widgets/exercise_picker_sheet.dart';
import '../widgets/training_picker_sheet.dart';
import 'training_form_page.dart';

/// Logs a finished workout after the fact, starting at [start] (e.g. the hour
/// tapped on the Schedule calendar).
///
/// Picking a training (ones logged before first, then a coach's, then any)
/// fills in its sets as planned; otherwise the user adds exercises. Saving
/// creates the whole session in one request. When it didn't follow one of the
/// user's own trainings, a dialog offers to save the exercises as a new
/// training (opens [TrainingFormPage] prefilled). Pops true once logged.
class LogWorkoutPage extends StatefulWidget {
  const LogWorkoutPage({super.key, required this.start});

  final DateTime start;

  @override
  State<LogWorkoutPage> createState() => _LogWorkoutPageState();
}

class _LogWorkoutPageState extends State<LogWorkoutPage> {
  static const _durations = [15, 30, 45, 60, 75, 90, 105, 120, 150, 180];

  final _api = ApiService();
  final _notes = TextEditingController();

  late DateTime _start = widget.start;
  int _minutes = 60;

  /// The followed training (detail with sets); null for a free workout.
  Training? _training;
  bool _loadingTraining = false;

  final List<_LogBlock> _blocks = [];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  // ── When ────────────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start.isAfter(now) ? now : _start,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _start = DateTime(picked.year, picked.month, picked.day, _start.hour, _start.minute);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _start = DateTime(_start.year, _start.month, _start.day, picked.hour, picked.minute);
    });
  }

  // ── Training ────────────────────────────────────────────────────────────────

  Future<void> _pickTraining() async {
    final pick = await showTrainingPicker(context, title: context.l10n.workoutLogPickTraining);
    final summary = pick?.training;
    if (summary == null || !mounted) return;
    if (_blocks.isNotEmpty) {
      final l10n = context.l10n;
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.workoutLogReplaceTitle),
          content: Text(l10n.workoutLogReplaceMessage(summary.name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.workoutLogReplace)),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    setState(() {
      _loadingTraining = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final detail = await _api.getTraining(token, summary.id);
      if (!mounted) return;
      setState(() {
        _training = detail;
        _blocks
          ..clear()
          ..addAll(detail.sets.map(_LogBlock.fromPlan).where((b) => b.exercises.isNotEmpty));
        _loadingTraining = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTraining = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Keeps what was entered, as a free workout.
  void _clearTraining() {
    setState(() {
      _training = null;
      for (final b in _blocks) {
        b.detachFromPlan();
      }
    });
  }

  // ── Exercises ───────────────────────────────────────────────────────────────

  Future<void> _addExercise() async {
    final picked = await showExercisePicker(context);
    if (picked == null || !mounted) return;
    // Starts from the last numbers logged for the same exercise, if any.
    final previous = _blocks.reversed
        .expand((b) => b.exercises)
        .where((e) => e.exerciseId == picked.id)
        .firstOrNull;
    setState(() {
      _error = null;
      _blocks.add(_LogBlock(exercises: [
        _LogExercise(
          exerciseId: picked.id,
          exercise: picked,
          drops: previous == null
              ? [_LogDrop()]
              : previous.drops.map((d) => d.copy(keepPlan: false)).toList(),
        ),
      ]));
    });
  }

  Future<void> _swapExercise(_LogExercise ex) async {
    final picked = await showExercisePicker(context);
    if (picked == null || !mounted) return;
    setState(() => ex.swapTo(picked));
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  String? _validate() {
    final l10n = context.l10n;
    if (_start.isAfter(DateTime.now())) return l10n.workoutLogFutureError;
    final exercises = _blocks.expand((b) => b.exercises).toList();
    if (exercises.isEmpty) return l10n.workoutLogNoExercisesError;
    final missingReps = exercises
        .expand((e) => e.drops)
        .any((d) => d.repType == RepType.count && d.reps == null);
    if (missingReps) return l10n.workoutLogMissingRepsError;
    return null;
  }

  Map<String, dynamic> _payload() {
    var position = 0;
    final notes = _notes.text.trim();
    return {
      'training_id': _training?.id,
      'started_at': _start.toUtc().toIso8601String(),
      'ended_at': _start.add(Duration(minutes: _minutes)).toUtc().toIso8601String(),
      'notes': notes.isEmpty ? null : notes,
      'sets': [
        for (final b in _blocks)
          for (final e in b.exercises)
            {
              'training_set_id': e.trainingSetId,
              'exercise_id': e.exerciseId,
              'position': position++,
              'drops': [
                for (final (i, d) in e.drops.indexed)
                  {
                    'training_set_drop_id': d.trainingSetDropId,
                    'drop_number': i,
                    'rep_type_actual': d.repType.apiValue,
                    'rep_count_actual': d.repType == RepType.count ? d.reps : null,
                    'weight_kg_actual': d.weightKg,
                    'side': d.side.apiValue,
                  },
              ],
            },
      ],
    };
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.logPastTrainingSession(token, _payload());
      if (!mounted) return;
      final me = AuthManager.instance.profile?.id;
      final ownTraining = _training != null && me != null && _training!.authorId == me;
      if (!ownTraining && await _offerToSaveAsTraining()) {
        await navigator.push<Training>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => TrainingFormPage(template: _asTemplate()),
          ),
        );
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l10n.workoutLogSaved)));
      }
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<bool> _offerToSaveAsTraining() async {
    final l10n = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.bookmark_add_outlined),
        title: Text(l10n.workoutLogAddToTrainingsTitle),
        content: Text(l10n.workoutLogAddToTrainingsMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.workoutLogNotNow)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.workoutLogAddToTrainings),
          ),
        ],
      ),
    );
    return yes == true;
  }

  /// What was logged, as an unsaved training for [TrainingFormPage].
  Training _asTemplate() => Training(
        id: '',
        name: _training?.name ?? '',
        description: _training?.description,
        isPublic: false,
        images: const [],
        sets: [
          for (final (i, b) in _blocks.indexed)
            TrainingSet(
              id: '',
              trainingId: '',
              type: b.type,
              position: i,
              restSeconds: b.restSeconds,
              exercises: [
                for (final (j, e) in b.exercises.indexed)
                  TrainingSetExercise(
                    id: '',
                    trainingSetId: '',
                    exerciseId: e.exerciseId,
                    exercise: e.exercise ?? _stubExercise(e.exerciseId, e.name),
                    position: j,
                    isAlternating: e.isAlternating,
                    restBetweenDropsSeconds: e.restBetweenDropsSeconds,
                    drops: [
                      for (final (k, d) in e.drops.indexed)
                        TrainingSetDrop(
                          id: '',
                          trainingSetExerciseId: '',
                          dropNumber: k,
                          repType: d.repType,
                          repCount: d.repType == RepType.count ? d.reps : null,
                          weightKg: d.weightKg,
                          side: d.side,
                        ),
                    ],
                  ),
              ],
            ),
        ],
      );

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workoutLogTitle),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(onPressed: _loadingTraining ? null : _save, child: Text(l10n.commonSave)),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    label: l10n.workoutLogDate,
                    value: (_start.year == DateTime.now().year
                            ? DateFormat.MMMEd(locale)
                            : DateFormat.yMMMEd(locale))
                        .format(_start),
                    icon: Icons.calendar_today_outlined,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerField(
                    label: l10n.workoutLogStart,
                    value: DateFormat.jm(locale).format(_start),
                    icon: Icons.schedule,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _minutes,
              decoration: InputDecoration(
                labelText: l10n.workoutLogDuration,
                prefixIcon: const Icon(Icons.timer_outlined),
              ),
              items: [
                for (final m in _durations)
                  DropdownMenuItem(value: m, child: Text(l10n.workoutLogMinutes(m))),
              ],
              onChanged: (v) => setState(() => _minutes = v ?? _minutes),
            ),
            const SizedBox(height: 20),
            _buildTrainingField(context),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.workoutLogExercises,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_blocks.isNotEmpty)
                  Text(
                    l10n.workoutLogSetCount(_blocks.length),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingTraining)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_blocks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l10n.workoutLogNoExercisesHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              )
            else
              for (final (i, b) in _blocks.indexed)
                _BlockCard(
                  key: ObjectKey(b),
                  block: b,
                  index: i,
                  onChanged: () => setState(() => _error = null),
                  onSwapExercise: _swapExercise,
                  onDuplicate: () => setState(() => _blocks.insert(i + 1, b.copy())),
                  onRemove: () => setState(() => _blocks.removeAt(i)),
                ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _loadingTraining ? null : _addExercise,
              icon: const Icon(Icons.add),
              label: Text(l10n.workoutLogAddExercise),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _notes,
              decoration: InputDecoration(labelText: l10n.trainingSessionNotes),
              maxLines: 3,
              minLines: 1,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingField(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final t = _training;
    return InkWell(
      onTap: _loadingTraining ? null : _pickTraining,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.workoutLogTraining,
          helperText: t == null ? l10n.workoutLogTrainingHelper : null,
          helperMaxLines: 2,
          prefixIcon: const Icon(Icons.fitness_center),
          suffixIcon: t == null
              ? const Icon(Icons.search)
              : IconButton(
                  tooltip: l10n.workoutLogClearTraining,
                  icon: const Icon(Icons.close),
                  onPressed: _clearTraining,
                ),
        ),
        child: Text(
          t?.name ?? l10n.workoutLogChooseTraining,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t == null ? TextStyle(color: cs.onSurfaceVariant) : null,
        ),
      ),
    );
  }
}

/// Only the id and name are known (exercise missing from the API response).
Exercise _stubExercise(String id, String name) {
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

// ── Form state ────────────────────────────────────────────────────────────────

/// One set as performed: a set type and its exercises (several for supersets
/// and circuits). Blocks from a training keep the planned ids so the session
/// links back to it.
class _LogBlock {
  final WorkoutSetType type;
  final int? restSeconds;
  final List<_LogExercise> exercises;

  _LogBlock({
    this.type = WorkoutSetType.standard,
    this.restSeconds,
    required this.exercises,
  });

  factory _LogBlock.fromPlan(TrainingSet s) => _LogBlock(
        type: s.type,
        restSeconds: s.restSeconds,
        exercises: [
          for (final e in s.exercises)
            _LogExercise(
              exerciseId: e.exerciseId,
              exercise: e.exercise,
              trainingSetId: s.id,
              isAlternating: e.isAlternating,
              restBetweenDropsSeconds: e.restBetweenDropsSeconds,
              drops: e.drops.isEmpty
                  ? [_LogDrop()]
                  : [
                      for (final d in e.drops)
                        _LogDrop(
                          trainingSetDropId: d.id,
                          repType: d.repType,
                          reps: d.repCount,
                          weightKg: d.weightKg,
                          side: d.side,
                        ),
                    ],
            ),
        ],
      );

  /// A repeat of this set; only the original stays linked to the plan.
  _LogBlock copy() => _LogBlock(
        type: type,
        restSeconds: restSeconds,
        exercises: exercises.map((e) => e.copy()).toList(),
      );

  void detachFromPlan() {
    for (final e in exercises) {
      e.trainingSetId = null;
      for (final d in e.drops) {
        d.trainingSetDropId = null;
      }
    }
  }
}

class _LogExercise {
  String exerciseId;
  Exercise? exercise;
  String? trainingSetId;
  final bool isAlternating;
  final int? restBetweenDropsSeconds;
  final List<_LogDrop> drops;

  _LogExercise({
    required this.exerciseId,
    this.exercise,
    this.trainingSetId,
    this.isAlternating = false,
    this.restBetweenDropsSeconds,
    required this.drops,
  });

  String get name => exercise?.name ?? '';

  _LogExercise copy() => _LogExercise(
        exerciseId: exerciseId,
        exercise: exercise,
        isAlternating: isAlternating,
        restBetweenDropsSeconds: restBetweenDropsSeconds,
        drops: drops.map((d) => d.copy(keepPlan: false)).toList(),
      );

  /// A different exercise than planned: no longer the planned slot.
  void swapTo(Exercise e) {
    exerciseId = e.id;
    exercise = e;
    trainingSetId = null;
    for (final d in drops) {
      d.trainingSetDropId = null;
    }
  }
}

class _LogDrop {
  String? trainingSetDropId;
  RepType repType;
  int? reps;
  double? weightKg;
  BodySide side;

  _LogDrop({
    this.trainingSetDropId,
    this.repType = RepType.count,
    this.reps,
    this.weightKg,
    this.side = BodySide.both,
  });

  _LogDrop copy({required bool keepPlan}) => _LogDrop(
        trainingSetDropId: keepPlan ? trainingSetDropId : null,
        repType: repType,
        reps: reps,
        weightKg: weightKg,
        side: side,
      );
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    super.key,
    required this.block,
    required this.index,
    required this.onChanged,
    required this.onSwapExercise,
    required this.onDuplicate,
    required this.onRemove,
  });

  final _LogBlock block;
  final int index;
  final VoidCallback onChanged;
  final Future<void> Function(_LogExercise exercise) onSwapExercise;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final grouped = block.exercises.length > 1;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    block.type == WorkoutSetType.standard
                        ? l10n.workoutLogSetNumber(index + 1)
                        : l10n.trainingLogSetHeader(index + 1, block.type.label(l10n)),
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: l10n.workoutLogRepeatSet,
                  icon: const Icon(Icons.content_copy, size: 18),
                  onPressed: onDuplicate,
                ),
                IconButton(
                  tooltip: l10n.workoutLogRemoveSet,
                  icon: Icon(Icons.close, size: 20, color: cs.error),
                  onPressed: onRemove,
                ),
              ],
            ),
            for (final e in block.exercises) ...[
              InkWell(
                onTap: () async {
                  await onSwapExercise(e);
                  onChanged();
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.name.isEmpty ? l10n.trainingLogExercise : e.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: grouped ? 14 : 15,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.swap_horiz,
                          size: 18,
                          color: cs.onSurfaceVariant,
                          semanticLabel: l10n.trainingPlanPickExercise,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final (i, d) in e.drops.indexed)
                _DropRow(
                  key: ObjectKey(d),
                  drop: d,
                  label: e.drops.length < 2
                      ? null
                      : block.type == WorkoutSetType.dropset
                      ? l10n.trainingPlanDropNumber(i + 1)
                      : '${i + 1}.',
                  onChanged: onChanged,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DropRow extends StatefulWidget {
  const _DropRow({super.key, required this.drop, this.label, required this.onChanged});

  final _LogDrop drop;
  final String? label;
  final VoidCallback onChanged;

  @override
  State<_DropRow> createState() => _DropRowState();
}

class _DropRowState extends State<_DropRow> {
  final _settings = SettingsService.instance;
  late final TextEditingController _reps;
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    _reps = TextEditingController(text: widget.drop.reps?.toString() ?? '');
    final w = widget.drop.weightKg;
    _weight = TextEditingController(text: w == null ? '' : _fmt(_settings.toDisplayWeight(w)));
  }

  static String _fmt(double v) {
    final r = double.parse(v.toStringAsFixed(1));
    return r == r.truncateToDouble() ? r.toInt().toString() : r.toString();
  }

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final d = widget.drop;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 10),
      child: Row(
        children: [
          if (widget.label != null)
            SizedBox(
              width: widget.label!.length > 3 ? 52 : 24,
              child: Text(widget.label!, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ),
          DropdownButton<RepType>(
            value: d.repType == RepType.unspecified ? RepType.count : d.repType,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: [
              for (final t in const [RepType.count, RepType.failure])
                DropdownMenuItem(value: t, child: Text(t.label(l10n), style: const TextStyle(fontSize: 13))),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => d.repType = v);
              widget.onChanged();
            },
          ),
          const SizedBox(width: 8),
          if (d.repType != RepType.failure)
            Expanded(
              child: TextField(
                controller: _reps,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: l10n.workoutLogReps,
                  isDense: true,
                ),
                onChanged: (v) {
                  d.reps = int.tryParse(v.trim());
                  widget.onChanged();
                },
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: _settings.weightUnit.value,
                suffixText: _settings.weightUnit.value,
                isDense: true,
              ),
              onChanged: (v) {
                final display = double.tryParse(v.trim().replaceAll(',', '.'));
                d.weightKg = display == null
                    ? null
                    : double.parse(_settings.fromDisplayWeight(display).toStringAsFixed(2));
                widget.onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}
