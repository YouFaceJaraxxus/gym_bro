import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../services/auth_manager.dart';
import '../services/api_service.dart';
import '../widgets/muscle_diagram.dart';
import '../widgets/open_url.dart';
import 'exercise_form_page.dart';

class ExerciseDetailPage extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailPage({super.key, required this.exercise});

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  late Exercise _exercise;
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _exercise = widget.exercise;
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trainingExerciseDeleteTitle),
        content: Text(l10n.trainingPlanDeleteBody(_exercise.name)),
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
      await _api.deleteExercise(token, _exercise.id);
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
    final profile = AuthManager.instance.profile;
    final isOwner = profile != null && profile.id == _exercise.authorId;
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_exercise.name),
        actions: [
          if (isOwner) ...[
            IconButton(
              tooltip: l10n.commonEdit,
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.push<Exercise>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExerciseFormPage(exercise: _exercise),
                  ),
                );
                if (updated != null) setState(() => _exercise = updated);
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_exercise.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                _exercise.imageUrl!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                semanticLabel: l10n.trainingExercisePhoto(_exercise.name),
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Muscle diagram
          if (_exercise.primaryMuscles.isNotEmpty) ...[
            Center(
              child: MuscleDiagram(
                primaryMuscles: _exercise.primaryMuscles.toSet(),
                secondaryMuscles: _exercise.secondaryMuscles.toSet(),
                size: 220,
              ),
            ),
            const SizedBox(height: 8),
            const Center(child: MuscleDiagramLegend()),
            const SizedBox(height: 16),
          ],

          // Muscle chips
          if (_exercise.primaryMuscles.isNotEmpty) ...[
            Text(l10n.trainingExerciseTargetMuscles,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            MuscleChips(
              primary: _exercise.primaryMuscles,
              secondary: _exercise.secondaryMuscles,
            ),
            const SizedBox(height: 20),
          ],

          if (_exercise.description != null && _exercise.description!.isNotEmpty) ...[
            Text(l10n.trainingPlanDescriptionLabel,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_exercise.description!),
            const SizedBox(height: 20),
          ],

          if (_exercise.note != null && _exercise.note!.isNotEmpty) ...[
            Text(l10n.trainingPlanNotes, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_exercise.note!),
            const SizedBox(height: 20),
          ],

          if (_exercise.videoUrl != null && _exercise.videoUrl!.isNotEmpty) ...[
            Text(l10n.trainingExerciseVideo, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Semantics(
              link: true,
              child: InkWell(
                onTap: () => openExternalUrl(context, _exercise.videoUrl!),
                child: Text(
                  _exercise.videoUrl!,
                  style: TextStyle(
                    color: cs.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
