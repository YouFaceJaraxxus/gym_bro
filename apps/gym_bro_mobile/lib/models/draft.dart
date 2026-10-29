import '../config.dart';

/// What a draft is a draft of; each create screen has its own kind.
enum DraftKind {
  post('post'),
  businessPost('business_post'),
  exercise('exercise'),
  training('training'),
  routine('routine'),
  recipe('recipe'),
  foodItem('food_item'),
  dailyMealPlan('daily_meal_plan'),
  mealPlan('meal_plan');

  const DraftKind(this.apiValue);
  final String apiValue;

  static DraftKind fromApi(String v) => values.firstWhere((k) => k.apiValue == v, orElse: () => post);
}

/// GET /drafts row: enough to list a draft.
class DraftSummary {
  final String id;
  final DraftKind kind;
  final String? scopeId;
  final String? title;

  /// Absolute URL (a signed one for the first photo of a media draft).
  final String? thumbnailUrl;
  final int mediaCount;
  final bool hasVideo;
  final DateTime updatedAt;

  const DraftSummary({
    required this.id,
    required this.kind,
    this.scopeId,
    this.title,
    this.thumbnailUrl,
    this.mediaCount = 0,
    this.hasVideo = false,
    required this.updatedAt,
  });

  factory DraftSummary.fromJson(Map<String, dynamic> json) => DraftSummary(
    id: json['id'] as String,
    kind: DraftKind.fromApi(json['kind'] as String),
    scopeId: json['scope_id'] as String?,
    title: json['title'] as String?,
    thumbnailUrl: json['thumbnail_url'] == null ? null : AppConfig.resolveUrl(json['thumbnail_url'] as String),
    mediaCount: (json['media_count'] as num?)?.toInt() ?? 0,
    hasVideo: json['has_video'] == true,
    updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
  );
}

/// A photo/video saved on a draft: already uploaded, plus its edit state.
class DraftMedia {
  final String path;
  final String mimeType;
  final String? fileName;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final int? durationMs;
  final Map<String, dynamic>? edit;

  /// Signed download URL (absolute).
  final String? url;

  const DraftMedia({
    required this.path,
    required this.mimeType,
    this.fileName,
    this.sizeBytes,
    this.width,
    this.height,
    this.durationMs,
    this.edit,
    this.url,
  });

  factory DraftMedia.fromJson(Map<String, dynamic> json) {
    int? i(Object? v) => v == null ? null : int.tryParse(v.toString());
    return DraftMedia(
      path: json['path'] as String,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      fileName: json['file_name'] as String?,
      sizeBytes: i(json['size_bytes']),
      width: i(json['width']),
      height: i(json['height']),
      durationMs: i(json['duration_ms']),
      edit: json['edit'] is Map ? Map<String, dynamic>.from(json['edit'] as Map) : null,
      url: json['url'] == null ? null : AppConfig.resolveUrl(json['url'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'file_name': ?fileName,
    'size_bytes': ?sizeBytes,
    'width': ?width,
    'height': ?height,
    'duration_ms': ?durationMs,
    'edit': ?edit,
  };
}

/// GET /drafts/:id — a draft with the form state it was saved with.
class Draft extends DraftSummary {
  final Map<String, dynamic> data;
  final List<DraftMedia> media;

  const Draft({
    required super.id,
    required super.kind,
    super.scopeId,
    super.title,
    super.thumbnailUrl,
    super.mediaCount,
    super.hasVideo,
    required super.updatedAt,
    this.data = const {},
    this.media = const [],
  });

  factory Draft.fromJson(Map<String, dynamic> json) {
    final s = DraftSummary.fromJson(json);
    return Draft(
      id: s.id,
      kind: s.kind,
      scopeId: s.scopeId,
      title: s.title,
      thumbnailUrl: s.thumbnailUrl,
      mediaCount: s.mediaCount,
      hasVideo: s.hasVideo,
      updatedAt: s.updatedAt,
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : const {},
      media: [for (final m in (json['media'] as List? ?? const [])) DraftMedia.fromJson(Map<String, dynamic>.from(m as Map))],
    );
  }
}
