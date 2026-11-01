// Exercise progress, personal records, body measurements.
//
// All weights are kilograms (convert with SettingsService at the UI edge).
// Postgres numerics may arrive as strings, so every number goes through
// [_toDouble] / [_toInt].

import '../config.dart';
import 'exercise.dart' show muscleValues;

double? _toDouble(dynamic v) =>
    v == null ? null : double.tryParse(v.toString());

int _toInt(dynamic v) => v == null
    ? 0
    : (int.tryParse(v.toString()) ??
          double.tryParse(v.toString())?.round() ??
          0);

DateTime? _toDate(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());

/// A session whose best e1RM for an exercise beat every earlier session.
class PersonalRecord {
  final String exerciseId;
  final String exerciseName;
  final String sessionId;
  final DateTime date;
  final double e1rm;
  final double? previousE1rm;
  final double? weightKg;
  final int reps;

  const PersonalRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.sessionId,
    required this.date,
    required this.e1rm,
    this.previousE1rm,
    this.weightKg,
    required this.reps,
  });

  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
    exerciseId: json['exercise_id'] as String,
    exerciseName: json['exercise_name'] as String? ?? 'Exercise',
    sessionId: json['session_id'] as String,
    date: _toDate(json['date']) ?? DateTime.now(),
    e1rm: _toDouble(json['e1rm']) ?? 0,
    previousE1rm: _toDouble(json['previous_e1rm']),
    weightKg: _toDouble(json['weight_kg']),
    reps: _toInt(json['reps']),
  );

  /// Improvement over the previous best, in kg.
  double? get gainKg => previousE1rm == null ? null : e1rm - previousE1rm!;
}

/// GET /progress/summary
class ProgressSummary {
  final String userId;
  final int sessions7d;
  final int sessions30d;
  final int sessionsTotal;
  final DateTime? lastSessionAt;
  final double volume30dKg;
  final int streakWeeks;
  final bool trainedThisWeek;
  final List<PersonalRecord> recentPrs;

  const ProgressSummary({
    required this.userId,
    required this.sessions7d,
    required this.sessions30d,
    required this.sessionsTotal,
    this.lastSessionAt,
    required this.volume30dKg,
    required this.streakWeeks,
    required this.trainedThisWeek,
    required this.recentPrs,
  });

