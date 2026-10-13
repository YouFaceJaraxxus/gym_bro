import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/progress.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/settings_service.dart';
import 'progress_chart.dart';
import 'progress_format.dart';

/// Body weight trend + measurement log. [canEdit] only for the user's own log.
class BodyMeasurementsTab extends StatefulWidget {
  final String? userId;
  final bool canEdit;

  const BodyMeasurementsTab({super.key, this.userId, required this.canEdit});

  @override
  State<BodyMeasurementsTab> createState() => _BodyMeasurementsTabState();
}

class _BodyMeasurementsTabState extends State<BodyMeasurementsTab>
    with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  final _settings = SettingsService.instance;
  List<BodyMeasurement> _items = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      final items = await _api.getBodyMeasurements(token, userId: widget.userId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _edit([BodyMeasurement? existing]) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MeasurementDialog(existing: existing),
    );
    if (data == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;
    try {
      final token = await AuthManager.instance.getValidToken();
      if (existing == null) {
        await _api.createBodyMeasurement(token, data);
      } else {
        await _api.updateBodyMeasurement(token, existing.id, data);
      }
      await _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: TextStyle(color: cs.onError),
          ),
          backgroundColor: cs.error,
        ),
      );
    }
  }

  Future<void> _delete(BodyMeasurement m) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trainingMeasureDeleteTitle),
        content: Text(
          l10n.trainingMeasureDeleteMessage(DateFormat.yMMMd(locale).format(m.measuredOn)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteBodyMeasurement(token, m.id);
      await _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: TextStyle(color: cs.onError),
          ),
          backgroundColor: cs.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<String>(
      valueListenable: _settings.weightUnit,
      builder: (context, unit, _) => _buildContent(unit),
    );
  }

  Widget _buildContent(String unit) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return ProgressErrorView(message: _error!, onRetry: _load);
    }

    final weights = [
      for (final m in _items)
        if (m.weightKg != null)
          ProgressChartPoint(m.measuredOn, _settings.toDisplayWeight(m.weightKg!)),
    ];
    final withWeight = _items.where((m) => m.weightKg != null).toList();
    final latest = withWeight.isEmpty ? null : withWeight.last;
    final first = withWeight.isEmpty ? null : withWeight.first;
    final change = latest != null && first != null && latest != first
        ? latest.weightKg! - first.weightKg!
        : null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_items.isEmpty)
            ProgressEmptyView(
              icon: Icons.monitor_weight_outlined,
              title: l10n.trainingMeasureEmptyTitle,
              message: widget.canEdit
                  ? l10n.trainingMeasureEmptyMessageOwn
                  : l10n.trainingMeasureEmptyMessageOther,
              action: widget.canEdit
                  ? FilledButton.icon(
                      onPressed: () => _edit(),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.trainingMeasureLogAction),
                    )
                  : null,
            )
          else ...[
            Card(
              elevation: 0,
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.trainingMeasureBodyWeight, style: text.titleSmall),
                                Text(
                                  latest == null ? '—' : _settings.formatWeight(latest.weightKg!),
                                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          if (change != null)
                            Text(
                              l10n.trainingMeasureChangeSince(
                                '${change >= 0 ? '+' : '−'}${_settings.formatWeight(change.abs())}',
                                DateFormat.MMMd(locale).format(first!.measuredOn),
                              ),
                              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ProgressLineChart(
                      points: weights,
                      height: 180,
                      seriesLabel: l10n.trainingMeasureBodyWeight,
                      formatValue: (y) => '${NumberFormat('0.0', locale).format(y)} $unit',
                      formatAxis: (y) => y.toStringAsFixed(0),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(l10n.trainingMeasureLogHeading, style: text.titleMedium)),
                if (widget.canEdit)
                  FilledButton.tonalIcon(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.trainingMeasureAdd),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ..._items.reversed.map(
              (m) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.secondaryContainer,
                    foregroundColor: cs.onSecondaryContainer,
                    child: const Icon(Icons.monitor_weight_outlined, size: 20),
                  ),
                  title: Text(
                    [
                      if (m.weightKg != null) _settings.formatWeight(m.weightKg!),
                      if (m.bodyFatPct != null)
                        l10n.trainingMeasureBodyFatValue(
                          NumberFormat('0.0', locale).format(m.bodyFatPct!),
                        ),
                    ].join(' · '),
                  ),
                  subtitle: Text(
                    [
                      DateFormat.yMMMEd(locale).format(m.measuredOn),
                      if (m.note != null && m.note!.isNotEmpty) m.note!,
                    ].join('\n'),
                  ),
                  isThreeLine: m.note != null && m.note!.isNotEmpty,
                  onTap: widget.canEdit ? () => _edit(m) : null,
                  trailing: widget.canEdit
                      ? IconButton(
                          tooltip: l10n.trainingMeasureDeleteTooltip,
                          icon: Icon(Icons.delete_outline, color: cs.error),
                          onPressed: () => _delete(m),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Add / edit dialog. Returns the POST/PUT body (weight in kg).
class _MeasurementDialog extends StatefulWidget {
  final BodyMeasurement? existing;

  const _MeasurementDialog({this.existing});

  @override
  State<_MeasurementDialog> createState() => _MeasurementDialogState();
}

class _MeasurementDialogState extends State<_MeasurementDialog> {
  final _settings = SettingsService.instance;
  late DateTime _date;
  late final TextEditingController _weight;
  late final TextEditingController _fat;
  late final TextEditingController _note;
  String? _error;

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
  }

  @override
  void dispose() {
    _weight.dispose();
    _fat.dispose();
    _note.dispose();
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

  void _submit() {
    final wText = _weight.text.trim().replaceAll(',', '.');
    final fText = _fat.text.trim().replaceAll(',', '.');
    final w = wText.isEmpty ? null : double.tryParse(wText);
    final f = fText.isEmpty ? null : double.tryParse(fText);
    if ((wText.isNotEmpty && (w == null || w <= 0)) ||
        (fText.isNotEmpty && (f == null || f <= 0 || f >= 100))) {
      setState(() => _error = context.l10n.trainingMeasureInvalidNumbers);
      return;
    }
    if (w == null && f == null) {
      setState(() => _error = context.l10n.trainingMeasureNeedValue);
      return;
    }
    Navigator.pop(context, {
      'measured_on': trainingApiDate(_date),
      'weight_kg': w == null
          ? null
          : double.parse(_settings.fromDisplayWeight(w).toStringAsFixed(2)),
      'body_fat_pct': f,
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final dateText = DateFormat.yMMMEd(locale).format(_date);
    return AlertDialog(
      title: Text(
        widget.existing == null ? l10n.trainingMeasureLogAction : l10n.trainingMeasureEditTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(dateText, semanticsLabel: l10n.trainingMeasureDateLabel(dateText)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weight,
              autofocus: widget.existing == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.trainingMeasureBodyWeight,
                suffixText: _settings.weightUnit.value,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fat,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.trainingMeasureBodyFatOptional,
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.trainingMeasureNoteOptional),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }
}
