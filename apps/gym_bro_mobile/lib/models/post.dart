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

  const Post({
    required this.id,
    required this.businessId,
    this.authorId,
    required this.content,
    required this.images,
    required this.createdAt,
    required this.updatedAt,
  });

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
      );

  Map<String, dynamic> toJson() => {
        'business_id': businessId,
        'content': content,
        'images': images.map((i) => i.toJson()).toList(),
      };

  String? get imageUrl => images.isEmpty ? null : images.first.url;
}
