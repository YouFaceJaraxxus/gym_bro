import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/progress.dart';
import '../../models/user_settings.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/settings_service.dart';
import '../../theme.dart';
import '../../utils/body_units.dart';
import '../../utils/weight_trend.dart';
import '../../widgets/skeleton.dart';
import 'body_metric_labels.dart';
import 'body_trend_chart.dart';
import 'goal_weight_sheet.dart';
import 'measurement_sheet.dart';
import 'progress_chart.dart';
import 'progress_format.dart';

/// Body weight trend, tape measurements and the measurement log. [canEdit]
/// only for the user's own log (a coach viewing a client can't edit, and
/// doesn't see the viewer's own goal).
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

  void _showError(Object e) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', ''), style: TextStyle(color: cs.onError)),
        backgroundColor: cs.error,
      ),
    );
  }

  Future<void> _edit([BodyMeasurement? existing]) async {
    final data = await showMeasurementSheet(context, existing: existing);
    if (data == null || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      if (existing == null) {
        await _api.createBodyMeasurement(token, data);
      } else {
        await _api.updateBodyMeasurement(token, existing.id, data);
      }
      await _load();
    } catch (e) {
      if (mounted) _showError(e);
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
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteBodyMeasurement(token, m.id);
      await _load();
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _items.isEmpty) {
      return SkeletonList(
        itemCount: 3,
        padding: const EdgeInsets.only(top: 16),
        header: const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SkeletonBox(height: 300, radius: 20),
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return ProgressErrorView(message: _error!, onRetry: _load);
    }
    return ValueListenableBuilder<String>(
      valueListenable: _settings.weightUnit,
      builder: (context, _, _) => ValueListenableBuilder<UserSettings>(
        valueListenable: _settings.settings,
        builder: (context, s, _) => BodyProgressView(
          items: _items,
          canEdit: widget.canEdit,
          goalKg: widget.canEdit ? s.goalWeightKg : null,
          onRefresh: _load,
          onAdd: () => _edit(),
          onEdit: _edit,
          onDelete: _delete,
        ),
      ),
    );
  }
}

/// Date ranges for the body charts.
enum BodyRange {
  m1(30),
  m3(91),
  y1(365),
  all(null);

  final int? days;
  const BodyRange(this.days);

  String label(AppLocalizations l10n) => switch (this) {
    BodyRange.m1 => l10n.trainingProgressRange1m,
    BodyRange.m3 => l10n.trainingProgressRange3m,
    BodyRange.y1 => l10n.bodyRange1y,
    BodyRange.all => l10n.trainingProgressRangeAll,
  };

  /// The first day shown, or null for everything.
  DateTime? start(DateTime today) =>
      days == null ? null : DateTime(today.year, today.month, today.day - days!);
}

/// The Body tab's content for a list of measurements (oldest first): metric
/// chips, the chart for the chosen metric and range, the goal card (weight,
/// own log only) and the log.
class BodyProgressView extends StatefulWidget {
  final List<BodyMeasurement> items;
  final bool canEdit;

  /// The goal weight (kg); only passed for the user's own log.
  final double? goalKg;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;
  final ValueChanged<BodyMeasurement> onEdit;
  final ValueChanged<BodyMeasurement> onDelete;

  /// "Today", for tests.
  final DateTime? today;

  const BodyProgressView({
    super.key,
    required this.items,
    required this.canEdit,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.goalKg,
    this.today,
  });

  @override
  State<BodyProgressView> createState() => _BodyProgressViewState();
}

class _BodyProgressViewState extends State<BodyProgressView> {
  final _settings = SettingsService.instance;
  BodyMetric _metric = BodyMetric.weight;
  BodyRange _range = BodyRange.m3;

  String get _unit => _settings.weightUnit.value;

