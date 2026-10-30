import 'dart:convert';

import '../config.dart';
import 'link_access.dart';
import 'reaction.dart';
import 'social.dart';

/// A photo or video on a post. Business posts carry public URLs; personal
/// posts carry short-lived signed URLs (already made absolute here).
class PostImage {
  final String id;
  final String postId;
  final String url;
  final int position;

  /// 'image' or 'video'.
  final String mediaType;
  final int? width;
  final int? height;
  final int? durationMs;

  /// People pinned on it.
  final List<PhotoTag> tags;

  const PostImage({
    required this.id,
    required this.postId,
    required this.url,
    required this.position,
    this.mediaType = 'image',
    this.width,
    this.height,
    this.durationMs,
    this.tags = const [],
  });

  PostImage withTags(List<PhotoTag> tags) => PostImage(
    id: id,
    postId: postId,
    url: url,
    position: position,
    mediaType: mediaType,
    width: width,
    height: height,
    durationMs: durationMs,
    tags: tags,
  );

  bool get isVideo => mediaType == 'video';

  double? get aspectRatio => (width != null && height != null && width! > 0 && height! > 0) ? width! / height! : null;

  factory PostImage.fromJson(Map<String, dynamic> json) => PostImage(
    id: json['id'] as String,
    postId: json['post_id'] as String,
    url: AppConfig.resolveUrl(json['url'] as String? ?? ''),
    position: json['position'] as int? ?? 0,
    mediaType: json['media_type'] as String? ?? 'image',
    width: json['width'] as int?,
    height: json['height'] as int?,
    durationMs: json['duration_ms'] as int?,
    tags: [
      for (final t in json['tags'] as List<dynamic>? ?? const [])
        if (t is Map<String, dynamic> && t['user_id'] != null) PhotoTag.fromJson(t),
    ],
  );

  Map<String, dynamic> toJson() => {'url': url, 'position': position};
}

/// Who can see a personal post. On a private account non-followers never
/// see posts, whatever this says.
enum PostVisibility {
  public('public'),
  followers('followers');

  const PostVisibility(this.apiValue);
  final String apiValue;

  static PostVisibility parse(Object? v) => v == 'followers' ? PostVisibility.followers : PostVisibility.public;
}

/// What a personal post shares. Typed posts carry a snapshot of the source
/// ([Post.attachment]) taken when posting.
enum PostType {
  generic('generic'),

  /// A logged training session (ref_id = session id).
  workout('workout'),

  /// The food logs of one day + meal slot (no ref_id).
  meal('meal'),
  exercise('exercise'),

  /// A workout template; "workout" in the UI.
  training('training'),

  /// A workout program.
  routine('routine'),
  recipe('recipe'),
  foodItem('food_item'),
  dailyMealPlan('daily_meal_plan'),

  /// A meal program.
  mealPlan('meal_plan');

  const PostType(this.apiValue);
  final String apiValue;

  static PostType parse(Object? v) => values.firstWhere((t) => t.apiValue == v, orElse: () => generic);

  /// Something that already happened (it can't be shared before it did).
  bool get isActivity => this == workout || this == meal;
}

double? _toDouble(Object? v) => v == null ? null : double.tryParse(v.toString());
int? _toInt(Object? v) => v == null ? null : _toDouble(v)?.round();

/// A person pinned on a photo at ([x], [y]), each 0–1 from the top left of
/// the whole photo.
class PhotoTag {
  final String userId;
  final String username;
  final String name;
  final String lastName;
  final String? avatarUrl;
  final double x;
  final double y;

  const PhotoTag({
    required this.userId,
    this.username = '',
    this.name = '',
    this.lastName = '',
    this.avatarUrl,
    required this.x,
    required this.y,
  });

  String get displayName {
    final full = '$name $lastName'.trim();
    return full.isNotEmpty ? full : username;
  }

  /// What the pin's label shows (Instagram shows the username).
  String get handle => username.isNotEmpty ? username : displayName;

  String get initials {
    final parts = [name, lastName].where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return username.isEmpty ? '?' : username[0].toUpperCase();
    return parts.map((s) => s[0].toUpperCase()).join();
  }

