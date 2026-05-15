enum MuscleGroup {
  // Chest
  chestAll,
  chestUpper,
  chestLower,
  // Back
  backAll,
  backUpper,
  backMid,
  backLower,
  backRhomboids,
  backTraps,
  backLats,
  // Deltoids
  deltsAll,
  deltsFront,
  deltsMedial,
  deltsRear,
  // Arms
  biceps,
  tricepsAll,
  tricepsLong,
  tricepsLateral,
  tricepsMedial,
  forearmsAll,
  forearmsTop,
  forearmsBottom,
  // Core
  absUpper,
  absLower,
  absObliques,
  // Lower body
  quadsAll,
  quadsMedial,
  quadsLateral,
  hamstrings,
  glutesAll,
  glutesMedius,
  glutesMinimus,
  glutesMaximus,
  calves,
  // Other
  neck;

  static const _apiValues = {
    MuscleGroup.chestAll: 'chest_all',
    MuscleGroup.chestUpper: 'chest_upper',
    MuscleGroup.chestLower: 'chest_lower',
    MuscleGroup.backAll: 'back_all',
    MuscleGroup.backUpper: 'back_upper',
    MuscleGroup.backMid: 'back_mid',
    MuscleGroup.backLower: 'back_lower',
    MuscleGroup.backRhomboids: 'back_rhomboids',
    MuscleGroup.backTraps: 'back_traps',
    MuscleGroup.backLats: 'back_lats',
    MuscleGroup.deltsAll: 'delts_all',
    MuscleGroup.deltsFront: 'delts_front',
    MuscleGroup.deltsMedial: 'delts_medial',
    MuscleGroup.deltsRear: 'delts_rear',
    MuscleGroup.biceps: 'biceps',
    MuscleGroup.tricepsAll: 'triceps_all',
    MuscleGroup.tricepsLong: 'triceps_long',
    MuscleGroup.tricepsLateral: 'triceps_lateral',
    MuscleGroup.tricepsMedial: 'triceps_medial',
    MuscleGroup.forearmsAll: 'forearms_all',
    MuscleGroup.forearmsTop: 'forearms_top',
    MuscleGroup.forearmsBottom: 'forearms_bottom',
    MuscleGroup.absUpper: 'abs_upper',
    MuscleGroup.absLower: 'abs_lower',
    MuscleGroup.absObliques: 'abs_obliques',
    MuscleGroup.quadsAll: 'quads_all',
    MuscleGroup.quadsMedial: 'quads_medial',
    MuscleGroup.quadsLateral: 'quads_lateral',
    MuscleGroup.hamstrings: 'hamstrings',
    MuscleGroup.glutesAll: 'glutes_all',
    MuscleGroup.glutesMedius: 'glutes_medius',
    MuscleGroup.glutesMinimus: 'glutes_minimus',
    MuscleGroup.glutesMaximus: 'glutes_maximus',
    MuscleGroup.calves: 'calves',
    MuscleGroup.neck: 'neck',
  };

  static const _displayNames = {
    MuscleGroup.chestAll: 'Chest',
    MuscleGroup.chestUpper: 'Upper Chest',
    MuscleGroup.chestLower: 'Lower Chest',
    MuscleGroup.backAll: 'Back',
    MuscleGroup.backUpper: 'Upper Back',
    MuscleGroup.backMid: 'Mid Back',
    MuscleGroup.backLower: 'Lower Back',
    MuscleGroup.backRhomboids: 'Rhomboids',
    MuscleGroup.backTraps: 'Traps',
    MuscleGroup.backLats: 'Lats',
    MuscleGroup.deltsAll: 'Deltoids',
    MuscleGroup.deltsFront: 'Front Delt',
    MuscleGroup.deltsMedial: 'Side Delt',
    MuscleGroup.deltsRear: 'Rear Delt',
    MuscleGroup.biceps: 'Biceps',
    MuscleGroup.tricepsAll: 'Triceps',
    MuscleGroup.tricepsLong: 'Triceps Long Head',
    MuscleGroup.tricepsLateral: 'Triceps Lateral',
    MuscleGroup.tricepsMedial: 'Triceps Medial',
    MuscleGroup.forearmsAll: 'Forearms',
    MuscleGroup.forearmsTop: 'Forearms (Top)',
    MuscleGroup.forearmsBottom: 'Forearms (Bottom)',
    MuscleGroup.absUpper: 'Upper Abs',
    MuscleGroup.absLower: 'Lower Abs',
    MuscleGroup.absObliques: 'Obliques',
    MuscleGroup.quadsAll: 'Quads',
    MuscleGroup.quadsMedial: 'Medial Quad',
    MuscleGroup.quadsLateral: 'Lateral Quad',
    MuscleGroup.hamstrings: 'Hamstrings',
    MuscleGroup.glutesAll: 'Glutes',
    MuscleGroup.glutesMedius: 'Glute Medius',
    MuscleGroup.glutesMinimus: 'Glute Minimus',
    MuscleGroup.glutesMaximus: 'Glute Maximus',
    MuscleGroup.calves: 'Calves',
    MuscleGroup.neck: 'Neck',
  };

  String get apiValue => _apiValues[this]!;
  String get displayName => _displayNames[this]!;

  static MuscleGroup? fromApiValue(String value) {
    return _apiValues.entries
        .where((e) => e.value == value)
        .map((e) => e.key)
        .firstOrNull;
  }

  // Coarse body-region grouping used by the muscle diagram
  BodyRegion get region {
    switch (this) {
      case MuscleGroup.chestAll:
      case MuscleGroup.chestUpper:
      case MuscleGroup.chestLower:
        return BodyRegion.chest;
      case MuscleGroup.backAll:
      case MuscleGroup.backUpper:
      case MuscleGroup.backMid:
      case MuscleGroup.backLower:
      case MuscleGroup.backRhomboids:
        return BodyRegion.midBack;
      case MuscleGroup.backTraps:
        return BodyRegion.traps;
      case MuscleGroup.backLats:
        return BodyRegion.lats;
      case MuscleGroup.deltsAll:
      case MuscleGroup.deltsFront:
      case MuscleGroup.deltsMedial:
        return BodyRegion.shoulderFront;
      case MuscleGroup.deltsRear:
        return BodyRegion.shoulderRear;
      case MuscleGroup.biceps:
        return BodyRegion.biceps;
      case MuscleGroup.tricepsAll:
      case MuscleGroup.tricepsLong:
      case MuscleGroup.tricepsLateral:
      case MuscleGroup.tricepsMedial:
        return BodyRegion.triceps;
      case MuscleGroup.forearmsAll:
      case MuscleGroup.forearmsTop:
      case MuscleGroup.forearmsBottom:
        return BodyRegion.forearms;
      case MuscleGroup.absUpper:
      case MuscleGroup.absLower:
        return BodyRegion.abs;
      case MuscleGroup.absObliques:
        return BodyRegion.obliques;
      case MuscleGroup.quadsAll:
      case MuscleGroup.quadsMedial:
      case MuscleGroup.quadsLateral:
        return BodyRegion.quads;
      case MuscleGroup.hamstrings:
        return BodyRegion.hamstrings;
      case MuscleGroup.glutesAll:
      case MuscleGroup.glutesMedius:
      case MuscleGroup.glutesMinimus:
      case MuscleGroup.glutesMaximus:
        return BodyRegion.glutes;
      case MuscleGroup.calves:
        return BodyRegion.calves;
      case MuscleGroup.neck:
        return BodyRegion.neck;
    }
  }
}

