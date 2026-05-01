import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
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
  }) =>
      _CacheEntry(
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
      if (profile == null) throw Exception('No profile');

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
            .map((n) => AppNotification(
                  id: n.id,
                  userId: n.userId,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  metadata: n.metadata,
                  isRead: true,
                  createdAt: n.createdAt,
                ))
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
    }
    // Other notification types: just marking read is enough for now
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
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
                  child: const Text('Retry')),
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
            Icon(Icons.notifications_none_outlined,
                size: 56, color: cs.outline),
            const SizedBox(height: 16),
            Text('No notifications yet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: cs.outline)),
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
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Center(
                      child: OutlinedButton(
                          onPressed: _loadMore,
                          child: const Text('Load more'))),
            );
          }
          return _NotificationTile(
            notification: items[index],
            onTap: () => _openNotification(items[index]),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final icon = _iconFor(n.type);
    final color = _colorFor(n, cs);
    final isInvitePending =
        n.type.isInvite && n.inviteStatus == InviteStatus.pending;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: n.isRead ? null : cs.primaryContainer.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
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
                        _timeAgo(n.createdAt),
                        style: ts.bodySmall?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                  if (n.body != null && n.body!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.body!,
                      style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (isInvitePending) ...[
                    const SizedBox(height: 6),
                    Chip(
                      label: const Text('Pending response'),
                      avatar: const Icon(Icons.pending_outlined, size: 14),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      backgroundColor: cs.secondaryContainer,
                      labelStyle: TextStyle(
                          fontSize: 11, color: cs.onSecondaryContainer),
                    ),
                  ] else if (n.type.isInvite) ...[
                    const SizedBox(height: 6),
                    Chip(
                      label: Text(
                        n.inviteStatus == InviteStatus.accepted
                            ? 'Accepted'
                            : 'Declined',
                      ),
                      avatar: Icon(
                        n.inviteStatus == InviteStatus.accepted
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        size: 14,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      backgroundColor: n.inviteStatus == InviteStatus.accepted
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
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
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
      };

  Color _colorFor(AppNotification n, ColorScheme cs) {
    if (n.type == NotificationType.membershipExpiring) return cs.error;
    if (n.type.isInvite) return cs.primary;
    if (n.type == NotificationType.purchaseMade) return cs.tertiary;
    return cs.secondary;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}
