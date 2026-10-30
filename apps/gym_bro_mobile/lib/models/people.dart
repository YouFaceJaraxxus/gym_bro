// People: profiles, relationships, discovery (API: /social/*).

/// Minimal public card of a user (lists, search results, chat members).
class PersonSummary {
  final String id;
  final String username;
  final String name;
  final String lastName;
  final String? avatarUrl;

  /// Present on list rows from /social/* (null elsewhere).
  final String? bio;
  final bool isPrivate;

  /// My relationship to them; null for myself or when not provided.
  final Relationship? relationship;

  const PersonSummary({
    required this.id,
    required this.username,
    required this.name,
    required this.lastName,
    this.avatarUrl,
    this.bio,
    this.isPrivate = false,
    this.relationship,
  });

  String get fullName => '$name $lastName'.trim();

  String get initials {
    final a = name.isNotEmpty ? name[0] : '';
    final b = lastName.isNotEmpty ? lastName[0] : '';
    final s = '$a$b'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  factory PersonSummary.fromJson(Map<String, dynamic> json) => PersonSummary(
    id: json['id'] as String,
    username: json['username'] as String? ?? '',
    name: json['name'] as String? ?? '',
    lastName: json['last_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    bio: json['bio'] as String?,
    isPrivate: json['is_private'] as bool? ?? false,
    relationship: Relationship.maybeFromJson(json['relationship']),
  );

  static PersonSummary? maybeFromJson(Object? json) =>
      json is Map<String, dynamic> ? PersonSummary.fromJson(json) : null;

  PersonSummary copyWith({Relationship? relationship}) => PersonSummary(
    id: id,
    username: username,
    name: name,
    lastName: lastName,
    avatarUrl: avatarUrl,
    bio: bio,
    isPrivate: isPrivate,
    relationship: relationship ?? this.relationship,
  );
}

enum FollowState {
  none,
  pending,
  accepted;

  static FollowState parse(Object? v) => switch (v) {
    'pending' => FollowState.pending,
    'accepted' => FollowState.accepted,
    _ => FollowState.none,
  };
}

enum FriendState {
  none,

  /// I asked them.
  outgoing,

  /// They asked me.
  incoming,
  friends;

  static FriendState parse(Object? v) => switch (v) {
    'outgoing' => FriendState.outgoing,
    'incoming' => FriendState.incoming,
    'friends' => FriendState.friends,
    _ => FriendState.none,
  };
}

/// My relationship to another user.
class Relationship {
  /// Me → them.
  final FollowState following;

  /// Them → me.
  final FollowState followedBy;
  final FriendState friendship;

  /// I blocked them.
  final bool blocked;

  const Relationship({
    this.following = FollowState.none,
    this.followedBy = FollowState.none,
    this.friendship = FriendState.none,
    this.blocked = false,
  });

  factory Relationship.fromJson(Map<String, dynamic> json) => Relationship(
    following: FollowState.parse(json['following']),
    followedBy: FollowState.parse(json['followed_by']),
    friendship: FriendState.parse(json['friendship']),
    blocked: json['blocked'] as bool? ?? false,
  );

  static Relationship? maybeFromJson(Object? json) =>
      json is Map<String, dynamic> ? Relationship.fromJson(json) : null;

  bool get isFriend => friendship == FriendState.friends;
}

class ProfileCounts {
  final int posts;
  final int followers;
  final int following;
  final int friends;

  const ProfileCounts({this.posts = 0, this.followers = 0, this.following = 0, this.friends = 0});

  factory ProfileCounts.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const ProfileCounts();
    int n(String k) => int.parse((json[k] ?? 0).toString());
    return ProfileCounts(posts: n('posts'), followers: n('followers'), following: n('following'), friends: n('friends'));
  }
}

class GymRef {
  final String id;
  final String name;
  final String? logo;

  const GymRef({required this.id, required this.name, this.logo});

  factory GymRef.fromJson(Map<String, dynamic> json) =>
      GymRef(id: json['id'] as String, name: json['name'] as String? ?? '', logo: json['logo'] as String?);
}

/// Who may message me directly (anyone else lands in message requests).
/// My own privacy settings (GET /social/me only).
class ProfileSettings {
  final bool isPrivate;
  final bool discoverable;
  /// Off: only approved followers (and friends) can message me.
  final bool allowNonFollowerMessages;
  final bool showActivityStatus;
  final bool hasLocation;
  final DateTime? locationUpdatedAt;

