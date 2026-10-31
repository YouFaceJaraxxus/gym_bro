import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/mention.dart';
import '../models/post.dart';
import '../pages/feed/post_detail_page.dart';
import '../services/auth_manager.dart';
import 'post_card.dart';
import 'post_attachment_card.dart';
import 'social_widgets.dart';
import 'video_frame_thumb.dart';

/// Instagram-style profile grid: three square tiles per row.
///
/// * photo → its thumbnail;
/// * video → a frame of it with ▶ and the duration;
/// * text-only post → the caption on a tinted tile;
/// * shared workout/meal/item without media → its picture, or its kind and
///   title on a tinted tile (a small badge marks shared things);
/// * several media → a "multiple" badge at the top right;
/// * pinned to the profile → a pin at the top left ([showPinned]).
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
    this.showPinned = true,
  });

  final List<Post> posts;
  final ValueChanged<Post> onTap;

  /// Mark pinned posts (the author's own grid); off for other lists.
  final bool showPinned;
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
    itemBuilder: (context, i) => PostGridTile(post: posts[i], showPinned: showPinned, onTap: () => onTap(posts[i])),
  );
}

class SliverPostGrid extends StatelessWidget {
  const SliverPostGrid({super.key, required this.posts, required this.onTap, this.showPinned = true});

  final List<Post> posts;
  final ValueChanged<Post> onTap;

  /// Mark pinned posts (the author's own grid); off for other lists.
  final bool showPinned;

  @override
  Widget build(BuildContext context) => SliverGrid.builder(
    gridDelegate: _gridDelegate,
    itemCount: posts.length,
    itemBuilder: (context, i) => PostGridTile(post: posts[i], showPinned: showPinned, onTap: () => onTap(posts[i])),
  );
}

/// One square tile of [PostGrid].
class PostGridTile extends StatelessWidget {
  const PostGridTile({super.key, required this.post, required this.onTap, this.showPinned = true});

  final Post post;
  final VoidCallback onTap;
  final bool showPinned;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final media = [...post.images]..sort((a, b) => a.position.compareTo(b.position));
    final first = media.isEmpty ? null : media.first;