  PhotoTag moved(double x, double y) => PhotoTag(
    userId: userId,
    username: username,
    name: name,
    lastName: lastName,
    avatarUrl: avatarUrl,
    x: x.clamp(0.0, 1.0),
    y: y.clamp(0.0, 1.0),
  );

  factory PhotoTag.fromJson(Map<String, dynamic> json) => PhotoTag(
    userId: json['user_id'].toString(),
    username: json['username'] as String? ?? '',
    name: json['name'] as String? ?? '',
    lastName: json['last_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    x: (_toDouble(json['x']) ?? 0.5).clamp(0.0, 1.0),
    y: (_toDouble(json['y']) ?? 0.5).clamp(0.0, 1.0),
  );

  /// Everything, for drafts.
  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'username': username,
    'name': name,
    'last_name': lastName,
    'avatar_url': avatarUrl,
    'x': x,
    'y': y,
  };

  /// What POST /posts (media[i].tags) and PUT photo_tags take.
  Map<String, dynamic> toRequestJson() => {'user_id': userId, 'x': x, 'y': y};
}

/// One exercise of a shared workout.
class AttachmentExercise {
  final String? id;
  final String name;
  final int sets;
  final double? bestWeightKg;
  final int? bestReps;

  const AttachmentExercise({this.id, required this.name, this.sets = 0, this.bestWeightKg, this.bestReps});
}

/// One food of a shared meal.
class AttachmentMealItem {
  final String name;
  final double? amount;

  /// 'g', 'ml' or 'serving'.
  final String unit;
  final double? kcal;

  const AttachmentMealItem({required this.name, this.amount, this.unit = 'g', this.kcal});
}

/// The snapshot a typed post shares (see the API's _shared/post_attachments.ts).
/// Kept as the raw JSON — every field may be missing — with typed getters;
/// numbers may arrive as strings.
class PostAttachment {
  const PostAttachment(this.json);

  final Map<String, dynamic> json;

  static PostAttachment? maybeFromJson(Object? v) {
    if (v is String && v.startsWith('{')) {
      try {
        v = jsonDecode(v);
      } on FormatException {
        return null;
      }
    }
    return v is Map<String, dynamic> ? PostAttachment(v) : null;
  }

  String? _str(String key) {
    final v = json[key];
    return v == null || v.toString().trim().isEmpty ? null : v.toString();
  }

  String? get title => _str('title');
  String? get description => _str('description');
  String? get imageUrl => _str('image_url');

  // Workout
  String? get trainingId => _str('training_id');
  DateTime? get startedAt => DateTime.tryParse(json['started_at']?.toString() ?? '')?.toLocal();
  DateTime? get endedAt => DateTime.tryParse(json['ended_at']?.toString() ?? '')?.toLocal();
  int? get durationMinutes => _toInt(json['duration_minutes']);
  int? get exerciseCount => _toInt(json['exercise_count']);
  int? get setCount => _toInt(json['set_count']);
  double? get volumeKg => _toDouble(json['volume_kg']);
  List<AttachmentExercise> get exercises => [
    for (final e in json['exercises'] as List<dynamic>? ?? const [])
      if (e is Map<String, dynamic>)
        AttachmentExercise(
          id: e['id']?.toString(),
          name: e['name'] as String? ?? '',
          sets: _toInt(e['sets']) ?? 0,
          bestWeightKg: _toDouble(e['best_weight_kg']),
          bestReps: _toInt(e['best_reps']),
        ),
  ];

  // Meal
  /// The day it was logged for (local midnight).
  DateTime? get logDate {
    final s = _str('log_date');
    if (s == null || s.length < 10) return null;
    final p = s.substring(0, 10).split('-').map(int.tryParse).toList();
    if (p.any((n) => n == null)) return null;
    return DateTime(p[0]!, p[1]!, p[2]!);
  }

