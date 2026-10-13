import 'social.dart';

class PostImage {
  final String id;
  final String postId;
  final String url;
  final int position;

  const PostImage({
    required this.id,
    required this.postId,
    required this.url,
    required this.position,
  });

  factory PostImage.fromJson(Map<String, dynamic> json) => PostImage(
    id: json['id'] as String,
    postId: json['post_id'] as String,
    url: json['url'] as String,
    position: json['position'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {'url': url, 'position': position};
}

class Post {
  final String id;
  final String businessId;
  final String? authorId;
  final String content;
  final List<PostImage> images;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SocialUser? author;
  final int likeCount;
  final int commentCount;

  /// False when the feed was loaded anonymously.
  final bool likedByMe;

  const Post({
    required this.id,
    required this.businessId,
    this.authorId,
    required this.content,
    required this.images,
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
  });

  Post copyWith({int? likeCount, int? commentCount, bool? likedByMe}) => Post(
    id: id,
    businessId: businessId,
    authorId: authorId,
    content: content,
    images: images,
    createdAt: createdAt,
    updatedAt: updatedAt,
    author: author,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    likedByMe: likedByMe ?? this.likedByMe,
  );

  /// The optimistic state after tapping the like button.
  Post toggledLike() => copyWith(
    likedByMe: !likedByMe,
    likeCount: likedByMe ? (likeCount > 0 ? likeCount - 1 : 0) : likeCount + 1,
  );

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    authorId: json['author_id'] as String?,
    content: json['content'] as String,
    images: (json['images'] as List<dynamic>? ?? [])
        .map((i) => PostImage.fromJson(i as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    author: SocialUser.maybeFromJson(json['author']),
    likeCount: int.parse((json['like_count'] ?? 0).toString()),
    commentCount: int.parse((json['comment_count'] ?? 0).toString()),
    likedByMe: json['liked_by_me'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'business_id': businessId,
    'content': content,
    'images': images.map((i) => i.toJson()).toList(),
  };

  String? get imageUrl => images.isEmpty ? null : images.first.url;
}
