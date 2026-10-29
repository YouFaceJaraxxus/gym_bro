import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/gym_class.dart';
import 'calendar_view.dart';

/// Loads the sessions of one week: [from] is Monday 00:00, [to] a week later.
typedef ClassWeekLoader =
    Future<List<GymClass>> Function(DateTime from, DateTime to);

/// [CalendarView] for class sessions: each block shows the time, location ·
/// gym, and booked/capacity with the waitlist and the caller's booking.
/// Done sessions are muted, cancelled ones struck through, and upcoming ones
/// filled — or, when [isHighlighted] says no, outlined and faded (e.g.
/// bookable classes that aren't mine).
class ClassCalendar extends StatefulWidget {
  const ClassCalendar({
    super.key,
    required this.load,
    required this.onTap,
    this.isHighlighted,
    this.filter,
    this.initialDay,
  });

  final ClassWeekLoader load;

  /// Opens a session; the calendar reloads the week once it completes.
  final Future<void> Function(GymClass gymClass) onTap;

  /// Null: every session is highlighted.
  final bool Function(GymClass gymClass)? isHighlighted;

  /// Which loaded sessions to show (applied without reloading).
  final bool Function(GymClass gymClass)? filter;

  final DateTime? initialDay;

  /// A session as a calendar entry; usable by any [CalendarView] of classes.
  static CalendarEntry entryOf(
    BuildContext context,
    GymClass c, {
    bool highlighted = true,
  }) {
    final l10n = context.l10n;
    final cancelled = c.isCancelled;
    final done = !cancelled && c.isPast;
    final place = [
      if (c.location?.isNotEmpty ?? false) c.location!,
      c.gymName,
    ].join(' · ');
    final status = cancelled
        ? l10n.calendarCancelled
        : done
        ? l10n.calendarDone
        : c.myBookingStatus?.label(l10n);
    return CalendarEntry(
      start: c.startsAt,
      end: c.endsAt,
      title: c.title,
      lines: [
        if (place.isNotEmpty) place,
        [
          '${c.bookedCount}/${c.capacity}',
          if (c.waitlistCount > 0)
            l10n.classCalendarWaitlistShort(c.waitlistCount),
          ?status,
        ].join(' · '),
      ],
      state: cancelled
          ? CalendarEntryState.cancelled
          : done
          ? CalendarEntryState.done
          : CalendarEntryState.upcoming,
      highlighted: highlighted,
      semanticLabel: [
        c.title,
        calendarTimeRange(context, c.startsAt, c.endsAt),
        if (place.isNotEmpty) place,
        l10n.classCalendarBookedOf(c.bookedCount, c.capacity),
        ?status,
      ].join(', '),
    );
  }

  @override
  State<ClassCalendar> createState() => ClassCalendarState();
}

class ClassCalendarState extends State<ClassCalendar> {
  final _view = GlobalKey<CalendarViewState<GymClass>>();

  /// Drops every cached week and reloads the one on screen.
  Future<void> refresh() => _view.currentState?.refresh() ?? Future.value();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CalendarView<GymClass>(
      key: _view,
      load: widget.load,
      describe: (c) => ClassCalendar.entryOf(
        context,
        c,
        highlighted: widget.isHighlighted?.call(c) ?? true,
      ),
      onTap: widget.onTap,
      filter: widget.filter,
      initialDay: widget.initialDay,
      emptyDayText: l10n.classCalendarNothingOnDay,
      daySemanticsLabel: l10n.classCalendarDayLabel,
    );
  }
}