    final caption = mentionPlainText(post.content);
    final attachment = post.isTyped ? post.attachment : null;
    final Widget content;
    final String label;
    if (first == null && attachment != null) {
      final kind = postTypeLabel(l10n, post.postType);
      final title = attachment.title;
      label = [kind, ?title, if (caption.isNotEmpty) caption].join(', ');
      content = attachment.imageUrl != null
          ? MediaImage(url: attachment.imageUrl!)
          : Container(
              color: cs.primaryContainer,
              padding: const EdgeInsets.all(8),
              alignment: Alignment.center,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(postTypeIcon(post.postType), color: cs.onPrimaryContainer, size: 26),
                const SizedBox(height: 4),
                Text(
                  title ?? kind,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
                ),
              ]),
            );
    } else if (first == null) {
      label = caption;
      content = Container(
        color: cs.surfaceContainerHighest,
        padding: const EdgeInsets.all(8),
        alignment: Alignment.center,
        child: Text(
          caption,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface),
        ),
      );
    } else if (first.isVideo) {
      label = l10n.feedVideo;
      content = VideoFrameThumb(
        url: first.url,
        iconSize: 34,
        caption: first.durationMs == null ? null : formatDuration(first.durationMs!),
      );
    } else {
      label = caption.isNotEmpty ? caption : l10n.nutritionPostPhoto;
      content = MediaImage(url: first.url);
    }

    final pinned = showPinned && post.pinned;
    final semantics = [
      if (pinned) l10n.postsPinned,
      label,
      if (media.length > 1) l10n.feedMultipleMedia,
    ].join(', ');
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(fit: StackFit.expand, children: [
          content,
          if (pinned)
            const Positioned(
              top: 6,
              left: 6,
              child: Icon(Icons.push_pin_rounded, size: 16, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
            ),
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
            )
          else if (attachment != null && (first != null || attachment.imageUrl != null))
            Positioned(
              top: 6,
              right: 6,
              child: Icon(
                postTypeIcon(post.postType),
                size: 16,
                color: Colors.white,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Paged grid ────────────────────────────────────────────────────────────────

/// Loads one page of posts.
typedef PostPageLoader = Future<List<Post>> Function(String token, int page, int pageSize);

/// A scrollable, paged list of posts as a [SliverPostGrid] (or [PostCard]s
/// with [asList]) with pull-to-refresh and loading more near the end.
/// Tapping a tile opens [PostDetailPage]; changes there come back into the
/// list, and posts matching [dropWhen] afterwards leave it (e.g. unsaved).
/// [load] is read on every fetch; give the widget a new key to start over
/// with a different source.
class PagedPostGrid extends StatefulWidget {
  const PagedPostGrid({
    super.key,
    required this.load,
    this.pageSize = 30,
    this.header = const [],
    this.empty,
    this.asList = false,
    this.dropWhen,
    this.onTotalChanged,
  });

  final PostPageLoader load;
  final int pageSize;

  /// Slivers above the posts.
  final List<Widget> header;

  /// Shown when there are no posts.
  final Widget? empty;
  final bool asList;
  final bool Function(Post post)? dropWhen;

  /// Posts were dropped or deleted ([delta] < 0).
  final ValueChanged<int>? onTotalChanged;

  @override
  State<PagedPostGrid> createState() => PagedPostGridState();
}

class PagedPostGridState extends State<PagedPostGrid> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  List<Post> _posts = const [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _gen = 0;

  List<Post> get posts => _posts;

  // Tabs keep their pages and scroll position.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 600) _loadMore();
  }

  /// Reloads from the first page.
  Future<void> refresh() async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final posts = await widget.load(token, 0, widget.pageSize);
      if (!mounted || gen != _gen) return;
      setState(() {
        _posts = posts;
        _page = 0;
        _hasMore = posts.length >= widget.pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = _msg(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _error != null) return;
    final gen = _gen;
    setState(() => _loadingMore = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final more = await widget.load(token, _page + 1, widget.pageSize);
      if (!mounted || gen != _gen) return;
      final known = _posts.map((p) => p.id).toSet();
      setState(() {
        _posts = [..._posts, ...more.where((p) => !known.contains(p.id))];
        _page++;
        _hasMore = more.length >= widget.pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  void _replace(Post updated) {
    if (!mounted) return;
    if (widget.dropWhen?.call(updated) == true) {
      _remove(updated.id);
      return;
    }
    setState(() => _posts = [for (final p in _posts) p.id == updated.id ? updated : p]);
  }

  void _remove(String id) {
    if (!mounted || !_posts.any((p) => p.id == id)) return;
    setState(() => _posts = _posts.where((p) => p.id != id).toList());
    widget.onTotalChanged?.call(-1);
  }

  void _open(Post post) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PostDetailPage(
        postId: post.id,
        initial: post,
        onChanged: _replace,
        onDeleted: () => _remove(post.id),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final Widget body;
    if (_posts.isEmpty && _loading) {
      body = const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()));
    } else if (_posts.isEmpty && _error != null) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_off_outlined, size: 44, color: cs.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: refresh, child: Text(l10n.commonRetry)),
            ]),
          ),
        ),
      );
    } else if (_posts.isEmpty) {
      body = SliverFillRemaining(hasScrollBody: false, child: Center(child: widget.empty ?? const SizedBox.shrink()));
    } else if (widget.asList) {
      body = SliverList.builder(
        itemCount: _posts.length,
        itemBuilder: (context, i) {
          final post = _posts[i];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: PostCard(
                key: ValueKey(post.id),
                post: post,
                onChanged: _replace,
                onDeleted: () => _remove(post.id),
              ),
            ),
          );
        },
      );
    } else {
      body = SliverPostGrid(posts: _posts, onTap: _open, showPinned: false);
    }
    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...widget.header,
          if (_loading && _posts.isNotEmpty) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
          body,
          if (_posts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: _loadingMore
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const SizedBox(height: 24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An icon, a title and a line of text, centred (empty lists).
class PostsEmptyState extends StatelessWidget {
  const PostsEmptyState({super.key, required this.icon, required this.title, this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 52, color: cs.outline),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(body!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ]),
    );
  }
}
