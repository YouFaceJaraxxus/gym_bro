enum NotificationType {
  employeeGymInvite,
  vendorShopInvite,
  memberInvite,
  news,
  events,
  training,
  trainingUpdate,
  classReminder,
  shopItemUpdate,
  purchaseMade,
  membershipExpiring,
  invoiceIssued,
  memberSubscriptionExtended,
  memberJoin,
  employeeJoin,
  vendorJoin;

  static NotificationType fromString(String s) => switch (s) {
        'employee_gym_invite' => employeeGymInvite,
        'vendor_shop_invite' => vendorShopInvite,
        'member_invite' => memberInvite,
        'news' => news,
        'events' => events,
        'training' => training,
        'training_update' => trainingUpdate,
        'class_reminder' => classReminder,
        'shop_item_update' => shopItemUpdate,
        'purchase_made' => purchaseMade,
        'membership_expiring' => membershipExpiring,
        'invoice_issued' => invoiceIssued,
        'member_subscription_extended' => memberSubscriptionExtended,
        'member_join' => memberJoin,
        'employee_join' => employeeJoin,
        'vendor_join' => vendorJoin,
        _ => news,
      };

  bool get isInvite =>
      this == employeeGymInvite ||
      this == vendorShopInvite ||
      this == memberInvite;
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
  String? get entityName =>
      (metadata?['gym_name'] ?? metadata?['shop_name']) as String?;
  String? get employeeType => metadata?['employee_type'] as String?;

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
