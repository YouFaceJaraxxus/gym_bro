import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/l10n.dart';
import 'pages/signup_page.dart';
import 'pages/check_email_page.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/verify_invite_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/people/profile_qr_page.dart';
import 'services/auth_manager.dart';
import 'services/push_service.dart';
import 'services/settings_service.dart';
import 'theme.dart';

/// The app's root navigator. Push-notification taps navigate through it
/// (see PushService / NotificationRouter), since they arrive outside any
/// widget's context.
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Apply the cached theme / units before the first frame.
  await SettingsService.instance.loadCached();
  // No-op unless the Firebase dart-defines are set (see push_service.dart).
  unawaited(PushService.instance.init(navigatorKey));
  runApp(const GymBroApp());
}

class GymBroApp extends StatelessWidget {
  const GymBroApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([settings.themeMode, settings.locale]),
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        navigatorKey: navigatorKey,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: settings.themeMode.value,
        locale: settings.locale.value,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Serbian is offered in Latin script only; plain `sr` exists as a
        // fallback for devices set to Serbian.
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: '/',
        routes: {
          '/': (_) => const _AppInit(),
          '/signup': (_) => const SignupPage(),
          '/check-email': (_) => const CheckEmailPage(),
          '/login': (_) => const LoginPage(),
          '/home': (_) => const HomePage(),
          '/verify-invite': (_) => const VerifyInvitePage(),
          '/forgot-password': (_) => const ForgotPasswordPage(),
          '/reset-password': (_) => const ResetPasswordPage(),
        },
      ),
    );
  }
}

class _AppInit extends StatefulWidget {
  const _AppInit();

  @override
  State<_AppInit> createState() => _AppInitState();
}

/// Deep links for the app's lifetime. Not tied to [_AppInit]: that splash
/// route is replaced by home right away, and links keep arriving after it.
StreamSubscription<Uri>? _linkSub;

class _AppInitState extends State<_AppInit> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Replaces the splash with [route], or — once the splash is gone (a link
  /// while the app runs) — everything on the root navigator.
  void _go(String route) {
    if (mounted) {
      Navigator.pushReplacementNamed(context, route);
    } else {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(route, (_) => false);
    }
  }

  Future<void> _init() async {
    final appLinks = AppLinks();

    // Check if the app was cold-started by tapping an invite/reset link.
    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null) {
      final handled = await _handleAuthLink(initialLink);
      if (handled) {
        // Subscribe for future links and return — navigation already done.
        _linkSub ??= appLinks.uriLinkStream.listen(_handleLink);
        return;
      }
    }

    // Normal start: restore persisted session. A storage failure (e.g. the
    // keychain is unavailable) must not leave the user stuck on this spinner.
    var hasSession = false;
    try {
      hasSession = await AuthManager.instance.tryRestoreSession();
    } catch (e) {
      debugPrint('Session restore failed: $e');
    }
    if (mounted) {
      Navigator.pushReplacementNamed(context, hasSession ? '/home' : '/signup');
    }
    // Cold-started from a profile QR code / link: open it over home.
    if (hasSession && initialLink != null) _openProfileLink(initialLink);

    // Subscribe for links that arrive while the app is already running
    // (e.g. user taps the invite email while the app is in the foreground).
    _linkSub ??= appLinks.uriLinkStream.listen(_handleLink);
  }

  Future<void> _handleLink(Uri uri) async {
    if (!await _handleAuthLink(uri)) _openProfileLink(uri);
  }

  /// `gymbroo://u/<username>` (a profile QR code) opens that profile when signed in.
  void _openProfileLink(Uri uri) {
    final username = usernameFromProfileLink(uri.toString());
    if (username == null || !AuthManager.instance.hasSession) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) openProfileByUsername(ctx, username);
    });
  }

  /// Parses a `gymbroo://auth/callback#access_token=…` URI, stores the session,
  /// and navigates to home. Returns true if the link was a valid auth callback.
  Future<bool> _handleAuthLink(Uri uri) async {
    final params = Uri.splitQueryString(uri.fragment);
    final accessToken = params['access_token'];
    final refreshToken = params['refresh_token'];
    final expiresIn = params['expires_in'];

    if (accessToken == null || refreshToken == null) return false;

    await AuthManager.instance.setSession({
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': int.tryParse(expiresIn ?? '') ?? 3600,
    });

    final type = params['type'];
    if (type == 'recovery') {
      _go('/reset-password');
    } else {
      await AuthManager.instance.ensureProfile();
      _go('/home');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          semanticsLabel: context.l10n.commonLoading,
        ),
      ),
    );
  }
}
