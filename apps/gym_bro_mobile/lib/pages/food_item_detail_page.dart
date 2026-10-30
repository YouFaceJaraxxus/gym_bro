import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/food_log.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'food_item_form_page.dart';
import 'nutrition/nutrition_widgets.dart';
import '../widgets/share_post.dart';

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
        title: Text(ctx.l10n.nutritionDeleteFoodItemTitle),
        content: Text(ctx.l10n.nutritionRemovePermanently(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(ctx.l10n.commonDelete),
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

  /// Logs this item to today's diary via the amount sheet.
  Future<void> _logToDiary() async {
    final item = _foodItem!;
    final result = await showLogAmountSheet(
      context,
      title: item.name,
      subtitle: item.brand,
      unit: LogUnit.forFoodItem(item),
      perUnit: MacroTotals.forFoodItem(item, 1),
      initialAmount: 100,
      initialSlot: _defaultSlotForNow(),
      confirmLabel: context.l10n.nutritionLogToToday,
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.createFoodLog(
        token,
        date: DateTime.now(),
        slotType: result.slot,
        foodItemId: item.id,
        amount: result.amount,
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.nutritionLoggedToSlot(result.slot.label(l10n)))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(errorText(e), style: TextStyle(color: cs.onError)),
        backgroundColor: cs.error,
      ));
    }
  }

  static MealSlotType _defaultSlotForNow() {
    final h = DateTime.now().hour;
    if (h < 11) return MealSlotType.breakfast;
    if (h < 15) return MealSlotType.lunch;
    if (h < 18) return MealSlotType.afternoonSnack;
    return MealSlotType.dinner;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
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
              Text(_error ?? l10n.commonSomethingWentWrong, style: TextStyle(color: cs.error)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: Text(l10n.commonRetry)),
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
          SharePostButton(target: foodItemShareTarget(item)),
          if (isOwner) ...[
            IconButton(
              tooltip: l10n.commonEdit,
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
              tooltip: l10n.commonDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logToDiary,
        icon: const Icon(Icons.add),
        label: Text(l10n.nutritionLogToDiary),
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
                          style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!item.isPublic) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.lock_outline, size: 18, color: cs.onSurfaceVariant, semanticLabel: l10n.nutritionPrivate),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _TypeChip(type: item.type),
                const SizedBox(width: 8),
                _SubtypeChip(type: item.type, label: item.subtypeLabel(l10n)),
              ],
            ),
            const SizedBox(height: 24),

            // ── Macro grid ───────────────────────────────────────────────────
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MacroCard(label: l10n.nutritionCalories, value: item.kcalPer100, unit: 'kcal'),
                _MacroCard(label: l10n.nutritionProtein, value: item.proteinPer100, unit: 'g'),
                _MacroCard(label: l10n.nutritionCarbs, value: item.carbPer100, unit: 'g'),
                _MacroCard(label: l10n.nutritionFat, value: item.fatPer100, unit: 'g'),
                _MacroCard(label: l10n.nutritionFiber, value: item.fiberPer100, unit: 'g'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.nutritionValuesPer(item.servingUnitLabel(l10n)),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            if (item.barcode != null) ...[
              Row(
                children: [
                  Icon(Icons.qr_code_2, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    l10n.nutritionBarcodeValue(item.barcode!),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Micronutrients ───────────────────────────────────────────────
            _MicronutrientsCard(
              item: item,
              formatAmount: (v) => _formatAmount(v, Localizations.localeOf(context).toString()),
              onAdd: isOwner
                  ? () async {
                      final updated = await Navigator.push<FoodItem>(
                        context,
                        MaterialPageRoute(builder: (_) => FoodItemFormPage(foodItem: item)),
                      );
                      if (updated != null) setState(() => _foodItem = updated);
                    }
                  : null,
            ),
            const SizedBox(height: 88),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double v, String locale) => NumberFormat('0.#', locale).format(v);
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

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat('0.#', Localizations.localeOf(context).toString()).format(value);
    return MergeSemantics(
      child: Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 96,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$formatted $unit',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final FoodItemType type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final c = foodTypeColors(context, type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.container,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        type.label(context.l10n),
        style: TextStyle(fontSize: 12, color: c.onContainer, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SubtypeChip extends StatelessWidget {
  final FoodItemType type;
  final String label;

  const _SubtypeChip({required this.type, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = foodTypeColors(context, type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.container.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: c.onContainer),
      ),
    );
  }
}

class _MicronutrientsCard extends StatelessWidget {
  final FoodItem item;
  final String Function(double) formatAmount;
  final VoidCallback? onAdd;

  const _MicronutrientsCard({required this.item, required this.formatAmount, this.onAdd});

  String _label(String name, String? symbol) =>
      symbol != null && !name.contains('($symbol)') && !name.endsWith(symbol) ? '$name ($symbol)' : name;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final empty = item.vitamins.isEmpty && item.minerals.isEmpty;
    final l10n = context.l10n;

    Widget header(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(title, style: text.labelLarge?.copyWith(color: cs.primary)),
        );

    Widget row(String label, double amount, String unit) => MergeSemantics(
          child: ListTile(
            dense: true,
            title: Text(label),
            trailing: Text('${formatAmount(amount)} $unit', style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(l10n.nutritionMicronutrients, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(item.servingUnitLabel(l10n)),
              trailing: onAdd == null
                  ? null
                  : IconButton(
                      tooltip: l10n.nutritionEditMicronutrients,
                      icon: Icon(empty ? Icons.add : Icons.edit_outlined),
                      onPressed: onAdd,
                    ),
            ),
            if (empty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l10n.nutritionNoMicronutrients,
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            if (item.vitamins.isNotEmpty) ...[
              header(l10n.nutritionVitamins),
              for (final v in item.vitamins)
                row(_label(v.vitamin?.name ?? l10n.nutritionVitamin, v.vitamin?.symbol), v.amountPer100, v.displayUnit),
            ],
            if (item.minerals.isNotEmpty) ...[
              header(l10n.nutritionMinerals),
              for (final m in item.minerals)
                row(_label(m.mineral?.name ?? l10n.nutritionMineral, m.mineral?.symbol), m.amountPer100, m.displayUnit),
            ],
          ],
        ),
      ),
    );
  }
}
