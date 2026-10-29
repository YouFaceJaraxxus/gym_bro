import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/class_series.dart';
import '../../models/gym_class.dart';
import '../../models/people.dart';
import '../../models/training_session.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../theme.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/class_calendar.dart';
import '../../widgets/social_widgets.dart';
import '../log_workout_page.dart';
import '../session_detail_page.dart';
import 'class_detail_page.dart';
import 'schedule_widgets.dart';
import 'series_format.dart';

/// The Schedule tab: pending invites (to classes, and from trainers) on top,
/// then a calendar of the caller's sessions — highlighted — merged with the
/// other sessions they can book at their gyms (faded) and the workouts they
/// logged, with an "Only mine" filter. Booking happens on a session's page;
/// tapping an empty hour logs a workout there ([LogWorkoutPage]).
///
/// Works as a tab body inside the home Scaffold, pushed inside a Scaffold
/// with an app bar, or pushed on its own (it then brings its own app bar).
class ClassSchedulePage extends StatefulWidget {
  const ClassSchedulePage({super.key});

  @override
  State<ClassSchedulePage> createState() => _ClassSchedulePageState();
}

class _ClassSchedulePageState extends State<ClassSchedulePage> {
  final _api = ApiService();
  final _calendar = GlobalKey<CalendarViewState<_ScheduleItem>>();
  List<ClassSeries> _classInvites = [];
  List<PersonSummary> _trainerInvites = [];
  final Set<String> _busy = {};
  bool _onlyMine = false;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait([
        _api.getClassInvites(token),
        _api.getCustomerInvites(token),
      ]);
      if (!mounted) return;
      setState(() {
        _classInvites = results[0] as List<ClassSeries>;
        _trainerInvites = results[1] as List<PersonSummary>;
      });
    } catch (_) {
      // Invites are extra; the calendar still works without them.
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadInvites(),
      _calendar.currentState?.refresh() ?? Future.value(),
    ]);
  }

  static bool _isMine(GymClass c) =>
      c.myBookingStatus != null && c.myBookingStatus != BookingStatus.cancelled;

  Future<List<_ScheduleItem>> _loadWeek(DateTime from, DateTime to) async {
    final token = await AuthManager.instance.getValidToken();
    // The default list covers the caller's gyms plus every class they're
    // booked into (also ones a trainer added them to).
    final classes = _api.getClasses(token, from: from, to: to);
    final workouts = _api
        .getTrainingSessions(token, from: from, to: to, pageSize: 100)
        // Workouts are extra; classes still show without them.
        .catchError((_) => <TrainingSession>[]);
    return [
      for (final c in await classes) _ClassItem(c),
      for (final s in await workouts) _WorkoutItem(s),
    ];
  }

  CalendarEntry _describe(BuildContext context, _ScheduleItem item) =>
      switch (item) {
        _ClassItem(:final gymClass) => ClassCalendar.entryOf(
          context,
          gymClass,
          highlighted: _isMine(gymClass),
        ),
        _WorkoutItem(:final session) => _workoutEntry(context, session),
      };

  CalendarEntry _workoutEntry(BuildContext context, TrainingSession s) {
    final l10n = context.l10n;
    final start = s.startedAt.toLocal();
    final end = (s.endedAt ?? DateTime.now()).toLocal();
    final title = s.trainingName ?? l10n.trainingSessionFree;
    final status = s.isActive
        ? l10n.trainingSessionInProgress
        : l10n.workoutLogCalendarDone;
    final lines = [
      [status, ?s.trainerName].join(' · '),
      if (s.commentCount > 0) l10n.trainingSessionCommentCount(s.commentCount),
    ];
    return CalendarEntry(
      start: start,
      end: end.isAfter(start) ? end : start.add(const Duration(minutes: 1)),
      title: title,
      lines: lines,
      color: context.appColors.success,
      semanticLabel: [
        l10n.workoutLogCalendarSemantics(title),
        calendarTimeRange(context, start, end),
        ...lines,
      ].join(', '),
    );
  }

  Future<void> _open(_ScheduleItem item) async {
    switch (item) {
      case _ClassItem(:final gymClass):
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => ClassDetailPage(classId: gymClass.id)),
        );
        if (mounted) _loadInvites();
      case _WorkoutItem(:final session):
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: session.id)),
        );
    }
  }

  Future<bool> _logWorkout(DateTime slot) async {
    if (slot.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.workoutLogFutureSlot)),
      );
      return false;
    }
    final logged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LogWorkoutPage(start: slot),
      ),
    );
    return logged == true;
  }

  Future<void> _answerClass(ClassSeries s, bool accept) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(s.id));
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.answerClassInvite(token, s.id, accept: accept);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? l10n.classCalendarJoined(s.title)
                : l10n.classCalendarInviteDeclined,
          ),
        ),
      );
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(s.id));
    }
  }

  Future<void> _answerTrainer(PersonSummary t, bool accept) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(t.id));
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.answerCustomerInvite(token, t.id, accept: accept);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? l10n.classCalendarTrainerAccepted(_name(t))
                : l10n.classCalendarInviteDeclined,
          ),
        ),
      );
      // Declining a trainer declines their class invites too.
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(t.id));
    }
  }

  static String _name(PersonSummary p) {
    final n = '${p.name} ${p.lastName}'.trim();
    return n.isEmpty ? '@${p.username}' : n;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parent = Scaffold.maybeOf(context);
    final ownAppBar = parent == null || !parent.hasAppBar;
    final inviteCount = _classInvites.length + _trainerInvites.length;
    return Scaffold(
      appBar: ownAppBar ? AppBar(title: Text(l10n.trainingClassClasses)) : null,
      body: Column(
        children: [
          if (inviteCount > 0) _buildInvites(context, inviteCount),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilterChip(
                avatar: _onlyMine
                    ? null
                    : const Icon(Icons.event_available, size: 18),
                label: Text(l10n.classCalendarOnlyMine),
                selected: _onlyMine,
                onSelected: (v) => setState(() => _onlyMine = v),
              ),
            ),
          ),
          Expanded(
            child: CalendarView<_ScheduleItem>(
              key: _calendar,
              load: _loadWeek,
              describe: (item) => _describe(context, item),
              filter: _onlyMine
                  ? (item) => switch (item) {
                      _ClassItem(:final gymClass) => _isMine(gymClass),
                      _WorkoutItem() => true,
                    }
                  : null,
              onTap: _open,
              onSlotTap: _logWorkout,
              slotSemanticsLabel: l10n.workoutLogSlotLabel,
              emptyDayText: l10n.workoutLogScheduleEmptyDay,
              daySemanticsLabel: l10n.classCalendarDayLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvites(BuildContext context, int count) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: cs.secondaryContainer,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.35,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.classCalendarInvites(count),
                  style: ts.titleSmall?.copyWith(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            for (final t in _trainerInvites)
              _InviteTile(
                leading: UserAvatar(url: t.avatarUrl, initials: t.initials),
                title: l10n.classCalendarTrainerInvite(_name(t)),
                subtitle: l10n.classCalendarTrainerInviteHint,
                busy: _busy.contains(t.id),
                onAccept: () => _answerTrainer(t, true),
                onDecline: () => _answerTrainer(t, false),
              ),
            for (final s in _classInvites)
              _InviteTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.event_repeat, color: cs.onPrimaryContainer),
                ),
                title: s.title,
                subtitle: [
                  [
                    if (s.invitedBy != null)
                      _name(s.invitedBy!)
                    else if (s.trainerName != null)
                      s.trainerName!,
                    s.gymName,
                  ].where((x) => x.isNotEmpty).join(' · '),
                  seriesScheduleSummary(context, s),
                ].join('\n'),
                busy: _busy.contains(s.id),
                onAccept: () => _answerClass(s, true),
                onDecline: () => _answerClass(s, false),
              ),
          ],
        ),
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ts.titleSmall?.copyWith(
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: ts.bodySmall?.copyWith(
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : onDecline,
                  child: Text(l10n.classCalendarDecline),
                ),
                FilledButton.tonal(
                  onPressed: busy ? null : onAccept,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.classCalendarAccept),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row on the Schedule calendar.
sealed class _ScheduleItem {}

final class _ClassItem extends _ScheduleItem {
  _ClassItem(this.gymClass);
  final GymClass gymClass;
}

/// A workout the caller logged (started live or logged afterwards).
final class _WorkoutItem extends _ScheduleItem {
  _WorkoutItem(this.session);
  final TrainingSession session;
}
