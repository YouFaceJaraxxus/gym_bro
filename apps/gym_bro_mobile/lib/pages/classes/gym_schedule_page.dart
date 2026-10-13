import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/gym_class.dart';
import '../../models/staff_shift.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'class_detail_page.dart';
import 'class_form_page.dart';
import 'schedule_widgets.dart';
import 'shift_form_page.dart';

/// Manager/staff view of one gym: classes and staff shifts, week by week.
class GymSchedulePage extends StatelessWidget {
  const GymSchedulePage({super.key, required this.gymId, required this.gymName});

  final String gymId;
  final String gymName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.trainingScheduleTitle),
              Text(gymName, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.event), text: l10n.trainingClassClasses),
              Tab(icon: const Icon(Icons.badge_outlined), text: l10n.trainingShiftShifts),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GymClassesTab(gymId: gymId),
            _GymShiftsTab(gymId: gymId, gymName: gymName),
          ],
        ),
      ),
    );
  }
}

// ── Classes tab ───────────────────────────────────────────────────────────────

class _GymClassesTab extends StatefulWidget {
  const _GymClassesTab({required this.gymId});

  final String gymId;

  @override
  State<_GymClassesTab> createState() => _GymClassesTabState();
}

class _GymClassesTabState extends State<_GymClassesTab>
    with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  DateTime _weekStart = startOfWeek(DateTime.now());
  List<GymClass> _classes = [];
  bool _canCreate = false;
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(checkAccess: true);
  }

  Future<void> _load({bool checkAccess = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final classesF = _api.getClasses(
        token,
        gymId: widget.gymId,
        from: _weekStart,
        to: _weekStart.add(const Duration(days: 7)),
        includeCancelled: true,
      );
      if (checkAccess) {
        try {
          final gyms = await _api.getCoachingGyms(token);
          _canCreate = gyms.any((g) => g.gymId == widget.gymId);
        } catch (_) {
          _canCreate = false;
        }
      }
      final classes = await classesF;
      if (!mounted) return;
      setState(() {
        _classes = classes;
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

  void _changeWeek(DateTime w) {
    setState(() => _weekStart = w);
    _load();
  }

  Future<void> _create() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ClassFormPage(initialGymId: widget.gymId)),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _open(GymClass c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClassDetailPage(classId: c.id)),
    );
    if (mounted) _load();
  }

  Future<void> _toggleBooking(GymClass c) async {
    setState(() => _busy.add(c.id));
    final changed = await toggleClassBooking(context, c);
    if (changed && mounted) await _load();
    if (mounted) setState(() => _busy.remove(c.id));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              heroTag: 'gym-schedule-class-fab',
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.trainingClassNew),
            )
          : null,
      body: Column(
        children: [
          WeekNavigator(weekStart: _weekStart, onChanged: _changeWeek),
          Expanded(
            child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _classes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) return ScheduleError(message: _error!, onRetry: _load);
    final l10n = context.l10n;
    if (_classes.isEmpty) {
      return ScheduleEmpty(
        icon: Icons.event_busy,
        title: l10n.trainingClassNoneThisWeek,
        message: _canCreate
            ? l10n.trainingClassNoneThisWeekCreate
            : l10n.trainingClassNoneThisWeekMessage,
        action: _canCreate
            ? FilledButton.tonalIcon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: Text(l10n.trainingClassCreateOne),
              )
            : null,
      );
    }
    final groups = groupByDay(_classes, (c) => c.startsAt);
    final children = <Widget>[];
    for (final entry in groups.entries) {
      children.add(DayHeader(entry.key,
          trailing: l10n.trainingClassCount(entry.value.length)));
      for (final c in entry.value) {
        children.add(ClassCard(
          key: ValueKey(c.id),
          gymClass: c,
          busy: _busy.contains(c.id),
          onTap: () => _open(c),
          onBook: () => _toggleBooking(c),
          onCancel: () => _toggleBooking(c),
        ));
      }
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      children: children,
    );
  }
}

// ── Shifts tab ────────────────────────────────────────────────────────────────

class _GymShiftsTab extends StatefulWidget {
  const _GymShiftsTab({required this.gymId, required this.gymName});

  final String gymId;
  final String gymName;

  @override
  State<_GymShiftsTab> createState() => _GymShiftsTabState();
}

