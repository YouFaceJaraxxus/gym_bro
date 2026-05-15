import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/auth_manager.dart';
import '../services/api_service.dart';
import '../widgets/muscle_diagram.dart';
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete exercise?'),
        content: Text('Remove "${_exercise.name}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
      await _api.deleteExercise(token, _exercise.id);
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
    final profile = AuthManager.instance.profile;
    final isOwner = profile != null && profile.id == _exercise.authorId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_exercise.name),
        actions: [
          if (isOwner) ...[
            IconButton(
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
            const Text('Target Muscles', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            MuscleChips(
              primary: _exercise.primaryMuscles,
              secondary: _exercise.secondaryMuscles,
            ),
            const SizedBox(height: 20),
          ],

          if (_exercise.description != null && _exercise.description!.isNotEmpty) ...[
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_exercise.description!),
            const SizedBox(height: 20),
          ],

          if (_exercise.note != null && _exercise.note!.isNotEmpty) ...[
            const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_exercise.note!),
            const SizedBox(height: 20),
          ],

          if (_exercise.videoUrl != null && _exercise.videoUrl!.isNotEmpty) ...[
            const Text('Video', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () {/* open URL - launcher package not yet added */},
              child: Text(
                _exercise.videoUrl!,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
