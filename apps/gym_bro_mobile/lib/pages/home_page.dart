import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/people.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';
import 'home/home_menu_page.dart';
import '../widgets/offline_banner.dart';
import '../widgets/social_widgets.dart';
import 'home/home_widgets.dart';
import 'classes/class_schedule_page.dart';
import 'chat/chat_inbox_page.dart';
import 'feed/feed_page.dart';
import 'notifications_page.dart';
import 'people/discover_page.dart';
import 'gym_hub_page.dart';
import 'profile_page.dart';

// ── Nav tabs ──────────────────────────────────────────────────────────────────

/// One bottom-nav destination. Everyone gets the same five: Home is a menu
/// of what the user can do (built from what they are: member, trainer, on a
/// gym's or shop's team, admin), the rest are shared. Labels are resolved at
/// build time so they follow the app language.
enum _Tab {
  home(Icons.space_dashboard_outlined, Icons.space_dashboard),
  feed(Icons.dynamic_feed_outlined, Icons.dynamic_feed),
  discover(Icons.explore_outlined, Icons.explore),
  schedule(Icons.calendar_month_outlined, Icons.calendar_month),
  gym(Icons.fitness_center_outlined, Icons.fitness_center);

  const _Tab(this.icon, this.selectedIcon);

  final IconData icon;
  final IconData selectedIcon;

  String label(AppLocalizations l10n) => switch (this) {
    _Tab.home => l10n.shellTabHome,
    _Tab.feed => l10n.shellTabFeed,
    _Tab.discover => l10n.shellTabDiscover,
    _Tab.schedule => l10n.shellTabSchedule,
    _Tab.gym => l10n.shellTabGym,
  };
}

