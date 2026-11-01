import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Comes with flutter_local_notifications (zonedSchedule takes its TZDateTime).
// Only its built-in UTC location is used, so no zone database is loaded.
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import '../models/water.dart';
import '../utils/device_timezone.dart';
import 'api_service.dart';
import 'auth_manager.dart';
import 'health_sync_service.dart';
import 'push_service.dart';
import 'rest_activity_service.dart';
import 'settings_service.dart';

/// Today's water, shared by every screen that shows it (Home's ring, the
/// Water page, the food diary card), plus the water reminders.
///
/// Reminders are local notifications, scheduled on the device:
/// * every 2 hours from 09:00 to 21:00 local time ([waterReminderHours]),
///   for today and the next few days ([waterReminderDays]);
/// * today's are dropped once today's goal is reached, and every change to
///   today's water reschedules them (so the text says what's left);
/// * each one is a one-off at a fixed instant, so nothing repeats forever:
///   anyone who stops opening the app stops being reminded after a few days;
/// * turning them off in Settings, or signing out (settings reset to the
///   defaults), cancels them all.
class WaterService {
  WaterService._() {
    _remindersOn = SettingsService.instance.settings.value.waterReminders;
    SettingsService.instance.settings.addListener(_onSettings);
  }

  static final WaterService instance = WaterService._();

  late final _api = ApiService(); // lazy: constructing it starts offline monitoring

  /// Null until loaded (and after signing out).
  final ValueNotifier<WaterDay?> today = ValueNotifier(null);

  String? _userId;
  int _pendingIds = 0;

  // ── Today ───────────────────────────────────────────────────────────────────

  /// Loads today's water. Throws when it can't (callers fail soft).
  Future<WaterDay> refresh() async {
    _forgetOtherUser();
    final token = await AuthManager.instance.getValidToken();
    final day = await _api.getWaterToday(token, tz: await deviceTimezone());
    today.value = day;
    unawaited(syncReminders());
    return day;
  }

  /// Logs a drink of [ml]. Shows it straight away and replaces it with the
  /// server's copy; puts things back and rethrows if that fails.
  Future<WaterAdded> add(int ml) async {
    _forgetOtherUser();
    final before = today.value;
    if (before != null) {
      today.value = before.adding(WaterEntry(id: 'pending-${_pendingIds++}', ml: ml, loggedAt: DateTime.now()));
    }
    try {
      final token = await AuthManager.instance.getValidToken();
      final added = await _api.addWater(token, ml, tz: await deviceTimezone());
      today.value = added.today;
      unawaited(syncReminders());
      unawaited(HealthSyncService.instance.writeWater(ml, added.entry.loggedAt, entryId: added.entry.id));
      return added;
    } catch (_) {
      today.value = before;
      rethrow;
    }
  }

  /// Deletes one of today's drinks (undo, swipe to delete).
  Future<void> remove(String id) async {
    final before = today.value;
    final entry = before?.entries.where((e) => e.id == id).firstOrNull;
    if (before != null) today.value = before.removing(id);
    try {
      final token = await AuthManager.instance.getValidToken();
      today.value = await _api.deleteWater(token, id, tz: await deviceTimezone());
      unawaited(syncReminders());
      if (entry != null) unawaited(HealthSyncService.instance.deleteWater(id, entry.loggedAt));
    } catch (_) {
      today.value = before;
      rethrow;
    }
  }

  void _forgetOtherUser() {
    final id = AuthManager.instance.profile?.id;
    if (id != _userId) {
      _userId = id;
      today.value = null;
    }
  }

  // ── Reminders ───────────────────────────────────────────────────────────────

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _pluginReady = false;
  bool _remindersOn = false;
  Future<void> _sync = Future.value();

  static const _channelId = 'gym_bro_water';

  void _onSettings() {
    final on = SettingsService.instance.settings.value.waterReminders;
    if (!AuthManager.instance.hasSession) {
      _userId = null;
      today.value = null;
    }
    if (on == _remindersOn) return;
    _remindersOn = on;
    unawaited(syncReminders());
  }

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<bool> _ensurePlugin() async {
    if (_pluginReady) return true;
    if (!_supported) return false;
    // With push configured, PushService initialises the (shared) plugin at
    // startup with its tap handler; initialising again would replace it.
    if (!PushService.isConfigured) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        // The rest timer notification's buttons.
        onDidReceiveBackgroundNotificationResponse: restNotificationAction,
      );
    }
    final l10n = _l10n();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            _channelId,
            l10n.waterReminderChannel,
            description: l10n.waterReminderChannelDescription,
          ),
        );
    _pluginReady = true;
    return true;
  }

  /// Makes sure the shared notifications plugin is set up (the rest timer's
  /// notification uses it too). False where notifications aren't supported.
  Future<bool> ensureNotifications() async {
    try {
      return await _ensurePlugin();
    } catch (e) {
      debugPrint('WaterService: notifications unavailable: $e');
      return false;
    }
  }

  /// Asks for permission to notify (from the Settings switch). True when
  /// granted, or on platforms without reminders' permission prompt.
  Future<bool> requestPermission() async {
    try {
      if (!await _ensurePlugin()) return false;
      if (Platform.isAndroid) {
        return await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            true;
      }
      return await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    } catch (e) {
      debugPrint('WaterService: permission request failed: $e');
      return false;
    }
  }

  /// Cancels the scheduled water reminders and, when they're on, schedules
  /// them again from now. Never throws; calls run one after another.
  Future<void> syncReminders() => _sync = _sync.then((_) => _syncNow()).catchError((Object e) {
        debugPrint('WaterService: could not schedule reminders: $e');
      });

  Future<void> _syncNow() async {
    if (!await _ensurePlugin()) return;
    for (final id in waterReminderIds) {
      await _plugin.cancel(id: id);
    }
    final on = SettingsService.instance.settings.value.waterReminders && AuthManager.instance.hasSession;
    if (!on) return;

    final day = today.value;
    final now = DateTime.now();
    final isToday = day != null && day.date == DateTime(now.year, now.month, now.day);
    final l10n = _l10n();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        l10n.waterReminderChannel,
        channelDescription: l10n.waterReminderChannelDescription,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    for (final slot in waterReminderSchedule(now, goalReachedToday: isToday && day.reached)) {
      await _plugin.zonedSchedule(
        id: slot.id,
        scheduledDate: tz.TZDateTime.from(slot.at, tz.UTC),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: l10n.waterReminderTitle,
        body: slot.dayOffset == 0 && isToday
            ? l10n.waterReminderBodyLeft(waterAmount(l10n, day.remainingMl))
            : l10n.waterReminderBody,
      );
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
