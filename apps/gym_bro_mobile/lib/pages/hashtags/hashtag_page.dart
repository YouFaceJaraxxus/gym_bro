import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/post_grid.dart';

/// Posts with a hashtag (Instagram): "#tag" with how many posts use it, then
/// Top / Recent tabs, each a paged grid.
class HashtagPage extends StatefulWidget {
  const HashtagPage({super.key, required this.tag});

  /// With or without "#", any case.
  final String tag;

  @override
  State<HashtagPage> createState() => _HashtagPageState();
}

class _HashtagPageState extends State<HashtagPage> {
  final _api = ApiService();
  late final String _tag = normalizeHashtag(widget.tag) ?? widget.tag.replaceFirst('#', '').toLowerCase();
  int? _count;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final info = await _api.getHashtag(token, _tag);
      if (mounted) setState(() => _count = info.postCount);
    } catch (_) {
      // The header just goes without a count.
    }
  }

  Future<List<Post>> Function(String, int, int) _loader(String sort) =>
      (token, page, pageSize) => _api.getHashtagPosts(token, _tag, sort: sort, page: page, pageSize: pageSize);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('#$_tag'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(128),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: cs.primaryContainer,
                    child: Text('#', style: tt.headlineMedium?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('#$_tag', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        _count == null ? ' ' : l10n.postsPostCount(_count!),
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ]),
                  ),
                ]),
              ),
              TabBar(tabs: [Tab(text: l10n.postsTabTop), Tab(text: l10n.postsTabRecent)]),
            ]),
          ),
        ),
        body: TabBarView(children: [
          for (final sort in const ['top', 'recent'])
            PagedPostGrid(
              key: PageStorageKey('hashtag-$_tag-$sort'),
              load: _loader(sort),
              empty: PostsEmptyState(icon: Icons.tag, title: l10n.postsHashtagEmpty),
            ),
        ]),
      ),
    );
  }
}
