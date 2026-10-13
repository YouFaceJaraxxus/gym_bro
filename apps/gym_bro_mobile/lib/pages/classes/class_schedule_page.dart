import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/gym_class.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'class_detail_page.dart';
import 'schedule_widgets.dart';

/// Upcoming classes at the caller's gyms for the next 14 days: day strip,
/// book / cancel / waitlist, and a "My bookings" filter.
class ClassSchedulePage extends StatefulWidget {
  const ClassSchedulePage({super.key});

  @override
  State<ClassSchedulePage> createState() => _ClassSchedulePageState();
}

class _ClassSchedulePageState extends State<ClassSchedulePage> {
  static const _days = 14;

  final _api = ApiService();
  List<GymClass> _classes = [];
  bool _loading = true;
  String? _error;
  bool _myBookingsOnly = false;
  late DateTime _start;
  late DateTime _selectedDay;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _start = dateOnly(DateTime.now());
    _selectedDay = _start;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _classes.isEmpty;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final now = DateTime.now();
      final classes = await _api.getClasses(
        token,
        from: now,
        to: _start.add(const Duration(days: _days)),
      );
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

  Future<void> _toggleBooking(GymClass c) async {
    setState(() => _busy.add(c.id));
    final changed = await toggleClassBooking(context, c);
    if (!mounted) return;
    if (changed) await _load();
    if (mounted) setState(() => _busy.remove(c.id));
  }

  Future<void> _openDetail(GymClass c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClassDetailPage(classId: c.id)),
    );
    if (mounted) _load();
  }

  bool get _multipleGyms => _classes.map((c) => c.gymId).toSet().length > 1;

  @override
  Widget build(BuildContext context) {
    final markedDays = _classes
        .where((c) => !_myBookingsOnly || c.myBookingStatus != null)
        .map((c) => dateOnly(c.startsAt))
        .toSet();
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trainingClassClasses),
        actions: [
          IconButton(
            tooltip: l10n.trainingClassRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_myBookingsOnly)
            DayStrip(
              start: _start,
              days: _days,
              selected: _selectedDay,
              markedDays: markedDays,
              onSelected: (d) => setState(() => _selectedDay = d),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                FilterChip(
                  avatar: _myBookingsOnly
                      ? null
                      : const Icon(Icons.event_available, size: 18),
                  label: Text(_myBookingCount > 0
                      ? l10n.trainingClassMyBookingsCount(_myBookingCount)
                      : l10n.trainingClassMyBookings),
                  selected: _myBookingsOnly,
                  onSelected: (v) => setState(() => _myBookingsOnly = v),
                ),
                const Spacer(),
                if (!_myBookingsOnly)
                  Text(
                    formatDayLabel(context, _selectedDay),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
          ),
        ],
      ),
    );
  }

  int get _myBookingCount => _classes.where((c) => c.hasActiveBooking).length;

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ScheduleError(message: _error!, onRetry: _load);
    return _myBookingsOnly ? _buildMyBookings() : _buildDay();
  }

  Widget _buildDay() {
    final l10n = context.l10n;
    final dayClasses =
        _classes.where((c) => sameDay(c.startsAt, _selectedDay)).toList();
    if (_classes.isEmpty) {
      return ScheduleEmpty(
        icon: Icons.event_busy,
        title: l10n.trainingClassNoneScheduled,
        message: l10n.trainingClassNoneScheduledMessage,
      );
    }
    if (dayClasses.isEmpty) {
      final next = _classes
          .where((c) => dateOnly(c.startsAt).isAfter(_selectedDay))
          .firstOrNull;
      return ScheduleEmpty(
        icon: Icons.free_breakfast_outlined,
        title: l10n.trainingClassNothingOn(formatDayLabel(context, _selectedDay)),
        message: next != null
            ? l10n.trainingClassNextClass(next.title,
                formatDayLabel(context, next.startsAt), formatTime(context, next.startsAt))
            : null,
        action: next != null
            ? FilledButton.tonal(
                onPressed: () =>
                    setState(() => _selectedDay = dateOnly(next.startsAt)),
                child: Text(l10n.trainingClassJumpToNext),
              )
            : null,
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: dayClasses.length,
      itemBuilder: (_, i) => _card(dayClasses[i]),
    );
  }

  Widget _buildMyBookings() {
    final mine = _classes.where((c) => c.myBookingStatus != null).toList();
    if (mine.isEmpty) {
      return ScheduleEmpty(
        icon: Icons.event_available,
        title: context.l10n.trainingClassNoBookings,
        message: context.l10n.trainingClassNoBookingsMessage,
        action: FilledButton.tonal(
          onPressed: () => setState(() => _myBookingsOnly = false),
          child: Text(context.l10n.trainingClassBrowse),
        ),
      );
    }
    final groups = groupByDay(mine, (c) => c.startsAt);
    final children = <Widget>[];
    for (final entry in groups.entries) {
      children.add(DayHeader(entry.key));
      children.addAll(entry.value.map(_card));
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
    );
  }

  Widget _card(GymClass c) => ClassCard(
        key: ValueKey(c.id),
        gymClass: c,
        showGym: _multipleGyms,
        busy: _busy.contains(c.id),
        onTap: () => _openDetail(c),
        onBook: () => _toggleBooking(c),
        onCancel: () => _toggleBooking(c),
      );
}
