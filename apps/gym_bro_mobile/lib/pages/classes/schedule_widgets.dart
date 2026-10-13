import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/gym_class.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';

// Shared building blocks for the class schedule and staff shift pages.

// ── Date helpers ──────────────────────────────────────────────────────────────

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Monday 00:00 (local) of the week containing [d].
DateTime startOfWeek(DateTime d) =>
    dateOnly(d).subtract(Duration(days: d.weekday - DateTime.monday));

/// The current locale as an intl locale string ("en", "sr_Latn").
String localeOf(BuildContext context) => Localizations.localeOf(context).toString();

/// Clock time in the user's locale ("6:30 PM" / "18:30").
String formatTime(BuildContext context, DateTime d) =>
    DateFormat.jm(localeOf(context)).format(d);

String formatTimeRange(BuildContext context, DateTime start, DateTime end) {
  final range = '${formatTime(context, start)} – ${formatTime(context, end)}';
  return sameDay(start, end) ? range : context.l10n.trainingScheduleNextDay(range);
}

/// "45 min", "1 h", "1 h 30 min".
String formatDuration(BuildContext context, Duration d) {
  final l10n = context.l10n;
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return l10n.trainingScheduleMinutes(m);
  if (m == 0) return l10n.trainingScheduleHours(h);
  return l10n.trainingScheduleHoursMinutes(h, m);
}

/// "Today", "Tomorrow", or e.g. "Wed, Oct 15".
String formatDayLabel(BuildContext context, DateTime d) {
  final l10n = context.l10n;
  final locale = localeOf(context);
  final today = dateOnly(DateTime.now());
  final day = dateOnly(d);
  final diff = day.difference(today).inDays;
  if (diff == 0) return l10n.commonToday;
  if (diff == 1) return l10n.trainingScheduleTomorrow;
  if (diff == -1) return l10n.trainingScheduleYesterday;
  if (day.year != today.year) return DateFormat.yMMMEd(locale).format(d);
  return DateFormat.MMMEd(locale).format(d);
}

/// Groups items by local calendar day, keeping input order inside each day.
Map<DateTime, List<T>> groupByDay<T>(
    Iterable<T> items, DateTime Function(T) dateOf) {
  final map = <DateTime, List<T>>{};
  for (final item in items) {
    map.putIfAbsent(dateOnly(dateOf(item)), () => []).add(item);
  }
  return map;
}

// ── States ────────────────────────────────────────────────────────────────────

/// Full-area error with a Retry button. Scrollable so pull-to-refresh works.
class ScheduleError extends StatelessWidget {
  const ScheduleError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(Icons.cloud_off_outlined, size: 48, color: cs.error),
        const SizedBox(height: 16),
        Text(
          message.replaceFirst('Exception: ', ''),
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.commonRetry),
          ),
        ),
      ],
    );
  }
}

/// Designed empty state. Scrollable so pull-to-refresh works.
class ScheduleEmpty extends StatelessWidget {
  const ScheduleEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: cs.primaryContainer,
            child: Icon(icon, size: 36, color: cs.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: ts.titleMedium),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 16),
          Center(child: action),
        ],
      ],
    );
  }
}

/// Small day heading used in grouped lists.
class DayHeader extends StatelessWidget {
  const DayHeader(this.day, {super.key, this.trailing});

  final DateTime day;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            formatDayLabel(context, day),
            style: ts.titleSmall?.copyWith(color: cs.primary),
          ),
          if (trailing != null) ...[
            const Spacer(),
            Text(trailing!,
                style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

// ── Week navigation ───────────────────────────────────────────────────────────

class WeekNavigator extends StatelessWidget {
  const WeekNavigator({
    super.key,
    required this.weekStart,
    required this.onChanged,
  });

  final DateTime weekStart;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = localeOf(context);
    final end = weekStart.add(const Duration(days: 6));
    final isThisWeek = sameDay(weekStart, startOfWeek(DateTime.now()));
    final label =
        '${DateFormat.MMMd(locale).format(weekStart)} – ${DateFormat.MMMd(locale).format(end)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.trainingSchedulePreviousWeek,
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                onChanged(weekStart.subtract(const Duration(days: 7))),
          ),
          Expanded(
            child: Column(
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                if (!isThisWeek)
                  TextButton(
                    onPressed: () => onChanged(startOfWeek(DateTime.now())),
                    child: Text(l10n.trainingScheduleThisWeek),
                  )
                else
                  Text(
                    l10n.trainingScheduleThisWeek,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.trainingScheduleNextWeek,
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(weekStart.add(const Duration(days: 7))),
          ),
        ],
      ),
    );
  }
}

// ── Day strip ─────────────────────────────────────────────────────────────────

/// Horizontal selector of [days] consecutive days starting at [start].
class DayStrip extends StatefulWidget {
  const DayStrip({
    super.key,
    required this.start,
    required this.days,
    required this.selected,
    required this.onSelected,
    this.markedDays = const {},
  });

  final DateTime start;
  final int days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  /// Days (date-only) that get a dot underneath — e.g. days with classes.
  final Set<DateTime> markedDays;

