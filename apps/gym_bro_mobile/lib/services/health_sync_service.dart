import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/progress.dart';
import '../models/training_session.dart';
import 'api_service.dart';
import 'auth_manager.dart';
import 'offline/outbox.dart' show QueuedOfflineException;
import 'settings_service.dart';

/// Apple Health (iOS) / Health Connect (Android) sync. Opt-in from Settings,
/// and per device: the connection lives in shared_preferences, tied to the
/// user who connected (someone else signing in on the phone starts
/// disconnected).
///
/// * Reads weigh-ins from the last 30 days into body measurements (on
///   connect and on resume, at most every [weightImportEvery]); see
///   [weighInsToImport] for which ones.
/// * Reads today's steps and last night's sleep for the Today dashboard
///   ([today]).
/// * Writes finished workouts (strength training, start/end) and each drink
///   of water logged.
///
/// Everything fails soft: unsupported, not installed or denied means nothing
/// happens.
class HealthSyncService {
  HealthSyncService._();

  static final HealthSyncService instance = HealthSyncService._();

  static const weightImportEvery = Duration(hours: 6);
  static const _prefsKey = 'health_sync.v1';

  /// The device's connection and choices (also before [init] finishes).
  final ValueNotifier<HealthSyncSettings> settings = ValueNotifier(const HealthSyncSettings());

  /// Today's steps and last night's sleep; null until read (or when off).
  final ValueNotifier<HealthToday?> today = ValueNotifier(null);

  Health? _health;
  Future<void>? _loading;
  AppLifecycleListener? _lifecycle;
  Future<void> _queue = Future.value();
  DateTime? _todayReadAt;

  bool get supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// "Apple Health" / "Health Connect" (brand names, not translated).
  String get platformName => !kIsWeb && Platform.isIOS ? 'Apple Health' : 'Health Connect';

  /// Connected, by the user who's signed in now.
  bool get isConnected {
    final s = settings.value;
    final me = AuthManager.instance.profile?.id;
    return supported && s.connected && me != null && s.userId == me;
  }

  // ── Setup ───────────────────────────────────────────────────────────────────

