import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'exercises_page.dart';
import 'workouts_page.dart';
import 'sessions_page.dart';
import 'meal_plans_page.dart';
import 'posts_page.dart';
import 'checkin/member_check_in_page.dart';
import 'classes/class_schedule_page.dart';
import 'nutrition/food_diary_page.dart';
import 'progress/progress_page.dart';
import 'shop/storefront_page.dart';

class GymHubPage extends StatefulWidget {
  const GymHubPage({super.key, this.profile});

  final UserProfile? profile;

  @override
  State<GymHubPage> createState() => _GymHubPageState();
}

class _GymHubPageState extends State<GymHubPage> {
  UserProfile? get profile => widget.profile;

  /// Whether the user is a member of any gym (shows the check-in card).
  bool _isMember = false;

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    final p = profile;
    if (p == null) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await ApiService().getMembers(token, userId: p.id);
      if (mounted) setState(() => _isMember = rows.isNotEmpty);
    } catch (_) {
      // The card just stays hidden; everything else on the hub works.
    }
  }

  void _push(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  /// Resolves the (business id, business name, canPost) the current user
  /// belongs to, trying every role relationship in turn. Returns null if none
  /// is found (e.g. a super_user with no personal membership/staff role).
  Future<({String id, String name, bool canPost})?> _resolveBusiness() async {
    final p = profile;
    if (p == null) return null;
    final token = await AuthManager.instance.getValidToken();
    final api = ApiService();

    Future<String?> firstGymId(
      Future<List<Map<String, dynamic>>> Function() fetch,
      String key,
    ) async {
      final rows = await fetch();
      return rows.isNotEmpty ? rows.first[key] as String? : null;
    }

    final staffGymId =
        await firstGymId(
          () => api.getEmployees(token, userId: p.id),
          'gym_id',
        ) ??
        await firstGymId(
          () => api.getTrainers(token, userId: p.id),
          'gym_id',
        ) ??
        await firstGymId(
          () => api.getEmployeeTrainers(token, userId: p.id),
          'gym_id',
        ) ??
        await firstGymId(() => api.getGymOwners(token, userId: p.id), 'gym_id');

    final gymId =
        staffGymId ??
        await firstGymId(() => api.getMembers(token, userId: p.id), 'gym_id');

    if (gymId != null) {
      final business = await api.getBusiness(token, gymId);
      return (id: gymId, name: business.name, canPost: staffGymId != null);
    }

    final shopId =
        await firstGymId(
          () => api.getShopOwners(token, userId: p.id),
          'shop_id',
        ) ??
        await firstGymId(
          () => api.getShopVendors(token, userId: p.id),
          'shop_id',
        );
    if (shopId != null) {
      final business = await api.getBusiness(token, shopId);
      return (id: shopId, name: business.name, canPost: true);
    }

    return null;
  }

  Future<void> _openCommunity() async {
    ({String id, String name, bool canPost})? resolved;
    try {
      resolved = await _resolveBusiness();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.shellHubCommunityOpenFailed(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
          action: SnackBarAction(
            label: context.l10n.commonRetry,
            onPressed: _openCommunity,
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    if (resolved == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.shellHubNotLinked)));
      return;
    }
    final target = resolved;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostsPage(
          businessId: target.id,
          businessName: target.name,
          canPost: target.canPost,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      children: [
        if (_isMember) ...[
          _HubCard(
            icon: Icons.qr_code_2,
            label: l10n.shellHubCheckIn,
            subtitle: l10n.shellHubCheckInSubtitle,
            onTap: () => _push(const MemberCheckInPage()),
          ),
          const SizedBox(height: 14),
        ],
        _HubCard(
          icon: Icons.event_available_outlined,
          label: l10n.shellTabSchedule,
          subtitle: l10n.planScheduleHubSubtitle,
          onTap: () => _push(const ClassSchedulePage()),
        ),
        const SizedBox(height: 14),
        _HubCard(
          icon: Icons.sports_gymnastics_outlined,
          label: l10n.shellHubExercises,
          subtitle: l10n.shellHubExercisesSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExercisesPage()),
          ),
        ),
        const SizedBox(height: 14),
        _HubCard(
          icon: Icons.menu_book_outlined,
          label: l10n.shellHubWorkouts,
          subtitle: l10n.shellHubWorkoutsSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WorkoutsPage()),
          ),
        ),
        const SizedBox(height: 14),
        _HubCard(
          icon: Icons.timer_outlined,
          label: l10n.shellHubSessions,
          subtitle: l10n.shellHubSessionsSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SessionsPage()),
          ),
        ),
        const SizedBox(height: 14),
        _HubCard(
          icon: Icons.show_chart,
          label: l10n.shellHubProgress,
          subtitle: l10n.shellMyProgressSubtitle,
          onTap: () => _push(const ProgressPage()),
        ),
        const SizedBox(height: 14),
        _HubCard(
          icon: Icons.menu_book,
          label: l10n.shellHubFoodDiary,
          subtitle: l10n.shellHubFoodDiarySubtitle,
          onTap: () => _push(const FoodDiaryPage()),
        ),
        const SizedBox(height: 14),
        _HubCard(
          icon: Icons.restaurant_menu_outlined,
          label: l10n.shellHubMealPlans,
          subtitle: l10n.shellHubMealPlansSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MealPlansPage()),
          ),
        ),
        const SizedBox(height: 14),
        _HubCard(
          icon: Icons.storefront_outlined,
          label: l10n.shellHubStore,
          subtitle: l10n.shellHubStoreSubtitle,
          onTap: () => _push(const StorefrontPage()),
        ),
        if (profile != null) ...[
          const SizedBox(height: 14),
          _HubCard(
            icon: Icons.forum_outlined,
            label: l10n.shellHubCommunity,
            subtitle: l10n.shellHubCommunitySubtitle,
            onTap: _openCommunity,
          ),
        ],
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // One button for screen readers: "<label>, <subtitle>".
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 28, color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
