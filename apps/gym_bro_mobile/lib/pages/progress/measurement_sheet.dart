import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/progress.dart';
import '../../services/settings_service.dart';
import '../../utils/body_units.dart';
import '../../widgets/app_bottom_sheet.dart';
import 'body_metric_labels.dart';

/// Opens the add / edit measurement sheet. Returns the POST/PUT body (weight
/// in kg, tape in cm; empty fields are null) or null when dismissed.
Future<Map<String, dynamic>?> showMeasurementSheet(BuildContext context, {BodyMeasurement? existing}) =>
    showAppBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MeasurementSheet(existing: existing),
    );

/// Date, weight and body fat up front; tape measurements in an expandable
/// "Body measurements" section (open when editing an entry that has some).
class MeasurementSheet extends StatefulWidget {
  final BodyMeasurement? existing;

  const MeasurementSheet({super.key, this.existing});

  @override
  State<MeasurementSheet> createState() => _MeasurementSheetState();
}

class _MeasurementSheetState extends State<MeasurementSheet> {
  final _settings = SettingsService.instance;
  late DateTime _date;
  late final TextEditingController _weight;
  late final TextEditingController _fat;
  late final TextEditingController _note;
  late final Map<BodyMetric, TextEditingController> _tape;
  String? _error;

  String get _unit => _settings.weightUnit.value;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _date = e?.measuredOn ?? DateTime(now.year, now.month, now.day);
    _weight = TextEditingController(
      text: e?.weightKg == null ? '' : _settings.toDisplayWeight(e!.weightKg!).toStringAsFixed(1),
    );
    _fat = TextEditingController(text: e?.bodyFatPct?.toStringAsFixed(1) ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _tape = {
      for (final m in BodyMetric.tape)
        m: TextEditingController(
          text: e == null || m.valueOf(e) == null ? '' : toDisplayLength(m.valueOf(e)!, _unit).toStringAsFixed(1),
        ),
    };
  }

  @override
  void dispose() {
    _weight.dispose();
    _fat.dispose();
    _note.dispose();
    for (final c in _tape.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  static double? _parse(String s) {
    final t = s.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  void _submit() {
    final l10n = context.l10n;
    final w = _parse(_weight.text);
    final f = _parse(_fat.text);
    if ((_weight.text.trim().isNotEmpty && (w == null || w <= 0)) ||
        (_fat.text.trim().isNotEmpty && (f == null || f <= 0 || f >= 100))) {
      setState(() => _error = l10n.trainingMeasureInvalidNumbers);
      return;
    }
    final tape = <String, double?>{};
    for (final m in BodyMetric.tape) {
      final raw = _tape[m]!.text;
      final v = _parse(raw);
      if (raw.trim().isNotEmpty && v == null) {
        setState(() => _error = l10n.trainingMeasureInvalidNumbers);
        return;
      }
      final cm = v == null ? null : fromDisplayLength(v, _unit);
      if (cm != null && (cm < m.min! || cm > m.max!)) {
        final lu = lengthUnitFor(_unit);
        setState(() => _error = l10n.bodyTapeOutOfRange(
          bodyMetricLabel(m, l10n),
          toDisplayLength(m.min!, _unit).toStringAsFixed(0),
          toDisplayLength(m.max!, _unit).toStringAsFixed(0),
          lu,
        ));
        return;
      }
      tape[m.apiKey] = cm;
    }
    if (w == null && f == null && tape.values.every((v) => v == null)) {
      setState(() => _error = l10n.bodyNeedAnyValue);
      return;
    }
    Navigator.pop(context, {
      'measured_on': trainingApiDate(_date),
      'weight_kg': w == null ? null : double.parse(_settings.fromDisplayWeight(w).toStringAsFixed(2)),
      'body_fat_pct': f,
      ...tape,
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final dateText = DateFormat.yMMMEd(locale).format(_date);
    final lu = lengthUnitFor(_unit);
    final e = widget.existing;
    const decimal = TextInputType.numberWithOptions(decimal: true);

    Widget tapeField(BodyMetric m) => TextField(
      controller: _tape[m],
      keyboardType: decimal,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: bodyMetricLabel(m, l10n), suffixText: lu, isDense: true),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              e == null ? l10n.trainingMeasureLogAction : l10n.trainingMeasureEditTitle,
              style: text.titleLarge,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(dateText, semanticsLabel: l10n.trainingMeasureDateLabel(dateText)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weight,
                    autofocus: e == null,
                    keyboardType: decimal,
                    decoration: InputDecoration(
                      labelText: l10n.trainingMeasureBodyWeight,
                      suffixText: _unit,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _fat,
                    keyboardType: decimal,
                    decoration: InputDecoration(labelText: l10n.bodyMetricBodyFat, suffixText: '%'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: cs.surfaceContainerLow,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: e?.hasTape ?? false,
                  leading: Icon(Icons.straighten, color: cs.primary),
                  title: Text(l10n.bodyTapeSection),
                  subtitle: Text(
                    l10n.bodyTapeSectionHint(lu),
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    for (var i = 0; i < BodyMetric.tape.length; i += 2) ...[
                      if (i > 0) const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: tapeField(BodyMetric.tape[i])),
                          const SizedBox(width: 12),
                          Expanded(child: tapeField(BodyMetric.tape[i + 1])),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.trainingMeasureNoteOptional),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: _submit, child: Text(l10n.commonSave))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