  /// Loads the saved connection and syncs on resume. Safe to call again.
  Future<void> init() {
    if (!supported) return Future.value();
    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(syncIfDue()));
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        settings.value = HealthSyncSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('HealthSync: could not load settings: $e');
    }
  }

  Future<void> _save(HealthSyncSettings next) async {
    settings.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(next.toJson()));
    } catch (e) {
      debugPrint('HealthSync: could not save settings: $e');
    }
  }

  Future<Health> _plugin() async {
    final h = _health ??= Health();
    await h.configure();
    return h;
  }

  /// Runs [job] after the ones before it; never throws.
  Future<T?> _serial<T>(Future<T> Function() job) {
    final done = Completer<T?>();
    _queue = _queue.then((_) async {
      try {
        done.complete(await job());
      } catch (e) {
        debugPrint('HealthSync: $e');
        done.complete(null);
      }
    });
    return done.future;
  }

  static List<HealthDataType> get _sleepTypes => !kIsWeb && Platform.isIOS
      ? const [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_DEEP, HealthDataType.SLEEP_LIGHT, HealthDataType.SLEEP_REM]
      : const [HealthDataType.SLEEP_SESSION];

  /// Everything asked for at once when connecting; the toggles only decide
  /// what's used.
  static List<(HealthDataType, HealthDataAccess)> get _access => [
        (HealthDataType.WEIGHT, HealthDataAccess.READ),
        (HealthDataType.STEPS, HealthDataAccess.READ),
        for (final t in _sleepTypes) (t, HealthDataAccess.READ),
        (HealthDataType.WORKOUT, HealthDataAccess.WRITE),
        (HealthDataType.WATER, HealthDataAccess.WRITE),
      ];

  // ── Connect / disconnect ────────────────────────────────────────────────────

  /// Asks for access and, when given, turns sync on and runs it once.
  Future<HealthConnectResult> connect() async {
    if (!supported) return HealthConnectResult.unsupported;
    await init();
    final me = AuthManager.instance.profile?.id;
    if (me == null) return HealthConnectResult.failed;
    try {
      final health = await _plugin();
      if (Platform.isAndroid) {
        final status = await health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) return HealthConnectResult.notInstalled;
      }
      final access = _access;
      final granted = await health.requestAuthorization(
        [for (final a in access) a.$1],
        permissions: [for (final a in access) a.$2],
      );
      if (!granted) return HealthConnectResult.denied;
      await _save(settings.value.copyWith(connected: true, userId: me, clearLastWeightImport: true));
      unawaited(importWeights(force: true));
      unawaited(refreshToday(force: true));
      return HealthConnectResult.connected;
    } catch (e) {
      debugPrint('HealthSync: connect failed: $e');
      return HealthConnectResult.failed;
    }
  }

  /// Opens the store page for Health Connect (Android).
  Future<void> installHealthConnect() async {
    try {
      await (await _plugin()).installHealthConnect();
    } catch (e) {
      debugPrint('HealthSync: install failed: $e');
    }
  }

  /// Stops syncing. On Android this also revokes Health Connect access; iOS
  /// doesn't let apps do that (the Health app does).
  Future<void> disconnect() async {
    await _save(settings.value.copyWith(connected: false, clearLastWeightImport: true));
    today.value = null;
    _todayReadAt = null;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await (await _plugin()).revokePermissions();
      } catch (e) {
        debugPrint('HealthSync: revoke failed: $e');
      }
    }
  }

  Future<void> update({bool? importWeight, bool? showActivity, bool? writeWorkouts, bool? writeWater}) async {
    await _save(settings.value.copyWith(
      importWeight: importWeight,
      showActivity: showActivity,
      writeWorkouts: writeWorkouts,
      writeWater: writeWater,
    ));
    if (showActivity == true) unawaited(refreshToday(force: true));
    if (showActivity == false) today.value = null;
    if (importWeight == true) unawaited(importWeights(force: true));
  }

  /// On resume (and app start): weigh-ins when due, today's numbers.
  Future<void> syncIfDue() async {
    await init();
    if (!isConnected) return;
    await Future.wait([importWeights(), refreshToday()]);
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  /// Imports new weigh-ins from the last 30 days. Returns how many were
  /// added, or null when it didn't run (off, not due, failed).
  Future<int?> importWeights({bool force = false}) => _serial<int?>(() async {
        await init();
        final s = settings.value;
        if (!isConnected || !s.importWeight) return null;
        final now = DateTime.now();
        final last = s.lastWeightImport;
        if (!force && last != null && now.difference(last) < weightImportEvery) return null;

        final health = await _plugin();
        final points = await health.getHealthDataFromTypes(
          types: const [HealthDataType.WEIGHT],
          startTime: now.subtract(const Duration(days: 30)),
          endTime: now,
        );
        final readings = [
          for (final p in points)
            if (p.value is NumericHealthValue)
              HealthWeighIn(at: p.dateFrom.toLocal(), kg: (p.value as NumericHealthValue).numericValue.toDouble()),
        ];

        final api = ApiService();
        final token = await AuthManager.instance.getValidToken();
        final existing = await api.getBodyMeasurements(token, from: now.subtract(const Duration(days: 31)));
        final todo = weighInsToImport(readings, {for (final m in existing) m.measuredOn});

        var added = 0;
        for (final w in todo) {
          try {
            await api.createBodyMeasurement(token, {
              'measured_on': trainingApiDate(w.at),
              'weight_kg': w.kg,
              'note': _l10n().nativeHealthWeighInNote(platformName),
            });
            added++;
          } on QueuedOfflineException {
            added++;
          } catch (e) {
            // 409: that day got a measurement meanwhile. Anything else: try
            // the rest; the next run picks up what's left.
            debugPrint('HealthSync: weigh-in ${trainingApiDate(w.at)} not imported: $e');
          }
        }
        await _save(settings.value.copyWith(lastWeightImport: now));
        return added;
      });

  /// Reads today's steps and last night's sleep (at most every 5 minutes
  /// unless [force]).
  Future<void> refreshToday({bool force = false}) => _serial(() async {
        await init();
        if (!isConnected || !settings.value.showActivity) {
          today.value = null;
          return;
        }
        final now = DateTime.now();
        if (!force && _todayReadAt != null && now.difference(_todayReadAt!) < const Duration(minutes: 5)) return;
        final health = await _plugin();
        final midnight = DateTime(now.year, now.month, now.day);
        int? steps;
        try {
          steps = await health.getTotalStepsInInterval(midnight, now);
        } catch (e) {
          debugPrint('HealthSync: steps: $e');
        }
        int? sleep;
        try {
          final window = sleepWindow(now);
          final points = await health.getHealthDataFromTypes(
            types: _sleepTypes,
            startTime: window.start,
            endTime: window.end,
          );
          sleep = points.isEmpty
              ? null
              : asleepMinutes([for (final p in points) (p.dateFrom.toLocal(), p.dateTo.toLocal())]);
        } catch (e) {
          debugPrint('HealthSync: sleep: $e');
        }
        _todayReadAt = now;
        today.value = HealthToday(steps: steps, sleepMinutes: sleep, readAt: now);
      });

  // ── Write ───────────────────────────────────────────────────────────────────

  /// Saves a finished workout of mine (not one a trainer logged for a
  /// client). [logged] is true for one entered after the fact.
  Future<void> writeWorkout(TrainingSession session, {bool logged = false}) => _serial(() async {
        await init();
        final end = session.endedAt;
        if (!isConnected || !settings.value.writeWorkouts || end == null) return;
        if (session.userId != AuthManager.instance.profile?.id) return;
        if (settings.value.writtenWorkouts.contains(session.id)) return;
        final start = session.startedAt.toLocal();
        if (!end.toLocal().isAfter(start)) return;
        final ok = await (await _plugin()).writeWorkoutData(
          activityType: Platform.isIOS
              ? HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING
              : HealthWorkoutActivityType.STRENGTH_TRAINING,
          start: start,
          end: end.toLocal(),
          // Gym Bro doesn't know calories burned; nothing is made up.
          title: session.trainingName,
          recordingMethod: logged ? RecordingMethod.manual : RecordingMethod.automatic,
        );
        if (ok) {
          final written = [...settings.value.writtenWorkouts, session.id];
          await _save(settings.value.copyWith(
            writtenWorkouts: written.length > 50 ? written.sublist(written.length - 50) : written,
          ));
        }
      });

  /// Strings for the app language (or the device's), outside any widget tree.
  static AppLocalizations _l10n() {
    final locale = SettingsService.instance.locale.value ?? PlatformDispatcher.instance.locale;
    return lookupAppLocalizations(
      locale.languageCode == 'sr'
          ? const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn')
          : const Locale('en'),
    );
  }

  /// Saves one drink of [ml] (logged at [at]). [entryId] (the water log's
  /// id) lets [deleteWater] find it again.
  Future<void> writeWater(int ml, DateTime at, {String? entryId}) => _serial(() async {
        await init();
        if (!isConnected || !settings.value.writeWater || ml <= 0) return;
        await (await _plugin()).writeHealthData(
          value: ml / 1000,
          unit: HealthDataUnit.LITER,
          type: HealthDataType.WATER,
          startTime: at,
          endTime: at,
          clientRecordId: entryId == null ? null : waterRecordId(entryId),
          recordingMethod: RecordingMethod.manual,
        );
      });

  /// Removes a deleted drink from Health. Health Connect finds it by the id
  /// it was written with; HealthKit by time (it only ever deletes this app's
  /// own samples, and two drinks are never logged in the same second).
  Future<void> deleteWater(String entryId, DateTime at) => _serial(() async {
        await init();
        if (!isConnected || !settings.value.writeWater) return;
        final health = await _plugin();
        if (Platform.isAndroid) {
          await health.deleteByClientRecordId(dataTypeKey: HealthDataType.WATER, clientRecordId: waterRecordId(entryId));
        } else {
          await health.delete(
            type: HealthDataType.WATER,
            startTime: at.subtract(const Duration(seconds: 1)),
            endTime: at.add(const Duration(seconds: 1)),
          );
        }
      });

  @visibleForTesting
  static String waterRecordId(String entryId) => 'gymbro-water-$entryId';
}

