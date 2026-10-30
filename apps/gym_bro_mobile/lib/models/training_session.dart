import '../l10n/app_localizations.dart';
import 'training.dart';

class SessionDropLog {
  final String id;
  final String sessionSetLogId;
  final String? trainingSetDropId;
  final int dropNumber;
  final RepType repTypeActual;
  final int? repCountActual;
  final double? weightKgActual;
  final BodySide side;
  final String? note;

  const SessionDropLog({
    required this.id,
    required this.sessionSetLogId,
    this.trainingSetDropId,
    required this.dropNumber,
    required this.repTypeActual,
    this.repCountActual,
    this.weightKgActual,
    required this.side,
    this.note,
  });

  factory SessionDropLog.fromJson(Map<String, dynamic> json) {
    final rawWeight = json['weight_kg_actual'];
    return SessionDropLog(
      id: json['id'] as String,
      sessionSetLogId: json['session_set_log_id'] as String,
      trainingSetDropId: json['training_set_drop_id'] as String?,
      dropNumber: json['drop_number'] as int? ?? 0,
      repTypeActual: RepType.fromApiValue(
        json['rep_type_actual'] as String? ?? 'count',
      ),
      repCountActual: json['rep_count_actual'] as int?,
      weightKgActual: rawWeight == null
          ? null
          : double.tryParse(rawWeight.toString()),
      side: BodySide.fromApiValue(json['side'] as String? ?? 'both'),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'training_set_drop_id': trainingSetDropId,
    'drop_number': dropNumber,
    'rep_type_actual': repTypeActual.apiValue,
    'rep_count_actual': repCountActual,
    'weight_kg_actual': weightKgActual,
    'side': side.apiValue,
    'note': note,
  };

  String label(AppLocalizations l10n) => trainingDropLabel(
    l10n,
    repType: repTypeActual,
    repCount: repCountActual,
    weightKg: weightKgActual,
    side: side,
  );
}

class SessionSetLog {
  final String id;
  final String sessionId;
  final String? trainingSetId;
  final String? exerciseId;
  final int position;
  final String? note;
  final List<SessionDropLog> dropLogs;

  /// Only on POST /training-sessions/:id/sets responses: true when this set
  /// beat the user's previous best e1RM ([prE1rm], kg) for [prExerciseId].
  final bool isPr;
  final double? prE1rm;
  final double? previousE1rm;
  final String? prExerciseId;

  const SessionSetLog({
    required this.id,
    required this.sessionId,
    this.trainingSetId,
    this.exerciseId,
    required this.position,
    this.note,
    required this.dropLogs,
    this.isPr = false,
    this.prE1rm,
    this.previousE1rm,
    this.prExerciseId,
  });

  factory SessionSetLog.fromJson(Map<String, dynamic> json) {
    final rawDrops = json['drop_logs'] as List<dynamic>? ?? [];
    return SessionSetLog(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      trainingSetId: json['training_set_id'] as String?,
      exerciseId: json['exercise_id'] as String?,
      position: json['position'] as int? ?? 0,
      note: json['note'] as String?,
      dropLogs: rawDrops
          .map((d) => SessionDropLog.fromJson(d as Map<String, dynamic>))
          .toList(),
      isPr: json['is_pr'] as bool? ?? false,
      prE1rm: json['pr_e1rm'] == null
          ? null
          : double.tryParse(json['pr_e1rm'].toString()),
      previousE1rm: json['previous_e1rm'] == null
          ? null
          : double.tryParse(json['previous_e1rm'].toString()),
      prExerciseId: json['pr_exercise_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'training_set_id': trainingSetId,
    'exercise_id': exerciseId,
    'position': position,
    'note': note,
    'drops': dropLogs.map((d) => d.toJson()).toList(),
  };
}

class TrainingSession {
  final String id;
  final String userId;
  final String? trainerId;
  final String? trainerName;
  final String? trainingId;

  /// The followed training's name (lists and detail); null for free sessions.
  final String? trainingName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? notes;

  /// The planned workout (plan entry) this session logs, if any.
  final String? planEntryId;
  final List<SessionSetLog> setLogs;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int commentCount;

  const TrainingSession({
    required this.id,
    required this.userId,
    this.trainerId,
    this.trainerName,
    this.trainingId,
    this.trainingName,
    required this.startedAt,
    this.endedAt,
    this.notes,
    this.planEntryId,
    required this.setLogs,
    required this.createdAt,
    required this.updatedAt,
    this.commentCount = 0,
  });

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    final rawLogs = json['set_logs'] as List<dynamic>? ?? [];
    return TrainingSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      trainerId: json['trainer_id'] as String?,
      trainerName: json['trainer_name'] as String?,
      trainingId: json['training_id'] as String?,
      trainingName: json['training_name'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at'] as String),
      notes: json['notes'] as String?,
      planEntryId: json['plan_entry_id'] as String?,
      setLogs: rawLogs
          .map((l) => SessionSetLog.fromJson(l as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      commentCount: int.tryParse(json['comment_count']?.toString() ?? '') ?? 0,
    );
  }

  bool get isActive => endedAt == null;

  Duration? get duration => endedAt?.difference(startedAt);

  String get durationLabel {
    final d = duration ?? DateTime.now().difference(startedAt);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
