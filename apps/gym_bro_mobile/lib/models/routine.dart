import 'training.dart';

enum RoutineScheduleType {
  fixedWeeks,
  wildcard;

  String get apiValue => this == RoutineScheduleType.fixedWeeks ? 'fixed_weeks' : 'wildcard';
  String get displayName =>
      this == RoutineScheduleType.fixedWeeks ? 'Fixed Weeks' : 'Wildcard';

  static RoutineScheduleType fromApiValue(String v) =>
      v == 'fixed_weeks' ? RoutineScheduleType.fixedWeeks : RoutineScheduleType.wildcard;
}

class RoutineImage {
  final String id;
  final String routineId;
  final String url;
  final bool isThumbnail;
  final int position;

  const RoutineImage({
    required this.id,
    required this.routineId,
    required this.url,
    required this.isThumbnail,
    required this.position,
  });

  factory RoutineImage.fromJson(Map<String, dynamic> json) => RoutineImage(
        id: json['id'] as String,
        routineId: json['routine_id'] as String,
        url: json['url'] as String,
        isThumbnail: json['is_thumbnail'] as bool? ?? false,
        position: json['position'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'is_thumbnail': isThumbnail,
        'position': position,
      };
}

class RoutineTrainingEntry {
  final String id;
  final String routineId;
  final String trainingId;
  final Training? training;
  final int? weekNumber;
  final int? dayOfWeek;
  final int position;
  final String? note;

  const RoutineTrainingEntry({
    required this.id,
    required this.routineId,
    required this.trainingId,
    this.training,
    this.weekNumber,
    this.dayOfWeek,
    required this.position,
    this.note,
  });

  factory RoutineTrainingEntry.fromJson(Map<String, dynamic> json) => RoutineTrainingEntry(
        id: json['id'] as String,
        routineId: json['routine_id'] as String,
        trainingId: json['training_id'] as String,
        training: json['training'] != null
            ? Training.fromJson(json['training'] as Map<String, dynamic>)
            : null,
        weekNumber: json['week_number'] as int?,
        dayOfWeek: json['day_of_week'] as int?,
        position: json['position'] as int? ?? 0,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'training_id': trainingId,
        'week_number': weekNumber,
        'day_of_week': dayOfWeek,
        'position': position,
        'note': note,
      };

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String get dayLabel => dayOfWeek != null ? _dayNames[dayOfWeek! - 1] : '';
}

class Routine {
  final String id;
  final String name;
  final String? description;
  final String? notes;
  final String? authorId;
  final bool isPublic;
  final RoutineScheduleType scheduleType;
  final int? numWeeks;
  final List<RoutineImage> images;
  final List<RoutineTrainingEntry> trainings;
  final RoutineImage? thumbnail;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Routine({
    required this.id,
    required this.name,
    this.description,
    this.notes,
    this.authorId,
    required this.isPublic,
    required this.scheduleType,
    this.numWeeks,
    required this.images,
    required this.trainings,
    this.thumbnail,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'] as List<dynamic>? ?? [];
    final rawTrainings = json['trainings'] as List<dynamic>? ?? [];
    final rawThumb = json['thumbnail'] as Map<String, dynamic>?;

    return Routine(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      notes: json['notes'] as String?,
      authorId: json['author_id'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      scheduleType:
          RoutineScheduleType.fromApiValue(json['schedule_type'] as String? ?? 'wildcard'),
      numWeeks: json['num_weeks'] as int?,
      images: rawImages.map((i) => RoutineImage.fromJson(i as Map<String, dynamic>)).toList(),
      trainings: rawTrainings
          .map((t) => RoutineTrainingEntry.fromJson(t as Map<String, dynamic>))
          .toList(),
      thumbnail: rawThumb != null ? RoutineImage.fromJson(rawThumb) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'notes': notes,
        'is_public': isPublic,
        'schedule_type': scheduleType.apiValue,
        'num_weeks': numWeeks,
        'images': images.map((i) => i.toJson()).toList(),
        'trainings': trainings.map((t) => t.toJson()).toList(),
      };

  String get thumbnailUrl =>
      thumbnail?.url ?? images.firstOrNull?.url ?? '';

  String get scheduleLabel {
    if (scheduleType == RoutineScheduleType.fixedWeeks && numWeeks != null) {
      return '$numWeeks-Week Program';
    }
    return 'Wildcard';
  }
}
