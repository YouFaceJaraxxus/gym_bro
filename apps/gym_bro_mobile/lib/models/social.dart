// Post comments and likes.
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// Minimal public profile attached to posts and comments.
class SocialUser {
  final String id;
  final String name;
  final String lastName;
  final String? avatarUrl;

  const SocialUser({
    required this.id,
    required this.name,
    required this.lastName,
    this.avatarUrl,
  });

  String get fullName => '$name $lastName'.trim();

  String get initials {
    final a = name.isNotEmpty ? name[0] : '';
    final b = lastName.isNotEmpty ? lastName[0] : '';
    final s = '$a$b'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  factory SocialUser.fromJson(Map<String, dynamic> json) => SocialUser(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    lastName: json['last_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
  );

  static SocialUser? maybeFromJson(Object? json) =>
      json is Map<String, dynamic> ? SocialUser.fromJson(json) : null;
}

class PostComment {
  final String id;
  final String postId;
  final String? authorId;
  final SocialUser? author;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Computed by the API for the caller: only the author can edit.
  final bool canEdit;

  /// The author, a super user or the business owner can delete.
  final bool canDelete;

  const PostComment({
    required this.id,
    required this.postId,
    this.authorId,
    this.author,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.canEdit = false,
    this.canDelete = false,
  });

  bool get isEdited => updatedAt.difference(createdAt).inSeconds >= 5;

  String authorName(AppLocalizations l10n) =>
      author?.fullName.isNotEmpty == true
      ? author!.fullName
      : l10n.nutritionDeletedUser;

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
    id: json['id'] as String,
    postId: json['post_id'] as String,
    authorId: json['author_id'] as String?,
    author: SocialUser.maybeFromJson(json['author']),
    body: json['body'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    canEdit: json['can_edit'] as bool? ?? false,
    canDelete: json['can_delete'] as bool? ?? false,
  );
}

/// Response of POST/DELETE /posts/:id/like.
class LikeResult {
  final String postId;
  final bool liked;
  final int likeCount;

  const LikeResult({
    required this.postId,
    required this.liked,
    required this.likeCount,
  });

  factory LikeResult.fromJson(Map<String, dynamic> json) => LikeResult(
    postId: json['post_id'] as String,
    liked: json['liked'] as bool? ?? false,
    likeCount: int.parse((json['like_count'] ?? 0).toString()),
  );
}

/// Short relative timestamp used by the feed and comments ("5m ago"),
/// falling back to a locale-formatted date after a week.
String relativeTime(AppLocalizations l10n, DateTime dt, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(dt);
  if (diff.inMinutes < 1) return l10n.nutritionJustNow;
  if (diff.inHours < 1) return l10n.nutritionMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.nutritionHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.nutritionDaysAgo(diff.inDays);
  return DateFormat.yMd(l10n.localeName).format(dt);
}
