import 'package:flutter/services.dart';

/// Light haptic ticks for small moments: likes and reactions, follows, tab
/// switches, toggles, successful saves and finished refreshes. Bigger moments
/// (PRs, finished workouts) use their own heavier feedback.
class Haptics {
  Haptics._();

  /// A light tap: likes, follows, saves.
  static void tap() => HapticFeedback.lightImpact();

  /// A selection tick: tabs, toggles, segmented choices.
  static void select() => HapticFeedback.selectionClick();

  /// Runs [refresh] (a pull-to-refresh callback) and ticks once it's done.
  static Future<void> refreshed(Future<void> Function() refresh) async {
    await refresh();
    HapticFeedback.lightImpact();
  }
}
