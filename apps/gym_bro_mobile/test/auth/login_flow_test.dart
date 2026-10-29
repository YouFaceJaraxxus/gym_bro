import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/user_profile.dart';
import 'package:gym_bro_mobile/services/auth_manager.dart';
import 'package:gym_bro_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/fake_backend.dart';
import 'auth_app.dart';
import 'auth_fixtures.dart';

void main() {
  late FakeBackend backend;
  late RouteLog routes;

  setUp(() {
    backend = freshAuthBackend();
    routes = RouteLog();
  });
  tearDown(() => resetAuth(backend));

  Future<void> openLogin(WidgetTester tester) async {
    await tester.pumpWidget(authApp(initialRoute: '/login', observer: routes));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, en.shellLogIn), findsOneWidget);
    routes.events.clear();
  }

  Future<void> tapButton(WidgetTester tester, Finder button) async {
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Finder signInButton() => find.widgetWithText(FilledButton, en.shellLogIn);

  testWidgets('sign in: POST /users/signin, session + profile stored, replaced by /home', (tester) async {
    backend.on('POST /users/signin', ok(signinJson(profile: profileJson(role: 'trainer'))));
    await openLogin(tester);

    await tester.enterText(field(en.shellAuthEmail), '  liam.oconnor@example.com ');
    await tester.enterText(field(en.shellAuthPassword), ' s3cret! ');
    await tapButton(tester, signInButton());

    expect(authCalls(backend), ['POST /users/signin']);
    // Email is trimmed, the password is sent as typed.
    expect(bodyOf(backend.last('POST /users/signin')), {'email': 'liam.oconnor@example.com', 'password': ' s3cret! '});

    final auth = AuthManager.instance;
    expect(auth.hasSession, isTrue);
    expect(auth.profile!.id, '8d0b05de-7c18-441b-9536-aaa042eaeaaa');
    expect(auth.profile!.role, UserRole.trainer);
    expect(await tester.runAsync(auth.getValidToken), 'access-1');
    final stored = await tester.runAsync(() => const FlutterSecureStorage().readAll());
    expect(stored!['access_token'], 'access-1');
    expect(stored['refresh_token'], 'refresh-1');
    expect(stored['user_profile'], contains('"role":"trainer"'));

    expect(find.text('<home>'), findsOneWidget);
    expect(routes.events, ['replace /login -> /home']);
  });

  testWidgets('API error is shown, the user stays on the page and can retry', (tester) async {
    backend.on('POST /users/signin', err(400, 'Invalid login credentials'));
    await openLogin(tester);

    await tester.enterText(field(en.shellAuthEmail), 'liam.oconnor@example.com');
    await tester.enterText(field(en.shellAuthPassword), 'wrong');
    await tapButton(tester, signInButton());

    expect(find.text('Invalid login credentials'), findsOneWidget);
    expect(find.text('<home>'), findsNothing);
    expect(AuthManager.instance.hasSession, isFalse);
    expect(routes.events, isEmpty);

    // Retry succeeds; the error goes away with the page.
    backend.on('POST /users/signin', ok(signinJson()));
    await tapButton(tester, signInButton());
    expect(authCalls(backend), ['POST /users/signin', 'POST /users/signin']);
    expect(find.text('<home>'), findsOneWidget);
  });

  testWidgets('the button shows a spinner and is disabled while signing in', (tester) async {
    // Hold the response until the test releases it.
    final release = Completer<void>();
    AuthService.debugClientOverride = MockClient((req) async {
      backend.requests.add(req);
      await release.future;
      return http.Response('{"error":"Invalid login credentials"}', 400);
    });
    await openLogin(tester);
    await tester.enterText(field(en.shellAuthEmail), 'a@b.co');
    await tester.enterText(field(en.shellAuthPassword), 'pw');

    await tester.tap(signInButton());
    await tester.pump();

    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(find.bySemanticsLabel(en.commonLoading), findsOneWidget);
    expect(authCalls(backend), ['POST /users/signin']);

    release.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    expect(find.text('Invalid login credentials'), findsOneWidget);
  });

  testWidgets('validation: empty or invalid fields send no request', (tester) async {
    await openLogin(tester);

    await tapButton(tester, signInButton());
    expect(find.text(en.shellAuthInvalidEmail), findsOneWidget);
    expect(find.text(en.commonRequired), findsOneWidget);

    await tester.enterText(field(en.shellAuthEmail), 'not-an-email');
    await tester.enterText(field(en.shellAuthPassword), 'pw');
    await tapButton(tester, signInButton());
    expect(find.text(en.shellAuthInvalidEmail), findsOneWidget);
    expect(find.text(en.commonRequired), findsNothing);

    await tester.enterText(field(en.shellAuthEmail), 'ok@example.com');
    await tester.enterText(field(en.shellAuthPassword), '');
    await tapButton(tester, signInButton());
    expect(find.text(en.shellAuthInvalidEmail), findsNothing);
    expect(find.text(en.commonRequired), findsOneWidget);

    expect(backend.requests, isEmpty);
  });

  testWidgets('Google sign-in is hidden in builds without the client IDs', (tester) async {
    await openLogin(tester);
    expect(find.text(en.shellContinueWithGoogle), findsNothing);
  });

  testWidgets('"Forgot password?" pushes /forgot-password (back returns to login)', (tester) async {
    await openLogin(tester);

    await tapButton(tester, find.text(en.shellForgotPasswordLink));
    expect(routes.events, ['push /forgot-password']);
    expect(find.widgetWithText(AppBar, en.shellForgotPasswordTitle), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, en.shellLogIn), findsOneWidget);
  });

  testWidgets('"Sign up" replaces login with /signup', (tester) async {
    await openLogin(tester);

    await tapButton(tester, find.text(en.shellNoAccountSignUp));
    expect(routes.events, ['replace /login -> /signup']);
    expect(find.widgetWithText(AppBar, en.shellCreateAccount), findsOneWidget);
  });

  testWidgets('"Have an invite code?" pushes /verify-invite', (tester) async {
    await openLogin(tester);

    await tapButton(tester, find.text(en.shellHaveInviteCode));
    expect(routes.events, ['push /verify-invite']);
    expect(find.widgetWithText(AppBar, en.shellActivateInviteTitle), findsOneWidget);
    expect(backend.requests, isEmpty);
  });
}
