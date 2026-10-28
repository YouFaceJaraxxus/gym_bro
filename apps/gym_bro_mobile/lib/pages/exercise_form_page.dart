import 'package:flutter/material.dart';
import '../config.dart';
import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../theme.dart';
import '../widgets/image_upload_field.dart';
import '../widgets/muscle_diagram.dart';

class ExerciseFormPage extends StatefulWidget {
  final Exercise? exercise;

  const ExerciseFormPage({super.key, this.exercise});

  @override
  State<ExerciseFormPage> createState() => _ExerciseFormPageState();
}

class _ExerciseFormPageState extends State<ExerciseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _note;
  late final TextEditingController _imageUrl;
  late final TextEditingController _videoUrl;

  final Set<MuscleGroup> _primaryMuscles = {};
  final Set<MuscleGroup> _secondaryMuscles = {};
  bool _isPublic = true;
  bool _saving = false;

  bool get _isEditing => widget.exercise != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.exercise;
    _name = TextEditingController(text: ex?.name ?? '');
    _description = TextEditingController(text: ex?.description ?? '');
    _note = TextEditingController(text: ex?.note ?? '');
    _imageUrl = TextEditingController(text: ex?.imageUrl ?? '');
    _videoUrl = TextEditingController(text: ex?.videoUrl ?? '');
    if (ex != null) {
      _primaryMuscles.addAll(ex.primaryMuscles);
      _secondaryMuscles.addAll(ex.secondaryMuscles);
      _isPublic = ex.isPublic;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _note.dispose();
    _imageUrl.dispose();
    _videoUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cs = Theme.of(context).colorScheme;
    setState(() => _saving = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final data = {
        'name': _name.text.trim(),
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'image_url': _imageUrl.text.trim().isEmpty
            ? null
            : _imageUrl.text.trim(),
        'video_url': _videoUrl.text.trim().isEmpty
            ? null
            : _videoUrl.text.trim(),
        'primary_muscles': _primaryMuscles.map((m) => m.apiValue).toList(),
        'secondary_muscles': _secondaryMuscles.map((m) => m.apiValue).toList(),
        'is_public': _isPublic,
      };
      final Exercise result;
      if (_isEditing) {
        result = await _api.updateExercise(token, widget.exercise!.id, data);
      } else {
        result = await _api.createExercise(token, data);
      }
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      setState(() => _saving = false);
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

  Future<void> _pickMuscles(bool isPrimary) async {
    final current = isPrimary ? _primaryMuscles : _secondaryMuscles;
    final other = isPrimary ? _secondaryMuscles : _primaryMuscles;
    final l10n = context.l10n;

    final result = await showModalBottomSheet<Set<MuscleGroup>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MusclePickerSheet(
        selected: Set.from(current),
        excluded: other,
        title: isPrimary
            ? l10n.trainingExercisePrimaryMuscles
            : l10n.trainingExerciseSecondaryMuscles,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (isPrimary) {
          _primaryMuscles
            ..clear()
            ..addAll(result);
        } else {
          _secondaryMuscles
            ..clear()
            ..addAll(result);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final app = context.appColors;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? l10n.trainingExerciseEditTitle
              : l10n.trainingExerciseNewTitle,
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(onPressed: _save, child: Text(l10n.commonSave)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l10n.trainingExerciseNameLabel,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              decoration: InputDecoration(
                labelText: l10n.trainingPlanDescriptionLabel,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              decoration: InputDecoration(
                labelText: l10n.trainingAssignNoteLabel,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ImagePickerField(
              imageUrl: _imageUrl.text.isEmpty ? null : AppConfig.resolveUrl(_imageUrl.text),
              folder: 'exercises',
              label: l10n.trainingExerciseAddPhoto,
              onUploaded: (url) => setState(() => _imageUrl.text = url),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _videoUrl,
              decoration: InputDecoration(
                labelText: l10n.trainingExerciseVideoUrl,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),

            // Muscle diagram preview
            if (_primaryMuscles.isNotEmpty) ...[
              Center(
                child: MuscleDiagram(
                  primaryMuscles: _primaryMuscles,
                  secondaryMuscles: _secondaryMuscles,
                  size: 180,
                ),
              ),
              const SizedBox(height: 8),
              const Center(child: MuscleDiagramLegend()),
              const SizedBox(height: 16),
            ],

            _MusclePickerTile(
              label: l10n.trainingExercisePrimaryMuscles,
              muscles: _primaryMuscles,
              background: cs.errorContainer,
              foreground: cs.onErrorContainer,
              border: cs.error,
              onTap: () => _pickMuscles(true),
            ),
            const SizedBox(height: 8),
            _MusclePickerTile(
              label: l10n.trainingExerciseSecondaryMuscles,
              muscles: _secondaryMuscles,
              background: app.warningContainer,
              foreground: app.onWarningContainer,
              border: app.warning,
              onTap: () => _pickMuscles(false),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: Text(l10n.trainingPlanPublic),
              subtitle: Text(l10n.trainingPlanPublicSubtitle),
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _MusclePickerTile extends StatelessWidget {
  final String label;
  final Set<MuscleGroup> muscles;
  final Color background;
  final Color foreground;
  final Color border;
  final VoidCallback onTap;

  const _MusclePickerTile({
    required this.label,
    required this.muscles,
    required this.background,
    required this.foreground,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (muscles.isEmpty)
                        Text(
                          l10n.trainingExerciseTapToSelect,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: muscles
                              .map(
                                (m) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: border.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    m.label(l10n),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: foreground,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Muscle picker bottom sheet ────────────────────────────────────────────────

class _MusclePickerSheet extends StatefulWidget {
  final Set<MuscleGroup> selected;
  final Set<MuscleGroup> excluded;
  final String title;

  const _MusclePickerSheet({
    required this.selected,
    required this.excluded,
    required this.title,
  });

  @override
  State<_MusclePickerSheet> createState() => _MusclePickerSheetState();
}

class _MusclePickerSheetState extends State<_MusclePickerSheet> {
  late final Set<MuscleGroup> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Text(context.l10n.trainingExerciseDone),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scroll,
              children: MuscleGroup.values.map((m) {
                final excluded = widget.excluded.contains(m);
                return CheckboxListTile(
                  title: Text(
                    m.label(context.l10n),
                    style: TextStyle(
                      color: excluded
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  value: _selected.contains(m),
                  onChanged: excluded
                      ? null
                      : (v) => setState(
                          () => v! ? _selected.add(m) : _selected.remove(m),
                        ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