  DateTime get _today {
    final t = widget.today ?? DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  /// [m]'s value in display units.
  double _display(BodyMetric m, double v) =>
      m == BodyMetric.weight ? _settings.toDisplayWeight(v) : m.isLength ? toDisplayLength(v, _unit) : v;

  String _format(BodyMetric m, double display, String locale) {
    final n = NumberFormat('0.0', locale).format(display);
    return switch (m) {
      BodyMetric.weight => '$n $_unit',
      BodyMetric.bodyFat => '$n %',
      _ => '$n ${lengthUnitFor(_unit)}',
    };
  }

  String _signed(String formattedAbs, double v) => '${v < 0 ? '−' : '+'}$formattedAbs';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = widget.items;
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          children: [
            ProgressEmptyView(
              icon: Icons.monitor_weight_outlined,
              title: l10n.trainingMeasureEmptyTitle,
              message: widget.canEdit
                  ? l10n.trainingMeasureEmptyMessageOwn
                  : l10n.trainingMeasureEmptyMessageOther,
              action: widget.canEdit
                  ? FilledButton.icon(
                      onPressed: widget.onAdd,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.trainingMeasureLogAction),
                    )
                  : null,
            ),
          ],
        ),
      );
    }

    final available = [
      for (final m in BodyMetric.values)
        if (m == BodyMetric.weight || items.any((e) => m.valueOf(e) != null)) m,
    ];
    final metric = available.contains(_metric) ? _metric : BodyMetric.weight;
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (available.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final m in available)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(bodyMetricIcon(m), size: 18),
                        label: Text(bodyMetricLabel(m, l10n)),
                        selected: m == metric,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _metric = m),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          metric == BodyMetric.weight ? _weightCard(context) : _metricCard(context, metric),
          if (metric == BodyMetric.weight && widget.canEdit) ...[
            const SizedBox(height: 12),
            _goalCard(context),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Text(l10n.trainingMeasureLogHeading, style: text.titleMedium)),
              if (widget.canEdit)
                FilledButton.tonalIcon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.trainingMeasureAdd),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.reversed.map((m) => _entryTile(context, m)),
        ],
      ),
    );
  }

  // ── Weight ──────────────────────────────────────────────────────────────────

  List<TrendPoint> get _rawKg => [
    for (final m in widget.items)
      if (m.weightKg != null) TrendPoint(m.measuredOn, m.weightKg!),
  ];

  Widget _rangePicker(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<BodyRange>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          for (final r in BodyRange.values) ButtonSegment(value: r, label: Text(r.label(l10n))),
        ],
        selected: {_range},
        onSelectionChanged: (s) => setState(() => _range = s.first),
      ),
    );
  }

  Widget _chartCard(BuildContext context, {required Widget header, required Widget chart, Widget? legend}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: header),
            const SizedBox(height: 8),
            chart,
            if (legend != null) Padding(padding: const EdgeInsets.fromLTRB(12, 4, 8, 0), child: legend),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _rangePicker(context)),
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context, {
    required String label,
    required String value,
    String? sub,
    String? change,
    String? changeHint,
  }) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value, style: AppText.stat(size: 36, weight: FontWeight.w800, color: cs.onSurface)),
              if (sub != null)
                Text(sub, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        if (change != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  change,
                  style: text.labelLarge?.copyWith(color: cs.onSecondaryContainer, fontWeight: FontWeight.w700),
                ),
              ),
              if (changeHint != null) ...[
                const SizedBox(height: 4),
                Text(changeHint, style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ],
          ),
      ],
    );
  }

  Widget _weightCard(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final rawKg = _rawKg;
    if (rawKg.isEmpty) {
      return _chartCard(
        context,
        header: _header(context, label: l10n.bodyTrendWeight, value: '—'),
        chart: BodyTrendChart(raw: const [], trend: const [], formatValue: (y) => _format(BodyMetric.weight, y, locale)),
      );
    }
    final trendKg = weightTrend(rawKg);
    final start = _range.start(_today);
    bool inRange(TrendPoint p) => start == null || !p.date.isBefore(start);
    TrendPoint disp(TrendPoint p) => TrendPoint(p.date, _settings.toDisplayWeight(p.value));
    var raw = [for (final p in rawKg) if (inRange(p)) disp(p)];
    var trend = [for (final p in trendKg) if (inRange(p)) disp(p)];
    if (trend.isEmpty) {
      // Nothing logged in this range: show the latest point so the card isn't blank.
      raw = [disp(rawKg.last)];
      trend = [disp(trendKg.last)];
    }
    final lastRaw = rawKg.last;
    final rateKg = weeklyRate(trendKg);
    final rawChange = trend.length > 1 ? trend.last.value - trend.first.value : null;
    // Hide a change that rounds to zero ("−0.0 kg").
    final change = rawChange == null || rawChange.abs() < 0.05 ? null : rawChange;
    final goalDisp = widget.goalKg == null ? null : _settings.toDisplayWeight(widget.goalKg!);

    return _chartCard(
      context,
      header: _header(
        context,
        label: l10n.bodyTrendWeight,
        value: _settings.formatWeight(trendKg.last.value),
        sub: [
          l10n.bodyLastWeighIn(_settings.formatWeight(lastRaw.value), DateFormat.MMMd(locale).format(lastRaw.date)),
          if (rateKg != null) l10n.bodyRatePerWeek(_signed(_settings.formatWeight(rateKg.abs(), decimals: 2), rateKg)),
        ].join('\n'),
        change: change == null ? null : _signed(_format(BodyMetric.weight, change.abs(), locale), change),
        changeHint: change == null ? null : _range == BodyRange.all
            ? l10n.bodyChangeSince(DateFormat.MMMd(locale).format(trend.first.date))
            : l10n.bodyChangeInRange(_range.label(l10n)),
      ),
      chart: BodyTrendChart(
        raw: raw,
        trend: trend,
        goal: goalDisp,
        formatValue: (y) => _format(BodyMetric.weight, y, locale),
      ),
      legend: BodyTrendLegend(
        showGoal: goalDisp != null &&
            BodyTrendChart.goalFits(
              goalDisp,
              [...raw, ...trend].map((p) => p.value).reduce((a, b) => a < b ? a : b),
              [...raw, ...trend].map((p) => p.value).reduce((a, b) => a > b ? a : b),
            ),
      ),
    );
  }

  Widget _goalCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final rawKg = _rawKg;
    final trendKg = weightTrend(rawKg);
    final current = trendKg.isEmpty ? null : trendKg.last.value;
    final goal = widget.goalKg;

    Future<void> openSheet() => showGoalWeightSheet(context, currentKg: current);

    if (goal == null) {
      return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: cs.tertiaryContainer,
            foregroundColor: cs.onTertiaryContainer,
            child: const Icon(Icons.flag_outlined),
          ),
          title: Text(l10n.bodyGoalSetTitle),
          subtitle: Text(l10n.bodyGoalSetHint),
          trailing: const Icon(Icons.chevron_right),
          onTap: openSheet,
        ),
      );
    }

    final eta = goalEta(current: current, goal: goal, ratePerWeek: weeklyRate(trendKg), today: _today);
    final remaining = current == null ? null : goal - current;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.tertiaryContainer.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.tertiary,
                  foregroundColor: cs.onTertiary,
                  radius: 18,
                  child: const Icon(Icons.flag, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.bodyLegendGoal, style: text.labelMedium?.copyWith(color: cs.onTertiaryContainer)),
                      Text(
                        _settings.formatWeight(goal),
                        style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: cs.onTertiaryContainer),
                      ),
                    ],
                  ),
                ),
                if (remaining != null && eta.kind != GoalEtaKind.reached)
                  Text(
                    l10n.bodyGoalToGo(_settings.formatWeight(remaining.abs())),
                    style: text.labelLarge?.copyWith(color: cs.onTertiaryContainer),
                  ),
                IconButton(
                  tooltip: l10n.bodyGoalEditTitle,
                  icon: Icon(Icons.edit_outlined, color: cs.onTertiaryContainer),
                  onPressed: openSheet,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (eta.kind) {
                      GoalEtaKind.reached => Icons.celebration_outlined,
                      GoalEtaKind.wrongWay => Icons.trending_flat,
                      GoalEtaKind.onTrack => Icons.event_available_outlined,
                      _ => Icons.info_outline,
                    },
                    size: 18,
                    color: cs.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goalEtaText(context, eta, goalKg: goal, rateKg: weeklyRate(trendKg)),
                      style: text.bodyMedium?.copyWith(color: cs.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Other metrics ───────────────────────────────────────────────────────────

  Widget _metricCard(BuildContext context, BodyMetric metric) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final start = _range.start(_today);
    final all = [
      for (final m in widget.items)
        if (metric.valueOf(m) != null) ProgressChartPoint(m.measuredOn, _display(metric, metric.valueOf(m)!)),
    ];
    final points = [for (final p in all) if (start == null || !p.date.isBefore(start)) p];
    final latest = all.isEmpty ? null : all.last;
    final rawChange = points.length > 1 ? points.last.y - points.first.y : null;
    final change = rawChange == null || rawChange.abs() < 0.05 ? null : rawChange;
    return _chartCard(
      context,
      header: _header(
        context,
        label: bodyMetricLabel(metric, l10n),
        value: latest == null ? '—' : _format(metric, latest.y, locale),
        sub: latest == null ? null : DateFormat.yMMMd(locale).format(latest.date),
        change: change == null ? null : _signed(_format(metric, change.abs(), locale), change),
        changeHint: change == null ? null : _range == BodyRange.all
            ? l10n.bodyChangeSince(DateFormat.MMMd(locale).format(points.first.date))
            : l10n.bodyChangeInRange(_range.label(l10n)),
      ),
      chart: ProgressLineChart(
        points: points,
        height: 200,
        seriesLabel: bodyMetricLabel(metric, l10n),
        formatValue: (y) => _format(metric, y, locale),
      ),
    );
  }

  // ── Log ─────────────────────────────────────────────────────────────────────

  Widget _entryTile(BuildContext context, BodyMeasurement m) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final nf = NumberFormat('0.0', locale);
    final main = [
      if (m.weightKg != null) _settings.formatWeight(m.weightKg!),
      if (m.bodyFatPct != null) l10n.trainingMeasureBodyFatValue(nf.format(m.bodyFatPct!)),
    ];
    final tape = [
      for (final t in BodyMetric.tape)
        if (t.valueOf(m) != null) '${bodyMetricLabel(t, l10n)} ${nf.format(toDisplayLength(t.valueOf(m)!, _unit))}',
    ];
    final tapeLine = tape.isEmpty ? null : '${tape.join(' · ')} ${lengthUnitFor(_unit)}';
    final lines = [
      DateFormat.yMMMEd(locale).format(m.measuredOn),
      if (main.isNotEmpty && tapeLine != null) tapeLine,
      if (m.note != null && m.note!.isNotEmpty) m.note!,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.secondaryContainer,
          foregroundColor: cs.onSecondaryContainer,
          child: Icon(main.isEmpty ? Icons.straighten : Icons.monitor_weight_outlined, size: 20),
        ),
        title: Text(main.isEmpty ? tapeLine ?? '' : main.join(' · ')),
        subtitle: Text(lines.join('\n')),
        isThreeLine: lines.length > 2,
        onTap: widget.canEdit ? () => widget.onEdit(m) : null,
        trailing: widget.canEdit
            ? IconButton(
                tooltip: l10n.trainingMeasureDeleteTooltip,
                icon: Icon(Icons.delete_outline, color: cs.error),
                onPressed: () => widget.onDelete(m),
              )
            : null,
      ),
    );
  }
}

