import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/training.dart';
import 'package:gym_bro_mobile/pages/session_log_page.dart';
import 'package:gym_bro_mobile/services/auth_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_fixtures.dart';
import '../helpers/fake_backend.dart';

// The live session screen with a planned bench press: last time's sets and a
// suggestion show up, empty weights are ghosted, one tap fills them in, and
// a PR set keeps a gold row with a trophy.
const _at = '2026-11-01T10:00:00.000Z';

Training _training() => Training.fromJson({
      'id': 't1',
      'name': 'Push',
      'is_public': false,
      'sets': [
        {
          'id': 'ts1',
          'training_id': 't1',
          'type': 'standard',
          'position': 0,
          'exercises': [
            {
              'id': 'tse1',
              'training_set_id': 'ts1',
              'exercise_id': 'ex-bench',
              'position': 0,
              'is_alternating': false,
              'exercise': {
                'id': 'ex-bench',
                'name': 'Bench Press',
                'primary_muscles': ['chest_all'],
                'secondary_muscles': ['triceps_all'],
                'created_at': _at,
                'updated_at': _at,
              },
              'drops': [
                for (var i = 0; i < 3; i++)
                  {
                    'id': 'd$i',
                    'training_set_exercise_id': 'tse1',
                    'drop_number': i,
                    'rep_type': 'count',
                    'rep_count': 8,
                    'weight_kg': null,
                    'side': 'both',
                  },
              ],
            },
          ],
        },
      ],
    });

Map<String, dynamic> _session() => {
      'id': 's1',
      'user_id': 'u-me',
      'training_id': 't1',
      'started_at': _at,
      'created_at': _at,
      'updated_at': _at,
    };

void main() {
  late FakeBackend backend;

  setUpAll(() async {
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

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SessionLogPage(training: _training()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Ends the page (and its elapsed-time ticker).
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('suggests from last time, fills it in, and keeps a PR row gold', (tester) async {
    backend.on('POST /training-sessions', ok(_session(), 201));
    backend.on('GET /training-sessions/last-sets', ok([
      {
        'exercise_id': 'ex-bench',
        'session_id': 'old',
        'started_at': DateTime.now().subtract(const Duration(days: 4)).toUtc().toIso8601String(),
        'sets': [
          for (var i = 0; i < 3; i++) {'weight_kg': '80', 'reps': 8, 'rep_type': 'count', 'side': 'both'},
        ],
      },
    ]));
    backend.on('POST /training-sessions/s1/sets', (req) => ok({
          'id': 'sl1',
          'session_id': 's1',
          'training_set_id': 'ts1',
          'position': 0,
          'drop_logs': [],
          'is_pr': true,
          'pr_e1rm': 104.5,
          'previous_e1rm': 101.3,
          'pr_exercise_id': 'ex-bench',
          'prs': [],
        }, 201));

    await open(tester);
    final query = backend.last('GET /training-sessions/last-sets').url.queryParameters;
    expect(query['exercise_ids'], 'ex-bench');
    expect(query.containsKey('user_id'), isFalse);

    expect(find.textContaining('Last: 80 kg × 8, 8, 8'), findsOneWidget);
    expect(find.textContaining('Try 82.5 kg × 8'), findsOneWidget);
    expect(find.text('Hit all reps last time → +2.5 kg'), findsOneWidget);
    // Empty weights show the suggestion as a hint.
    expect(find.widgetWithText(TextField, '82.5'), findsNWidgets(3));

    await tester.tap(find.text('Use'));
    await tester.pump();
    final weights = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((f) => f.controller!.text)
        .where((t) => t.contains('.'))
        .toList();
    expect(weights, ['82.5', '82.5', '82.5']);

    await tester.tap(find.text('Log Set'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final body = bodyOf(backend.last('POST /training-sessions/s1/sets')) as Map<String, dynamic>;
    expect([for (final d in body['drops'] as List) d['weight_kg_actual']], [82.5, 82.5, 82.5]);

    // The suggestion goes once the set is logged; one row turns gold.
    expect(find.textContaining('Try 82.5'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    await close(tester);
  });

  testWidgets('no history (or offline) → no chip, logging still works', (tester) async {
    backend.on('POST /training-sessions', ok(_session(), 201));
    backend.on('GET /training-sessions/last-sets', err(500, 'down'));
    await open(tester);
    expect(find.textContaining('Last:'), findsNothing);
    expect(find.text('Log Set'), findsOneWidget);
    await close(tester);
  });
}
