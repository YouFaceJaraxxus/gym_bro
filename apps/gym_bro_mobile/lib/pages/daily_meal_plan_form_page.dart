import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/draft.dart';
import '../models/food_log.dart' show fmtAmount;
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/drafts.dart';
import 'nutrition/nutrition_widgets.dart';
import '../widgets/app_bottom_sheet.dart';

class DailyMealPlanFormPage extends StatefulWidget {
  final DailyMealPlan? plan;

  /// A saved draft to continue (new plans only).
  final Draft? draft;

  const DailyMealPlanFormPage({super.key, this.plan, this.draft});

  @override
  State<DailyMealPlanFormPage> createState() => _DailyMealPlanFormPageState();
}

class _DailyMealPlanFormPageState extends State<DailyMealPlanFormPage> with DraftableForm {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late final TextEditingController _name;
  late final TextEditingController _description;

  bool _isPublic = false;
  bool _saving = false;

  final List<_SlotDraft> _slots = [];

  bool get _isEditing => widget.plan != null;

  // ── computed totals ──────────────────────────────────────────────────────────

  double get _totalKcal => _slots.fold(0, (s, slot) => s + slot.kcalTotal);
  double get _totalProtein => _slots.fold(0, (s, slot) => s + slot.proteinTotal);
  double get _totalCarb => _slots.fold(0, (s, slot) => s + slot.carbTotal);
  double get _totalFat => _slots.fold(0, (s, slot) => s + slot.fatTotal);

  // ── drafts ───────────────────────────────────────────────────────────────────

  @override
  DraftKind get draftKind => DraftKind.dailyMealPlan;
  @override
  Draft? get initialDraft => widget.draft;
  @override
  bool get draftsEnabled => !_isEditing;
  @override
  bool get hasDraftContent =>
      _name.text.trim().isNotEmpty || _description.text.trim().isNotEmpty || _slots.isNotEmpty;
  @override
  String? draftTitle() => _name.text;
  @override
  Map<String, dynamic> draftData() => {
        'name': _name.text,
        'description': _description.text,
        'is_public': _isPublic,
        'slots': [for (final slot in _slots) slot.toDraftJson()],
      };