// ── HomePage shell ────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();
  final _api = ApiService();

  int _tabIndex = 0;
  UserProfile? _profile;
  bool _loading = true;
  String? _error;
  int _unreadNotifications = 0;
  SocialBadges _badges = const SocialBadges();
  StreamSubscription<UserEvent>? _realtimeSub;
  Timer? _badgeDebounce;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Live badges: any inbox, notification or relationship event refreshes them.
    _realtimeSub = RealtimeService.instance.userEvents.listen((_) {
      _badgeDebounce?.cancel();
      _badgeDebounce = Timer(const Duration(milliseconds: 400), () {
        final profile = _profile;
        if (profile != null && mounted) _refreshUnreadCount(profile.id);
      });
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _badgeDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    // Show the cached profile immediately to avoid a loading spinner, but
    // always fetch fresh from the API so what the user can do is never stale.
    final cached = AuthManager.instance.profile;
    if (cached != null) {
      setState(() {
        _profile = cached;
        _loading = false;
      });
      _refreshUnreadCount(cached.id);
    }
    try {
      final token = await AuthManager.instance.getValidToken();
      final data = await _authService.testEndpoint(token);
      final profileData = data['profile'] as Map<String, dynamic>?;
      if (profileData == null) {
        if (!mounted) return;
        throw Exception(context.l10n.shellHomeProfileLoadFailed);
      }
      final fresh = UserProfile.fromJson(profileData);
      await AuthManager.instance.updateProfile(fresh);
      if (mounted) {
        setState(() {
          _profile = fresh;
          _loading = false;
          _error = null;
        });
        _refreshUnreadCount(fresh.id);
      }
    } catch (e) {
      if (mounted && _profile == null) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshUnreadCount(String userId) async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final page = await _api.getNotifications(
        token,
        userId: userId,
        page: 0,
        pageSize: 1,
      );
      if (mounted) setState(() => _unreadNotifications = page.unreadCount);
    } catch (_) {}
    try {
      final token = await AuthManager.instance.getValidToken();
      final badges = await _api.getSocialBadges(token);
      if (mounted) setState(() => _badges = badges);
    } catch (_) {}
    unawaited(RealtimeService.instance.connect());
  }

  Future<void> _openChats() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const ChatInboxPage()),
    );
    final profile = _profile;
    if (profile != null && mounted) _refreshUnreadCount(profile.id);
  }

  Future<void> _openNotifications() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
    // Refresh badge when returning from notifications
    final profile = _profile;
    if (profile != null && mounted) _refreshUnreadCount(profile.id);
  }

  Future<void> _openProfile() async {
    await pushTabPage<void>(
      context,
      context.l10n.shellTabProfile,
      ProfilePage(
        profile: _profile!,
        onUpdated: (updated) => setState(() => _profile = updated),
      ),
    );
    final profile = _profile;
    if (profile != null && mounted) _refreshUnreadCount(profile.id);
  }

  /// Logs out, or (while impersonating) returns to the admin's account.
  Future<void> _logout() async {
    final stillSignedIn = await AuthManager.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      stillSignedIn ? '/home' : '/signup',
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            semanticsLabel: context.l10n.commonLoading,
          ),
        ),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(_error ?? context.l10n.shellHomeProfileLoadFailed),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _logout,
                  child: Text(context.l10n.shellHomeBackToLogin),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final l10n = context.l10n;
    final profile = _profile!;
    const tabs = _Tab.values;
    final badges = _badges.requests;

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[_tabIndex].label(l10n)),
        actions: [
          _BadgeIconButton(
            icon: Icons.chat_bubble_outline,
            count: _badges.unreadConversations + _badges.messageRequests,
            tooltip: _badges.unreadConversations + _badges.messageRequests > 0
                ? l10n.shellChatsUnread(
                    _badges.unreadConversations + _badges.messageRequests,
                  )
                : l10n.shellChats,
            onPressed: _openChats,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: _unreadNotifications > 0
                    ? l10n.shellHomeNotificationsUnread(_unreadNotifications)
                    : l10n.shellHomeNotifications,
                onPressed: _openNotifications,
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  // The count is already in the button's tooltip.
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          _unreadNotifications > 99
                              ? '99+'
                              : '$_unreadNotifications',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onError,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: l10n.shellTabProfile,
            onPressed: _openProfile,
            icon: UserAvatar(
              url: profile.avatarUrl,
              initials: _initials(profile),
              radius: 14,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (AuthManager.instance.isImpersonating)
            _ImpersonationBanner(name: profile.fullName, onReturn: _logout),
          const OfflineBanner(),
          Expanded(child: _buildBody(profile, _tabIndex)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          // Coming back to Home picks up new roles, invites and reviews.
          if (tabs[i] == _Tab.home && _tabIndex != i) _loadProfile();
          setState(() => _tabIndex = i);
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: _tabIcon(tab, tab.icon, profile, badges),
              selectedIcon: _tabIcon(tab, tab.selectedIcon, profile, badges),
              label: tab.label(l10n),
              tooltip: tab.label(l10n),
            ),
        ],
      ),
    );
  }

  /// Home shows open team invites; Discover, follow and friend requests.
  Widget _tabIcon(_Tab tab, IconData icon, UserProfile profile, int requests) {
    final count = switch (tab) {
      _Tab.home => profile.pendingInvites,
      _Tab.discover => requests,
      _ => 0,
    };
    if (count == 0) return Icon(icon);
    return Badge(
      label: ExcludeSemantics(child: Text(count > 99 ? '99+' : '$count')),
      child: Icon(icon),
    );
  }

  Widget _buildBody(UserProfile profile, int index) {
    return switch (_Tab.values[index]) {
      _Tab.home => HomeMenuPage(
        profile: profile,
        onProfileChanged: (updated) async {
          await AuthManager.instance.updateProfile(updated);
          if (mounted) setState(() => _profile = updated);
        },
        onRefresh: _loadProfile,
      ),
      _Tab.feed => const FeedPage(),
      _Tab.discover => const DiscoverPage(),
      _Tab.schedule => const ClassSchedulePage(),
      _Tab.gym => GymHubPage(profile: profile),
    };
  }
}

String _initials(UserProfile p) {
  final initials =
      '${p.name.isNotEmpty ? p.name[0] : ''}${p.lastName.isNotEmpty ? p.lastName[0] : ''}'
          .toUpperCase();
  return initials.isEmpty ? '?' : initials;
}

/// App bar icon with a small count badge (hidden at zero).
class _BadgeIconButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final String tooltip;
  final VoidCallback onPressed;

  const _BadgeIconButton({
    required this.icon,
    required this.count,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        // The count is already in the tooltip.
        label: ExcludeSemantics(child: Text(count > 99 ? '99+' : '$count')),
        child: Icon(icon),
      ),
    );
  }
}

/// Persistent strip shown while a super user is signed in as someone else.
class _ImpersonationBanner extends StatelessWidget {
  const _ImpersonationBanner({required this.name, required this.onReturn});

  final String name;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.tertiaryContainer,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 20,
                color: cs.onTertiaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.shellHomeViewingAs(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: cs.onTertiaryContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: onReturn,
                style: TextButton.styleFrom(
                  foregroundColor: cs.onTertiaryContainer,
                ),
                child: Text(context.l10n.shellHomeReturnToAdmin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
