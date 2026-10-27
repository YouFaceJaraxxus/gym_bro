import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/people.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/social_widgets.dart';
import 'people/blocked_users_page.dart';
import 'people/edit_social_profile_page.dart';
import 'people/people_list_page.dart';
import 'people/requests_page.dart';
import 'people/user_profile_page.dart';
import 'progress/progress_page.dart';
import 'settings_page.dart';
import 'shop/my_orders_page.dart';

/// The "Profile" tab: my social card (avatar, bio, counts), requests and
/// privacy, then progress, orders, settings and log out. Names, username and
/// avatar are edited in [EditSocialProfilePage].
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.profile, this.onUpdated});

  final UserProfile profile;
  final void Function(UserProfile updated)? onUpdated;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _api = ApiService();
  late UserProfile _profile;
  PublicProfile? _social;
  SocialBadges? _badges;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _load();
  }

  @override
  void didUpdateWidget(ProfilePage old) {
    super.didUpdateWidget(old);
    if (!identical(old.profile, widget.profile)) _profile = widget.profile;
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait([_api.getMyProfile(token), _api.getSocialBadges(token)]);
      if (!mounted) return;
      setState(() {
        _social = results[0] as PublicProfile;
        _badges = results[1] as SocialBadges;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// After editing: pick up the new name/username/avatar and counts.
  Future<void> _afterEdit() async {
    final me = AuthManager.instance.profile;
    if (me != null && mounted) {
      setState(() => _profile = me);
      widget.onUpdated?.call(me);
    }
    await _load();
  }

  Future<void> _logout() async {
    // While impersonating, logging out returns to the admin's own account.
    final stillSignedIn = await AuthManager.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      stillSignedIn ? '/home' : '/signup',
      (_) => false,
    );
  }

  Future<void> _open(Widget page, {bool reload = false}) async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page));
    if (reload && mounted) await _afterEdit();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final requests = _badges?.requests ?? 0;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SocialHeaderCard(
              profile: _profile,
              social: _social,
              error: _error,
              onRetry: _load,
              onView: () => _open(UserProfilePage(userId: _profile.id), reload: true),
              onEdit: () => _open(const EditSocialProfilePage(), reload: true),
              onOpenList: (tab) => _open(
                PeopleListPage(userId: _profile.id, initialTab: tab, title: '@${_profile.username}'),
                reload: true,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Badge(
                isLabelVisible: requests > 0,
                label: Text('$requests'),
                child: const Icon(Icons.person_add_alt_1_outlined),
              ),
              title: Text(l10n.peopleRequestsTitle),
              subtitle: Text(l10n.peopleRequestsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(
                RequestsPage(initialTab: (_badges?.followRequests ?? 0) == 0 && (_badges?.friendRequests ?? 0) > 0 ? 1 : 0),
                reload: true,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(l10n.peoplePrivacy),
              subtitle: Text(l10n.peoplePrivacySubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(const EditSocialProfilePage(scrollToPrivacy: true), reload: true),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(l10n.peopleBlockedUsers),
              subtitle: Text(l10n.peopleBlockedUsersSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(const BlockedUsersPage(), reload: true),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: Text(l10n.shellMyProgress),
              subtitle: Text(l10n.shellMyProgressSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(const ProgressPage()),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l10n.shellMyOrders),
              subtitle: Text(l10n.shellMyOrdersSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(const MyOrdersPage()),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.shellSettings),
              subtitle: Text(l10n.shellSettingsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(const SettingsPage()),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: cs.error),
              title: Text(
                AuthManager.instance.isImpersonating
                    ? l10n.shellHomeReturnToAdmin
                    : l10n.shellHomeLogOut,
                style: TextStyle(color: cs.error),
              ),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact social card: avatar, name, @username, bio snippet, counts and
/// View / Edit profile.
class _SocialHeaderCard extends StatelessWidget {
  const _SocialHeaderCard({
    required this.profile,
    required this.social,
    required this.error,
    required this.onRetry,
    required this.onView,
    required this.onEdit,
    required this.onOpenList,
  });

  final UserProfile profile;
  final PublicProfile? social;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final void Function(PeopleListTab tab) onOpenList;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final s = social;
    final initials = '${profile.name.isNotEmpty ? profile.name[0] : ''}${profile.lastName.isNotEmpty ? profile.lastName[0] : ''}'
        .toUpperCase();
    final bio = s?.bio?.trim() ?? '';

    Widget count(int? value, String label, PeopleListTab? tab) => Expanded(
      child: Semantics(
        button: tab != null,
        label: '${value ?? 0} $label',
        excludeSemantics: true,
        child: InkWell(
          onTap: tab == null ? null : () => onOpenList(tab),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Text(value == null ? '–' : '$value', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onView,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  UserAvatar(url: profile.avatarUrl, initials: initials.isEmpty ? '?' : initials, radius: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '@${profile.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                profile.role.label(l10n),
                                style: text.labelSmall?.copyWith(color: cs.onSecondaryContainer),
                              ),
                            ),
                            if (s?.isPrivate ?? false)
                              Icon(Icons.lock_outline, size: 14, color: cs.onSurfaceVariant, semanticLabel: l10n.peopleLocked),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(bio, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
            ],
            const SizedBox(height: 8),
            if (error != null && s == null)
              Row(
                children: [
                  Expanded(
                    child: Text(error!, style: text.bodySmall?.copyWith(color: cs.error), maxLines: 2),
                  ),
                  TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
                ],
              )
            else
              Row(
                children: [
                  count(s?.counts.posts, l10n.peoplePosts, null),
                  count(s?.counts.followers, l10n.peopleFollowers, s == null ? null : PeopleListTab.followers),
                  count(s?.counts.following, l10n.peopleFollowing, s == null ? null : PeopleListTab.following),
                  count(s?.counts.friends, l10n.peopleFriends, s == null ? null : PeopleListTab.friends),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: onView,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    child: Text(l10n.peopleViewProfile),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    child: Text(l10n.peopleEditProfile),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
