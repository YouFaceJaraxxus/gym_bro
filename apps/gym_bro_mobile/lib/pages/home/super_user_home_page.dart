import 'package:flutter/material.dart';
import '../../models/user_profile.dart';

class SuperUserHomePage extends StatelessWidget {
  const SuperUserHomePage({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Panel',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${profile.username} · ${profile.role.displayName}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 32),
          _AdminTile(
            icon: Icons.business_outlined,
            label: 'Businesses',
            subtitle: 'Manage gyms & shops',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _AdminTile(
            icon: Icons.people_outline,
            label: 'Users',
            subtitle: 'Manage all accounts',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _AdminTile(
            icon: Icons.receipt_long_outlined,
            label: 'Invoices',
            subtitle: 'View all membership invoices',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 28),
        title: Text(label),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
