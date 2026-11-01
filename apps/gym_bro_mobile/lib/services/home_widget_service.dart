import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/plan_entry.dart';
import '../models/progress.dart' show trainingApiDate;
import '../models/streak.dart';
import '../models/water.dart';
import '../pages/streaks/streak_page.dart';
import '../pages/water/water_page.dart';
import '../utils/device_timezone.dart';
import '../widgets/streak_widgets.dart' show StreakTierLook;
import 'api_service.dart';
import 'auth_manager.dart';
import 'settings_service.dart';
import 'water_service.dart';

/// The App Group the iOS widget extension (home-screen widgets and the rest
/// Live Activity) shares with the app. Must match both targets'
/// entitlements and `gymBroAppGroup` in ios/GymBroWidgets/GymBroShared.swift.
const kAppGroupId = 'group.com.example.gymBroMobile';

/// One home-screen widget, by its iOS kind and Android provider.
enum GymBroWidget {
  streak('StreakWidget', 'StreakWidgetProvider'),
  water('WaterWidget', 'WaterWidgetProvider'),
  today('TodayWidget', 'TodayWidgetProvider');

  const GymBroWidget(this.iOSKind, this.androidProvider);

  final String iOSKind;
  final String androidProvider;

  String get qualifiedAndroidName => 'com.example.gym_bro_mobile.widgets.$androidProvider';
}

/// Feeds the home-screen widgets (streak, water, today's workout): the
/// numbers and already-translated labels go to the App Group (iOS) /
/// SharedPreferences (Android) through home_widget, then the widgets reload.
///
/// Updated on app start and resume, when the streak or water changes, and
/// when the Today dashboard loads today's plan ([setTodayWorkouts]).
/// Signing out leaves a "Sign in" widget. Tapping a widget opens the app on
/// its page ([openLink]).
class HomeWidgetService {
  HomeWidgetService._();

  static final HomeWidgetService instance = HomeWidgetService._();

  late final _api = ApiService(); // lazy: constructing it starts offline monitoring
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _started = false;
  AppLifecycleListener? _lifecycle;

  StreakStatus? _streak;
  List<PlanEntry>? _workouts;
  DateTime? _workoutsDay;
  String? _userId;
  DateTime? _refreshedAt;
  Timer? _pushSoon;

