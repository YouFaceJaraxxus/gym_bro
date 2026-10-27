import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/post.dart';
import 'social_widgets.dart';

/// Instagram-style profile grid: three square tiles per row.
///
/// * photo → its thumbnail;
/// * video → a dark tile with ▶ and the duration (no frame decoding);
/// * text-only post → the caption on a tinted tile;
/// * several media → a "multiple" badge at the top right.
///
/// [PostGrid] is a box widget (shrink-wrapped, not scrollable by default);
/// [SliverPostGrid] goes straight into a `CustomScrollView`.
const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  mainAxisSpacing: 2,
  crossAxisSpacing: 2,
);

class PostGrid extends StatelessWidget {
  const PostGrid({
    super.key,
    required this.posts,
    required this.onTap,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  final List<Post> posts;
  final ValueChanged<Post> onTap;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => GridView.builder(
    controller: controller,
    shrinkWrap: shrinkWrap,
    physics: physics,
    padding: padding,
    gridDelegate: _gridDelegate,
    itemCount: posts.length,
    itemBuilder: (context, i) => PostGridTile(post: posts[i], onTap: () => onTap(posts[i])),
  );
}

class SliverPostGrid extends StatelessWidget {
  const SliverPostGrid({super.key, required this.posts, required this.onTap});

  final List<Post> posts;
  final ValueChanged<Post> onTap;

  @override
  Widget build(BuildContext context) => SliverGrid.builder(
    gridDelegate: _gridDelegate,
    itemCount: posts.length,
    itemBuilder: (context, i) => PostGridTile(post: posts[i], onTap: () => onTap(posts[i])),
  );
}

/// One square tile of [PostGrid].
class PostGridTile extends StatelessWidget {
  const PostGridTile({super.key, required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final media = [...post.images]..sort((a, b) => a.position.compareTo(b.position));
    final first = media.isEmpty ? null : media.first;

    final Widget content;
    final String label;
    if (first == null) {
      label = post.content;
      content = Container(
        color: cs.surfaceContainerHighest,
        padding: const EdgeInsets.all(8),
        alignment: Alignment.center,
        child: Text(
          post.content,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface),
        ),
      );
    } else if (first.isVideo) {
      label = l10n.feedVideo;
      content = Container(
        color: const Color(0xFF1C1C1E),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
          if (first.durationMs != null)
            Text(formatDuration(first.durationMs!), style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
    } else {
      label = post.content.isNotEmpty ? post.content : l10n.nutritionPostPhoto;
      content = MediaImage(url: first.url);
    }

    return Semantics(
      button: true,
      label: media.length > 1 ? '$label, ${l10n.feedMultipleMedia}' : label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(fit: StackFit.expand, children: [
          content,
          if (media.length > 1)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.filter_none_rounded, size: 16, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
            )
          else if (first != null && first.isVideo)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.videocam_rounded, size: 16, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
            ),
        ]),
      ),
    );
  }
}