  @override
  State<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<DayStrip> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = localeOf(context);
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: widget.days,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final day = dateOnly(widget.start.add(Duration(days: i)));
          final selected = sameDay(day, widget.selected);
          final marked = widget.markedDays.contains(day);
          final fg = selected ? cs.onPrimary : cs.onSurface;
          return Semantics(
            selected: selected,
            button: true,
            label: [
              DateFormat.MMMMEEEEd(locale).format(day),
              if (marked) l10n.trainingScheduleHasClasses,
            ].join(', '),
            excludeSemantics: true,
            child: Material(
              color: selected ? cs.primary : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => widget.onSelected(day),
                child: SizedBox(
                  width: 52,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        i == 0 ? l10n.commonToday : DateFormat.E(locale).format(day),
                        style: ts.labelSmall?.copyWith(color: fg),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat.d(locale).format(day),
                        style: ts.titleMedium?.copyWith(
                            color: fg, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: marked
                              ? (selected ? cs.onPrimary : cs.primary)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Capacity ──────────────────────────────────────────────────────────────────

class CapacityBar extends StatelessWidget {
  const CapacityBar({super.key, required this.gymClass, this.dense = true});

  final GymClass gymClass;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final c = gymClass;
    final ratio = c.capacity == 0 ? 0.0 : (c.bookedCount / c.capacity).clamp(0.0, 1.0);
    final l10n = context.l10n;
    final color = c.isFull ? cs.error : (ratio >= 0.8 ? cs.tertiary : cs.primary);
    final label = c.isFull
        ? (c.waitlistCount > 0
            ? l10n.trainingClassFullWaiting(c.waitlistCount)
            : l10n.trainingClassFull)
        : l10n.trainingClassSpotsLeft(c.spotsLeft);
    final booked = l10n.trainingClassBookedOf(c.bookedCount, c.capacity);
    return MergeSemantics(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            semanticsLabel: l10n.trainingClassCapacity,
            value: ratio,
            minHeight: dense ? 5 : 8,
            color: color,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(booked,
                style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            const Spacer(),
            Text(label, style: ts.labelSmall?.copyWith(color: color)),
          ],
        ),
      ],
      ),
    );
  }
}

// ── Booking action ────────────────────────────────────────────────────────────

/// What the booking button should show for a class, from the caller's view.
enum BookingAction { book, joinWaitlist, cancelBooking, leaveWaitlist, full, none }

BookingAction bookingActionFor(GymClass c) {
  if (c.isCancelled || c.hasStarted) return BookingAction.none;
  switch (c.myBookingStatus) {
    case BookingStatus.booked:
      return BookingAction.cancelBooking;
    case BookingStatus.waitlisted:
      return BookingAction.leaveWaitlist;
    case BookingStatus.attended:
    case BookingStatus.noShow:
      return BookingAction.none;
    case BookingStatus.cancelled:
    case null:
      // Coaches manage the class rather than book it.
      if (c.canCoach) return c.isFull ? BookingAction.full : BookingAction.none;
      return c.isFull ? BookingAction.joinWaitlist : BookingAction.book;
  }
}

/// Book / Join waitlist / Cancel booking / Waitlisted #n / Full.
class BookingButton extends StatelessWidget {
  const BookingButton({
    super.key,
    required this.gymClass,
    required this.busy,
    required this.onBook,
    required this.onCancel,
    this.expanded = false,
  });

  final GymClass gymClass;
  final bool busy;
  final VoidCallback onBook;
  final VoidCallback onCancel;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final action = bookingActionFor(gymClass);
    if (action == BookingAction.none) return const SizedBox.shrink();

    final spinner = SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
    );

    Widget button;
    switch (action) {
      case BookingAction.book:
        button = FilledButton(
          onPressed: busy ? null : onBook,
          child: busy ? spinner : Text(l10n.trainingClassBook),
        );
      case BookingAction.joinWaitlist:
        button = FilledButton.tonal(
          onPressed: busy ? null : onBook,
          child: busy ? spinner : Text(l10n.trainingClassJoinWaitlist),
        );
      case BookingAction.cancelBooking:
        button = OutlinedButton(
          onPressed: busy ? null : onCancel,
          child: busy ? spinner : Text(l10n.trainingClassCancelBooking),
        );
      case BookingAction.leaveWaitlist:
        final pos = gymClass.myWaitlistPosition;
        button = OutlinedButton.icon(
          onPressed: busy ? null : onCancel,
          icon: busy ? spinner : const Icon(Icons.hourglass_top, size: 18),
          label: Text(pos != null
              ? l10n.trainingClassWaitlistedPosition(pos)
              : l10n.trainingBookingWaitlisted),
        );
      case BookingAction.full:
        button = Chip(
          label: Text(l10n.trainingClassFull),
          labelStyle: TextStyle(color: cs.onErrorContainer),
          backgroundColor: cs.errorContainer,
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
        );
      case BookingAction.none:
        button = const SizedBox.shrink();
    }
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Status pill for the caller's own booking (Booked / Waitlisted / Attended…).
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({super.key, required this.status, this.position});

