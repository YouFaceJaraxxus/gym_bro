import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../services/notification_router.dart';
import 'invite_accept_page.dart';

const _kPageSize = 20;

class _CacheEntry {
  final List<AppNotification> items;
  final bool hasMore;
  final int pagesLoaded;

  const _CacheEntry({
    required this.items,
    required this.hasMore,
    required this.pagesLoaded,
  });

  _CacheEntry copyWith({
    List<AppNotification>? items,
    bool? hasMore,
    int? pagesLoaded,
  }) => _CacheEntry(
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    pagesLoaded: pagesLoaded ?? this.pagesLoaded,
  );
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _api = ApiService();

  _CacheEntry? _cache;
  int _unreadCount = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _cache = null;
        _loading = true;
        _error = null;
      });
    }
    try {
      final token = await AuthManager.instance.getValidToken();
      final profile = AuthManager.instance.profile;
      if (profile == null) {
        if (!mounted) return;
        throw Exception(context.l10n.shellHomeProfileLoadFailed);
      }

      final page = await _api.getNotifications(
        token,
        userId: profile.id,
        page: 0,
        pageSize: _kPageSize,
      );
      if (!mounted) return;
      setState(() {
        _cache = _CacheEntry(
          items: page.items,
          hasMore: page.items.length >= _kPageSize,
          pagesLoaded: 1,
        );
        _unreadCount = page.unreadCount;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    final cached = _cache;
    if (cached == null || !cached.hasMore || _loadingMore) return;

    setState(() => _loadingMore = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final profile = AuthManager.instance.profile!;

      final page = await _api.getNotifications(
        token,
        userId: profile.id,
        page: cached.pagesLoaded,
        pageSize: _kPageSize,
      );
      if (!mounted) return;
      setState(() {
        _cache = cached.copyWith(
          items: [...cached.items, ...page.items],
          hasMore: page.items.length >= _kPageSize,
          pagesLoaded: cached.pagesLoaded + 1,
        );
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.markAllNotificationsRead(token);
      if (!mounted) return;
      setState(() {
        final updated = _cache?.items
            .map(
              (n) => AppNotification(
                id: n.id,
                userId: n.userId,
                type: n.type,
                title: n.title,
                body: n.body,
                metadata: n.metadata,
                isRead: true,
                createdAt: n.createdAt,
              ),
            )
            .toList();
        if (updated != null) {
          _cache = _cache?.copyWith(items: updated);
        }
        _unreadCount = 0;
      });
    } catch (_) {}
  }

  Future<void> _openNotification(AppNotification notif) async {
    if (!notif.isRead) {
      try {
        final token = await AuthManager.instance.getValidToken();
        await _api.markNotificationRead(token, notif.id);
        if (!mounted) return;
        _replaceItem(notif.id, isRead: true);
      } catch (_) {}
    }

    if (!mounted) return;

    if (notif.type.isInvite && notif.inviteStatus == InviteStatus.pending) {
      final accepted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => InviteAcceptPage(notification: notif),
        ),
      );
      if (accepted != null && mounted) {
        // Refresh to get updated invite_status in metadata
        _load(refresh: true);
      }
    } else if (notif.type.isInvite) {
      // Already acted on — show read-only invite page
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => InviteAcceptPage(notification: notif),
        ),
      );
    } else {
      await _navigateFor(notif);
    }
  }

  /// Opens the screen a non-invite notification refers to, if any.
  Future<void> _navigateFor(AppNotification notif) => NotificationRouter.open(
    context,
    notif.type.apiValue,
    notif.metadata ?? const {},
  );

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> _delete(AppNotification notif) async {
    final cached = _cache;
    if (cached == null) return;
    final index = cached.items.indexWhere((n) => n.id == notif.id);
    if (index < 0) return;

    // Optimistically remove; restore on failure.
    setState(() {
      _cache = cached.copyWith(items: [...cached.items]..removeAt(index));
      if (!notif.isRead && _unreadCount > 0) _unreadCount--;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteNotification(token, notif.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final items = [...?_cache?.items];
        items.insert(index.clamp(0, items.length), notif);
        _cache = _cache?.copyWith(items: items);
        if (!notif.isRead) _unreadCount++;
      });
      _showError(e);
    }
  }

  void _replaceItem(String id, {bool? isRead}) {
    final updated = _cache?.items.map((n) {
      if (n.id != id) return n;
      return AppNotification(
        id: n.id,
        userId: n.userId,
        type: n.type,
        title: n.title,
        body: n.body,
        metadata: n.metadata,
        isRead: isRead ?? n.isRead,
        createdAt: n.createdAt,
      );
    }).toList();
    if (updated != null) {
      final wasUnread = _cache!.items.any((n) => n.id == id && !n.isRead);
      setState(() {
        _cache = _cache!.copyWith(items: updated);
        if (wasUnread && isRead == true && _unreadCount > 0) {
          _unreadCount--;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shellHomeNotifications),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(l10n.shellMarkAllRead),
            ),
        ],
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    final l10n = context.l10n;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _load(refresh: true),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    final items = _cache?.items ?? [];

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 56,
              color: cs.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.shellNoNotifications,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: cs.outline),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView.builder(
        itemCount: items.length + (_cache?.hasMore == true ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _loadingMore
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: l10n.commonLoading,
                      ),
                    )
                  : Center(
                      child: OutlinedButton(
                        onPressed: _loadMore,
                        child: Text(l10n.shellLoadMore),
                      ),
                    ),
            );
          }
          final notif = items[index];
          return Dismissible(
            key: ValueKey(notif.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: cs.errorContainer,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
            ),
            onDismissed: (_) => _delete(notif),
            // Swipe-to-delete isn't reachable with a screen reader.
            child: Semantics(
              customSemanticsActions: {
                CustomSemanticsAction(label: l10n.commonDelete): () =>
                    _delete(notif),
              },
              child: _NotificationTile(
                notification: notif,
                onTap: () => _openNotification(notif),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final l10n = context.l10n;

    final icon = _iconFor(n.type);
    final color = _colorFor(n, cs);
    final isInvitePending =
        n.type.isInvite && n.inviteStatus == InviteStatus.pending;

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Container(
            color: n.isRead
                ? null
                : cs.primaryContainer.withValues(alpha: 0.18),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: ts.bodyMedium?.copyWith(
                                fontWeight: n.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            _timeAgo(context, n.createdAt),
                            semanticsLabel: _timeAgoSemantics(
                              context,
                              n.createdAt,
                            ),
                            style: ts.bodySmall?.copyWith(color: cs.outline),
                          ),
                        ],
                      ),
                      if (n.body != null && n.body!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          n.body!,
                          style: ts.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (isInvitePending) ...[
                        const SizedBox(height: 6),
                        Chip(
                          label: Text(l10n.shellInvitePending),
                          avatar: const Icon(Icons.pending_outlined, size: 14),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          backgroundColor: cs.secondaryContainer,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                      ] else if (n.type.isInvite) ...[
                        const SizedBox(height: 6),
                        Chip(
                          label: Text(
                            n.inviteStatus == InviteStatus.accepted
                                ? l10n.shellInviteAccepted
                                : l10n.shellInviteDeclinedChip,
                          ),
                          avatar: Icon(
                            n.inviteStatus == InviteStatus.accepted
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            size: 14,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          backgroundColor:
                              n.inviteStatus == InviteStatus.accepted
                              ? cs.primaryContainer
                              : cs.errorContainer,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: n.inviteStatus == InviteStatus.accepted
                                ? cs.onPrimaryContainer
                                : cs.onErrorContainer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!n.isRead) ...[
                  const SizedBox(width: 8),
                  Semantics(
                    label: l10n.shellNotificationUnread,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(NotificationType t) => switch (t) {
    NotificationType.employeeGymInvite => Icons.fitness_center_outlined,
    NotificationType.vendorShopInvite => Icons.storefront_outlined,
    NotificationType.memberInvite => Icons.person_add_alt_outlined,
    NotificationType.news => Icons.newspaper_outlined,
    NotificationType.events => Icons.event_outlined,
    NotificationType.training => Icons.sports_outlined,
    NotificationType.trainingUpdate => Icons.update_outlined,
    NotificationType.classReminder => Icons.alarm_outlined,
    NotificationType.shopItemUpdate => Icons.inventory_2_outlined,
    NotificationType.purchaseMade => Icons.receipt_outlined,
    NotificationType.membershipExpiring => Icons.warning_amber_outlined,
    NotificationType.invoiceIssued => Icons.description_outlined,
    NotificationType.memberSubscriptionExtended =>
      Icons.card_membership_outlined,
    NotificationType.memberJoin => Icons.person_outlined,
    NotificationType.employeeJoin => Icons.badge_outlined,
    NotificationType.vendorJoin => Icons.storefront_outlined,
    NotificationType.postComment => Icons.chat_bubble_outline,
    NotificationType.shiftAssigned => Icons.schedule_outlined,
    NotificationType.orderUpdate => Icons.local_shipping_outlined,
    NotificationType.paymentReceived => Icons.payments_outlined,
    NotificationType.sessionComment => Icons.comment_outlined,
  };

  Color _colorFor(AppNotification n, ColorScheme cs) {
    if (n.type == NotificationType.membershipExpiring) return cs.error;
    if (n.type.isInvite) return cs.primary;
    if (n.type == NotificationType.purchaseMade ||
        n.type == NotificationType.orderUpdate ||
        n.type == NotificationType.paymentReceived) {
      return cs.tertiary;
    }
    return cs.secondary;
  }

  String _timeAgo(BuildContext context, DateTime dt) {
    final l10n = context.l10n;
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return l10n.shellTimeNow;
    if (diff.inMinutes < 60) return l10n.shellTimeMinutesShort(diff.inMinutes);
    if (diff.inHours < 24) return l10n.shellTimeHoursShort(diff.inHours);
    if (diff.inDays < 7) return l10n.shellTimeDaysShort(diff.inDays);
    return DateFormat.MMMd(
      Localizations.localeOf(context).toString(),
    ).format(dt.toLocal());
  }

  /// Spelled-out version of [_timeAgo] for screen readers.
  String _timeAgoSemantics(BuildContext context, DateTime dt) {
    final l10n = context.l10n;
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return l10n.shellTimeNow;
    if (diff.inMinutes < 60) return l10n.shellTimeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.shellTimeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.shellTimeDaysAgo(diff.inDays);
    return _timeAgo(context, dt);
  }
}
