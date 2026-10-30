import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../models/training.dart';
import '../models/training_session.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../services/offline/outbox.dart' show QueuedOfflineException;
import '../services/settings_service.dart';
import '../utils/one_rep_max.dart';
import '../widgets/exercise_picker_sheet.dart';
import '../widgets/plate_calculator_sheet.dart';
import '../widgets/rest_timer.dart';
import '../widgets/share_post.dart';

/// Active workout logging screen.
/// Pass [training] for a structured session following a program,
/// or null for a free-form ad-hoc session.
///
/// After each logged set a rest countdown starts; a "New PR!" snackbar shows
/// when the API reports a personal record; sets logged offline stay visible
/// as pending until the outbox syncs them.
class SessionLogPage extends StatefulWidget {
  final Training? training;

  const SessionLogPage({super.key, this.training});

  @override
  State<SessionLogPage> createState() => _SessionLogPageState();
}

class _SessionLogPageState extends State<SessionLogPage> {
  final _api = ApiService();
  final _rest = RestTimerController();
  final _settings = SettingsService.instance;

  TrainingSession? _session;
  bool _starting = true;
  bool _finishing = false;
  String? _error;

  // Live elapsed time
  late final Timer _timer;
  Duration _elapsed = Duration.zero;

  // Per-set logging state. Key: set index, value: logged drops.
  final Map<int, List<_LoggedDrop>> _loggedDrops = {};
  final Set<int> _pendingSets = {};

