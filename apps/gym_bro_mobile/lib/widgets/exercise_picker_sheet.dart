import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

const _kDebounce = Duration(milliseconds: 350);

/// Opens a searchable bottom sheet of exercises and returns the picked one
/// (or null when dismissed). Results update as you type (debounced).
Future<Exercise?> showExercisePicker(BuildContext context) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ExercisePickerSheet(),
  );
}

class ExercisePickerSheet extends StatefulWidget {
  const ExercisePickerSheet({super.key});

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  final _api = ApiService();
  final _search = TextEditingController();
  List<Exercise> _exercises = [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(_onTextChanged);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onTextChanged);
    _search.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_search.text.trim() == _activeQuery) return;
    _debounce?.cancel();
    _debounce = Timer(_kDebounce, _load);
  }

  Future<void> _load() async {
    _debounce?.cancel();
    final query = _search.text.trim();
    setState(() {
      _activeQuery = query;
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await _api.getExercises(
        token,
        name: query.isEmpty ? null : query,
        pageSize: 50,
      );
      if (!mounted || query != _activeQuery) return;
      setState(() {
        _exercises = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || query != _activeQuery) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _buildList(ScrollController scroll) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                style: TextStyle(color: cs.error),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    if (_exercises.isEmpty) {
      return Center(
        child: Text(l10n.trainingExerciseNoneFound,
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return ListView.builder(
      controller: scroll,
      itemCount: _exercises.length,
      itemBuilder: (context, i) {
        final ex = _exercises[i];
        return ListTile(
          leading: ex.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    ex.displayImageUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    // Square crop on the right (end position) panel of the illustration.
                    alignment: const Alignment(0.8, 0),
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.fitness_center),
                  ),
                )
              : const Icon(Icons.fitness_center),
          title: Text(ex.name),
          subtitle: ex.primaryMuscles.isEmpty
              ? null
              : Text(
                  ex.primaryMuscles.map((m) => m.label(l10n)).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
          onTap: () => Navigator.pop(context, ex),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.l10n.trainingExerciseSearchHint,
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(child: _buildList(scroll)),
        ],
      ),
    );
  }
}
