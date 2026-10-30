import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/post.dart';
import '../../models/reaction.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/social_widgets.dart';
import '../people/user_profile_page.dart';
import '../../widgets/app_bottom_sheet.dart';

/// "Who reacted": a tab for everyone plus one per emoji (with counts), each a
/// paginated list of people. Tapping a person opens their profile.
Future<void> showReactionsSheet(BuildContext context, Post post) {
  if (post.reactions.total == 0) return Future.value();
  return showAppBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _ReactionsSheet(post: post),
  );
}

/// Per-emoji counts for a comment (the API doesn't list who reacted to
/// comments).
Future<void> showReactionBreakdownSheet(BuildContext context, ReactionSummary summary) {
  if (summary.total == 0) return Future.value();
  final entries = summary.counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return showAppBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final l10n = ctx.l10n;
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l10n.reactionCount(summary.total), style: Theme.of(ctx).textTheme.titleMedium),
          ),
          for (final e in entries)
            ListTile(
              dense: true,
              leading: Text(e.key.emoji, style: const TextStyle(fontSize: 24)),
              title: Text(e.key.label(l10n)),
              trailing: Text('${e.value}', style: Theme.of(ctx).textTheme.titleSmall),
            ),
          const SizedBox(height: 8),
        ]),
      );
    },
  );
}

class _ReactionsSheet extends StatelessWidget {
  const _ReactionsSheet({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final types = post.reactions.counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.index.compareTo(b.key.index));
    final tabs = <ReactionType?>[null, ...types.map((e) => e.key)];
    return DefaultTabController(
      length: tabs.length,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.feedReactionsTitle, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final t in tabs)
                Tab(
                  child: Semantics(
                    label: t == null
                        ? l10n.feedReactionsAll(post.reactions.total)
                        : '${t.label(l10n)} ${post.reactions.counts[t] ?? 0}',
                    excludeSemantics: true,
                    child: Text(
                      t == null ? l10n.feedReactionsAll(post.reactions.total) : '${t.emoji} ${post.reactions.counts[t] ?? 0}',
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: TabBarView(children: [
              for (final t in tabs) _ReactorList(key: PageStorageKey(t?.apiValue ?? 'all'), postId: post.id, reaction: t),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ReactorList extends StatefulWidget {
  const _ReactorList({super.key, required this.postId, this.reaction});

  final String postId;
  final ReactionType? reaction;

  @override
  State<_ReactorList> createState() => _ReactorListState();
}

class _ReactorListState extends State<_ReactorList> with AutomaticKeepAliveClientMixin {
  /// The API's default page size for GET /posts/:id/reactions.
  static const _pageSize = 50;

  final _api = ApiService();
  final List<Reactor> _items = [];
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await _api.getPostReactions(token, widget.postId, reaction: widget.reaction);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(rows);
        _page = 0;
        _hasMore = rows.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await _api.getPostReactions(token, widget.postId, reaction: widget.reaction, page: _page + 1);
      if (!mounted) return;
      final known = _items.map((r) => r.user.id).toSet();
      setState(() {
        _items.addAll(rows.where((r) => !known.contains(r.user.id)));
        _page++;
        _hasMore = rows.length >= _pageSize;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(l10n.commonRetry)),
          ]),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(child: Text(l10n.feedNoReactions, style: TextStyle(color: cs.onSurfaceVariant)));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 300) _loadMore();
        return false;
      },
      child: ListView.builder(
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          final r = _items[i];
          final name = r.user.fullName.isNotEmpty ? r.user.fullName : l10n.nutritionDeletedUser;
          return ListTile(
            leading: Stack(clipBehavior: Clip.none, children: [
              UserAvatar(url: r.user.avatarUrl, initials: r.user.initials),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
                  child: Text(r.reaction.emoji, semanticsLabel: r.reaction.label(l10n), style: const TextStyle(fontSize: 13)),
                ),
              ),
            ]),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: r.username.isNotEmpty ? Text('@${r.username}', maxLines: 1, overflow: TextOverflow.ellipsis) : null,
            onTap: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(MaterialPageRoute(builder: (_) => UserProfilePage(userId: r.user.id)));
            },
          );
        },
      ),
    );
  }
}
