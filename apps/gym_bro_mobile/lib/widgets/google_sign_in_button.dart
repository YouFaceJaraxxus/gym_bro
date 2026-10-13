// "Continue with Google" (google_sign_in v7 → ID token → POST /users/google).
//
// Hidden unless the build sets the OAuth client IDs:
//
//   --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>.apps.googleusercontent.com
//   --dart-define=GOOGLE_IOS_CLIENT_ID=<ios client id>.apps.googleusercontent.com   (iOS only)
//
// Setup (details in apps/gym_bro_api/supabase/config.toml, [auth.external.google]):
//   1. Google Cloud Console → Credentials: create a "Web application" client
//      (GOOGLE_SERVER_CLIENT_ID; the ID token's audience), an "iOS" client for
//      the bundle id (GOOGLE_IOS_CLIENT_ID) and an "Android" client for the
//      package name + signing SHA-1 (no ID needed in the app).
//   2. iOS: add the reversed iOS client ID
//      (com.googleusercontent.apps.<id>) as a URL scheme in Info.plist.
//   3. Enable the Google provider in Supabase Auth with the web client ID +
//      secret and list every client ID.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../l10n/l10n.dart';
import '../services/auth_manager.dart';
import '../services/auth_service.dart';

class GoogleAuth {
  GoogleAuth._();

  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static Future<void>? _initialized;

  /// True when this build can offer Google sign-in.
  static bool get isConfigured {
    if (kIsWeb || _serverClientId.isEmpty) return false;
    if (Platform.isIOS) return _iosClientId.isNotEmpty;
    return Platform.isAndroid;
  }

  /// Runs the native Google flow and signs into Gym Bro with the ID token.
  /// Returns false if the user cancelled. Throws with a readable message on
  /// failure.
  static Future<bool> signIn(AppLocalizations l10n) async {
    final google = GoogleSignIn.instance;
    _initialized ??= google.initialize(
      clientId: Platform.isIOS ? _iosClientId : null,
      serverClientId: _serverClientId,
    );
    await _initialized;
    if (!google.supportsAuthenticate()) {
      throw Exception(l10n.shellGoogleNotSupported);
    }

    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return false;
      }
      throw Exception(e.description ?? l10n.shellGoogleFailed);
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) throw Exception(l10n.shellGoogleNoIdToken);

    final data = await AuthService().signInWithGoogle(idToken);
    await AuthManager.instance.setSession(
      data,
      profileData: data['profile'] as Map<String, dynamic>?,
    );
    return true;
  }
}

/// "Continue with Google" with an "or" divider above it. Renders nothing when
/// Google sign-in isn't configured for this build. Navigates home on success.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key, this.enabled = true});

  /// False while the surrounding form is busy.
  final bool enabled;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final signedIn = await GoogleAuth.signIn(context.l10n);
      if (signedIn && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!GoogleAuth.isConfigured) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l10n.shellOr,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: (_loading || !widget.enabled) ? null : _signIn,
          icon: _loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: l10n.commonLoading,
                  ),
                )
              : ExcludeSemantics(
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: cs.primary,
                    ),
                  ),
                ),
          label: Text(l10n.shellContinueWithGoogle),
        ),
      ],
    );
  }
}
