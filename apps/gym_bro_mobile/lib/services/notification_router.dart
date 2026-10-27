import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/user_profile.dart';
import '../pages/chat/chat_launcher.dart';
import '../pages/classes/class_detail_page.dart';
import '../pages/feed/post_detail_page.dart';
import '../pages/classes/my_shifts_page.dart';
import '../pages/gym_detail_page.dart';
import '../pages/meal_plans_page.dart';
import '../pages/membership_page.dart';
import '../pages/notifications_page.dart';
import '../pages/people/requests_page.dart';
import '../pages/people/user_profile_page.dart';
import '../pages/posts_page.dart';
import '../pages/routine_detail_page.dart';
import '../pages/session_detail_page.dart';
import '../pages/shop/order_detail_page.dart';
import '../pages/shop/storefront_page.dart';
import '../pages/shop/storefront_shop_page.dart';
import '../pages/shop_detail_page.dart';
import 'api_service.dart';
import 'auth_manager.dart';

/// Opens the screen a notification refers to. Shared by the notifications
/// list and push-notification taps (foreground, background and cold start).
///
/// Invites are not handled here: the notifications list opens its own
/// accept/decline page, and a push tap on an invite opens the list.
class NotificationRouter {
  NotificationRouter._();

  /// [type] is the API's `notification_type` value (e.g. `class_reminder`),
  /// [metadata] the notification's metadata. Unknown types and notifications
  /// without a target do nothing.
  static Future<void> open(
    BuildContext context,
    String type,
    Map<String, dynamic> metadata,
  ) async {
    final profile = AuthManager.instance.profile;
    if (profile == null) return;
    final nav = Navigator.of(context);
    final l10n = context.l10n;

    Future<void> push(Widget page) =>
        nav.push<void>(MaterialPageRoute(builder: (_) => page));

    String? str(String key) {
      final v = metadata[key];
      return v == null || v.toString().isEmpty ? null : v.toString();
    }

    switch (type) {
      case 'employee_gym_invite':
      case 'vendor_shop_invite':
      case 'member_invite':
        await push(const NotificationsPage());

      case 'class_reminder':
      case 'events':
        final classId = str('class_id');
        if (classId != null) await push(ClassDetailPage(classId: classId));

      case 'shift_assigned':
        await push(const MyShiftsPage());

      case 'order_update':
      case 'purchase_made':
        final orderId = str('order_id');
        if (orderId != null) await push(OrderDetailPage(orderId: orderId));

      case 'payment_received':
        final orderId = str('order_id');
        if (orderId != null) {
          await push(OrderDetailPage(orderId: orderId));
        } else {
          await push(_membershipScreen(profile, l10n));
        }

      case 'membership_expiring':
      case 'invoice_issued':
      case 'member_subscription_extended':
        await push(_membershipScreen(profile, l10n));

      // Comments, replies and reactions open the post itself (scrolled to
      // the comment); gym news opens the business feed.
      case 'post_comment' || 'comment_reply' || 'post_reaction' when str('post_id') != null:
        await push(PostDetailPage(postId: str('post_id')!, focusCommentId: str('comment_id')));

      case 'follow_request' || 'friend_request':
        await push(const RequestsPage());

      case 'follow' || 'follow_accepted' || 'friend_accepted':
        final userId = str('user_id');
        if (userId != null) await push(UserProfilePage(userId: userId));

      case 'chat_message' || 'group_added':
        final conversationId = str('conversation_id');
        if (conversationId != null && context.mounted) await openConversation(context, conversationId);

      case 'news':
      case 'post_comment':
        final businessId =
            str('business_id') ?? str('gym_id') ?? str('shop_id');
        if (businessId == null) return;
        var name = str('business_name') ?? str('gym_name') ?? str('shop_name');
        if (name == null) {
          try {
            final token = await AuthManager.instance.getValidToken();
            name = (await ApiService().getBusiness(token, businessId)).name;
          } catch (e) {
            if (context.mounted) _showError(context, e);
            return;
          }
        }
        await push(PostsPage(businessId: businessId, businessName: name));

      case 'session_comment':
        final sessionId = str('session_id');
        if (sessionId != null) {
          await push(SessionDetailPage(sessionId: sessionId));
        }

      case 'training':
        // Routine assigned by a coach; older "meal plan assigned" ones have no routine_id.
        final routineId = str('routine_id');
        await push(
          routineId != null
              ? RoutineDetailPage(routineId: routineId)
              : const MealPlansPage(),
        );

      case 'shop_item_update':
        final shopId = metadata['shop_id']?.toString();
        await push(
          shopId == null
              ? const StorefrontPage()
              : StorefrontShopPage(
                  shopId: shopId,
                  shopName:
                      metadata['shop_name']?.toString() ?? l10n.shellMuteShop,
                ),
        );

      case 'member_join':
      case 'employee_join':
      case 'vendor_join':
        if (!context.mounted) return;
        await _openManagedBusiness(context, type, metadata, profile);

      default:
        // Nothing to open: marking it read is enough.
        break;
    }
  }

  static Widget _membershipScreen(UserProfile profile, AppLocalizations l10n) =>
      Scaffold(
        appBar: AppBar(title: Text(l10n.shellTabMembership)),
        body: MembershipPage(profile: profile),
      );

  /// Opens the gym / shop from a *_join notification, but only when the
  /// current user manages that business.
  static Future<void> _openManagedBusiness(
    BuildContext context,
    String type,
    Map<String, dynamic> metadata,
    UserProfile profile,
  ) async {
    final gymId = metadata['gym_id'] as String?;
    final shopId = metadata['shop_id'] as String?;
    final isShop = type == 'vendor_join' || (gymId == null && shopId != null);
    final businessId =
        (isShop ? shopId : gymId) ?? metadata['business_id'] as String?;
    if (businessId == null) return;

    final api = ApiService();
    try {
      final token = await AuthManager.instance.getValidToken();
      if (profile.role != UserRole.superUser) {
        final rows = isShop
            ? await api.getShopOwners(token, userId: profile.id)
            : await api.getGymOwners(token, userId: profile.id);
        final key = isShop ? 'shop_id' : 'gym_id';
        if (!rows.any((r) => r[key] == businessId)) return;
      }
      final name =
          (metadata['gym_name'] ?? metadata['shop_name']) as String? ??
          (await api.getBusiness(token, businessId)).name;
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => isShop
              ? ShopDetailPage(shopId: businessId, shopName: name)
              : GymDetailPage(gymId: businessId, gymName: name),
        ),
      );
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  static void _showError(BuildContext context, Object e) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
  }
}
