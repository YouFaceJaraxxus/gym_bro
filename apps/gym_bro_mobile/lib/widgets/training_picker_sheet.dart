import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/training.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'app_bottom_sheet.dart';

const _kDebounce = Duration(milliseconds: 350);

/// What [showTrainingPicker] pops with: the picked training (a list row,
/// without sets), or null for the "no training" option.
typedef TrainingPick = ({Training? training});

/// A searchable sheet of trainings in priority order: ones the user logged
/// before, then ones from routines a coach assigned them, then their own and
/// public trainings. Typing filters every section (debounced).
///
/// [noneLabel] adds a first option for going without a training (e.g. a
/// free session). Returns null when dismissed.
Future<TrainingPick?> showTrainingPicker(
  BuildContext context, {
  String? title,
  String? noneLabel,
}) {
  return showAppBottomSheet<TrainingPick>(
    context: context,
    isScrollControlled: true,
    builder: (_) => TrainingPickerSheet(title: title, noneLabel: noneLabel),
  );
}

class TrainingPickerSheet extends StatefulWidget {
  const TrainingPickerSheet({super.key, this.title, this.noneLabel});

  final String? title;
  final String? noneLabel;

  @override
  State<TrainingPickerSheet> createState() => _TrainingPickerSheetState();
}

class _TrainingPickerSheetState extends State<TrainingPickerSheet> {
  final _api = ApiService();
  final _search = TextEditingController();
  Timer? _debounce;
  String _activeQuery = '';
  TrainingSuggestions? _results;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onTextChanged);
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onTextChanged);
    _search.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final query = _search.text.trim();
    if (query == _activeQuery) return;
    _debounce?.cancel();
    _debounce = Timer(_kDebounce, () => _load(query));
  }

  Future<void> _load(String query) async {
    if (!mounted) return;
    setState(() {
      _activeQuery = query;
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await _api.getTrainingSuggestions(
        token,
        name: query,
        limit: 20,
      );
      if (!mounted || _activeQuery != query) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || _activeQuery != query) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _pick(Training? t) => Navigator.pop<TrainingPick>(context, (training: t));

  Widget _header(String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }

  Widget _tile(TrainingSuggestion s, String? subtitle) {
    final cs = Theme.of(context).colorScheme;
    final t = s.training;
    final thumb = t.thumbnailUrl;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 44,
          child: thumb.isNotEmpty
              ? Image.network(
                  thumb,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => _placeholder(cs),
                )
              : _placeholder(cs),
        ),
      ),
      title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null || subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => _pick(t),
    );
  }

  static Widget _placeholder(ColorScheme cs) => ColoredBox(
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.fitness_center, color: cs.onSurfaceVariant, size: 20),
      );

  Widget _buildList(ScrollController scroll) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final r = _results;
    if (r == null && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (r == null && _error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: cs.error), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _load(_activeQuery), child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (widget.noneLabel != null)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.secondaryContainer,
              child: Icon(Icons.edit_note, color: cs.onSecondaryContainer),
            ),
            title: Text(widget.noneLabel!),
            onTap: () => _pick(null),
          ),
        if (r != null && r.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              l10n.workoutPickerNoResults,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        if (r != null && r.recent.isNotEmpty) ...[
          _header(l10n.workoutPickerRecent),
          for (final s in r.recent)
            _tile(
              s,
              s.lastUsedAt == null
                  ? null
                  : l10n.workoutPickerLastLogged(
                      DateFormat.yMMMd(locale).format(s.lastUsedAt!.toLocal()),
                    ),
            ),
        ],
        if (r != null && r.assigned.isNotEmpty) ...[
          _header(l10n.workoutPickerAssigned),
          for (final s in r.assigned)
            _tile(
              s,
              [s.routineName, s.assignedByName].whereType<String>().join(' · '),
            ),
        ],
        if (r != null && r.library.isNotEmpty) ...[
          _header(l10n.workoutPickerLibrary),
          for (final s in r.library) _tile(s, s.training.description),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          if (widget.title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(widget.title!, style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.workoutPickerSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onSubmitted: (v) {
                _debounce?.cancel();
                _load(v.trim());
              },
            ),
          ),
          SizedBox(
            height: 2,
            child: _loading && _results != null ? const LinearProgressIndicator() : null,
          ),
          Expanded(child: _buildList(scroll)),
        ],
      ),
    );
  }
}
