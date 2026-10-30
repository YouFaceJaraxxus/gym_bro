import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/food_log.dart' show dateOnly;
import 'package:gym_bro_mobile/widgets/calendar_view.dart';
import 'package:gym_bro_mobile/widgets/plan_enrolment.dart';

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  group('EnrolDialog', () {
    Future<void> open(
      WidgetTester tester, {
      required EnrolKind kind,
      required bool scheduled,
      Enrolment? existing,
    }) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<EnrolOptions>(
                  context: context,
                  builder: (_) => EnrolDialog(
                    kind: kind,
                    name: 'Deadlift Block',
                    scheduled: scheduled,
                    existing: existing,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'a fixed-weeks routine asks for a workout time and starts today at 18:00',
      (tester) async {
        await open(tester, kind: EnrolKind.routine, scheduled: true);
        expect(find.text('Start Deadlift Block'), findsOneWidget);
        expect(find.text('Workout time'), findsOneWidget);
        expect(find.text('No end date'), findsOneWidget);
        expect(find.text('6:00 PM'), findsOneWidget);
      },
    );

    testWidgets('Start pops the chosen options', (tester) async {
      late Future<EnrolOptions?> pending;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => pending = showDialog<EnrolOptions>(
                  context: context,
                  builder: (_) => const EnrolDialog(
                    kind: EnrolKind.routine,
                    name: 'X',
                    scheduled: true,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  early bird  ');
      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pumpAndSettle();

      final o = (await pending)!;
      expect(o.startDate, dateOnly(DateTime.now()));
      expect(o.endDate, isNull);
      expect(o.workoutTime, const TimeOfDay(hour: 18, minute: 0));
      expect(o.note, 'early bird');
    });

    testWidgets(
      'a wildcard routine explains it has no schedule and asks no time',
      (tester) async {
        await open(tester, kind: EnrolKind.routine, scheduled: false);
        expect(find.textContaining('no fixed days'), findsOneWidget);
        expect(find.text('Workout time'), findsNothing);
      },
    );

    testWidgets('managing prefills the enrolment and saves', (tester) async {
      await open(
        tester,
        kind: EnrolKind.routine,
        scheduled: true,
        existing: Enrolment(
          id: 'ra1',
          startDate: DateTime(2030, 1, 6),
          endDate: DateTime(2030, 3, 1),
          workoutTime: '06:30',
          note: 'Mornings',
          createdAt: DateTime(2030),
        ),
      );
      expect(find.text('Manage Deadlift Block'), findsOneWidget);
      expect(find.text('6:30 AM'), findsOneWidget);
      expect(find.text('Mornings'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    });

    testWidgets('a meal plan has no workout time', (tester) async {
      await open(tester, kind: EnrolKind.mealPlan, scheduled: true);
      expect(find.textContaining('usual times'), findsOneWidget);
      expect(find.text('Workout time'), findsNothing);
    });
  });

  testWidgets('CalendarBlock shows the kind icon, also once done', (
    tester,
  ) async {
    final start = DateTime(2030, 1, 7, 13);
    Future<void> pump(CalendarEntryState state) => tester.pumpWidget(
      _app(
        Scaffold(
          body: SizedBox(
            width: 200,
            height: 80,
            child: CalendarBlock(
              entry: CalendarEntry(
                start: start,
                end: start.add(const Duration(minutes: 45)),
                title: 'Lunch',
                state: state,
                highlighted: false,
                color: Colors.orange,
                icon: Icons.restaurant,
              ),
            ),
          ),
        ),
      ),
    );

    await pump(CalendarEntryState.upcoming);
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    await pump(CalendarEntryState.done);
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
