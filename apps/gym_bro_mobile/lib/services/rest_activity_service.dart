import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:ui' show Color, IsolateNameServer, Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:live_activities/live_activities.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import 'home_widget_service.dart' show kAppGroupId;
import 'settings_service.dart';
import 'water_service.dart';

/// The rest timer outside the app, while a rest runs:
/// * iOS: a Live Activity on the Lock Screen and in the Dynamic Island
///   (ios/GymBroWidgets/RestLiveActivity.swift), ticking by itself;
/// * Android: an ongoing, silent notification with a countdown chronometer
///   and "+30 s" / "Skip" buttons.
///
/// On iOS a "Rest's over" notification is also scheduled for the end, since
/// a suspended app can't tell the Live Activity's 0:00 apart from anything
/// else (Android keeps the app's own timer running).
///
/// [RestTimerController] drives it: [show] when a rest starts or changes,
/// [end] when it's over, skipped, or the session closes. Fails soft: not
/// supported, not enabled or not allowed means nothing happens.
class RestActivityService {
  RestActivityService._();

  static final RestActivityService instance = RestActivityService._();

  static const _activityId = 'gym_bro_rest';
  static const _notificationId = 7310;
  static const _restOverId = 7311;
  static const _channelId = 'gym_bro_rest';
  static const actionAdd = 'rest_add_30';
  static const actionSkip = 'rest_skip';
  static const _portName = 'gym_bro_rest_actions';
  static const _askedKey = 'rest_activity.asked_permission';

  /// Seconds the "+30 s" button adds.
  static const addSeconds = 30;

  Future<void> _queue = Future.value();
  bool _showing = false;
  DateTime? _endsAt;
  RestActivityActions? _actions;
  ReceivePort? _port;

  static bool get _android => !kIsWeb && Platform.isAndroid;
  static bool get _ios => !kIsWeb && Platform.isIOS;

  /// Shows (or moves) the rest: [endsAt] is when it's over. [actions] gets
  /// the notification's buttons (Android).
  Future<void> show({
    required DateTime startedAt,
    required DateTime endsAt,
    String? exercise,
    String? next,
    RestActivityActions? actions,
  }) {
    _actions = actions;
    _endsAt = endsAt;
    return _run(() async {
      if (_ios) {
        await _showIos(startedAt, endsAt, exercise, next);
        await _scheduleRestOver(endsAt, next);
      } else if (_android) {
        await _showAndroid(endsAt, exercise, next);
      }
    });
  }

  /// Takes the rest off the lock screen.
  Future<void> end() {
    _actions = null;
    // Ended early (skipped, session closed): the alert mustn't go off. At
    // the end itself it stays, in case the app is about to be suspended.
    final early = _endsAt != null && DateTime.now().isBefore(_endsAt!.subtract(const Duration(seconds: 2)));
    _endsAt = null;
    return _run(() async {
      if (_ios && early) await FlutterLocalNotificationsPlugin().cancel(id: _restOverId);
      if (!_showing) return;
      _showing = false;
      if (_ios) {
        await _liveActivities.endAllActivities();
      } else if (_android) {
        await FlutterLocalNotificationsPlugin().cancel(id: _notificationId);
      }
    });
  }

  /// Runs [job] after the ones before it; never throws.
  Future<void> _run(Future<void> Function() job) => _queue = _queue.then((_) => job()).catchError((Object e) {
        debugPrint('RestActivity: $e');
      });

  // ── iOS: Live Activity ──────────────────────────────────────────────────────

  final _liveActivities = LiveActivities();
  bool? _iosReady;

  Future<bool> _ensureIos() async {
    if (_iosReady != null) return _iosReady!;
    try {
      await _liveActivities.init(appGroupId: kAppGroupId, requestAndroidNotificationPermission: false);
      final ok = await _liveActivities.areActivitiesSupported() && await _liveActivities.areActivitiesEnabled();
      // One left over from a crash or a killed app.
      if (ok) await _liveActivities.endAllActivities();
      return _iosReady = ok;
    } catch (e) {
      debugPrint('RestActivity: Live Activities unavailable: $e');
      return _iosReady = false;
    }
  }

  Future<void> _showIos(DateTime startedAt, DateTime endsAt, String? exercise, String? next) async {
    if (!await _ensureIos()) return;
    final l10n = _l10n();
    await _liveActivities.createOrUpdateActivity(
      _activityId,
      {
        'title': l10n.nativeRestTitle,
        'exercise': exercise ?? '',
        'next': next == null || next.isEmpty ? '' : l10n.nativeRestNext(next),
        'startMs': startedAt.millisecondsSinceEpoch,
        'endMs': endsAt.millisecondsSinceEpoch,
      },
      removeWhenAppIsKilled: true,
      iOSEnableRemoteUpdates: false,
    );
    _showing = true;
  }

