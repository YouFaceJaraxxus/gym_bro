import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../widgets/post_grid.dart';

/// Posts I reacted to, most recent reaction first, as a grid or a list of
/// cards. Taking my reaction back drops a post from here.
class LikedPostsPage extends StatefulWidget {
  const LikedPostsPage({super.key});

  @override
  State<LikedPostsPage> createState() => _LikedPostsPageState();
}

class _LikedPostsPageState extends State<LikedPostsPage> {
  final _api = ApiService();
  bool _list = false;

  Future<List<Post>> _load(String token, int page, int pageSize) =>
      _api.getLikedPosts(token, page: page, pageSize: pageSize);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.postsLikedTitle),
        actions: [
          IconButton(
            tooltip: _list ? l10n.postsGridView : l10n.postsListView,
            icon: Icon(_list ? Icons.grid_on_rounded : Icons.view_agenda_outlined),
            onPressed: () => setState(() => _list = !_list),
          ),
        ],
      ),
      body: PagedPostGrid(
        key: ValueKey(_list),
        load: _load,
        pageSize: _list ? 10 : 30,
        asList: _list,
        // In the list a reaction can be tapped off and on again in place.
        dropWhen: _list ? null : (p) => p.myReaction == null,
        empty: PostsEmptyState(
          icon: Icons.favorite_border_rounded,
          title: l10n.postsNoLikedTitle,
          body: l10n.postsNoLikedBody,
        ),
      ),
    );
  }
}
