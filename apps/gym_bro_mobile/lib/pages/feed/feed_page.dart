import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/l10n.dart';
import '../../models/draft.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/post_upload_queue.dart';
import '../../utils/haptics.dart';
import '../../widgets/drafts.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/post_card.dart';
import '../../widgets/posting_bar.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/social_widgets.dart';
import '../people/discover_page.dart';
import '../reels/reels_page.dart';
import '../stories/story_composer_page.dart';
import '../stories/story_tray.dart';
import 'create_post_page.dart';

class _FeedState {
  List<Post> posts = const [];
  int page = 0;
  bool hasMore = true;
  bool loading = false;
  bool loaded = false;
  bool loadingMore = false;
  String? error;
  int gen = 0;
  double offset = 0;
}

/// The social feed tab body (it lives inside the home shell's Scaffold):
/// a "share something" row (with the [ReelsPage] entry), Home / Explore
/// switch and an endless list of [PostCard]s with pull-to-refresh.
///
/// New posts publish in the background ([PostUploadQueue]): a "Posting…"
/// bar sits at the top while they upload, and each one fades into the top
/// of Home once it's out.
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  static const _pageSize = 15;

  final _api = ApiService();
  final _scroll = ScrollController();
  final _feeds = {false: _FeedState(), true: _FeedState()};
  final _tray = GlobalKey<StoryTrayState>();
  bool _explore = false;

  final _queue = PostUploadQueue.instance;
  StreamSubscription<Post>? _postedSub;

  /// Queued posts already seen (a new one brings Home to the top).
  final Set<String> _seenPending = {};

  /// Posts that just came out of the queue: they fade in once.
  final Set<String> _fresh = {};

  _FeedState get _current => _feeds[_explore]!;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _seenPending.addAll(_queue.items.map((p) => p.id));
    _queue.addListener(_onQueue);
    _postedSub = _queue.posted.listen(_onPosted);
    _load(false);
  }

  @override
  void dispose() {
    _queue.removeListener(_onQueue);
    _postedSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// A post was just queued: show Home from the top, where its bar is.
  void _onQueue() {
    var added = false;
    for (final p in _queue.items) {
      if (_seenPending.add(p.id)) added = true;
    }
    if (!added || !mounted) return;
    _switchMode(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  /// A queued post is out: it slides into the top of Home.
  void _onPosted(Post post) {
    if (!mounted) return;
    Haptics.tap();
    final home = _feeds[false]!;
    setState(() {
      _fresh.add(post.id);
      home.posts = [post, ...home.posts.where((p) => p.id != post.id)];
    });
    Future.delayed(const Duration(seconds: 2), () => _fresh.remove(post.id));
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 900) _loadMore(_explore);
  }

  Future<void> _load(bool explore) async {
    final st = _feeds[explore]!;
    final gen = ++st.gen;
    setState(() {
      st.loading = true;
      st.loadingMore = false;
      st.error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final posts = await _api.getFeed(token, explore: explore, pageSize: _pageSize);
      if (!mounted || gen != st.gen) return;
      setState(() {
        st.posts = posts;
        st.page = 0;
        st.hasMore = posts.length >= _pageSize;
        st.loading = false;
        st.loaded = true;
      });
    } catch (e) {
      if (!mounted || gen != st.gen) return;
      setState(() {
        st.error = _msg(e);
        st.loading = false;
      });
    }
  }

  Future<void> _loadMore(bool explore) async {
    final st = _feeds[explore]!;
    if (st.loading || st.loadingMore || !st.hasMore || !st.loaded) return;
    final gen = st.gen;
    setState(() => st.loadingMore = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final posts = await _api.getFeed(token, explore: explore, page: st.page + 1, pageSize: _pageSize);
      if (!mounted || gen != st.gen) return;
      final known = st.posts.map((p) => p.id).toSet();
      setState(() {
        st.posts = [...st.posts, ...posts.where((p) => !known.contains(p.id))];
        st.page++;
        st.hasMore = posts.length >= _pageSize;
        st.loadingMore = false;
      });
    } catch (e) {
      if (!mounted || gen != st.gen) return;
      setState(() => st.loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  void _replace(Post updated) {
    if (!mounted) return;
    setState(() {
      for (final st in _feeds.values) {
        st.posts = [for (final p in st.posts) p.id == updated.id ? updated : p];
      }
    });
  }

  void _remove(String id) {
    if (!mounted) return;
    setState(() {
      for (final st in _feeds.values) {
        st.posts = st.posts.where((p) => p.id != id).toList();
      }
    });
  }

  void _switchMode(bool explore) {
    if (explore == _explore) return;
    if (_scroll.hasClients) _current.offset = _scroll.offset;
    setState(() => _explore = explore);
    if (!_current.loaded && !_current.loading) _load(explore);
    final target = _current.offset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  Future<void> _create({bool pick = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final created = await openCreateWithDrafts<Post>(
      context,
      kind: DraftKind.post,
      fullscreenDialog: true,
      // Uploads in the background: the page closes right away (null) and
      // the post arrives through [_onPosted].
      builder: (draft) => CreatePostPage(pickOnOpen: pick && draft == null, draft: draft, background: true),
    );
    if (created == null || !mounted) return;
    final home = _feeds[false]!;
    setState(() => home.posts = [created, ...home.posts.where((p) => p.id != created.id)]);
    _switchMode(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
    messenger.showSnackBar(SnackBar(content: Text(l10n.feedPosted)));
  }

  Future<void> _newStory() async {
    // Queued: its progress shows in the "Posting…" bar, and the tray
    // reloads once it's out.
    final pending = await openStoryComposer(context);
    if (pending != null) Haptics.tap();
  }

  @override
  Widget build(BuildContext context) {
    final st = _current;
    return RefreshIndicator(
      onRefresh: () => Haptics.refreshed(
        () => Future.wait([_load(_explore), if (_tray.currentState != null) _tray.currentState!.refresh()]),
      ),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _constrained(PostingBar(queue: _queue))),
          SliverToBoxAdapter(child: _constrained(StoryTray(key: _tray))),
          SliverToBoxAdapter(child: _constrained(_composerRow(context))),
          SliverToBoxAdapter(child: _constrained(_modeSwitch(context))),
          ..._content(context, st),
        ],
      ),
    );
  }

  Widget _constrained(Widget child) => Center(
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: child),
  );

  Widget _composerRow(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final me = AuthManager.instance.profile;
    final initials = me == null
        ? '?'
        : '${me.name.isNotEmpty ? me.name[0] : ''}${me.lastName.isNotEmpty ? me.lastName[0] : ''}'.toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
      child: Row(children: [
        ExcludeSemantics(child: UserAvatar(url: me?.avatarUrl, initials: initials.isEmpty ? '?' : initials)),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: _create,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(
                  l10n.feedComposerHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.postsReels,
          icon: Icon(Icons.smart_display_outlined, color: cs.primary),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReelsPage())),
        ),
        IconButton(
          tooltip: l10n.storyNew,
          icon: Icon(Icons.history_toggle_off, color: cs.primary),
          onPressed: _newStory,
        ),
        IconButton(
          tooltip: l10n.feedAddMedia,
          icon: Icon(Icons.add_photo_alternate_outlined, color: cs.primary),
          onPressed: () => _create(pick: true),
        ),
      ]),
    );
  }

  Widget _modeSwitch(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          ButtonSegment(value: false, icon: const Icon(Icons.home_outlined, size: 18), label: Text(l10n.feedTabHome)),
          ButtonSegment(value: true, icon: const Icon(Icons.explore_outlined, size: 18), label: Text(l10n.feedTabExplore)),
        ],
        selected: {_explore},
        onSelectionChanged: (s) => _switchMode(s.first),
      ),
    );
  }

  List<Widget> _content(BuildContext context, _FeedState st) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (st.posts.isEmpty) {
      if (st.loading || !st.loaded && st.error == null) {
        return [
          SliverToBoxAdapter(
            child: _constrained(
              const Skeleton(child: Column(children: [SkeletonPostCard(), SkeletonPostCard()])),
            ),
          ),
        ];
      }
      if (st.error != null) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.cloud_off_outlined, size: 44, color: cs.error),
                  const SizedBox(height: 12),
                  Text(st.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => _load(_explore), child: Text(l10n.commonRetry)),
                ]),
              ),
            ),
          ),
        ];
      }
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _explore
              ? EmptyState(
                  icon: Icons.explore_outlined,
                  title: l10n.feedEmptyExploreTitle,
                  message: l10n.feedEmptyExploreBody,
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    EmptyState(
                      icon: Icons.dynamic_feed_outlined,
                      title: l10n.feedEmptyHomeTitle,
                      message: l10n.feedEmptyHomeBody,
                      actionLabel: l10n.polishFeedFindPeople,
                      actionIcon: Icons.person_search_outlined,
                      onAction: () => openDiscover(context),
                    ),
                    TextButton.icon(
                      onPressed: () => _switchMode(true),
                      icon: const Icon(Icons.explore_outlined),
                      label: Text(l10n.feedExploreAction),
                    ),
                  ],
                ),
        ),
      ];
    }
    return [
      if (st.loading) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
      SliverList.builder(
        itemCount: st.posts.length,
        itemBuilder: (context, i) {
          final post = st.posts[i];
          Widget card = PostCard(
            key: ValueKey(post.id),
            post: post,
            heroScope: 'feed',
            onChanged: _replace,
            onDeleted: () => _remove(post.id),
          );
          if (_fresh.contains(post.id) && !MediaQuery.disableAnimationsOf(context)) {
            card = card
                .animate(key: ValueKey('fresh-${post.id}'))
                .fadeIn(duration: 350.ms)
                .slideY(begin: -0.08, end: 0, duration: 350.ms, curve: Curves.easeOutCubic);
          }
          return _constrained(card);
        },
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Center(
            child: st.loadingMore
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : st.hasMore
                ? const SizedBox(height: 24)
                : Text(l10n.feedEndOfFeed, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ),
      ),
    ];
  }
}