  /// The API's meal_slot_type value.
  String? get slotType => _str('slot_type');
  DateTime? get eatenAt => DateTime.tryParse(json['eaten_at']?.toString() ?? '')?.toLocal();
  List<AttachmentMealItem> get items => [
    for (final e in json['items'] as List<dynamic>? ?? const [])
      if (e is Map<String, dynamic>)
        AttachmentMealItem(
          name: e['name'] as String? ?? '',
          amount: _toDouble(e['amount']),
          unit: e['unit'] as String? ?? 'g',
          kcal: _toDouble(e['kcal']),
        ),
  ];
  int get itemCount => _toInt(json['item_count']) ?? items.length;
  Map<String, dynamic> get _totals => json['totals'] is Map<String, dynamic> ? json['totals'] as Map<String, dynamic> : const {};
  double? get totalKcal => _toDouble(_totals['kcal']);
  double? get totalProtein => _toDouble(_totals['protein']);
  double? get totalCarb => _toDouble(_totals['carb']);
  double? get totalFat => _toDouble(_totals['fat']);

  // Exercise
  List<String> get primaryMuscles => [for (final m in json['primary_muscles'] as List<dynamic>? ?? const []) m.toString()];
  List<String> get secondaryMuscles => [for (final m in json['secondary_muscles'] as List<dynamic>? ?? const []) m.toString()];

  // Routine / meal plan
  String? get scheduleType => _str('schedule_type');
  int? get numWeeks => _toInt(json['num_weeks']);
  int? get trainingCount => _toInt(json['training_count']);
  int? get daysPlanned => _toInt(json['days_planned']);

  // Recipe
  int? get servings => _toInt(json['servings']);
  double? get kcalPerServing => _toDouble(json['kcal_per_serving']);
  double? get proteinPerServing => _toDouble(json['protein_per_serving']);
  double? get carbPerServing => _toDouble(json['carb_per_serving']);
  double? get fatPerServing => _toDouble(json['fat_per_serving']);

  // Food item
  String? get brand => _str('brand');
  String? get servingUnit => _str('serving_unit');
  double? get kcalPer100 => _toDouble(json['kcal_per_100']);
  double? get proteinPer100 => _toDouble(json['protein_per_100']);
  double? get carbPer100 => _toDouble(json['carb_per_100']);
  double? get fatPer100 => _toDouble(json['fat_per_100']);

  // Daily meal plan
  double? get kcalTotal => _toDouble(json['kcal_total']);
  double? get proteinTotal => _toDouble(json['protein_total']);
  double? get carbTotal => _toDouble(json['carb_total']);
  double? get fatTotal => _toDouble(json['fat_total']);
}

/// What "Share as post" shares: a logged workout or meal, or a library item.
/// [preview] is a locally built attachment shown while composing (the server
/// builds the real one).
class ShareTarget {
  final PostType type;

  /// The source id; null for a meal.
  final String? refId;

  /// Meals: YYYY-MM-DD and the API's slot type.
  final String? mealDate;
  final String? mealSlot;
  final PostAttachment preview;

  /// When the workout/meal happens; sharing waits until it has.
  final DateTime? happensAt;

  const ShareTarget({
    required this.type,
    this.refId,
    this.mealDate,
    this.mealSlot,
    this.preview = const PostAttachment({}),
    this.happensAt,
  });

  /// A library item (exercise, training, routine, recipe, food item, day
  /// plan, meal plan).
  const ShareTarget.item(this.type, String this.refId, {this.preview = const PostAttachment({})})
    : mealDate = null,
      mealSlot = null,
      happensAt = null;

  /// A logged training session.
  const ShareTarget.workout(String sessionId, {required DateTime startedAt, this.preview = const PostAttachment({})})
    : type = PostType.workout,
      refId = sessionId,
      mealDate = null,
      mealSlot = null,
      happensAt = startedAt;

  /// The food logged for [date] (a local day) in [slot] (API value). A day
  /// ahead of today counts as the future; today is up to the server, which
  /// knows when each item was eaten.
  ShareTarget.meal(DateTime date, String slot, {this.preview = const PostAttachment({})})
    : type = PostType.meal,
      refId = null,
      mealDate = _ymd(date),
      mealSlot = slot,
      happensAt = DateTime(date.year, date.month, date.day);

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Hasn't happened yet, so it can't be shared yet.
  bool isFuture([DateTime? now]) => type.isActivity && happensAt != null && happensAt!.isAfter(now ?? DateTime.now());

