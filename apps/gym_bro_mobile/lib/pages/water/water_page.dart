import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/user_settings.dart';
import '../../models/water.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/settings_service.dart';
import '../../services/water_service.dart';
import '../../theme.dart';
import '../../utils/device_timezone.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/water_widgets.dart';

/// The water tracker: today's bottle and quick adds, today's drinks (swipe
/// to delete) and the last 14 or 30 days against the goal.
class WaterPage extends StatefulWidget {
  const WaterPage({super.key});

  @override
  State<WaterPage> createState() => _WaterPageState();
}

class _WaterPageState extends State<WaterPage> {
  final _api = ApiService();
  final _service = WaterService.instance;
  WaterHistory? _history;
  int _days = 14;
  bool _loading = true;
  String? _error;
  int _historyRequest = 0;

  @override
  void initState() {
    super.initState();
    waterChanges.addListener(_loadHistory);
    _load();
  }

  @override
  void dispose() {
    waterChanges.removeListener(_loadHistory);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _service.today.value == null;
      _error = null;
    });
    try {
      await Future.wait([_service.refresh(), _loadHistory()]);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_service.today.value == null) _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadHistory() async {
    final id = ++_historyRequest;
    try {
      final token = await AuthManager.instance.getValidToken();
      final h = await _api.getWaterHistory(token, days: _days, tz: await deviceTimezone());
      if (mounted && id == _historyRequest) setState(() => _history = h);
    } catch (_) {
      // The chart is extra; today's water still works.
    }
  }

  Future<void> _delete(WaterEntry e) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.remove(e.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.waterRemoved(waterAmount(l10n, e.ml)))));
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))));
    }
  }

  void _openSettings() {
    showAppBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ValueListenableBuilder<UserSettings>(
            valueListenable: SettingsService.instance.settings,
            builder: (ctx, s, _) => WaterSettingsCard(settings: s),
          ),
        ),
      ),
    ).then((_) => _loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.waterTitle),
        actions: [
          IconButton(
            tooltip: l10n.shellSettings,
            icon: const Icon(Icons.tune),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ValueListenableBuilder<WaterDay?>(
        valueListenable: _service.today,
        builder: (context, day, _) {
          if (day == null) {
            if (_loading) {
              return const Skeleton(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      SkeletonBox(height: 300, radius: 24),
                      SizedBox(height: 16),
                      SkeletonBox(height: 56, radius: 16),
                      SizedBox(height: 16),
                      SkeletonBox(height: 180, radius: 20),
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.waterLoadFailed, textAlign: TextAlign.center),
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.tonal(onPressed: _load, child: Text(l10n.commonRetry)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _TodayHero(day: day),
                const SizedBox(height: 20),
                const WaterQuickAdd(),
                const SizedBox(height: 28),
                _SectionHeader(l10n.waterTodayEntries),
                _Entries(day: day, onDelete: _delete),
                const SizedBox(height: 28),
                _SectionHeader(
                  l10n.waterHistory,
                  trailing: SegmentedButton<int>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      for (final d in const [14, 30]) ButtonSegment(value: d, label: Text(l10n.waterHistoryDays(d))),
                    ],
                    selected: {_days},
                    onSelectionChanged: (v) {
                      setState(() => _days = v.first);
                      _loadHistory();
                    },
                  ),
                ),
                if (_history != null) _HistoryCard(history: _history!),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The big bottle with the total, the goal and what's left.
class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.day});

  final WaterDay day;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final water = WaterColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [water.container, Color.lerp(water.container, cs.surface, 0.6)!],
        ),
      ),
      child: Row(
        children: [
          WaterBottle(
            fraction: day.fraction,
            percent: day.percent,
            width: 120,
            height: 196,
            semanticLabel: l10n.waterBottleSemantics(
              waterAmount(l10n, day.totalMl),
              waterAmount(l10n, day.goalMl),
              day.percent,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  waterAmount(l10n, day.totalMl),
                  style: AppText.stat(size: 46, weight: FontWeight.w800, color: water.onContainer),
                ),
                Text(
                  l10n.waterOfGoal(waterAmount(l10n, day.goalMl)),
                  style: text.titleMedium?.copyWith(color: water.onContainer.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 14),
                _Pill(
                  icon: day.reached ? Icons.emoji_events_outlined : Icons.flag_outlined,
                  label: day.reached ? l10n.waterGoalReached : l10n.waterLeft(waterAmount(l10n, day.remainingMl)),
                  color: day.reached ? context.appColors.success : water.water,
                ),
                if (day.workoutBonusMl > 0) ...[
                  const SizedBox(height: 8),
                  _Pill(
                    icon: Icons.fitness_center,
                    label: l10n.waterWorkoutBonus(waterAmount(l10n, day.workoutBonusMl)),
                    color: cs.tertiary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's drinks, newest first; swipe one away to delete it.
class _Entries extends StatelessWidget {
  const _Entries({required this.day, required this.onDelete});

  final WaterDay day;
  final Future<void> Function(WaterEntry) onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final water = WaterColors.of(context);
    if (day.entries.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.water_drop_outlined, color: water.water),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.waterNoEntries, style: TextStyle(color: cs.onSurfaceVariant))),
            ],
          ),
        ),
      );
    }
    final time = DateFormat.Hm(Localizations.localeOf(context).toString());
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, e) in day.entries.indexed) ...[
            if (i > 0) const Divider(indent: 64),
            Dismissible(
              key: ValueKey(e.id),
              direction: e.id.startsWith('pending-') ? DismissDirection.none : DismissDirection.endToStart,
              background: Container(
                color: cs.errorContainer,
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsetsDirectional.only(end: 20),
                child: Icon(Icons.delete_outline, color: cs.onErrorContainer, semanticLabel: l10n.commonDelete),
              ),
              onDismissed: (_) => onDelete(e),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: water.container,
                  foregroundColor: water.water,
                  child: Icon(e.ml >= 700 ? Icons.water_outlined : Icons.local_drink_outlined, size: 20),
                ),
                title: Text(
                  waterAmount(l10n, e.ml),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                ),
                trailing: Text(time.format(e.loggedAt), style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bars per day (filled to the total, over a faint bar to the day's goal),
/// with the average, days at the goal and the current run.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});

  final WaterHistory history;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final water = WaterColors.of(context);
    final days = history.days;
    final locale = Localizations.localeOf(context).toString();
    final peak = history.peakMl * 1.08;
    final step = peak > 4000 ? 1000.0 : 500.0;
    final maxY = (peak / step).ceil() * step;
    final barWidth = days.length > 20 ? 6.0 : 12.0;
    final labelEvery = days.length > 20 ? 7 : 3;
    final calm = MediaQuery.disableAnimationsOf(context);

    Widget stat(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                stat(l10n.waterAverage, waterAmount(l10n, history.averageMl)),
                stat(l10n.waterDaysReached, l10n.waterDaysReachedValue(history.daysReached, days.length)),
                stat(l10n.waterStreak, l10n.waterStreakValue(history.streak)),
              ],
            ),
            const SizedBox(height: 20),
            Semantics(
              label: l10n.waterChartSemantics(days.length, history.daysReached),
              excludeSemantics: true,
              child: SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    minY: 0,
                    maxY: maxY,
                    alignment: BarChartAlignment.spaceAround,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: step,
                      getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
                    ),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: history.baseGoalMl.toDouble(),
                          color: water.deep.withValues(alpha: 0.7),
                          strokeWidth: 1.5,
                          dashArray: [6, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: text.labelSmall?.copyWith(color: water.deep, fontWeight: FontWeight.w700),
                            labelResolver: (_) => l10n.waterGoalLine,
                          ),
                        ),
                      ],
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => cs.inverseSurface,
                        getTooltipItem: (group, _, rod, _) {
                          final d = days[group.x];
                          return BarTooltipItem(
                            '${DateFormat.MMMEd(locale).format(d.date)}\n'
                            '${l10n.waterProgress(waterAmount(l10n, d.totalMl), waterAmount(l10n, d.goalMl))}',
                            TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.w600, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: maxY > 2000 ? 1000 : step,
                          getTitlesWidget: (v, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(
                              v == 0 ? '0' : waterAmount(l10n, v.round()),
                              style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (v, meta) {
                            final i = v.toInt();
                            final fromEnd = days.length - 1 - i;
                            if (i < 0 || i >= days.length || fromEnd % labelEvery != 0) return const SizedBox.shrink();
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                DateFormat.Md(locale).format(days[i].date),
                                style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < days.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: math.min(days[i].totalMl.toDouble(), maxY),
                              width: barWidth,
                              color: days[i].reached ? water.water : water.water.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(barWidth / 2),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: days[i].goalMl.toDouble(),
                                color: water.container,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  duration: calm ? Duration.zero : const Duration(milliseconds: 400),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
