import 'package:flutter/material.dart';
import '../models/training.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/muscle_diagram.dart';
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete training?'),
        content: Text('Remove "${_training!.name}" permanently?'),
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
      await _api.deleteTraining(token, widget.trainingId);
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
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _training == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error ?? 'Unknown error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
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
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.push<Training>(
                  context,
                  MaterialPageRoute(builder: (_) => TrainingFormPage(training: training)),
                );
                if (updated != null) setState(() => _training = updated);
              },
            ),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
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
        label: const Text('Start Session'),
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
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('Private', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${training.sets.length} set${training.sets.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sticky_note_2_outlined, size: 16, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Expanded(child: Text(training.notes!)),
                  ],
                ),
              ),
            ],

            // Muscle diagram
            if (allPrimary.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Muscles Trained', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
              const Text('Programme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    'Rest ${set.restSeconds}s',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            if (set.note != null && set.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(set.note!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

  Color get _color {
    switch (type) {
      case WorkoutSetType.standard:
        return Colors.blue;
      case WorkoutSetType.superset:
        return Colors.purple;
      case WorkoutSetType.dropset:
        return Colors.orange;
      case WorkoutSetType.circuit:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        type.displayName,
        style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final TrainingSetExercise ex;

  const _ExerciseRow({required this.ex});

  @override
  Widget build(BuildContext context) {
    final name = ex.exercise?.name ?? 'Exercise';
    final drops = ex.drops;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name +
                      (ex.isAlternating ? ' (alternating)' : ''),
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
                        ? 'Drop ${d.dropNumber + 1}: ${d.label}'
                        : d.label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