  const ProfileSettings({
    required this.isPrivate,
    required this.discoverable,
    required this.allowNonFollowerMessages,
    required this.showActivityStatus,
    required this.hasLocation,
    this.locationUpdatedAt,
  });

  factory ProfileSettings.fromJson(Map<String, dynamic> json) => ProfileSettings(
    isPrivate: json['is_private'] as bool? ?? false,
    discoverable: json['discoverable'] as bool? ?? true,
    allowNonFollowerMessages: json['allow_non_follower_messages'] as bool? ?? true,
    showActivityStatus: json['show_activity_status'] as bool? ?? true,
    hasLocation: json['has_location'] as bool? ?? false,
    locationUpdatedAt: DateTime.tryParse(json['location_updated_at'] as String? ?? '')?.toLocal(),
  );
}

/// A user's profile page (GET /social/users/:id, /social/me).
class PublicProfile {
  final String id;
  final String username;
  final String name;
  final String lastName;
  final String? avatarUrl;
  final String role;
  final String? bio;
  final List<String> interests;
  final bool isPrivate;
  final bool isMe;
  final ProfileCounts counts;
  final Relationship? relationship;

  /// False for a private account I don't follow: no posts, no lists.
  final bool canViewContent;

  /// 'active' (lands in their inbox), 'request' (message request) or null
  /// (can't message: blocked, or it's me).
  final String? messageStatus;
  final int mutualFriendCount;
  final List<PersonSummary> mutualFriendsPreview;
  final List<GymRef> gyms;

  /// Only when they share activity status and we're connected.
  final DateTime? lastActiveAt;
  final DateTime? createdAt;

  /// Only on my own profile.
  final ProfileSettings? settings;

  /// Their live stories I can see, and whether any are unwatched (the
  /// coloured ring around the avatar).
  final int storyCount;
  final bool hasUnseenStory;

  const PublicProfile({
    required this.id,
    required this.username,
    required this.name,
    required this.lastName,
    this.avatarUrl,
    this.role = 'member',
    this.bio,
    this.interests = const [],
    this.isPrivate = false,
    this.isMe = false,
    this.counts = const ProfileCounts(),
    this.relationship,
    this.canViewContent = true,
    this.messageStatus,
    this.mutualFriendCount = 0,
    this.mutualFriendsPreview = const [],
    this.gyms = const [],
    this.lastActiveAt,
    this.createdAt,
    this.settings,
    this.storyCount = 0,
    this.hasUnseenStory = false,
  });

  String get fullName => '$name $lastName'.trim();

  bool get hasStory => storyCount > 0;

