import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

class FoodItemFormPage extends StatefulWidget {
  final FoodItem? foodItem;

  const FoodItemFormPage({super.key, this.foodItem});

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

  bool get _isEditing => widget.foodItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.foodItem;
    _name = TextEditingController(text: item?.name ?? '');
    _brand = TextEditingController(text: item?.brand ?? '');
    _barcode = TextEditingController(text: item?.barcode ?? '');
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
        'kcal_per_100': double.tryParse(_kcal.text.trim()) ?? 0,
        'protein_per_100': double.tryParse(_protein.text.trim()) ?? 0,
        'carb_per_100': double.tryParse(_carb.text.trim()) ?? 0,
        'fat_per_100': double.tryParse(_fat.text.trim()) ?? 0,
        'fiber_per_100': double.tryParse(_fiber.text.trim()) ?? 0,
        'is_public': _isPublic,
      };
      final FoodItem result;
      if (_isEditing) {
        result = await _api.updateFoodItem(token, widget.foodItem!.id, data);
      } else {
        result = await _api.createFoodItem(token, data);
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

  // ── Subtype dropdown helpers ──────────────────────────────────────────────

  Widget _buildSubtypeDropdown() {
    switch (_type) {
      case FoodItemType.food:
        return DropdownButtonFormField<FoodSubtype>(
          key: const ValueKey('food_subtype'),
          initialValue: _foodSubtype,
          decoration: const InputDecoration(labelText: 'Subtype *'),
          items: FoodSubtype.values
              .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName)))
              .toList(),
          validator: (v) => v == null ? 'Required' : null,
          onChanged: (v) => setState(() => _foodSubtype = v),
        );
      case FoodItemType.drink:
        return DropdownButtonFormField<DrinkSubtype>(
          key: const ValueKey('drink_subtype'),
          initialValue: _drinkSubtype,
          decoration: const InputDecoration(labelText: 'Subtype *'),
          items: DrinkSubtype.values
              .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName)))
              .toList(),
          validator: (v) => v == null ? 'Required' : null,
          onChanged: (v) => setState(() => _drinkSubtype = v),
        );
      case FoodItemType.spice:
        return DropdownButtonFormField<SpiceSubtype>(
          key: const ValueKey('spice_subtype'),
          initialValue: _spiceSubtype,
          decoration: const InputDecoration(labelText: 'Subtype *'),
          items: SpiceSubtype.values
              .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName)))
              .toList(),
          validator: (v) => v == null ? 'Required' : null,
          onChanged: (v) => setState(() => _spiceSubtype = v),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Food Item' : 'New Food Item'),
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
            TextButton(onPressed: _save, child: const Text('Save')),
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
              decoration: const InputDecoration(labelText: 'Name *'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _brand,
              decoration: const InputDecoration(labelText: 'Brand (optional)'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _barcode,
              decoration: const InputDecoration(
                labelText: 'Barcode (optional)',
                hintText: 'EAN / UPC',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // ── Type ───────────────────────────────────────────────────────
            const Text('Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            SegmentedButton<FoodItemType>(
              segments: FoodItemType.values
                  .map((t) => ButtonSegment(value: t, label: Text(t.displayName)))
                  .toList(),
              selected: {_type},
              onSelectionChanged: (s) => _onTypeChanged(s.first),
            ),
            const SizedBox(height: 16),

            // ── Subtype ────────────────────────────────────────────────────
            _buildSubtypeDropdown(),
            const SizedBox(height: 16),

            // ── Serving unit ───────────────────────────────────────────────
            const Text('Serving unit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
            const Text('Macronutrients', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            _MacroField(controller: _kcal, label: 'Calories (kcal)'),
            const SizedBox(height: 12),
            _MacroField(controller: _protein, label: 'Protein (g)'),
            const SizedBox(height: 12),
            _MacroField(controller: _carb, label: 'Carbs (g)'),
            const SizedBox(height: 12),
            _MacroField(controller: _fat, label: 'Fat (g)'),
            const SizedBox(height: 12),
            _MacroField(controller: _fiber, label: 'Fiber (g)'),
            const SizedBox(height: 4),
            Text(
              'Micronutrients can be added after saving.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),

            // ── Visibility ─────────────────────────────────────────────────
            SwitchListTile(
              title: const Text('Public'),
              subtitle: const Text('Visible to all users'),
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
        if (v == null || v.trim().isEmpty) return 'Required';
        if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
        return null;
      },
    );
  }
}
