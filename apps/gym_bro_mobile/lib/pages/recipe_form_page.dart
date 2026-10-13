import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../theme.dart';
import '../widgets/image_upload_field.dart';
import 'nutrition/nutrition_widgets.dart';

class RecipeFormPage extends StatefulWidget {
  final Recipe? recipe;

  const RecipeFormPage({super.key, this.recipe});

  @override
  State<RecipeFormPage> createState() => _RecipeFormPageState();
}

class _RecipeFormPageState extends State<RecipeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  // Basic info controllers
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _servings;
  late final TextEditingController _prepTime;
  late final TextEditingController _cookTime;
  bool _isPublic = false;
  bool _saving = false;

  // Images
  final List<_ImageDraft> _images = [];

  // Ingredients
  final List<_IngredientDraft> _ingredients = [];

  // Steps
  final List<_StepDraft> _steps = [];

  // Videos
  final List<_VideoDraft> _videos = [];

  bool get _isEditing => widget.recipe != null;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _name = TextEditingController(text: r?.name ?? '');
    _description = TextEditingController(text: r?.description ?? '');
    _servings = TextEditingController(text: r?.servings.toString() ?? '1');
    _prepTime = TextEditingController(text: r?.prepTimeMinutes?.toString() ?? '');
    _cookTime = TextEditingController(text: r?.cookTimeMinutes?.toString() ?? '');
    _isPublic = r?.isPublic ?? false;

    if (r != null) {
      for (final img in r.images) {
        _images.add(_ImageDraft(
          urlController: TextEditingController(text: img.url),
          isThumbnail: img.isThumbnail,
        ));
      }
      for (final ing in r.ingredients) {
        _ingredients.add(_IngredientDraft(
          foodItemId: ing.foodItemId,
          foodItemName: ing.foodItem?.name ?? ing.foodItemId,
          servingUnit: ing.foodItem?.servingUnit ?? ServingUnit.g,
          quantityController: TextEditingController(text: ing.quantity.toString()),
          noteController: TextEditingController(text: ing.note ?? ''),
        ));
      }
      for (final step in r.steps) {
        _steps.add(_StepDraft(
          instructionController: TextEditingController(text: step.instruction),
          imageUrlController: TextEditingController(text: step.imageUrl ?? ''),
        ));
      }
      for (final v in r.videos) {
        _videos.add(_VideoDraft(
          urlController: TextEditingController(text: v.url),
          titleController: TextEditingController(text: v.title ?? ''),
        ));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _servings.dispose();
    _prepTime.dispose();
    _cookTime.dispose();
    for (final img in _images) { img.dispose(); }
    for (final ing in _ingredients) { ing.dispose(); }
    for (final step in _steps) { step.dispose(); }
    for (final v in _videos) { v.dispose(); }
    super.dispose();
  }

  // ── Computed macros from ingredients ────────────────────────────────────────

  ({double kcal, double protein, double carb, double fat}) _computedMacros() {
    double kcal = 0, protein = 0, carb = 0, fat = 0;
    for (final ing in _ingredients) {
      final qty = double.tryParse(ing.quantityController.text.trim()) ?? 0;
      if (ing.foodItem != null) {
        kcal += ing.foodItem!.kcalPer100 * qty / 100;
        protein += ing.foodItem!.proteinPer100 * qty / 100;
        carb += ing.foodItem!.carbPer100 * qty / 100;
        fat += ing.foodItem!.fatPer100 * qty / 100;
      }
    }
    final s = int.tryParse(_servings.text.trim()) ?? 1;
    final divisor = s > 0 ? s.toDouble() : 1.0;
    return (
      kcal: kcal / divisor,
      protein: protein / divisor,
      carb: carb / divisor,
      fat: fat / divisor,
    );
  }

  // ── Thumbnail management ─────────────────────────────────────────────────────

  void _setThumbnail(int index) {
    setState(() {
      for (var i = 0; i < _images.length; i++) {
        _images[i].isThumbnail = i == index;
      }
    });
  }

  // ── Food picker ─────────────────────────────────────────────────────────────

  Future<void> _openFoodPicker() async {
    final picked = await showModalBottomSheet<FoodItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FoodPickerSheet(),
    );
    if (picked == null || !mounted) return;

    // Ask for quantity
    final qtyController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.nutritionAddNamed(picked.name)),
        content: TextField(
          controller: qtyController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: ctx.l10n.nutritionLabelWithUnit(ctx.l10n.nutritionQuantity, picked.servingUnit.displayName),
            hintText: ctx.l10n.nutritionBarcodeExample('150'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.nutritionAdd)),
        ],
      ),
    );
    qtyController.dispose();
    if (confirmed != true || !mounted) return;

    // Re-read via a fresh controller we keep
    final qty = double.tryParse(qtyController.text.trim()) ?? 0;
    setState(() {
      _ingredients.add(_IngredientDraft(
        foodItemId: picked.id,
        foodItemName: picked.name,
        servingUnit: picked.servingUnit,
        foodItem: picked,
        quantityController: TextEditingController(text: qty > 0 ? qty.toString() : ''),
        noteController: TextEditingController(),
      ));
    });
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final token = await AuthManager.instance.getValidToken();
      final macros = _computedMacros();
      final servings = int.tryParse(_servings.text.trim()) ?? 1;

      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'servings': servings,
        'prep_time_minutes': _prepTime.text.trim().isEmpty ? null : int.tryParse(_prepTime.text.trim()),
        'cook_time_minutes': _cookTime.text.trim().isEmpty ? null : int.tryParse(_cookTime.text.trim()),
        'is_public': _isPublic,
        'kcal_per_serving': macros.kcal,
        'protein_per_serving': macros.protein,
        'carb_per_serving': macros.carb,
        'fat_per_serving': macros.fat,
        'fiber_per_serving': 0.0,
        'images': _images.asMap().entries.map((e) => {
              'url': e.value.urlController.text.trim(),
              'is_thumbnail': e.value.isThumbnail,
              'position': e.key,
            }).where((m) => (m['url'] as String).isNotEmpty).toList(),
        'ingredients': _ingredients.asMap().entries.map((e) => {
              'food_item_id': e.value.foodItemId,
              'quantity': double.tryParse(e.value.quantityController.text.trim()) ?? 0,
              'note': e.value.noteController.text.trim().isEmpty ? null : e.value.noteController.text.trim(),
              'position': e.key,
            }).toList(),
        'steps': _steps.asMap().entries.map((e) => {
              'instruction': e.value.instructionController.text.trim(),
              'image_url': e.value.imageUrlController.text.trim().isEmpty ? null : e.value.imageUrlController.text.trim(),
              'position': e.key,
            }).where((m) => (m['instruction'] as String).isNotEmpty).toList(),
        'videos': _videos.asMap().entries.map((e) => {
              'url': e.value.urlController.text.trim(),
              'title': e.value.titleController.text.trim().isEmpty ? null : e.value.titleController.text.trim(),
              'position': e.key,
            }).where((m) => (m['url'] as String).isNotEmpty).toList(),
      };

      final Recipe result;
      if (_isEditing) {
        result = await _api.updateRecipe(token, widget.recipe!.id, data);
      } else {
        result = await _api.createRecipe(token, data);
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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final macros = _computedMacros();
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final macroColors = MacroColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.nutritionEditRecipeTitle : l10n.nutritionNewRecipeTitle),
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
            // ── Basic info ───────────────────────────────────────────────────
            _SectionHeader(l10n.nutritionBasicInfo),
            const SizedBox(height: 10),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.nutritionRecipeNameRequiredLabel),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              decoration: InputDecoration(labelText: l10n.nutritionDescription),
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _servings,
              decoration: InputDecoration(labelText: l10n.nutritionServingsRequiredLabel),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 1) return l10n.nutritionEnterValidNumber;
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prepTime,
                    decoration: InputDecoration(labelText: l10n.nutritionPrepMinLabel),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cookTime,
                    decoration: InputDecoration(labelText: l10n.nutritionCookMinLabel),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(l10n.nutritionPublic),
              subtitle: Text(l10n.nutritionVisibleToAllUsers),
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),

            // ── Images ───────────────────────────────────────────────────────
            _SectionHeader(l10n.nutritionImages),
            const SizedBox(height: 10),
            ..._images.asMap().entries.map((e) {
              final i = e.key;
              final img = e.value;
              return Card(
                key: ValueKey('img_$i'),
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: img.urlController,
                          decoration: InputDecoration(labelText: l10n.nutritionImageUrl, border: InputBorder.none),
                          keyboardType: TextInputType.url,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.nutritionUploadPhoto,
                        icon: const Icon(Icons.upload_outlined),
                        onPressed: () => pickAndUploadImage(
                          context: context,
                          bucket: 'media',
                          folder: 'recipes',
                          onUploaded: (url) => setState(() => img.urlController.text = url),
                          onUploadingChanged: (_) {},
                        ),
                      ),
                      // Thumbnail selector
                      IconButton(
                        tooltip: img.isThumbnail ? l10n.nutritionThumbnail : l10n.nutritionSetAsThumbnail,
                        isSelected: img.isThumbnail,
                        icon: Icon(
                          img.isThumbnail ? Icons.star : Icons.star_border,
                          color: img.isThumbnail ? context.appColors.warning : cs.onSurfaceVariant,
                        ),
                        onPressed: () => _setThumbnail(i),
                      ),
                      IconButton(
                        tooltip: l10n.nutritionRemoveImage,
                        icon: Icon(Icons.close, color: cs.error),
                        onPressed: () => setState(() {
                          _images[i].dispose();
                          _images.removeAt(i);
                        }),
                      ),
                    ],
                  ),
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => _images.add(_ImageDraft(
                    urlController: TextEditingController(),
                    isThumbnail: _images.isEmpty,
                  ))),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.nutritionAddImage),
            ),
            const SizedBox(height: 24),

            // ── Ingredients ─────────────────────────────────────────────────
            _SectionHeader(l10n.nutritionIngredients),
            const SizedBox(height: 10),
            if (_ingredients.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.nutritionNoIngredientsYet,
                  style: TextStyle(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ingredients.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _ingredients.removeAt(oldIndex);
                    _ingredients.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, i) {
                  final ing = _ingredients[i];
                  return _IngredientTile(
                    key: ValueKey('ing_$i'),
                    draft: ing,
                    index: i,
                    onChanged: () => setState(() {}),
                    onRemove: () => setState(() {
                      _ingredients[i].dispose();
                      _ingredients.removeAt(i);
                    }),
                  );
                },
              ),
            TextButton.icon(
              onPressed: _openFoodPicker,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.nutritionAddIngredient),
            ),
            const SizedBox(height: 24),

            // ── Steps ────────────────────────────────────────────────────────
            _SectionHeader(l10n.nutritionSteps),
            const SizedBox(height: 10),
            if (_steps.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.nutritionNoStepsYet,
                  style: TextStyle(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _steps.removeAt(oldIndex);
                    _steps.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, i) {
                  final step = _steps[i];
                  return _StepTile(
                    key: ValueKey('step_$i'),
                    draft: step,
                    stepNumber: i + 1,
                    onRemove: () => setState(() {
                      _steps[i].dispose();
                      _steps.removeAt(i);
                    }),
                  );
                },
              ),
            TextButton.icon(
              onPressed: () => setState(() => _steps.add(_StepDraft(
                    instructionController: TextEditingController(),
                    imageUrlController: TextEditingController(),
                  ))),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.nutritionAddStep),
            ),
            const SizedBox(height: 24),

            // ── Videos ───────────────────────────────────────────────────────
            _SectionHeader(l10n.nutritionVideos),
            const SizedBox(height: 10),
            ..._videos.asMap().entries.map((e) {
              final i = e.key;
              final v = e.value;
              return Card(
                key: ValueKey('vid_$i'),
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: v.urlController,
                              decoration: InputDecoration(labelText: l10n.nutritionVideoUrl, border: InputBorder.none),
                              keyboardType: TextInputType.url,
                            ),
                            TextFormField(
                              controller: v.titleController,
                              decoration: InputDecoration(labelText: l10n.nutritionTitleOptional, border: InputBorder.none),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.nutritionRemoveVideo,
                        icon: Icon(Icons.close, color: cs.error),
                        onPressed: () => setState(() {
                          _videos[i].dispose();
                          _videos.removeAt(i);
                        }),
                      ),
                    ],
                  ),
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => _videos.add(_VideoDraft(
                    urlController: TextEditingController(),
                    titleController: TextEditingController(),
                  ))),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.nutritionAddVideo),
            ),
            const SizedBox(height: 24),

            // ── Macro summary ────────────────────────────────────────────────
            _SectionHeader(l10n.nutritionComputedPerServing),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _MacroReadout(label: l10n.nutritionKcal, value: macros.kcal, color: macroColors.kcal)),
                const SizedBox(width: 6),
                Expanded(child: _MacroReadout(label: l10n.nutritionProtein, value: macros.protein, color: macroColors.protein, unit: 'g')),
                const SizedBox(width: 6),
                Expanded(child: _MacroReadout(label: l10n.nutritionCarbsShort, value: macros.carb, color: macroColors.carb, unit: 'g')),
                const SizedBox(width: 6),
                Expanded(child: _MacroReadout(label: l10n.nutritionFat, value: macros.fat, color: macroColors.fat, unit: 'g')),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Draft data classes ─────────────────────────────────────────────────────────