  PersonSummary get summary =>
      PersonSummary(id: id, username: username, name: name, lastName: lastName, avatarUrl: avatarUrl, bio: bio, isPrivate: isPrivate, relationship: relationship);

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    final mutual = json['mutual_friends'] as Map<String, dynamic>? ?? const {};
    return PublicProfile(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'member',
      bio: json['bio'] as String?,
      interests: (json['interests'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      isPrivate: json['is_private'] as bool? ?? false,
      isMe: json['is_me'] as bool? ?? false,
      counts: ProfileCounts.fromJson(json['counts']),
      relationship: Relationship.maybeFromJson(json['relationship']),
      canViewContent: json['can_view_content'] as bool? ?? true,
      messageStatus: json['message_status'] as String?,
      mutualFriendCount: int.parse((mutual['count'] ?? 0).toString()),
      mutualFriendsPreview: (mutual['preview'] as List<dynamic>? ?? [])
          .map((e) => PersonSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      gyms: (json['gyms'] as List<dynamic>? ?? []).map((e) => GymRef.fromJson(e as Map<String, dynamic>)).toList(),
      lastActiveAt: DateTime.tryParse(json['last_active_at'] as String? ?? '')?.toLocal(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
      settings: json['settings'] is Map<String, dynamic>
          ? ProfileSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : null,
      storyCount: json['story_count'] as int? ?? 0,
      hasUnseenStory: json['has_unseen_story'] as bool? ?? false,
    );
  }
}

/// Why someone is suggested (GET /social/suggestions → reasons[]).
sealed class SuggestionReason {
  const SuggestionReason();

  static SuggestionReason? fromJson(Map<String, dynamic> json) => switch (json['type']) {
    'follows_you' => const FollowsYouReason(),
    'mutual' => MutualReason(int.parse((json['count'] ?? 0).toString())),
    'same_gym' => SameGymReason((json['gyms'] as List<dynamic>? ?? []).map((e) => e.toString()).toList()),
    'same_time' => SameTimeReason(int.parse((json['days'] ?? 0).toString())),
    'same_class' => SameClassReason(int.parse((json['count'] ?? 0).toString())),
    'nearby' => NearbyReason(int.parse((json['km'] ?? 0).toString())),
    'interests' => InterestsReason((json['interests'] as List<dynamic>? ?? []).map((e) => e.toString()).toList()),
    _ => null,
  };
}

class FollowsYouReason extends SuggestionReason {
  const FollowsYouReason();
}

class MutualReason extends SuggestionReason {
  final int count;
  const MutualReason(this.count);
}

class SameGymReason extends SuggestionReason {
  final List<String> gyms;
  const SameGymReason(this.gyms);
}

/// Checks in at the same gym around the same time of day.
class SameTimeReason extends SuggestionReason {
  final int days;
  const SameTimeReason(this.days);
}

class SameClassReason extends SuggestionReason {
  final int count;
  const SameClassReason(this.count);
}

class NearbyReason extends SuggestionReason {
  final int km;
  const NearbyReason(this.km);
}

class InterestsReason extends SuggestionReason {
  final List<String> interests;
  const InterestsReason(this.interests);
}

/// A "people you may know" card.
class Suggestion {
  final PersonSummary person;
  final double score;
  final List<SuggestionReason> reasons;

  const Suggestion({required this.person, required this.score, required this.reasons});

  factory Suggestion.fromJson(Map<String, dynamic> json) => Suggestion(
    person: PersonSummary.fromJson(json),
    score: double.parse((json['score'] ?? 0).toString()),
    reasons: (json['reasons'] as List<dynamic>? ?? [])
        .map((e) => SuggestionReason.fromJson(e as Map<String, dynamic>))
        .whereType<SuggestionReason>()
        .toList(),
  );
}

/// GET /social/nearby row.
class NearbyPerson {
  final PersonSummary person;

  /// Rounded; 0 means under a kilometre.
  final int distanceKm;

  const NearbyPerson({required this.person, required this.distanceKm});

  factory NearbyPerson.fromJson(Map<String, dynamic> json) =>
      NearbyPerson(person: PersonSummary.fromJson(json), distanceKm: int.parse((json['distance_km'] ?? 0).toString()));
}

/// Incoming friend request row (has a mutual friend count).
class FriendRequest {
  final PersonSummary person;
  final int mutualCount;
  final DateTime? createdAt;

  const FriendRequest({required this.person, this.mutualCount = 0, this.createdAt});

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    person: PersonSummary.fromJson(json),
    mutualCount: int.parse((json['mutual_count'] ?? 0).toString()),
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
  );
}

/// Counts for nav badges (GET /social/badges).
class SocialBadges {
  final int followRequests;
  final int friendRequests;
  final int unreadConversations;
  final int messageRequests;
  final int unreadNotifications;

  const SocialBadges({
    this.followRequests = 0,
    this.friendRequests = 0,
    this.unreadConversations = 0,
    this.messageRequests = 0,
    this.unreadNotifications = 0,
  });

  int get requests => followRequests + friendRequests;

  factory SocialBadges.fromJson(Map<String, dynamic> json) {
    int n(String k) => int.parse((json[k] ?? 0).toString());
    return SocialBadges(
      followRequests: n('follow_requests'),
      friendRequests: n('friend_requests'),
      unreadConversations: n('unread_conversations'),
      messageRequests: n('message_requests'),
      unreadNotifications: n('unread_notifications'),
    );
  }
}

enum ReportReason {
  spam('spam'),
  harassment('harassment'),
  inappropriate('inappropriate'),
  impersonation('impersonation'),
  other('other');

  const ReportReason(this.apiValue);
  final String apiValue;
}
