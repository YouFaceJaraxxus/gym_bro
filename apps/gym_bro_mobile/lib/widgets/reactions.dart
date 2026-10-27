import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/reaction.dart';

/// Facebook/LinkedIn-style reactions.
///
/// * [ReactionButton]: tap toggles 👍 (or removes my current reaction);
///   long-press opens [showReactionPicker] with all ten.
/// * [ReactionSummaryView]: the top three emojis, overlapped, plus a count.

/// Shows the floating emoji bar above [anchor] and returns the chosen
/// reaction (null if dismissed).
Future<ReactionType?> showReactionPicker(
  BuildContext context, {
  required BuildContext anchor,
  ReactionType? current,
}) {
  final box = anchor.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) return Future.value(null);
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  HapticFeedback.mediumImpact();
  return Navigator.of(context).push<ReactionType>(PageRouteBuilder(
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, animation, _) => _ReactionPickerOverlay(
      anchorTop: topLeft.dy,
      anchorLeft: topLeft.dx,
      anchorHeight: box.size.height,
      current: current,
      animation: animation,
    ),
  ));
}

class _ReactionPickerOverlay extends StatelessWidget {
  final double anchorTop;
  final double anchorLeft;
  final double anchorHeight;
  final ReactionType? current;
  final Animation<double> animation;

  const _ReactionPickerOverlay({
    required this.anchorTop,
    required this.anchorLeft,
    required this.anchorHeight,
    required this.current,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    const itemSize = 40.0;
    const barHeight = 56.0;
    // Two rows of five on narrow phones, one row of ten otherwise.
    final oneRow = media.size.width >= ReactionType.values.length * itemSize + 40;
    final perRow = oneRow ? ReactionType.values.length : 5;
    final rows = oneRow ? 1 : 2;
    final width = perRow * itemSize + 16;
    final height = rows * (barHeight - 12) + 12;
    final left = (anchorLeft - 8).clamp(8.0, media.size.width - width - 8);
    final above = anchorTop - height - 8;
    final top = above > media.padding.top + 8 ? above : anchorTop + anchorHeight + 8;

    return Stack(children: [
      Positioned.fill(child: GestureDetector(onTap: () => Navigator.pop(context))),
      Positioned(
        left: left,
        top: top,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          alignment: Alignment.bottomLeft,
          child: Material(
            elevation: 6,
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: SizedBox(
                width: width - 16,
                child: Wrap(
                  children: [
                    for (final (i, r) in ReactionType.values.indexed)
                      _PickerEmoji(reaction: r, selected: r == current, index: i, animation: animation, size: itemSize),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _PickerEmoji extends StatefulWidget {
  final ReactionType reaction;
  final bool selected;
  final int index;
  final Animation<double> animation;
  final double size;

  const _PickerEmoji({required this.reaction, required this.selected, required this.index, required this.animation, required this.size});

  @override
  State<_PickerEmoji> createState() => _PickerEmojiState();
}

class _PickerEmojiState extends State<_PickerEmoji> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Staggered pop-in, left to right.
    final start = (widget.index * 0.05).clamp(0.0, 0.6);
    final pop = CurvedAnimation(parent: widget.animation, curve: Interval(start, 1, curve: Curves.easeOutBack));
    return Tooltip(
      message: widget.reaction.label(context.l10n),
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.reaction.label(context.l10n),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _hover = true),
          onTapCancel: () => setState(() => _hover = false),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context, widget.reaction);
          },
          child: ScaleTransition(
            scale: pop,
            child: AnimatedScale(
              scale: _hover ? 1.35 : 1,
              duration: const Duration(milliseconds: 100),
              child: Container(
                width: widget.size,
                height: widget.size + 4,
                alignment: Alignment.center,
                decoration: widget.selected
                    ? BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle)
                    : null,
                child: Text(widget.reaction.emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Like" action of a post or comment. Tap: 👍 on / my reaction off.
/// Long-press: pick any reaction. [onChanged] gets the new reaction (null = removed).
class ReactionButton extends StatelessWidget {
  final ReactionType? current;
  final ValueChanged<ReactionType?> onChanged;

  /// Smaller text for comment rows.
  final bool dense;

  const ReactionButton({super.key, required this.current, required this.onChanged, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final r = current;
    final color = r == null ? cs.onSurfaceVariant : _tint(r, cs);
    final label = (r ?? ReactionType.like).label(l10n);
    return Builder(builder: (anchor) {
      return Semantics(
        button: true,
        selected: r != null,
        hint: l10n.reactionPickerHint,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            HapticFeedback.lightImpact();
            onChanged(r == null ? ReactionType.like : null);
          },
          onLongPress: () async {
            final picked = await showReactionPicker(context, anchor: anchor, current: r);
            if (picked != null) onChanged(picked == r ? null : picked);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: dense ? 4 : 12, vertical: dense ? 4 : 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                child: r == null
                    ? Icon(Icons.thumb_up_alt_outlined, key: const ValueKey('none'), size: dense ? 16 : 20, color: color)
                    : Text(r.emoji, key: ValueKey(r), style: TextStyle(fontSize: dense ? 15 : 19)),
              ),
              SizedBox(width: dense ? 4 : 6),
              Text(
                label,
                style: (dense ? Theme.of(context).textTheme.labelMedium : Theme.of(context).textTheme.labelLarge)
                    ?.copyWith(color: color, fontWeight: r == null ? FontWeight.w500 : FontWeight.w700),
              ),
            ]),
          ),
        ),
      );
    });
  }

  static Color _tint(ReactionType r, ColorScheme cs) => switch (r) {
    ReactionType.like || ReactionType.clap => cs.primary,
    ReactionType.love || ReactionType.angry || ReactionType.fire => cs.error,
    ReactionType.haha || ReactionType.wow || ReactionType.sad || ReactionType.celebrate => const Color(0xFFE0A100),
    ReactionType.strong => cs.tertiary,
  };
}

/// Overlapping top emojis + total, e.g. "👍❤️🔥 24". Tappable (who reacted).
class ReactionSummaryView extends StatelessWidget {
  final ReactionSummary summary;
  final VoidCallback? onTap;
  final bool dense;

  const ReactionSummaryView({super.key, required this.summary, this.onTap, this.dense = false});

  @override
  Widget build(BuildContext context) {
    if (summary.total == 0) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final size = dense ? 16.0 : 20.0;
    final top = summary.top.isEmpty ? [ReactionType.like] : summary.top;
    return Semantics(
      button: onTap != null,
      label: context.l10n.reactionCount(summary.total),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: size + (top.length - 1) * size * 0.7,
              height: size,
              child: Stack(children: [
                for (final (i, r) in top.indexed)
                  Positioned(
                    left: i * size * 0.7,
                    child: Container(
                      width: size,
                      height: size,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 1.5),
                      ),
                      child: Text(r.emoji, style: TextStyle(fontSize: size * 0.62)),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 4),
            Text(
              '${summary.total}',
              style: (dense ? Theme.of(context).textTheme.labelSmall : Theme.of(context).textTheme.labelMedium)
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ]),
        ),
      ),
    );
  }
}
