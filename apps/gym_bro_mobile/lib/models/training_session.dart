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
      repTypeActual: RepType.fromApiValue(json['rep_type_actual'] as String? ?? 'count'),
      repCountActual: json['rep_count_actual'] as int?,
      weightKgActual: rawWeight == null ? null : double.tryParse(rawWeight.toString()),
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

  String get label {
    final reps = switch (repTypeActual) {
      RepType.count => repCountActual != null ? '${repCountActual}x' : '',
      RepType.failure => 'Failure',
      RepType.unspecified => '—',
    };
    final weight =
        weightKgActual != null ? ' @ ${weightKgActual!.toStringAsFixed(1)} kg' : '';
    final sideLabel = side != BodySide.both ? ' (${side.displayName})' : '';
    return '$reps$weight$sideLabel'.trim();
  }
}

class SessionSetLog {
  final String id;
  final String sessionId;
  final String? trainingSetId;
  final String? exerciseId;
  final int position;
  final String? note;
  final List<SessionDropLog> dropLogs;

  const SessionSetLog({
    required this.id,
    required this.sessionId,
    this.trainingSetId,
    this.exerciseId,
    required this.position,
    this.note,
    required this.dropLogs,
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
      dropLogs:
          rawDrops.map((d) => SessionDropLog.fromJson(d as Map<String, dynamic>)).toList(),
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
  final String? trainingId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? notes;
  final List<SessionSetLog> setLogs;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrainingSession({
    required this.id,
    required this.userId,
    this.trainerId,
    this.trainingId,
    required this.startedAt,
    this.endedAt,
    this.notes,
    required this.setLogs,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    final rawLogs = json['set_logs'] as List<dynamic>? ?? [];
    return TrainingSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      trainerId: json['trainer_id'] as String?,
      trainingId: json['training_id'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] == null ? null : DateTime.parse(json['ended_at'] as String),
      notes: json['notes'] as String?,
      setLogs: rawLogs.map((l) => SessionSetLog.fromJson(l as Map<String, dynamic>)).toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
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