// ── State ─────────────────────────────────────────────────────────────────────

enum HealthConnectResult { connected, denied, notInstalled, unsupported, failed }

/// Device-local Health settings.
@immutable
class HealthSyncSettings {
  final bool connected;

  /// Who connected (sync only runs for them).
  final String? userId;
  final bool importWeight;
  final bool showActivity;
  final bool writeWorkouts;
  final bool writeWater;
  final DateTime? lastWeightImport;

  /// Sessions already written (the newest 50), so none is saved twice.
  final List<String> writtenWorkouts;

  const HealthSyncSettings({
    this.connected = false,
    this.userId,
    this.importWeight = true,
    this.showActivity = true,
    this.writeWorkouts = true,
    this.writeWater = true,
    this.lastWeightImport,
    this.writtenWorkouts = const [],
  });

  factory HealthSyncSettings.fromJson(Map<String, dynamic> j) => HealthSyncSettings(
        connected: j['connected'] == true,
        userId: j['user_id'] as String?,
        importWeight: j['import_weight'] != false,
        showActivity: j['show_activity'] != false,
        writeWorkouts: j['write_workouts'] != false,
        writeWater: j['write_water'] != false,
        lastWeightImport: DateTime.tryParse('${j['last_weight_import']}'),
        writtenWorkouts: [for (final id in j['written_workouts'] as List? ?? const []) '$id'],
      );

