import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/food_log.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

class FoodItemFormPage extends StatefulWidget {
  final FoodItem? foodItem;

  /// Prefills the barcode field (e.g. after an unknown barcode scan).
  final String? initialBarcode;

  const FoodItemFormPage({super.key, this.foodItem, this.initialBarcode});

  @override
  State<FoodItemFormPage> createState() => _FoodItemFormPageState();
}

class _FoodItemFormPageState extends State<FoodItemFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _barcode;
  late final TextEditingController _kcal;
  late final TextEditingController _protein;
  late final TextEditingController _carb;
  late final TextEditingController _fat;
  late final TextEditingController _fiber;

  late FoodItemType _type;
  FoodSubtype? _foodSubtype;
  DrinkSubtype? _drinkSubtype;
  SpiceSubtype? _spiceSubtype;
  late ServingUnit _servingUnit;
  late bool _isPublic;

  bool _saving = false;

  // Micronutrients (per 100 g/ml), edited locally and sent with the item.
  late List<FoodItemVitamin> _vitamins;
  late List<FoodItemMineral> _minerals;
  NutrientReference? _nutrients;
  bool _nutrientsLoading = false;
  String? _nutrientsError;

  bool get _isEditing => widget.foodItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.foodItem;
    _name = TextEditingController(text: item?.name ?? '');
    _brand = TextEditingController(text: item?.brand ?? '');
    _barcode = TextEditingController(text: item?.barcode ?? widget.initialBarcode ?? '');
    _kcal = TextEditingController(text: item != null ? _fmt(item.kcalPer100) : '0');
    _protein = TextEditingController(text: item != null ? _fmt(item.proteinPer100) : '0');
    _carb = TextEditingController(text: item != null ? _fmt(item.carbPer100) : '0');
    _fat = TextEditingController(text: item != null ? _fmt(item.fatPer100) : '0');
    _fiber = TextEditingController(text: item != null ? _fmt(item.fiberPer100) : '0');
    _type = item?.type ?? FoodItemType.food;
    _foodSubtype = item?.foodSubtype;
    _drinkSubtype = item?.drinkSubtype;
    _spiceSubtype = item?.spiceSubtype;
    _servingUnit = item?.servingUnit ?? ServingUnit.g;
    _isPublic = item?.isPublic ?? true;
    _vitamins = [...?item?.vitamins];
    _minerals = [...?item?.minerals];
    _loadNutrients();
  }

  Future<void> _loadNutrients() async {
    setState(() {
      _nutrientsLoading = true;
      _nutrientsError = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final ref = await _api.getNutrients(token);
      if (mounted) setState(() => _nutrients = ref);
    } catch (e) {
      if (mounted) setState(() => _nutrientsError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _nutrientsLoading = false);
    }
  }

  Future<void> _addMicronutrient({required bool vitamin}) async {
    final ref = _nutrients;
    if (ref == null) return;
    final options = vitamin
        ? ref.vitamins
            .where((v) => !_vitamins.any((x) => x.vitaminId == v.id))
            .map((v) => _NutrientOption(v.id, v.name, v.symbol, v.defaultUnit))
            .toList()
        : ref.minerals
            .where((m) => !_minerals.any((x) => x.mineralId == m.id))
            .map((m) => _NutrientOption(m.id, m.name, m.symbol, m.defaultUnit))
            .toList();
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(vitamin ? context.l10n.nutritionAllVitaminsAdded : context.l10n.nutritionAllMineralsAdded),
      ));
      return;
    }
    final result = await showDialog<_NutrientInput>(
      context: context,
      builder: (_) => _NutrientDialog(
        title: vitamin ? context.l10n.nutritionAddVitamin : context.l10n.nutritionAddMineral,
        options: options,
        perLabel: context.l10n.nutritionPer100Unit(_servingUnit.displayName),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (vitamin) {
        _vitamins.add(FoodItemVitamin(
          vitaminId: result.option.id,
          vitamin: ref.vitamins.firstWhere((v) => v.id == result.option.id),
          amountPer100: result.amount,
          unit: result.unit == result.option.defaultUnit ? null : result.unit,
        ));
      } else {
        _minerals.add(FoodItemMineral(
          mineralId: result.option.id,
          mineral: ref.minerals.firstWhere((m) => m.id == result.option.id),
          amountPer100: result.amount,
          unit: result.unit == result.option.defaultUnit ? null : result.unit,
        ));
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _barcode.dispose();
    _kcal.dispose();
    _protein.dispose();
    _carb.dispose();
    _fat.dispose();
    _fiber.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  void _onTypeChanged(FoodItemType t) {
    setState(() {
      _type = t;
      _foodSubtype = null;
      _drinkSubtype = null;
      _spiceSubtype = null;
      _servingUnit = t == FoodItemType.drink ? ServingUnit.ml : ServingUnit.g;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'brand': _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        'barcode': _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        'type': _type.apiValue,
        'food_subtype': _foodSubtype?.apiValue,
        'drink_subtype': _drinkSubtype?.apiValue,
        'spice_subtype': _spiceSubtype?.apiValue,
        'serving_unit': _servingUnit.apiValue,
        'kcal_per_100': _parseNum(_kcal.text) ?? 0,
        'protein_per_100': _parseNum(_protein.text) ?? 0,
        'carb_per_100': _parseNum(_carb.text) ?? 0,
        'fat_per_100': _parseNum(_fat.text) ?? 0,
        'fiber_per_100': _parseNum(_fiber.text) ?? 0,
        'is_public': _isPublic,
        'vitamins': _vitamins.map((v) => v.toJson()).toList(),
        'minerals': _minerals.map((m) => m.toJson()).toList(),
      };
      final FoodItem result;
      if (_isEditing) {
        result = await _api.updateFoodItem(token, widget.foodItem!.id, data);
      } else {
        result = await _api.createFoodItem(token, data);
      }
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''), style: TextStyle(color: cs.onError)),
          backgroundColor: cs.error,
        ),
      );
    }
  }

  // ── Subtype dropdown helpers ──────────────────────────────────────────────

  Widget _buildSubtypeDropdown() {
    final l10n = context.l10n;
    switch (_type) {
      case FoodItemType.food:
        return DropdownButtonFormField<FoodSubtype>(
          key: const ValueKey('food_subtype'),
          initialValue: _foodSubtype,
          decoration: InputDecoration(labelText: l10n.nutritionSubtypeRequiredLabel),
          items: FoodSubtype.values
              .map((s) => DropdownMenuItem(value: s, child: Text(s.label(l10n))))
              .toList(),
          validator: (v) => v == null ? l10n.commonRequired : null,
          onChanged: (v) => setState(() => _foodSubtype = v),
        );
      case FoodItemType.drink:
        return DropdownButtonFormField<DrinkSubtype>(
          key: const ValueKey('drink_subtype'),
          initialValue: _drinkSubtype,
          decoration: InputDecoration(labelText: l10n.nutritionSubtypeRequiredLabel),
          items: DrinkSubtype.values
              .map((s) => DropdownMenuItem(value: s, child: Text(s.label(l10n))))
              .toList(),
          validator: (v) => v == null ? l10n.commonRequired : null,
          onChanged: (v) => setState(() => _drinkSubtype = v),
        );
      case FoodItemType.spice:
        return DropdownButtonFormField<SpiceSubtype>(
          key: const ValueKey('spice_subtype'),
          initialValue: _spiceSubtype,
          decoration: InputDecoration(labelText: l10n.nutritionSubtypeRequiredLabel),
          items: SpiceSubtype.values
              .map((s) => DropdownMenuItem(value: s, child: Text(s.label(l10n))))
              .toList(),
          validator: (v) => v == null ? l10n.commonRequired : null,
          onChanged: (v) => setState(() => _spiceSubtype = v),
        );
    }
  }

  Widget _buildMicronutrients(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final perLabel = l10n.nutritionPer100Unit(_servingUnit.displayName);

    Widget row(String name, String? symbol, double amount, String unit, VoidCallback onRemove) => ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(symbol != null && !name.contains('($symbol)') && !name.endsWith(symbol) ? '$name ($symbol)' : name),
          subtitle: Text('${fmtAmount(amount, l10n.localeName)} $unit $perLabel'),
          trailing: IconButton(
            tooltip: l10n.nutritionRemove,
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.nutritionMicronutrients, style: text.labelLarge),
        const SizedBox(height: 4),
        Text(
          l10n.nutritionMicronutrientsOptionalHint(perLabel),
          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        if (_vitamins.isEmpty && _minerals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.nutritionNoMicronutrientsAdded, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ),
        for (final v in _vitamins)
          row(v.vitamin?.name ?? l10n.nutritionVitamin, v.vitamin?.symbol, v.amountPer100, v.displayUnit,
              () => setState(() => _vitamins.remove(v))),
        for (final m in _minerals)
          row(m.mineral?.name ?? l10n.nutritionMineral, m.mineral?.symbol, m.amountPer100, m.displayUnit,
              () => setState(() => _minerals.remove(m))),
        const SizedBox(height: 8),
        if (_nutrientsLoading)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
        else if (_nutrientsError != null)
          Row(
            children: [
              Expanded(
                child: Text(l10n.nutritionNutrientListLoadFailed(_nutrientsError!),
                    style: text.bodySmall?.copyWith(color: cs.error)),
              ),
              TextButton(onPressed: _loadNutrients, child: Text(l10n.commonRetry)),
            ],
          )
        else
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _addMicronutrient(vitamin: true),
                icon: const Icon(Icons.add),
                label: Text(l10n.nutritionVitamin),
              ),
              OutlinedButton.icon(
                onPressed: () => _addMicronutrient(vitamin: false),
                icon: const Icon(Icons.add),
                label: Text(l10n.nutritionMineral),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.nutritionEditFoodItemTitle : l10n.nutritionNewFoodItemTitle),
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
            // ── Basic info ─────────────────────────────────────────────────
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.nutritionNameRequiredLabel),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _brand,
              decoration: InputDecoration(labelText: l10n.nutritionBrandOptional),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _barcode,
              decoration: InputDecoration(
                labelText: l10n.nutritionBarcodeOptional,
                hintText: 'EAN / UPC',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // ── Type ───────────────────────────────────────────────────────
            Text(l10n.nutritionType, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            SegmentedButton<FoodItemType>(
              segments: FoodItemType.values
                  .map((t) => ButtonSegment(value: t, label: Text(t.label(l10n))))
                  .toList(),
              selected: {_type},
              onSelectionChanged: (s) => _onTypeChanged(s.first),
            ),
            const SizedBox(height: 16),

            // ── Subtype ────────────────────────────────────────────────────
            _buildSubtypeDropdown(),
            const SizedBox(height: 16),

            // ── Serving unit ───────────────────────────────────────────────
            Text(l10n.nutritionServingUnit, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            SegmentedButton<ServingUnit>(
              segments: ServingUnit.values
                  .map((u) => ButtonSegment(value: u, label: Text(u.displayName)))
                  .toList(),
              selected: {_servingUnit},
              onSelectionChanged: (s) => setState(() => _servingUnit = s.first),
            ),
            const SizedBox(height: 24),

            // ── Macros ─────────────────────────────────────────────────────
            Text(l10n.nutritionMacronutrients, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            _MacroField(controller: _kcal, label: l10n.nutritionLabelWithUnit(l10n.nutritionCalories, 'kcal')),
            const SizedBox(height: 12),
            _MacroField(controller: _protein, label: l10n.nutritionLabelWithUnit(l10n.nutritionProtein, 'g')),
            const SizedBox(height: 12),
            _MacroField(controller: _carb, label: l10n.nutritionLabelWithUnit(l10n.nutritionCarbs, 'g')),
            const SizedBox(height: 12),
            _MacroField(controller: _fat, label: l10n.nutritionLabelWithUnit(l10n.nutritionFat, 'g')),
            const SizedBox(height: 12),
            _MacroField(controller: _fiber, label: l10n.nutritionLabelWithUnit(l10n.nutritionFiber, 'g')),
            const SizedBox(height: 24),

            // ── Micronutrients ─────────────────────────────────────────────
            _buildMicronutrients(context),
            const SizedBox(height: 20),

            // ── Visibility ─────────────────────────────────────────────────
            SwitchListTile(
              title: Text(l10n.nutritionPublic),
              subtitle: Text(l10n.nutritionVisibleToAllUsers),
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

// ── Shared macro field widget ─────────────────────────────────────────────────

class _MacroField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _MacroField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return context.l10n.commonRequired;
        if (_parseNum(v) == null) return context.l10n.nutritionEnterValidNumber;
        return null;
      },
    );
  }
}

/// Accepts both "1.5" and "1,5" (Serbian decimal comma).
double? _parseNum(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

// ── Micronutrient dialog ──────────────────────────────────────────────────────

class _NutrientOption {
  final String id;
  final String name;
  final String? symbol;
  final String defaultUnit;
  const _NutrientOption(this.id, this.name, this.symbol, this.defaultUnit);
}

class _NutrientInput {
  final _NutrientOption option;
  final double amount;
  final String unit;
  const _NutrientInput(this.option, this.amount, this.unit);
}

class _NutrientDialog extends StatefulWidget {
  final String title;
  final List<_NutrientOption> options;
  final String perLabel;

  const _NutrientDialog({required this.title, required this.options, required this.perLabel});

  @override
  State<_NutrientDialog> createState() => _NutrientDialogState();
}

class _NutrientDialogState extends State<_NutrientDialog> {
  late _NutrientOption _selected = widget.options.first;
  final _amount = TextEditingController();
  late final _unit = TextEditingController(text: widget.options.first.defaultUnit);

  @override
  void dispose() {
    _amount.dispose();
    _unit.dispose();
    super.dispose();
  }

  double? get _parsed {
    final v = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    return v != null && v >= 0 ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<_NutrientOption>(
              initialValue: _selected,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.nutritionNutrient),
              items: widget.options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o.name, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (o) {
                if (o == null) return;
                setState(() {
                  _selected = o;
                  _unit.text = o.defaultUnit;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amount,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l10n.nutritionAmount, helperText: widget.perLabel),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _unit,
                    decoration: InputDecoration(labelText: l10n.nutritionUnit),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(
          onPressed: _parsed == null || _unit.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _NutrientInput(_selected, _parsed!, _unit.text.trim())),
          child: Text(l10n.nutritionAdd),
        ),
      ],
    );
  }
}
