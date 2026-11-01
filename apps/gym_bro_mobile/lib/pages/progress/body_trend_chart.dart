import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../utils/weight_trend.dart';
import 'progress_chart.dart';

/// Body-weight chart: raw weigh-ins as faint dots, the smoothed trend as a
/// bold line and an optional dashed goal line. Values are display units.
/// Draws itself in left to right (instantly with reduced motion).
class BodyTrendChart extends StatelessWidget {
  final List<TrendPoint> raw;
  final List<TrendPoint> trend;
  final double? goal;
  final String Function(double y) formatValue;
  final double height;

  const BodyTrendChart({
    super.key,
    required this.raw,
    required this.trend,
    required this.formatValue,
    this.goal,
    this.height = 220,
  });

  static double _dayX(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch / Duration.millisecondsPerDay;

  static DateTime _xDate(double x) {
    final d = DateTime.fromMillisecondsSinceEpoch((x * Duration.millisecondsPerDay).round(), isUtc: true);
    return DateTime(d.year, d.month, d.day);
  }

  /// Whether the goal is close enough to the data to share its y-axis.
  static bool goalFits(double goal, double lo, double hi) {
    final span = math.max(hi - lo, 2.0);
    return goal >= lo - span * 1.5 && goal <= hi + span * 1.5;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (raw.isEmpty || trend.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(child: Text(l10n.trainingChartNoData, style: TextStyle(color: cs.onSurfaceVariant))),
      );
    }

    final rawSpots = [for (final p in raw) FlSpot(_dayX(p.date), p.value)]..sort((a, b) => a.x.compareTo(b.x));
    final trendSpots = [for (final p in trend) FlSpot(_dayX(p.date), p.value)]..sort((a, b) => a.x.compareTo(b.x));

    var minX = math.min(rawSpots.first.x, trendSpots.first.x);
    var maxX = math.max(rawSpots.last.x, trendSpots.last.x);
    if (maxX - minX < 1) {
      minX -= 3;
      maxX += 3;
    }
    final ys = [...rawSpots.map((s) => s.y), ...trendSpots.map((s) => s.y)];
    var lo = ys.reduce(math.min);
    var hi = ys.reduce(math.max);
    final showGoal = goal != null && goalFits(goal!, lo, hi);
    if (showGoal) {
      lo = math.min(lo, goal!);
      hi = math.max(hi, goal!);
    }
    // At least ±0.5 so a nearly flat stretch doesn't look like a cliff.
    final pad = math.max((hi - lo) * 0.15, 0.5);
    final minY = math.max(0.0, lo - pad);
    final maxY = hi + pad;
    final yInterval = ProgressLineChart.niceInterval((maxY - minY) / 4);
    final xSpan = maxX - minX;
    final xInterval = math.max(1.0, xSpan / 3);
    final dateFmt = xSpan > 300 ? DateFormat.yMMM(locale) : DateFormat.MMMd(locale);
    final lastTrend = trendSpots.last;
    final dotColor = cs.primary.withValues(alpha: dark ? 0.45 : 0.35);
    final goalColor = cs.tertiary;

    LineChartData data(double t) {
      final cut = minX + (maxX - minX) * t;
      return LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        lineBarsData: [
          // 0: raw weigh-ins — dots only.
          LineChartBarData(
            spots: [for (final s in rawSpots) if (s.x <= cut) s],
            color: Colors.transparent,
            barWidth: 0,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(radius: 3, color: dotColor, strokeWidth: 0, strokeColor: Colors.transparent),
            ),
          ),
          // 1: the trend.
          LineChartBarData(
            spots: revealSpots(trendSpots, cut),
            isCurved: trendSpots.length > 2,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: cs.primary,
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, bar) => t >= 1 && spot == lastTrend,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(radius: 5, color: cs.primary, strokeWidth: 2.5, strokeColor: cs.surfaceContainerLow),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [cs.primary.withValues(alpha: dark ? 0.26 : 0.18), cs.primary.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (showGoal)
              HorizontalLine(
                y: goal!,
                color: goalColor.withValues(alpha: 0.9),
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 4, bottom: 2),
                  style: text.labelSmall?.copyWith(color: goalColor, fontWeight: FontWeight.w700),
                  labelResolver: (_) => l10n.bodyGoalLineLabel(formatValue(goal!)),
                ),
              ),
          ],
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: cs.outlineVariant.withValues(alpha: dark ? 0.35 : 0.5), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    NumberFormat(yInterval < 1 ? '0.0' : '0', locale).format(value),
                    style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: xInterval,
              getTitlesWidget: (value, meta) => crowdsAxisEdge(value, meta.min, meta.max, xInterval)
                  ? const SizedBox.shrink()
                  : SideTitleWidget(
                      meta: meta,
                      fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
                      child: Text(
                        dateFmt.format(_xDate(value)),
                        style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: t >= 1,
          handleBuiltInTouches: true,
          touchSpotThreshold: 16,
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                bar.barWidth == 0
                    ? const FlLine(color: Colors.transparent, strokeWidth: 0)
                    : FlLine(color: cs.outline, strokeWidth: 1, dashArray: [4, 4]),
                FlDotData(
                  getDotPainter: (spot, percent, b, index) => FlDotCirclePainter(
                    radius: b.barWidth == 0 ? 4 : 5.5,
                    color: b.barWidth == 0 ? cs.primary.withValues(alpha: 0.7) : cs.primary,
                    strokeWidth: 2,
                    strokeColor: cs.surface,
                  ),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            tooltipBorderRadius: BorderRadius.circular(10),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touched) {
              final items = <LineTooltipItem?>[];
              for (final s in touched) {
                final isTrend = s.barIndex == 1;
                final isLast = identical(s, touched.last);
                items.add(
                  LineTooltipItem(
                    isTrend ? l10n.bodyTooltipTrend(formatValue(s.y)) : l10n.bodyTooltipWeighIn(formatValue(s.y)),
                    TextStyle(
                      color: cs.onInverseSurface,
                      fontWeight: isTrend ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    children: [
                      if (isLast)
                        TextSpan(
                          text: '\n${DateFormat.yMMMd(locale).format(_xDate(s.x))}',
                          style: TextStyle(
                            color: cs.onInverseSurface.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                );
              }
              return items;
            },
          ),
        ),
      );
    }

    final summary = l10n.trainingChartSummary(l10n.bodyTrendSeries, formatValue(lastTrend.y), raw.length);
    return Semantics(
      label: summary,
      container: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(right: 12, top: 8),
            child: ChartDrawIn(
              replayKey: Object.hashAll([minX, maxX, rawSpots.length, lastTrend.y]),
              builder: (context, t) => LineChart(
                data(t),
                duration: t < 1 ? Duration.zero : kChartUpdateDuration,
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small key under the weight chart: weigh-ins, trend and (optional) goal.
class BodyTrendLegend extends StatelessWidget {
  final bool showGoal;

  const BodyTrendLegend({super.key, required this.showGoal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final style = text.labelSmall?.copyWith(color: cs.onSurfaceVariant);
    Widget item(Widget mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [mark, const SizedBox(width: 6), Text(label, style: style)],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        item(
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.4), shape: BoxShape.circle),
          ),
          l10n.bodyLegendWeighIns,
        ),
        item(
          Container(
            width: 16,
            height: 3.5,
            decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(2)),
          ),
          l10n.bodyLegendTrend,
        ),
        if (showGoal)
          item(
            SizedBox(
              width: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 3; i++) Container(width: 4, height: 1.5, color: cs.tertiary),
                ],
              ),
            ),
            l10n.bodyLegendGoal,
          ),
      ],
    );
  }
}
