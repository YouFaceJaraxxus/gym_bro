import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

class DailyMealPlanFormPage extends StatefulWidget {
  final DailyMealPlan? plan;

  const DailyMealPlanFormPage({super.key, this.plan});

  @override
  State<DailyMealPlanFormPage> createState() => _DailyMealPlanFormPageState();
}

class _DailyMealPlanFormPageState extends State<DailyMealPlanFormPage> {
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

  @override
  void initState() {
    super.initState();
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
                recipeName: e.recipe?.name ?? 'Recipe',
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
      }
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
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
        const SnackBar(content: Text('All meal slots have been added')),
      );
      return;
    }
    final picked = await showModalBottomSheet<MealSlotType>(
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
    final item = await showModalBottomSheet<FoodItem>(
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
    final recipe = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RecipePickerSheet(),
    );
    if (recipe == null || !mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _QuantityDialog(
        title: recipe.name,
        unitLabel: 'servings',
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Meal Plan' : 'New Meal Plan'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Basic fields ────────────────────────────────────────────────
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Plan name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Public'),
              subtitle: const Text('Visible to all users'),
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),

            // ── Slots ───────────────────────────────────────────────────────
            const Text('Meal Slots', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              label: const Text('Add Slot'),
            ),
            const SizedBox(height: 28),

            // ── Macro totals ────────────────────────────────────────────────
            const Text('Totals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    required String recipeName,
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

  bool get isFoodItem => foodItemId != null;

  String get displayName => foodItemName ?? recipeName ?? 'Item';

  String get amountLabel {
    if (isFoodItem && quantity != null) {
      final unit = foodItemUnit?.displayName ?? 'g';
      final q = quantity! == quantity!.truncateToDouble()
          ? quantity!.toInt().toString()
          : quantity!.toStringAsFixed(1);
      return '$q$unit';
    }
    return servings == 1.0 ? '1 serving' : '${servings.toStringAsFixed(1)} servings';
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
                Text(slot.slotType.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    '${slot.kcalTotal.round()} kcal',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: onRemove,
                  tooltip: 'Remove slot',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Entries
            if (slot.entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('No entries yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
              )
            else
              ...slot.entries.asMap().entries.map((e) {
                final ei = e.key;
                final entry = e.value;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  title: Text(entry.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  subtitle: entry.note != null && entry.note!.isNotEmpty
                      ? Text(entry.note!, style: const TextStyle(fontSize: 11, color: Colors.grey))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entry.amountLabel,
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.red),
                        onPressed: () => onRemoveEntry(ei),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
                  label: const Text('Add food item', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onAddRecipe,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add recipe', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            _TotalCell(label: 'kcal', value: kcal.round().toString(), color: Colors.orange.shade700),
            _TotalDivider(),
            _TotalCell(label: 'protein', value: '${protein.round()}g', color: Colors.red.shade400),
            _TotalDivider(),
            _TotalCell(label: 'carbs', value: '${carb.round()}g', color: Colors.amber.shade700),
            _TotalDivider(),
            _TotalCell(label: 'fat', value: '${fat.round()}g', color: Colors.blue.shade400),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _TotalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 32, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 4));
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
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Select Meal Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  title: Text(type.displayName),
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
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search food items…',
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
                      '${item.subtypeLabel} · ${item.kcalPer100.round()} kcal/100${item.servingUnit.displayName}',
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
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search recipes…',
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
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, _) => const Icon(Icons.restaurant),
                            ),
                          )
                        : const Icon(Icons.restaurant),
                    title: Text(recipe.name),
                    subtitle: Text(
                      '${recipe.kcalPerServing.round()} kcal/serving',
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
    final raw = double.tryParse(_quantity.text.trim());
    final noteText = _note.text.trim().isEmpty ? null : _note.text.trim();
    if (widget.isServings) {
      Navigator.pop(context, {'servings': raw ?? 1.0, 'note': noteText});
    } else {
      Navigator.pop(context, {'quantity': raw, 'note': noteText});
    }
  }

  @override
  Widget build(BuildContext context) {
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
              labelText: widget.isServings ? 'Servings' : 'Quantity (${widget.unitLabel})',
              hintText: widget.isServings ? '1.0' : '100',
            ),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _confirm, child: const Text('Add')),
      ],
    );
  }
}
