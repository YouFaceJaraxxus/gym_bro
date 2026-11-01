import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Shimmering placeholders shown while a screen loads for the first time, so
/// the layout appears straight away instead of a bare spinner.
///
/// Wrap placeholder blocks ([SkeletonBox], [SkeletonCircle], [SkeletonLine])
/// in one [Skeleton]; it paints a single highlight sweep across all of them.
/// With reduce motion on, the blocks stay static. Ready-made shapes:
/// [SkeletonList], [SkeletonTile], [SkeletonPostCard], [SkeletonGrid].
///
/// Keep spinners for small inline actions (buttons, "load more" rows).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.of(context);
    final content = Semantics(
      label: context.l10n.commonLoading,
      container: true,
      child: ExcludeSemantics(child: widget.child),
    );
    if (MediaQuery.disableAnimationsOf(context)) return content;
    return AnimatedBuilder(
      animation: _controller,
      child: content,
      builder: (context, child) {
        // The highlight band travels from just off the left edge to just off
        // the right one.
        final t = _controller.value * 2.5 - 0.75;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [colors.base, colors.highlight, colors.base],
            stops: [
              (t - 0.25).clamp(0.0, 1.0),
              t.clamp(0.0, 1.0),
              (t + 0.25).clamp(0.0, 1.0),
            ],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// Placeholder fill colors for both themes.
class SkeletonColors {
  const SkeletonColors(this.base, this.highlight);

  final Color base;
  final Color highlight;

  static SkeletonColors of(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return cs.brightness == Brightness.dark
        ? SkeletonColors(cs.surfaceContainerHigh, cs.surfaceBright)
        : SkeletonColors(cs.surfaceContainerHighest, cs.surfaceContainerLow);
  }
}

/// A rounded placeholder block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: SkeletonColors.of(context).base,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A round placeholder (avatars).
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: SkeletonColors.of(context).base, shape: BoxShape.circle),
    );
  }
}

/// A line of text: [widthFactor] of the available width.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.widthFactor = 1, this.height = 12});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: SkeletonBox(height: height, radius: height / 2),
    );
  }
}

/// A list-tile shape: avatar (or square icon), a title and a subtitle line.
/// Bare blocks; wrap in a [Skeleton] (or use [SkeletonList]).
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key, this.leadingSize = 44, this.square = false, this.trailing = false, this.lines = 2});

  final double leadingSize;
  final bool square;
  final bool trailing;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          square
              ? SkeletonBox(width: leadingSize, height: leadingSize, radius: 12)
              : SkeletonCircle(size: leadingSize),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SkeletonLine(widthFactor: 0.55, height: 13),
                for (var i = 1; i < lines; i++) ...[
                  const SizedBox(height: 8),
                  SkeletonLine(widthFactor: i.isOdd ? 0.85 : 0.4, height: 11),
                ],
              ],
            ),
          ),
          if (trailing) ...[
            const SizedBox(width: 14),
            const SkeletonBox(width: 72, height: 32, radius: 10),
          ],
        ],
      ),
    );
  }
}

/// A full-screen list of placeholder rows. [itemBuilder] defaults to a
/// [SkeletonTile]; [header] sits above the rows (e.g. a profile header).
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 8,
    this.itemBuilder,
    this.header,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  final int itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final Widget? header;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        padding: padding,
        // A placeholder: nothing to scroll to yet.
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ?header,
          for (var i = 0; i < itemCount; i++)
            itemBuilder?.call(context, i) ?? const SkeletonTile(),
        ],
      ),
    );
  }

  /// Rows of post-card placeholders (feeds).
  static Widget posts({int count = 3, Widget? header}) =>
      SkeletonList(itemCount: count, header: header, itemBuilder: (_, _) => const SkeletonPostCard());

  /// Rows of card placeholders [height] tall (sessions, challenges, gyms).
  static Widget cards({int count = 6, double height = 92, Widget? header}) => SkeletonList(
    itemCount: count,
    header: header,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    itemBuilder: (_, _) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SkeletonBox(height: height, radius: 16),
    ),
  );
}

/// A feed post: author row, square media, action row and a caption line.
class SkeletonPostCard extends StatelessWidget {
  const SkeletonPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonTile(leadingSize: 36),
          AspectRatio(aspectRatio: 1, child: SkeletonBox(radius: 0)),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                SkeletonCircle(size: 26),
                SizedBox(width: 14),
                SkeletonCircle(size: 26),
                SizedBox(width: 14),
                SkeletonCircle(size: 26),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SkeletonLine(widthFactor: 0.7),
          ),
        ],
      ),
    );
  }
}

/// A 3-column grid of square tiles (profile post grids).
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({super.key, this.count = 9});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [for (var i = 0; i < count; i++) const SkeletonBox(radius: 0)],
    );
  }
}

/// A profile header: big avatar with stat columns, name and bio lines.
class SkeletonProfileHeader extends StatelessWidget {
  const SkeletonProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonCircle(size: 84),
              const SizedBox(width: 24),
              for (var i = 0; i < 3; i++)
                const Expanded(
                  child: Column(
                    children: [
                      SkeletonBox(width: 32, height: 18),
                      SizedBox(height: 6),
                      SkeletonBox(width: 52, height: 10),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const SkeletonLine(widthFactor: 0.45, height: 14),
          const SizedBox(height: 8),
          const SkeletonLine(widthFactor: 0.8, height: 11),
          const SizedBox(height: 16),
          const SkeletonBox(height: 36, radius: 10),
        ],
      ),
    );
  }
}
