import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'exercises_page.dart';
import 'workouts_page.dart';
import 'sessions_page.dart';
import 'meal_plans_page.dart';
import 'posts_page.dart';

class GymHubPage extends StatelessWidget {
  const GymHubPage({super.key, this.profile});

  final UserProfile? profile;

  /// Resolves the (business id, business name, canPost) the current user
  /// belongs to, trying every role relationship in turn. Returns null if none
  /// is found (e.g. a super_user with no personal membership/staff role).
  Future<({String id, String name, bool canPost})?> _resolveBusiness() async {
    final p = profile;
    if (p == null) return null;
    final token = await AuthManager.instance.getValidToken();
    final api = ApiService();

    Future<String?> firstGymId(Future<List<Map<String, dynamic>>> Function() fetch, String key) async {
      final rows = await fetch();
      return rows.isNotEmpty ? rows.first[key] as String? : null;
    }

    final staffGymId = await firstGymId(() => api.getEmployees(token, userId: p.id), 'gym_id') ??
        await firstGymId(() => api.getTrainers(token, userId: p.id), 'gym_id') ??
        await firstGymId(() => api.getEmployeeTrainers(token, userId: p.id), 'gym_id') ??
        await firstGymId(() => api.getGymOwners(token, userId: p.id), 'gym_id');

    final gymId = staffGymId ?? await firstGymId(() => api.getMembers(token, userId: p.id), 'gym_id');

    if (gymId != null) {
      final business = await api.getBusiness(token, gymId);
      return (id: gymId, name: business.name, canPost: staffGymId != null);
    }

    final shopId = await firstGymId(() => api.getShopOwners(token, userId: p.id), 'shop_id') ??
        await firstGymId(() => api.getShopVendors(token, userId: p.id), 'shop_id');
    if (shopId != null) {
      final business = await api.getBusiness(token, shopId);
      return (id: shopId, name: business.name, canPost: true);
    }

    return null;
  }

  Future<void> _openCommunity(BuildContext context) async {
    ({String id, String name, bool canPost})? resolved;
    try {
      resolved = await _resolveBusiness();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Couldn't open community: ${e.toString().replaceFirst('Exception: ', '')}"),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _openCommunity(context),
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You're not linked to a gym or shop yet")),
      );
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      children: [
        _HubCard(
          icon: Icons.sports_gymnastics_outlined,
          label: 'Exercises',
          subtitle: 'Browse and manage exercises',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExercisesPage()),
          ),
        ),
        const SizedBox(height: 14),
        _HubCard(
          icon: Icons.menu_book_outlined,
          label: 'Workouts',
          subtitle: 'Trainings and routines',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WorkoutsPage()),
          ),
        ),
        const SizedBox(height: 14),
        _HubCard(
          icon: Icons.timer_outlined,
          label: 'Sessions',
          subtitle: 'Log and review your sessions',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SessionsPage()),
          ),
        ),
        const SizedBox(height: 14),
        _HubCard(
          icon: Icons.restaurant_menu_outlined,
          label: 'Meal Plans',
          subtitle: 'Food, recipes and nutrition',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MealPlansPage()),
          ),
        ),
        if (profile != null) ...[
          const SizedBox(height: 14),
          _HubCard(
            icon: Icons.forum_outlined,
            label: 'Community',
            subtitle: 'Posts and announcements from your gym',
            onTap: () => _openCommunity(context),
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant),
                    ),
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
