import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/gym_class.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'class_form_page.dart';
import 'schedule_widgets.dart';

/// One class: details and booking; for coaches also the roster with
/// attendance, plus edit and cancel.
class ClassDetailPage extends StatefulWidget {
  const ClassDetailPage({super.key, required this.classId});

  final String classId;

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage> {
  final _api = ApiService();
  GymClass? _class;
  bool _loading = true;
  String? _error;
  bool _bookingBusy = false;
  final Set<String> _rowBusy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _class == null;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final c = await _api.getClass(token, widget.classId);
      if (!mounted) return;
      setState(() {
        _class = c;
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

  Future<void> _toggleBooking() async {
    final c = _class;
    if (c == null) return;
    setState(() => _bookingBusy = true);
    final changed = await toggleClassBooking(context, c);
    if (changed && mounted) await _load();
    if (mounted) setState(() => _bookingBusy = false);
  }

  Future<void> _edit() async {
    final c = _class;
    if (c == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ClassFormPage(existing: c)),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _cancelClass() async {
    final c = _class;
    if (c == null) return;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final people = c.bookedCount + c.waitlistCount;
    final notice = people > 0
        ? l10n.trainingClassCancelNotifyPeople(people)
        : l10n.trainingClassNobodyBooked;

    // null = keep, false = this class only, true = this and future classes
    final bool? series = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trainingClassCancelQuestion),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notice),
            if (c.isSeries) ...[
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event_busy, color: cs.error),
                title: Text(l10n.trainingClassCancelThisOnly),
                onTap: () => Navigator.pop(ctx, false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.repeat_on, color: cs.error),
                title: Text(l10n.trainingClassCancelThisAndFuture),
                onTap: () => Navigator.pop(ctx, true),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.trainingClassKeepClass),
          ),
          if (!c.isSeries)
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: cs.error, foregroundColor: cs.onError),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.trainingClassCancelClass),
            ),
        ],
      ),
    );
    if (series == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.cancelClass(token, c.id, series: series);
      messenger.showSnackBar(SnackBar(
          content: Text(series
              ? l10n.trainingClassClassesCancelled
              : l10n.trainingClassClassCancelled)));
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  Future<void> _setAttendance(ClassBooking b, BookingStatus status) async {
    final c = _class;
    if (c == null || c.bookings == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final previous = b.status;
    void apply(BookingStatus s) {
      final c = _class;
      if (c == null || c.bookings == null) return;
      final idx = c.bookings!.indexWhere((x) => x.id == b.id);
      if (idx >= 0) c.bookings![idx] = c.bookings![idx].copyWith(status: s);
    }

    setState(() {
      _rowBusy.add(b.id);
      apply(status);
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.setClassBookingStatus(token, c.id, b.id, status);
    } catch (e) {
      if (mounted) setState(() => apply(previous));
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _rowBusy.remove(b.id));
    }
  }

  Future<void> _removeBooking(ClassBooking b) async {
    final c = _class;
    if (c == null) return;
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.trainingClassRemoveQuestion(
          b.fullName.isEmpty ? l10n.trainingClassMember : b.fullName),
      message: b.status == BookingStatus.waitlisted
          ? l10n.trainingClassRemoveWaitlistMessage
          : l10n.trainingClassRemoveBookedMessage,
      confirmLabel: l10n.trainingClassRemove,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _rowBusy.add(b.id));
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.cancelClassBooking(token, c.id, userId: b.userId);
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _rowBusy.remove(b.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _class;
    final l10n = context.l10n;
    final canManage = c != null && c.canCoach && !c.isCancelled && !c.isPast;
    return Scaffold(
      appBar: AppBar(
        title: Text(c?.title ?? l10n.trainingClassTitle),
        actions: [
          if (canManage) ...[
            IconButton(
              tooltip: l10n.trainingClassEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
            IconButton(
              tooltip: l10n.trainingClassCancelClass,
              icon: const Icon(Icons.event_busy_outlined),
              onPressed: _cancelClass,
            ),
          ],
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _class == null) {
      return ScheduleError(message: _error!, onRetry: _load);
    }
    final c = _class!;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final showBooking = bookingActionFor(c) != BookingAction.none;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (c.isCancelled)
          Card(
            color: cs.errorContainer,
            child: ListTile(
              leading: Icon(Icons.event_busy, color: cs.onErrorContainer),
              title: Text(l10n.trainingClassWasCancelled,
                  style: TextStyle(color: cs.onErrorContainer)),
            ),
          ),
        Text(c.title, style: ts.headlineSmall),
        if (c.myBookingStatus != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: BookingStatusChip(
                status: c.myBookingStatus!, position: c.myWaitlistPosition),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _info(Icons.calendar_today_outlined,
                  DateFormat.yMMMMEEEEd(localeOf(context)).format(c.startsAt),
                  formatDayLabel(context, c.startsAt)),
              _info(Icons.schedule, formatTimeRange(context, c.startsAt, c.endsAt),
                  formatDuration(context, c.duration)),
              _info(Icons.fitness_center, c.gymName, c.location),
              if (c.trainerName != null)
                ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: cs.secondaryContainer,
                    foregroundImage: c.trainerAvatarUrl != null
                        ? NetworkImage(c.trainerAvatarUrl!)
                        : null,
                    child: Icon(Icons.person,
                        size: 16, color: cs.onSecondaryContainer),
                  ),
                  title: Text(c.trainerName!),
                  subtitle: Text(l10n.trainingStaffRoleTrainer),
                ),
              if (c.isSeries)
                _info(Icons.repeat, l10n.trainingClassWeekly, l10n.trainingClassWeeklySeries),
            ],
          ),
        ),
        if (c.description != null) ...[
          const SizedBox(height: 16),
          Text(l10n.trainingClassAbout, style: ts.titleMedium),
          const SizedBox(height: 4),
          Text(c.description!, style: ts.bodyMedium),
        ],
        if (!c.isCancelled) ...[
          const SizedBox(height: 20),
          Text(l10n.trainingClassSpots, style: ts.titleMedium),
          const SizedBox(height: 8),
          CapacityBar(gymClass: c, dense: false),
        ],
        if (showBooking) ...[
          const SizedBox(height: 20),
          BookingButton(
            gymClass: c,
            busy: _bookingBusy,
            onBook: _toggleBooking,
            onCancel: _toggleBooking,
            expanded: true,
          ),
        ] else if (!c.isCancelled && c.hasStarted && !c.canCoach) ...[
          const SizedBox(height: 20),
          Text(
            c.isPast ? l10n.trainingClassEnded : l10n.trainingClassInProgress,
            style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        if (c.canCoach && c.bookings != null) ..._buildRoster(c),
      ],
    );
  }

  Widget _info(IconData icon, String title, String? subtitle) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
      );

  List<Widget> _buildRoster(GymClass c) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final seated = c.bookings!.where((b) => b.status.takesSeat).toList();
    final waitlist =
        c.bookings!.where((b) => b.status == BookingStatus.waitlisted).toList();
    final attended = seated.where((b) => b.status == BookingStatus.attended).length;

    return [
      const SizedBox(height: 28),
      Row(
        children: [
          Expanded(child: Text(l10n.trainingClassRoster, style: ts.titleMedium)),
          if (seated.isNotEmpty)
            Text(l10n.trainingClassAttendedOf(attended, seated.length),
                style: ts.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
      const SizedBox(height: 8),
      if (seated.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(Icons.group_outlined, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(l10n.trainingClassNoBookingsYet,
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        )
      else
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [for (final b in seated) _rosterRow(c, b)],
          ),
        ),
      if (waitlist.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(l10n.trainingClassWaitlistCount(waitlist.length), style: ts.titleMedium),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < waitlist.length; i++)
                _rosterRow(c, waitlist[i], position: i + 1),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _rosterRow(GymClass c, ClassBooking b, {int? position}) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final busy = _rowBusy.contains(b.id);
    final canRemove = !c.isCancelled &&
        !c.hasStarted &&
        (b.status == BookingStatus.booked || b.status == BookingStatus.waitlisted);
    final canMark = !c.isCancelled && b.status.takesSeat;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        foregroundImage: b.avatarUrl != null ? NetworkImage(b.avatarUrl!) : null,
        child: Text(b.initials, style: TextStyle(color: cs.onPrimaryContainer)),
      ),
      title: Text(b.fullName.isEmpty ? l10n.trainingClassMember : b.fullName),
      subtitle: position != null
          ? Text(l10n.trainingClassWaitlistPosition(position))
          : Text(b.status == BookingStatus.booked
              ? l10n.trainingClassBookedAt(DateFormat.MMMd(localeOf(context))
                  .add_jm()
                  .format(b.createdAt))
              : b.status.label(l10n)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canMark) ...[
            IconButton(
              tooltip: b.status == BookingStatus.attended
                  ? l10n.trainingClassAttendedUndo
                  : l10n.trainingClassMarkAttended,
              isSelected: b.status == BookingStatus.attended,
              icon: const Icon(Icons.check_circle_outline),
              selectedIcon: Icon(Icons.check_circle, color: cs.primary),
              onPressed: busy
                  ? null
                  : () => _setAttendance(
                      b,
                      b.status == BookingStatus.attended
                          ? BookingStatus.booked
                          : BookingStatus.attended),
            ),
            IconButton(
              tooltip: b.status == BookingStatus.noShow
                  ? l10n.trainingClassNoShowUndo
                  : l10n.trainingClassMarkNoShow,
              isSelected: b.status == BookingStatus.noShow,
              icon: const Icon(Icons.person_off_outlined),
              selectedIcon: Icon(Icons.person_off, color: cs.error),
              onPressed: busy
                  ? null
                  : () => _setAttendance(
                      b,
                      b.status == BookingStatus.noShow
                          ? BookingStatus.booked
                          : BookingStatus.noShow),
            ),
          ],
          if (canRemove)
            PopupMenuButton<String>(
              tooltip: l10n.trainingClassMore,
              enabled: !busy,
              onSelected: (_) => _removeBooking(b),
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'remove', child: Text(l10n.trainingClassRemoveFromClass)),
              ],
            ),
        ],
      ),
    );
  }
}