  final BookingStatus status;
  final int? position;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      BookingStatus.booked => (cs.primaryContainer, cs.onPrimaryContainer),
      BookingStatus.attended => (cs.secondaryContainer, cs.onSecondaryContainer),
      BookingStatus.waitlisted => (cs.tertiaryContainer, cs.onTertiaryContainer),
      BookingStatus.noShow => (cs.errorContainer, cs.onErrorContainer),
      BookingStatus.cancelled => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    final text = status == BookingStatus.waitlisted && position != null
        ? context.l10n.trainingClassWaitlistedPosition(position!)
        : status.label(context.l10n);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}

// ── Class card ────────────────────────────────────────────────────────────────

/// A class in a list: time, title, trainer, gym, capacity and booking button.
class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.gymClass,
    required this.onTap,
    this.showGym = false,
    this.showDate = false,
    this.busy = false,
    this.onBook,
    this.onCancel,
  });

  final GymClass gymClass;
  final VoidCallback onTap;
  final bool showGym;
  final bool showDate;
  final bool busy;

  /// Null hides the booking button (e.g. trainer views).
  final VoidCallback? onBook;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final c = gymClass;
    final muted = ts.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final subtitle = [
      if (c.trainerName != null) c.trainerName!,
      if (showGym) c.gymName,
      if (c.location != null) c.location!,
    ].join(' · ');
    // The waitlist button already shows "Waitlisted #n"; don't repeat it.
    final showStatus = c.myBookingStatus != null &&
        !(c.myBookingStatus == BookingStatus.waitlisted &&
            onBook != null &&
            bookingActionFor(c) != BookingAction.none);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDate)
                          Text(DateFormat.MEd(localeOf(context)).format(c.startsAt),
                              style: ts.labelSmall?.copyWith(color: cs.primary)),
                        Text(formatTime(context, c.startsAt),
                            style: ts.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        Text(formatDuration(context, c.duration), style: muted),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.title,
                                style: ts.titleMedium?.copyWith(
                                  decoration: c.isCancelled
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (c.isSeries)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Tooltip(
                                  message: l10n.trainingClassWeekly,
                                  child: Icon(Icons.repeat,
                                      size: 16, color: cs.onSurfaceVariant),
                                ),
                              ),
                          ],
                        ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(subtitle, style: muted),
                          ),
                        if (c.isCancelled)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(l10n.trainingClassCancelled,
                                style: ts.labelMedium?.copyWith(color: cs.error)),
                          )
                        else if (showStatus)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: BookingStatusChip(
                              status: c.myBookingStatus!,
                              position: c.myWaitlistPosition,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!c.isCancelled) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: CapacityBar(gymClass: c)),
                    if (onBook != null && onCancel != null &&
                        bookingActionFor(c) != BookingAction.none) ...[
                      const SizedBox(width: 12),
                      BookingButton(
                        gymClass: c,
                        busy: busy,
                        onBook: onBook!,
                        onCancel: onCancel!,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Generic yes/no confirmation dialog.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final cs = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(context.l10n.trainingClassKeep),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: cs.error, foregroundColor: cs.onError)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

String errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

/// Books [c] (or joins its waitlist), or — after confirming — cancels the
/// caller's booking / leaves the waitlist. Shows a snackbar with the result.
/// Returns true when something changed and the caller should reload.
Future<bool> toggleClassBooking(BuildContext context, GymClass c) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final cancelling = c.hasActiveBooking;
  if (cancelling) {
    final waitlisted = c.myBookingStatus == BookingStatus.waitlisted;
    final ok = await confirmDialog(
      context,
      title: waitlisted
          ? l10n.trainingClassLeaveWaitlistQuestion
          : l10n.trainingClassCancelBookingQuestion,
      message: waitlisted
          ? l10n.trainingClassLeaveWaitlistMessage(c.title)
          : l10n.trainingClassCancelBookingMessage(c.title),
      confirmLabel:
          waitlisted ? l10n.trainingClassLeaveWaitlist : l10n.trainingClassCancelBooking,
      destructive: true,
    );
    if (!ok) return false;
  }
  try {
    final token = await AuthManager.instance.getValidToken();
    final api = ApiService();
    if (cancelling) {
      await api.cancelClassBooking(token, c.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.trainingClassBookingCancelled)));
    } else {
      final b = await api.bookClass(token, c.id);
      messenger.showSnackBar(SnackBar(
        content: Text(b.status == BookingStatus.waitlisted
            ? (b.waitlistPosition != null
                ? l10n.trainingClassWaitlistJoined(b.waitlistPosition!)
                : l10n.trainingClassWaitlistJoinedNoPosition)
            : l10n.trainingClassBookedFor(c.title)),
      ));
    }
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    return true; // state may have changed server-side; reload anyway
  }
}

/// Small "On now" pill for shifts in progress.
class NowPill extends StatelessWidget {
  const NowPill({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(context.l10n.trainingShiftOnNow,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: cs.onTertiaryContainer)),
    );
  }
}