  Map<String, dynamic> toJson() => {
        'connected': connected,
        'user_id': userId,
        'import_weight': importWeight,
        'show_activity': showActivity,
        'write_workouts': writeWorkouts,
        'write_water': writeWater,
        'last_weight_import': lastWeightImport?.toIso8601String(),
        'written_workouts': writtenWorkouts,
      };

  HealthSyncSettings copyWith({
    bool? connected,
    String? userId,
    bool? importWeight,
    bool? showActivity,
    bool? writeWorkouts,
    bool? writeWater,
    DateTime? lastWeightImport,
    bool clearLastWeightImport = false,
    List<String>? writtenWorkouts,
  }) =>
      HealthSyncSettings(
        connected: connected ?? this.connected,
        userId: userId ?? this.userId,
        importWeight: importWeight ?? this.importWeight,
        showActivity: showActivity ?? this.showActivity,
        writeWorkouts: writeWorkouts ?? this.writeWorkouts,
        writeWater: writeWater ?? this.writeWater,
        lastWeightImport: clearLastWeightImport ? null : (lastWeightImport ?? this.lastWeightImport),
        writtenWorkouts: writtenWorkouts ?? this.writtenWorkouts,
      );
}

/// Today's numbers from Health. Null fields: no data (or no access).
@immutable
class HealthToday {
  final int? steps;
  final int? sleepMinutes;
  final DateTime readAt;

  const HealthToday({this.steps, this.sleepMinutes, required this.readAt});

  bool get isEmpty => steps == null && sleepMinutes == null;
}

// ── Pure parts (unit-tested) ──────────────────────────────────────────────────

/// One weigh-in read from Health.
@immutable
class HealthWeighIn {
  /// Local time.
  final DateTime at;
  final double kg;

  const HealthWeighIn({required this.at, required this.kg});

  DateTime get day => DateTime(at.year, at.month, at.day);

  @override
  bool operator ==(Object other) => other is HealthWeighIn && other.at == at && other.kg == kg;

  @override
  int get hashCode => Object.hash(at, kg);

  @override
  String toString() => 'HealthWeighIn($at, $kg kg)';
}

/// Which weigh-ins to add as body measurements: at most one per day (the
/// day's last reading; duplicates of the same value from several sources
/// collapse), none on a day that already has a measurement ([existingDays],
/// local midnights), and none that isn't a plausible body weight. Rounded
/// to 0.01 kg, oldest first.
List<HealthWeighIn> weighInsToImport(Iterable<HealthWeighIn> readings, Set<DateTime> existingDays) {
  final taken = {for (final d in existingDays) DateTime(d.year, d.month, d.day)};
  final latest = <DateTime, HealthWeighIn>{};
  for (final r in readings) {
    if (!r.kg.isFinite || r.kg < 20 || r.kg > 400) continue;
    final day = r.day;
    if (taken.contains(day)) continue;
    final had = latest[day];
    if (had == null || r.at.isAfter(had.at)) latest[day] = r;
  }
  final out = [
    for (final r in latest.values) HealthWeighIn(at: r.at, kg: (r.kg * 100).round() / 100),
  ]..sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// "Last night": from 18:00 yesterday until noon today (or now, if earlier).
({DateTime start, DateTime end}) sleepWindow(DateTime now) {
  final midnight = DateTime(now.year, now.month, now.day);
  final noon = midnight.add(const Duration(hours: 12));
  return (
    start: midnight.subtract(const Duration(hours: 6)),
    end: now.isBefore(noon) ? now : noon,
  );
}

/// Minutes covered by [intervals], counting overlaps once (a watch and a
/// phone both recording the same night, or stages inside a session).
int asleepMinutes(Iterable<(DateTime, DateTime)> intervals) {
  final sorted = [
    for (final (a, b) in intervals)
      if (b.isAfter(a)) (a, b),
  ]..sort((x, y) => x.$1.compareTo(y.$1));
  var total = Duration.zero;
  DateTime? start;
  DateTime? end;
  for (final (a, b) in sorted) {
    if (end == null || a.isAfter(end)) {
      if (start != null) total += end!.difference(start);
      start = a;
      end = b;
    } else if (b.isAfter(end)) {
      end = b;
    }
  }
  if (start != null) total += end!.difference(start);
  return total.inMinutes;
}