class _GymShiftsTabState extends State<_GymShiftsTab>
    with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  DateTime _weekStart = startOfWeek(DateTime.now());
  List<StaffShift> _shifts = [];
  GymShiftStaff? _staff;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  bool get _canManage => _staff?.canManage ?? false;

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
      final staffF = _staff == null
          ? _api.getShiftStaff(token, widget.gymId)
          : Future.value(_staff!);
      final shifts = await _api.getGymShifts(
        token,
        widget.gymId,
        from: _weekStart,
        to: _weekStart.add(const Duration(days: 7)),
      );
      final staff = await staffF;
      if (!mounted) return;
      setState(() {
        _shifts = shifts;
        _staff = staff;
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

  void _changeWeek(DateTime w) {
    setState(() => _weekStart = w);
    _load();
  }

  Future<void> _openForm({StaffShift? existing, DateTime? day}) async {
    final staff = _staff;
    if (staff == null || !staff.canManage) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ShiftFormPage(
          gymId: widget.gymId,
          gymName: widget.gymName,
          staff: staff.staff,
          existing: existing,
          initialDate: day ?? _defaultDay(),
        ),
      ),
    );
    if (saved == true && mounted) {
      // Refresh the staff list too, in case staff changed meanwhile.
      _staff = null;
      _load();
    }
  }

  /// Today when viewing this week, otherwise the Monday of the shown week.
  DateTime _defaultDay() {
    final today = dateOnly(DateTime.now());
    final end = _weekStart.add(const Duration(days: 7));
    return !today.isBefore(_weekStart) && today.isBefore(end) ? today : _weekStart;
  }

  Future<void> _delete(StaffShift s) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.trainingShiftDeleteQuestion,
      message: l10n.trainingShiftDeleteMessage(
          s.fullName, formatDayLabel(context, s.startsAt)),
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteShift(token, s.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.trainingShiftDeleted)));
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              heroTag: 'gym-schedule-shift-fab',
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.trainingShiftAdd),
            )
          : null,
      body: Column(
        children: [
          WeekNavigator(weekStart: _weekStart, onChanged: _changeWeek),
          Expanded(
            child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _shifts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) return ScheduleError(message: _error!, onRetry: _load);
    final l10n = context.l10n;
    if (_shifts.isEmpty) {
      return ScheduleEmpty(
        icon: Icons.badge_outlined,
        title: l10n.trainingShiftNoneThisWeek,
        message: _canManage
            ? l10n.trainingShiftNoneThisWeekManage
            : l10n.trainingShiftNoneThisWeekMessage,
        action: _canManage
            ? FilledButton.tonalIcon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: Text(l10n.trainingShiftAddOne),
              )
            : null,
      );
    }

    final cs = Theme.of(context).colorScheme;
    final groups = groupByDay(_shifts, (s) => s.startsAt);
    final children = <Widget>[];
    for (var i = 0; i < 7; i++) {
      final day = dateOnly(_weekStart.add(Duration(days: i)));
      final dayShifts = groups[day] ?? const <StaffShift>[];
      children.add(Row(
        children: [
          Expanded(
            child: DayHeader(day,
                trailing: dayShifts.isEmpty
                    ? null
                    : l10n.trainingShiftCount(dayShifts.length)),
          ),
          if (_canManage)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 12),
              child: IconButton(
                tooltip: l10n.trainingShiftAddOn(formatDayLabel(context, day)),
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _openForm(day: day),
              ),
            ),
        ],
      ));
      if (dayShifts.isEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(l10n.trainingShiftNone,
              style: TextStyle(color: cs.onSurfaceVariant)),
        ));
      } else {
        children.addAll(dayShifts.map(_shiftTile));
      }
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      children: children,
    );
  }

  Widget _shiftTile(StaffShift s) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final me = AuthManager.instance.profile?.id;
    final mine = s.userId == me;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: mine ? cs.secondaryContainer : null,
      child: ListTile(
        onTap: _canManage ? () => _openForm(existing: s) : null,
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          foregroundImage: s.avatarUrl != null ? NetworkImage(s.avatarUrl!) : null,
          child: Text(
            '${s.name.isNotEmpty ? s.name[0] : ''}${s.lastName.isNotEmpty ? s.lastName[0] : ''}'
                .toUpperCase(),
            style: TextStyle(color: cs.onPrimaryContainer),
          ),
        ),
        title: Row(
          children: [
            Flexible(
                child: Text(mine ? l10n.trainingClassNameYou(s.fullName) : s.fullName)),
            if (s.isNow) ...[
              const SizedBox(width: 8),
              const NowPill(),
            ],
          ],
        ),
        subtitle: Text([
          '${formatTimeRange(context, s.startsAt, s.endsAt)} · ${formatDuration(context, s.duration)}',
          if (s.note != null) s.note!,
        ].join('\n')),
        isThreeLine: s.note != null,
        trailing: _canManage
            ? PopupMenuButton<String>(
                tooltip: l10n.trainingShiftOptions,
                onSelected: (v) =>
                    v == 'edit' ? _openForm(existing: s) : _delete(s),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
                  PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete)),
                ],
              )
            : null,
      ),
    );
  }
}
