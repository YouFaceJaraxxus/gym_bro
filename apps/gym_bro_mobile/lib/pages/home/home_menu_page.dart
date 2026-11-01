import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/home_streak_card.dart';
import '../admin/db_console_page.dart';
import '../business/business_invites_page.dart';
import '../business/business_manage_page.dart';
import '../business/business_review_page.dart';
import '../business/business_widgets.dart';
import '../business/owner_overview_page.dart';
import '../business_form_page.dart';
import '../classes/my_shifts_page.dart';
import '../classes/trainer_classes_page.dart';
import '../exercises_page.dart';
import '../invoices_page.dart';
import '../meal_plans_page.dart';
import '../membership_page.dart';
import '../nutrition/food_diary_page.dart';
import '../progress/progress_page.dart';
import '../sessions_page.dart';
import '../shop/buy_membership_page.dart';
import '../shop/my_orders_page.dart';
import '../workouts_page.dart';
import 'owner_users_page.dart';

/// The Home tab: everything the user can do, grouped into cards. Nobody has a
/// single "type" — the cards stack up from what they are: everyone trains,
/// eats and holds memberships; trainers get trainer tools; anyone on a gym's
/// or shop's team gets a card per business; super users get Admin.
class HomeMenuPage extends StatefulWidget {
  const HomeMenuPage({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    required this.onRefresh,
  });

  final UserProfile profile;

  /// Hands back a profile the menu changed itself (e.g. became a trainer).
  final Future<void> Function(UserProfile) onProfileChanged;

  /// Reloads the profile from the server (roles, invites, reviews).
  final Future<void> Function() onRefresh;

  @override
  State<HomeMenuPage> createState() => _HomeMenuPageState();
}

class _HomeMenuPageState extends State<HomeMenuPage> {
  final _api = ApiService();

  /// Businesses waiting for review (super users only).
  int _pendingReviews = 0;
  final _streak = GlobalKey<HomeStreakCardState>();

  @override
  void initState() {
    super.initState();
    _loadReviewCount();
  }

  @override
  void didUpdateWidget(HomeMenuPage old) {
    super.didUpdateWidget(old);
    if (old.profile.isSuperUser != widget.profile.isSuperUser) {
      _loadReviewCount();
    }
  }

