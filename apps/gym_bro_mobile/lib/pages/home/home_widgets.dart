import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../models/membership.dart';
import '../../models/payment.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../edit_gym_member_page.dart';
import '../invoices_page.dart';

/// Greeting + role line shown at the top of every role home page.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

/// Section heading with optional trailing widget.
class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Inline error with a Retry button (used inside scrolling home pages).
class HomeError extends StatelessWidget {
  const HomeError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: cs.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Muted one-line empty state.
class HomeEmpty extends StatelessWidget {
  const HomeEmpty({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(color: outline)),
          ),
        ],
      ),
    );
  }
}

/// A number + label tile used in the stats grids.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    // Read as one item ("12, Members, …"), and as a button when tappable.
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: Card(
          color: color,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 20),
                      const Spacer(),
                      if (onTap != null)
                        const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(value, style: ts.headlineSmall),
                  Text(label, style: ts.bodySmall),
                  if (detail != null)
                    Text(
                      detail!,
                      style: ts.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-column grid of [StatTile]s that sizes to its content.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// Stats cards + "Expiring soon" list for owners and super users, rendered
/// from GET /businesses/stats.
class BusinessStatsView extends StatelessWidget {
  const BusinessStatsView({
    super.key,
    required this.stats,
    required this.onChanged,
  });

  final BusinessStats stats;

  /// Called after returning from a page that may have changed the numbers.
  final VoidCallback onChanged;

  Future<void> _openInvoices(
    BuildContext context,
    InvoiceStatus? status,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoicesPage(initialStatus: status)),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final s = stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatGrid(
          children: [
            StatTile(
              icon: Icons.people_outline,
              label: l10n.shellStatsMembers,
              value: '${s.membersTotal}',
              detail: l10n.shellStatsGymCount(s.gyms),
              color: cs.primaryContainer,
            ),
            StatTile(
              icon: Icons.card_membership_outlined,
              label: l10n.shellStatsActiveMemberships,
              value: '${s.activeMemberships}',
              color: cs.primaryContainer,
            ),
            StatTile(
              icon: Icons.badge_outlined,
              label: l10n.shellStatsStaff,
              value: '${s.staffTotal}',
              color: cs.secondaryContainer,
            ),
            StatTile(
              icon: Icons.receipt_long_outlined,
              label: l10n.shellStatsInvoicesThisMonth,
              value: '${s.invoicesMonthCount}',
              detail: formatMoney(s.invoicesMonthTotal),
              color: cs.secondaryContainer,
              onTap: () => _openInvoices(context, null),
            ),
            StatTile(
              icon: Icons.pending_actions_outlined,
              label: l10n.shellStatsUnpaidInvoices,
              value: '${s.unpaidInvoicesCount}',
              color: s.unpaidInvoicesCount > 0
                  ? cs.tertiaryContainer
                  : cs.surfaceContainerHighest,
              onTap: () => _openInvoices(context, InvoiceStatus.unpaid),
            ),
          ],
        ),
        HomeSectionTitle(
          l10n.shellStatsExpiringSoon,
          trailing: Text(
            l10n.shellStatsNext14Days,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.outline),
          ),
        ),
        if (s.expiringSoon.isEmpty)
          HomeEmpty(
            icon: Icons.event_available_outlined,
            label: l10n.shellStatsNoneExpiring,
          )
        else
          for (final e in s.expiringSoon)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: ExcludeSemantics(
                  child: CircleAvatar(
                    child: Text(
                      e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                    ),
                  ),
                ),
                title: Text(e.fullName),
                subtitle: Text(
                  l10n.shellStatsEndsOn(
                    e.gymName,
                    _daysLeft(context, e.toDate),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await openGymMember(
                    context,
                    userId: e.userId,
                    gymId: e.gymId,
                    gymName: e.gymName,
                  );
                  onChanged();
                },
              ),
            ),
      ],
    );
  }

  static String _daysLeft(BuildContext context, DateTime to) {
    final l10n = context.l10n;
    final today = DateUtils.dateOnly(DateTime.now());
    final days = DateUtils.dateOnly(to).difference(today).inDays;
    if (days <= 0) return l10n.shellStatsEndsToday;
    if (days == 1) return l10n.shellStatsEndsTomorrow;
    final date = DateFormat.MMMd(
      Localizations.localeOf(context).toString(),
    ).format(to);
    return l10n.shellStatsEndsInDays(days, date);
  }
}

/// Resolves the member row + profile for [userId] at [gymId] and opens the
/// edit-member page. Shows a snackbar on failure.
Future<void> openGymMember(
  BuildContext context, {
  required String userId,
  required String gymId,
  required String gymName,
}) async {
  final api = ApiService();
  try {
    final token = await AuthManager.instance.getValidToken();
    final results = await Future.wait([
      api.getMembers(token, gymId: gymId, userId: userId),
      api.getUser(token, userId),
    ]);
    final rows = results[0] as List<Map<String, dynamic>>;
    final user = results[1] as UserProfile;
    if (rows.isEmpty) {
      if (!context.mounted) return;
      throw Exception(context.l10n.shellNoLongerMember(user.fullName));
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditGymMemberPage(
          memberId: rows.first['id'] as String,
          user: user,
          gymName: gymName,
          gymId: gymId,
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}

/// Pushes a tab body widget (which has no Scaffold of its own) as a page.
Future<T?> pushTabPage<T>(BuildContext context, String title, Widget body) {
  return Navigator.push<T>(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: body,
      ),
    ),
  );
}
