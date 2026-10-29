import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/draft.dart';
import '../models/routine.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/drafts.dart';
import '../widgets/image_upload_field.dart';
import '../widgets/training_picker_sheet.dart';

class RoutineFormPage extends StatefulWidget {
  final Routine? routine;

  /// A saved draft to continue (new routines only).
  final Draft? draft;

  const RoutineFormPage({super.key, this.routine, this.draft});

  @override
  State<RoutineFormPage> createState() => _RoutineFormPageState();
}

class _RoutineFormPageState extends State<RoutineFormPage> with DraftableForm {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  late final TextEditingController _numWeeks;

  bool _isPublic = false;
  RoutineScheduleType _scheduleType = RoutineScheduleType.wildcard;
  bool _saving = false;
  String? _thumbnailUrl;

  final List<_RoutineTrainingDraft> _entries = [];

  bool get _isEditing => widget.routine != null;

  // ── Drafts ──────────────────────────────────────────────────────────────────

  @override
  DraftKind get draftKind => DraftKind.routine;
  @override
  Draft? get initialDraft => widget.draft;
  @override
  bool get draftsEnabled => !_isEditing;
  @override
  bool get hasDraftContent =>
      [_name, _description, _notes, _numWeeks].any((c) => c.text.trim().isNotEmpty) ||
      _thumbnailUrl != null ||
      _entries.isNotEmpty;
  @override
  String? draftTitle() => _name.text;
  @override
  String? draftThumbnailUrl() => _thumbnailUrl;
  @override
  Map<String, dynamic> draftData() => {
        'name': _name.text,
        'description': _description.text,
        'notes': _notes.text,
        'num_weeks': _numWeeks.text,
        'is_public': _isPublic,
        'schedule_type': _scheduleType.apiValue,
        'thumbnail_url': _thumbnailUrl,
        'trainings': [
          for (final e in _entries)
            {
              'training_id': e.trainingId,
              'training_name': e.trainingName,
              'week_number': e.weekNumber,
              'day_of_week': e.dayOfWeek,
              'note': e.note,
            },
        ],
      };

