import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';

/// A Google-Calendar-style week/day view for any timed items: a month header
/// with week navigation, a 7-day strip (a dot on days with entries) and a day
/// timeline where each entry is a block sized by its duration. Overlapping
/// entries sit side by side. Swipe the timeline sideways to change day, pull
/// down to reload. Weeks are loaded on demand and cached until
/// [CalendarViewState.refresh].
///
/// The calendar knows nothing about the items: [CalendarView.describe] turns
/// each one into a [CalendarEntry] (times, title, extra lines, state, colour).
///
/// ```dart
/// CalendarView<Shift>(
///   load: (from, to) => api.getShifts(token, from: from, to: to),
///   describe: (s) => CalendarEntry(
///     start: s.startsAt,
///     end: s.endsAt,
///     title: s.staffName,
///     lines: [if (s.note != null) s.note!],
///     state: s.endsAt.isBefore(DateTime.now())
///         ? CalendarEntryState.done
///         : CalendarEntryState.upcoming,
///   ),
///   onTap: (s) => Navigator.push(context, ShiftPage.route(s)),
/// )
/// ```
///
/// An entry shows on the day it starts and is cut off at midnight. With
/// [CalendarView.onSlotTap], tapping empty time opens that hour (e.g. to add
/// something there); the slot stays highlighted until the future completes.
class CalendarView<T> extends StatefulWidget {
  const CalendarView({
    super.key,
    required this.load,
    required this.describe,
    this.onTap,
    this.onSlotTap,
    this.slotSemanticsLabel,
    this.filter,
    this.blockBuilder,
    this.initialDay,
    this.firstWeekday = DateTime.monday,
    this.emptyDayText,
    this.daySemanticsLabel,
    this.headerActions = const [],
    this.defaultScrollHour = 7,
  }) : assert(
         firstWeekday >= DateTime.monday && firstWeekday <= DateTime.sunday,
       );

  /// Loads one week: [from] is the first day 00:00, [to] seven days later.
  final Future<List<T>> Function(DateTime from, DateTime to) load;

  /// How an item looks and where it sits. Called on every build, so it may
  /// read state that changes without reloading (e.g. "is this mine?").
  final CalendarEntry Function(T item) describe;

  /// Opens an item; the item's week reloads once the future completes. Null
  /// makes the calendar read-only.
  final Future<void> Function(T item)? onTap;

  /// Opens an empty hour, given its start (local); completes with whether
  /// something was added (the week then reloads). Null: empty time does nothing.
  final Future<bool> Function(DateTime slot)? onSlotTap;

  /// Screen-reader label for an hour slot, given its formatted time ("6 PM").
  final String Function(String time)? slotSemanticsLabel;

  /// Which loaded items to show (applied without reloading).
  final bool Function(T item)? filter;

  /// Replaces the default [CalendarBlock] for an item.
  final Widget Function(
    BuildContext context,
    T item,
    CalendarEntry entry,
    VoidCallback? onTap,
  )?
  blockBuilder;

  final DateTime? initialDay;

  /// The week starts on this day ([DateTime.monday] … [DateTime.sunday]).
  final int firstWeekday;

  /// Shown on a day with nothing on it; defaults to a generic message.
  final String? emptyDayText;

  /// Screen-reader label for a day in the week strip, given the formatted
  /// date and how many entries it has; defaults to a generic count.
  final String Function(String day, int count)? daySemanticsLabel;

  /// Extra buttons in the header, after the week navigation.
  final List<Widget> headerActions;

  /// Hour scrolled to on an empty day that isn't today.
  final double defaultScrollHour;

  @override
  State<CalendarView<T>> createState() => CalendarViewState<T>();
}

/// The look of an entry: done ones are muted with a check, cancelled ones
/// struck through, upcoming ones filled ([CalendarEntry.highlighted]) or
/// outlined and faded.
enum CalendarEntryState { upcoming, done, cancelled }

