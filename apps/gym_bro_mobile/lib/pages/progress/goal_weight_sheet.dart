import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/settings_service.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_bottom_sheet.dart';

/// Set, change or remove the goal weight (`user_settings.goal_weight_kg`).
/// [currentKg] (the trend) is offered as a hint. Returns true when saved.
Future<bool?> showGoalWeightSheet(BuildContext context, {double? currentKg}) => showAppBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => GoalWeightSheet(currentKg: currentKg),
);

class GoalWeightSheet extends StatefulWidget {
  final double? currentKg;

  const GoalWeightSheet({super.key, this.currentKg});

  @override
  State<GoalWeightSheet> createState() => _GoalWeightSheetState();
}

class _GoalWeightSheetState extends State<GoalWeightSheet> {
  /// The API accepts 20–400 kg.
  static const _minKg = 20.0;
  static const _maxKg = 400.0;

  final _settings = SettingsService.instance;
  late final TextEditingController _goal;
  bool _saving = false;
  String? _error;

  double? get _existing => _settings.settings.value.goalWeightKg;

  @override
  void initState() {
    super.initState();
    _goal = TextEditingController(
      text: _existing == null ? '' : _settings.toDisplayWeight(_existing!).toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    final l10n = context.l10n;
    double? kg;
    if (!remove) {
      final v = double.tryParse(_goal.text.trim().replaceAll(',', '.'));
      kg = v == null ? null : double.parse(_settings.fromDisplayWeight(v).toStringAsFixed(1));
      if (kg == null || kg < _minKg || kg > _maxKg) {
        setState(() => _error = l10n.bodyGoalInvalid(_settings.formatWeight(_minKg, decimals: 0), _settings.formatWeight(_maxKg, decimals: 0)));
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (remove) {
        await _settings.update(clearGoalWeight: true);
      } else {
        await _settings.update(goalWeightKg: kg);
      }
      Haptics.tap();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final unit = _settings.weightUnit.value;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, color: cs.tertiary),
                const SizedBox(width: 8),
                Text(_existing == null ? l10n.bodyGoalSetTitle : l10n.bodyGoalEditTitle, style: text.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.currentKg == null
                  ? l10n.bodyGoalSheetHelp
                  : l10n.bodyGoalSheetHelpCurrent(_settings.formatWeight(widget.currentKg!)),
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _goal,
              autofocus: true,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: l10n.bodyGoalFieldLabel,
                suffixText: unit,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (_existing != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => _save(remove: true),
                      style: OutlinedButton.styleFrom(foregroundColor: cs.error),
                      child: Text(l10n.bodyGoalRemove),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l10n.commonSave),
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
