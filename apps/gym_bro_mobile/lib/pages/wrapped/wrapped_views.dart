import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which years' Wrapped I've already watched on this device (the banner
/// stops offering a past year once it's been seen).
class WrappedViews {
  WrappedViews._();

  static const _key = 'wrapped_viewed_years_v1';

  /// Bumped when a year is marked viewed, so a banner on screen can hide.
  static final changes = ValueNotifier<int>(0);

  static Future<Set<int>> viewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {for (final y in prefs.getStringList(_key) ?? const <String>[]) ?int.tryParse(y)};
    } catch (_) {
      return {};
    }
  }

  static Future<void> markViewed(int year) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final years = {...?prefs.getStringList(_key), '$year'};
      await prefs.setStringList(_key, years.toList()..sort());
      changes.value++;
    } catch (_) {
      // The banner just shows again.
    }
  }
}