  static bool get supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Starts listening and fills the widgets once. Safe to call again.
  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    if (_started || !supported) return;
    _started = true;
    try {
      if (Platform.isIOS) await HomeWidget.setAppGroupId(kAppGroupId);
    } catch (e) {
      debugPrint('HomeWidget: no App Group: $e');
    }
    streakChanges.addListener(_onStreakChange);
    waterChanges.addListener(_schedulePush);
    WaterService.instance.today.addListener(_schedulePush);
    SettingsService.instance.settings.addListener(_onSettings);
    SettingsService.instance.locale.addListener(_schedulePush);
    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(refresh()));

    try {
      HomeWidget.widgetClicked.listen(openLink, onError: (Object e) => debugPrint('HomeWidget: $e'));
      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initial != null) unawaited(openLink(initial));
    } catch (e) {
      debugPrint('HomeWidget: launch link unavailable: $e');
    }
    // The session is restored right after start; give it a moment.
    Future.delayed(const Duration(seconds: 2), () => unawaited(refresh(force: true)));
  }

  /// Today's planned workouts, as the Today dashboard just loaded them.
  void setTodayWorkouts(List<PlanEntry> workouts) {
    final now = DateTime.now();
    _workouts = workouts;
    _workoutsDay = DateTime(now.year, now.month, now.day);
    // Signed in after start: the streak hasn't been loaded yet.
    if (_streak == null && AuthManager.instance.hasSession) {
      unawaited(refresh());
    } else {
      _schedulePush();
    }
  }

  /// Reloads the streak and today's plan, then updates the widgets. At most
  /// every 30 s unless [force].
  Future<void> refresh({bool force = false}) async {
    if (!_started) return;
    final now = DateTime.now();
    if (!force && _refreshedAt != null && now.difference(_refreshedAt!) < const Duration(seconds: 30)) {
      return _push();
    }
    _forgetOtherUser();
    if (!AuthManager.instance.hasSession) return _push();
    _refreshedAt = now;
    final tz = await deviceTimezone();
    await Future.wait([
      _loadStreak(tz),
      _loadWorkouts(tz),
      if (WaterService.instance.today.value == null) WaterService.instance.refresh().then((_) {}, onError: (Object _) {}),
    ]);
    await _push();
  }

  Future<void> _loadStreak(String? tz) async {
    try {
      final token = await AuthManager.instance.getValidToken();
      _streak = await _api.getStreak(token, tz: tz);
    } catch (e) {
      debugPrint('HomeWidget: streak: $e');
    }
  }

  Future<void> _loadWorkouts(String? tz) async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final entries = await _api.getPlanEntries(
        token,
        from: start,
        to: DateTime(now.year, now.month, now.day + 1),
        timezone: tz,
      );
      setTodayWorkouts(entries.where((e) => e.isWorkout).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt)));
    } catch (e) {
      debugPrint('HomeWidget: plan: $e');
    }
  }

  void _onStreakChange() {
    // A finished workout moves the streak and today's plan.
    _refreshedAt = null;
    unawaited(refresh(force: true));
  }

  void _onSettings() {
    if (!AuthManager.instance.hasSession) _forgetOtherUser();
    _schedulePush();
  }

  void _forgetOtherUser() {
    final id = AuthManager.instance.hasSession ? AuthManager.instance.profile?.id : null;
    if (id != _userId) {
      _userId = id;
      _streak = null;
      _workouts = null;
      _workoutsDay = null;
    }
  }

  /// Coalesces bursts of changes into one write.
  void _schedulePush() {
    if (!_started) return;
    _pushSoon?.cancel();
    _pushSoon = Timer(const Duration(milliseconds: 400), () => unawaited(_push()));
  }

  Future<void> _push() async {
    if (!_started) return;
    _forgetOtherUser();
    final now = DateTime.now();
    final signedIn = AuthManager.instance.hasSession;
    final today = DateTime(now.year, now.month, now.day);
    final water = WaterService.instance.today.value;
    final payload = homeWidgetPayload(
      _l10n(),
      now: now,
      signedIn: signedIn,
      streak: signedIn ? _streak : null,
      water: signedIn && water != null && water.date == today ? water : null,
      workouts: signedIn && _workoutsDay == today ? _workouts : null,
    );
    try {
      for (final e in payload.entries) {
        await HomeWidget.saveWidgetData<Object>(e.key, e.value);
      }
      for (final w in GymBroWidget.values) {
        await HomeWidget.updateWidget(iOSName: w.iOSKind, qualifiedAndroidName: w.qualifiedAndroidName);
      }
    } catch (e) {
      debugPrint('HomeWidget: update failed: $e');
    }
  }

  /// `gymbroo://widget/<page>` from a widget tap: streak and water open their
  /// pages; the rest just bring the app up.
  Future<void> openLink(Uri? uri) async {
    if (uri == null || uri.host != 'widget') return;
    final page = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    final Widget? target = switch (page) {
      'streak' => const StreakPage(),
      'water' => const WaterPage(),
      _ => null,
    };
    if (target == null) return;
    // Cold start: wait for the navigator and the restored session.
    for (var i = 0; i < 40; i++) {
      final nav = _navigatorKey?.currentState;
      if (nav != null && AuthManager.instance.profile != null) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        _navigatorKey?.currentState?.push(MaterialPageRoute(builder: (_) => target));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  /// Strings for the app language (or the device's), outside any widget tree.
  static AppLocalizations _l10n() {
    final locale = SettingsService.instance.locale.value ?? PlatformDispatcher.instance.locale;
    return lookupAppLocalizations(
      locale.languageCode == 'sr'
          ? const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn')
          : const Locale('en'),
    );
  }
}

/// What the widgets show, as home_widget keys (read by
/// ios/GymBroWidgets/GymBroShared.swift and the Android providers in
/// android/app/src/main/kotlin/.../widgets/). A null source leaves its keys
/// out (the streak) or blank (water and the plan are only good for [now]'s
/// day; the widgets ask to open the app then).
Map<String, Object> homeWidgetPayload(
  AppLocalizations l10n, {
  required DateTime now,
  required bool signedIn,
  StreakStatus? streak,
  WaterDay? water,
  List<PlanEntry>? workouts,
}) {
  final out = <String, Object>{
    'gb_signed_in': signedIn,
    'gb_day': trainingApiDate(now),
    'gb_streak_title': l10n.nativeWidgetStreak,
    'gb_water_title': l10n.waterTitle,
    'gb_today_title': l10n.nativeWidgetToday,
    'gb_signed_out_label': l10n.nativeWidgetSignedOut,
    'gb_stale_label': l10n.nativeWidgetOpenApp,
    'gb_streak_risk_label': l10n.streakProgressHintRisk,
  };
  if (!signedIn) {
    out.addAll({
      'gb_streak': 0,
      'gb_streak_lit': false,
      'gb_streak_risk': false,
      'gb_streak_tier': '',
      'gb_streak_label': l10n.streakWorkoutsInARow(0),
    });
  } else if (streak != null) {
    out.addAll({
      'gb_streak': streak.current,
      'gb_streak_lit': streak.current > 0,
      'gb_streak_risk': streak.needsWorkoutToday,
      'gb_streak_tier': streak.tier?.label(l10n) ?? '',
      'gb_streak_label': l10n.streakWorkoutsInARow(streak.current),
    });
  }

  out.addAll({
    'gb_water_ml': water?.totalMl ?? 0,
    'gb_water_goal_ml': water?.goalMl ?? 0,
    'gb_water_pct': water?.percent ?? 0,
    'gb_water_text': water == null ? '' : l10n.waterProgress(waterAmount(l10n, water.totalMl), waterAmount(l10n, water.goalMl)),
  });

  var name = '';
  var status = '';
  var done = false;
  var free = false;
  if (workouts != null) {
    final next = workouts.where((e) => e.status == PlanEntryStatus.planned).firstOrNull;
    if (workouts.isEmpty) {
      name = l10n.todayFreeDay;
      status = l10n.todayFreeDayHint;
      free = true;
    } else if (next != null) {
      name = _workoutName(l10n, next);
      final time = _hourMinute(next.startsAt.toLocal(), l10n.localeName);
      status = l10n.todayWorkoutWhen(time, next.durationMinutes);
    } else {
      name = _workoutName(l10n, workouts.last);
      status = l10n.todayAllDone;
      done = true;
    }
  }
  out.addAll({
    'gb_workout_name': name,
    'gb_workout_status': status,
    'gb_workout_done': done,
    'gb_workout_free': free,
  });
  return out;
}

/// "18:00" in [locale]; plain 24-hour when its date data isn't loaded
/// (outside the widget tree, before the app's localizations load).
String _hourMinute(DateTime t, String locale) {
  try {
    return DateFormat.Hm(locale).format(t);
  } catch (_) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

String _workoutName(AppLocalizations l10n, PlanEntry e) => e.trainingName ?? e.routineName ?? l10n.todayWorkoutFallback;
