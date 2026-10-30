import 'package:flutter/material.dart';
import '../models/draft.dart';
import '../widgets/drafts.dart';
import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'exercise_detail_page.dart';
import 'exercise_form_page.dart';
import '../widgets/app_bottom_sheet.dart';

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
  // false → public library; true → only my private exercises (is_public=false).
  bool _privateOnly = false;
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
        isPublic: _privateOnly ? false : null,
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
    final selected = await showAppBottomSheet<MuscleGroup?>(
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
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trainingExerciseTitle),
        actions: [
          IconButton(
            tooltip: _filterMuscle == null
                ? l10n.trainingExerciseFilterTooltip
                : l10n.trainingExerciseFilterActiveTooltip(_filterMuscle!.label(l10n)),
            icon: Badge(
              isLabelVisible: _filterMuscle != null,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _openFilter,
          ),
          IconButton(
            tooltip: l10n.trainingExerciseNewTitle,
            icon: const Icon(Icons.add),
            onPressed: () async {
              final created = await openCreateWithDrafts<Exercise>(
                context,
                kind: DraftKind.exercise,
                builder: (draft) => ExerciseFormPage(draft: draft),
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
                hintText: l10n.trainingExerciseSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        tooltip: l10n.trainingWorkoutsClearSearch,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(l10n.trainingPlanPublic),
                  selected: !_privateOnly,
                  onSelected: (_) {
                    if (!_privateOnly) return;
                    setState(() => _privateOnly = false);
                    _load(reset: true);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.lock_outline, size: 16),
                  label: Text(l10n.trainingExerciseMyPrivate),
                  selected: _privateOnly,
                  onSelected: (_) {
                    if (_privateOnly) return;
                    setState(() => _privateOnly = true);
                    _load(reset: true);
                  },
                ),
              ],
            ),
          ),
          if (_filterMuscle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Chip(
                    label: Text(_filterMuscle!.label(l10n),
                        style: TextStyle(color: cs.onErrorContainer)),
                    deleteIcon: Icon(Icons.close, size: 16, color: cs.onErrorContainer),
                    deleteButtonTooltipMessage: l10n.trainingExerciseClearFilter,
                    onDeleted: () {
                      setState(() => _filterMuscle = null);
                      _load(reset: true);
                    },
                    backgroundColor: cs.errorContainer,
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
    final l10n = context.l10n;
    if (_loading && _exercises.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _load(reset: true), child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    if (_exercises.isEmpty) {
      return Center(
        child: Text(_privateOnly
            ? l10n.trainingExerciseNoPrivate
            : l10n.trainingExerciseNoneFound),
      );
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
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: exercise.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  exercise.displayImageUrl!,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  // Square crop on the right (end position) panel of the illustration.
                  alignment: const Alignment(0.8, 0),
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stack) => _placeholder(cs),
                ),
              )
            : _placeholder(cs),
        title: Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: exercise.primaryMuscles.isEmpty
            ? null
            : Text(
                exercise.primaryMuscles.map((m) => m.label(l10n)).join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.fitness_center, color: cs.onSurfaceVariant),
      );
}

// ── Muscle filter bottom sheet ────────────────────────────────────────────────

class _MuscleFilterSheet extends StatelessWidget {
  final MuscleGroup? current;

  const _MuscleFilterSheet({this.current});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
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
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.trainingExerciseFilterTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: Text(l10n.trainingExerciseAllMuscles),
            selected: current == null,
            trailing: current == null ? Icon(Icons.check, color: cs.primary) : null,
            onTap: () => Navigator.pop(context, null),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scroll,
              children: MuscleGroup.values.map((m) => ListTile(
                title: Text(m.label(l10n)),
                selected: current == m,
                trailing: current == m ? Icon(Icons.check, color: cs.primary) : null,
                onTap: () => Navigator.pop(context, m),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
