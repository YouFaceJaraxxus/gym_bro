import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_settings.dart';
import 'api_service.dart';
import 'auth_manager.dart';

/// App-wide user preferences. Screens listen to these notifiers so a change
/// in Settings applies everywhere immediately.
///
/// Weights are always stored and sent to the API in kilograms; use
/// [formatWeight] / [toDisplayWeight] / [fromDisplayWeight] at the UI edge.
///
/// Lifecycle: [loadCached] before `runApp` (so the theme is right on the
/// first frame), [syncFromServer] after sign-in, [reset] on logout.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const double _lbPerKg = 2.2046226218;
  static const _prefsKey = 'user_settings_v1';

  late final _api = ApiService(); // lazy: constructing it starts offline monitoring

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  /// 'kg' or 'lb'.
  final ValueNotifier<String> weightUnit = ValueNotifier('kg');

  /// The app language; null follows the device. Stored in the API as a
  /// language tag ('en', 'sr-Latn').
  final ValueNotifier<Locale?> locale = ValueNotifier(null);

  /// Everything, including push preferences. [themeMode] and [weightUnit]
  /// mirror the matching fields.
  final ValueNotifier<UserSettings> settings =
      ValueNotifier(UserSettings.defaults);

  bool get usesPounds => weightUnit.value == 'lb';

  /// Kilograms → the user's unit.
  double toDisplayWeight(double kg) => usesPounds ? kg * _lbPerKg : kg;

  /// The user's unit → kilograms.
  double fromDisplayWeight(double value) => usesPounds ? value / _lbPerKg : value;

  /// e.g. "62.5 kg" or "137.8 lb". Whole numbers drop the decimal.
  ///
  /// Uses the app language's decimal separator ("62,5 kg" in Serbian).
  String formatWeight(double kg, {int decimals = 1}) {
    final v = toDisplayWeight(kg);
    final format = NumberFormat.decimalPattern(_numberLocale())
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = decimals;
    return '${format.format(v)} ${weightUnit.value}';
  }

  /// The locale for number formatting: the chosen app language, else the device's.
  String _numberLocale() {
    final l = locale.value ?? ui.PlatformDispatcher.instance.locale;
    final tag = Intl.canonicalizedLocale(l.toString());
    return NumberFormat.localeExists(tag) ? tag : (NumberFormat.localeExists(l.languageCode) ? l.languageCode : 'en');
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  /// Applies the settings cached on this device. Never throws.
  Future<void> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      _apply(UserSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    } catch (e) {
      debugPrint('SettingsService: could not read cached settings: $e');
    }
  }

  /// Fetches the signed-in user's settings and caches them. Never throws;
  /// keeps the current values when offline.
  Future<void> syncFromServer() async {
    if (!AuthManager.instance.hasSession) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      final fresh = await _api.getSettings(token);
      _apply(fresh);
      await _save(fresh);
    } catch (e) {
      debugPrint('SettingsService: could not load settings: $e');
    }
  }

  /// Changes some settings. Applies immediately, then saves to the API;
  /// reverts and rethrows if the save fails.
  Future<void> update({
    ThemeMode? themeMode,
    String? weightUnit,
    bool? pushEnabled,
    Set<String>? mutedTypes,
    // Pass [useSystemLocale] to go back to the device language.
    Locale? locale,
    bool useSystemLocale = false,
  }) async {
    final previous = settings.value;
    final changes = <String, dynamic>{
      if (themeMode != null) 'theme_mode': _themeModeToApi(themeMode),
      'weight_unit': ?weightUnit,
      'push_enabled': ?pushEnabled,
      if (mutedTypes != null) 'muted_types': mutedTypes.toList()..sort(),
      if (locale != null) 'locale': localeToTag(locale),
      if (useSystemLocale) 'locale': null,
    };
    if (changes.isEmpty) return;

    final next = previous.copyWith(
      themeMode: themeMode == null ? null : _themeModeToApi(themeMode),
      weightUnit: weightUnit,
      pushEnabled: pushEnabled,
      mutedTypes: mutedTypes,
      locale: locale == null ? null : localeToTag(locale),
      clearLocale: useSystemLocale,
    );
    _apply(next);
    try {
      final token = await AuthManager.instance.getValidToken();
      final saved = await _api.updateSettings(token, changes);
      _apply(saved);
      await _save(saved);
    } catch (_) {
      _apply(previous);
      rethrow;
    }
  }

  /// Back to defaults and forget the cached copy (on logout).
  Future<void> reset() async {
    _apply(UserSettings.defaults);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  // ── Internals ───────────────────────────────────────────────────────────────

  void _apply(UserSettings s) {
    settings.value = s;
    themeMode.value = switch (s.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    weightUnit.value = s.weightUnit;
    locale.value = tagToLocale(s.locale);
  }

  /// 'sr-Latn' ↔ Locale('sr', scriptCode: 'Latn').
  static String localeToTag(Locale l) =>
      [l.languageCode, l.scriptCode, l.countryCode].whereType<String>().join('-');

  static Locale? tagToLocale(String? tag) {
    if (tag == null || tag.isEmpty) return null;
    final parts = tag.split(RegExp('[-_]'));
    String? script;
    String? country;
    for (final p in parts.skip(1)) {
      if (p.length == 4) {
        script = p;
      } else {
        country = p;
      }
    }
    return Locale.fromSubtags(languageCode: parts.first, scriptCode: script, countryCode: country);
  }

  Future<void> _save(UserSettings s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(s.toJson()));
    } catch (_) {}
  }

  static String _themeModeToApi(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