  /// The fields POST /posts takes.
  Map<String, dynamic> toRequestJson() => {
    'type': type.apiValue,
    'ref_id': ?refId,
    if (type == PostType.meal) 'meal': {'log_date': mealDate, 'slot_type': mealSlot},
  };

  Map<String, dynamic> toJson() => {
    ...toRequestJson(),
    'preview': preview.json,
    'happens_at': ?happensAt?.toUtc().toIso8601String(),
  };

  static ShareTarget? maybeFromJson(Object? v) {
    if (v is! Map<String, dynamic>) return null;
    final type = PostType.parse(v['type']);
    if (type == PostType.generic) return null;
    final meal = v['meal'] is Map<String, dynamic> ? v['meal'] as Map<String, dynamic> : const <String, dynamic>{};
    final refId = v['ref_id']?.toString();
    if (type != PostType.meal && refId == null) return null;
    if (type == PostType.meal && (meal['log_date'] == null || meal['slot_type'] == null)) return null;
    return ShareTarget(
      type: type,
      refId: refId,
      mealDate: meal['log_date']?.toString(),
      mealSlot: meal['slot_type']?.toString(),
      preview: PostAttachment.maybeFromJson(v['preview']) ?? const PostAttachment({}),
      happensAt: DateTime.tryParse(v['happens_at']?.toString() ?? '')?.toLocal(),
    );
  }
}

/// The gym/shop a business post belongs to.
class PostBusiness {
  final String id;
  final String name;
  final String? logo;
  final String type;

  const PostBusiness({required this.id, required this.name, this.logo, this.type = 'gym'});

  static PostBusiness? maybeFromJson(Object? json) => json is Map<String, dynamic>
      ? PostBusiness(
          id: json['id'] as String,
          name: json['name'] as String? ?? '',
          logo: json['logo'] as String?,
          type: json['type'] as String? ?? 'gym',
        )
      : null;
}

class Post {
  final String id;

  /// Null for a personal post.
  final String? businessId;
  final String? authorId;
  final String content;
  final List<PostImage> images;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SocialUser? author;
  final PostBusiness? business;
  final PostVisibility visibility;
  final ReactionSummary reactions;

  /// The caller's reaction; null when none (or loaded anonymously).
  final ReactionType? myReaction;
  final int commentCount;
  final bool canEdit;

  /// Personal posts: what it shares ([PostType.generic] = nothing).
  final PostType postType;

  /// The shared source (session, exercise, recipe, …); null for generic
  /// posts and meals.
  final String? refId;

  /// Snapshot of what's shared; null for generic posts.
  final PostAttachment? attachment;

  /// Whether I can open the shared source: someone else's workout or meal,
  /// or a private plan, is [LinkAccess.private]; a deleted one
  /// [LinkAccess.unavailable]. Null for generic posts.
  final LinkAccess? refAccess;

  /// Set while archived: hidden from everyone but me (profile, feed, shares).
  final DateTime? archivedAt;

  const Post({
    required this.id,
    this.businessId,
    this.authorId,
    required this.content,
    required this.images,
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.business,
    this.visibility = PostVisibility.public,
    this.reactions = ReactionSummary.empty,
    this.myReaction,
    this.commentCount = 0,
    this.canEdit = false,
    this.postType = PostType.generic,
    this.refId,
    this.attachment,
    this.refAccess,
    this.archivedAt,
  });

  bool get isPersonal => businessId == null;
  bool get isArchived => archivedAt != null;

  /// Shares a workout, meal or library item (shown as a card).
  bool get isTyped => postType != PostType.generic && attachment != null;

  /// Photos with people pinned on them.
  bool get hasPhotoTags => images.any((i) => i.tags.isNotEmpty);

  /// Whether [userId] is pinned on any photo.
  bool isTaggedIn(String userId) => images.any((i) => i.tags.any((t) => t.userId == userId));