class _ImageDraft {
  final TextEditingController urlController;
  bool isThumbnail;

  _ImageDraft({required this.urlController, required this.isThumbnail});

  void dispose() => urlController.dispose();
}

class _IngredientDraft {
  final String foodItemId;
  final String foodItemName;
  final ServingUnit servingUnit;
  final FoodItem? foodItem;
  final TextEditingController quantityController;
  final TextEditingController noteController;

  _IngredientDraft({
    required this.foodItemId,
    required this.foodItemName,
    required this.servingUnit,
    this.foodItem,
    required this.quantityController,
    required this.noteController,
  });

  void dispose() {
    quantityController.dispose();
    noteController.dispose();
  }
}

class _StepDraft {
  final TextEditingController instructionController;
  final TextEditingController imageUrlController;

  _StepDraft({required this.instructionController, required this.imageUrlController});

  void dispose() {
    instructionController.dispose();
    imageUrlController.dispose();
  }
}

class _VideoDraft {
  final TextEditingController urlController;
  final TextEditingController titleController;

  _VideoDraft({required this.urlController, required this.titleController});

  void dispose() {
    urlController.dispose();
    titleController.dispose();
  }
}

// ── Tile widgets ──────────────────────────────────────────────────────────────

class _IngredientTile extends StatelessWidget {
  final _IngredientDraft draft;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _IngredientTile({
    super.key,
    required this.draft,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(top: 14, left: 4, right: 4),
                child: Icon(Icons.drag_handle, color: cs.onSurfaceVariant, semanticLabel: l10n.nutritionDragToReorder),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(draft.foodItemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: draft.quantityController,
                          decoration: InputDecoration(
                            labelText: l10n.nutritionLabelWithUnit(l10n.nutritionQtyShort, draft.servingUnit.displayName),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: draft.noteController,
                          decoration: InputDecoration(
                            labelText: l10n.nutritionNoteOptional,
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.nutritionRemoveIngredient,
              icon: Icon(Icons.close, color: cs.error, size: 20),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final _StepDraft draft;
  final int stepNumber;
  final VoidCallback onRemove;

  const _StepTile({
    super.key,
    required this.draft,
    required this.stepNumber,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReorderableDragStartListener(
              index: stepNumber - 1,
              child: Padding(
                padding: const EdgeInsets.only(top: 14, left: 4, right: 4),
                child: Icon(Icons.drag_handle, color: cs.onSurfaceVariant, semanticLabel: l10n.nutritionDragToReorder),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.nutritionStepNumber(stepNumber), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: cs.onSurfaceVariant)),
                  TextField(
                    controller: draft.instructionController,
                    decoration: InputDecoration(
                      hintText: l10n.nutritionInstructionHint,
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    maxLines: null,
                    minLines: 2,
                  ),
                  TextField(
                    controller: draft.imageUrlController,
                    decoration: InputDecoration(
                      labelText: l10n.nutritionStepImageUrlOptional,
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.nutritionRemoveStep,
              icon: Icon(Icons.close, color: cs.error, size: 20),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Food picker bottom sheet ───────────────────────────────────────────────────

class _FoodPickerSheet extends StatefulWidget {
  const _FoodPickerSheet();

  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {
  final _api = ApiService();
  final _search = TextEditingController();
  List<FoodItem> _items = [];
  bool _loading = false;

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
      final results = await _api.getFoodItems(
        token,
        name: _search.text.trim().isEmpty ? null : _search.text.trim(),
        pageSize: 50,
      );
      setState(() {
        _items = results;
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
      initialChildSize: 0.65,
      maxChildSize: 0.95,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: false,
              decoration: InputDecoration(
                hintText: l10n.nutritionSearchFoodItemsHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_items.isEmpty)
            Expanded(
              child: Center(
                child: Text(l10n.nutritionNoResults, style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final item = _items[i];
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      [if (item.brand != null) item.brand!, item.subtypeLabel(l10n)].join(' · '),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      item.servingUnitLabel(l10n),
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }
}

class _MacroReadout extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String unit;

  const _MacroReadout({
    required this.label,
    required this.value,
    required this.color,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    final display = value < 0.1 ? '0' : NumberFormat('0.0', Localizations.localeOf(context).toString()).format(value);
    return MergeSemantics(
      child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$display$unit',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
        ],
      ),
      ),
    );
  }
}