  void _restoreDraft(Map<String, dynamic> draft) {
    String? str(Object? v) => v is String ? v : null;
    int? integer(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    _name = TextEditingController(text: str(draft['name']) ?? '');
    _description = TextEditingController(text: str(draft['description']) ?? '');
    _notes = TextEditingController(text: str(draft['notes']) ?? '');
    _numWeeks = TextEditingController(text: str(draft['num_weeks']) ?? '${integer(draft['num_weeks']) ?? ''}');
    _isPublic = draft['is_public'] == true;
    _scheduleType = RoutineScheduleType.fromApiValue(str(draft['schedule_type']) ?? '');
    final thumb = str(draft['thumbnail_url']);
    _thumbnailUrl = thumb?.isNotEmpty == true ? thumb : null;
    // The week dropdown only offers 1..numWeeks (as the list renders it).
    final numWeeks = int.tryParse(_numWeeks.text) ?? 1;
    final raw = draft['trainings'];
    for (final t in raw is List ? raw : const []) {
      if (t is! Map) continue;
      final id = str(t['training_id']);
      if (id == null || id.isEmpty) continue;
      final week = integer(t['week_number']);
      final day = integer(t['day_of_week']);
      _entries.add(_RoutineTrainingDraft(
        trainingId: id,
        trainingName: str(t['training_name']),
        weekNumber: week != null && week >= 1 && week <= numWeeks ? week : null,
        dayOfWeek: day != null && day >= 1 && day <= 7 ? day : null,
        position: _entries.length,
        note: str(t['note']),
      ));
    }
  }

  @override
  void initState() {
    super.initState();
    final draft = widget.draft?.data;
    if (draft != null && !_isEditing) {
      _restoreDraft(draft);
      return;
    }
    final r = widget.routine;
    _name = TextEditingController(text: r?.name ?? '');
    _description = TextEditingController(text: r?.description ?? '');
    _notes = TextEditingController(text: r?.notes ?? '');
    _numWeeks = TextEditingController(text: r?.numWeeks?.toString() ?? '');
    _isPublic = r?.isPublic ?? false;
    _scheduleType = r?.scheduleType ?? RoutineScheduleType.wildcard;
    _thumbnailUrl = r?.thumbnailUrl.isNotEmpty == true ? r!.thumbnailUrl : null;
    if (r != null) {
      for (final t in r.trainings) {
        _entries.add(_RoutineTrainingDraft(
          trainingId: t.trainingId,
          trainingName: t.training?.name,
          weekNumber: t.weekNumber,
          dayOfWeek: t.dayOfWeek,
          position: t.position,
          note: t.note,
        ));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _notes.dispose();
    _numWeeks.dispose();
    super.dispose();
  }

  Future<void> _pickTraining() async {
    final picked = (await showTrainingPicker(context))?.training;
    if (picked != null && mounted) {
      setState(() => _entries.add(_RoutineTrainingDraft(
            trainingId: picked.id,
            trainingName: picked.name,
          )));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (_scheduleType == RoutineScheduleType.fixedWeeks) {
      final weeks = int.tryParse(_numWeeks.text.trim());
      if (weeks == null || weeks < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.trainingRoutineInvalidWeeks)),
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final numWeeks = _scheduleType == RoutineScheduleType.fixedWeeks
          ? int.tryParse(_numWeeks.text.trim())
          : null;

      final data = {
        'name': _name.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'is_public': _isPublic,
        'schedule_type': _scheduleType.apiValue,
        'num_weeks': numWeeks,
        'images': _thumbnailUrl != null
            ? [{'url': _thumbnailUrl, 'is_thumbnail': true, 'position': 0}]
            : <Map<String, dynamic>>[],
        'trainings': _entries.asMap().entries.map((e) => e.value.toJson(e.key)).toList(),
      };

      final Routine result;
      if (_isEditing) {
        result = await _api.updateRoutine(token, widget.routine!.id, data);
      } else {
        result = await _api.createRoutine(token, data);
        await draftPublished();
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final banner = draftBanner(context);
    return draftPopScope(
      busy: _saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? l10n.trainingRoutineEditTitle : l10n.trainingWorkoutsNewRoutine),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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
              if (banner != null) ...[banner, const SizedBox(height: 16)],
              ImagePickerField(
                imageUrl: _thumbnailUrl,
                folder: 'routines',
                label: l10n.trainingPlanAddCoverPhoto,
                onUploaded: (url) => setState(() => _thumbnailUrl = url),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: l10n.trainingRoutineNameLabel),
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                decoration: InputDecoration(labelText: l10n.trainingPlanDescriptionLabel),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                decoration: InputDecoration(labelText: l10n.trainingPlanNotes),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                title: Text(l10n.trainingPlanPublic),
                subtitle: Text(l10n.trainingPlanPublicSubtitle),
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),

              // Schedule type
              Text(l10n.trainingRoutineScheduleType,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<RoutineScheduleType>(
                segments: [
                  ButtonSegment(
                      value: RoutineScheduleType.wildcard,
                      label: Text(RoutineScheduleType.wildcard.label(l10n))),
                  ButtonSegment(
                      value: RoutineScheduleType.fixedWeeks,
                      label: Text(RoutineScheduleType.fixedWeeks.label(l10n))),
                ],
                selected: {_scheduleType},
                onSelectionChanged: (s) => setState(() => _scheduleType = s.first),
              ),

              if (_scheduleType == RoutineScheduleType.fixedWeeks) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _numWeeks,
                  decoration: InputDecoration(
                    labelText: l10n.trainingRoutineNumWeeksLabel,
                    hintText: l10n.trainingRoutineNumWeeksHint,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (_scheduleType != RoutineScheduleType.fixedWeeks) return null;
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1) return l10n.trainingRoutineInvalidNumber;
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.trainingWorkoutsTabTrainings,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _pickTraining,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.trainingRoutineAdd),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(l10n.trainingRoutineNoTrainingsAdded,
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _entries.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _entries.removeAt(oldIndex);
                      _entries.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, i) {
                    final entry = _entries[i];
                    return _TrainingEntryTile(
                      key: ValueKey('${entry.trainingId}_$i'),
                      entry: entry,
                      index: i,
                      scheduleType: _scheduleType,
                      numWeeks: int.tryParse(_numWeeks.text) ?? 1,
                      onChanged: () => setState(() {}),
                      onRemove: () => setState(() => _entries.removeAt(i)),
                    );
                  },
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineTrainingDraft {
  final String trainingId;

  /// Null when the API row has no embedded training; shown as a fallback.
  final String? trainingName;
  int? weekNumber;
  int? dayOfWeek;
  int position;
  String? note;

  _RoutineTrainingDraft({
    required this.trainingId,
    required this.trainingName,
    this.weekNumber,
    this.dayOfWeek,
    this.position = 0,
    this.note,
  });

  Map<String, dynamic> toJson(int index) => {
        'training_id': trainingId,
        'week_number': weekNumber,
        'day_of_week': dayOfWeek,
        'position': index,
        'note': note,
      };
}

class _TrainingEntryTile extends StatelessWidget {
  final _RoutineTrainingDraft entry;
  final int index;
  final RoutineScheduleType scheduleType;
  final int numWeeks;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _TrainingEntryTile({
    super.key,
    required this.entry,
    required this.index,
    required this.scheduleType,
    required this.numWeeks,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final dayFmt = DateFormat.E(Localizations.localeOf(context).toString());
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: Icon(Icons.drag_handle,
              color: cs.onSurfaceVariant, semanticLabel: l10n.trainingPlanReorderSet),
        ),
        title: Text(entry.trainingName ?? l10n.trainingRoutineTrainingFallback,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: scheduleType == RoutineScheduleType.fixedWeeks
            ? Row(
                children: [
                  // Week picker
                  DropdownButton<int>(
                    value: entry.weekNumber,
                    hint: Text(l10n.trainingRoutineWeekShortHint, style: const TextStyle(fontSize: 12)),
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: List.generate(numWeeks, (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(l10n.trainingRoutineWeekShort(i + 1), style: const TextStyle(fontSize: 12)),
                    )),
                    onChanged: (v) {
                      entry.weekNumber = v;
                      onChanged();
                    },
                  ),
                  const SizedBox(width: 8),
                  // Day picker
                  DropdownButton<int>(
                    value: entry.dayOfWeek,
                    hint: Text(l10n.trainingRoutineDayHint, style: const TextStyle(fontSize: 12)),
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: List.generate(7, (i) => DropdownMenuItem(
                      value: i + 1,
                      // 2024-01-01 was a Monday.
                      child: Text(dayFmt.format(DateTime(2024, 1, i + 1)),
                          style: const TextStyle(fontSize: 12)),
                    )),
                    onChanged: (v) {
                      entry.dayOfWeek = v;
                      onChanged();
                    },
                  ),
                ],
              )
            : null,
        trailing: IconButton(
          tooltip: l10n.trainingRoutineRemoveTraining,
          icon: Icon(Icons.close, color: cs.error),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
