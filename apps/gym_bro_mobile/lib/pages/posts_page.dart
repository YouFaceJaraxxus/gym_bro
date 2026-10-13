import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/post.dart';
import '../models/social.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/image_upload_field.dart';

/// Community feed for a gym or shop. Staff (owners/trainers/employees/vendors)
/// can post announcements; everyone with access to the business can read them.
class PostsPage extends StatefulWidget {
  const PostsPage({
    super.key,
    required this.businessId,
    required this.businessName,
    this.canPost = false,
  });

  final String businessId;
  final String businessName;
  final bool canPost;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  final _api = ApiService();
  List<Post> _posts = [];
  bool _loading = true;
  String? _error;

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
      final posts = await _api.getPosts(token, businessId: widget.businessId);
      if (mounted) setState(() { _posts = posts; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  final Set<String> _likePending = {};

  /// Optimistic like toggle: flip immediately, reconcile with the server's
  /// count, revert on failure.
  Future<void> _toggleLike(Post post) async {
    if (_likePending.contains(post.id)) return;
    final optimistic = post.toggledLike();
    _replacePost(optimistic);
    _likePending.add(post.id);
    try {
      final token = await AuthManager.instance.getValidToken();
      final result = optimistic.likedByMe
          ? await _api.likePost(token, post.id)
          : await _api.unlikePost(token, post.id);
      _replacePost(_findPost(post.id)
          ?.copyWith(likedByMe: result.liked, likeCount: result.likeCount));
    } catch (e) {
      _replacePost(_findPost(post.id)
          ?.copyWith(likedByMe: post.likedByMe, likeCount: post.likeCount));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      _likePending.remove(post.id);
    }
  }

  Post? _findPost(String id) {
    for (final p in _posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _replacePost(Post? updated) {
    if (updated == null || !mounted) return;
    setState(() {
      _posts = [for (final p in _posts) p.id == updated.id ? updated : p];
    });
  }

  Future<void> _openComments(Post post) async {
    final count = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => PostCommentsPage(post: post)),
    );
    if (count != null) _replacePost(_findPost(post.id)?.copyWith(commentCount: count));
  }

  Future<void> _openCreatePost() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _PostFormPage(businessId: widget.businessId)),
    );
    if (created == true) _load();
  }

  Future<void> _openEditPost(Post post) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _PostFormPage(businessId: widget.businessId, post: post),
      ),
    );
    if (saved == true) _load();
  }

  /// The API lets only the author (or a super user) edit or delete a post.
  bool _canManage(Post post) {
    final profile = AuthManager.instance.profile;
    if (profile == null) return false;
    return profile.role == UserRole.superUser ||
        (post.authorId != null && post.authorId == profile.id);
  }

  Future<void> _delete(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.nutritionDeletePostTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.commonDelete)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deletePost(token, post.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nutritionCommunityTitle(widget.businessName))),
      floatingActionButton: widget.canPost
          ? FloatingActionButton.extended(
              onPressed: _openCreatePost,
              icon: const Icon(Icons.add),
              label: Text(l10n.nutritionNewPost),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(context.l10n.commonRetry)),
          ],
        ),
      );
    }
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(context.l10n.nutritionNoPostsYet),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: _posts.length,
        itemBuilder: (_, i) => _PostCard(
          post: _posts[i],
          canManage: _canManage(_posts[i]),
          onEdit: () => _openEditPost(_posts[i]),
          onDelete: () => _delete(_posts[i]),
          onLike: () => _toggleLike(_posts[i]),
          onComments: () => _openComments(_posts[i]),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.onLike,
    required this.onComments,
  });

  final Post post;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLike;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.images.length == 1)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                post.images.first.url,
                semanticLabel: l10n.nutritionPostPhoto,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            )
          else if (post.images.length > 1)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: PageView(
                children: post.images
                    .asMap()
                    .entries
                    .map((e) => Image.network(
                          e.value.url,
                          semanticLabel: l10n.nutritionPostPhotoOf(e.key + 1, post.images.length),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const SizedBox.shrink(),
                        ))
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (post.author != null) ...[
                      _Avatar(user: post.author!, radius: 14),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (post.author != null)
                            Text(
                              post.author!.fullName,
                              style: Theme.of(context).textTheme.labelLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            relativeTime(l10n, post.createdAt.toLocal()),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Theme.of(context).colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                    if (post.images.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          l10n.nutritionPhotoCount(post.images.length),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (canManage) ...[
                      IconButton(
                        tooltip: l10n.nutritionEditPost,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: onEdit,
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        tooltip: l10n.nutritionDeletePost,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: onDelete,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(post.content),
                if (post.updatedAt.difference(post.createdAt).inMinutes >= 1) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.nutritionEdited,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                _ActionButton(
                  tooltip: post.likedByMe ? l10n.nutritionUnlike : l10n.nutritionLike,
                  icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
                  color: post.likedByMe ? Theme.of(context).colorScheme.error : null,
                  label: post.likeCount == 0 ? l10n.nutritionLike : '${post.likeCount}',
                  semanticsLabel: l10n.nutritionLikeCount(post.likeCount),
                  selected: post.likedByMe,
                  onPressed: onLike,
                ),
                _ActionButton(
                  tooltip: l10n.nutritionComments,
                  icon: Icons.mode_comment_outlined,
                  label: post.commentCount == 0
                      ? l10n.nutritionComment
                      : l10n.nutritionCommentCount(post.commentCount),
                  onPressed: onComments,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.semanticsLabel,
    this.selected,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  /// Read instead of [label] (e.g. "3 likes" for "3").
  final String? semanticsLabel;

  /// Toggle state for screen readers (liked / not liked).
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        selected: selected,
        child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: fg),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: Icon(icon, key: ValueKey(icon), size: 20, color: fg),
        ),
        label: Text(label, semanticsLabel: semanticsLabel),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, this.radius = 18});
  final SocialUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = user.avatarUrl;
    // Decorative: the author's name is always shown next to it.
    return ExcludeSemantics(
      child: CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      foregroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: Text(
        user.initials,
        style: TextStyle(fontSize: radius * 0.75, color: cs.onPrimaryContainer),
      ),
      ),
    );
  }
}

