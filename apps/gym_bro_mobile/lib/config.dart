import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Build-time configuration, supplied with `--dart-define` (or
/// `--dart-define-from-file`). See README.md for the full list.
class AppConfig {
  AppConfig._();

  static const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Base URL of the edge functions, e.g. `https://xyz.supabase.co/functions/v1`.
  ///
  /// Without `--dart-define=API_BASE_URL=...` it points at the local Supabase
  /// stack:
  /// - Web              → dart:io Platform is unavailable, always localhost
  /// - Android emulator → the host machine is 10.0.2.2
  /// - iOS simulator    → localhost works fine
  /// - Physical device  → pass your machine's LAN IP via API_BASE_URL
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride.endsWith('/')
          ? _apiBaseUrlOverride.substring(0, _apiBaseUrlOverride.length - 1)
          : _apiBaseUrlOverride;
    }
    final host = !kIsWeb && Platform.isAndroid ? '10.0.2.2' : 'localhost';
    return 'http://$host:54321/functions/v1';
  }

  /// True when the API URL came from a dart-define rather than the local default.
  static bool get hasCustomApiBaseUrl => _apiBaseUrlOverride.isNotEmpty;
}
