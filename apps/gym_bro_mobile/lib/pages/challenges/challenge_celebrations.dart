import 'package:shared_preferences/shared_preferences.dart';

/// Which completed challenges already got their confetti on this device, so
/// opening one I just finished celebrates once.
class ChallengeCelebrations {
  ChallengeCelebrations._();

  static const _key = 'challenges_celebrated_v1';
  static const _keep = 100;

  static Future<bool> isCelebrated(String challengeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key) ?? const []).contains(challengeId);
    } catch (_) {
      return true; // No storage: don't risk celebrating on every open.
    }
  }

  static Future<void> markCelebrated(String challengeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = [...?prefs.getStringList(_key)]..remove(challengeId);
      ids.add(challengeId);
      await prefs.setStringList(_key, ids.length > _keep ? ids.sublist(ids.length - _keep) : ids);
    } catch (_) {
      // Celebrating again next time is harmless.
    }
  }
}
