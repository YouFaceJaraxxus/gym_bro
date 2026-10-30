// Routine assignments and session comments.

DateTime? _parseLocalDate(dynamic v) {
  if (v == null) return null;
  final parts = v.toString().split('T').first.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// A routine assigned to a user (by themself or a coach).
class RoutineAssignment {
  final String id;
  final String routineId;
  final String userId;
  final String? assignedById;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? note;

  /// IANA zone planned workouts are placed in (null: the viewer's zone).
  final String? timezone;

  /// 'HH:MM' — when planned workouts start (fixed-weeks routines).
  final String? workoutTime;
  final DateTime createdAt;
  final String routineName;
  final bool? routineIsPublic;
  final String? routineScheduleLabel;
  final String? userName;
  final String? assignedByName;

  const RoutineAssignment({
    required this.id,
    required this.routineId,
    required this.userId,
    this.assignedById,
    this.startDate,
    this.endDate,
    this.note,
    this.timezone,
    this.workoutTime,
    required this.createdAt,
    required this.routineName,
    this.routineIsPublic,
    this.routineScheduleLabel,
    this.userName,
    this.assignedByName,
  });

  factory RoutineAssignment.fromJson(Map<String, dynamic> json) =>
      RoutineAssignment(
        id: json['id'] as String,
        routineId: json['routine_id'] as String,
        userId: json['user_id'] as String,
        assignedById: json['assigned_by_id'] as String?,
        startDate: _parseLocalDate(json['start_date']),
        endDate: _parseLocalDate(json['end_date']),
        note: json['note'] as String?,
        timezone: json['timezone'] as String?,
        workoutTime: json['workout_time'] as String?,
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        routineName: json['routine_name'] as String? ?? 'Routine',
        routineIsPublic: json['routine_is_public'] as bool?,
        routineScheduleLabel: json['routine_schedule_label'] as String?,
        userName: json['user_name'] as String?,
        assignedByName: json['assigned_by_name'] as String?,
      );

  bool get isSelfAssigned => assignedById != null && assignedById == userId;
}

/// A comment on a training session (owner ↔ coaches thread).
class SessionComment {
  final String id;
  final String sessionId;
  final String? authorId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SessionComment({
    required this.id,
    required this.sessionId,
    this.authorId,
    this.authorName,
    this.authorAvatarUrl,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SessionComment.fromJson(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now();
    return SessionComment(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      authorId: json['author_id'] as String?,
      authorName: json['author_name'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      body: json['body'] as String? ?? '',
      createdAt: created,
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? created,
    );
  }

  /// Edited more than a few seconds after posting.
  bool get isEdited => updatedAt.difference(createdAt).inSeconds > 5;
}
