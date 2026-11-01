import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';

/// One point on a progress chart. [y] is already in display units.
class ProgressChartPoint {
  final DateTime date;
  final double y;
  const ProgressChartPoint(this.date, this.y);
}

/// How long a chart takes to draw itself in.
const kChartDrawInDuration = Duration(milliseconds: 900);

/// How fl_chart animates later changes to a drawn chart (e.g. kg ↔ lb).
const kChartUpdateDuration = Duration(milliseconds: 250);

/// The spots of [spots] (sorted by x) up to [cutX], ending with a point
/// interpolated at [cutX], so a line grows from left to right. Never empty
/// for non-empty input.
List<FlSpot> revealSpots(List<FlSpot> spots, double cutX) {
  if (spots.isEmpty || cutX >= spots.last.x) return spots;
  final out = <FlSpot>[];
  for (var i = 0; i < spots.length; i++) {
    final s = spots[i];
    if (s.x <= cutX) {
      out.add(s);
      continue;
    }
    if (i > 0) {
      final p = spots[i - 1];
      final f = (cutX - p.x) / (s.x - p.x);
      out.add(FlSpot(cutX, p.y + (s.y - p.y) * f));
    }
    break;
  }
  return out.isEmpty ? [spots.first] : out;
}

/// Whether an interval label on the date axis sits so close to the first or
/// last label (fl_chart always draws both edges) that they would overlap.
bool crowdsAxisEdge(double value, double min, double max, double interval) {
  if (value == min || value == max) return false;
  return value - min < interval * 0.5 || max - value < interval * 0.5;
}

/// Plays a 0 → 1 draw-in progress once (ease-out), handing it to [builder].
/// Changing [replayKey] plays it again. With reduced motion the chart is
/// drawn complete straight away.
class ChartDrawIn extends StatelessWidget {
  final Object? replayKey;
  final Duration duration;
  final Widget Function(BuildContext context, double t) builder;

  const ChartDrawIn({
    super.key,
    this.replayKey,
    this.duration = kChartDrawInDuration,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return builder(context, 1);
    return TweenAnimationBuilder<double>(
      key: ValueKey(replayKey),
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => builder(context, t),
    );
  }
}

/// Single-series time chart: 2px line, soft area fill, faint horizontal grid,
/// the latest point highlighted, touch tooltips with date + value.
class ProgressLineChart extends StatelessWidget {
  final List<ProgressChartPoint> points;

  /// Formats a y value for tooltips (e.g. "102.5 kg").
  final String Function(double y) formatValue;

  /// Formats a y value for the axis (short).
  final String Function(double y)? formatAxis;
  final double height;

  /// Series name for the screen-reader summary, e.g. "Estimated 1RM".
  final String? seriesLabel;

  const ProgressLineChart({
    super.key,
    required this.points,
    required this.formatValue,
    this.formatAxis,
    this.height = 220,
    this.seriesLabel,
  });

  static double _dayX(DateTime d) => d.millisecondsSinceEpoch / Duration.millisecondsPerDay;

  static DateTime _xDate(double x) =>
      DateTime.fromMillisecondsSinceEpoch((x * Duration.millisecondsPerDay).round());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(l10n.trainingChartNoData, style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }

    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));
    final spots = [for (final p in sorted) FlSpot(_dayX(p.date), p.y)];

    var minX = spots.first.x;
    var maxX = spots.last.x;
    if (maxX - minX < 1) {
      minX -= 3;
      maxX += 3;
    }
    final ys = spots.map((s) => s.y);
    var minY = ys.reduce(math.min);
    var maxY = ys.reduce(math.max);
    final pad = (maxY - minY).abs() < 1e-9 ? math.max(1.0, maxY.abs() * 0.1) : (maxY - minY) * 0.15;
    minY = math.max(0, minY - pad);
    maxY = maxY + pad;
    final yInterval = _niceInterval((maxY - minY) / 4);
    final xSpan = maxX - minX;
    final xInterval = math.max(1.0, xSpan / 3);
    final dateFmt = xSpan > 300 ? DateFormat.yMMM(locale) : DateFormat.MMMd(locale);
    final axisFmt = formatAxis ?? (double v) => NumberFormat(yInterval < 1 ? '0.#' : '0', locale).format(v);
    final last = spots.last;

    LineChartBarData bar(double t) => LineChartBarData(
      spots: revealSpots(spots, minX + (maxX - minX) * t),
      isCurved: spots.length > 2,
      curveSmoothness: 0.2,
      preventCurveOverShooting: true,
      color: cs.primary,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, data) => t >= 1 && spot == last,
        getDotPainter: (spot, percent, data, index) => FlDotCirclePainter(
          radius: 5,
          color: cs.primary,
          strokeWidth: 2,
          strokeColor: cs.surface,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.primary.withValues(alpha: 0.22), cs.primary.withValues(alpha: 0.02)],
        ),
      ),
    );

    final summary = l10n.trainingChartSummary(
      seriesLabel ?? l10n.trainingChartDefaultSeries,
      formatValue(sorted.last.y),
      sorted.length,
    );

    return Semantics(
      label: summary,
      container: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(right: 12, top: 8),
            child: ChartDrawIn(
              replayKey: Object.hashAll([for (final s in spots) ...[s.x, s.y]]),
              builder: (context, t) => LineChart(
                duration: t < 1 ? Duration.zero : kChartUpdateDuration,
                curve: Curves.easeOutCubic,
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [bar(t)],
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yInterval,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: cs.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: yInterval,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              axisFmt(value),
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
                        getTitlesWidget: (value, meta) {
                          if (crowdsAxisEdge(value, meta.min, meta.max, xInterval)) return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            fitInside: SideTitleFitInsideData.fromTitleMeta(
                              meta,
                              distanceFromEdge: 0,
                            ),
                            child: Text(
                              dateFmt.format(_xDate(value)),
                              style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: t >= 1,
                    handleBuiltInTouches: true,
                    getTouchedSpotIndicator: (data, indexes) => [
                      for (final _ in indexes)
                        TouchedSpotIndicatorData(
                          FlLine(color: cs.outline, strokeWidth: 1, dashArray: [4, 4]),
                          FlDotData(
                            getDotPainter: (spot, percent, data, index) => FlDotCirclePainter(
                              radius: 5,
                              color: cs.primary,
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
                      getTooltipItems: (touched) => [
                        for (final s in touched)
                          LineTooltipItem(
                            '${formatValue(s.y)}\n',
                            TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.w700),
                            children: [
                              TextSpan(
                                text: DateFormat.yMMMd(locale).format(_xDate(s.x)),
                                style: TextStyle(
                                  color: cs.onInverseSurface.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 1, 2, 2.5, 5 × 10^n closest above [raw].
  static double niceInterval(double raw) => _niceInterval(raw);

  static double _niceInterval(double raw) {
    if (raw <= 0 || raw.isNaN) return 1;
    final exp = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    for (final m in [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (raw <= m * exp) return m * exp;
    }
    return 10 * exp;
  }
}
