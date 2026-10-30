// Month arithmetic and day grouping for the archive calendar. Everything is
// in local time: a story posted at 00:30 belongs to the day the user saw.

/// The first moment of [d]'s month (local).
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

/// The month after [month] (local); with [delta], that many months on (or back).
DateTime addMonths(DateTime month, int delta) => DateTime(month.year, month.month + delta);

/// [d]'s day at local midnight.
DateTime dayOf(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// The archive can't go past the current month.
bool canGoToNextMonth(DateTime month, DateTime now) => !addMonths(month, 1).isAfter(monthOf(now));

/// [items] by local day, keeping their order within each day.
Map<DateTime, List<T>> groupByDay<T>(Iterable<T> items, DateTime Function(T item) at) {
  final out = <DateTime, List<T>>{};
  for (final item in items) {
    (out[dayOf(at(item))] ??= []).add(item);
  }
  return out;
}

/// The weeks of [month] as rows of seven days starting on [firstWeekday];
/// days outside the month are null.
List<List<DateTime?>> monthGrid(DateTime month, {int firstWeekday = DateTime.monday}) {
  final first = monthOf(month);
  final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
  final lead = (first.weekday - firstWeekday) % 7;
  final cells = <DateTime?>[
    for (var i = 0; i < lead; i++) null,
    for (var d = 1; d <= daysInMonth; d++) DateTime(first.year, first.month, d),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
}
