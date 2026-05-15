import 'exercise.dart';

enum WorkoutSetType {
  standard,
  superset,
  dropset,
  circuit;

  String get apiValue => name;
  String get displayName {
    switch (this) {
      case WorkoutSetType.standard:
        return 'Straight Set';
      case WorkoutSetType.superset:
        return 'Superset';
      case WorkoutSetType.dropset:
        return 'Drop Set';
      case WorkoutSetType.circuit:
        return 'Circuit';
    }
  }

  static WorkoutSetType fromApiValue(String v) =>
      WorkoutSetType.values.firstWhere((e) => e.name == v, orElse: () => WorkoutSetType.standard);
}

enum RepType {
  count,
  failure,
  unspecified;

  String get apiValue => name;
  String get displayName {
    switch (this) {
      case RepType.count:
        return 'Reps';
      case RepType.failure:
        return 'To Failure';
      case RepType.unspecified:
        return '—';
    }
  }

  static RepType fromApiValue(String v) =>
      RepType.values.firstWhere((e) => e.name == v, orElse: () => RepType.count);
}

enum BodySide {
  both,
  left,
  right;

  String get apiValue => name;
  String get displayName {
    switch (this) {
      case BodySide.both:
        return 'Both';
      case BodySide.left:
        return 'Left';
      case BodySide.right:
        return 'Right';
    }
  }

  static BodySide fromApiValue(String v) =>
      BodySide.values.firstWhere((e) => e.name == v, orElse: () => BodySide.both);
}

// ── Training set drop ─────────────────────────────────────────────────────────

class TrainingSetDrop {
  final String id;
  final String trainingSetExerciseId;
  final int dropNumber;
  final RepType repType;
  final int? repCount;
  final double? weightKg;
  final BodySide side;
  final String? note;

  const TrainingSetDrop({
    required this.id,
    required this.trainingSetExerciseId,
    required this.dropNumber,
    required this.repType,
    this.repCount,
    this.weightKg,
    required this.side,
    this.note,
  });

  factory TrainingSetDrop.fromJson(Map<String, dynamic> json) {
    final rawWeight = json['weight_kg'];
    return TrainingSetDrop(
      id: json['id'] as String,
      trainingSetExerciseId: json['training_set_exercise_id'] as String,
      dropNumber: json['drop_number'] as int? ?? 0,
      repType: RepType.fromApiValue(json['rep_type'] as String? ?? 'count'),
      repCount: json['rep_count'] as int?,
      weightKg: rawWeight == null ? null : double.tryParse(rawWeight.toString()),
      side: BodySide.fromApiValue(json['side'] as String? ?? 'both'),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'drop_number': dropNumber,
        'rep_type': repType.apiValue,
        'rep_count': repCount,
        'weight_kg': weightKg,
        'side': side.apiValue,
        'note': note,
      };

  String get label {
    final reps = switch (repType) {
      RepType.count => repCount != null ? '${repCount}x' : '',
      RepType.failure => 'Failure',
      RepType.unspecified => '—',
    };
    final weight = weightKg != null ? ' @ ${weightKg!.toStringAsFixed(1)} kg' : '';
    final sideLabel = side != BodySide.both ? ' (${side.displayName})' : '';
    return '$reps$weight$sideLabel'.trim();
  }
}

// ── Training set exercise ─────────────────────────────────────────────────────

class TrainingSetExercise {
  final String id;
  final String trainingSetId;
  final String exerciseId;
  final Exercise? exercise;
  final int position;
  final bool isAlternating;
  final int? restBetweenDropsSeconds;
  final String? note;
  final List<TrainingSetDrop> drops;

  const TrainingSetExercise({
    required this.id,
    required this.trainingSetId,
    required this.exerciseId,
    this.exercise,
    required this.position,
    required this.isAlternating,
    this.restBetweenDropsSeconds,
    this.note,
    required this.drops,
  });

