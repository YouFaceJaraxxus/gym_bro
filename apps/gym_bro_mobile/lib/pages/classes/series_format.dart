import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/class_series.dart';
import 'schedule_widgets.dart';

// How a class's timetable reads, shared by every screen that lists classes.

/// Localized short weekday name for an ISO weekday (1 = Monday).
String weekdayShort(BuildContext context, int isoDay) =>
    // 2024-01-01 was a Monday.
    DateFormat.E(localeOf(context)).format(DateTime(2024, 1, isoDay));

/// "HH:MM" from the API as a clock time in the user's locale.
String formatSeriesTime(BuildContext context, String hhmm) {
  final p = hhmm.split(':');
  final t = TimeOfDay(
    hour: int.tryParse(p[0]) ?? 0,
    minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
  );
  return t.format(context);
}

/// "Mon, Wed, Fri" / "Every day" / "Once on Oct 30".
String seriesDaysSummary(BuildContext context, ClassSeries s) {
  final l10n = context.l10n;
  return switch (s.repeat) {
    ClassRepeat.none => l10n.classSeriesOnceOn(
      DateFormat.MMMd(localeOf(context)).format(s.startsOn),
    ),
    ClassRepeat.daily => l10n.classSeriesEveryDay,
    ClassRepeat.weekly =>
      s.weekdays.map((d) => weekdayShort(context, d)).join(', '),
  };
}

/// "Mon, Wed, Fri · 7:00 AM, 6:30 PM · 45 min".
String seriesScheduleSummary(BuildContext context, ClassSeries s) => [
  seriesDaysSummary(context, s),
  s.times.map((t) => formatSeriesTime(context, t)).join(', '),
  formatDuration(context, Duration(minutes: s.durationMinutes)),
].join(' · ');
