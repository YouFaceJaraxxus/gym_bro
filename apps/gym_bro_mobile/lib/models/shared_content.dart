// Things shared in chat messages and stories (API: _shared/shares.ts).
//
// A share is resolved by the server for whoever reads it, so the preview
// always follows the current visibility rules: a viewer who can't see a
// private account's post gets [SharedContent.available] false with a
// [ShareUnavailableReason] instead of the post.
import 'post.dart';
import 'social.dart';

/// What can be shared. Stories take all but [user], [business] and [story].
enum ShareKind {
  post('post'),
  story('story'),
  user('user'),
  business('business'),
  shopItem('shop_item'),

  /// A logged training session (a snapshot by its owner).
  workout('workout'),

  /// The food logged for a day + meal slot (a snapshot by its owner).
  meal('meal'),
  exercise('exercise'),

  /// A workout template; "workout" in the UI.
  training('training'),
  routine('routine'),
  recipe('recipe'),
  foodItem('food_item'),
  dailyMealPlan('daily_meal_plan'),
  mealPlan('meal_plan');

  const ShareKind(this.apiValue);
  final String apiValue;

  static ShareKind? tryParse(Object? v) {
    for (final k in values) {
      if (k.apiValue == v) return k;
    }
    return null;
  }

  /// Whether it can go in a story (people and businesses — accounts — can't).
  bool get storyable => this != user && this != business && this != story;

  /// The post type sharing the same thing, for kinds a post can share too.
  PostType? get postType => switch (this) {
    workout => PostType.workout,
    meal => PostType.meal,
    exercise => PostType.exercise,
    training => PostType.training,
    routine => PostType.routine,
    recipe => PostType.recipe,
    foodItem => PostType.foodItem,
    dailyMealPlan => PostType.dailyMealPlan,
    mealPlan => PostType.mealPlan,
    _ => null,
  };

  static ShareKind fromPostType(PostType t) => switch (t) {
    PostType.workout => workout,
    PostType.meal => meal,
    PostType.exercise => exercise,
    PostType.training => training,
    PostType.routine => routine,
    PostType.recipe => recipe,
    PostType.foodItem => foodItem,
    PostType.dailyMealPlan => dailyMealPlan,
    PostType.mealPlan => mealPlan,
    PostType.generic => post,
  };
}

/// Why a share shows no preview.
enum ShareUnavailableReason {
  /// It exists, but this viewer isn't allowed to see it (a private account,
  /// a private plan, a followers-only post).
  private('private'),

  /// Deleted, archived, or someone blocked someone.
  unavailable('unavailable'),

  /// A story past its 24 hours (its author still sees it).
  expired('expired');

  const ShareUnavailableReason(this.apiValue);
  final String apiValue;

  static ShareUnavailableReason parse(Object? v) =>
      values.firstWhere((r) => r.apiValue == v, orElse: () => unavailable);
}

/// What to share: a thing by id, or a logged meal by day + slot. Built from
/// whatever screen the share starts on and sent as `share` to the API.
class ShareRequest {
  final ShareKind kind;

  /// The thing's id; null only for a meal.
  final String? refId;

  /// Meals: YYYY-MM-DD and the API's slot type.
  final String? mealDate;
  final String? mealSlot;

  /// A preview to show while choosing where to send it (what's known
  /// locally); the server builds the real one.
  final PostAttachment preview;

  /// A short label for the sheet ("Leg day", "@ana").
  final String? title;

  /// When a workout/meal happens; it can't be shared before it has.
  final DateTime? happensAt;

  const ShareRequest({
    required this.kind,
    this.refId,
    this.mealDate,
    this.mealSlot,
    this.preview = const PostAttachment({}),
    this.title,
    this.happensAt,
  });

  const ShareRequest.of(this.kind, String this.refId, {this.title, this.preview = const PostAttachment({})})
    : mealDate = null,
      mealSlot = null,
      happensAt = null;

  /// The same thing as a "Share as post" target (workouts, meals and library
  /// items), so the share sheet can offer posting it too.
  factory ShareRequest.fromTarget(ShareTarget t) => ShareRequest(
    kind: ShareKind.fromPostType(t.type),
    refId: t.refId,
    mealDate: t.mealDate,
    mealSlot: t.mealSlot,
    preview: t.preview,
    title: t.preview.title,
    happensAt: t.happensAt,
  );

  /// Back to a "Share as post" target; null for kinds a post can't share.
  ShareTarget? get postTarget {
    final type = kind.postType;
    if (type == null) return null;
    return ShareTarget(
      type: type,
      refId: refId,
      mealDate: mealDate,
      mealSlot: mealSlot,
      preview: preview,
      happensAt: happensAt,
    );
  }

  bool isFuture([DateTime? now]) =>
      (kind == ShareKind.workout || kind == ShareKind.meal) && happensAt != null && happensAt!.isAfter(now ?? DateTime.now());

