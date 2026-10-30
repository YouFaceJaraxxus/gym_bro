import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/pages/archive/archive_page.dart';
import 'package:gym_bro_mobile/services/auth_manager.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_fixtures.dart';
import '../helpers/fake_backend.dart';

// The archive page: both tabs load the visible month, show what's there on
// the calendar and below it, and say when a month is empty.
Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  late FakeBackend backend;
  final now = DateTime.now();
  final at = now.toUtc().toIso8601String();

  setUpAll(() async {
    await initializeDateFormatting();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    backend = FakeBackend()..install();
    await AuthManager.instance.setSession(signinJson(), profileData: profileJson(id: 'u-me', name: 'Liam'));
    await pumpEventQueue();
  });

  tearDownAll(() async {
    await AuthManager.instance.clear();
    backend.uninstall();
  });

  /// A tall phone, so the calendar and the list below it both fit.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Map<String, dynamic> story(String id, String caption, {bool live = true}) => {
    'id': id,
    'author_id': 'u-me',
    'media_type': null,
    'caption': caption,
    'background': '#2a9d8f',
    'share': null,
    'created_at': at,
    'expires_at': now.add(const Duration(hours: 24)).toUtc().toIso8601String(),
    'is_live': live,
    'seen': true,
    'is_mine': true,
    'view_count': 4,
    'reaction_count': 0,
  };

  testWidgets('stories tab: today has a thumbnail, the month lists them; posts tab is empty', (tester) async {
    phone(tester);
    backend
      ..on('GET /stories/archive', ok([story('s2', 'Deadlift PR'), story('s1', 'Morning run', live: false)]))
      ..on('GET /posts/archive', ok([]));
    await tester.pumpWidget(_app(const ArchivePage()));
    await tester.pumpAndSettle();

    final month = DateFormat.yMMMM('en').format(now);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text(month), findsOneWidget);
    expect(find.textContaining('Only you can see your archive.'), findsOneWidget);
    expect(find.text('All of $month'), findsOneWidget);
    // Two items today: the day cell shows a count.
    expect(find.text('2'), findsWidgets);
    // The grid: both stories, one still live.
    expect(find.text('Deadlift PR'), findsWidgets);
    expect(find.text('Morning run'), findsWidgets);
    expect(find.text('Live'), findsOneWidget);

    final storyQuery = backend.last('GET /stories/archive').url.queryParameters;
    expect(DateTime.parse(storyQuery['from']!).toLocal(), DateTime(now.year, now.month));
    expect(DateTime.parse(storyQuery['to']!).toLocal(), DateTime(now.year, now.month + 1));

    // Can't go past this month.
    final next = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right).first);
    expect(next.onPressed, isNull);

    await tester.tap(find.text('Posts'));
    await tester.pumpAndSettle();
    expect(find.text('No archived posts from $month'), findsOneWidget);
  });

  testWidgets('tapping a day narrows the list; the list view drops the calendar', (tester) async {
    phone(tester);
    backend
      ..on('GET /stories/archive', ok([story('s1', 'Morning run')]))
      ..on('GET /posts/archive', ok([]));
    await tester.pumpWidget(_app(const ArchivePage()));
    await tester.pumpAndSettle();

    final dayLabel = DateFormat.MMMMEEEEd('en').format(now);
    await tester.tap(find.bySemanticsLabel(RegExp('^${RegExp.escape(dayLabel)}, 1 item')));
    await tester.pumpAndSettle();
    expect(find.text(dayLabel), findsOneWidget);

    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Calendar'), findsOneWidget);
    expect(find.text('All of ${DateFormat.yMMMM('en').format(now)}'), findsOneWidget);
  });
}
