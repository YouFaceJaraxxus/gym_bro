import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/food_log.dart';
import '../../models/meal_plan.dart';
import '../../theme.dart';

// ── Macro colors (derived from the theme so dark mode works) ──────────────────

class MacroColors {
  final Color kcal;
  final Color protein;
  final Color carb;
  final Color fat;

  const MacroColors._(this.kcal, this.protein, this.carb, this.fat);

  factory MacroColors.of(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MacroColors._(cs.primary, cs.tertiary, cs.secondary, cs.error);
  }
}

/// Accent colors for a food item type (food / spice / drink), legible in both
/// themes: [color] for text/borders on surfaces, [container]/[onContainer]
/// for filled chips.
({Color color, Color container, Color onContainer}) foodTypeColors(BuildContext context, FoodItemType type) {
  final cs = Theme.of(context).colorScheme;
  final app = context.appColors;
  return switch (type) {
    FoodItemType.food => (color: app.success, container: app.successContainer, onContainer: app.onSuccessContainer),
    FoodItemType.spice => (color: app.warning, container: app.warningContainer, onContainer: app.onWarningContainer),
    FoodItemType.drink => (color: cs.tertiary, container: cs.tertiaryContainer, onContainer: cs.onTertiaryContainer),
  };
}

// ── Calorie ring ──────────────────────────────────────────────────────────────

/// Circular kcal progress. Without a [target] it just shows the eaten total.
class KcalRing extends StatelessWidget {
  final double eaten;
  final double? target;
  final double size;

  const KcalRing({super.key, required this.eaten, this.target, this.size = 120});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final over = target != null && target! > 0 && eaten > target!;
    final remaining = target == null ? null : (target! - eaten);
    return Semantics(
      label: target == null
          ? l10n.nutritionKcalEatenSemantics(eaten.round())
          : l10n.nutritionKcalRingSemantics(eaten.round(), target!.round()),
      excludeSemantics: true,
      child: SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: target == null ? 0 : progressFraction(eaten, target),
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: cs.surfaceContainerHighest,
              color: over ? cs.error : cs.primary,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                eaten.round().toString(),
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                target == null ? l10n.nutritionKcal : l10n.nutritionOfTargetKcal(target!.round()),
                style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (remaining != null)
                Text(
                  remaining >= 0
                      ? l10n.nutritionKcalLeft(remaining.round())
                      : l10n.nutritionKcalOver((-remaining).round()),
                  style: text.labelSmall?.copyWith(
                    color: remaining >= 0 ? cs.onSurfaceVariant : cs.error,
                    fontWeight: FontWeight.w600,
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

// ── Macro bar ─────────────────────────────────────────────────────────────────

class MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double? target;
  final Color color;

  const MacroBar({
    super.key,
    required this.label,
    required this.value,
    this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: text.labelMedium),
            const Spacer(),
            Text(
              target == null ? '${value.round()} g' : '${value.round()} / ${target!.round()} g',
              style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: target == null ? 0 : progressFraction(value, target),
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
            color: color,
          ),
        ),
      ],
      ),
    );
  }
}

/// Compact "kcal · P · C · F" line for list rows.
class MacroLine extends StatelessWidget {
  final MacroTotals macros;
  const MacroLine({super.key, required this.macros});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      macros.pcfLabel(context.l10n),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
    );
  }
}

// ── Amount sheet ──────────────────────────────────────────────────────────────

/// Result of [showLogAmountSheet].
class LogAmountResult {
  final double amount;
  final MealSlotType slot;
  const LogAmountResult(this.amount, this.slot);
}

/// Bottom sheet: amount (in [unit]) + meal slot, with a live macro preview.
/// [perUnit] = macros for one g/ml/serving.
Future<LogAmountResult?> showLogAmountSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required LogUnit unit,
  required MacroTotals perUnit,
  required double initialAmount,
  required MealSlotType initialSlot,
  String? confirmLabel,
}) {
  return showModalBottomSheet<LogAmountResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _LogAmountSheet(
      title: title,
      subtitle: subtitle,
      unit: unit,
      perUnit: perUnit,
      initialAmount: initialAmount,
      initialSlot: initialSlot,
      confirmLabel: confirmLabel ?? context.l10n.nutritionLogAction,
    ),
  );
}

class _LogAmountSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final LogUnit unit;
  final MacroTotals perUnit;
  final double initialAmount;
  final MealSlotType initialSlot;
  final String confirmLabel;

  const _LogAmountSheet({
    required this.title,
    this.subtitle,
    required this.unit,
    required this.perUnit,
    required this.initialAmount,
    required this.initialSlot,
    required this.confirmLabel,
  });

  @override
  State<_LogAmountSheet> createState() => _LogAmountSheetState();
}

class _LogAmountSheetState extends State<_LogAmountSheet> {
  late final TextEditingController _amount;
  late MealSlotType _slot;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: fmtAmount(widget.initialAmount));
    _slot = widget.initialSlot;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _parsed {
    final v = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    return v != null && v > 0 ? v : null;
  }

  List<double> get _presets => widget.unit == LogUnit.serving
      ? const [0.5, 1, 1.5, 2]
      : const [50, 100, 150, 200, 250];

  void _submit() {
    final v = _parsed;
    if (v == null) return;
    Navigator.pop(context, LogAmountResult(v, _slot));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final amount = _parsed ?? 0;
    final p = widget.perUnit;
    final preview = MacroTotals(
      kcal: p.kcal * amount,
      protein: p.protein * amount,
      carb: p.carb * amount,
      fat: p.fat * amount,
      fiber: p.fiber * amount,
    );
    final colors = MacroColors.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: text.titleLarge),
            if (widget.subtitle != null)
              Text(widget.subtitle!, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(
                labelText: l10n.nutritionAmount,
                suffixText: widget.unit.shortLabel(l10n),
                border: const OutlineInputBorder(),
                errorText: _amount.text.isNotEmpty && _parsed == null ? l10n.nutritionEnterPositiveNumber : null,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _presets
                  .map((v) => ActionChip(
                        label: Text(widget.unit.label(l10n, v)),
                        onPressed: () => setState(() => _amount.text = fmtAmount(v)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MealSlotType>(
              initialValue: _slot,
              decoration: InputDecoration(labelText: l10n.nutritionMeal, border: const OutlineInputBorder()),
              items: MealSlotType.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label(l10n))))
                  .toList(),
              onChanged: (v) => setState(() => _slot = v ?? _slot),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              color: cs.surfaceContainerHigh,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _PreviewStat(label: l10n.nutritionKcal, value: preview.kcal, color: colors.kcal),
                    _PreviewStat(label: l10n.nutritionProtein, value: preview.protein, color: colors.protein, unit: 'g'),
                    _PreviewStat(label: l10n.nutritionCarbsShort, value: preview.carb, color: colors.carb, unit: 'g'),
                    _PreviewStat(label: l10n.nutritionFat, value: preview.fat, color: colors.fat, unit: 'g'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _parsed == null ? null : _submit,
              child: Text(widget.confirmLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String unit;

  const _PreviewStat({required this.label, required this.value, required this.color, this.unit = ''});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    return MergeSemantics(
      child: Column(
      children: [
        Text(
          '${value < 10 && unit.isNotEmpty ? NumberFormat('0.0', locale).format(value) : value.round()}$unit',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: text.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
      ),
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────────

class NutritionErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const NutritionErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(
              message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}

class NutritionEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  const NutritionEmptyView({super.key, required this.icon, required this.title, this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: cs.outline),
          const SizedBox(height: 12),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

String errorText(Object e) => e.toString().replaceFirst('Exception: ', '');
