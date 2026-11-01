import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../theme.dart';

/// Localized role name: Owner / Staff / Trainer.
String businessRoleLabel(AppLocalizations l10n, BusinessRole role) =>
    switch (role) {
      BusinessRole.owner => l10n.rolesRoleOwner,
      BusinessRole.staff => l10n.rolesRoleStaff,
      BusinessRole.trainer => l10n.rolesRoleTrainer,
    };

/// Localized review status.
String businessStatusLabel(AppLocalizations l10n, BusinessStatus status) =>
    switch (status) {
      BusinessStatus.pending => l10n.rolesStatusPending,
      BusinessStatus.approved => l10n.rolesStatusApproved,
      BusinessStatus.rejected => l10n.rolesStatusRejected,
      BusinessStatus.blocked => l10n.rolesStatusBlocked,
    };

/// "Gym", "Shop" or "Gym & shop".
String businessKindLabel(AppLocalizations l10n, bool hasGym, bool hasShop) {
  if (hasGym && hasShop) return l10n.rolesKindGymAndShop;
  return hasGym ? l10n.rolesKindGym : l10n.rolesKindShop;
}

IconData businessKindIcon(bool hasGym, bool hasShop) {
  if (hasGym && hasShop) return Icons.store_mall_directory_outlined;
  return hasGym ? Icons.fitness_center : Icons.storefront_outlined;
}

/// Round logo, or the kind's icon when there is none.
class BusinessAvatar extends StatelessWidget {
  const BusinessAvatar({
    super.key,
    required this.logo,
    required this.hasGym,
    required this.hasShop,
    this.radius = 22,
  });

  final String? logo;
  final bool hasGym;
  final bool hasShop;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = logo;
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.secondaryContainer,
      foregroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: Icon(
        businessKindIcon(hasGym, hasShop),
        size: radius,
        color: cs.onSecondaryContainer,
      ),
    );
  }
}

/// Small coloured label for a business's review status. Approved shows
/// nothing unless [showApproved].
class BusinessStatusChip extends StatelessWidget {
  const BusinessStatusChip({
    super.key,
    required this.status,
    this.showApproved = false,
  });

  final BusinessStatus status;
  final bool showApproved;

  @override
  Widget build(BuildContext context) {
    if (status == BusinessStatus.approved && !showApproved) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final (bg, fg) = switch (status) {
      BusinessStatus.pending => (colors.warningContainer, colors.onWarningContainer),
      BusinessStatus.approved => (colors.successContainer, colors.onSuccessContainer),
      BusinessStatus.rejected || BusinessStatus.blocked => (
        cs.errorContainer,
        cs.onErrorContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        businessStatusLabel(context.l10n, status),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Outlined chips for roles; [invited] ones read "Invited · Trainer".
class RoleChips extends StatelessWidget {
  const RoleChips({super.key, required this.roles, this.invited = const []});

  final List<BusinessRole> roles;
  final List<BusinessRole> invited;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall;
    Widget chip(String text, {bool muted = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: muted ? null : cs.primaryContainer,
        border: muted ? Border.all(color: cs.outlineVariant) : null,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: style?.copyWith(
          color: muted ? cs.onSurfaceVariant : cs.onPrimaryContainer,
        ),
      ),
    );
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final r in roles) chip(businessRoleLabel(l10n, r)),
        for (final r in invited)
          chip(l10n.rolesInvitedAs(businessRoleLabel(l10n, r)), muted: true),
      ],
    );
  }
}