/// "At −0.4 kg/week you'll reach 78 kg around 12 Jan", or what to say when
/// there's no data, the trend is flat, going the wrong way or already there.
String goalEtaText(BuildContext context, GoalEta eta, {required double goalKg, required double? rateKg}) {
  final l10n = context.l10n;
  final s = SettingsService.instance;
  final locale = Localizations.localeOf(context).toString();
  final goal = s.formatWeight(goalKg);
  final rate = rateKg == null ? '' : '${rateKg < 0 ? '−' : '+'}${s.formatWeight(rateKg.abs(), decimals: 2)}';
  return switch (eta.kind) {
    GoalEtaKind.noData => l10n.bodyGoalEtaNoData(goal),
    GoalEtaKind.reached => l10n.bodyGoalEtaReached(goal),
    GoalEtaKind.flat => l10n.bodyGoalEtaFlat(goal),
    GoalEtaKind.wrongWay => l10n.bodyGoalEtaWrongWay(rate, goal),
    GoalEtaKind.tooFar => l10n.bodyGoalEtaTooFar(rate, goal),
    GoalEtaKind.onTrack => l10n.bodyGoalEtaOnTrack(
      rate,
      goal,
      (eta.date!.year == DateTime.now().year ? DateFormat.MMMd(locale) : DateFormat.yMMMd(locale)).format(eta.date!),
    ),
  };
}