  /// "Rest's over" at [endsAt] (replacing the previous one). Silent while
  /// the app is open, where the in-app timer already says so.
  Future<void> _scheduleRestOver(DateTime endsAt, String? next) async {
    if (!await WaterService.instance.ensureNotifications()) return;
    await _askOnce();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.cancel(id: _restOverId);
    if (!endsAt.isAfter(DateTime.now())) return;
    final l10n = _l10n();
    await plugin.zonedSchedule(
      id: _restOverId,
      scheduledDate: tz.TZDateTime.from(endsAt, tz.UTC),
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBanner: false,
          presentList: false,
          presentSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: l10n.nativeRestOverTitle,
      body: next == null || next.isEmpty ? l10n.nativeRestOverBody : l10n.nativeRestNext(next),
    );
  }

  // ── Android: ongoing notification ───────────────────────────────────────────

  Future<void> _showAndroid(DateTime endsAt, String? exercise, String? next) async {
    if (!await WaterService.instance.ensureNotifications()) return;
    await _askOnce();
    _listenForActions();
    final l10n = _l10n();
    final plugin = FlutterLocalNotificationsPlugin();
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        l10n.nativeRestChannel,
        description: l10n.nativeRestChannelDescription,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
    final left = endsAt.difference(DateTime.now());
    if (left <= Duration.zero) return;
    await plugin.show(
      id: _notificationId,
      title: exercise == null || exercise.isEmpty ? l10n.nativeRestTitle : '${l10n.nativeRestTitle} · $exercise',
      body: next == null || next.isEmpty ? l10n.nativeRestBody : l10n.nativeRestNext(next),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          l10n.nativeRestChannel,
          channelDescription: l10n.nativeRestChannelDescription,
          icon: 'ic_stat_rest',
          color: const Color(0xFFFF7A1A),
          importance: Importance.low,
          priority: Priority.low,
          category: AndroidNotificationCategory.stopwatch,
          visibility: NotificationVisibility.public,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          silent: true,
          showWhen: true,
          when: endsAt.millisecondsSinceEpoch,
          usesChronometer: true,
          chronometerCountDown: true,
          // Gone by itself if the app can't take it down in time.
          timeoutAfter: left.inMilliseconds + 1000,
          actions: [
            AndroidNotificationAction(actionAdd, l10n.nativeRestAdd30, cancelNotification: false),
            AndroidNotificationAction(actionSkip, l10n.nativeRestSkip),
          ],
        ),
      ),
    );
    _showing = true;
  }

  /// Asks before showing notifications (Android 13+, iOS): once, at the first rest.
  Future<void> _askOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) == true) return;
      await prefs.setBool(_askedKey, true);
      await WaterService.instance.requestPermission();
    } catch (_) {}
  }

  /// The buttons are handled in a background isolate (see
  /// [restNotificationAction]), which forwards them here.
  void _listenForActions() {
    if (_port != null) return;
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(_portName);
    if (!IsolateNameServer.registerPortWithName(port.sendPort, _portName)) {
      port.close();
      return;
    }
    _port = port;
    port.listen((message) {
      handleAction(message is String ? message : null);
    });
  }

  /// Applies a notification button to the running rest.
  @visibleForTesting
  void handleAction(String? actionId) {
    final actions = _actions;
    if (actions == null) return;
    if (actionId == actionAdd) actions.onAdd(addSeconds);
    if (actionId == actionSkip) actions.onSkip();
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

/// What the rest notification's buttons do.
class RestActivityActions {
  final void Function(int seconds) onAdd;
  final VoidCallback onSkip;

  const RestActivityActions({required this.onAdd, required this.onSkip});
}

/// flutter_local_notifications runs this in a background isolate when a
/// notification button that doesn't open the app is tapped (both places that
/// initialise the plugin pass it). Rest buttons go to the app's isolate,
/// where the rest timer runs; anything else is ignored.
@pragma('vm:entry-point')
void restNotificationAction(NotificationResponse response) {
  final id = response.actionId;
  if (id != RestActivityService.actionAdd && id != RestActivityService.actionSkip) return;
  IsolateNameServer.lookupPortByName(RestActivityService._portName)?.send(id);
}
