import 'package:flutter/material.dart';
import '../config.dart';
import '../l10n/l10n.dart';
import '../models/draft.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../theme.dart';
import '../widgets/drafts.dart';
import '../widgets/image_upload_field.dart';
import 'nutrition/nutrition_widgets.dart';

class MealPlanFormPage extends StatefulWidget {
  final MealPlan? plan;

  /// A saved draft to continue (new plans only).
  final Draft? draft;

  const MealPlanFormPage({super.key, this.plan, this.draft});

  @override
  State<MealPlanFormPage> createState() => _MealPlanFormPageState();
}

class _MealPlanFormPageState extends State<MealPlanFormPage>
    with DraftableForm {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late final TextEditingController _name;
  late final TextEditingController _description;

  int _numWeeks = 1;
  bool _isPublic = false;
  bool _saving = false;

  // Images
  final List<_ImageDraft> _images = [];

  // Schedule: (weekNumber, dayOfWeek) → _DayDraft
  final Map<(int, int), _DayDraft> _schedule = {};

  bool get _isEditing => widget.plan != null;

  // ── Drafts ──────────────────────────────────────────────────────────────────

  @override
  DraftKind get draftKind => DraftKind.mealPlan;
  @override
  Draft? get initialDraft => widget.draft;
  @override
  bool get draftsEnabled => !_isEditing;
  @override
  bool get hasDraftContent =>
      _name.text.trim().isNotEmpty ||
      _description.text.trim().isNotEmpty ||
      _images.any((i) => i.urlController.text.trim().isNotEmpty) ||
      _schedule.isNotEmpty;
  @override
  String? draftTitle() => _name.text;
  @override
  String? draftThumbnailUrl() {
    final images =
        _images.where((i) => i.urlController.text.trim().isNotEmpty).toList();
    if (images.isEmpty) return null;
    final thumb =
        images.firstWhere((i) => i.isThumbnail, orElse: () => images.first);
    return AppConfig.resolveUrl(thumb.urlController.text.trim());
  }
  @override
  Map<String, dynamic> draftData() => {
        'name': _name.text,
        'description': _description.text,
        'num_weeks': _numWeeks,
        'is_public': _isPublic,
        'images': [
          for (final img in _images)
            {'url': img.urlController.text, 'is_thumbnail': img.isThumbnail},
        ],
        // Days past a shortened duration are kept, as on screen until save.
        'days': [
          for (final MapEntry(key: (week, day), value: d) in _schedule.entries)
            {
              'week_number': week,
              'day_of_week': day,
              'daily_meal_plan_id': d.dailyMealPlanId,
              'daily_meal_plan_name': d.dailyMealPlanName,
              'kcal_total': d.kcalTotal,
              'note': d.note,
            },
        ],
      };

  void _restoreDraft(Map<String, dynamic> d) {
    String text(Object? v) => v is String ? v : '';
    int? integer(Object? v) => v == null ? null : int.tryParse(v.toString());
    _name = TextEditingController(text: text(d['name']));
    _description = TextEditingController(text: text(d['description']));
    _isPublic = d['is_public'] is bool ? d['is_public'] as bool : false;
    final weeks = integer(d['num_weeks']) ?? 1;
    _numWeeks = weeks < 1 ? 1 : (weeks > 4 ? 4 : weeks);
    for (final img in _draftMaps(d['images'])) {
      _images.add(_ImageDraft(
        urlController: TextEditingController(text: text(img['url'])),
        isThumbnail: img['is_thumbnail'] == true,
      ));
    }
    for (final day in _draftMaps(d['days'])) {
      final week = integer(day['week_number']);
      final dow = integer(day['day_of_week']);
      final id = day['daily_meal_plan_id'];
      if (week == null || week < 1 || dow == null || dow < 1 || dow > 7) {
        continue;
      }
      if (id is! String || id.isEmpty) continue;
      final kcal = day['kcal_total'];
      _schedule[(week, dow)] = _DayDraft(
        dailyMealPlanId: id,
        dailyMealPlanName: day['daily_meal_plan_name'] is String
            ? day['daily_meal_plan_name'] as String
            : null,
        kcalTotal: kcal == null ? null : double.tryParse(kcal.toString()),
        note: day['note'] is String ? day['note'] as String : null,
      );
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
    final p = widget.plan;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _isPublic = p?.isPublic ?? false;
    _numWeeks = p?.numWeeks ?? 1;

    if (p != null) {
      for (final img in p.images) {
        _images.add(_ImageDraft(
          urlController: TextEditingController(text: img.url),
          isThumbnail: img.isThumbnail,
        ));
      }
      for (final day in p.days) {
        _schedule[(day.weekNumber, day.dayOfWeek)] = _DayDraft(
          dailyMealPlanId: day.dailyMealPlanId,
          dailyMealPlanName: day.dailyMealPlan?.name,
          kcalTotal: day.dailyMealPlan?.kcalTotal,
          note: day.note,
        );
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    for (final img in _images) {
      img.urlController.dispose();
    }
    super.dispose();
  }

  void _addImage() {
    setState(() {
      _images.add(_ImageDraft(urlController: TextEditingController()));
    });
  }

  void _removeImage(int index) {
    _images[index].urlController.dispose();
    setState(() => _images.removeAt(index));
  }

  void _setThumbnail(int index) {
    setState(() {
      for (var i = 0; i < _images.length; i++) {
        _images[i].isThumbnail = i == index;
      }
    });
  }

  Future<void> _pickDailyPlan(int weekNumber, int dayOfWeek) async {
    final result = await showModalBottomSheet<_DailyPlanPickResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DailyPlanPickerSheet(),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.clear) {
        _schedule.remove((weekNumber, dayOfWeek));
      } else {
        _schedule[(weekNumber, dayOfWeek)] = _DayDraft(
          dailyMealPlanId: result.plan!.id,
          dailyMealPlanName: result.plan!.name,
          kcalTotal: result.plan!.kcalTotal,
        );
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final token = await AuthManager.instance.getValidToken();

      final assignedDays = <Map<String, dynamic>>[];
      for (final entry in _schedule.entries) {
        final (weekNum, dayOfWeek) = entry.key;
        final draft = entry.value;
        // Days beyond a shortened duration are dropped, not saved.
        if (weekNum > _numWeeks) continue;
        if (draft.dailyMealPlanId != null) {
          assignedDays.add({
            'daily_meal_plan_id': draft.dailyMealPlanId,
            'week_number': weekNum,
            'day_of_week': dayOfWeek,
            'note': draft.note,
          });
        }
      }

      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        'num_weeks': _numWeeks,
        'is_public': _isPublic,
        'days': assignedDays,
        'images': _images
            .where((img) => img.urlController.text.trim().isNotEmpty)
            .toList()
            .asMap()
            .entries
            .map((e) => {
                  'url': e.value.urlController.text.trim(),
                  'is_thumbnail': e.value.isThumbnail,
                  'position': e.key,
                })
            .toList(),
      };

      final MealPlan result;
      if (_isEditing) {
        result = await _api.updateMealPlan(token, widget.plan!.id, data);
      } else {
        result = await _api.createMealPlan(token, data);
        await draftPublished();
      }
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorText(e), style: TextStyle(color: cs.onError)),
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
    final locale = Localizations.localeOf(context).toString();
    final banner = draftBanner(context);
    return draftPopScope(
      busy: _saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? l10n.nutritionEditMealPlanTitle : l10n.nutritionNewMealPlanTitle),
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
              if (banner != null) ...[banner, const SizedBox(height: 16)],
              // ── Basic ─────────────────────────────────────────────────────
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: l10n.nutritionNameRequiredLabel),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                decoration: InputDecoration(labelText: l10n.nutritionDescription),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // numWeeks segmented button
              Text(l10n.nutritionDuration,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  for (final w in const [1, 2, 3, 4])
                    ButtonSegment(value: w, label: Text(l10n.nutritionWeeksShort(w))),
                ],
                selected: {_numWeeks},
                onSelectionChanged: (s) {
                  if (s.isNotEmpty) setState(() => _numWeeks = s.first);
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(l10n.nutritionPublic),
                subtitle: Text(l10n.nutritionVisibleToAllUsers),
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                contentPadding: EdgeInsets.zero,
              ),

              // ── Images ────────────────────────────────────────────────────
              const SizedBox(height: 20),
              Text(l10n.nutritionImages,
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ..._images.asMap().entries.map((entry) {
                final i = entry.key;
                final img = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: img.urlController,
                            decoration: InputDecoration(
                              hintText: l10n.nutritionImageUrl,
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.nutritionUploadPhoto,
                          icon: const Icon(Icons.upload_outlined, size: 20),
                          onPressed: () => pickAndUploadImage(
                            context: context,
                            bucket: 'media',
                            folder: 'meal-plans',
                            onUploaded: (url) => setState(() => img.urlController.text = url),
                            onUploadingChanged: (_) {},
                          ),
                        ),
                        IconButton(
                          tooltip: img.isThumbnail
                              ? l10n.nutritionThumbnail
                              : l10n.nutritionSetAsThumbnail,
                          isSelected: img.isThumbnail,
                          icon: Icon(
                            img.isThumbnail
                                ? Icons.star
                                : Icons.star_border_outlined,
                            color: img.isThumbnail
                                ? context.appColors.warning
                                : cs.onSurfaceVariant,
                            size: 20,
                          ),
                          onPressed: () => _setThumbnail(i),
                        ),
                        IconButton(
                          tooltip: l10n.nutritionRemoveImage,
                          icon: Icon(Icons.close,
                              size: 18, color: cs.error),
                          onPressed: () => _removeImage(i),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: _addImage,
                icon: const Icon(Icons.add),
                label: Text(l10n.nutritionAddImage),
              ),

              // ── Schedule ──────────────────────────────────────────────────
              const SizedBox(height: 24),
              Text(l10n.nutritionSchedule,
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...List.generate(_numWeeks, (wi) {
                final weekNum = wi + 1;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: ExpansionTile(
                    title: Text(l10n.nutritionWeekNumber(weekNum),
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    children: List.generate(7, (di) {
                      final dayOfWeek = di + 1;
                      final label = shortWeekdayName(dayOfWeek, locale);
                      final draft = _schedule[(weekNum, dayOfWeek)];
                      return ListTile(
                        dense: true,
                        leading: SizedBox(
                          width: 36,
                          child: Text(label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                        title: draft?.dailyMealPlanName != null
                            ? Text(draft!.dailyMealPlanName!)
                            : Text(l10n.nutritionUnassigned,
                                style: TextStyle(color: cs.onSurfaceVariant)),
                        trailing: IconButton(
                          tooltip: l10n.nutritionChooseDailyPlanFor(
                              l10n.nutritionWeekNumber(weekNum), label),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () =>
                              _pickDailyPlan(weekNum, dayOfWeek),
                        ),
                      );
                    }),
                  ),
                );
              }),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Draft models ──────────────────────────────────────────────────────────────

class _DayDraft {
  String? dailyMealPlanId;
  String? dailyMealPlanName;
  double? kcalTotal;
  String? note;

  _DayDraft({
    this.dailyMealPlanId,
    this.dailyMealPlanName,
    this.kcalTotal,
    this.note,
  });
}

class _ImageDraft {
  final TextEditingController urlController;
  bool isThumbnail;

  _ImageDraft({required this.urlController, this.isThumbnail = false});
}

Iterable<Map<String, dynamic>> _draftMaps(Object? raw) => raw is List
    ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m))
    : const [];

class _DailyPlanPickResult {
  final DailyMealPlan? plan;
  final bool clear;

  const _DailyPlanPickResult({this.plan, this.clear = false});
}

// ── Daily plan picker sheet ───────────────────────────────────────────────────

class _DailyPlanPickerSheet extends StatefulWidget {
  @override
  State<_DailyPlanPickerSheet> createState() => _DailyPlanPickerSheetState();
}

class _DailyPlanPickerSheetState extends State<_DailyPlanPickerSheet> {
  final _api = ApiService();
  final _search = TextEditingController();
  List<DailyMealPlan> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await _api.getDailyMealPlans(
        token,
        name: _search.text.trim().isEmpty ? null : _search.text.trim(),
        pageSize: 50,
      );
      setState(() {
        _plans = results;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.nutritionSearchDailyPlansHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          // Clear option
          ListTile(
            leading: Icon(Icons.block_outlined, color: cs.onSurfaceVariant),
            title: Text(l10n.nutritionClearUnassign,
                style: TextStyle(color: cs.onSurfaceVariant)),
            onTap: () => Navigator.pop(
                context, const _DailyPlanPickResult(clear: true)),
          ),
          const Divider(height: 1),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: _plans.length,
                itemBuilder: (context, i) {
                  final plan = _plans[i];
                  return ListTile(
                    leading: const Icon(Icons.restaurant_menu_outlined),
                    title: Text(plan.name),
                    subtitle: Text(
                      '${l10n.nutritionKcalValue(plan.kcalTotal.round())} · '
                      '${l10n.nutritionPcfGrams(plan.proteinTotal.round(), plan.carbTotal.round(), plan.fatTotal.round())}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => Navigator.pop(
                        context, _DailyPlanPickResult(plan: plan)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