  factory ProgressSummary.fromJson(Map<String, dynamic> json) =>
      ProgressSummary(
        userId: json['user_id'] as String? ?? '',
        sessions7d: _toInt(json['sessions_7d']),
        sessions30d: _toInt(json['sessions_30d']),
        sessionsTotal: _toInt(json['sessions_total']),
        lastSessionAt: _toDate(json['last_session_at']),
        volume30dKg: _toDouble(json['volume_30d_kg']) ?? 0,
        streakWeeks: _toInt(json['streak_weeks']),
        trainedThisWeek: json['trained_this_week'] as bool? ?? false,
        recentPrs: (json['recent_prs'] as List<dynamic>? ?? [])
            .map((e) => PersonalRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One row of GET /progress/exercises.
class ExerciseProgress {
  final String id;
  final String name;
  final List<String> primaryMuscles;
  final int sessionCount;
  final DateTime? lastPerformed;
  final double? bestWeightKg;
  final double? bestE1rm;

  /// Per-session best e1RM (else best weight) for the last 12 sessions,
  /// oldest first. Values are kg.
  final List<double> trend;

  const ExerciseProgress({
    required this.id,
    required this.name,
    required this.primaryMuscles,
    required this.sessionCount,
    this.lastPerformed,
    this.bestWeightKg,
    this.bestE1rm,
    required this.trend,
  });

  factory ExerciseProgress.fromJson(Map<String, dynamic> json) =>
      ExerciseProgress(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Exercise',
        primaryMuscles: muscleValues(json['primary_muscles']),
        sessionCount: _toInt(json['session_count']),
        lastPerformed: _toDate(json['last_performed']),
        bestWeightKg: _toDouble(json['best_weight_kg']),
        bestE1rm: _toDouble(json['best_e1rm']),
        trend: (json['trend'] as List<dynamic>? ?? [])
            .map(_toDouble)
            .whereType<double>()
            .toList(),
      );
}

/// One session in an exercise's history.
class ExerciseSeriesPoint {
  final String sessionId;
  final DateTime date;
  final double? bestWeightKg;
  final double? bestE1rm;
  final double volumeKg;
  final int totalReps;

  const ExerciseSeriesPoint({
    required this.sessionId,
    required this.date,
    this.bestWeightKg,
    this.bestE1rm,
    required this.volumeKg,
    required this.totalReps,
  });

  factory ExerciseSeriesPoint.fromJson(Map<String, dynamic> json) =>
      ExerciseSeriesPoint(
        sessionId: json['session_id'] as String,
        date: _toDate(json['date']) ?? DateTime.now(),
        bestWeightKg: _toDouble(json['best_weight_kg']),
        bestE1rm: _toDouble(json['best_e1rm']),
        volumeKg: _toDouble(json['volume_kg']) ?? 0,
        totalReps: _toInt(json['total_reps']),
      );
}

/// An all-time best value and the session that set it.
class ExerciseRecord {
  final double value;
  final String sessionId;
  final DateTime date;

  const ExerciseRecord({
    required this.value,
    required this.sessionId,
    required this.date,
  });

  static ExerciseRecord? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final v = _toDouble(json['value']);
    if (v == null) return null;
    return ExerciseRecord(
      value: v,
      sessionId: json['session_id'] as String? ?? '',
      date: _toDate(json['date']) ?? DateTime.now(),
    );
  }
}

/// GET /progress/exercises/:id
class ExerciseProgressDetail {
  final String exerciseId;
  final String exerciseName;
  final List<String> primaryMuscles;
  final List<ExerciseSeriesPoint> series;
  final ExerciseRecord? bestWeight;
  final ExerciseRecord? bestE1rm;
  final ExerciseRecord? bestVolume;

  const ExerciseProgressDetail({
    required this.exerciseId,
    required this.exerciseName,
    required this.primaryMuscles,
    required this.series,
    this.bestWeight,
    this.bestE1rm,
    this.bestVolume,
  });

  factory ExerciseProgressDetail.fromJson(Map<String, dynamic> json) {
    final ex = json['exercise'] as Map<String, dynamic>? ?? const {};
    final prs = json['prs'] as Map<String, dynamic>? ?? const {};
    return ExerciseProgressDetail(
      exerciseId: ex['id'] as String? ?? '',
      exerciseName: ex['name'] as String? ?? 'Exercise',
      primaryMuscles: muscleValues(ex['primary_muscles']),
      series: (json['series'] as List<dynamic>? ?? [])
          .map((e) => ExerciseSeriesPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      bestWeight: ExerciseRecord.fromJson(prs['best_weight_kg']),
      bestE1rm: ExerciseRecord.fromJson(prs['best_e1rm']),
      bestVolume: ExerciseRecord.fromJson(prs['best_volume_kg']),
    );
  }
}

/// 'YYYY-MM-DD' → a local calendar date (no UTC shift); null when unparsable.
DateTime? _localDay(dynamic v) {
  final parts = (v?.toString() ?? '').split('T').first.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  return y == null || m == null || d == null ? null : DateTime(y, m, d);
}

/// A body_measurement row. [measuredOn] is a local calendar date. Tape
/// measurements are centimetres.
class BodyMeasurement {
  final String id;
  final String userId;
  final DateTime measuredOn;
  final double? weightKg;
  final double? bodyFatPct;
  final double? waistCm;
  final double? chestCm;
  final double? hipsCm;
  final double? armCm;
  final double? thighCm;
  final double? neckCm;
  final String? note;
  final DateTime? createdAt;

  const BodyMeasurement({
    required this.id,
    required this.userId,
    required this.measuredOn,
    this.weightKg,
    this.bodyFatPct,
    this.waistCm,
    this.chestCm,
    this.hipsCm,
    this.armCm,
    this.thighCm,
    this.neckCm,
    this.note,
    this.createdAt,
  });

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    return BodyMeasurement(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      measuredOn: _localDay(json['measured_on']) ?? DateTime.now(),
      weightKg: _toDouble(json['weight_kg']),
      bodyFatPct: _toDouble(json['body_fat_pct']),
      waistCm: _toDouble(json['waist_cm']),
      chestCm: _toDouble(json['chest_cm']),
      hipsCm: _toDouble(json['hips_cm']),
      armCm: _toDouble(json['arm_cm']),
      thighCm: _toDouble(json['thigh_cm']),
      neckCm: _toDouble(json['neck_cm']),
      note: json['note'] as String?,
      createdAt: _toDate(json['created_at']),
    );
  }

  /// Any tape measurement logged in this entry.
  bool get hasTape => BodyMetric.tape.any((m) => m.valueOf(this) != null);
}

/// What a body chart can show. Tape metrics are lengths in cm; the API keys
/// match the body_measurement columns.
enum BodyMetric {
  weight('weight_kg'),
  bodyFat('body_fat_pct'),
  waist('waist_cm', min: 30, max: 250),
  chest('chest_cm', min: 40, max: 250),
  hips('hips_cm', min: 40, max: 250),
  arm('arm_cm', min: 10, max: 100),
  thigh('thigh_cm', min: 20, max: 150),
  neck('neck_cm', min: 15, max: 80);

  final String apiKey;

  /// Accepted range in cm for tape metrics (matches the API).
  final double? min;
  final double? max;
  const BodyMetric(this.apiKey, {this.min, this.max});

  static const tape = [waist, chest, hips, arm, thigh, neck];

  bool get isLength => min != null;

  double? valueOf(BodyMeasurement m) => switch (this) {
    weight => m.weightKg,
    bodyFat => m.bodyFatPct,
    waist => m.waistCm,
    chest => m.chestCm,
    hips => m.hipsCm,
    arm => m.armCm,
    thigh => m.thighCm,
    neck => m.neckCm,
  };
}

/// How a progress photo was taken.
enum ProgressPose {
  front,
  side,
  back,
  other;

  String get api => name;

  static ProgressPose fromApi(dynamic v) =>
      values.firstWhere((p) => p.name == v, orElse: () => ProgressPose.other);
}

/// A private progress photo (GET /progress-photos). Only its owner ever
/// sees it. [url] is an absolute, short-lived signed URL.
class ProgressPhoto {
  final String id;
  final String userId;
  final ProgressPose pose;
  final DateTime takenOn;
  final double? weightKg;
  final String? note;
  final DateTime? createdAt;
  final String? url;

  const ProgressPhoto({
    required this.id,
    required this.userId,
    required this.pose,
    required this.takenOn,
    this.weightKg,
    this.note,
    this.createdAt,
    this.url,
  });

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String?;
    return ProgressPhoto(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      pose: ProgressPose.fromApi(json['pose']),
      takenOn: _localDay(json['taken_on']) ?? DateTime.now(),
      weightKg: _toDouble(json['weight_kg']),
      note: json['note'] as String?,
      createdAt: _toDate(json['created_at']),
      url: url == null || url.isEmpty ? null : AppConfig.resolveUrl(url),
    );
  }
}

/// Newest first: by date, then upload time.
int compareProgressPhotosNewestFirst(ProgressPhoto a, ProgressPhoto b) {
  final byDay = b.takenOn.compareTo(a.takenOn);
  if (byDay != 0) return byDay;
  return (b.createdAt ?? b.takenOn).compareTo(a.createdAt ?? a.takenOn);
}

/// The default before/after pair: the oldest and newest photo of the newest
/// photo's pose; when that pose has a single photo, the oldest and newest
/// overall. Null with fewer than two photos.
({ProgressPhoto before, ProgressPhoto after})? defaultComparePair(List<ProgressPhoto> photos) {
  if (photos.length < 2) return null;
  final sorted = [...photos]..sort(compareProgressPhotosNewestFirst);
  final newest = sorted.first;
  final samePose = sorted.where((p) => p.pose == newest.pose).toList();
  final pool = samePose.length >= 2 ? samePose : sorted;
  return (before: pool.last, after: pool.first);
}

/// 'YYYY-MM-DD' for a local date, as the API expects for DATE columns.
String trainingApiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Photos grouped by the month they were taken, newest month (and photo) first.
List<({DateTime month, List<ProgressPhoto> photos})> groupProgressPhotosByMonth(List<ProgressPhoto> photos) {
  final sorted = [...photos]..sort(compareProgressPhotosNewestFirst);
  final out = <({DateTime month, List<ProgressPhoto> photos})>[];
  for (final p in sorted) {
    final month = DateTime(p.takenOn.year, p.takenOn.month);
    if (out.isEmpty || out.last.month != month) out.add((month: month, photos: <ProgressPhoto>[]));
    out.last.photos.add(p);
  }
  return out;
}
