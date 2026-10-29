import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/pages/verify_invite_page.dart';
import 'package:gym_bro_mobile/services/auth_manager.dart';

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

  Future<void> openSignup(WidgetTester tester) async {
    await tester.pumpWidget(authApp(initialRoute: '/signup', observer: routes));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, en.shellCreateAccount), findsOneWidget);
    routes.events.clear();
  }

  Future<void> tapButton(WidgetTester tester, Finder button) async {
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Finder signUpButton() => find.widgetWithText(FilledButton, en.shellSignUp);

  Future<void> fillForm(
    WidgetTester tester, {
    String name = ' Nina ',
    String lastName = ' Novak ',
    String username = ' ninanovak ',
    String email = ' nina.novak@example.com ',
    String password = 'secret1',
  }) async {
    await tester.enterText(field(en.shellAuthFirstName), name);
    await tester.enterText(field(en.shellAuthLastName), lastName);
    await tester.enterText(field(en.shellAuthUsername), username);
    await tester.enterText(field(en.shellAuthEmail), email);
    await tester.enterText(field(en.shellAuthPassword), password);
  }

  testWidgets('sign up: POST /users/signup with every field trimmed → /check-email', (tester) async {
    backend.on(
      'POST /users/signup',
      ok({
        'message': 'Check your email to verify your account.',
        'user': profileJson(id: 'u-new', username: 'ninanovak', email: 'nina.novak@example.com'),
        'role_assignment': null,
      }, 201),
    );
    await openSignup(tester);

    await fillForm(tester);
    await tapButton(tester, signUpButton());

    expect(backend.requests.map(describe), ['POST /users/signup']);
    expect(bodyOf(backend.only), {
      'email': 'nina.novak@example.com',
      'password': 'secret1',
      'username': 'ninanovak',
      'name': 'Nina',
      'last_name': 'Novak',
    });
    expect(routes.events, ['replace /signup -> /check-email']);
    expect(find.text(en.shellCheckEmailTitle), findsOneWidget);
    expect(find.text(en.shellCheckEmailBody), findsOneWidget);
    // Signup returns no session: the user confirms the email first.
    expect(AuthManager.instance.hasSession, isFalse);

    // "Go to login" from the check-email page.
    await tapButton(tester, find.text(en.shellGoToLogin));
    expect(routes.events.last, 'replace /check-email -> /login');
    expect(find.widgetWithText(AppBar, en.shellLogIn), findsOneWidget);
  });

  testWidgets('email_taken: localized message with a "log in instead" link to /login', (tester) async {
    backend.on('POST /users/signup', err(409, 'An account with this email already exists', code: 'email_taken'));
    await openSignup(tester);

    await fillForm(tester);
    await tapButton(tester, signUpButton());

    expect(find.text(en.shellSignupEmailTaken), findsOneWidget);
    expect(routes.events, isEmpty);

    await tapButton(tester, find.text(en.shellLogInInstead));
    expect(routes.events, ['replace /signup -> /login']);
  });

  testWidgets('invite_pending: dialog, then VerifyInvitePage prefilled with the email', (tester) async {
    backend.on(
      'POST /users/signup',
      err(409, "You've already been invited. We sent you a new invite email: enter its code to set up your account.",
          code: 'invite_pending'),
    );
    await openSignup(tester);

    await fillForm(tester, email: 'priya.nair@example.com');
    await tester.ensureVisible(signUpButton());
    await tester.tap(signUpButton());
    // The form's spinner keeps running behind the dialog: no pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(en.shellSignupPendingInviteTitle), findsOneWidget);
    expect(find.text(en.shellSignupPendingInviteBody('priya.nair@example.com')), findsOneWidget);
    expect(find.byType(VerifyInvitePage), findsNothing);

    await tester.tap(find.text(en.shellSignupEnterCode));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    final page = tester.widget<VerifyInvitePage>(find.byType(VerifyInvitePage));
    expect(page.initialEmail, 'priya.nair@example.com');
    expect(find.widgetWithText(TextFormField, 'priya.nair@example.com'), findsOneWidget);
    expect(backend.requests.map(describe), ['POST /users/signup'], reason: 'nothing else is sent');

    // And activating from there signs in.
    backend.on('POST /users/verify-invite', ok(signinJson(profile: profileJson(role: 'employee'))));
    await tester.enterText(field(en.shellInviteCode), '123456');
    await tester.enterText(field(en.shellNewPassword), 'newpass1');
    await tester.enterText(field(en.shellConfirmPassword), 'newpass1');
    await tapButton(tester, find.widgetWithText(FilledButton, en.shellActivateAccount));

    expect(bodyOf(backend.last('POST /users/verify-invite')),
        {'email': 'priya.nair@example.com', 'token': '123456', 'password': 'newpass1'});
    expect(find.text('<home>'), findsOneWidget);
    expect(AuthManager.instance.hasSession, isTrue);
  });

  testWidgets('other API errors show the API message', (tester) async {
    backend.on('POST /users/signup', err(409, 'That username is taken', code: 'username_taken'));
    await openSignup(tester);

    await fillForm(tester);
    await tapButton(tester, signUpButton());

    expect(find.text('That username is taken'), findsOneWidget);
    expect(find.text(en.shellLogInInstead), findsNothing);
    expect(routes.events, isEmpty);
  });

  testWidgets('a non-JSON server error shows a generic message', (tester) async {
    backend.on('POST /users/signup', ok('<html>502 Bad Gateway</html>', 502));
    await openSignup(tester);

    await fillForm(tester);
    await tapButton(tester, signUpButton());

    expect(find.text('Signup failed (502)'), findsOneWidget);
  });

  testWidgets('client-side validation prevents requests', (tester) async {
    await openSignup(tester);

    // Everything empty.
    await tapButton(tester, signUpButton());
    expect(find.text(en.commonRequired), findsNWidgets(3)); // name, last name, username
    expect(find.text(en.shellAuthInvalidEmail), findsOneWidget);
    expect(find.text(en.shellAuthPasswordMin(6)), findsOneWidget);

    // Whitespace-only names, bad email, short password.
    await fillForm(tester, name: '  ', lastName: 'Novak', username: 'nn', email: 'nina.example.com', password: '12345');
    await tapButton(tester, signUpButton());
    expect(find.text(en.commonRequired), findsOneWidget);
    expect(find.text(en.shellAuthInvalidEmail), findsOneWidget);
    expect(find.text(en.shellAuthPasswordMin(6)), findsOneWidget);

    // Only the password is too short.
    await fillForm(tester, password: '12345');
    await tapButton(tester, signUpButton());
    expect(find.text(en.commonRequired), findsNothing);
    expect(find.text(en.shellAuthPasswordMin(6)), findsOneWidget);

    expect(backend.requests, isEmpty);
  });

  testWidgets('"Already have an account?" replaces signup with /login', (tester) async {
    await openSignup(tester);

    await tapButton(tester, find.text(en.shellHaveAccountLogIn));
    expect(routes.events, ['replace /signup -> /login']);
    expect(find.text(en.shellContinueWithGoogle), findsNothing, reason: 'Google is off without client IDs');
  });
}