  Future<void> _loadReviewCount() async {
    if (!widget.profile.isSuperUser) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      final queue = await _api.getBusinessReviewQueue(token);
      if (mounted) setState(() => _pendingReviews = queue.length);
    } catch (_) {
      // The count is a nicety; the queue page shows errors itself.
    }
  }

  /// Opens [page]; on return, refreshes the profile (and the review count),
  /// since most of these screens can change what the user is.
  Future<void> _open(Widget page, {bool refresh = false}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (!refresh || !mounted) return;
    await widget.onRefresh();
    _loadReviewCount();
  }

  Future<void> _becomeTrainer() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.sports_outlined),
        title: Text(l10n.rolesBecomeTrainerTitle),
        content: Text(l10n.rolesBecomeTrainerBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.rolesBecomeTrainerConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      final updated = await _api.setTrainer(token, enabled: true);
      await widget.onProfileChanged(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.rolesBecameTrainer)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = widget.profile;
    final ownsGym = p.businessesAs(BusinessRole.owner).any((b) => b.hasGym);
    final worksAtGym = p.workGyms.any(
      (b) =>
          b.roles.contains(BusinessRole.staff) ||
          b.roles.contains(BusinessRole.trainer),
    );

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([widget.onRefresh(), if (_streak.currentState != null) _streak.currentState!.refresh()]);
        await _loadReviewCount();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          HomeStreakCard(key: _streak),
          if (p.pendingInvites > 0) ...[
            _InviteBanner(
              count: p.pendingInvites,
              onTap: () => _open(const BusinessInvitesPage(), refresh: true),
            ),
            const SizedBox(height: 12),
          ],

          // ── Everyone ──
          _MenuSection(
            title: l10n.rolesMenuTraining,
            icon: Icons.fitness_center,
            items: [
              _MenuItem(
                Icons.menu_book_outlined,
                l10n.shellHubWorkouts,
                () => _open(const WorkoutsPage()),
              ),
              _MenuItem(
                Icons.timer_outlined,
                l10n.shellHubSessions,
                () => _open(const SessionsPage()),
              ),
              _MenuItem(
                Icons.sports_gymnastics_outlined,
                l10n.shellHubExercises,
                () => _open(const ExercisesPage()),
              ),
              _MenuItem(
                Icons.show_chart,
                l10n.shellHubProgress,
                () => _open(const ProgressPage()),
              ),
            ],
          ),
          _MenuSection(
            title: l10n.rolesMenuNutrition,
            icon: Icons.restaurant_outlined,
            items: [
              _MenuItem(
                Icons.restaurant_menu_outlined,
                l10n.shellHubMealPlans,
                () => _open(const MealPlansPage()),
              ),
              _MenuItem(
                Icons.menu_book,
                l10n.shellHubFoodDiary,
                () => _open(const FoodDiaryPage()),
              ),
            ],
          ),
          _MenuSection(
            title: l10n.rolesMenuMemberships,
            icon: Icons.card_membership_outlined,
            items: [
              _MenuItem(
                Icons.badge_outlined,
                l10n.shellMyMembership,
                () => _open(MembershipPage(profile: p)),
              ),
              _MenuItem(
                Icons.add_card_outlined,
                l10n.rolesMenuBuyMembership,
                () => _open(const BuyMembershipPage()),
              ),
              _MenuItem(
                Icons.receipt_long_outlined,
                l10n.shellMyOrders,
                () => _open(const MyOrdersPage()),
              ),
            ],
          ),

          // ── Trainers ──
          if (p.isTrainer)
            _MenuSection(
              title: l10n.rolesMenuTrainer,
              icon: Icons.sports_outlined,
              items: [
                _MenuItem(
                  Icons.event_note_outlined,
                  l10n.rolesMenuTrainerClasses,
                  () => _open(const TrainerClassesPage()),
                ),
                _MenuItem(
                  Icons.repeat,
                  l10n.rolesMenuTrainerTimetables,
                  () => _open(const TrainerClassesPage(initialTab: 1)),
                ),
                _MenuItem(
                  Icons.groups_outlined,
                  l10n.rolesMenuTrainerClients,
                  () => _open(const TrainerClassesPage(initialTab: 2)),
                ),
                _MenuItem(
                  Icons.assignment_outlined,
                  l10n.rolesMenuTrainerSessions,
                  () => _open(SessionsPage(asTrainerId: p.id)),
                ),
              ],
            ),

          // ── Gyms and shops the user is on the team of ──
          if (p.businesses.isNotEmpty)
            _MenuSection(
              title: l10n.rolesMenuMyBusinesses,
              icon: Icons.storefront_outlined,
              rows: [
                for (final b in p.businesses)
                  _BusinessRow(
                    business: b,
                    onTap: () =>
                        _open(BusinessManagePage(businessId: b.id), refresh: true),
                  ),
              ],
              items: [
                if (ownsGym)
                  _MenuItem(
                    Icons.insights_outlined,
                    l10n.rolesMenuOwnerOverview,
                    () => _open(const OwnerOverviewPage()),
                  ),
                if (p.staffedGyms.isNotEmpty)
                  _MenuItem(
                    Icons.receipt_outlined,
                    l10n.shellInvoices,
                    () => _open(const InvoicesPage()),
                  ),
                if (worksAtGym)
                  _MenuItem(
                    Icons.schedule_outlined,
                    l10n.rolesMenuMyShifts,
                    () => _open(const MyShiftsPage()),
                  ),
              ],
            ),

          // ── Ways to do more ──
          _MenuSection(
            title: l10n.rolesMenuDoMore,
            icon: Icons.auto_awesome_outlined,
            rows: [
              if (!p.isTrainer)
                _ActionRow(
                  icon: Icons.sports_outlined,
                  title: l10n.rolesMenuBecomeTrainer,
                  subtitle: l10n.rolesMenuBecomeTrainerSubtitle,
                  onTap: _becomeTrainer,
                ),
              _ActionRow(
                icon: Icons.add_business_outlined,
                title: l10n.rolesMenuRegisterBusiness,
                subtitle: p.isSuperUser
                    ? l10n.rolesMenuRegisterBusinessSubtitleAdmin
                    : l10n.rolesMenuRegisterBusinessSubtitle,
                onTap: () => _open(const BusinessFormPage(), refresh: true),
              ),
            ],
          ),

          // ── Platform admin ──
          if (p.isSuperUser)
            _MenuSection(
              title: l10n.rolesMenuAdmin,
              icon: Icons.admin_panel_settings_outlined,
              items: [
                _MenuItem(
                  Icons.verified_outlined,
                  l10n.rolesMenuReviewQueue,
                  () => _open(const BusinessReviewPage(), refresh: true),
                  badge: _pendingReviews,
                ),
                _MenuItem(
                  Icons.storage_outlined,
                  l10n.adminDbTitle,
                  () => _open(const DbConsolePage(), refresh: true),
                ),
                _MenuItem(
                  Icons.manage_accounts_outlined,
                  l10n.shellTabUsers,
                  () => _open(
                    Scaffold(
                      appBar: AppBar(title: Text(l10n.shellTabUsers)),
                      body: const OwnerUsersPage(),
                    ),
                  ),
                ),
                _MenuItem(
                  Icons.receipt_outlined,
                  l10n.shellInvoices,
                  () => _open(const InvoicesPage()),
                ),
                _MenuItem(
                  Icons.insights_outlined,
                  l10n.shellPlatformOverview,
                  () => _open(const OwnerOverviewPage()),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Building blocks ───────────────────────────────────────────────────────────

class _MenuItem {
  const _MenuItem(this.icon, this.label, this.onTap, {this.badge = 0});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
}

/// A titled card: optional full-width [rows] on top, then [items] as a grid
/// of two-per-line tiles.
class _MenuSection extends StatelessWidget {
  const _MenuSection({
    required this.title,
    required this.icon,
    this.items = const [],
    this.rows = const [],
  });

  final String title;
  final IconData icon;
  final List<_MenuItem> items;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && rows.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: text.titleSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final r in rows) ...[r, const SizedBox(height: 8)],
              if (items.isNotEmpty)
                LayoutBuilder(
                  builder: (context, c) {
                    const gap = 8.0;
                    final w = (c.maxWidth - gap) / 2;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final i in items)
                          SizedBox(width: w, child: _MenuTile(item: i)),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item});

  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = Icon(item.icon, size: 22, color: cs.onSecondaryContainer);
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: item.badge > 0
                    ? Badge(label: Text('${item.badge}'), child: icon)
                    : icon,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width row with an icon, title and a line of explanation.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: cs.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// One of the user's businesses: logo, name, what they are there, and the
/// review status while it isn't approved.
class _BusinessRow extends StatelessWidget {
  const _BusinessRow({required this.business, required this.onTap});

  final MyBusiness business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = business;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              BusinessAvatar(logo: b.logo, hasGym: b.hasGym, hasShop: b.hasShop),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            b.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: 6),
                        BusinessStatusChip(status: b.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      businessKindLabel(context.l10n, b.hasGym, b.hasShop),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RoleChips(roles: b.roles),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteBanner extends StatelessWidget {
  const _InviteBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Material(
      color: cs.tertiaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Icon(Icons.mail_outline, color: cs.onTertiaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.rolesMenuInvitesBanner(count),
                  style: TextStyle(color: cs.onTertiaryContainer),
                ),
              ),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  foregroundColor: cs.onTertiaryContainer,
                ),
                child: Text(l10n.rolesMenuInvitesReview),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
