// A MaterialApp with lib/main.dart's routes and localizations, for driving
// the auth pages. /home (and /) are placeholders so the home shell isn't built.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/pages/check_email_page.dart';
import 'package:gym_bro_mobile/pages/forgot_password_page.dart';
import 'package:gym_bro_mobile/pages/login_page.dart';
import 'package:gym_bro_mobile/pages/reset_password_page.dart';
import 'package:gym_bro_mobile/pages/signup_page.dart';
import 'package:gym_bro_mobile/pages/verify_invite_page.dart';
import 'package:gym_bro_mobile/services/auth_manager.dart';
import 'package:gym_bro_mobile/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backend.dart';
import 'auth_fixtures.dart';

final en = lookupAppLocalizations(const Locale('en'));

/// Records route changes so tests can assert push vs. replace.
class RouteLog extends NavigatorObserver {
  final List<String> events = [];

  String _name(Route<dynamic>? r) => r?.settings.name ?? r.runtimeType.toString();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => events.add('push ${_name(route)}');

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      events.add('replace ${_name(oldRoute)} -> ${_name(newRoute)}');

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => events.add('pop ${_name(route)}');
}

Widget authApp({required String initialRoute, NavigatorObserver? observer}) => MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: [?observer],
      initialRoute: initialRoute,
      routes: {
        '/': (_) => placeholder('root'),
        '/signup': (_) => const SignupPage(),
        '/check-email': (_) => const CheckEmailPage(),
        '/login': (_) => const LoginPage(),
        '/home': (_) => placeholder('home'),
        '/verify-invite': (_) => const VerifyInvitePage(),
        '/forgot-password': (_) => const ForgotPasswordPage(),
        '/reset-password': (_) => const ResetPasswordPage(),
      },
    );

/// Fresh storage and an installed FakeBackend; call from setUp.
FakeBackend freshAuthBackend() {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  return FakeBackend()..install();
}

/// Signs out (AuthManager is a singleton) and removes the backend; call from tearDown.
Future<void> resetAuth(FakeBackend backend) async {
  await AuthManager.instance.clear();
  backend.uninstall();
}

/// Requests to the auth endpoints (drops the background settings / realtime
/// calls that follow a sign-in).
List<String> authCalls(FakeBackend backend) => backend.requests
    .where((r) => pathOf(r).startsWith('/users/') && pathOf(r) != '/users/me/settings')
    .map(describe)
    .toList();

/// The text field labelled [label].
Finder field(String label) => find.widgetWithText(TextFormField, label);