/// What the calendar needs to draw one item.
class CalendarEntry {
  const CalendarEntry({
    required this.start,
    required this.end,
    required this.title,
    this.lines = const [],
    this.state = CalendarEntryState.upcoming,
    this.highlighted = true,
    this.color,
    this.icon,
    this.semanticLabel,
  });

  /// Local times.
  final DateTime start;
  final DateTime end;
  final String title;

  /// Shown under the time range, one line each (clipped when the block is short).
  final List<String> lines;
  final CalendarEntryState state;

  /// Upcoming entries: filled when true, outlined and faded when false (e.g.
  /// bookable classes that aren't mine).
  final bool highlighted;

  /// Accent for an upcoming entry (the fill and edge when highlighted, the
  /// outline when not); defaults to the primary colour.
  final Color? color;

  /// Shown before the title (e.g. what kind of item it is), in [color].
  final IconData? icon;

  /// Screen-reader label; defaults to title, time, lines and state.
  final String? semanticLabel;
}

/// Lays out time spans (minutes from midnight, sorted by start) in columns:
/// spans that overlap, directly or through others, share the width. Returns
/// each span's column and how many columns its group has.
List<({int column, int columns})> calendarColumns(
  List<({double start, double end})> spans,
) {
  final out = List<({int column, int columns})>.filled(spans.length, (
    column: 0,
    columns: 1,
  ));
  var group = <int>[];
  var groupEnd = double.negativeInfinity;

  void flush() {
    if (group.isEmpty) return;
    final columnEnds = <double>[];
    final columnOf = <int, int>{};
    for (final i in group) {
      var col = columnEnds.indexWhere((end) => end <= spans[i].start);
      if (col == -1) {
        col = columnEnds.length;
        columnEnds.add(0);
      }
      columnEnds[col] = spans[i].end;
      columnOf[i] = col;
    }
    for (final i in group) {
      out[i] = (column: columnOf[i]!, columns: columnEnds.length);
    }
    group = [];
  }

  for (var i = 0; i < spans.length; i++) {
    if (group.isNotEmpty && spans[i].start >= groupEnd) flush();
    groupEnd = group.isEmpty
        ? spans[i].end
        : (spans[i].end > groupEnd ? spans[i].end : groupEnd);
    group.add(i);
  }
  flush();
  return out;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _locale(BuildContext context) =>
    Localizations.localeOf(context).toString();

/// "6:00 PM – 7:00 PM" in the user's locale, marked when it ends the next day.
String calendarTimeRange(BuildContext context, DateTime start, DateTime end) {
  final fmt = DateFormat.jm(_locale(context));
  final range = '${fmt.format(start)} – ${fmt.format(end)}';
  return _sameDay(start, end) ? range : context.l10n.calendarNextDay(range);
}

class CalendarViewState<T> extends State<CalendarView<T>> {
  static const _gutter = 52.0;
  static const _minBlock = 28.0;

  late DateTime _day = _dateOnly(widget.initialDay ?? DateTime.now());
  final Map<DateTime, List<T>> _weeks = {};
  final Set<DateTime> _loading = {};
  final Map<DateTime, String> _errors = {};
  final _scroll = ScrollController();
  Timer? _clock;
  DateTime? _scrolledFor;

  /// The hour opened through [CalendarView.onSlotTap], highlighted until done.
  DateTime? _activeSlot;

  /// The day on screen.
  DateTime get day => _day;

  DateTime _weekOf(DateTime d) {
    final back = (d.weekday - widget.firstWeekday + 7) % 7;
    return DateTime(d.year, d.month, d.day - back);
  }

  DateTime get _weekStart => _weekOf(_day);

  @override
  void initState() {
    super.initState();
    // First load after the first frame (it calls setState).
    _loading.add(_weekStart);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureWeek(_weekStart, force: true);
    });
    // Keeps the now-line moving.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Drops every cached week and reloads the one on screen.
  Future<void> refresh() async {
    _weeks.clear();
    _errors.clear();
    _scrolledFor = null;
    await _ensureWeek(_weekStart, force: true);
  }

  /// Shows [day] (loading its week if needed).
  void showDay(DateTime day) {
    final d = _dateOnly(day);
    if (_sameDay(d, _day)) return;
    setState(() => _day = d);
    _ensureWeek(_weekOf(d));
  }

  Future<void> _ensureWeek(DateTime weekStart, {bool force = false}) async {
    final cached =
        _weeks.containsKey(weekStart) || _loading.contains(weekStart);
    if (!force && cached) return;
    setState(() {
      _loading.add(weekStart);
      _errors.remove(weekStart);
    });
    try {
      final items = await widget.load(
        weekStart,
        DateTime(weekStart.year, weekStart.month, weekStart.day + 7),
      );
      if (!mounted) return;
      items.sort(
        (a, b) => widget.describe(a).start.compareTo(widget.describe(b).start),
      );
      setState(() => _weeks[weekStart] = items);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errors[weekStart] = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loading.remove(weekStart));
    }
  }

  Future<void> _open(T item, CalendarEntry entry) async {
    await widget.onTap!(item);
    if (!mounted) return;
    final week = _weekOf(entry.start);
    _weeks.remove(week);
    _scrolledFor = _day; // keep the scroll position on return
    await _ensureWeek(week, force: true);
  }

  Future<void> _openSlot(DateTime slot) async {
    setState(() => _activeSlot = slot);
    var changed = false;
    try {
      changed = await widget.onSlotTap!(slot);
    } finally {
      if (mounted) setState(() => _activeSlot = null);
    }
    if (!changed || !mounted) return;
    final week = _weekOf(slot);
    _weeks.remove(week);
    _scrolledFor = _day; // keep the scroll position on return
    await _ensureWeek(week, force: true);
  }

  List<(T, CalendarEntry)> _entriesOn(DateTime day) {
    final week = _weeks[_weekOf(day)] ?? <T>[];
    return [
      for (final item in week)
        if (widget.filter?.call(item) ?? true)
          if (widget.describe(item) case final e when _sameDay(e.start, day))
            (item, e),
    ];
  }

  double _hourHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(60).clamp(60.0, 110.0);

  /// Scrolls to the first entry of the day, or to now on today, once per day shown.
  void _autoScroll(double hourHeight, List<(T, CalendarEntry)> entries) {
    if (_scrolledFor != null && _sameDay(_scrolledFor!, _day)) return;
    if (!_weeks.containsKey(_weekStart)) return;
    _scrolledFor = _day;
    final now = DateTime.now();
    final hour = entries.isNotEmpty
        ? entries.first.$2.start.hour + entries.first.$2.start.minute / 60
        : _sameDay(_day, now)
        ? now.hour + now.minute / 60
        : widget.defaultScrollHour;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = ((hour - 0.75) * hourHeight).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        _buildWeekStrip(context),
        const Divider(height: 1),
        Expanded(child: _buildDay(context)),
      ],
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final l10n = context.l10n;
    final ts = Theme.of(context).textTheme;
    final isToday = _sameDay(_day, DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                DateFormat.yMMMM(_locale(context)).format(_day),
                style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (!isToday)
            Tooltip(
              message: l10n.calendarGoToToday,
              child: TextButton(
                onPressed: () => showDay(DateTime.now()),
                child: Text(l10n.commonToday),
              ),
            ),
          IconButton(
            tooltip: l10n.calendarPreviousWeek,
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                showDay(DateTime(_day.year, _day.month, _day.day - 7)),
          ),
          IconButton(
            tooltip: l10n.calendarNextWeek,
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                showDay(DateTime(_day.year, _day.month, _day.day + 7)),
          ),
          ...widget.headerActions,
        ],
      ),
    );
  }

  // ── Week strip ──────────────────────────────────────────────────────────────

  Widget _buildWeekStrip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = _locale(context);
    final today = _dateOnly(DateTime.now());
    final start = _weekStart;
    final days = List.generate(
      7,
      (i) => DateTime(start.year, start.month, start.day + i),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Row(
        children: [
          for (final d in days)
            Expanded(
              child: Builder(
                builder: (context) {
                  final selected = _sameDay(d, _day);
                  final isToday = _sameDay(d, today);
                  final count = _entriesOn(d).length;
                  final fg = selected
                      ? cs.onPrimary
                      : (isToday ? cs.primary : cs.onSurface);
                  final dayText = DateFormat.MMMMEEEEd(locale).format(d);
                  return Semantics(
                    button: true,
                    selected: selected,
                    label:
                        widget.daySemanticsLabel?.call(dayText, count) ??
                        l10n.calendarDayLabel(dayText, count),
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showDay(d),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              child: Text(
                                DateFormat.EEEEE(locale).format(d),
                                style: ts.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected ? cs.primary : null,
                                border: isToday && !selected
                                    ? Border.all(color: cs.primary, width: 1.5)
                                    : null,
                              ),
                              child: FittedBox(
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Text(
                                    '${d.day}',
                                    style: ts.titleSmall?.copyWith(
                                      color: fg,
                                      fontWeight: selected || isToday
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: count > 0
                                    ? cs.primary
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ── Day timeline ────────────────────────────────────────────────────────────

  Widget _buildDay(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final hourHeight = _hourHeight(context);
    final week = _weekStart;
    final error = _errors[week];
    final loading = _loading.contains(week);
    final entries = _entriesOn(_day);
    _autoScroll(hourHeight, entries);

    if (error != null && !_weeks.containsKey(week)) {
      return _CalendarError(
        message: error,
        onRetry: () => _ensureWeek(week, force: true),
      );
    }

    final timeline = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 250) return;
        showDay(DateTime(_day.year, _day.month, _day.day + (v < 0 ? 1 : -1)));
      },
      child: RefreshIndicator(
        onRefresh: refresh,
        child: SingleChildScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: hourHeight * 24 + 16,
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  ..._hourLines(context, hourHeight),
                  if (widget.onSlotTap != null) ..._slots(context, hourHeight),
                  ..._blocks(
                    context,
                    entries,
                    hourHeight,
                    box.maxWidth - _gutter - 8,
                  ),
                  if (_sameDay(_day, DateTime.now()))
                    _nowLine(context, hourHeight),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        timeline,
        if (loading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (!loading && entries.isEmpty && _weeks.containsKey(week))
          Positioned(
            left: _gutter + 8,
            right: 8,
            top: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.emptyDayText ?? l10n.calendarNothingOnDay,
                  style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _hourLines(BuildContext context, double hourHeight) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final fmt = DateFormat.j(_locale(context));
    return [
      for (var h = 0; h < 24; h++) ...[
        Positioned(
          left: _gutter,
          right: 0,
          top: h * hourHeight + 8,
          child: Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        if (h > 0)
          Positioned(
            left: 0,
            width: _gutter - 6,
            top: h * hourHeight + 8 - 8,
            child: ExcludeSemantics(
              child: Text(
                fmt.format(DateTime(2000, 1, 1, h)),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),
      ],
    ];
  }

  /// One tappable row per hour, under the entries (which win the tap).
  List<Widget> _slots(BuildContext context, double hourHeight) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat.j(_locale(context));
    return [
      for (var h = 0; h < 24; h++)
        Builder(
          builder: (context) {
            final slot = DateTime(_day.year, _day.month, _day.day, h);
            final active = _activeSlot == slot;
            final time = fmt.format(slot);
            return Positioned(
              left: _gutter,
              right: 0,
              top: h * hourHeight + 8 + 1,
              height: hourHeight - 1,
              child: Semantics(
                button: true,
                label: widget.slotSemanticsLabel?.call(time) ?? time,
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _activeSlot == null ? () => _openSlot(slot) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                    alignment: AlignmentDirectional.topStart,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: active
                          ? cs.primary.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: active ? Border.all(color: cs.primary) : null,
                    ),
                    child: active
                        ? Icon(Icons.add, size: 18, color: cs.primary)
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
    ];
  }

  Widget _nowLine(BuildContext context, double hourHeight) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final top = (now.hour + now.minute / 60) * hourHeight + 8;
    return Positioned(
      left: _gutter - 5,
      right: 0,
      top: top - 5,
      child: IgnorePointer(
        child: Semantics(
          label: context.l10n.calendarNow(
            DateFormat.jm(_locale(context)).format(now),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: cs.error,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(child: Container(height: 2, color: cs.error)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _blocks(
    BuildContext context,
    List<(T, CalendarEntry)> entries,
    double hourHeight,
    double width,
  ) {
    if (entries.isEmpty || width <= 0) return const [];
    final dayStart = _dateOnly(_day);
    double minutesOf(DateTime t) =>
        t.difference(dayStart).inMinutes.clamp(0, 24 * 60).toDouble();
    final spans = [
      for (final (_, e) in entries)
        (
          start: minutesOf(e.start),
          end: minutesOf(
            e.end,
          ).clamp(minutesOf(e.start) + 1, 24 * 60).toDouble(),
        ),
    ];
    final layout = calendarColumns(spans);
    return [
      for (var i = 0; i < entries.length; i++)
        Builder(
          builder: (context) {
            final (item, entry) = entries[i];
            final colWidth = width / layout[i].columns;
            final height =
                ((spans[i].end - spans[i].start) / 60 * hourHeight).clamp(
                  _minBlock,
                  double.infinity,
                ) -
                2;
            final onTap = widget.onTap == null
                ? null
                : () => _open(item, entry);
            return Positioned(
              left: _gutter + 4 + layout[i].column * colWidth,
              width: colWidth - 3,
              top: spans[i].start / 60 * hourHeight + 8 + 1,
              height: height,
              child:
                  widget.blockBuilder?.call(context, item, entry, onTap) ??
                  CalendarBlock(entry: entry, onTap: onTap),
            );
          },
        ),
    ];
  }
}

/// The default look of an entry in [CalendarView]; also usable from a
/// custom `blockBuilder` (e.g. to wrap it).
class CalendarBlock extends StatelessWidget {
  const CalendarBlock({super.key, required this.entry, this.onTap});

  final CalendarEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final cancelled = e.state == CalendarEntryState.cancelled;
    final done = e.state == CalendarEntryState.done;
    final accent = e.color ?? cs.primary;

    final (Color bg, Color fg, Color? border) = cancelled
        ? (cs.errorContainer.withValues(alpha: 0.55), cs.onErrorContainer, null)
        : done
        ? (cs.surfaceContainerHighest, cs.onSurfaceVariant, null)
        : e.highlighted
        ? (
            e.color == null
                ? cs.primaryContainer
                : accent.withValues(alpha: 0.18),
            e.color == null ? cs.onPrimaryContainer : cs.onSurface,
            accent,
          )
        : (
            cs.surface,
            cs.onSurfaceVariant,
            e.color?.withValues(alpha: 0.7) ?? cs.outlineVariant,
          );

    final time = calendarTimeRange(context, e.start, e.end);
    final semantics =
        e.semanticLabel ??
        [
          e.title,
          time,
          ...e.lines,
          if (cancelled) l10n.calendarCancelled,
          if (done) l10n.calendarDone,
        ].join(', ');

    return Semantics(
      button: onTap != null,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: border == null
                  ? null
                  : e.highlighted && !done && !cancelled
                  ? Border(left: BorderSide(color: border, width: 3))
                  : Border.all(color: border),
              borderRadius: e.highlighted ? null : BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minHeight: 0,
                maxHeight: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (done) ...[
                          Icon(Icons.check_circle, size: 14, color: fg),
                          const SizedBox(width: 4),
                        ],
                        if (cancelled) ...[
                          Icon(Icons.event_busy, size: 14, color: fg),
                          const SizedBox(width: 4),
                        ],
                        if (e.icon != null) ...[
                          Icon(
                            e.icon,
                            size: 14,
                            color: done || cancelled || e.color == null
                                ? fg
                                : accent,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ts.labelLarge?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w600,
                              decoration: cancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    for (final line in [time, ...e.lines])
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts.labelSmall?.copyWith(color: fg),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarError extends StatelessWidget {
  const _CalendarError({required this.message, required this.onRetry});

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
          message,
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
