import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'pages/signup_page.dart';
import 'pages/check_email_page.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/verify_invite_page.dart';
import 'services/auth_manager.dart';

void main() {
  runApp(const GymBroApp());
}

class GymBroApp extends StatelessWidget {
  const GymBroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Bro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const _AppInit(),
        '/signup': (_) => const SignupPage(),
        '/check-email': (_) => const CheckEmailPage(),
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomePage(),
        '/verify-invite': (_) => const VerifyInvitePage(),
      },
    );
  }
}

class _AppInit extends StatefulWidget {
  const _AppInit();

  @override
  State<_AppInit> createState() => _AppInitState();
}

class _AppInitState extends State<_AppInit> {
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final appLinks = AppLinks();

    // Check if the app was cold-started by tapping an invite/reset link.
    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null) {
      final handled = await _handleAuthLink(initialLink);
      if (handled) {
        // Subscribe for future links and return — navigation already done.
        _linkSub = appLinks.uriLinkStream.listen(_handleAuthLink);
        return;
      }
    }

    // Normal start: restore persisted session.
    final hasSession = await AuthManager.instance.tryRestoreSession();
    if (mounted) {
      Navigator.pushReplacementNamed(context, hasSession ? '/home' : '/signup');
    }

    // Subscribe for links that arrive while the app is already running
    // (e.g. user taps the invite email while the app is in the foreground).
    _linkSub = appLinks.uriLinkStream.listen(_handleAuthLink);
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
    await AuthManager.instance.ensureProfile();

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
