// Stories, Instagram-style (API: /stories/*): a photo/video, a text card on a
// colour, or something shared — live for 24 hours, then in the author's
// archive.
import 'dart:ui' show Color;

import '../config.dart';
import 'reaction.dart';
import 'shared_content.dart';
import 'social.dart';

/// How long a story stays live.
const kStoryLifetime = Duration(hours: 24);

/// How long a photo / text / shared story shows before moving on.
const kStoryPhotoDuration = Duration(seconds: 5);

/// Background colours offered for text and shared stories ("#rrggbb").
const kStoryBackgrounds = ['#2b2d42', '#ef233c', '#ff7b00', '#2a9d8f', '#3a86ff', '#8338ec', '#ff006e', '#111111'];

class Story {
  final String id;
  final String authorId;
  final SocialUser? author;

  /// Signed URL (absolute) of the photo/video; null for text/shared stories.
  final String? mediaUrl;

  /// 'image' or 'video'; null without media.
  final String? mediaType;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? caption;

  /// "#rrggbb" behind text / shared stories.
  final String? background;

  /// What it shares, as the server resolved it for me.
  final SharedContent? share;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isLive;
  final bool seen;
  final ReactionType? myReaction;
  final bool isMine;

  /// The author only.
  final int? viewCount;
  final int? reactionCount;

  const Story({
    required this.id,
    required this.authorId,
    this.author,
    this.mediaUrl,
    this.mediaType,
    this.width,
    this.height,
    this.durationMs,
    this.caption,
    this.background,
    this.share,
    required this.createdAt,
    required this.expiresAt,
    this.isLive = true,
    this.seen = false,
    this.myReaction,
    this.isMine = false,
    this.viewCount,
    this.reactionCount,
  });

  bool get isVideo => mediaType == 'video';
  bool get hasMedia => mediaUrl != null;
  bool get liked => myReaction != null;

  /// How long it shows in the viewer: a video's length (capped at a minute),
  /// else [kStoryPhotoDuration].
  Duration get displayDuration {
    if (isVideo && durationMs != null && durationMs! > 0) {
      return Duration(milliseconds: durationMs!.clamp(1000, 60000));
    }
    return kStoryPhotoDuration;
  }

  Color get backgroundColor => parseHexColor(background) ?? const Color(0xFF2B2D42);

  Story copyWith({bool? seen, ReactionType? myReaction, bool clearMyReaction = false, int? reactionCount}) => Story(
    id: id,
    authorId: authorId,
    author: author,
    mediaUrl: mediaUrl,
    mediaType: mediaType,
    width: width,
    height: height,
    durationMs: durationMs,
    caption: caption,
    background: background,
    share: share,
    createdAt: createdAt,
    expiresAt: expiresAt,
    isLive: isLive,
    seen: seen ?? this.seen,
    myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
    isMine: isMine,
    viewCount: viewCount,
    reactionCount: reactionCount ?? this.reactionCount,
  );

  factory Story.fromJson(Map<String, dynamic> json) {
    final media = json['media_url'] as String?;
    return Story(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      author: SocialUser.maybeFromJson(json['author']),
      mediaUrl: media == null || media.isEmpty ? null : AppConfig.resolveUrl(media),
      mediaType: json['media_type'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      durationMs: json['duration_ms'] as int?,
      caption: json['caption'] as String?,
      background: json['background'] as String?,
      share: SharedContent.maybeFromJson(json['share']),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
      isLive: json['is_live'] as bool? ?? true,
      seen: json['seen'] as bool? ?? false,
      myReaction: ReactionType.tryParse(json['my_reaction']),
      isMine: json['is_mine'] as bool? ?? false,
      viewCount: json['view_count'] as int?,
      reactionCount: json['reaction_count'] as int?,
    );
  }
}

/// "#rrggbb" → Color; null when it isn't one.
Color? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

/// One person in the stories tray.
class StoryTrayEntry {
  final SocialUser user;
  final bool isMe;
  final int storyCount;
  final int unseenCount;
  final DateTime latestAt;

  const StoryTrayEntry({
    required this.user,
    this.isMe = false,
    this.storyCount = 0,
    this.unseenCount = 0,
    required this.latestAt,
  });

  bool get hasUnseen => unseenCount > 0;

  StoryTrayEntry seenAll() =>
      StoryTrayEntry(user: user, isMe: isMe, storyCount: storyCount, unseenCount: 0, latestAt: latestAt);

  factory StoryTrayEntry.fromJson(Map<String, dynamic> json) => StoryTrayEntry(
    user: SocialUser.fromJson(json['user'] as Map<String, dynamic>),
    isMe: json['is_me'] as bool? ?? false,
    storyCount: json['story_count'] as int? ?? 0,
    unseenCount: json['unseen_count'] as int? ?? 0,
    latestAt: DateTime.tryParse(json['latest_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
  );
}

/// Someone who watched my story (GET /stories/:id/viewers).
class StoryViewer {
  final SocialUser user;
  final DateTime viewedAt;
  final ReactionType? reaction;

  const StoryViewer({required this.user, required this.viewedAt, this.reaction});

  factory StoryViewer.fromJson(Map<String, dynamic> json) => StoryViewer(
    user: SocialUser.fromJson(json['user'] as Map<String, dynamic>),
    viewedAt: DateTime.tryParse(json['viewed_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    reaction: ReactionType.tryParse(json['reaction']),
  );
}

/// Response of liking / reacting to a story.
class StoryReactionResult {
  final String storyId;
  final ReactionType? myReaction;

  /// The author only.
  final int? reactionCount;

  const StoryReactionResult({required this.storyId, this.myReaction, this.reactionCount});

  factory StoryReactionResult.fromJson(Map<String, dynamic> json) => StoryReactionResult(
    storyId: json['story_id'] as String,
    myReaction: ReactionType.tryParse(json['my_reaction']),
    reactionCount: json['reaction_count'] as int?,
  );
}

/// The quick reactions offered when swiping up on someone's story (each
/// sends "Reacted 🔥 to your story" to their DMs).
const kStoryQuickReactions = [
  ReactionType.haha,
  ReactionType.wow,
  ReactionType.love,
  ReactionType.sad,
  ReactionType.clap,
  ReactionType.fire,
  ReactionType.celebrate,
  ReactionType.strong,
];
