import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'food_item_form_page.dart';

class FoodItemDetailPage extends StatefulWidget {
  final String foodItemId;

  const FoodItemDetailPage({super.key, required this.foodItemId});

  @override
  State<FoodItemDetailPage> createState() => _FoodItemDetailPageState();
}

class _FoodItemDetailPageState extends State<FoodItemDetailPage> {
  final _api = ApiService();
  FoodItem? _foodItem;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final item = await _api.getFoodItem(token, widget.foodItemId);
      setState(() {
        _foodItem = item;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _delete() async {
    final item = _foodItem!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete food item?'),
        content: Text('Remove "${item.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteFoodItem(token, item.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _foodItem == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Unknown error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final item = _foodItem!;
    final profile = AuthManager.instance.profile;
    final isOwner = profile != null && profile.id == item.authorId;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.push<FoodItem>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FoodItemFormPage(foodItem: item),
                  ),
                );
                if (updated != null) setState(() => _foodItem = updated);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      if (item.brand != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.brand!,
                          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!item.isPublic) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _TypeChip(type: item.type),
                const SizedBox(width: 8),
                _SubtypeChip(type: item.type, label: item.subtypeLabel),
              ],
            ),
            const SizedBox(height: 24),

            // ── Macro grid ───────────────────────────────────────────────────
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MacroCard(label: 'Calories', value: item.kcalPer100, unit: 'kcal'),
                _MacroCard(label: 'Protein', value: item.proteinPer100, unit: 'g'),
                _MacroCard(label: 'Carbs', value: item.carbPer100, unit: 'g'),
                _MacroCard(label: 'Fat', value: item.fatPer100, unit: 'g'),
                _MacroCard(label: 'Fiber', value: item.fiberPer100, unit: 'g'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Values ${item.servingUnitLabel}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),

            // ── Vitamins ─────────────────────────────────────────────────────
            if (item.vitamins.isNotEmpty) ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  title: const Text('Vitamins', style: TextStyle(fontWeight: FontWeight.w600)),
                  shape: const Border(),
                  children: item.vitamins.map((v) {
                    final name = v.vitamin?.name ?? v.vitaminId;
                    final symbol = v.vitamin?.symbol;
                    return ListTile(
                      dense: true,
                      title: Text(symbol != null ? '$name ($symbol)' : name),
                      trailing: Text(
                        '${_formatAmount(v.amountPer100)} ${v.displayUnit}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Minerals ─────────────────────────────────────────────────────
            if (item.minerals.isNotEmpty) ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  title: const Text('Minerals', style: TextStyle(fontWeight: FontWeight.w600)),
                  shape: const Border(),
                  children: item.minerals.map((m) {
                    final name = m.mineral?.name ?? m.mineralId;
                    final symbol = m.mineral?.symbol;
                    return ListTile(
                      dense: true,
                      title: Text(symbol != null ? '$name ($symbol)' : name),
                      trailing: Text(
                        '${_formatAmount(m.amountPer100)} ${m.displayUnit}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  String _formatAmount(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _MacroCard extends StatelessWidget {
  final String label;
  final double value;
  final String unit;

  const _MacroCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  String get _formatted =>
      value == value.truncateToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 96,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_formatted $unit',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final FoodItemType type;

  const _TypeChip({required this.type});

  Color get _color {
    switch (type) {
      case FoodItemType.food:
        return Colors.green;
      case FoodItemType.spice:
        return Colors.orange;
      case FoodItemType.drink:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        type.displayName,
        style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SubtypeChip extends StatelessWidget {
  final FoodItemType type;
  final String label;

  const _SubtypeChip({required this.type, required this.label});

  Color get _color {
    switch (type) {
      case FoodItemType.food:
        return Colors.green;
      case FoodItemType.spice:
        return Colors.orange;
      case FoodItemType.drink:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: _color.withValues(alpha: 0.85)),
      ),
    );
  }
}
