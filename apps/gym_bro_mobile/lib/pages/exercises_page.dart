import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'exercise_detail_page.dart';
import 'exercise_form_page.dart';

class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key});

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  final _api = ApiService();
  final _search = TextEditingController();

  List<Exercise> _exercises = [];
  bool _loading = true;
  String? _error;
  MuscleGroup? _filterMuscle;
  int _page = 0;
  bool _hasMore = true;

  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 0;
      _hasMore = true;
    }
    if (!_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await _api.getExercises(
        token,
        name: _search.text.trim().isEmpty ? null : _search.text.trim(),
        muscle: _filterMuscle,
        page: _page,
        pageSize: _pageSize,
      );
      setState(() {
        if (reset) {
          _exercises = results;
        } else {
          _exercises.addAll(results);
        }
        _hasMore = results.length == _pageSize;
        _page++;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openFilter() async {
    final selected = await showModalBottomSheet<MuscleGroup?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MuscleFilterSheet(current: _filterMuscle),
    );
    if (!mounted) return;
    if (selected != _filterMuscle) {
      setState(() => _filterMuscle = selected);
      _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _filterMuscle != null,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _openFilter,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final created = await Navigator.push<Exercise>(
                context,
                MaterialPageRoute(builder: (_) => const ExerciseFormPage()),
              );
              if (created != null) _load(reset: true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search exercises…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _load(reset: true);
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onSubmitted: (_) => _load(reset: true),
            ),
          ),
          if (_filterMuscle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Chip(
                    label: Text(_filterMuscle!.displayName),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() => _filterMuscle = null);
                      _load(reset: true);
                    },
                    backgroundColor:
                        const Color(0xFFE53935).withValues(alpha: 0.12),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _exercises.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_exercises.isEmpty) {
      return const Center(child: Text('No exercises found'));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!_loading && _hasMore && n.metrics.extentAfter < 200) {
          _load();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _exercises.length + (_loading ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 1),
        itemBuilder: (context, i) {
          if (i == _exercises.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final ex = _exercises[i];
          return _ExerciseCard(
            exercise: ex,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ExerciseDetailPage(exercise: ex)),
              );
              _load(reset: true);
            },
          );
        },
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;

  const _ExerciseCard({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: exercise.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  exercise.imageUrl!,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => _placeholder(),
                ),
              )
            : _placeholder(),
        title: Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: exercise.primaryMuscles.isEmpty
            ? null
            : Text(
                exercise.primaryMuscles.map((m) => m.displayName).join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.fitness_center, color: Colors.grey),
      );
}

// ── Muscle filter bottom sheet ────────────────────────────────────────────────

class _MuscleFilterSheet extends StatelessWidget {
  final MuscleGroup? current;

  const _MuscleFilterSheet({this.current});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Filter by Muscle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('All muscles'),
            trailing: current == null ? const Icon(Icons.check, color: Color(0xFFE53935)) : null,
            onTap: () => Navigator.pop(context, null),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scroll,
              children: MuscleGroup.values.map((m) => ListTile(
                title: Text(m.displayName),
                trailing: current == m ? const Icon(Icons.check, color: Color(0xFFE53935)) : null,
                onTap: () => Navigator.pop(context, m),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