  // Older "like" vocabulary: any reaction counts.
  int get likeCount => reactions.total;
  bool get likedByMe => myReaction != null;

  Post copyWith({
    int? commentCount,
    ReactionSummary? reactions,
    ReactionType? myReaction,
    bool clearMyReaction = false,
    String? content,
    PostVisibility? visibility,
    List<PostImage>? images,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
  }) => Post(
    id: id,
    businessId: businessId,
    authorId: authorId,
    content: content ?? this.content,
    images: images ?? this.images,
    createdAt: createdAt,
    updatedAt: updatedAt,
    author: author,
    business: business,
    visibility: visibility ?? this.visibility,
    reactions: reactions ?? this.reactions,
    myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
    commentCount: commentCount ?? this.commentCount,
    canEdit: canEdit,
    postType: postType,
    refId: refId,
    attachment: attachment,
    refAccess: refAccess,
    archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
  );

  /// The optimistic state after setting my reaction to [to] (null removes it).
  Post withMyReaction(ReactionType? to) => copyWith(
    reactions: reactions.switched(myReaction, to),
    myReaction: to,
    clearMyReaction: to == null,
  );

  /// The optimistic state after tapping a plain like button.
  Post toggledLike() => withMyReaction(myReaction == null ? ReactionType.like : null);

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    businessId: json['business_id'] as String?,
    authorId: json['author_id'] as String?,
    content: json['content'] as String? ?? '',
    images: (json['images'] as List<dynamic>? ?? [])
        .map((i) => PostImage.fromJson(i as Map<String, dynamic>))
        .where((i) => i.url.isNotEmpty)
        .toList(),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    author: SocialUser.maybeFromJson(json['author']),
    business: PostBusiness.maybeFromJson(json['business']),
    visibility: PostVisibility.parse(json['visibility']),
    reactions: json['reactions'] != null
        ? ReactionSummary.fromJson(json['reactions'])
        : ReactionSummary(
            total: int.parse((json['like_count'] ?? 0).toString()),
            counts: {
              if (int.parse((json['like_count'] ?? 0).toString()) > 0)
                ReactionType.like: int.parse((json['like_count'] ?? 0).toString()),
            },
          ),
    myReaction: ReactionType.tryParse(json['my_reaction']) ??
        ((json['liked_by_me'] as bool? ?? false) ? ReactionType.like : null),
    commentCount: int.parse((json['comment_count'] ?? 0).toString()),
    canEdit: json['can_edit'] as bool? ?? false,
    postType: PostType.parse(json['post_type']),
    refId: json['ref_id'] as String?,
    attachment: PostAttachment.maybeFromJson(json['attachment']),
    refAccess: LinkAccess.tryParse(json['ref_access']),
    archivedAt: DateTime.tryParse(json['archived_at'] as String? ?? '')?.toLocal(),
  );

  Map<String, dynamic> toJson() => {
    'business_id': businessId,
    'content': content,
    'images': images.map((i) => i.toJson()).toList(),
  };

  String? get imageUrl => images.isEmpty ? null : images.first.url;
}

/// Response of PUT/DELETE /posts/:id/reaction (and the legacy like routes).
class ReactionResult {
  final String postId;
  final ReactionSummary reactions;
  final ReactionType? myReaction;

  const ReactionResult({required this.postId, required this.reactions, this.myReaction});

  factory ReactionResult.fromJson(Map<String, dynamic> json) => ReactionResult(
    postId: json['post_id'] as String,
    reactions: ReactionSummary.fromJson(json['reactions']),
    myReaction: ReactionType.tryParse(json['my_reaction']),
  );
}

/// A row of GET /posts/:id/reactions.
class Reactor {
  final SocialUser user;
  final String username;
  final ReactionType reaction;

  const Reactor({required this.user, required this.username, required this.reaction});

  factory Reactor.fromJson(Map<String, dynamic> json) => Reactor(
    user: SocialUser.fromJson(json),
    username: json['username'] as String? ?? '',
    reaction: ReactionType.tryParse(json['reaction']) ?? ReactionType.like,
  );
}