  /// The `share` object the API takes.
  Map<String, dynamic> toJson() => {
    'kind': kind.apiValue,
    'ref_id': ?refId,
    if (kind == ShareKind.meal) 'meal': {'log_date': mealDate, 'slot_type': mealSlot},
  };
}

/// A shared thing as the server resolved it for me.
class SharedContent {
  final ShareKind kind;
  final String? refId;

  /// true: [preview] is set. false: [reason] says why not. null: not
  /// resolved yet (a realtime payload) — fetch the message.
  final bool? available;
  final ShareUnavailableReason? reason;

  /// The kind's fields (see the API's _shared/shares.ts). Library items,
  /// workouts and meals use the post attachment shape.
  final Map<String, dynamic> preview;

  const SharedContent({
    required this.kind,
    this.refId,
    this.available,
    this.reason,
    this.preview = const {},
  });

  bool get isAvailable => available == true;
  bool get isResolved => available != null;

  static SharedContent? maybeFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final kind = ShareKind.tryParse(json['kind']);
    if (kind == null) return null;
    final available = json['available'] as bool?;
    return SharedContent(
      kind: kind,
      refId: json['ref_id'] as String?,
      available: available,
      reason: available == false ? ShareUnavailableReason.parse(json['reason']) : null,
      preview: json['preview'] is Map<String, dynamic> ? json['preview'] as Map<String, dynamic> : const {},
    );
  }

  // ── Typed views of [preview] ──

  /// Library items, workouts and meals.
  PostAttachment get attachment => PostAttachment(preview);

  String? _str(String key) {
    final v = preview[key];
    return v == null || v.toString().trim().isEmpty ? null : v.toString();
  }

  /// The person who posted it (post, story).
  SocialUser? get author => SocialUser.maybeFromJson(preview['author']);

  /// Posts: caption (mentions as "@Name").
  String? get caption => _str('caption');

  /// Posts: first photo/video (signed, relative); stories: the media.
  String? get mediaUrl => _str('thumbnail_url') ?? _str('media_url');
  bool get isVideo => preview['media_type'] == 'video';
  int get mediaCount => int.tryParse(preview['media_count']?.toString() ?? '') ?? 0;

  /// Posts: what the post itself shares.
  PostType get postType => PostType.parse(preview['post_type']);
  PostAttachment? get postAttachment => PostAttachment.maybeFromJson(preview['attachment']);

  /// Stories: text and background.
  String? get background => _str('background');
  DateTime? get expiresAt => DateTime.tryParse(preview['expires_at']?.toString() ?? '')?.toLocal();

  // Accounts
  String? get username => _str('username');
  String get fullName => '${preview['name'] ?? ''} ${preview['last_name'] ?? ''}'.trim();
  String? get avatarUrl => _str('avatar_url');
  bool get isPrivate => preview['is_private'] == true;
  String? get bio => _str('bio');

  // Businesses & products
  String? get name => _str('name');
  String? get logo => _str('logo');
  String? get location => _str('location');
  String? get businessType => _str('type');
  String? get imageUrl => _str('image_url');
  double? get price => double.tryParse(preview['price']?.toString() ?? '');
  String? get shopName => _str('shop_name');

  /// The best one-line title for any kind.
  String? get title => switch (kind) {
    ShareKind.user => fullName.isNotEmpty ? fullName : username,
    ShareKind.business || ShareKind.shopItem => name,
    ShareKind.post || ShareKind.story => author?.fullName,
    _ => attachment.title,
  };
}

/// A message answering a story: a text reply, or a quick emoji reaction.
class StoryReplyInfo {
  /// 'reply' or 'reaction'.
  final String mode;
  final String? storyId;

  /// Whose story it was.
  final String? ownerId;

  /// Reactions: the API's reaction type ('fire', 'love', …).
  final String? reaction;

  /// The story as I may see it now (expired / deleted → unavailable).
  final SharedContent story;

  const StoryReplyInfo({required this.mode, this.storyId, this.ownerId, this.reaction, required this.story});

  bool get isReaction => mode == 'reaction';

  static StoryReplyInfo? maybeFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return StoryReplyInfo(
      mode: json['mode'] as String? ?? 'reply',
      storyId: json['story_id'] as String?,
      ownerId: json['owner_id'] as String?,
      reaction: json['reaction'] as String?,
      story: SharedContent.maybeFromJson(json['story']) ??
          const SharedContent(kind: ShareKind.story, available: false, reason: ShareUnavailableReason.unavailable),
    );
  }
}

/// One target's outcome of POST /chat/share.
class ShareSendResult {
  final String? userId;
  final String? conversationId;
  final bool sent;
  final String? error;

  const ShareSendResult({this.userId, this.conversationId, required this.sent, this.error});

  factory ShareSendResult.fromJson(Map<String, dynamic> json) => ShareSendResult(
    userId: json['user_id'] as String?,
    conversationId: json['conversation_id'] as String?,
    sent: json['status'] == 201,
    error: json['error'] as String?,
  );
}
