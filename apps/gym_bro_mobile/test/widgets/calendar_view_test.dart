import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/widgets/calendar_view.dart';

typedef _Item = ({String title, DateTime start, DateTime end, bool hidden});

_Item _item(String title, DateTime start, int minutes, {bool hidden = false}) =>
    (
      title: title,
      start: start,
      end: start.add(Duration(minutes: minutes)),
      hidden: hidden,
    );

void main() {
  group('calendarColumns', () {
    test(
      'overlapping spans share columns; separate ones get the full width',
      () {
        final layout = calendarColumns([
          (start: 540, end: 600), // 09:00–10:00
          (start: 570, end: 630), // 09:30–10:30
          (start: 660, end: 720), // 11:00–12:00
        ]);
        expect(layout, [
          (column: 0, columns: 2),
          (column: 1, columns: 2),
          (column: 0, columns: 1),
        ]);
      },
    );

    test('a chain of overlaps is one group, and freed columns are reused', () {
      final layout = calendarColumns([
        (start: 0, end: 60),
        (start: 30, end: 90),
        (
          start: 70,
          end: 120,
        ), // overlaps only the second; column 0 is free again
      ]);
      expect(layout, [
        (column: 0, columns: 2),
        (column: 1, columns: 2),
        (column: 0, columns: 2),
      ]);
    });
  });

  group('CalendarView', () {
    // A Monday well away from today, so no now-line or "today" logic interferes.
    final monday = DateTime(2030, 1, 7);
    final items = [
      _item('Alpha', monday.add(const Duration(hours: 9)), 60),
      _item('Bravo', monday.add(const Duration(hours: 9, minutes: 30)), 60),
      _item('Hidden', monday.add(const Duration(hours: 10)), 30, hidden: true),
      _item('Tuesday', monday.add(const Duration(days: 1, hours: 9)), 60),
    ];

    Future<List<(DateTime, DateTime)>> pump(
      WidgetTester tester, {
      void Function(_Item)? onTap,
      int firstWeekday = DateTime.monday,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final loads = <(DateTime, DateTime)>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarView<_Item>(
              initialDay: monday,
              firstWeekday: firstWeekday,
              load: (from, to) async {
                loads.add((from, to));
                return [...items];
              },
              describe: (i) => CalendarEntry(
                start: i.start,
                end: i.end,
                title: i.title,
                lines: ['Room ${i.title}'],
              ),
              filter: (i) => !i.hidden,
              onTap: onTap == null ? null : (i) async => onTap(i),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return loads;
    }

    testWidgets('loads the week, shows the day through describe and filter', (
      tester,
    ) async {
      final loads = await pump(tester);
      expect(loads.single, (monday, DateTime(2030, 1, 14)));
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Bravo'), findsOneWidget);
      expect(find.text('Room Alpha'), findsOneWidget);
      expect(find.text('Hidden'), findsNothing, reason: 'filtered out');
      expect(find.text('Tuesday'), findsNothing, reason: 'another day');

      // Overlapping blocks sit side by side.
      final a = tester.getTopLeft(find.text('Alpha'));
      final b = tester.getTopLeft(find.text('Bravo'));
      expect(b.dx, greaterThan(a.dx));
    });

    testWidgets('tapping opens the item and reloads its week', (tester) async {
      _Item? tapped;
      final loads = await pump(tester, onTap: (i) => tapped = i);
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(tapped?.title, 'Alpha');
      expect(loads.length, 2);
    });

    testWidgets('weeks can start on Sunday', (tester) async {
      final loads = await pump(tester, firstWeekday: DateTime.sunday);
      expect(loads.single.$1, DateTime(2030, 1, 6));
    });
  });
}