  void _restoreDraft(Map<String, dynamic> d) {
    _name = TextEditingController(text: _draftText(d['name']));
    _description = TextEditingController(text: _draftText(d['description']));
    _isPublic = d['is_public'] is bool ? d['is_public'] as bool : false;
    for (final raw in _draftMaps(d['slots'])) {
      final slot = _SlotDraft.fromDraftJson(raw, position: _slots.length);
      // One slot per meal type, as the slot picker enforces.
      if (slot != null && !_slots.any((s) => s.slotType == slot.slotType)) _slots.add(slot);
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
    if (p != null) {
      final sorted = [...p.slots]..sort((a, b) => a.position.compareTo(b.position));
      for (final slot in sorted) {
        final sortedEntries = [...slot.entries]..sort((a, b) => a.position.compareTo(b.position));
        _slots.add(_SlotDraft(
          slotType: slot.slotType,
          position: slot.position,
          note: slot.note,
          entries: sortedEntries.map((e) {
            if (e.foodItem != null) {
              return _EntryDraft.fromFoodItem(
                foodItemId: e.foodItemId!,
                foodItemName: e.foodItem!.name,
                foodItemUnit: e.foodItem!.servingUnit,
                foodItemKcalPer100: e.foodItem!.kcalPer100,
                foodItemProteinPer100: e.foodItem!.proteinPer100,
                foodItemCarbPer100: e.foodItem!.carbPer100,
                foodItemFatPer100: e.foodItem!.fatPer100,
                quantity: e.quantity,
                note: e.note,
                position: e.position,
              );
            } else {
              return _EntryDraft.fromRecipe(
                recipeId: e.recipeId!,
                recipeName: e.recipe?.name,
                recipeKcalPerServing: e.recipe?.kcalPerServing ?? 0,
                recipeProteinPerServing: e.recipe?.proteinPerServing ?? 0,
                recipeCarbPerServing: e.recipe?.carbPerServing ?? 0,
                recipeFatPerServing: e.recipe?.fatPerServing ?? 0,
                servings: e.servings,
                note: e.note,
                position: e.position,
              );
            }
          }).toList(),
        ));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  // ── save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final token = await AuthManager.instance.getValidToken();

      final slots = _slots.asMap().entries.map((slotEntry) {
        final si = slotEntry.key;
        final slot = slotEntry.value;
        return {
          'slot_type': slot.slotType.apiValue,
          'position': si,
          'note': slot.note,
          'entries': slot.entries.asMap().entries.map((entryEntry) {
            final ei = entryEntry.key;
            final entry = entryEntry.value;
            return {
              'food_item_id': entry.foodItemId,
              'recipe_id': entry.recipeId,
              'quantity': entry.quantity,
              'servings': entry.servings,
              'position': ei,
              'note': entry.note,
            };
          }).toList(),
        };
      }).toList();

      final data = {
        'name': _name.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'is_public': _isPublic,
        'kcal_total': _totalKcal,
        'protein_total': _totalProtein,
        'carb_total': _totalCarb,
        'fat_total': _totalFat,
        'fiber_total': 0.0,
        'slots': slots,
      };

      final DailyMealPlan result;
      if (_isEditing) {
        result = await _api.updateDailyMealPlan(token, widget.plan!.id, data);
      } else {
        result = await _api.createDailyMealPlan(token, data);
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

  // ── add slot ─────────────────────────────────────────────────────────────────

  Future<void> _addSlot() async {
    final usedTypes = _slots.map((s) => s.slotType).toSet();
    final available = MealSlotType.values.where((t) => !usedTypes.contains(t)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.nutritionAllSlotsAdded)),
      );
      return;
    }
    final picked = await showAppBottomSheet<MealSlotType>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SlotTypePicker(available: available),
    );
    if (picked != null && mounted) {
      setState(() => _slots.add(_SlotDraft(
            slotType: picked,
            position: _slots.length,
          )));
    }
  }

  // ── add food item to slot ────────────────────────────────────────────────────

  Future<void> _addFoodItem(int slotIndex) async {
    final item = await showAppBottomSheet<FoodItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FoodItemPickerSheet(),
    );
    if (item == null || !mounted) return;

    // Ask for quantity + note
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _QuantityDialog(
        title: item.name,
        unitLabel: item.servingUnit.displayName,
        isServings: false,
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _slots[slotIndex].entries.add(_EntryDraft.fromFoodItem(
        foodItemId: item.id,
        foodItemName: item.name,
        foodItemUnit: item.servingUnit,
        foodItemKcalPer100: item.kcalPer100,
        foodItemProteinPer100: item.proteinPer100,
        foodItemCarbPer100: item.carbPer100,
        foodItemFatPer100: item.fatPer100,
        quantity: result['quantity'] as double?,
        note: result['note'] as String?,
        position: _slots[slotIndex].entries.length,
      ));
    });
  }

  // ── add recipe to slot ───────────────────────────────────────────────────────

  Future<void> _addRecipe(int slotIndex) async {
    final recipe = await showAppBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RecipePickerSheet(),
    );
    if (recipe == null || !mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _QuantityDialog(
        title: recipe.name,
        unitLabel: context.l10n.nutritionUnitServings,
        isServings: true,
        defaultValue: 1.0,
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _slots[slotIndex].entries.add(_EntryDraft.fromRecipe(
        recipeId: recipe.id,
        recipeName: recipe.name,
        recipeKcalPerServing: recipe.kcalPerServing,
        recipeProteinPerServing: recipe.proteinPerServing,
        recipeCarbPerServing: recipe.carbPerServing,
        recipeFatPerServing: recipe.fatPerServing,
        servings: result['servings'] as double? ?? 1.0,
        note: result['note'] as String?,
        position: _slots[slotIndex].entries.length,
      ));
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final banner = draftBanner(context);
    return draftPopScope(
      busy: _saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? l10n.nutritionEditDailyPlanTitle : l10n.nutritionNewDailyPlanTitle),
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
              // ── Basic fields ────────────────────────────────────────────────
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: l10n.nutritionPlanNameRequiredLabel),
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                decoration: InputDecoration(labelText: l10n.nutritionDescription),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(l10n.nutritionPublic),
                subtitle: Text(l10n.nutritionVisibleToAllUsers),
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),

              // ── Slots ───────────────────────────────────────────────────────
              Text(l10n.nutritionMealSlots, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              ..._slots.asMap().entries.map((entry) {
                final si = entry.key;
                final slot = entry.value;
                return _SlotCard(
                  key: ValueKey('slot_$si'),
                  slot: slot,
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() => _slots.removeAt(si)),
                  onAddFoodItem: () => _addFoodItem(si),
                  onAddRecipe: () => _addRecipe(si),
                  onRemoveEntry: (ei) => setState(() => slot.entries.removeAt(ei)),
                );
              }),

              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addSlot,
                icon: const Icon(Icons.add),
                label: Text(l10n.nutritionAddSlot),
              ),
              const SizedBox(height: 28),

              // ── Macro totals ────────────────────────────────────────────────
              Text(l10n.nutritionTotals, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _TotalsCard(
                kcal: _totalKcal,
                protein: _totalProtein,
                carb: _totalCarb,
                fat: _totalFat,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Draft models ──────────────────────────────────────────────────────────────

class _SlotDraft {
  MealSlotType slotType;
  int position;
  String? note;
  List<_EntryDraft> entries;

  _SlotDraft({
    required this.slotType,
    required this.position,
    this.note,
    List<_EntryDraft>? entries,
  }) : entries = entries ?? [];

  Map<String, dynamic> toDraftJson() => {
        'slot_type': slotType.apiValue,
        'note': note,
        'entries': [for (final e in entries) e.toDraftJson()],
      };

  /// Null when the slot type is unknown (e.g. removed in a newer version).
  static _SlotDraft? fromDraftJson(Map<String, dynamic> json, {required int position}) {
    final type = json['slot_type'] is String ? MealSlotType.fromApiValue(json['slot_type'] as String) : null;
    if (type == null) return null;
    final entries = <_EntryDraft>[];
    for (final raw in _draftMaps(json['entries'])) {
      final entry = _EntryDraft.fromDraftJson(raw, position: entries.length);
      if (entry != null) entries.add(entry);
    }
    return _SlotDraft(
      slotType: type,
      position: position,
      note: json['note'] is String ? json['note'] as String : null,
      entries: entries,
    );
  }

  double get kcalTotal => entries.fold(0, (s, e) => s + e.kcal);
  double get proteinTotal => entries.fold(0, (s, e) => s + e.protein);
  double get carbTotal => entries.fold(0, (s, e) => s + e.carb);
  double get fatTotal => entries.fold(0, (s, e) => s + e.fat);
}

class _EntryDraft {
  String? foodItemId;
  String? foodItemName;
  ServingUnit? foodItemUnit;
  double? foodItemKcalPer100;
  double? foodItemProteinPer100;
  double? foodItemCarbPer100;
  double? foodItemFatPer100;
  String? recipeId;
  String? recipeName;
  double? recipeKcalPerServing;
  double? recipeProteinPerServing;
  double? recipeCarbPerServing;
  double? recipeFatPerServing;
  double? quantity; // for food items
  double servings; // for recipes
  String? note;
  int position;

  _EntryDraft({
    this.foodItemId,
    this.foodItemName,
    this.foodItemUnit,
    this.foodItemKcalPer100,
    this.foodItemProteinPer100,
    this.foodItemCarbPer100,
    this.foodItemFatPer100,
    this.recipeId,
    this.recipeName,
    this.recipeKcalPerServing,
    this.recipeProteinPerServing,
    this.recipeCarbPerServing,
    this.recipeFatPerServing,
    this.quantity,
    this.servings = 1.0,
    this.note,
    required this.position,
  });

  factory _EntryDraft.fromFoodItem({
    required String foodItemId,
    required String foodItemName,
    required ServingUnit foodItemUnit,
    required double foodItemKcalPer100,
    required double foodItemProteinPer100,
    required double foodItemCarbPer100,
    required double foodItemFatPer100,
    double? quantity,
    String? note,
    required int position,
  }) =>
      _EntryDraft(
        foodItemId: foodItemId,
        foodItemName: foodItemName,
        foodItemUnit: foodItemUnit,
        foodItemKcalPer100: foodItemKcalPer100,
        foodItemProteinPer100: foodItemProteinPer100,
        foodItemCarbPer100: foodItemCarbPer100,
        foodItemFatPer100: foodItemFatPer100,
        quantity: quantity,
        note: note,
        position: position,
      );

  factory _EntryDraft.fromRecipe({
    required String recipeId,
    required String? recipeName,
    required double recipeKcalPerServing,
    required double recipeProteinPerServing,
    required double recipeCarbPerServing,
    required double recipeFatPerServing,
    double servings = 1.0,
    String? note,
    required int position,
  }) =>
      _EntryDraft(
        recipeId: recipeId,
        recipeName: recipeName,
        recipeKcalPerServing: recipeKcalPerServing,
        recipeProteinPerServing: recipeProteinPerServing,
        recipeCarbPerServing: recipeCarbPerServing,
        recipeFatPerServing: recipeFatPerServing,
        servings: servings,
        note: note,
        position: position,
      );

  Map<String, dynamic> toDraftJson() => {
        'food_item_id': foodItemId,
        'food_item_name': foodItemName,
        'food_item_unit': foodItemUnit?.apiValue,
        'food_item_kcal_per_100': foodItemKcalPer100,
        'food_item_protein_per_100': foodItemProteinPer100,
        'food_item_carb_per_100': foodItemCarbPer100,
        'food_item_fat_per_100': foodItemFatPer100,
        'recipe_id': recipeId,
        'recipe_name': recipeName,
        'recipe_kcal_per_serving': recipeKcalPerServing,
        'recipe_protein_per_serving': recipeProteinPerServing,
        'recipe_carb_per_serving': recipeCarbPerServing,
        'recipe_fat_per_serving': recipeFatPerServing,
        'quantity': quantity,
        'servings': servings,
        'note': note,
      };

  /// Null when the entry references neither a food item nor a recipe.
  static _EntryDraft? fromDraftJson(Map<String, dynamic> json, {required int position}) {
    String? str(String key) => json[key] is String && (json[key] as String).isNotEmpty ? json[key] as String : null;
    double? dbl(String key) => json[key] == null ? null : double.tryParse(json[key].toString());
    final foodItemId = str('food_item_id');
    final recipeId = str('recipe_id');
    if (foodItemId != null) {
      return _EntryDraft(
        foodItemId: foodItemId,
        foodItemName: str('food_item_name'),
        foodItemUnit: str('food_item_unit') == null ? null : ServingUnit.fromApiValue(str('food_item_unit')!),
        foodItemKcalPer100: dbl('food_item_kcal_per_100'),
        foodItemProteinPer100: dbl('food_item_protein_per_100'),
        foodItemCarbPer100: dbl('food_item_carb_per_100'),
        foodItemFatPer100: dbl('food_item_fat_per_100'),
        quantity: dbl('quantity'),
        note: str('note'),
        position: position,
      );
    }
    if (recipeId != null) {
      return _EntryDraft(
        recipeId: recipeId,
        recipeName: str('recipe_name'),
        recipeKcalPerServing: dbl('recipe_kcal_per_serving'),
        recipeProteinPerServing: dbl('recipe_protein_per_serving'),
        recipeCarbPerServing: dbl('recipe_carb_per_serving'),
        recipeFatPerServing: dbl('recipe_fat_per_serving'),
        servings: dbl('servings') ?? 1.0,
        note: str('note'),
        position: position,
      );
    }
    return null;
  }

  bool get isFoodItem => foodItemId != null;

  String displayName(AppLocalizations l10n) =>
      foodItemName ?? recipeName ?? (isFoodItem ? l10n.nutritionItemFallback : l10n.nutritionRecipeFallback);

  String amountLabel(AppLocalizations l10n) {
    if (isFoodItem && quantity != null) {
      final unit = foodItemUnit?.displayName ?? 'g';
      return '${fmtAmount(double.parse(quantity!.toStringAsFixed(1)), l10n.localeName)}$unit';
    }
    return l10n.nutritionServingsAmount(servings, fmtAmount(double.parse(servings.toStringAsFixed(1)), l10n.localeName));
  }

  double get kcal {
    if (isFoodItem && quantity != null && foodItemKcalPer100 != null) {
      return foodItemKcalPer100! * quantity! / 100;
    }
    if (!isFoodItem && recipeKcalPerServing != null) {
      return recipeKcalPerServing! * servings;
    }
    return 0;
  }

  double get protein {
    if (isFoodItem && quantity != null && foodItemProteinPer100 != null) {
      return foodItemProteinPer100! * quantity! / 100;
    }
    if (!isFoodItem && recipeProteinPerServing != null) {
      return recipeProteinPerServing! * servings;
    }
    return 0;
  }

  double get carb {
    if (isFoodItem && quantity != null && foodItemCarbPer100 != null) {
      return foodItemCarbPer100! * quantity! / 100;
    }
    if (!isFoodItem && recipeCarbPerServing != null) {
      return recipeCarbPerServing! * servings;
    }
    return 0;
  }

  double get fat {
    if (isFoodItem && quantity != null && foodItemFatPer100 != null) {
      return foodItemFatPer100! * quantity! / 100;
    }
    if (!isFoodItem && recipeFatPerServing != null) {
      return recipeFatPerServing! * servings;
    }
    return 0;
  }
}

// ── Saved-draft (server) helpers ──────────────────────────────────────────────
// Drafts may come from an older app version: every key is optional.

String _draftText(Object? v, [String fallback = '']) => v is String ? v : (v is num ? '$v' : fallback);

Iterable<Map<String, dynamic>> _draftMaps(Object? raw) =>
    raw is List ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)) : const [];

