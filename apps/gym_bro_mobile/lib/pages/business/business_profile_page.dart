import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/open_url.dart';
import '../../widgets/person_tile.dart';
import '../../widgets/post_card.dart';
import '../../widgets/social_widgets.dart';
import '../posts_page.dart';
import '../shop/buy_membership_page.dart';
import '../shop/storefront_shop_page.dart';
import 'business_manage_page.dart';
import 'business_widgets.dart';

/// A gym's or shop's public profile: who runs it, where and when it's open,
/// memberships and products, and its posts. Anyone can follow it; its team
/// gets a Manage button, and someone invited to it can answer from here.
class BusinessProfilePage extends StatefulWidget {
  const BusinessProfilePage({super.key, required this.businessId});

  final String businessId;

  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  final _api = ApiService();

  Business? _business;
  List<Post> _posts = [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final business = await _api.getBusiness(token, widget.businessId);
      final posts = business.isApproved
          ? await _api.getPosts(token, businessId: business.id, pageSize: 5)
          : <Post>[];
      if (!mounted) return;
      setState(() {
        _business = business;
        _posts = posts;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _run(Future<void> Function(String token) action) async {
    setState(() => _busy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await action(token);
      await _load();
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFollow() async {
    final b = _business!;
    await _run((token) async {
      await _api.setFollowingBusiness(token, b.id, follow: !b.isFollowing);
    });
  }

  Future<void> _answer(BusinessRole role, bool accept) async {
    await _run((token) async {
      await _api.answerBusinessInvite(token, _business!.id, role, accept: accept);
      // Joining changes what the user can do; keep the cached profile fresh.
      await AuthManager.instance.updateProfile(await _api.getMe(token));
    });
  }

  void _push(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final b = _business;
    return Scaffold(
      appBar: AppBar(
        title: Text(b?.name ?? ''),
        actions: [
          // The team manages it; super users can manage any business.
          if (b != null &&
              (b.onTeam || (AuthManager.instance.profile?.isSuperUser ?? false)))
            TextButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BusinessManagePage(businessId: b.id),
                  ),
                );
                _load();
              },
              icon: const Icon(Icons.tune),
              label: Text(l10n.rolesManage),
            ),
        ],
      ),
      body: _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : b == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _Header(
                    business: b,
                    busy: _busy,
                    onFollow: b.isApproved ? _toggleFollow : null,
                  ),
                  for (final role in b.myInvites)
                    _InviteCard(
                      business: b,
                      role: role,
                      busy: _busy,
                      onAnswer: (accept) => _answer(role, accept),
                    ),
                  _InfoSection(business: b),
                  if (b.owners.isNotEmpty)
                    _PeopleSection(
                      title: l10n.rolesProfileOwners,
                      people: b.owners,
                    ),
                  if (b.trainers.isNotEmpty)
                    _PeopleSection(
                      title: l10n.rolesProfileTrainers,
                      people: b.trainers,
                    ),
                  if (b.isApproved && (b.hasGym || b.hasShop))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (b.hasGym)
                            FilledButton.tonalIcon(
                              onPressed: () => _push(
                                BuyMembershipPage(initialGymId: b.id),
                              ),
                              icon: const Icon(Icons.card_membership_outlined),
                              label: Text(l10n.rolesProfileMemberships),
                            ),
                          if (b.hasShop)
                            FilledButton.tonalIcon(
                              onPressed: () => _push(
                                StorefrontShopPage(shopId: b.id, shopName: b.name),
                              ),
                              icon: const Icon(Icons.shopping_bag_outlined),
                              label: Text(l10n.rolesProfileProducts),
                            ),
                        ],
                      ),
                    ),
                  if (b.isApproved) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.rolesProfilePosts,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _push(
                              PostsPage(
                                businessId: b.id,
                                businessName: b.name,
                                canPost: b.onTeam,
                              ),
                            ),
                            child: Text(l10n.rolesProfileAllPosts),
                          ),
                        ],
                      ),
                    ),
                    if (_posts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            l10n.nutritionNoPostsYet,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                      )
                    else
                      for (final post in _posts)
                        PostCard(
                          key: ValueKey(post.id),
                          post: post,
                          onChanged: (_) => _load(),
                          onDeleted: _load,
                        ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.business, required this.busy, this.onFollow});

  final Business business;
  final bool busy;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final b = business;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BusinessAvatar(
                logo: b.logo,
                hasGym: b.hasGym,
                hasShop: b.hasShop,
                radius: 40,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: b.name,
                        children: [
                          // Approved by Gym Bro's team: a real, verified business.
                          if (b.isApproved)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Tooltip(
                                  message: l10n.rolesVerified,
                                  child: Icon(Icons.verified, size: 20, color: cs.primary),
                                ),
                              ),
                            ),
                        ],
                      ),
                      style: text.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          businessKindLabel(l10n, b.hasGym, b.hasShop),
                          style: text.bodyMedium?.copyWith(color: cs.primary),
                        ),
                        BusinessStatusChip(status: b.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.rolesProfileFollowers(b.followerCount),
                      style: text.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((b.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(b.bio!, style: text.bodyMedium),
          ],
          if (b.myRoles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  l10n.rolesProfileYouAre,
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 6),
                Flexible(child: RoleChips(roles: b.myRoles)),
              ],
            ),
          ],
          if (onFollow != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: b.isFollowing
                  ? OutlinedButton(
                      onPressed: busy ? null : onFollow,
                      child: Text(l10n.rolesProfileFollowing),
                    )
                  : FilledButton(
                      onPressed: busy ? null : onFollow,
                      child: Text(l10n.rolesProfileFollow),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.business});

  final Business business;

  String _hours(BuildContext context) {
    String hhmm(String t) => t.length >= 5 ? t.substring(0, 5) : t;
    final locale = Localizations.localeOf(context).toString();
    final days = [...business.workingWeekdays]..sort();
    final dayText = days.map((d) => weekdayLabel(d, locale)).join(', ');
    return '$dayText · ${hhmm(business.workingHoursFrom)}–${hhmm(business.workingHoursTo)}';
  }

  @override
  Widget build(BuildContext context) {
    final b = business;
    final website = b.website;
    final phone = b.phone;
    return Column(
      children: [
        if (b.location.isNotEmpty)
          ListTile(
            dense: true,
            leading: const Icon(Icons.place_outlined),
            title: Text(b.location),
          ),
        if (b.workingWeekdays.isNotEmpty)
          ListTile(
            dense: true,
            leading: const Icon(Icons.schedule_outlined),
            title: Text(_hours(context)),
          ),
        if (website != null && website.isNotEmpty)
          ListTile(
            dense: true,
            leading: const Icon(Icons.link),
            title: Text(
              website.replaceFirst(RegExp(r'^https?://'), ''),
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            onTap: () => openExternalUrl(context, website),
          ),
        if (phone != null && phone.isNotEmpty)
          ListTile(
            dense: true,
            leading: const Icon(Icons.phone_outlined),
            title: Text(phone),
            onTap: () => openExternalUrl(context, 'tel:$phone'),
          ),
      ],
    );
  }
}

class _PeopleSection extends StatelessWidget {
  const _PeopleSection({required this.title, required this.people});

  final String title;
  final List<BusinessPerson> people;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final p = people[i];
              final initials =
                  '${p.name.isNotEmpty ? p.name[0] : ''}${p.lastName.isNotEmpty ? p.lastName[0] : ''}'
                      .toUpperCase();
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => openUserProfile(context, p.id),
                child: SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      UserAvatar(url: p.avatarUrl, initials: initials, radius: 28),
                      const SizedBox(height: 6),
                      Text(
                        p.name.isEmpty ? p.username : p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.business,
    required this.role,
    required this.busy,
    required this.onAnswer,
  });

  final Business business;
  final BusinessRole role;
  final bool busy;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.rolesInviteToJoin(
                business.name,
                businessRoleLabel(l10n, role),
              ),
              style: TextStyle(color: cs.onTertiaryContainer),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: busy ? null : () => onAnswer(false),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onTertiaryContainer,
                  ),
                  child: Text(l10n.rolesInviteDecline),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: busy ? null : () => onAnswer(true),
                  child: Text(l10n.rolesInviteAccept),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
