import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/staff_shift.dart';
import '../pages/classes/my_shifts_page.dart';
import '../pages/classes/schedule_widgets.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

/// Compact "Next shifts" card for staff home pages: the next 3 shifts and a
/// "See all" link to [MyShiftsPage]. Loads its own data.
class MyShiftsCard extends StatefulWidget {
  const MyShiftsCard({super.key});

  @override
  State<MyShiftsCard> createState() => _MyShiftsCardState();
}

class _MyShiftsCardState extends State<MyShiftsCard> {
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
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final shifts = await _api.getMyShifts(token);
      if (!mounted) return;
      setState(() {
        _shifts = shifts.take(3).toList();
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

  Future<void> _seeAll() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyShiftsPage()),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge_outlined, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(context.l10n.trainingShiftNextShifts, style: ts.titleMedium)),
                TextButton(
                    onPressed: _seeAll, child: Text(context.l10n.trainingShiftSeeAll)),
              ],
            ),
            _buildContent(cs, ts),
          ],
        ),
      ),
    );
  }

  /// "Today", "Tomorrow" or the short weekday ("Wed" / "sre").
  String _shortDay(DateTime d) {
    final diff = dateOnly(d).difference(dateOnly(DateTime.now())).inDays;
    if (diff == 0) return context.l10n.commonToday;
    if (diff == 1) return context.l10n.trainingScheduleTomorrow;
    return DateFormat.E(localeOf(context)).format(d);
  }

  Widget _buildContent(ColorScheme cs, TextTheme ts) {
    final l10n = context.l10n;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 4),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 20, color: cs.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.trainingShiftLoadFailed,
                  style: ts.bodyMedium?.copyWith(color: cs.error)),
            ),
            TextButton(onPressed: _load, child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    if (_shifts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 8, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.surfaceContainerHighest,
              child: Icon(Icons.beach_access_outlined,
                  size: 20, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.trainingShiftNoUpcoming, style: ts.bodyLarge),
                  Text(l10n.trainingShiftFree,
                      style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final s in _shifts)
          ListTile(
            contentPadding: const EdgeInsets.only(right: 8),
            dense: true,
            onTap: _seeAll,
            leading: SizedBox(
              width: 44,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _shortDay(s.startsAt),
                    style: ts.labelSmall?.copyWith(color: cs.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(DateFormat.d(localeOf(context)).format(s.startsAt),
                      style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
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
            subtitle: Text(
              [s.gymName, if (s.note != null) s.note!].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