// ── Comments ──────────────────────────────────────────────────────────────────

/// Comments on one post: oldest first, with a composer. Authors can edit and
/// delete their own comments; the business owner and super users can delete
/// any (the API computes `can_edit` / `can_delete`). Pops with the new
/// comment count.
class PostCommentsPage extends StatefulWidget {
  const PostCommentsPage({super.key, required this.post});
  final Post post;

  @override
  State<PostCommentsPage> createState() => _PostCommentsPageState();
}

class _PostCommentsPageState extends State<PostCommentsPage> {
  static const _pageSize = 50;

  final _api = ApiService();
  final _composer = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  List<PostComment> _comments = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  bool _sending = false;
  PostComment? _editing;
  late int _count = widget.post.commentCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _load() async {
    setState(() {
      _loading = _comments.isEmpty;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await _api.getPostComments(token, widget.post.id, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _comments = rows;
        _hasMore = rows.length == _pageSize;
        _loading = false;
        if (!_hasMore) _count = rows.length;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _msg(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final page = _comments.length ~/ _pageSize;
      final rows = await _api.getPostComments(token, widget.post.id,
          page: page, pageSize: _pageSize);
      if (!mounted) return;
      final known = _comments.map((c) => c.id).toSet();
      setState(() {
        _comments = [..._comments, ...rows.where((c) => !known.contains(c.id))];
        _hasMore = rows.length == _pageSize;
      });
    } catch (e) {
      if (mounted) _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _startEdit(PostComment c) {
    setState(() => _editing = c);
    _composer.text = c.body;
    _composer.selection = TextSelection.collapsed(offset: c.body.length);
    _focus.requestFocus();
  }

  void _cancelEdit() {
    setState(() => _editing = null);
    _composer.clear();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final editing = _editing;
      if (editing != null) {
        final updated = await _api.updatePostComment(token, editing.id, text);
        if (!mounted) return;
        setState(() {
          _comments = [for (final c in _comments) c.id == updated.id ? updated : c];
          _editing = null;
        });
      } else {
        final created = await _api.createPostComment(token, widget.post.id, text);
        if (!mounted) return;
        setState(() {
          // Only append when the whole thread is loaded; otherwise it lands on a
          // later page.
          if (!_hasMore) _comments = [..._comments, created];
          _count += 1;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
      _composer.clear();
    } catch (e) {
      if (mounted) _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(PostComment c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.nutritionDeleteCommentTitle),
        content: Text(ctx.l10n.nutritionCannotBeUndone),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.commonDelete)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deletePostComment(token, c.id);
      if (!mounted) return;
      setState(() {
        _comments = _comments.where((x) => x.id != c.id).toList();
        _count = _count > 0 ? _count - 1 : 0;
        if (_editing?.id == c.id) {
          _editing = null;
          _composer.clear();
        }
      });
    } catch (e) {
      if (mounted) _snack(_msg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<int>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _count);
      },
      child: Scaffold(
        appBar: AppBar(
            title: Text(_count == 0
                ? context.l10n.nutritionComments
                : context.l10n.nutritionCommentsWithCount(_count))),
        body: Column(
          children: [
            Expanded(child: _buildList()),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: cs.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: Text(context.l10n.commonRetry)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              widget.post.content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const Divider(height: 1),
          if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: cs.outline),
                  const SizedBox(height: 16),
                  Text(context.l10n.nutritionNoCommentsYet, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(context.l10n.nutritionStartConversation,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ..._comments.map(_buildComment),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : OutlinedButton(onPressed: _loadMore, child: Text(context.l10n.nutritionLoadMore)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComment(PostComment c) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final author = c.author;
    final l10n = context.l10n;
    return Container(
      color: _editing?.id == c.id ? cs.secondaryContainer.withValues(alpha: 0.4) : null,
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          author != null
              ? _Avatar(user: author)
              : ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.surfaceContainerHighest,
                    child: Icon(Icons.person_outline, size: 18, color: cs.onSurfaceVariant),
                  ),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(c.authorName(l10n), style: tt.labelLarge),
                    Text(
                      relativeTime(l10n, c.createdAt) + (c.isEdited ? ' · ${l10n.nutritionEditedLower}' : ''),
                      style: tt.bodySmall?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(c.body),
              ],
            ),
          ),
          if (c.canEdit || c.canDelete)
            PopupMenuButton<String>(
              tooltip: l10n.nutritionCommentOptions,
              icon: Icon(Icons.more_vert, size: 20, color: cs.onSurfaceVariant),
              onSelected: (v) => v == 'edit' ? _startEdit(c) : _delete(c),
              itemBuilder: (_) => [
                if (c.canEdit)
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(l10n.commonEdit),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (c.canDelete)
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text(l10n.commonDelete),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Material(
      color: cs.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_editing != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l10n.nutritionEditingComment,
                          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      tooltip: l10n.nutritionCancelEditing,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _cancelEdit,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: l10n.nutritionWriteCommentHint,
                        counterText: '',
                        isDense: true,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: _editing != null ? l10n.nutritionSaveComment : l10n.nutritionSendComment,
                    onPressed: _sending || _composer.text.trim().isEmpty ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_editing != null ? Icons.check : Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Create a post, or edit [post]'s text and images when given.
class _PostFormPage extends StatefulWidget {
  const _PostFormPage({required this.businessId, this.post});
  final String businessId;
  final Post? post;

  @override
  State<_PostFormPage> createState() => _PostFormPageState();
}

class _PostFormPageState extends State<_PostFormPage> {
  final _api = ApiService();
  late final TextEditingController _contentCtrl;
  late final List<String> _imageUrls;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.post != null;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: widget.post?.content ?? '');
    final images = [...?widget.post?.images]
      ..sort((a, b) => a.position.compareTo(b.position));
    _imageUrls = images.map((i) => i.url).toList();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    await pickAndUploadImage(
      context: context,
      bucket: 'media',
      folder: 'posts',
      onUploaded: (url) {
        if (mounted) setState(() => _imageUrls.add(url));
      },
      onUploadingChanged: (v) {
        if (mounted) setState(() => _uploading = v);
      },
    );
  }

  Future<void> _submit() async {
    if (_contentCtrl.text.trim().isEmpty) {
      setState(() => _error = context.l10n.nutritionWriteSomethingFirst);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final images = _imageUrls
          .asMap()
          .entries
          .map((e) => {'url': e.value, 'position': e.key})
          .toList();
      if (_isEditing) {
        await _api.updatePost(token, widget.post!.id, {
          'content': _contentCtrl.text.trim(),
          'images': images,
        });
      } else {
        await _api.createPost(token, {
          'business_id': widget.businessId,
          'content': _contentCtrl.text.trim(),
          'images': images,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? l10n.nutritionEditPostTitle : l10n.nutritionNewPost)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._imageUrls.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                e.value,
                                semanticLabel: l10n.nutritionPostPhotoOf(e.key + 1, _imageUrls.length),
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => Container(
                                  width: 110,
                                  height: 110,
                                  color: cs.surfaceContainerHighest,
                                  child: const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Semantics(
                                button: true,
                                label: l10n.nutritionRemovePhoto,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () =>
                                      setState(() => _imageUrls.removeAt(e.key)),
                                  // 48 dp hit area around the small badge.
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Align(
                                      alignment: Alignment.topRight,
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: cs.inverseSurface.withValues(alpha: 0.7),
                                          child: Icon(Icons.close,
                                              size: 14, color: cs.onInverseSurface),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _uploading || _saving ? null : _addPhoto,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _uploading
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    color: cs.onSurfaceVariant),
                                const SizedBox(height: 4),
                                Text(l10n.nutritionAddPhoto,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentCtrl,
              decoration: InputDecoration(
                labelText: l10n.nutritionShareHint,
                alignLabelWithHint: true,
              ),
              maxLines: 6,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving || _uploading ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? l10n.commonSave : l10n.nutritionPostAction),
            ),
          ],
        ),
      ),
    );
  }
}
