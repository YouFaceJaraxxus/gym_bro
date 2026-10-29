import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/services/auth_manager.dart';
import 'package:http/http.dart' as http;

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

  Future<void> tapButton(WidgetTester tester, Finder button) async {
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('ForgotPasswordPage', () {
    Future<void> openForgot(WidgetTester tester) async {
      await tester.pumpWidget(authApp(initialRoute: '/login', observer: routes));
      await tester.pumpAndSettle();
      await tapButton(tester, find.text(en.shellForgotPasswordLink));
      expect(find.widgetWithText(AppBar, en.shellForgotPasswordTitle), findsOneWidget);
      routes.events.clear();
    }

    Finder send() => find.widgetWithText(FilledButton, en.shellSendResetLink);

    testWidgets('POST /users/forgot-password {email} → "check your email" → back to login', (tester) async {
      backend.on('POST /users/forgot-password', ok({'success': true}));
      await openForgot(tester);

      await tester.enterText(field(en.shellAuthEmail), ' liam.oconnor@example.com ');
      await tapButton(tester, send());

      expect(backend.requests.map(describe), ['POST /users/forgot-password']);
      final req = backend.only;
      expect(req.headers['content-type'], startsWith('application/json'));
      expect(req.headers.containsKey('authorization'), isFalse);
      expect(bodyOf(req), {'email': 'liam.oconnor@example.com'});

      expect(find.text(en.shellCheckEmailTitle), findsOneWidget);
      expect(find.text(en.shellResetLinkSent('liam.oconnor@example.com')), findsOneWidget);
      expect(send(), findsNothing);
      expect(routes.events, isEmpty);

      await tapButton(tester, find.text(en.shellHomeBackToLogin));
      // Replaces itself with a new /login (the original login page stays below it).
      expect(routes.events, ['replace /forgot-password -> /login']);
      expect(find.widgetWithText(AppBar, en.shellLogIn), findsOneWidget);
    });

    testWidgets('an API error is shown and the form stays', (tester) async {
      backend.on('POST /users/forgot-password', err(429, 'For security purposes, you can only request this after 60 seconds.'));
      await openForgot(tester);

      await tester.enterText(field(en.shellAuthEmail), 'liam.oconnor@example.com');
      await tapButton(tester, send());

      expect(find.text('For security purposes, you can only request this after 60 seconds.'), findsOneWidget);
      expect(send(), findsOneWidget);
      expect(find.text(en.shellCheckEmailTitle), findsNothing);
    });

    testWidgets('an invalid email sends nothing', (tester) async {
      await openForgot(tester);

      await tapButton(tester, send());
      expect(find.text(en.shellAuthInvalidEmail), findsOneWidget);

      await tester.enterText(field(en.shellAuthEmail), 'liam.example.com');
      await tapButton(tester, send());
      expect(find.text(en.shellAuthInvalidEmail), findsOneWidget);

      expect(backend.requests, isEmpty);
    });
  });

  group('ResetPasswordPage (after a recovery link set the session)', () {
    Future<void> openReset(WidgetTester tester, {int expiresIn = 3600}) async {
      await tester.runAsync(() async {
        // What _handleAuthLink stores for gymbroo://auth/callback#…&type=recovery.
        await AuthManager.instance.setSession(sessionJson(accessToken: 'recovery-access', expiresIn: expiresIn));
        await pumpEventQueue();
      });
      backend.requests.clear();
      await tester.pumpWidget(authApp(initialRoute: '/reset-password', observer: routes));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, en.shellResetPasswordTitle), findsOneWidget);
      routes.events.clear();
    }

    Finder save() => find.widgetWithText(FilledButton, en.shellSetNewPassword);

    testWidgets('POST /users/reset-password {password} with the recovery token → /home', (tester) async {
      backend.on('POST /users/reset-password', ok({'success': true}));
      await openReset(tester);

      await tester.enterText(field(en.shellNewPassword), 'brandnew1');
      await tester.enterText(field(en.shellConfirmPassword), 'brandnew1');
      await tapButton(tester, save());

      expect(authCalls(backend), ['POST /users/reset-password']);
      final req = backend.last('POST /users/reset-password');
      expect(req.headers['authorization'], 'Bearer recovery-access');
      expect(req.headers['content-type'], startsWith('application/json'));
      expect(bodyOf(req), {'password': 'brandnew1'});
      expect(routes.events, ['replace /reset-password -> /home']);
      expect(find.text('<home>'), findsOneWidget);
    });

    testWidgets('refreshes an expiring recovery session first', (tester) async {
      final refreshedWith = <Object?>[];
      backend.on('POST /users/refresh', (http.Request r) {
        refreshedWith.add(bodyOf(r));
        return ok(sessionJson(accessToken: 'refreshed-access'));
      });
      backend.on('POST /users/reset-password', ok({'success': true}));
      await openReset(tester, expiresIn: 20);

      await tester.enterText(field(en.shellNewPassword), 'brandnew1');
      await tester.enterText(field(en.shellConfirmPassword), 'brandnew1');
      await tapButton(tester, save());

      // (The refresh may already have happened in the background right after the session was set.)
      expect(refreshedWith, [
        {'refresh_token': 'refresh-1'},
      ]);
      expect(backend.last('POST /users/reset-password').headers['authorization'], 'Bearer refreshed-access');
    });

    testWidgets('an API error is shown and the user stays', (tester) async {
      backend.on('POST /users/reset-password', err(422, 'New password should be different from the old password.'));
      await openReset(tester);

      await tester.enterText(field(en.shellNewPassword), 'samepass');
      await tester.enterText(field(en.shellConfirmPassword), 'samepass');
      await tapButton(tester, save());

      expect(find.text('New password should be different from the old password.'), findsOneWidget);
      expect(routes.events, isEmpty);
    });

    testWidgets('without a session the error is shown and nothing is sent', (tester) async {
      await tester.pumpWidget(authApp(initialRoute: '/reset-password', observer: routes));
      await tester.pumpAndSettle();

      await tester.enterText(field(en.shellNewPassword), 'brandnew1');
      await tester.enterText(field(en.shellConfirmPassword), 'brandnew1');
      await tapButton(tester, save());

      expect(find.text('No active session'), findsOneWidget);
      expect(backend.requests, isEmpty);
    });

    testWidgets('validation: required, min length, must match — nothing sent', (tester) async {
      await openReset(tester);

      await tapButton(tester, save());
      expect(find.text(en.commonRequired), findsNWidgets(2));

      await tester.enterText(field(en.shellNewPassword), 'abc');
      await tester.enterText(field(en.shellConfirmPassword), 'abc');
      await tapButton(tester, save());
      expect(find.text(en.shellAuthPasswordMin(6)), findsOneWidget);

      await tester.enterText(field(en.shellNewPassword), 'brandnew1');
      await tester.enterText(field(en.shellConfirmPassword), 'brandnew2');
      await tapButton(tester, save());
      expect(find.text(en.shellPasswordsDontMatch), findsOneWidget);
      expect(find.text(en.shellAuthPasswordMin(6)), findsNothing);

      expect(backend.requests, isEmpty);
    });
  });
}
