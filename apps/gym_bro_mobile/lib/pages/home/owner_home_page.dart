import 'package:flutter/material.dart';
import '../../models/user_profile.dart';

class OwnerHomePage extends StatelessWidget {
  const OwnerHomePage({super.key, required this.profile});

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
            'Welcome back, ${profile.name}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            profile.role.displayName,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 32),
          _SummaryCard(
            icon: Icons.people_outline,
            label: 'Total Members',
            value: '—',
            color: colorScheme.primaryContainer,
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            icon: Icons.person_outline,
            label: 'Active Staff',
            value: '—',
            color: colorScheme.secondaryContainer,
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            icon: Icons.receipt_long_outlined,
            label: 'Invoices This Month',
            value: '—',
            color: colorScheme.tertiaryContainer,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: ListTile(
        leading: Icon(icon, size: 28),
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
