import '../config.dart';
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

  const PostImage({
    required this.id,
    required this.postId,
    required this.url,
    required this.position,
    this.mediaType = 'image',
    this.width,
    this.height,
    this.durationMs,
  });

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
  });

  bool get isPersonal => businessId == null;

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
  }) => Post(
    id: id,
    businessId: businessId,
    authorId: authorId,
    content: content ?? this.content,
    images: images,
    createdAt: createdAt,
    updatedAt: updatedAt,
    author: author,
    business: business,
    visibility: visibility ?? this.visibility,
    reactions: reactions ?? this.reactions,
    myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
    commentCount: commentCount ?? this.commentCount,
    canEdit: canEdit,
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
