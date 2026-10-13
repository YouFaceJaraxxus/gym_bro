// Exercise progress, personal records, body measurements.
//
// All weights are kilograms (convert with SettingsService at the UI edge).
// Postgres numerics may arrive as strings, so every number goes through
// [_toDouble] / [_toInt].

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
        primaryMuscles: (json['primary_muscles'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
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
      primaryMuscles: (ex['primary_muscles'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      series: (json['series'] as List<dynamic>? ?? [])
          .map((e) => ExerciseSeriesPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      bestWeight: ExerciseRecord.fromJson(prs['best_weight_kg']),
      bestE1rm: ExerciseRecord.fromJson(prs['best_e1rm']),
      bestVolume: ExerciseRecord.fromJson(prs['best_volume_kg']),
    );
  }
}

/// A body_measurement row. [measuredOn] is a local calendar date.
class BodyMeasurement {
  final String id;
  final String userId;
  final DateTime measuredOn;
  final double? weightKg;
  final double? bodyFatPct;
  final String? note;
  final DateTime? createdAt;

  const BodyMeasurement({
    required this.id,
    required this.userId,
    required this.measuredOn,
    this.weightKg,
    this.bodyFatPct,
    this.note,
    this.createdAt,
  });

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    final raw = json['measured_on']?.toString() ?? '';
    // 'YYYY-MM-DD' → a local date (no UTC shift).
    final parts = raw.split('T').first.split('-');
    final measuredOn = parts.length == 3
        ? DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          )
        : DateTime.now();
    return BodyMeasurement(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      measuredOn: measuredOn,
      weightKg: _toDouble(json['weight_kg']),
      bodyFatPct: _toDouble(json['body_fat_pct']),
      note: json['note'] as String?,
      createdAt: _toDate(json['created_at']),
    );
  }
}

/// 'YYYY-MM-DD' for a local date, as the API expects for DATE columns.
String trainingApiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