// ── Slot card widget ──────────────────────────────────────────────────────────

class _SlotCard extends StatelessWidget {
  final _SlotDraft slot;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onAddFoodItem;
  final VoidCallback onAddRecipe;
  final ValueChanged<int> onRemoveEntry;

  const _SlotCard({
    super.key,
    required this.slot,
    required this.onChanged,
    required this.onRemove,
    required this.onAddFoodItem,
    required this.onAddRecipe,
    required this.onRemoveEntry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(slot.slotType.label(l10n),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    l10n.nutritionKcalValue(slot.kcalTotal.round()),
                    style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                  onPressed: onRemove,
                  tooltip: l10n.nutritionRemoveSlot,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Entries
            if (slot.entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(l10n.nutritionNoEntriesYet, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              )
            else
              ...slot.entries.asMap().entries.map((e) {
                final ei = e.key;
                final entry = e.value;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  title: Text(entry.displayName(l10n),
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  subtitle: entry.note != null && entry.note!.isNotEmpty
                      ? Text(entry.note!, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entry.amountLabel(l10n),
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      IconButton(
                        tooltip: l10n.nutritionRemoveNamed(entry.displayName(l10n)),
                        icon: Icon(Icons.close, size: 16, color: cs.error),
                        onPressed: () => onRemoveEntry(ei),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 4),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onAddFoodItem,
                  icon: const Icon(Icons.add, size: 14),
                  label: Text(l10n.nutritionAddFoodItem, style: const TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onAddRecipe,
                  icon: const Icon(Icons.add, size: 14),
                  label: Text(l10n.nutritionAddRecipe, style: const TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Totals card ───────────────────────────────────────────────────────────────

class _TotalsCard extends StatelessWidget {
  final double kcal;
  final double protein;
  final double carb;
  final double fat;

  const _TotalsCard({
    required this.kcal,
    required this.protein,
    required this.carb,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = MacroColors.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            _TotalCell(label: l10n.nutritionKcal, value: kcal.round().toString(), color: colors.kcal),
            _TotalDivider(),
            _TotalCell(label: l10n.nutritionProtein, value: '${protein.round()}g', color: colors.protein),
            _TotalDivider(),
            _TotalCell(label: l10n.nutritionCarbsShort, value: '${carb.round()}g', color: colors.carb),
            _TotalDivider(),
            _TotalCell(label: l10n.nutritionFat, value: '${fat.round()}g', color: colors.fat),
          ],
        ),
      ),
    );
  }
}

class _TotalCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TotalCell({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MergeSemantics(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
        ),
      ),
    );
  }
}

class _TotalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 32, color: Theme.of(context).colorScheme.outlineVariant, margin: const EdgeInsets.symmetric(horizontal: 4));
  }
}

// ── Slot type picker sheet ────────────────────────────────────────────────────

class _SlotTypePicker extends StatelessWidget {
  final List<MealSlotType> available;

  const _SlotTypePicker({required this.available});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(context.l10n.nutritionSelectMealSlot, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: available.length,
              itemBuilder: (context, i) {
                final type = available[i];
                return ListTile(
                  title: Text(type.label(context.l10n)),
                  onTap: () => Navigator.pop(context, type),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Food item picker sheet ────────────────────────────────────────────────────

class _FoodItemPickerSheet extends StatefulWidget {
  const _FoodItemPickerSheet();

  @override
  State<_FoodItemPickerSheet> createState() => _FoodItemPickerSheetState();
}

class _FoodItemPickerSheetState extends State<_FoodItemPickerSheet> {
  final _api = ApiService();
  final _search = TextEditingController();
  List<FoodItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.l10n.nutritionSearchFoodItemsHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
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
                      '${item.subtypeLabel(context.l10n)} · ${item.kcalPer100.round()} kcal/100${item.servingUnit.displayName}',
                      style: const TextStyle(fontSize: 12),
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

// ── Recipe picker sheet ───────────────────────────────────────────────────────

class _RecipePickerSheet extends StatefulWidget {
  const _RecipePickerSheet();

  @override
  State<_RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<_RecipePickerSheet> {
  final _api = ApiService();
  final _search = TextEditingController();
  List<Recipe> _recipes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await _api.getRecipes(
        token,
        name: _search.text.trim().isEmpty ? null : _search.text.trim(),
        pageSize: 50,
      );
      setState(() {
        _recipes = results;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.l10n.nutritionSearchRecipesHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: _recipes.length,
                itemBuilder: (context, i) {
                  final recipe = _recipes[i];
                  return ListTile(
                    leading: recipe.thumbnailUrlOrNull != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              recipe.thumbnailUrlOrNull!,
                              excludeFromSemantics: true,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.restaurant),
                            ),
                          )
                        : const Icon(Icons.restaurant),
                    title: Text(recipe.name),
                    subtitle: Text(
                      context.l10n.nutritionKcalPerServing(recipe.kcalPerServing.round()),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => Navigator.pop(context, recipe),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Quantity / servings dialog ────────────────────────────────────────────────

class _QuantityDialog extends StatefulWidget {
  final String title;
  final String unitLabel;
  final bool isServings;
  final double? defaultValue;

  const _QuantityDialog({
    required this.title,
    required this.unitLabel,
    required this.isServings,
    this.defaultValue,
  });

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController _quantity;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(
      text: widget.defaultValue != null ? widget.defaultValue.toString() : '',
    );
    _note = TextEditingController();
  }

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  void _confirm() {
    final raw = double.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    final noteText = _note.text.trim().isEmpty ? null : _note.text.trim();
    if (widget.isServings) {
      Navigator.pop(context, {'servings': raw ?? 1.0, 'note': noteText});
    } else {
      Navigator.pop(context, {'quantity': raw, 'note': noteText});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.isServings
                  ? l10n.nutritionServings
                  : l10n.nutritionLabelWithUnit(l10n.nutritionQuantity, widget.unitLabel),
              hintText: widget.isServings ? '1.0' : '100',
            ),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: l10n.nutritionNoteOptional),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        TextButton(onPressed: _confirm, child: Text(l10n.nutritionAdd)),
      ],
    );
  }
}
