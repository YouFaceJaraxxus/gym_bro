import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/link_access.dart';

/// The line shown instead of a link that no longer opens: "Private · you
/// don't have access to this anymore" or "No longer available · it was
/// deleted". Nothing for [LinkAccess.ok] or null.
class LinkAccessNote extends StatelessWidget {
  const LinkAccessNote({super.key, required this.access, this.dense = false});

  final LinkAccess? access;
  final bool dense;

  static String? textOf(BuildContext context, LinkAccess? access) => switch (access) {
    LinkAccess.private => context.l10n.accessPrivate,
    LinkAccess.unavailable => context.l10n.accessUnavailable,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final text = textOf(context, access);
    if (text == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final style = (dense ? Theme.of(context).textTheme.bodySmall : Theme.of(context).textTheme.bodyMedium)
        ?.copyWith(color: cs.onSurfaceVariant);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          access == LinkAccess.private ? Icons.lock_outline : Icons.link_off,
          size: dense ? 14 : 16,
          color: cs.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}
