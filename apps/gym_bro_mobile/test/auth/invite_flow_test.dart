// Signing up via an invite: a gym/shop invites an email address, the person
// gets an email with a 6-digit code and activates the account on
// VerifyInvitePage. Already-registered users get an in-app invite instead,
// answered on InviteAcceptPage.
//
// Not covered: the email deep link (gymbroo://auth/callback#access_token=…)
// handled by _AppInit._handleAuthLink in lib/main.dart — it's private to
// GymBroApp and needs the app_links platform channels plus the real HomePage.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/app_notification.dart';
import 'package:gym_bro_mobile/models/user_profile.dart';
import 'package:gym_bro_mobile/pages/invite_accept_page.dart';
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

  Future<void> tapButton(WidgetTester tester, Finder button) async {
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('VerifyInvitePage', () {
    Future<void> openVerify(WidgetTester tester) async {
      // Reached from the login page ("Have an invite code?").
      await tester.pumpWidget(authApp(initialRoute: '/login', observer: routes));
      await tester.pumpAndSettle();
      await tapButton(tester, find.text(en.shellHaveInviteCode));
      expect(find.widgetWithText(AppBar, en.shellActivateInviteTitle), findsOneWidget);
      routes.events.clear();
    }

    Finder activate() => find.widgetWithText(FilledButton, en.shellActivateAccount);

    Future<void> fill(WidgetTester tester, {String email = ' priya.nair@example.com ', String code = '482913', String password = 'newpass1', String? confirm}) async {
      await tester.enterText(field(en.shellAuthEmail), email);
      await tester.enterText(field(en.shellInviteCode), code);
      await tester.enterText(field(en.shellNewPassword), password);
      await tester.enterText(field(en.shellConfirmPassword), confirm ?? password);
    }

    testWidgets('email + code + password → POST /users/verify-invite → session → /home', (tester) async {
      backend.on(
        'POST /users/verify-invite',
        ok(signinJson(
          accessToken: 'invite-access',
          refreshToken: 'invite-refresh',
          profile: profileJson(id: 'u-priya', username: 'priyanair', name: 'Priya', lastName: 'Nair', role: 'employee'),
        )),
      );
      await openVerify(tester);

      await fill(tester);
      await tapButton(tester, activate());

      expect(authCalls(backend), ['POST /users/verify-invite']);
      final req = backend.last('POST /users/verify-invite');
      expect(req.headers['content-type'], startsWith('application/json'));
      expect(req.headers.containsKey('authorization'), isFalse);
      expect(bodyOf(req), {'email': 'priya.nair@example.com', 'token': '482913', 'password': 'newpass1'});

      final auth = AuthManager.instance;
      expect(auth.hasSession, isTrue);
      expect(auth.profile!.id, 'u-priya');
      expect(auth.profile!.role, UserRole.employee);
      final stored = await tester.runAsync(() => const FlutterSecureStorage().readAll());
      expect(stored!['access_token'], 'invite-access');
      expect(stored['refresh_token'], 'invite-refresh');

      expect(routes.events, ['replace /verify-invite -> /home']);
      expect(find.text('<home>'), findsOneWidget);
    });

    testWidgets('a wrong code shows the API error and keeps the user on the page', (tester) async {
      backend.on('POST /users/verify-invite', err(403, 'Token has expired or is invalid'));
      await openVerify(tester);

      await fill(tester, code: '000000');
      await tapButton(tester, activate());

      expect(find.text('Token has expired or is invalid'), findsOneWidget);
      expect(AuthManager.instance.hasSession, isFalse);
      expect(routes.events, isEmpty);
      expect(find.widgetWithText(AppBar, en.shellActivateInviteTitle), findsOneWidget);
    });

    testWidgets('the code field keeps digits only, at most 6', (tester) async {
      await openVerify(tester);

      await tester.enterText(field(en.shellInviteCode), '12a3-45 678');
      await tester.pump();

      final code = tester.widget<EditableText>(find.descendant(of: field(en.shellInviteCode), matching: find.byType(EditableText)));
      expect(code.controller.text, '123456');
    });

    testWidgets('validation: bad email, short code, short or mismatched password send nothing', (tester) async {
      await openVerify(tester);

      await tapButton(tester, activate());
      expect(find.text(en.shellAuthInvalidEmail), findsOneWidget);
      expect(find.text(en.shellInviteCodeInvalid), findsOneWidget);
      expect(find.text(en.shellAuthPasswordMin(6)), findsOneWidget);

      await fill(tester, email: 'priya@example.com', code: '12345', password: 'newpass1');
      await tapButton(tester, activate());
      expect(find.text(en.shellInviteCodeInvalid), findsOneWidget);
      expect(find.text(en.shellAuthInvalidEmail), findsNothing);

      await fill(tester, email: 'priya@example.com', code: '123456', password: 'newpass1', confirm: 'newpass2');
      await tapButton(tester, activate());
      expect(find.text(en.shellPasswordsDontMatch), findsOneWidget);
      expect(find.text(en.shellInviteCodeInvalid), findsNothing);

      await fill(tester, email: 'priya@example.com', code: '123456', password: 'abc');
      await tapButton(tester, activate());
      expect(find.text(en.shellAuthPasswordMin(6)), findsOneWidget);

      expect(backend.requests, isEmpty);
    });

    testWidgets('the show-password toggles reveal each field', (tester) async {
      await openVerify(tester);

      bool obscured(String label) => tester
          .widget<EditableText>(find.descendant(of: field(label), matching: find.byType(EditableText)))
          .obscureText;

      expect(obscured(en.shellNewPassword), isTrue);
      expect(obscured(en.shellConfirmPassword), isTrue);

      await tapButton(tester, find.byTooltip(en.shellShowPassword).first);
      expect(obscured(en.shellNewPassword), isFalse);
      expect(obscured(en.shellConfirmPassword), isTrue);
    });

    testWidgets('"Back" returns to the login page', (tester) async {
      await openVerify(tester);

      await tapButton(tester, find.widgetWithText(TextButton, en.commonBack));
      expect(routes.events, ['pop /verify-invite']);
      expect(find.widgetWithText(AppBar, en.shellLogIn), findsOneWidget);
    });
  });

  group('InviteAcceptPage (in-app invite for an existing account)', () {
    AppNotification gymInvite({String status = 'pending', String employeeType = 'employee_trainer'}) =>
        AppNotification.fromJson({
          'id': 'n-1',
          'user_id': 'u-priya',
          'type': 'employee_gym_invite',
          'title': "You've been invited to join Iron Temple",
          'body': 'You have a pending invitation to work at Iron Temple as Employee Trainer.',
          'metadata': {
            'invite_status': status,
            'inviter_id': 'u-marcus',
            'gym_id': 'g-1',
            'gym_name': 'Iron Temple',
            'employee_type': employeeType,
          },
          'is_read': false,
          'created_at': '2026-10-20T09:00:00.000Z',
        });

    AppNotification shopInvite() => AppNotification.fromJson({
          'id': 'n-2',
          'user_id': 'u-ravi',
          'type': 'vendor_shop_invite',
          'title': "You've been invited to join Protein Hub",
          'body': 'You have a pending invitation to work at Protein Hub as a Vendor.',
          'metadata': {'invite_status': 'pending', 'inviter_id': 'u-marcus', 'shop_id': 's-1', 'shop_name': 'Protein Hub'},
          'is_read': false,
          'created_at': '2026-10-20T09:00:00.000Z',
        });

    Map<String, dynamic> answered(AppNotification n, String status) => {
          'id': n.id,
          'user_id': n.userId,
          'type': n.type.apiValue,
          'title': n.title,
          'body': n.body,
          'metadata': {...?n.metadata, 'invite_status': status},
          'is_read': true,
          'created_at': '2026-10-20T09:00:00.000Z',
        };

    /// Opens the page over a launcher and records what it pops with.
    Future<List<Object?>> openInvite(WidgetTester tester, AppNotification n) async {
      await tester.runAsync(() async {
        await AuthManager.instance.setSession(signinJson(accessToken: 'member-token'), profileData: profileJson());
        await pumpEventQueue(); // background settings sync / realtime attempt
      });
      await tester.pumpAndSettle();
      backend.requests.clear();
      final results = <Object?>[];
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(
                await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => InviteAcceptPage(notification: n))),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('shows the gym, role and invite text', (tester) async {
      await openInvite(tester, gymInvite());

      expect(find.text("You've been invited to join Iron Temple"), findsOneWidget);
      expect(find.text(en.shellInviteBody('Iron Temple', en.shellRoleEmployeeTrainer)), findsOneWidget);
      expect(find.text('You have a pending invitation to work at Iron Temple as Employee Trainer.'), findsOneWidget);
      expect(find.text(en.shellInviteAccept('Iron Temple')), findsOneWidget);
      expect(find.text(en.shellInviteDecline), findsOneWidget);
    });

    testWidgets('accept → POST /notifications/:id/accept with the token, pops true', (tester) async {
      final n = gymInvite();
      backend.on('POST /notifications/n-1/accept', ok(answered(n, 'accepted')));
      final results = await openInvite(tester, n);

      await tester.tap(find.text(en.shellInviteAccept('Iron Temple')));
      await tester.pumpAndSettle();

      final req = backend.only;
      expect(describe(req), 'POST /notifications/n-1/accept');
      expect(req.headers['authorization'], 'Bearer member-token');
      expect(req.body, isEmpty);
      expect(results, [true]);
      expect(find.byType(InviteAcceptPage), findsNothing);
    });

    testWidgets('decline → POST /notifications/:id/decline, pops false', (tester) async {
      final n = shopInvite();
      backend.on('POST /notifications/n-2/decline', ok(answered(n, 'declined')));
      final results = await openInvite(tester, n);

      expect(find.text(en.shellInviteBody('Protein Hub', en.shellRoleVendor)), findsOneWidget);
      await tester.tap(find.text(en.shellInviteDecline));
      await tester.pumpAndSettle();

      final req = backend.only;
      expect(describe(req), 'POST /notifications/n-2/decline');
      expect(req.headers['authorization'], 'Bearer member-token');
      expect(results, [false]);
    });

    testWidgets('an API error is shown and the buttons come back', (tester) async {
      backend.on('POST /notifications/n-1/accept', err(409, 'This gym no longer exists'));
      final results = await openInvite(tester, gymInvite());

      await tester.tap(find.text(en.shellInviteAccept('Iron Temple')));
      await tester.pumpAndSettle();

      expect(find.text('This gym no longer exists'), findsOneWidget);
      expect(find.byType(InviteAcceptPage), findsOneWidget);
      expect(find.text(en.shellInviteAccept('Iron Temple')), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('an already answered invite shows its status and no buttons', (tester) async {
      await openInvite(tester, gymInvite(status: 'accepted', employeeType: 'employee'));

      expect(find.text(en.shellInviteJoined('Iron Temple', en.shellRoleEmployee)), findsOneWidget);
      expect(find.text(en.shellInviteDecline), findsNothing);
      expect(backend.requests, isEmpty);
    });
  });
}
