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

  /// 'everyone' or 'close_friends' (the green ring).
  final String audience;

  /// The poll sticker on it, if any.
  final StoryPoll? poll;

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
    this.audience = kStoryAudienceEveryone,
    this.poll,
  });

  bool get closeFriends => audience == kStoryAudienceCloseFriends;
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

  Story copyWith({bool? seen, ReactionType? myReaction, bool clearMyReaction = false, int? reactionCount, StoryPoll? poll}) => Story(
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
    audience: audience,
    poll: poll ?? this.poll,
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
      audience: json['audience'] as String? ??
          (json['close_friends'] == true ? kStoryAudienceCloseFriends : kStoryAudienceEveryone),
      poll: StoryPoll.maybeFromJson(json['poll']),
    );
  }
}

const kStoryAudienceEveryone = 'everyone';
const kStoryAudienceCloseFriends = 'close_friends';

/// The colour of close-friends stories: their ring, badge and the composer's button.
const kCloseFriendsGreen = Color(0xFF1DB954);

int? _intOrNull(Object? v) => v == null ? null : (v is int ? v : int.tryParse(v.toString()) ?? double.tryParse(v.toString())?.round());

/// A poll sticker ({question, options: 2–4}). [counts] and [total] are null
/// until I vote, unless it's my story.
class StoryPoll {
  final String question;
  final List<String> options;

  /// The option I picked (index), null when I haven't voted.
  final int? myVote;
  final int? total;
  final List<int>? counts;

  const StoryPoll({this.question = '', required this.options, this.myVote, this.total, this.counts});

  bool get hasResults => counts != null;
  bool get voted => myVote != null;

  /// Option [i]'s share of the votes, 0–1 (0 without results or votes).
  double fraction(int i) {
    final c = counts;
    if (c == null || i < 0 || i >= c.length) return 0;
    final sum = total ?? c.fold<int>(0, (a, b) => a + b);
    return sum <= 0 ? 0 : c[i] / sum;
  }

  /// Option [i]'s share in whole percent.
  int percent(int i) => (fraction(i) * 100).round();

  /// The body for creating one.
  Map<String, dynamic> toJson() => {'question': question.trim(), 'options': [for (final o in options) o.trim()]};

  factory StoryPoll.fromJson(Map<String, dynamic> json) => StoryPoll(
    question: json['question'] as String? ?? '',
    options: [for (final o in json['options'] as List<dynamic>? ?? const []) o.toString()],
    myVote: _intOrNull(json['my_vote']),
    total: _intOrNull(json['total']),
    counts: json['counts'] is List ? [for (final c in json['counts'] as List) _intOrNull(c) ?? 0] : null,
  );

  static StoryPoll? maybeFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final poll = StoryPoll.fromJson(json);
    return poll.options.length < 2 ? null : poll;
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

  /// Some of their live stories are for close friends (the green ring).
  final bool closeFriends;

  const StoryTrayEntry({
    required this.user,
    this.isMe = false,
    this.storyCount = 0,
    this.unseenCount = 0,
    required this.latestAt,
    this.closeFriends = false,
  });

  bool get hasUnseen => unseenCount > 0;

  StoryTrayEntry seenAll() => StoryTrayEntry(
    user: user,
    isMe: isMe,
    storyCount: storyCount,
    unseenCount: 0,
    latestAt: latestAt,
    closeFriends: closeFriends,
  );

  factory StoryTrayEntry.fromJson(Map<String, dynamic> json) => StoryTrayEntry(
    user: SocialUser.fromJson(json['user'] as Map<String, dynamic>),
    isMe: json['is_me'] as bool? ?? false,
    storyCount: json['story_count'] as int? ?? 0,
    unseenCount: json['unseen_count'] as int? ?? 0,
    latestAt: DateTime.tryParse(json['latest_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    closeFriends: json['close_friends'] as bool? ?? false,
  );
}

/// Someone who watched my story (GET /stories/:id/viewers).
class StoryViewer {
  final SocialUser user;
  final DateTime viewedAt;
  final ReactionType? reaction;

  /// The poll option they picked, if the story has a poll and they voted.
  final int? pollVote;

  const StoryViewer({required this.user, required this.viewedAt, this.reaction, this.pollVote});

  factory StoryViewer.fromJson(Map<String, dynamic> json) => StoryViewer(
    user: SocialUser.fromJson(json['user'] as Map<String, dynamic>),
    viewedAt: DateTime.tryParse(json['viewed_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    reaction: ReactionType.tryParse(json['reaction']),
    pollVote: _intOrNull(json['poll_vote']),
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

// ── Highlights ────────────────────────────────────────────────────────────────

/// What a highlight's circle shows: its cover story's photo/video, or its
/// colour and text.
class HighlightCover {
  final String storyId;
  final String? mediaUrl;
  final String? mediaType;
  final String? background;
  final String? caption;

  const HighlightCover({required this.storyId, this.mediaUrl, this.mediaType, this.background, this.caption});

  bool get isVideo => mediaType == 'video';
  bool get hasMedia => mediaUrl != null;
  Color get backgroundColor => parseHexColor(background) ?? const Color(0xFF2B2D42);

  factory HighlightCover.fromJson(Map<String, dynamic> json) {
    final media = json['media_url'] as String?;
    return HighlightCover(
      storyId: json['story_id'] as String? ?? '',
      mediaUrl: media == null || media.isEmpty ? null : AppConfig.resolveUrl(media),
      mediaType: json['media_type'] as String?,
      background: json['background'] as String?,
      caption: json['caption'] as String?,
    );
  }
}

/// A highlight on someone's profile (GET /stories/highlights?user_id=):
/// stories kept after they expired. [storyCount] counts only those I may see.
class StoryHighlight {
  final String id;
  final String userId;
  final String title;

  /// The cover the owner picked (null: the newest story).
  final String? coverStoryId;
  final int storyCount;
  final HighlightCover? cover;

  const StoryHighlight({
    required this.id,
    required this.userId,
    required this.title,
    this.coverStoryId,
    this.storyCount = 0,
    this.cover,
  });

  factory StoryHighlight.fromJson(Map<String, dynamic> json) => StoryHighlight(
    id: json['id'] as String,
    userId: json['user_id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    coverStoryId: json['cover_story_id'] as String?,
    storyCount: _intOrNull(json['story_count']) ?? 0,
    cover: json['cover'] is Map<String, dynamic> ? HighlightCover.fromJson(json['cover'] as Map<String, dynamic>) : null,
  );
}

/// One highlight with its stories, oldest first (GET /stories/highlights/:id).
class StoryHighlightDetail {
  final StoryHighlight highlight;
  final SocialUser? user;
  final List<Story> stories;

  const StoryHighlightDetail({required this.highlight, this.user, this.stories = const []});

  String get id => highlight.id;
  String get title => highlight.title;

  factory StoryHighlightDetail.fromJson(Map<String, dynamic> json) => StoryHighlightDetail(
    highlight: StoryHighlight.fromJson(json),
    user: SocialUser.maybeFromJson(json['user']),
    stories: [for (final s in json['stories'] as List<dynamic>? ?? const []) Story.fromJson(s as Map<String, dynamic>)],
  );
}
