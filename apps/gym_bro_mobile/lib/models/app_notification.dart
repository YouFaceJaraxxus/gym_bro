import 'business.dart';

enum NotificationType {
  /// Invited to a gym's or shop's team (metadata: business_id, role).
  businessInvite('business_invite'),
  memberInvite('member_invite'),
  news('news'),
  events('events'),
  training('training'),
  trainingUpdate('training_update'),
  classReminder('class_reminder'),
  shopItemUpdate('shop_item_update'),
  purchaseMade('purchase_made'),
  membershipExpiring('membership_expiring'),
  invoiceIssued('invoice_issued'),
  memberSubscriptionExtended('member_subscription_extended'),
  memberJoin('member_join'),

  /// Someone accepted an invite to my business's team.
  businessJoin('business_join'),

  /// A super user approved, rejected or blocked my business.
  businessReview('business_review'),
  postComment('post_comment'),
  shiftAssigned('shift_assigned'),
  orderUpdate('order_update'),
  paymentReceived('payment_received'),
  sessionComment('session_comment'),
  follow('follow'),
  followRequest('follow_request'),
  followAccepted('follow_accepted'),
  friendRequest('friend_request'),
  friendAccepted('friend_accepted'),
  chatMessage('chat_message'),
  groupAdded('group_added'),
  postReaction('post_reaction'),
  commentReply('comment_reply'),

  /// Someone @mentioned me (or a business/product I own) in a post or comment.
  mention('mention'),

  /// Someone tagged me on a photo.
  photoTag('photo_tag'),

  /// Someone liked / reacted to my story.
  storyReaction('story_reaction'),

  /// Someone @mentioned me in their story.
  storyMention('story_mention');

  const NotificationType(this.apiValue);

  /// The `notification_type` enum value on the API side.
  final String apiValue;

  /// Unknown values (from a newer API) fall back to [news].
  static NotificationType fromString(String s) =>
      tryParse(s) ?? NotificationType.news;

  static NotificationType? tryParse(String s) {
    for (final t in values) {
      if (t.apiValue == s) return t;
    }
    return null;
  }

  bool get isInvite => this == businessInvite || this == memberInvite;
}

enum InviteStatus { pending, accepted, declined }

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String? body;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.metadata,
    required this.isRead,
    required this.createdAt,
  });

  InviteStatus? get inviteStatus {
    if (!type.isInvite) return null;
    return switch (metadata?['invite_status'] as String?) {
      'pending' => InviteStatus.pending,
      'accepted' => InviteStatus.accepted,
      'declined' => InviteStatus.declined,
      _ => null,
    };
  }

  String? get gymId => metadata?['gym_id'] as String?;
  String? get shopId => metadata?['shop_id'] as String?;

  /// The business a team invite, join or review is about.
  String? get businessId =>
      (metadata?['business_id'] ?? metadata?['gym_id'] ?? metadata?['shop_id'])
          as String?;
  String? get entityName =>
      (metadata?['business_name'] ??
              metadata?['gym_name'] ??
              metadata?['shop_name'])
          as String?;

  /// The role a team invite offers.
  BusinessRole? get businessRole =>
      BusinessRole.tryParse(metadata?['role'] as String?);

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        type: NotificationType.fromString(json['type'] as String? ?? ''),
        title: json['title'] as String,
        body: json['body'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class NotificationPage {
  final List<AppNotification> items;
  final int unreadCount;

  const NotificationPage({required this.items, required this.unreadCount});

  factory NotificationPage.fromJson(Map<String, dynamic> json) =>
      NotificationPage(
        items: (json['items'] as List? ?? [])
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList(),
        unreadCount: json['unread_count'] as int? ?? 0,
      );
}
