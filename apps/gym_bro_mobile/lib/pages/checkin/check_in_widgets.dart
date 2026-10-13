import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/check_in.dart';
import '../../theme.dart';

/// Semantic colors for check-in outcomes: success/warning from the app's
/// [AppColors] extension, grey and red from the color scheme.
class CheckInPalette {
  final Color container;
  final Color onContainer;
  const CheckInPalette(this.container, this.onContainer);

  static CheckInPalette of(BuildContext context, CheckInOutcome outcome) {
    final cs = Theme.of(context).colorScheme;
    final app = context.appColors;
    return switch (outcome) {
      CheckInOutcome.checkedIn => CheckInPalette(
        app.successContainer,
        app.onSuccessContainer,
      ),
      CheckInOutcome.noActiveMembership => CheckInPalette(
        app.warningContainer,
        app.onWarningContainer,
      ),
      CheckInOutcome.duplicate => CheckInPalette(
        cs.surfaceContainerHighest,
        cs.onSurfaceVariant,
      ),
      CheckInOutcome.invalid => CheckInPalette(
        cs.errorContainer,
        cs.onErrorContainer,
      ),
    };
  }
}

String _locale(BuildContext context) =>
    Localizations.localeOf(context).toString();

String formatTime(BuildContext context, DateTime dt) =>
    DateFormat.Hm(_locale(context)).format(dt);

String formatDay(BuildContext context, DateTime dt) {
  final l10n = context.l10n;
  final locale = _locale(context);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l10n.commonToday;
  if (diff == 1) return l10n.businessCheckInYesterday;
  if (day.year == now.year) return DateFormat.MMMEd(locale).format(dt);
  return DateFormat.yMMMd(locale).format(dt);
}

/// "15 Nov 2026" from a YYYY-MM-DD string (falls back to the raw string).
String formatYmd(BuildContext context, String ymd) {
  final d = DateTime.tryParse(ymd);
  return d == null ? ymd : DateFormat.yMMMd(_locale(context)).format(d);
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.initials,
    this.url,
    this.radius = 20,
    this.semanticLabel,
  });

  final String initials;
  final String? url;
  final double radius;

  /// Usually the person's name; leave null when a name is shown next to it.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final u = url;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      foregroundImage: u != null && u.isNotEmpty ? NetworkImage(u) : null,
      child: Text(
        initials,
        style: TextStyle(fontSize: radius * 0.7, color: cs.onPrimaryContainer),
      ),
    );
    final label = semanticLabel;
    return label == null
        ? ExcludeSemantics(child: avatar)
        : Semantics(
            label: label,
            image: true,
            excludeSemantics: true,
            child: avatar,
          );
  }
}

class CheckInErrorState extends StatelessWidget {
  const CheckInErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.error_outline, size: 44, color: cs.error),
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckInEmptyState extends StatelessWidget {
  const CheckInEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Small labelled number used in stat rows.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: cs.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(height: 6),
              ],
              Text(
                value,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                label,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
