import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../services/settings_service.dart';
import '../utils/plate_calculator.dart';
import 'app_bottom_sheet.dart';

/// Plate calculator + warm-up suggestions in the user's weight unit.
/// [initialWeightKg] pre-fills the target (converted for display).
Future<void> showPlateCalculator(BuildContext context, {double? initialWeightKg}) {
  return showAppBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => PlateCalculatorSheet(initialWeightKg: initialWeightKg),
  );
}

class PlateCalculatorSheet extends StatefulWidget {
  final double? initialWeightKg;

  const PlateCalculatorSheet({super.key, this.initialWeightKg});

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  final _settings = SettingsService.instance;
  late final TextEditingController _target;
  late double _bar;

  bool get _lb => _settings.usesPounds;
  String get _unit => _settings.weightUnit.value;
  List<double> get _plates => _lb ? lbPlates : kgPlates;
  List<double> get _bars => _lb ? lbBars : kgBars;

  @override
  void initState() {
    super.initState();
    _bar = _bars.first;
    final initial = widget.initialWeightKg;
    _target = TextEditingController(
      text: initial == null || initial <= 0
          ? ''
          : formatPlateWeight(_roundDisplay(_settings.toDisplayWeight(initial))),
    );
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  double _roundDisplay(double v) => (v * 4).round() / 4;

  double? get _targetValue => double.tryParse(_target.text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final target = _targetValue;
    final load = target == null
        ? null
        : calculatePlates(target: target, bar: _bar, plates: _plates);
    final warmups = target == null || target <= _bar
        ? const <WarmupSet>[]
        : warmupSets(workingWeight: target, bar: _bar, plates: _plates);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.trainingPlateTitle, style: text.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _target,
              autofocus: widget.initialWeightKg == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.trainingPlateTargetWeight,
                suffixText: _unit,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text(l10n.trainingPlateBar, style: text.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<double>(
              segments: [
                for (final b in _bars)
                  ButtonSegment(value: b, label: Text('${formatPlateWeight(b, _locale(context))} $_unit')),
              ],
              selected: {_bar},
              onSelectionChanged: (s) => setState(() => _bar = s.first),
            ),
            const SizedBox(height: 20),
            if (load == null)
              Text(l10n.trainingPlateEnterTarget, style: TextStyle(color: cs.onSurfaceVariant))
            else ...[
              _LoadSummary(load: load, unit: _unit),
              const SizedBox(height: 24),
              Text(l10n.trainingPlateWarmup, style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                l10n.trainingPlateSuggestedRamp('${formatPlateWeight(load.target, _locale(context))} $_unit'),
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              if (warmups.isEmpty)
                Text(l10n.trainingPlateNoWarmup, style: TextStyle(color: cs.onSurfaceVariant))
              else
                ...warmups.map((w) => _WarmupRow(set: w, unit: _unit)),
            ],
            const SizedBox(height: 8),
            Text(
              l10n.trainingPlateAvailable('${_plates.map((p) => formatPlateWeight(p, _locale(context))).join(', ')} $_unit'),
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadSummary extends StatelessWidget {
  final PlateLoad load;
  final String unit;

  const _LoadSummary({required this.load, required this.unit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.trainingPlateEachSide,
              style: text.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            if (load.platesPerSide.isEmpty)
              Text(l10n.trainingPlateEmptyBar, style: text.titleMedium)
            else ...[
              // The chips below list the same plates, so the drawing is decorative.
              ExcludeSemantics(
                child: _BarDiagram(plates: load.platesPerSide, maxPlate: lbOrKgMax(unit)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in load.countsPerSide.entries)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${e.value} × ${formatPlateWeight(e.key, _locale(context))} $unit'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (load.isExact)
              Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    l10n.trainingPlateTotal('${formatPlateWeight(load.achievable, _locale(context))} $unit'),
                    style: text.titleSmall,
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: cs.tertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.trainingPlateNotExact(
                        '${formatPlateWeight(load.target, _locale(context))} $unit',
                        '${formatPlateWeight(load.achievable, _locale(context))} $unit',
                        '${load.difference > 0 ? '+' : '−'}${formatPlateWeight(load.difference.abs(), _locale(context))} $unit',
                      ),
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static double lbOrKgMax(String unit) => unit == 'lb' ? lbPlates.first : kgPlates.first;
}

/// Plates drawn as blocks on a sleeve, taller for heavier plates.
class _BarDiagram extends StatelessWidget {
  final List<double> plates;
  final double maxPlate;

  const _BarDiagram({required this.plates, required this.maxPlate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const maxH = 64.0;
    return SizedBox(
      height: maxH,
      child: Row(
        children: [
          Container(width: 18, height: 10, color: cs.outline),
          Container(width: 6, height: 26, color: cs.outline),
          for (final p in plates)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Tooltip(
                message: formatPlateWeight(p, _locale(context)),
                child: Container(
                  width: p >= maxPlate * 0.5 ? 14 : 10,
                  height: (maxH * (0.35 + 0.65 * (p / maxPlate))).clamp(18.0, maxH),
                  decoration: BoxDecoration(
                    color: p >= maxPlate * 0.5 ? cs.primary : cs.secondary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          Expanded(child: Container(height: 10, color: cs.outlineVariant)),
        ],
      ),
    );
  }
}

class _WarmupRow extends StatelessWidget {
  final WarmupSet set;
  final String unit;

  const _WarmupRow({required this.set, required this.unit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final plates = set.load.platesPerSide;
    return MergeSemantics(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: cs.secondaryContainer,
          foregroundColor: cs.onSecondaryContainer,
          child: Text('${(set.percent * 100).round()}%', style: const TextStyle(fontSize: 11)),
        ),
        title: Text('${formatPlateWeight(set.weight, _locale(context))} $unit × ${set.reps}'),
        subtitle: Text(
          plates.isEmpty
              ? l10n.trainingPlateEmptyBar
              : l10n.trainingPlatePerSide(plates.map((p) => formatPlateWeight(p, _locale(context))).join(' + ')),
        ),
      ),
    );
  }
}

String _locale(BuildContext context) => Localizations.localeOf(context).toString();