  /// Last weight (kg) the user entered; pre-fills the plate calculator.
  double? _lastWeightKg;

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
    _rest.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final session = await _api.startTrainingSession(
        token,
        trainingId: widget.training?.id,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _starting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _starting = false;
      });
    }
  }

  Future<void> _finishSession() async {
    if (_session == null) return;
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trainingLogFinishTitle),
        content: Text(_pendingSets.isEmpty
            ? l10n.trainingLogFinishMessage
            : l10n.trainingLogFinishMessageOffline),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.trainingLogKeepGoing)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.trainingLogFinish)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _finishing = true);
    final messenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;
    try {
      final token = await AuthManager.instance.getValidToken();
      final ended = await _api.endTrainingSession(token, _session!.id);
      _rest.skip();
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final l10n = context.l10n;
      navigator.pop(true);
      showLoggedWithShare(messenger, navigator, message: l10n.postShareWorkoutFinished, target: workoutShareTarget(ended));
    } catch (e) {
      if (!mounted) return;
      setState(() => _finishing = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''),
              style: TextStyle(color: cs.onError)),
          backgroundColor: cs.error,
        ),
      );
    }
  }

  /// Called after every logged set (online or queued offline).
  void _onSetLogged({
    SessionSetLog? result,
    bool queued = false,
    required String Function(String? exerciseId) exerciseName,
    int? restSeconds,
    double? weightKg,
  }) {
    if (weightKg != null && weightKg > 0) _lastWeightKg = weightKg;
    _rest.start(restSeconds != null && restSeconds > 0 ? restSeconds : null);

    final messenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    if (queued) {
      messenger.showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_upload_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.trainingLogOfflineSaved)),
          ],
        ),
      ));
      return;
    }
    if (result != null && result.isPr) {
      final name = exerciseName(result.prExerciseId);
      final e1rm = result.prE1rm;
      messenger.showSnackBar(SnackBar(
        backgroundColor: cs.tertiaryContainer,
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Icon(Icons.emoji_events, color: cs.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                e1rm != null
                    ? l10n.trainingLogNewPrWithE1rm(name, _settings.formatWeight(e1rm))
                    : l10n.trainingLogNewPr(name),
                style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ));
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
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    if (_starting) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.trainingLogStarting)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.trainingLogCouldNotStart)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error ?? l10n.commonSomethingWentWrong,
                  style: TextStyle(color: cs.error), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: _startSession, child: Text(l10n.commonRetry)),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonBack)),
            ]),
          ),
        ),
      );
    }

    final sets = widget.training?.sets ?? [];

    return ValueListenableBuilder<String>(
      valueListenable: _settings.weightUnit,
      builder: (context, _, _) => Scaffold(
        appBar: AppBar(
          title: Text(widget.training?.name ?? l10n.trainingSessionFree),
          actions: [
            Center(
              child: Text(
                _elapsedLabel,
                semanticsLabel: l10n.trainingLogElapsed(_elapsedLabel),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.trainingLogPlateTooltip,
              icon: const Icon(Icons.calculate_outlined),
              onPressed: () => showPlateCalculator(context, initialWeightKg: _lastWeightKg),
            ),
            IconButton(
              tooltip: l10n.trainingLogStartRest,
              icon: const Icon(Icons.timer_outlined),
              onPressed: () => _rest.start(),
            ),
            if (_finishing)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              TextButton(
                onPressed: _finishSession,
                child: Text(l10n.trainingLogFinish,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        body: Column(
          children: [
            RestTimerBanner(controller: _rest),
            Expanded(
              child: sets.isEmpty
                  ? _FreeFormLogger(
                      session: _session!,
                      api: _api,
                      onLogged: _onSetLogged,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: sets.length,
                      itemBuilder: (context, i) {
                        final set = sets[i];
                        return _SetLogger(
                          key: ValueKey(set.id),
                          set: set,
                          setIndex: i,
                          session: _session!,
                          api: _api,
                          loggedDrops: _loggedDrops[i] ?? [],
                          pending: _pendingSets.contains(i),
                          onLogged: (drops, result, queued) {
                            setState(() {
                              _loggedDrops[i] = drops;
                              if (queued) _pendingSets.add(i);
                            });
                            final heaviest = drops
                                .map((d) => d.weightKg ?? 0)
                                .fold<double>(0, (a, b) => a > b ? a : b);
                            _onSetLogged(
                              result: result,
                              queued: queued,
                              restSeconds: set.restSeconds,
                              weightKg: heaviest,
                              exerciseName: (id) {
                                final name =
                                    drops.where((d) => d.exerciseId == id).firstOrNull?.exerciseName ??
                                        drops.firstOrNull?.exerciseName;
                                return name == null || name.isEmpty ? l10n.trainingLogExercise : name;
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _OnSetLogged = void Function({
  SessionSetLog? result,
  bool queued,
  required String Function(String? exerciseId) exerciseName,
  int? restSeconds,
  double? weightKg,
});

// ── Structured set logger ─────────────────────────────────────────────────────

class _SetLogger extends StatefulWidget {
  final TrainingSet set;
  final int setIndex;
  final TrainingSession session;
  final ApiService api;
  final List<_LoggedDrop> loggedDrops;
  final bool pending;
  final void Function(List<_LoggedDrop> drops, SessionSetLog? result, bool queued) onLogged;

  const _SetLogger({
    super.key,
    required this.set,
    required this.setIndex,
    required this.session,
    required this.api,
    required this.loggedDrops,
    required this.pending,
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
    _drops = widget.loggedDrops.isNotEmpty ? List.from(widget.loggedDrops) : _buildFromPlan();
    _done = widget.loggedDrops.isNotEmpty;
  }

  List<_LoggedDrop> _buildFromPlan() {
    final result = <_LoggedDrop>[];
    for (final ex in widget.set.exercises) {
      for (final drop in ex.drops) {
        result.add(_LoggedDrop(
          trainingSetDropId: drop.id,
          exerciseId: ex.exerciseId,
          // Empty = unknown; rendered as the localized "Exercise" fallback.
          exerciseName: ex.exercise?.name ?? '',
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
    final data = {
      'training_set_id': widget.set.id,
      'position': widget.setIndex,
      'drops': _drops.map((d) => d.toJson()).toList(),
    };
    try {
      final token = await AuthManager.instance.getValidToken();
      final result = await widget.api.logSessionSet(token, widget.session.id, data);
      if (!mounted) return;
      setState(() {
        _done = true;
        _logging = false;
      });
      widget.onLogged(List.from(_drops), result, false);
    } on QueuedOfflineException {
      if (!mounted) return;
      setState(() {
        _done = true;
        _logging = false;
      });
      widget.onLogged(List.from(_drops), null, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _logging = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              context.l10n
                  .trainingLogCouldNotLogSet(e.toString().replaceFirst('Exception: ', '')),
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final pending = widget.pending;
    final rest = widget.set.restSeconds;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: !_done
              ? Colors.transparent
              : pending
                  ? cs.tertiary
                  : cs.primary,
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
                Expanded(
                  child: Text(
                    rest != null && rest > 0
                        ? l10n.trainingLogSetHeaderWithRest(
                            widget.setIndex + 1, widget.set.type.label(l10n), formatRestTime(rest))
                        : l10n.trainingLogSetHeader(widget.setIndex + 1, widget.set.type.label(l10n)),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_done && pending)
                  Tooltip(
                    message: l10n.trainingLogSavedOfflineTooltip,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: cs.tertiary, size: 18),
                        const SizedBox(width: 4),
                        Text(l10n.trainingLogPending,
                            style: TextStyle(color: cs.tertiary, fontSize: 12)),
                      ],
                    ),
                  )
                else if (_done)
                  Icon(Icons.check_circle,
                      color: cs.primary, size: 20, semanticLabel: l10n.trainingLogLogged)
                else if (_logging)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  TextButton(onPressed: _logSet, child: Text(l10n.trainingLogLogSet)),
              ],
            ),
            const SizedBox(height: 8),
            ..._drops.asMap().entries.map((entry) {
              final i = entry.key;
              final d = entry.value;
              return _DropLogRow(
                drop: d,
                enabled: !_done,
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

class _AdHocEntry {
  final String exerciseName;
  final String summary;
  final bool pending;
  final bool isPr;

  const _AdHocEntry({
    required this.exerciseName,
    required this.summary,
    this.pending = false,
    this.isPr = false,
  });
}

/// What [_AdHocSetSheet] pops with.
class _AdHocResult {
  final _AdHocEntry entry;
  final SessionSetLog? result;
  final double? weightKg;
  const _AdHocResult(this.entry, this.result, this.weightKg);
}

class _FreeFormLogger extends StatefulWidget {
  final TrainingSession session;
  final ApiService api;
  final _OnSetLogged onLogged;

  const _FreeFormLogger({required this.session, required this.api, required this.onLogged});

  @override
  State<_FreeFormLogger> createState() => _FreeFormLoggerState();
}

class _FreeFormLoggerState extends State<_FreeFormLogger> {
  final List<_AdHocEntry> _logged = [];
  Exercise? _lastExercise;

  Future<void> _logSet() async {
    final r = await showModalBottomSheet<_AdHocResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AdHocSetSheet(
        session: widget.session,
        api: widget.api,
        position: _logged.length,
        initialExercise: _lastExercise,
        onExercisePicked: (e) => _lastExercise = e,
      ),
    );
    if (r == null || !mounted) return;
    setState(() => _logged.add(r.entry));
    widget.onLogged(
      result: r.result,
      queued: r.entry.pending,
      weightKg: r.weightKg,
      exerciseName: (_) => r.entry.exerciseName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Column(
      children: [
        Expanded(
          child: _logged.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fitness_center, size: 44, color: cs.outline),
                      const SizedBox(height: 12),
                      Text(l10n.trainingLogFirstSetHint,
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logged.length,
                  itemBuilder: (context, i) {
                    final entry = _logged[i];
                    return MergeSemantics(
                      child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            entry.pending ? cs.tertiaryContainer : cs.primaryContainer,
                        child: Icon(
                          entry.pending
                              ? Icons.cloud_upload_outlined
                              : entry.isPr
                                  ? Icons.emoji_events
                                  : Icons.check,
                          color: entry.pending ? cs.onTertiaryContainer : cs.onPrimaryContainer,
                          size: 18,
                        ),
                      ),
                      title: Text(entry.exerciseName),
                      subtitle: Text([
                        entry.summary,
                        if (entry.pending) l10n.trainingLogPendingSync,
                        if (entry.isPr) l10n.trainingLogNewPrShort,
                      ].join(' · ')),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _logSet,
              icon: const Icon(Icons.add),
              label: Text(l10n.trainingLogLogASet),
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
  final int position;
  final Exercise? initialExercise;
  final ValueChanged<Exercise> onExercisePicked;

  const _AdHocSetSheet({
    required this.session,
    required this.api,
    required this.position,
    this.initialExercise,
    required this.onExercisePicked,
  });

  @override
  State<_AdHocSetSheet> createState() => _AdHocSetSheetState();
}

class _AdHocSetSheetState extends State<_AdHocSetSheet> {
  final _settings = SettingsService.instance;
  final _reps = TextEditingController();
  final _weight = TextEditingController();
  RepType _repType = RepType.count;
  bool _saving = false;
  Exercise? _exercise;
  String? _error;

  @override
  void initState() {
    super.initState();
    _exercise = widget.initialExercise;
  }

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _pickExercise() async {
    final picked = await showExercisePicker(context);
    if (picked != null && mounted) {
      widget.onExercisePicked(picked);
      setState(() {
        _exercise = picked;
        _error = null;
      });
    }
  }

  double? get _weightDisplay => double.tryParse(_weight.text.trim().replaceAll(',', '.'));

  double? get _weightKg {
    final w = _weightDisplay;
    return w == null ? null : double.parse(_settings.fromDisplayWeight(w).toStringAsFixed(2));
  }

  Future<void> _save() async {
    if (_exercise == null) {
      setState(() => _error = context.l10n.trainingLogPickExercise);
      return;
    }
    final reps = int.tryParse(_reps.text.trim());
    if (_repType == RepType.count && reps == null) {
      setState(() => _error = context.l10n.trainingLogEnterReps);
      return;
    }
    final weightText = _weight.text.trim();
    if (weightText.isNotEmpty && _weightDisplay == null) {
      setState(() => _error = context.l10n.trainingSessionWeightNumber);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final weightKg = _weightKg;
    final data = {
      'exercise_id': _exercise!.id,
      'position': widget.position,
      'drops': [
        {
          'drop_number': 0,
          'rep_type_actual': _repType.apiValue,
          'rep_count_actual': _repType == RepType.count ? reps : null,
          'weight_kg_actual': weightKg,
          'side': 'both',
        }
      ],
    };
    final l10n = context.l10n;
    final repsLabel = _repType == RepType.count
        ? l10n.trainingProgressRepsCount(reps!)
        : _repType.label(l10n);
    final weightLabel = weightKg != null ? ' @ ${_settings.formatWeight(weightKg)}' : '';
    final summary = '$repsLabel$weightLabel';
    try {
      final token = await AuthManager.instance.getValidToken();
      final result = await widget.api.logSessionSet(token, widget.session.id, data);
      if (!mounted) return;
      Navigator.pop(
        context,
        _AdHocResult(
          _AdHocEntry(exerciseName: _exercise!.name, summary: summary, isPr: result.isPr),
          result,
          weightKg,
        ),
      );
    } on QueuedOfflineException {
      if (!mounted) return;
      Navigator.pop(
        context,
        _AdHocResult(
          _AdHocEntry(exerciseName: _exercise!.name, summary: summary, pending: true),
          null,
          weightKg,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final unit = _settings.weightUnit.value;
    final e1rm = _repType == RepType.count
        ? epleyOneRepMax(_weightKg, int.tryParse(_reps.text.trim()))
        : null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.trainingLogLogSet, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            InkWell(
              onTap: _saving ? null : _pickExercise,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.trainingLogExercise,
                  suffixIcon: const Icon(Icons.search),
                ),
                child: Text(
                  _exercise?.name ?? l10n.trainingLogChooseExercise,
                  style: _exercise == null ? TextStyle(color: cs.onSurfaceVariant) : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RepType>(
              initialValue: _repType,
              decoration: InputDecoration(labelText: l10n.trainingLogRepType),
              items: RepType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label(l10n))))
                  .toList(),
              onChanged: (v) => setState(() => _repType = v ?? _repType),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_repType == RepType.count) ...[
                  Expanded(
                    child: TextField(
                      controller: _reps,
                      decoration: InputDecoration(labelText: l10n.trainingRepTypeCount),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: TextField(
                    controller: _weight,
                    decoration: InputDecoration(
                      labelText: l10n.trainingLogWeight,
                      suffixText: unit,
                      hintText: l10n.trainingLogBodyweightHint,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  tooltip: l10n.trainingPlateTitle,
                  icon: const Icon(Icons.calculate_outlined),
                  onPressed: () => showPlateCalculator(context, initialWeightKg: _weightKg),
                ),
              ],
            ),
            if (e1rm != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.trainingLogEstimated1rm(_settings.formatWeight(e1rm)),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: _saving
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton(onPressed: _save, child: Text(l10n.trainingLogLog)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Drop log row ──────────────────────────────────────────────────────────────

class _DropLogRow extends StatefulWidget {
  final _LoggedDrop drop;
  final bool enabled;
  final ValueChanged<_LoggedDrop> onChange;

  const _DropLogRow({required this.drop, required this.onChange, this.enabled = true});

  @override
  State<_DropLogRow> createState() => _DropLogRowState();
}

class _DropLogRowState extends State<_DropLogRow> {
  final _settings = SettingsService.instance;
  late final TextEditingController _reps;
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    _reps = TextEditingController(text: widget.drop.repCount?.toString() ?? '');
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
    final d = widget.drop;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(d.exerciseName.isEmpty ? l10n.trainingLogExercise : d.exerciseName,
                style: const TextStyle(fontSize: 13)),
          ),
          if (d.repType == RepType.count)
            SizedBox(
              width: 56,
              child: TextField(
                controller: _reps,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: l10n.trainingRepTypeCount,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onChanged: (v) => widget.onChange(d.copyWith(repCount: int.tryParse(v))),
              ),
            )
          else
            Text(d.repType.label(l10n), style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: TextField(
              controller: _weight,
              enabled: widget.enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: _settings.weightUnit.value,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              onChanged: (v) {
                final display = double.tryParse(v.trim().replaceAll(',', '.'));
                widget.onChange(d.copyWith(
                  weightKg: display == null
                      ? null
                      : double.parse(_settings.fromDisplayWeight(display).toStringAsFixed(2)),
                  clearWeight: display == null,
                ));
              },
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

  _LoggedDrop copyWith({int? repCount, double? weightKg, bool clearWeight = false}) => _LoggedDrop(
        trainingSetDropId: trainingSetDropId,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        dropNumber: dropNumber,
        repType: repType,
        repCount: repCount ?? this.repCount,
        weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
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
