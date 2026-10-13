import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/staff_shift.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'schedule_widgets.dart';

/// The caller's upcoming shifts across every gym, grouped by day.
class MyShiftsPage extends StatefulWidget {
  const MyShiftsPage({super.key});

  @override
  State<MyShiftsPage> createState() => _MyShiftsPageState();
}

class _MyShiftsPageState extends State<MyShiftsPage> {
  static const _days = 60;

  final _api = ApiService();
  List<StaffShift> _shifts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _shifts.isEmpty;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final now = DateTime.now();
      final shifts = await _api.getMyShifts(
        token,
        from: now,
        to: now.add(const Duration(days: _days)),
      );
      if (!mounted) return;
      setState(() {
        _shifts = shifts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.trainingShiftMyShifts)),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ScheduleError(message: _error!, onRetry: _load);
    final l10n = context.l10n;
    if (_shifts.isEmpty) {
      return ScheduleEmpty(
        icon: Icons.beach_access_outlined,
        title: l10n.trainingShiftNoUpcoming,
        message: l10n.trainingShiftNoUpcomingMessage,
      );
    }

    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final total = _shifts.fold<Duration>(Duration.zero, (a, s) => a + s.duration);
    final weekEnd = startOfWeek(DateTime.now()).add(const Duration(days: 7));
    final thisWeek = _shifts
        .where((s) => s.startsAt.isBefore(weekEnd))
        .fold<Duration>(Duration.zero, (a, s) => a + s.duration);
    final multipleGyms = _shifts.map((s) => s.gymId).toSet().length > 1;

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: _SummaryTile(
                label: l10n.trainingScheduleThisWeek,
                value: formatDuration(context, thisWeek),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryTile(
                label: l10n.trainingShiftNextDays(_days),
                value:
                    '${l10n.trainingShiftCount(_shifts.length)} · ${l10n.trainingScheduleHours(total.inHours)}',
              ),
            ),
          ],
        ),
      ),
    ];
    final groups = groupByDay(_shifts, (s) => s.startsAt);
    for (final entry in groups.entries) {
      children.add(DayHeader(entry.key));
      for (final s in entry.value) {
        children.add(Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: s.isNow ? cs.secondaryContainer : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.badge_outlined, color: cs.onPrimaryContainer),
            ),
            title: Row(
              children: [
                Flexible(child: Text(formatTimeRange(context, s.startsAt, s.endsAt))),
                if (s.isNow) ...[
                  const SizedBox(width: 8),
                  const NowPill(),
                ],
              ],
            ),
            subtitle: Text([
              '${s.gymName} · ${formatDuration(context, s.duration)}',
              if (s.note != null) s.note!,
            ].join('\n')),
            isThreeLine: s.note != null,
            trailing: multipleGyms
                ? null
                : Text(DateFormat.E(localeOf(context)).format(s.startsAt),
                    style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
        ));
      }
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Card(
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ts.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(value, style: ts.titleMedium),
          ],
        ),
      ),
      ),
    );
  }
}
