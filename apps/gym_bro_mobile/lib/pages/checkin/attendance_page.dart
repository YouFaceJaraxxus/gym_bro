import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/check_in.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'check_in_scanner_page.dart';
import 'check_in_widgets.dart';

/// Staff view of a gym's attendance: a day's check-ins, the last 30 days,
/// busiest hours and the most frequent members.
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key, required this.gymId, required this.gymName});

  final String gymId;
  final String gymName;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  static const _days = 30;

  final _api = ApiService();

  GymAttendanceStats? _stats;
  bool _statsLoading = true;
  String? _statsError;

  late DateTime _day = _today();
  List<CheckIn> _dayList = [];
  bool _dayLoading = true;
  String? _dayError;
  int _dayRequest = 0;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isToday => _day == _today();

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadDay();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _loadStats() async {
    setState(() {
      _statsLoading = _stats == null;
      _statsError = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final s = await _api.getGymCheckInStats(token, widget.gymId, days: _days);
      if (mounted) {
        setState(() {
          _stats = s;
          _statsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statsError = _msg(e);
          _statsLoading = false;
        });
      }
    }
  }

  Future<void> _loadDay() async {
    final request = ++_dayRequest;
    setState(() {
      _dayLoading = true;
      _dayError = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await _api.getGymCheckIns(token, widget.gymId, date: _day);
      if (!mounted || request != _dayRequest) return;
      setState(() {
        _dayList = rows;
        _dayLoading = false;
      });
    } catch (e) {
      if (!mounted || request != _dayRequest) return;
      setState(() {
        _dayError = _msg(e);
        _dayLoading = false;
      });
    }
  }

  Future<void> _refresh() => Future.wait([_loadStats(), _loadDay()]);

  void _setDay(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    if (day.isAfter(_today()) || day == _day) return;
    setState(() => _day = day);
    _loadDay();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: _today(),
      helpText: context.l10n.businessCheckInPickDayHelp,
    );
    if (picked != null) _setDay(picked);
  }

  Future<void> _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CheckInScannerPage(gymId: widget.gymId, gymName: widget.gymName),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.businessCheckInAttendanceTitle),
            Text(widget.gymName, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.businessCheckInScanTooltip,
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _openScanner,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ..._buildStatsSection(),
            const SizedBox(height: 24),
            ..._buildDaySection(),
          ],
        ),
      ),
    );
  }

  // ── Stats ───────────────────────────────────────────────────────────────────

  List<Widget> _buildStatsSection() {
    if (_statsLoading) {
      return const [
        SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_statsError != null) {
      return [CheckInErrorState(message: _statsError!, onRetry: _loadStats)];
    }
    final l10n = context.l10n;
    final s = _stats!;
    final avg = s.averagePerDay;
    final avgDigits = avg >= 10 ? 0 : 1;
    final avgText =
        (NumberFormat.decimalPattern(Localizations.localeOf(context).toString())
              ..minimumFractionDigits = avgDigits
              ..maximumFractionDigits = avgDigits)
            .format(avg);
    final peaks = s.peakHours().map(hourRangeLabel).join(', ');
    return [
      Row(
        children: [
          Expanded(
            child: StatTile(
              icon: Icons.today,
              label: l10n.commonToday,
              value: '${s.today}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              icon: Icons.date_range,
              label: l10n.businessCheckInThisWeek,
              value: '${s.thisWeek}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              icon: Icons.people_outline,
              label: l10n.businessCheckInMembersInDays(s.days),
              value: '${s.uniqueMembers}',
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _ChartCard(
        title: l10n.businessCheckInLastDays(s.days),
        subtitle: l10n.businessCheckInTotalPerDay(s.total, avgText),
        child: s.total == 0
            ? _NoData(message: l10n.businessCheckInNoCheckInsInPeriod)
            : Semantics(
                container: true,
                label: l10n.businessCheckInDailyChartSemantics(
                  s.days,
                  s.total,
                  avgText,
                ),
                child: ExcludeSemantics(
                  child: _DailyChart(perDay: s.perDay, onTapDay: _setDay),
                ),
              ),
      ),
      const SizedBox(height: 16),
      _ChartCard(
        title: l10n.businessCheckInBusiestHours,
        subtitle: peaks.isEmpty
            ? l10n.businessCheckInLastDays(s.days)
            : l10n.businessCheckInPeak(peaks),
        child: s.total == 0
            ? _NoData(message: l10n.businessCheckInNotEnoughData)
            : Semantics(
                container: true,
                label: l10n.businessCheckInHourlyChartSemantics(peaks),
                child: ExcludeSemantics(
                  child: _HourlyChart(hours: s.busiestHours),
                ),
              ),
      ),
      const SizedBox(height: 16),
      _buildTopMembers(s),
    ];
  }

  Widget _buildTopMembers(GymAttendanceStats s) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.l10n.businessCheckInTopMembers,
                style: tt.titleMedium,
              ),
            ),
            if (s.topMembers.isEmpty)
              _NoData(message: context.l10n.businessCheckInNoVisitsInPeriod)
            else
              for (var i = 0; i < s.topMembers.length; i++)
                MergeSemantics(
                  child: ListTile(
                    leading: PersonAvatar(
                      initials: s.topMembers[i].person.initials,
                      url: s.topMembers[i].person.avatarUrl,
                    ),
                    title: Text(s.topMembers[i].person.fullName),
                    subtitle: s.topMembers[i].lastCheckInAt == null
                        ? null
                        : Text(
                            context.l10n.businessCheckInLastVisit(
                              formatDay(
                                context,
                                s.topMembers[i].lastCheckInAt!,
                              ).toLowerCase(),
                            ),
                          ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${s.topMembers[i].visits}',
                          style: tt.titleMedium?.copyWith(color: cs.primary),
                        ),
                        Text(
                          context.l10n.businessCheckInVisitsUnit(
                            s.topMembers[i].visits,
                          ),
                          style: tt.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // ── Day list ────────────────────────────────────────────────────────────────

  List<Widget> _buildDaySection() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final header = Row(
      children: [
        Expanded(
          child: Text(
            _dayLoading
                ? l10n.businessCheckInCheckIns
                : l10n.businessCheckInCount(_dayList.length),
            style: tt.titleMedium,
          ),
        ),
        IconButton(
          tooltip: l10n.businessCheckInPreviousDay,
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _setDay(_day.subtract(const Duration(days: 1))),
        ),
        TextButton.icon(
          onPressed: _pickDay,
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(formatDay(context, _day)),
        ),
        IconButton(
          tooltip: l10n.businessCheckInNextDay,
          icon: const Icon(Icons.chevron_right),
          onPressed: _isToday
              ? null
              : () => _setDay(_day.add(const Duration(days: 1))),
        ),
      ],
    );

    if (_dayLoading && _dayList.isEmpty) {
      return [
        header,
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_dayError != null) {
      return [
        header,
        CheckInErrorState(message: _dayError!, onRetry: _loadDay),
      ];
    }
    if (_dayList.isEmpty) {
      return [
        header,
        CheckInEmptyState(
          icon: Icons.event_busy,
          title: _isToday
              ? l10n.businessCheckInNoneToday
              : l10n.businessCheckInNoneOnDay,
          message: _isToday ? l10n.businessCheckInScanHint : null,
          action: _isToday
              ? FilledButton.icon(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l10n.businessCheckInOpenScanner),
                )
              : null,
        ),
      ];
    }
    return [
      header,
      if (_dayLoading) const LinearProgressIndicator(minHeight: 2),
      Card(
        margin: const EdgeInsets.only(top: 4),
        elevation: 0,
        color: cs.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < _dayList.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 72),
              MergeSemantics(
                child: ListTile(
                  leading: PersonAvatar(
                    initials: _initials(_dayList[i]),
                    url: _dayList[i].avatarUrl,
                  ),
                  title: Text(
                    _dayList[i].memberName.isEmpty
                        ? l10n.businessCheckInMemberFallback
                        : _dayList[i].memberName,
                  ),
                  subtitle: Text(
                    _dayList[i].isManual
                        ? l10n.businessCheckInManual
                        : l10n.businessCheckInQrScan,
                  ),
                  trailing: Text(
                    formatTime(context, _dayList[i].checkedInAt),
                    style: tt.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  String _initials(CheckIn c) {
    final n = c.name ?? '';
    final l = c.lastName ?? '';
    final s = '${n.isNotEmpty ? n[0] : ''}${l.isNotEmpty ? l[0] : ''}'
        .toUpperCase();
    return s.isEmpty ? '?' : s;
  }
}

// ── Chart widgets ─────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: tt.titleMedium),
            Text(
              subtitle,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 180, child: child),
          ],
        ),
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.insights_outlined, color: cs.outline),
            ),
            const SizedBox(height: 6),
            Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

BarTouchData _touchData(
  BuildContext context,
  String Function(int index, int value) label,
) {
  final cs = Theme.of(context).colorScheme;
  return BarTouchData(
    touchTooltipData: BarTouchTooltipData(
      getTooltipColor: (_) => cs.inverseSurface,
      fitInsideHorizontally: true,
      fitInsideVertically: true,
      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
        label(group.x, rod.toY.round()),
        TextStyle(
          color: cs.onInverseSurface,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    ),
  );
}

FlGridData _grid(BuildContext context, double step) {
  final cs = Theme.of(context).colorScheme;
  return FlGridData(
    drawVerticalLine: false,
    horizontalInterval: step,
    getDrawingHorizontalLine: (_) =>
        FlLine(color: cs.outlineVariant.withValues(alpha: 0.6), strokeWidth: 1),
  );
}

AxisTitles _countAxis(BuildContext context, double step) => AxisTitles(
  sideTitles: SideTitles(
    showTitles: true,
    reservedSize: 28,
    interval: step,
    getTitlesWidget: (value, meta) {
      if (value != value.roundToDouble()) return const SizedBox.shrink();
      return SideTitleWidget(
        meta: meta,
        child: Text(
          value.toInt().toString(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
    },
  ),
);

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.perDay, required this.onTapDay});
  final List<DayCount> perDay;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final maxCount = perDay.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    final step = niceAxisStep(maxCount).toDouble();
    final labelEvery = perDay.length > 14 ? 7 : (perDay.length > 7 ? 2 : 1);
    final barWidth = perDay.length > 20 ? 6.0 : 12.0;

    return BarChart(
      BarChartData(
        maxY: (maxCount / step).ceil() * step,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: _grid(context, step),
        barTouchData:
            _touchData(
              context,
              (i, v) =>
                  '${DateFormat.MMMEd(locale).format(perDay[i].date)}\n${l10n.businessCheckInCount(v)}',
            ).copyWith(
              touchCallback: (event, response) {
                final spot = response?.spot;
                if (event is FlTapUpEvent && spot != null) {
                  onTapDay(perDay[spot.touchedBarGroupIndex].date);
                }
              },
            ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: _countAxis(context, step),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                final fromEnd = perDay.length - 1 - i;
                if (i < 0 || i >= perDay.length || fromEnd % labelEvery != 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    DateFormat.Md(locale).format(perDay[i].date),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < perDay.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: perDay[i].count.toDouble(),
                  width: barWidth,
                  color: i == perDay.length - 1 ? cs.tertiary : cs.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.hours});
  final List<int> hours;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Trim quiet hours at both ends (keeping at least 06–22) to give bars room.
    var first = hours.indexWhere((c) => c > 0);
    var last = hours.lastIndexWhere((c) => c > 0);
    first = first < 0 ? 6 : (first < 6 ? first : 6);
    last = last < 0 ? 22 : (last > 22 ? last : 22);
    final range = [for (var h = first; h <= last; h++) h];
    final maxCount = hours.fold<int>(0, (m, c) => c > m ? c : m);
    final step = niceAxisStep(maxCount).toDouble();
    final peak = maxCount == 0 ? -1 : hours.indexOf(maxCount);

    return BarChart(
      BarChartData(
        maxY: (maxCount / step).ceil() * step,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: _grid(context, step),
        barTouchData: _touchData(
          context,
          (h, v) =>
              '${hourRangeLabel(h)}\n${context.l10n.businessCheckInCount(v)}',
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: _countAxis(context, step),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final h = value.toInt();
                if (h % 3 != 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    h.toString().padLeft(2, '0'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (final h in range)
            BarChartGroupData(
              x: h,
              barRods: [
                BarChartRodData(
                  toY: hours[h].toDouble(),
                  width: 8,
                  color: h == peak ? cs.tertiary : cs.secondary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
