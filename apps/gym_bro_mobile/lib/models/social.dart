// Post comments (threaded) and their reactions.
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import 'reaction.dart';

/// Minimal public profile attached to posts and comments.
class SocialUser {
  final String id;
  final String username;
  final String name;
  final String lastName;
  final String? avatarUrl;

  const SocialUser({
    required this.id,
    this.username = '',
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
    username: json['username'] as String? ?? '',
    name: json['name'] as String? ?? '',
    lastName: json['last_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
  );

  static SocialUser? maybeFromJson(Object? json) =>
      json is Map<String, dynamic> ? SocialUser.fromJson(json) : null;
}

/// The deepest reply level the API accepts (depth 0 … 9 = ten levels).
const kMaxCommentDepth = 9;

class PostComment {
  final String id;
  final String postId;

  /// Null for a top-level comment.
  final String? parentId;

  /// 0 for top-level, up to [kMaxCommentDepth].
  final int depth;
  final String? authorId;
  final SocialUser? author;

  /// Empty when [deleted] or [hidden].
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Removed but kept as a placeholder because it has replies.
  final bool deleted;

  /// Written by someone I blocked or who blocked me.
  final bool hidden;
  final int replyCount;
  final ReactionSummary reactions;
  final ReactionType? myReaction;

  /// Reactions + 2 × replies; used to sort siblings by "top".
  final int score;

  /// Computed by the API for the caller: only the author can edit.
  final bool canEdit;

  /// The author, a super user, the business owner or the post's author can delete.
  final bool canDelete;
  final bool canReply;

  const PostComment({
    required this.id,
    required this.postId,
    this.parentId,
    this.depth = 0,
    this.authorId,
    this.author,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.hidden = false,
    this.replyCount = 0,
    this.reactions = ReactionSummary.empty,
    this.myReaction,
    this.score = 0,
    this.canEdit = false,
    this.canDelete = false,
    this.canReply = false,
  });

  PostComment withMyReaction(ReactionType? to) => PostComment(
    id: id,
    postId: postId,
    parentId: parentId,
    depth: depth,
    authorId: authorId,
    author: author,
    body: body,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
    hidden: hidden,
    replyCount: replyCount,
    reactions: reactions.switched(myReaction, to),
    myReaction: to,
    score: score,
    canEdit: canEdit,
    canDelete: canDelete,
    canReply: canReply,
  );

  bool get isEdited => updatedAt.difference(createdAt).inSeconds >= 5;

  String authorName(AppLocalizations l10n) =>
      author?.fullName.isNotEmpty == true
      ? author!.fullName
      : l10n.nutritionDeletedUser;

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
    id: json['id'] as String,
    postId: json['post_id'] as String,
    parentId: json['parent_id'] as String?,
    depth: json['depth'] as int? ?? 0,
    authorId: json['author_id'] as String?,
    author: SocialUser.maybeFromJson(json['author']),
    body: json['body'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    deleted: json['deleted'] as bool? ?? false,
    hidden: json['hidden'] as bool? ?? false,
    replyCount: int.parse((json['reply_count'] ?? 0).toString()),
    reactions: ReactionSummary.fromJson(json['reactions']),
    myReaction: ReactionType.tryParse(json['my_reaction']),
    score: int.parse((json['score'] ?? 0).toString()),
    canEdit: json['can_edit'] as bool? ?? false,
    canDelete: json['can_delete'] as bool? ?? false,
    canReply: json['can_reply'] as bool? ?? false,
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
