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
/// * Reads today's steps, last night's sleep and the latest resting heart
///   rate and HRV for the Today dashboard ([today]).
/// * Reads the heart rate and active calories a watch (or ring, strap...)
///   recorded during a workout ([workoutStats]), on demand.
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

  /// Bumped whenever [_access] asks for more; connections made before it are
  /// offered the new access in Settings ([needsNewAccess]).
  static const accessVersion = 2;

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

  /// Connected before [_access] grew: Settings offers to ask again.
  bool get needsNewAccess => isConnected && settings.value.accessVersion < accessVersion;

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

  /// Apple Watch measures SDNN; Health Connect stores RMSSD.
  static HealthDataType get _hrvType => !kIsWeb && Platform.isIOS
      ? HealthDataType.HEART_RATE_VARIABILITY_SDNN
      : HealthDataType.HEART_RATE_VARIABILITY_RMSSD;

  /// Everything asked for at once when connecting; the toggles only decide
  /// what's used.
  static List<(HealthDataType, HealthDataAccess)> get _access => [
        (HealthDataType.WEIGHT, HealthDataAccess.READ),
        (HealthDataType.STEPS, HealthDataAccess.READ),
        for (final t in _sleepTypes) (t, HealthDataAccess.READ),
        (HealthDataType.HEART_RATE, HealthDataAccess.READ),
        (HealthDataType.ACTIVE_ENERGY_BURNED, HealthDataAccess.READ),
        (HealthDataType.RESTING_HEART_RATE, HealthDataAccess.READ),
        (_hrvType, HealthDataAccess.READ),
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
      await _save(settings.value.copyWith(
        connected: true,
        userId: me,
        accessVersion: accessVersion,
        clearLastWeightImport: true,
      ));
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

  Future<void> update({
    bool? importWeight,
    bool? showActivity,
    bool? showWorkoutStats,
    bool? writeWorkouts,
    bool? writeWater,
  }) async {
    await _save(settings.value.copyWith(
      importWeight: importWeight,
      showActivity: showActivity,
      showWorkoutStats: showWorkoutStats,
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

  /// Reads today's steps, last night's sleep and the latest resting heart
  /// rate and HRV (at most every 5 minutes unless [force]).
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
        final restingHr = await _latest(health, HealthDataType.RESTING_HEART_RATE, now);
        final hrv = await _latest(health, _hrvType, now);
        _todayReadAt = now;
        today.value = HealthToday(
          steps: steps,
          sleepMinutes: sleep,
          restingHeartRate: restingHr?.round(),
          hrvMs: hrv?.round(),
          readAt: now,
        );
      });

  /// The newest reading of [type] from the last 24 hours, if any.
  Future<double?> _latest(Health health, HealthDataType type, DateTime now) async {
    try {
      final points = await health.getHealthDataFromTypes(
        types: [type],
        startTime: now.subtract(const Duration(hours: 24)),
        endTime: now,
      );
      HealthDataPoint? newest;
      for (final p in points) {
        if (p.value is! NumericHealthValue) continue;
        if (newest == null || p.dateTo.isAfter(newest.dateTo)) newest = p;
      }
      final v = (newest?.value as NumericHealthValue?)?.numericValue.toDouble();
      return v != null && v.isFinite && v > 0 ? v : null;
    } catch (e) {
      debugPrint('HealthSync: ${type.name}: $e');
      return null;
    }
  }

  /// Heart rate and active calories recorded during a finished workout of
  /// mine (by a watch, ring, strap...). Null when off, not mine, still
  /// running, or nothing was recorded. Read each time it's asked for, since
  /// a watch may sync its data a while after the workout.
  Future<HealthWorkoutStats?> workoutStats(TrainingSession session) => _serial<HealthWorkoutStats?>(() async {
        await init();
        final end = session.endedAt?.toLocal();
        if (!isConnected || !settings.value.showWorkoutStats || end == null) return null;
        if (session.userId != AuthManager.instance.profile?.id) return null;
        final start = session.startedAt.toLocal();
        if (!end.isAfter(start)) return null;
        final health = await _plugin();
        List<HealthDataPoint> heart = const [];
        try {
          heart = await health.getHealthDataFromTypes(
            types: const [HealthDataType.HEART_RATE],
            startTime: start,
            endTime: end,
          );
        } catch (e) {
          debugPrint('HealthSync: heart rate: $e');
        }
        List<HealthDataPoint> energy = const [];
        try {
          energy = await health.getHealthDataFromTypes(
            types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
            startTime: start,
            endTime: end,
          );
        } catch (e) {
          debugPrint('HealthSync: active energy: $e');
        }
        final hr = heartRateSummary([
          for (final p in heart)
            if (p.value is NumericHealthValue) (p.value as NumericHealthValue).numericValue,
        ]);
        final kcal = activeCalories([
          for (final p in energy)
            if (p.value is NumericHealthValue)
              HealthEnergySample(
                source: p.sourceId,
                from: p.dateFrom.toLocal(),
                to: p.dateTo.toLocal(),
                kcal: (p.value as NumericHealthValue).numericValue.toDouble(),
              ),
        ], start, end);
        final stats = HealthWorkoutStats(avgHeartRate: hr?.avg, maxHeartRate: hr?.max, activeKcal: kcal);
        return stats.isEmpty ? null : stats;
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

  /// Heart rate and calories on my finished workouts.
  final bool showWorkoutStats;
  final bool writeWorkouts;
  final bool writeWater;
  final DateTime? lastWeightImport;

  /// [HealthSyncService.accessVersion] when access was last asked for.
  final int accessVersion;

  /// Sessions already written (the newest 50), so none is saved twice.
  final List<String> writtenWorkouts;

  const HealthSyncSettings({
    this.connected = false,
    this.userId,
    this.importWeight = true,
    this.showActivity = true,
    this.showWorkoutStats = true,
    this.writeWorkouts = true,
    this.writeWater = true,
    this.lastWeightImport,
    this.accessVersion = HealthSyncService.accessVersion,
    this.writtenWorkouts = const [],
  });

  factory HealthSyncSettings.fromJson(Map<String, dynamic> j) => HealthSyncSettings(
        connected: j['connected'] == true,
        userId: j['user_id'] as String?,
        importWeight: j['import_weight'] != false,
        showActivity: j['show_activity'] != false,
        showWorkoutStats: j['show_workout_stats'] != false,
        writeWorkouts: j['write_workouts'] != false,
        writeWater: j['write_water'] != false,
        lastWeightImport: DateTime.tryParse('${j['last_weight_import']}'),
        // Saved before versions existed: the first access.
        accessVersion: j['access_version'] is int ? j['access_version'] as int : 1,
        writtenWorkouts: [for (final id in j['written_workouts'] as List? ?? const []) '$id'],
      );

  Map<String, dynamic> toJson() => {
        'connected': connected,
        'user_id': userId,
        'import_weight': importWeight,
        'show_activity': showActivity,
        'show_workout_stats': showWorkoutStats,
        'write_workouts': writeWorkouts,
        'write_water': writeWater,
        'last_weight_import': lastWeightImport?.toIso8601String(),
        'access_version': accessVersion,
        'written_workouts': writtenWorkouts,
      };

  HealthSyncSettings copyWith({
    bool? connected,
    String? userId,
    bool? importWeight,
    bool? showActivity,
    bool? showWorkoutStats,
    bool? writeWorkouts,
    bool? writeWater,
    DateTime? lastWeightImport,
    int? accessVersion,
    bool clearLastWeightImport = false,
    List<String>? writtenWorkouts,
  }) =>
      HealthSyncSettings(
        connected: connected ?? this.connected,
        userId: userId ?? this.userId,
        importWeight: importWeight ?? this.importWeight,
        showActivity: showActivity ?? this.showActivity,
        showWorkoutStats: showWorkoutStats ?? this.showWorkoutStats,
        writeWorkouts: writeWorkouts ?? this.writeWorkouts,
        writeWater: writeWater ?? this.writeWater,
        lastWeightImport: clearLastWeightImport ? null : (lastWeightImport ?? this.lastWeightImport),
        accessVersion: accessVersion ?? this.accessVersion,
        writtenWorkouts: writtenWorkouts ?? this.writtenWorkouts,
      );
}

/// Today's numbers from Health. Null fields: no data (or no access).
@immutable
class HealthToday {
  final int? steps;
  final int? sleepMinutes;

  /// The latest from the last 24 hours (bpm, ms).
  final int? restingHeartRate;
  final int? hrvMs;
  final DateTime readAt;

  const HealthToday({this.steps, this.sleepMinutes, this.restingHeartRate, this.hrvMs, required this.readAt});

  bool get isEmpty => steps == null && sleepMinutes == null && !hasRecovery;

  bool get hasRecovery => restingHeartRate != null || hrvMs != null;
}

/// What Health recorded during one workout. Null fields: no data.
@immutable
class HealthWorkoutStats {
  final int? avgHeartRate;
  final int? maxHeartRate;
  final int? activeKcal;

  const HealthWorkoutStats({this.avgHeartRate, this.maxHeartRate, this.activeKcal});

  bool get isEmpty => avgHeartRate == null && activeKcal == null;
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

/// Average and highest of [bpm] readings, ignoring implausible ones; null
/// without any.
({int avg, int max})? heartRateSummary(Iterable<num> bpm) {
  final ok = [
    for (final b in bpm)
      if (b.isFinite && b >= 25 && b <= 250) b.toDouble(),
  ];
  if (ok.isEmpty) return null;
  final sum = ok.fold<double>(0, (a, b) => a + b);
  return (avg: (sum / ok.length).round(), max: ok.reduce((a, b) => a > b ? a : b).round());
}

/// One active-energy sample read from Health.
@immutable
class HealthEnergySample {
  /// The app or device that recorded it.
  final String source;

  /// Local times.
  final DateTime from;
  final DateTime to;
  final double kcal;

  const HealthEnergySample({required this.source, required this.from, required this.to, required this.kcal});
}

/// Active calories burned between [start] and [end]. A sample only partly
/// inside counts in proportion. A phone and a watch both record the same
/// movement, so sources aren't added up: the one that recorded the most
/// wins. Null when nothing was recorded.
int? activeCalories(Iterable<HealthEnergySample> samples, DateTime start, DateTime end) {
  final bySource = <String, double>{};
  for (final s in samples) {
    if (!s.kcal.isFinite || s.kcal <= 0) continue;
    double share;
    if (!s.to.isAfter(s.from)) {
      share = s.from.isBefore(start) || s.from.isAfter(end) ? 0 : 1;
    } else {
      final a = s.from.isAfter(start) ? s.from : start;
      final b = s.to.isBefore(end) ? s.to : end;
      share = b.isAfter(a) ? b.difference(a).inMilliseconds / s.to.difference(s.from).inMilliseconds : 0;
    }
    if (share > 0) bySource[s.source] = (bySource[s.source] ?? 0) + s.kcal * share;
  }
  if (bySource.isEmpty) return null;
  final best = bySource.values.reduce((a, b) => a > b ? a : b).round();
  return best > 0 ? best : null;
}
