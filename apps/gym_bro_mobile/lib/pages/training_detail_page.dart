import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/training.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../theme.dart';
import '../widgets/muscle_diagram.dart';
import '../widgets/share_post.dart';
import 'training_form_page.dart';
import 'session_log_page.dart';

class TrainingDetailPage extends StatefulWidget {
  final String trainingId;

  const TrainingDetailPage({super.key, required this.trainingId});

  @override
  State<TrainingDetailPage> createState() => _TrainingDetailPageState();
}

class _TrainingDetailPageState extends State<TrainingDetailPage> {
  final _api = ApiService();
  Training? _training;
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
      final t = await _api.getTraining(token, widget.trainingId);
      setState(() {
        _training = t;
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
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trainingPlanDeleteTitle),
        content: Text(l10n.trainingPlanDeleteBody(_training!.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteTraining(token, widget.trainingId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final app = context.appColors;
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _training == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error ?? l10n.commonSomethingWentWrong, style: TextStyle(color: cs.error)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: Text(l10n.commonRetry)),
          ]),
        ),
      );
    }

    final training = _training!;
    final profile = AuthManager.instance.profile;
    final isOwner = profile != null && profile.id == training.authorId;
    final allPrimary = training.primaryMuscles;

    return Scaffold(
      appBar: AppBar(
        title: Text(training.name),
        actions: [
          SharePostButton(target: trainingShareTarget(training)),
          if (isOwner) ...[
            IconButton(
              tooltip: l10n.commonEdit,
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.push<Training>(
                  context,
                  MaterialPageRoute(builder: (_) => TrainingFormPage(training: training)),
                );
                if (updated != null) setState(() => _training = updated);
              },
            ),
            IconButton(
              tooltip: l10n.commonDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessionLogPage(training: training),
            ),
          );
        },
        icon: const Icon(Icons.play_arrow),
        label: Text(l10n.trainingPlanStartSession),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Thumbnail
            if (training.thumbnailUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  training.thumbnailUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Header chips
            Row(
              children: [
                if (!training.isPublic) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(l10n.trainingRoutinePrivate,
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  l10n.trainingWorkoutsSetCount(training.sets.length),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),

            if (training.description != null && training.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(training.description!),
            ],

            if (training.notes != null && training.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: app.warningContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: app.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sticky_note_2_outlined,
                        size: 16,
                        color: app.onWarningContainer,
                        semanticLabel: l10n.trainingPlanNotes),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(training.notes!,
                          style: TextStyle(color: app.onWarningContainer)),
                    ),
                  ],
                ),
              ),
            ],

            // Muscle diagram
            if (allPrimary.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(l10n.trainingPlanMusclesTrained,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Center(
                child: MuscleDiagram(primaryMuscles: allPrimary, size: 200),
              ),
              const SizedBox(height: 8),
              const Center(child: MuscleDiagramLegend()),
            ],

            // Sets
            if (training.sets.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(l10n.trainingPlanProgramme,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ...training.sets.map((s) => _SetCard(set: s)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetCard extends StatelessWidget {
  final TrainingSet set;

  const _SetCard({required this.set});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SetTypeBadge(type: set.type),
                const Spacer(),
                if (set.restSeconds != null)
                  Text(
                    l10n.trainingPlanRestSeconds(set.restSeconds!),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
            if (set.note != null && set.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(set.note!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 10),
            ...set.exercises.map((e) => _ExerciseRow(ex: e)),
          ],
        ),
      ),
    );
  }
}

class _SetTypeBadge extends StatelessWidget {
  final WorkoutSetType type;

  const _SetTypeBadge({required this.type});

  /// (background, foreground) per set type, from theme roles.
  (Color, Color) _colors(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final app = context.appColors;
    return switch (type) {
      WorkoutSetType.standard => (cs.secondaryContainer, cs.onSecondaryContainer),
      WorkoutSetType.superset => (cs.primaryContainer, cs.onPrimaryContainer),
      WorkoutSetType.dropset => (cs.tertiaryContainer, cs.onTertiaryContainer),
      WorkoutSetType.circuit => (app.successContainer, app.onSuccessContainer),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        type.label(context.l10n),
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final TrainingSetExercise ex;

  const _ExerciseRow({required this.ex});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final name = ex.exercise?.name ?? l10n.trainingExerciseFallbackName;
    final drops = ex.drops;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ex.isAlternating ? l10n.trainingExerciseAlternating(name) : name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (drops.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: drops.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    drops.length > 1
                        ? l10n.trainingPlanDropLine(d.dropNumber + 1, d.label(l10n))
                        : d.label(l10n),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
