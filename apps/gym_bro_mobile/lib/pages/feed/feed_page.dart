import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/draft.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/drafts.dart';
import '../../widgets/post_card.dart';
import '../../widgets/social_widgets.dart';
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
/// a "share something" row, Home / Explore switch and an endless list of
/// [PostCard]s with pull-to-refresh.
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
  bool _explore = false;

  _FeedState get _current => _feeds[_explore]!;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(false);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
      builder: (draft) => CreatePostPage(pickOnOpen: pick && draft == null, draft: draft),
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

  @override
  Widget build(BuildContext context) {
    final st = _current;
    return RefreshIndicator(
      onRefresh: () => _load(_explore),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
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
        return const [SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))];
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(_explore ? Icons.explore_outlined : Icons.dynamic_feed_outlined, size: 52, color: cs.outline),
                const SizedBox(height: 16),
                Text(
                  _explore ? l10n.feedEmptyExploreTitle : l10n.feedEmptyHomeTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  _explore ? l10n.feedEmptyExploreBody : l10n.feedEmptyHomeBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                if (!_explore) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () => _switchMode(true),
                    icon: const Icon(Icons.explore_outlined),
                    label: Text(l10n.feedExploreAction),
                  ),
                ],
              ]),
            ),
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
          return _constrained(PostCard(
            key: ValueKey(post.id),
            post: post,
            onChanged: _replace,
            onDeleted: () => _remove(post.id),
          ));
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