  factory TrainingSetExercise.fromJson(Map<String, dynamic> json) {
    final rawDrops = json['drops'] as List<dynamic>? ?? [];
    return TrainingSetExercise(
      id: json['id'] as String,
      trainingSetId: json['training_set_id'] as String,
      exerciseId: json['exercise_id'] as String,
      exercise: json['exercise'] != null
          ? Exercise.fromJson(json['exercise'] as Map<String, dynamic>)
          : null,
      position: json['position'] as int? ?? 0,
      isAlternating: json['is_alternating'] as bool? ?? false,
      restBetweenDropsSeconds: json['rest_between_drops_seconds'] as int?,
      note: json['note'] as String?,
      drops: rawDrops.map((d) => TrainingSetDrop.fromJson(d as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'position': position,
        'is_alternating': isAlternating,
        'rest_between_drops_seconds': restBetweenDropsSeconds,
        'note': note,
        'drops': drops.map((d) => d.toJson()).toList(),
      };
}

// ── Training set ──────────────────────────────────────────────────────────────

class TrainingSet {
  final String id;
  final String trainingId;
  final WorkoutSetType type;
  final int position;
  final int? restSeconds;
  final String? note;
  final List<TrainingSetExercise> exercises;

  const TrainingSet({
    required this.id,
    required this.trainingId,
    required this.type,
    required this.position,
    this.restSeconds,
    this.note,
    required this.exercises,
  });

  factory TrainingSet.fromJson(Map<String, dynamic> json) {
    final rawExercises = json['exercises'] as List<dynamic>? ?? [];
    return TrainingSet(
      id: json['id'] as String,
      trainingId: json['training_id'] as String,
      type: WorkoutSetType.fromApiValue(json['type'] as String? ?? 'standard'),
      position: json['position'] as int? ?? 0,
      restSeconds: json['rest_seconds'] as int?,
      note: json['note'] as String?,
      exercises: rawExercises
          .map((e) => TrainingSetExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.apiValue,
        'position': position,
        'rest_seconds': restSeconds,
        'note': note,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  String get setsLabel {
    if (exercises.isEmpty) return '';
    final first = exercises.first;
    if (first.drops.isEmpty) return '';
    if (first.drops.length == 1) {
      return first.drops.first.label;
    }
    return '${first.drops.length} drops';
  }
}

// ── Training image ────────────────────────────────────────────────────────────

class TrainingImage {
  final String id;
  final String trainingId;
  final String url;
  final bool isThumbnail;
  final int position;

  const TrainingImage({
    required this.id,
    required this.trainingId,
    required this.url,
    required this.isThumbnail,
    required this.position,
  });

  factory TrainingImage.fromJson(Map<String, dynamic> json) => TrainingImage(
        id: json['id'] as String,
        trainingId: json['training_id'] as String,
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

// ── Training ──────────────────────────────────────────────────────────────────

class Training {
  final String id;
  final String name;
  final String? description;
  final String? notes;
  final String? authorId;
  final bool isPublic;
  final List<TrainingImage> images;
  final List<TrainingSet> sets;
  final TrainingImage? thumbnail;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Training({
    required this.id,
    required this.name,
    this.description,
    this.notes,
    this.authorId,
    required this.isPublic,
    required this.images,
    required this.sets,
    this.thumbnail,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Training.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'] as List<dynamic>? ?? [];
    final rawSets = json['sets'] as List<dynamic>? ?? [];
    final rawThumb = json['thumbnail'] as Map<String, dynamic>?;

    return Training(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      notes: json['notes'] as String?,
      authorId: json['author_id'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      images: rawImages.map((i) => TrainingImage.fromJson(i as Map<String, dynamic>)).toList(),
      sets: rawSets.map((s) => TrainingSet.fromJson(s as Map<String, dynamic>)).toList(),
      thumbnail: rawThumb != null ? TrainingImage.fromJson(rawThumb) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'notes': notes,
        'is_public': isPublic,
        'images': images.map((i) => i.toJson()).toList(),
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  String get thumbnailUrl => thumbnail?.url ?? images.firstOrNull?.url ?? '';

  // All unique primary muscle groups across all exercises in this training
  Set<MuscleGroup> get primaryMuscles {
    return sets
        .expand((s) => s.exercises)
        .expand((e) => e.exercise?.primaryMuscles ?? <MuscleGroup>[])
        .toSet();
  }
}
