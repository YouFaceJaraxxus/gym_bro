import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/progress.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/settings_service.dart';
import '../session_detail_page.dart';
import 'progress_chart.dart';
import 'progress_format.dart';

enum _Metric { e1rm, weight, volume }

enum _Range {
  m1(30),
  m3(91),
  m6(182),
  all(null);

  final int? days;
  const _Range(this.days);

  String label(AppLocalizations l10n) => switch (this) {
    _Range.m1 => l10n.trainingProgressRange1m,
    _Range.m3 => l10n.trainingProgressRange3m,
    _Range.m6 => l10n.trainingProgressRange6m,
    _Range.all => l10n.trainingProgressRangeAll,
  };
}

/// One exercise's history: chart (e1RM / best weight / volume over a range),
/// all-time records and the per-session list.
class ExerciseProgressPage extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;

  /// Whose progress; null = me.
  final String? userId;

  const ExerciseProgressPage({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    this.userId,
  });

  @override
  State<ExerciseProgressPage> createState() => _ExerciseProgressPageState();
}

class _ExerciseProgressPageState extends State<ExerciseProgressPage> {
  final _api = ApiService();
  final _settings = SettingsService.instance;
  ExerciseProgressDetail? _detail;
  bool _loading = true;
  String? _error;
  _Metric _metric = _Metric.e1rm;
  _Range _range = _Range.m3;

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
      final days = _range.days;
      final detail = await _api.getExerciseProgress(
        token,
        widget.exerciseId,
        userId: widget.userId,
        from: days == null ? null : DateTime.now().subtract(Duration(days: days)),
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        // Bodyweight / timed exercises have no e1RM; fall back to volume or reps.
        if (_metric == _Metric.e1rm && detail.bestE1rm == null) {
          _metric = detail.bestWeight != null ? _Metric.weight : _Metric.volume;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _setRange(_Range r) {
    if (r == _range) return;
    setState(() => _range = r);
    _load();
  }

  double? _metricValue(ExerciseSeriesPoint p) => switch (_metric) {
    _Metric.e1rm => p.bestE1rm,
    _Metric.weight => p.bestWeightKg,
    _Metric.volume => p.volumeKg > 0 ? p.volumeKg : null,
  };

  void _openSession(String sessionId) {
    if (sessionId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: sessionId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: _settings.weightUnit,
      builder: (context, _, _) => Scaffold(
        appBar: AppBar(title: Text(_detail?.exerciseName ?? widget.exerciseName)),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    if (_loading && _detail == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _detail == null) {
      return ProgressErrorView(message: _error!, onRetry: _load);
    }
    final d = _detail!;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final points = <ProgressChartPoint>[
      for (final p in d.series)
        if (_metricValue(p) != null)
          ProgressChartPoint(p.date.toLocal(), _settings.toDisplayWeight(_metricValue(p)!)),
    ];
    final unit = _settings.weightUnit.value;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (d.primaryMuscles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                muscleLabels(d.primaryMuscles, l10n),
                style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          SegmentedButton<_Metric>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: _Metric.e1rm, label: Text(l10n.trainingProgressMetricE1rm)),
              ButtonSegment(value: _Metric.weight, label: Text(l10n.trainingProgressMetricWeight)),
              ButtonSegment(value: _Metric.volume, label: Text(l10n.trainingProgressMetricVolume)),
            ],
            selected: {_metric},
            onSelectionChanged: (s) => setState(() => _metric = s.first),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(switch (_metric) {
                            _Metric.e1rm => l10n.trainingProgressChartE1rm(unit),
                            _Metric.weight => l10n.trainingProgressChartWeight(unit),
                            _Metric.volume => l10n.trainingProgressChartVolume(unit),
                          }, style: text.titleSmall),
                        ),
                        if (_loading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ProgressLineChart(
                    points: points,
                    seriesLabel: switch (_metric) {
                      _Metric.e1rm => l10n.trainingProgressSeriesE1rm,
                      _Metric.weight => l10n.trainingProgressSeriesWeight,
                      _Metric.volume => l10n.trainingProgressSeriesVolume,
                    },
                    formatValue: (y) => _metric == _Metric.volume
                        ? '${NumberFormat.decimalPattern(locale).format(y.round())} $unit'
                        : '${NumberFormat('0.0', locale).format(y)} $unit',
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final r in _Range.values)
                        ChoiceChip(
                          label: Text(r.label(l10n)),
                          selected: _range == r,
                          onSelected: (_) => _setRange(r),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.trainingProgressPersonalRecords, style: text.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PrCard(
                  icon: Icons.trending_up,
                  label: l10n.trainingProgressBestE1rm,
                  record: d.bestE1rm,
                  format: (v) => _settings.formatWeight(v),
                  onTap: _openSession,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PrCard(
                  icon: Icons.fitness_center,
                  label: l10n.trainingProgressHeaviest,
                  record: d.bestWeight,
                  format: (v) => _settings.formatWeight(v),
                  onTap: _openSession,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PrCard(
                  icon: Icons.stacked_bar_chart,
                  label: l10n.trainingProgressBestVolume,
                  record: d.bestVolume,
                  format: (v) => formatVolume(v, locale),
                  onTap: _openSession,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _range == _Range.all
                ? l10n.trainingProgressSessionsHeading
                : l10n.trainingProgressSessionsInRange(_range.label(l10n)),
            style: text.titleMedium,
          ),
          const SizedBox(height: 8),
          if (d.series.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  l10n.trainingProgressNoSessionsInRange,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            ...d.series.reversed.map(
              (p) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(DateFormat.yMMMEd(locale).format(p.date.toLocal())),
                  subtitle: Text(
                    [
                      if (p.bestWeightKg != null)
                        l10n.trainingProgressTopWeight(_settings.formatWeight(p.bestWeightKg!)),
                      if (p.bestE1rm != null)
                        l10n.trainingProgressE1rm(_settings.formatWeight(p.bestE1rm!)),
                      if (p.totalReps > 0) l10n.trainingProgressRepsCount(p.totalReps),
                      if (p.volumeKg > 0) formatVolume(p.volumeKg, locale),
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openSession(p.sessionId),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final ExerciseRecord? record;
  final String Function(double) format;
  final ValueChanged<String> onTap;

  const _PrCard({
    required this.icon,
    required this.label,
    required this.record,
    required this.format,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = record;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    return MergeSemantics(
      child: Card(
        elevation: 0,
        color: r == null ? cs.surfaceContainerLow : cs.secondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: r == null ? null : () => onTap(r.sessionId),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: r == null ? cs.outline : cs.onSecondaryContainer),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: text.labelSmall?.copyWith(
                    color: r == null ? cs.onSurfaceVariant : cs.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    r == null ? '—' : format(r.value),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: r == null ? cs.onSurfaceVariant : cs.onSecondaryContainer,
                    ),
                  ),
                ),
                Text(
                  r == null
                      ? l10n.trainingProgressNoData
                      : DateFormat.yMMMd(locale).format(r.date.toLocal()),
                  style: text.labelSmall?.copyWith(
                    color: r == null ? cs.onSurfaceVariant : cs.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