// Coarse anatomical regions that map to visual areas in the muscle diagram.
enum BodyRegion {
  chest,
  lats,
  midBack,
  traps,
  shoulderFront,
  shoulderRear,
  biceps,
  triceps,
  forearms,
  abs,
  obliques,
  quads,
  hamstrings,
  glutes,
  calves,
  neck,
}

class Exercise {
  final String id;
  final String name;
  final String? description;
  final String? note;
  final String? imageUrl;
  final String? videoUrl;
  final String? authorId;
  final List<MuscleGroup> primaryMuscles;
  final List<MuscleGroup> secondaryMuscles;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Exercise({
    required this.id,
    required this.name,
    this.description,
    this.note,
    this.imageUrl,
    this.videoUrl,
    this.authorId,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    List<MuscleGroup> parseMuscles(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .map((v) => MuscleGroup.fromApiValue(v.toString()))
          .whereType<MuscleGroup>()
          .toList();
    }

    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      note: json['note'] as String?,
      imageUrl: json['image_url'] as String?,
      videoUrl: json['video_url'] as String?,
      authorId: json['author_id'] as String?,
      primaryMuscles: parseMuscles(json['primary_muscles']),
      secondaryMuscles: parseMuscles(json['secondary_muscles']),
      isPublic: json['is_public'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'note': note,
        'image_url': imageUrl,
        'video_url': videoUrl,
        'author_id': authorId,
        'primary_muscles': primaryMuscles.map((m) => m.apiValue).toList(),
        'secondary_muscles': secondaryMuscles.map((m) => m.apiValue).toList(),
        'is_public': isPublic,
      };
}
