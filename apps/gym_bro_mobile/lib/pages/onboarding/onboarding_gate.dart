import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/settings_service.dart';
import 'onboarding_page.dart';

/// Shows the first-run flow once, to someone who never finished or skipped it.
///
/// The cached settings can be stale defaults (the server sync after sign-in
/// runs in the background), so a missing `onboarded_at` is only trusted when
/// the server confirms it. Never while impersonating, and never when the
/// server can't be reached (it asks again on the next launch).
class OnboardingGate {
  OnboardingGate._();

  static bool _running = false;

  /// Called by HomePage once it's on screen.
  static Future<void> maybeShow(BuildContext context) async {
    if (_running) return;
    final auth = AuthManager.instance;
    final settings = SettingsService.instance;
    if (!auth.hasSession || auth.isImpersonating) return;
    if (settings.settings.value.onboardedAt != null) return;
    _running = true;
    try {
      final token = await auth.getValidToken();
      final fresh = await ApiService().getSettings(token);
      if (fresh.onboardedAt != null || auth.isImpersonating || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(fullscreenDialog: true, builder: (_) => const OnboardingPage()),
      );
    } catch (_) {
      // Offline or the server failed: try again next time.
    } finally {
      _running = false;
    }
  }
}
