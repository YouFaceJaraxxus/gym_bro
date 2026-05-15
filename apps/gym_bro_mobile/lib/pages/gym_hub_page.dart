import 'package:flutter/material.dart';
import 'exercises_page.dart';
import 'workouts_page.dart';
import 'sessions_page.dart';
import 'meal_plans_page.dart';

class GymHubPage extends StatelessWidget {
  const GymHubPage({super.key});

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
