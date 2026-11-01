import 'package:flutter/material.dart';

/// A friendly "nothing here yet" block: a tinted icon badge, a title, one
/// line of explanation and an optional next-step button.
///
/// Use [EmptyState.scrollable] inside a [RefreshIndicator] so the empty
/// screen can still be pulled to refresh.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.compact = false,
  }) : _scrollable = false;

  /// Fills the viewport inside an always-scrollable view, for pull-to-refresh.
  const EmptyState.scrollable({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.compact = false,
  }) : _scrollable = true;

  final IconData icon;
  final String title;
  final String? message;

  /// The next-step button; shown when both [actionLabel] and [onAction] are set.
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// Smaller padding and badge, for sections inside a longer page.
  final bool compact;

  final bool _scrollable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final badge = compact ? 56.0 : 76.0;
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 20 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: badge,
            height: badge,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: cs.brightness == Brightness.dark ? 0.55 : 0.7),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: badge * 0.46, color: cs.onPrimaryContainer),
          ),
          SizedBox(height: compact ? 12 : 18),
          Text(title, style: tt.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message!,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: compact ? 14 : 20),
            actionIcon == null
                ? FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!))
                : FilledButton.tonalIcon(
                    onPressed: onAction,
                    icon: Icon(actionIcon),
                    label: Text(actionLabel!),
                  ),
          ],
        ],
      ),
    );
    if (!_scrollable) return Center(child: content);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: content),
        ),
      ),
    );
  }
}
