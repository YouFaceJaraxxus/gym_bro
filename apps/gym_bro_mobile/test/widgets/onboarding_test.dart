import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/user_settings.dart';
import 'package:gym_bro_mobile/pages/onboarding/onboarding_gate.dart';
import 'package:gym_bro_mobile/pages/onboarding/onboarding_page.dart';
import 'package:gym_bro_mobile/services/auth_manager.dart';
import 'package:gym_bro_mobile/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_fixtures.dart';
import '../helpers/fake_backend.dart';

// The first-run flow: what each step saves, skipping, and when the gate
// shows it.
void main() {
  late FakeBackend backend;
  late Map<String, dynamic> server; // the settings row on the "server"

  Map<String, dynamic> settingsJson() => {
        'push_enabled': true,
        'muted_types': [],
        'weight_unit': 'kg',
        'theme_mode': 'system',
        'locale': null,
        'weekly_workout_target': 3,
        'show_on_gym_boards': true,
        'fitness_goal': null,
        'goal_weight_kg': null,
        'water_goal_ml': null,
        'water_cups': [250, 500],
        'water_reminders': false,
        'onboarded_at': null,
      };

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

  setUp(() async {
    backend.requests.clear();
    server = settingsJson();
    await SettingsService.instance.reset();
    backend.on('GET /users/me/settings', (_) => ok(server));
    backend.on('PUT /users/me/settings', (req) {
      final changes = Map<String, dynamic>.from(bodyOf(req) as Map);
      final onboarded = changes.remove('onboarded');
      server = {...server, ...changes};
      if (onboarded == true) server['onboarded_at'] = '2026-11-01T10:00:00.000Z';
      return ok(server);
    });
    backend.on('GET /body-measurements', ok([]));
    backend.on('POST /body-measurements', (req) => ok({
          'id': 'm1',
          'user_id': 'u-me',
          'measured_on': '2026-11-01',
          'weight_kg': (bodyOf(req) as Map)['weight_kg'],
        }, 201));
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// A launcher page, so the flow can pop back to it.
  Future<void> open(WidgetTester tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Reduce motion: the welcome hero loops forever otherwise.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage())),
              child: const Text('launcher'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('launcher'));
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
  }

  List<Map> settingsPuts() => [
        for (final r in backend.requests)
          if ('${r.method} ${pathOf(r)}' == 'PUT /users/me/settings') bodyOf(r) as Map,
      ];

  testWidgets('walks through every step and saves each one', (tester) async {
    await open(tester);
    expect(find.text('Welcome to Gym Bro'), findsOneWidget);
    await next(tester);

    await tester.tap(find.text('Build muscle'));
    await tester.pumpAndSettle();
    await next(tester);

    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(find.text('5 days a week'), findsOneWidget);
    await next(tester);

    // A goal weight is suggested from the current one (+5% to build muscle).
    await tester.enterText(find.byKey(const ValueKey('onboarding-current-weight')), '80');
    await tester.pumpAndSettle();
    expect(find.text('84'), findsOneWidget);
    await next(tester);

    // Water: auto from 80 kg is 2.8 L; one step up makes it custom.
    expect(find.text('2.8 L'), findsOneWidget);
    await tester.tap(find.byTooltip('More water'));
    await tester.pumpAndSettle();
    expect(find.text('3.05 L'), findsOneWidget);
    await next(tester);

    expect(find.text("You're all set!"), findsOneWidget);
    expect(find.text('80 kg → 84 kg'), findsOneWidget);
    await next(tester);

    expect(find.text('launcher'), findsOneWidget, reason: 'the flow closed');
    final puts = settingsPuts();
    expect(puts, [
      {'fitness_goal': 'build_muscle'},
      {'weekly_workout_target': 5},
      {'goal_weight_kg': 84.0},
      {'water_goal_ml': 3050},
      {'onboarded': true},
    ]);
    expect(bodyOf(backend.last('POST /body-measurements')), {'weight_kg': 80.0});
    expect(SettingsService.instance.settings.value.onboardedAt, isNotNull);
  });

  testWidgets('skip marks the user onboarded without saving anything else', (tester) async {
    await open(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('launcher'), findsOneWidget);
    expect(settingsPuts(), [
      {'onboarded': true},
    ]);
  });

  testWidgets('an out-of-range weight stops on the body step', (tester) async {
    await open(tester);
    for (var i = 0; i < 3; i++) {
      await next(tester);
    }
    await tester.enterText(find.byKey(const ValueKey('onboarding-current-weight')), '5');
    await next(tester);
    expect(find.text('About you'), findsOneWidget);
    expect(find.textContaining('Enter a weight between'), findsOneWidget);
    expect(backend.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  test('goal weight suggestions follow the goal', () {
    expect(suggestGoalWeightKg(FitnessGoal.loseFat, 90), 83);
    expect(suggestGoalWeightKg(FitnessGoal.buildMuscle, 70), 73.5);
    expect(suggestGoalWeightKg(FitnessGoal.stayFit, 70), isNull);
  });

  group('gate', () {
    Future<void> launch(WidgetTester tester) async {
      phone(tester);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () => OnboardingGate.maybeShow(context), child: const Text('home')),
          ),
        ),
      ));
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the flow when the server says never onboarded', (tester) async {
      await launch(tester);
      expect(find.text('Welcome to Gym Bro'), findsOneWidget);
    });

    testWidgets('stays away for someone already onboarded on the server', (tester) async {
      server['onboarded_at'] = '2026-01-01T00:00:00.000Z';
      await launch(tester);
      expect(find.text('Welcome to Gym Bro'), findsNothing);
    });

    testWidgets('trusts cached settings that say onboarded (no request)', (tester) async {
      await SettingsService.instance.update(onboarded: true);
      backend.requests.clear();
      await launch(tester);
      expect(find.text('Welcome to Gym Bro'), findsNothing);
      expect(backend.requests, isEmpty);
    });

    testWidgets('stays away when the server fails', (tester) async {
      backend.on('GET /users/me/settings', err(500, 'boom'));
      await launch(tester);
      expect(find.text('Welcome to Gym Bro'), findsNothing);
    });
  });
}
