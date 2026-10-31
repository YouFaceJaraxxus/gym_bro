import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/post_grid.dart';
import 'save_collection_sheet.dart';

/// My saved posts (Instagram's "Saved"): "All posts" first, then my
/// collections, each a tile of up to four covers. Tapping one opens its
/// posts; collections can be created here and renamed / deleted inside.
class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  final _api = ApiService();
  SavedOverview? _overview;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final overview = await _api.getSaveCollections(token);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _msg(e);
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final name = await promptCollectionName(context, title: l10n.postsNewCollection);
    if (name == null || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.createSaveCollection(token, name);
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  Future<void> _open(SaveCollection? collection) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SavedCollectionPage(collection: collection)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final o = _overview;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.postsSavedTitle),
        actions: [
          IconButton(tooltip: l10n.postsNewCollection, icon: const Icon(Icons.add), onPressed: _create),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(children: [
                  Icon(Icons.lock_outline, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.postsSavedOnlyYou,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ]),
              ),
            ),
            if (o == null && _loading)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else if (o == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error ?? '', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: Text(l10n.commonRetry)),
                  ]),
                ),
              )
            else if (o.saved.postCount == 0 && o.collections.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: PostsEmptyState(
                    icon: Icons.bookmark_border,
                    title: l10n.postsNoSavedTitle,
                    body: l10n.postsNoSavedBody,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildListDelegate([
                    CollectionTile(
                      name: l10n.postsAllPosts,
                      postCount: o.saved.postCount,
                      covers: o.saved.covers,
                      onTap: () => _open(null),
                    ),
                    for (final c in o.collections)
                      CollectionTile(name: c.name, postCount: c.postCount, covers: c.covers, onTap: () => _open(c)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A collection as a square of 2×2 covers with its name and post count.
class CollectionTile extends StatelessWidget {
  const CollectionTile({super.key, required this.name, required this.postCount, required this.covers, required this.onTap});

  final String name;
  final int postCount;
  final List<SaveCover> covers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final count = l10n.postsPostCount(postCount);
    return Semantics(
      button: true,
      label: '$name, $count',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: cs.surfaceContainerHighest,
                child: covers.isEmpty
                    ? Center(child: Icon(Icons.bookmark_border, size: 36, color: cs.onSurfaceVariant))
                    : covers.length == 1
                    ? SizedBox.expand(child: CoverThumb(cover: covers.first))
                    : GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 1.5,
                        crossAxisSpacing: 1.5,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: [
                          for (var i = 0; i < 4; i++)
                            i < covers.length ? CoverThumb(cover: covers[i]) : ColoredBox(color: cs.surfaceContainerHigh),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          Text(count, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

enum _CollectionAction { rename, delete }

/// The posts of one collection, or of "All posts" when [collection] is null
/// (newest save first). A collection can be renamed or deleted (its posts
/// stay saved). Posts I unsave elsewhere leave the grid.
class SavedCollectionPage extends StatefulWidget {
  const SavedCollectionPage({super.key, this.collection});

  final SaveCollection? collection;

  @override
  State<SavedCollectionPage> createState() => _SavedCollectionPageState();
}

class _SavedCollectionPageState extends State<SavedCollectionPage> {
  final _api = ApiService();
  late String? _name = widget.collection?.name;

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<List<Post>> _loadPage(String token, int page, int pageSize) =>
      _api.getSavedPosts(token, collectionId: widget.collection?.id, page: page, pageSize: pageSize);

  Future<void> _onAction(_CollectionAction action) async {
    final c = widget.collection;
    if (c == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case _CollectionAction.rename:
        final name = await promptCollectionName(context, title: l10n.postsRenameCollection, initial: _name ?? c.name);
        if (name == null || name == _name || !mounted) return;
        try {
          final token = await AuthManager.instance.getValidToken();
          final renamed = await _api.renameSaveCollection(token, c.id, name);
          if (mounted) setState(() => _name = renamed.name.isEmpty ? name : renamed.name);
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(_msg(e))));
        }
      case _CollectionAction.delete:
        final nav = Navigator.of(context);
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.l10n.postsDeleteCollectionTitle(_name ?? c.name)),
            content: Text(ctx.l10n.postsDeleteCollectionBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.commonDelete)),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        try {
          final token = await AuthManager.instance.getValidToken();
          await _api.deleteSaveCollection(token, c.id);
          nav.pop();
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(_msg(e))));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isCollection = widget.collection != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(_name ?? l10n.postsAllPosts),
        actions: [
          if (isCollection)
            PopupMenuButton<_CollectionAction>(
              onSelected: _onAction,
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: _CollectionAction.rename,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(l10n.postsRenameCollection),
                  ),
                ),
                PopupMenuItem(
                  value: _CollectionAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_outline),
                    title: Text(l10n.postsDeleteCollection),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: PagedPostGrid(
        load: _loadPage,
        dropWhen: (p) => !p.savedByMe,
        empty: PostsEmptyState(
          icon: Icons.bookmark_border,
          title: isCollection ? l10n.postsCollectionEmpty : l10n.postsNoSavedTitle,
          body: isCollection ? null : l10n.postsNoSavedBody,
        ),
      ),
    );
  }
}
