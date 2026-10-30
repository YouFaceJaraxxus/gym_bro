import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/post.dart';
import '../../models/reaction.dart';
import '../../models/social.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/comment_thread.dart';
import '../../widgets/mentions.dart';
import '../../widgets/post_card.dart';

String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

PostComment _copyComment(
  PostComment c, {
  String? body,
  DateTime? updatedAt,
  bool? deleted,
  bool clearAuthor = false,
  ReactionSummary? reactions,
  ReactionType? myReaction,
  bool setMyReaction = false,
  int? score,
  bool? canEdit,
  bool? canDelete,
  bool? canReply,
}) => PostComment(
  id: c.id,
  postId: c.postId,
  parentId: c.parentId,
  depth: c.depth,
  authorId: clearAuthor ? null : c.authorId,
  author: clearAuthor ? null : c.author,
  body: body ?? c.body,
  createdAt: c.createdAt,
  updatedAt: updatedAt ?? c.updatedAt,
  deleted: deleted ?? c.deleted,
  hidden: c.hidden,
  replyCount: c.replyCount,
  reactions: reactions ?? c.reactions,
  myReaction: setMyReaction ? myReaction : c.myReaction,
  score: score ?? c.score,
  canEdit: canEdit ?? c.canEdit,
  canDelete: canDelete ?? c.canDelete,
  canReply: canReply ?? c.canReply,
);

/// The comments of one post, shared by [PostDetailPage] and the focused
/// [CommentThreadPage]s pushed from it: paging, sort, and optimistic
/// create/edit/delete/react (each rolls back and rethrows on failure).
/// Keeps `post.commentCount` in sync.
class CommentStore extends ChangeNotifier {
  CommentStore({required this.postId, Post? post}) : _post = post;

  static const pageSize = 20;

  final String postId;
  final _api = ApiService();

  Post? _post;
  Post? get post => _post;
  set post(Post? p) {
    _post = p;
    _notify();
  }

  final Map<String, PostComment> _byId = {};
  List<PostComment> _list = const [];

  /// Every loaded comment, flat (a new list instance after each change).
  List<PostComment> get comments => _list;
  PostComment? operator [](String id) => _byId[id];

  CommentSort _sort = CommentSort.top;
  CommentSort get sort => _sort;

  int _page = 0;
  bool hasMore = false;
  bool loading = true;
  bool loadingMore = false;
  String? error;

  /// Comments I wrote this session (shown first) and ones still sending.
  Set<String> pinned = const {};
  Set<String> pending = const {};

  int _gen = 0;
  int _tempSeq = 0;
  bool _disposed = false;
  final Map<String, int> _reactSeq = {};

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    _list = List.unmodifiable(_byId.values);
    _notify();
  }

  void _bumpCount(int delta) {
    final p = _post;
    if (p != null) _post = p.copyWith(commentCount: math.max(0, p.commentCount + delta));
  }

  bool _hasMoreAfter(List<PostComment> rows) => rows.where((c) => c.parentId == null).length >= pageSize;

  /// First page; with [sort] switches the order and starts over.
  Future<void> load({CommentSort? sort}) async {
    final gen = ++_gen;
    if (sort != null && sort != _sort) {
      _sort = sort;
      _byId.removeWhere((id, _) => !pending.contains(id));
      _list = List.unmodifiable(_byId.values);
    }
    loading = true;
    loadingMore = false;
    error = null;
    _notify();
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await _api.getPostComments(token, postId, sort: _sort.apiValue, pageSize: pageSize);
      if (gen != _gen || _disposed) return;
      final keep = {for (final id in pending) id: _byId[id]};
      _byId.clear();
      for (final c in rows) {
        _byId[c.id] = c;
      }
      for (final e in keep.entries) {
        if (e.value != null) _byId[e.key] = e.value!;
      }
      _page = 0;
      hasMore = _hasMoreAfter(rows);
      loading = false;
      _changed();
    } catch (e) {
      if (gen != _gen || _disposed) return;
      error = _msg(e);
      loading = false;
      _notify();
    }
  }

  /// The next page of top-level comments (with their replies). Throws on failure.
  Future<void> loadMore() async {
    if (loadingMore || !hasMore || loading) return;
    final gen = _gen;
    loadingMore = true;
    _notify();
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await _api.getPostComments(token, postId, sort: _sort.apiValue, page: _page + 1, pageSize: pageSize);
      if (gen != _gen || _disposed) return;
      for (final c in rows) {
        _byId[c.id] = c;
      }
      _page++;
      hasMore = _hasMoreAfter(rows);
      _changed();
    } finally {
      if (gen == _gen) {
        loadingMore = false;
        _notify();
      }
    }
  }

  /// Adds an optimistic comment (a reply when [parent] is set) and returns
  /// its temporary id; then call [commitPending].
  String insertPending(String body, {PostComment? parent}) {
    final me = AuthManager.instance.profile;
    final id = 'pending-${++_tempSeq}';
    final now = DateTime.now();
    _byId[id] = PostComment(
      id: id,
      postId: postId,
      parentId: parent?.id,
      depth: parent == null ? 0 : parent.depth + 1,
      authorId: me?.id,
      author: me == null
          ? null
          : SocialUser(id: me.id, username: me.username, name: me.name, lastName: me.lastName, avatarUrl: me.avatarUrl),
      body: body,
      createdAt: now,
      updatedAt: now,
    );
    pending = {...pending, id};
    pinned = {...pinned, id};
    _bumpCount(1);
    _changed();
    return id;
  }

  /// Sends a pending comment and swaps in the server's copy, or removes it
  /// and rethrows.
  Future<PostComment> commitPending(String tempId) async {
    final temp = _byId[tempId];
    if (temp == null) throw StateError('No pending comment $tempId');
    try {
      final token = await AuthManager.instance.getValidToken();
      final created = await _api.createPostComment(token, postId, temp.body, parentId: temp.parentId);
      _byId.remove(tempId);
      _byId[created.id] = created;
      pending = {...pending}..remove(tempId);
      pinned = {...pinned}
        ..remove(tempId)
        ..add(created.id);
      _changed();
      return created;
    } catch (_) {
      _byId.remove(tempId);
      pending = {...pending}..remove(tempId);
      pinned = {...pinned}..remove(tempId);
      _bumpCount(-1);
      _changed();
      rethrow;
    }
  }

  Future<void> edit(PostComment c, String body) async {
    final before = _byId[c.id];
    if (before == null || before.body == body) return;
    _byId[c.id] = _copyComment(before, body: body, updatedAt: DateTime.now());
    _changed();
    try {
      final token = await AuthManager.instance.getValidToken();
      final saved = await _api.updatePostComment(token, c.id, body);
      if (_byId.containsKey(c.id)) {
        // Keep the old score so "top" order doesn't jump.
        _byId[c.id] = _copyComment(saved, score: before.score);
        _changed();
      }
    } catch (_) {
      if (_byId.containsKey(c.id)) {
        _byId[c.id] = before;
        _changed();
      }
      rethrow;
    }
  }

  /// With replies the comment stays as a "[deleted]" placeholder (like the
  /// API); a placeholder left without replies disappears too.
  Future<void> delete(PostComment c) async {
    final before = _byId[c.id];
    if (before == null) return;
    final removed = <PostComment>[];
    bool hasReplies(String id) => _byId.values.any((x) => x.parentId == id);
    if (hasReplies(c.id)) {
      _byId[c.id] = _copyComment(
        before,
        body: '',
        deleted: true,
        clearAuthor: true,
        reactions: ReactionSummary.empty,
        setMyReaction: true,
        canEdit: false,
        canDelete: false,
        canReply: false,
      );
    } else {
      removed.add(_byId.remove(c.id)!);
      var parentId = before.parentId;
      while (parentId != null) {
        final parent = _byId[parentId];
        if (parent == null || !parent.deleted || hasReplies(parentId)) break;
        removed.add(_byId.remove(parentId)!);
        parentId = parent.parentId;
      }
    }
    _bumpCount(-1);
    _changed();
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deletePostComment(token, c.id);
    } catch (_) {
      _byId[c.id] = before;
      for (final r in removed) {
        _byId[r.id] = r;
      }
      _bumpCount(1);
      _changed();
      rethrow;
    }
  }

  /// Optimistic reaction; only the latest tap per comment is applied.
  Future<void> react(PostComment c, ReactionType? to) async {
    final before = _byId[c.id];
    if (before == null || before.myReaction == to) return;
    final seq = (_reactSeq[c.id] ?? 0) + 1;
    _reactSeq[c.id] = seq;
    _byId[c.id] = before.withMyReaction(to);
    _changed();
    try {
      final token = await AuthManager.instance.getValidToken();
      final saved = await _api.reactToComment(token, c.id, to);
      final cur = _byId[c.id];
      if (_reactSeq[c.id] != seq || cur == null) return;
      _byId[c.id] = _copyComment(cur, reactions: saved.reactions, myReaction: saved.myReaction, setMyReaction: true);
      _changed();
    } catch (_) {
      final cur = _byId[c.id];
      if (_reactSeq[c.id] != seq || cur == null) return;
      _byId[c.id] = _copyComment(cur, reactions: before.reactions, myReaction: before.myReaction, setMyReaction: true);
      _changed();
      rethrow;
    }
  }
}

const _threadRouteName = 'comment-thread';

/// Composer + comment actions shared by the detail page and thread pages.
mixin _CommentsUi<T extends StatefulWidget> on State<T> {
  CommentStore get store;

  final threadController = CommentThreadController();
  final composerText = MentionTextEditingController();
  final composerFocus = FocusNode();
  PostComment? replyTo;
  PostComment? editing;
  String? highlightId;
  Timer? _highlightTimer;

  void disposeComposer() {
    _highlightTimer?.cancel();
    composerText.dispose();
    composerFocus.dispose();
  }

  void snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void highlight(String id) {
    _highlightTimer?.cancel();
    setState(() => highlightId = id);
    _highlightTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => highlightId = null);
    });
  }

  void startComment() {
    if (editing != null) composerText.clear();
    setState(() {
      replyTo = null;
      editing = null;
    });
    composerFocus.requestFocus();
  }

  void startReply(PostComment c) {
    if (editing != null) composerText.clear();
    setState(() {
      replyTo = c;
      editing = null;
    });
    composerFocus.requestFocus();
  }

  void startEdit(PostComment c) {
    setState(() {
      editing = c;
      replyTo = null;
    });
    composerText.markup = c.body;
    composerFocus.requestFocus();
  }

  void cancelComposer() {
    if (editing != null) composerText.clear();
    setState(() {
      replyTo = null;
      editing = null;
    });
  }

  Future<void> openThread(PostComment root, {String? focusCommentId, bool replace = false}) {
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: _threadRouteName),
      builder: (_) => CommentThreadPage(store: store, rootId: root.id, focusCommentId: focusCommentId),
    );
    final nav = Navigator.of(context);
    return replace ? nav.pushReplacement(route) : nav.push(route);
  }

  Future<void> send() async {
    final text = composerText.markup.trim();
    if (text.isEmpty) return;
    final edit = editing;
    final parent = replyTo;
    composerText.clear();
    setState(() {
      editing = null;
      replyTo = null;
    });

    if (edit != null) {
      composerFocus.unfocus();
      try {
        await store.edit(edit, text);
      } catch (e) {
        snack(_msg(e));
      }
      return;
    }

    if (parent != null) composerFocus.unfocus();
    final tempId = store.insertPending(text, parent: parent);
    var tooDeep = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      tooDeep = !threadController.reveal(tempId) && parent != null;
    });
    try {
      final created = await store.commitPending(tempId);
      if (!mounted) return;
      if (tooDeep && parent != null) {
        await openThread(parent, focusCommentId: created.id);
      } else {
        highlight(created.id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) threadController.reveal(created.id);
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Put the text back so nothing is lost.
      if (composerText.text.isEmpty) composerText.markup = text;
      setState(() => replyTo = parent);
      snack(_msg(e));
    }
  }

  Future<void> confirmDelete(PostComment c) async {
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
    if (confirmed != true || !mounted) return;
    if (editing?.id == c.id) cancelComposer();
    if (replyTo?.id == c.id) cancelComposer();
    try {
      await store.delete(c);
    } catch (e) {
      snack(_msg(e));
    }
  }

  Future<void> react(PostComment c, ReactionType? r) async {
    try {
      await store.react(c, r);
    } catch (e) {
      snack(_msg(e));
    }
  }

  Widget buildThread({String? rootId}) => CommentThreadView(
    comments: store.comments,
    sort: store.sort,
    rootId: rootId,
    opAuthorId: store.post?.authorId,
    controller: threadController,
    highlightId: highlightId,
    pinnedIds: store.pinned,
    pendingIds: store.pending,
    onReply: startReply,
    onEdit: startEdit,
    onDelete: confirmDelete,
    onReact: react,
    onContinueThread: (c) => openThread(c),
  );

  Widget buildComposer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final target = replyTo;
    final author = target?.author;
    final targetName = author == null
        ? (target?.authorName(l10n) ?? '')
        : (author.username.isNotEmpty ? '@${author.username}' : author.fullName);
    return Material(
      color: cs.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (target != null || editing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
              child: Row(children: [
                Icon(editing != null ? Icons.edit_outlined : Icons.reply_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    editing != null ? l10n.nutritionEditingComment : l10n.feedReplyingTo(targetName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: editing != null ? l10n.nutritionCancelEditing : l10n.feedCancelReply,
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: cancelComposer,
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: MentionAutocomplete(
                  controller: composerText,
                  focusNode: composerFocus,
                  child: TextField(
                    controller: composerText,
                    focusNode: composerFocus,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: target != null ? l10n.feedWriteReplyHint : l10n.nutritionWriteCommentHint,
                      counterText: '',
                      isDense: true,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: composerText,
                builder: (context, value, _) => IconButton.filled(
                  tooltip: editing != null ? l10n.nutritionSaveComment : l10n.nutritionSendComment,
                  onPressed: value.text.trim().isEmpty ? null : send,
                  icon: Icon(editing != null ? Icons.check : Icons.send),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Post detail ───────────────────────────────────────────────────────────────

/// A post with its threaded comments in one scroll view and a composer at the
/// bottom. Changes to the post (reactions, edits, comment count) are reported
/// through [onChanged] as they happen; [onDeleted] fires (and the page pops)
/// when the post is deleted here.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.postId,
    this.initial,
    this.focusCommentId,
    this.onChanged,
    this.onDeleted,
    this.onArchived,
  });

  final String postId;

  /// Shown immediately while the post loads.
  final Post? initial;

  /// Scroll to and highlight this comment (from a reply notification).
  final String? focusCommentId;

  final ValueChanged<Post>? onChanged;
  final VoidCallback? onDeleted;

  /// The post was archived from here (the page then closes). Defaults to
  /// [onDeleted].
  final VoidCallback? onArchived;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> with _CommentsUi<PostDetailPage> {
  final _api = ApiService();
  late final CommentStore _store = CommentStore(postId: widget.postId, post: widget.initial);
  late Post? _reported = widget.initial;
  String? _postError;

  @override
  CommentStore get store => _store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    _loadPost();
    _loadComments();
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _store.dispose();
    disposeComposer();
    super.dispose();
  }

  void _onStore() {
    final p = _store.post;
    if (p != null && !identical(p, _reported)) {
      _reported = p;
      widget.onChanged?.call(p);
    }
  }

  Future<void> _loadPost() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final p = await _api.getPost(token, widget.postId);
      if (!mounted) return;
      _store.post = p;
    } catch (e) {
      if (!mounted || _store.post != null) return;
      setState(() => _postError = _msg(e));
    }
  }

  Future<void> _loadComments() async {
    await _store.load();
    if (!mounted) return;
    await _focus();
  }

  Future<void> _refresh() async {
    setState(() => _postError = null);
    await Future.wait([_loadPost(), _store.load()]);
  }

  Future<void> _loadMore() async {
    try {
      await _store.loadMore();
    } catch (e) {
      snack(_msg(e));
    }
  }

  /// Notification deep link: page until the comment shows up, then expand
  /// and scroll to it — or open a focused thread when it's too deep.
  Future<void> _focus() async {
    final id = widget.focusCommentId;
    if (id == null) return;
    for (var tries = 0; _store[id] == null && _store.hasMore && tries < 5; tries++) {
      try {
        await _store.loadMore();
      } catch (_) {
        break;
      }
      if (!mounted) return;
    }
    if (!mounted || _store[id] == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      highlight(id);
      if (threadController.reveal(id)) return;
      final ancestors = CommentTree.build(_store.comments).ancestorsOf(id);
      if (ancestors.isEmpty) return;
      openThread(ancestors[math.max(0, ancestors.length - 2)].comment, focusCommentId: id);
    });
  }

  void _onDeleted() {
    widget.onDeleted?.call();
    if (mounted) Navigator.of(context).maybePop();
  }

  void _onArchived() {
    (widget.onArchived ?? widget.onDeleted)?.call();
    if (mounted) Navigator.of(context).maybePop();
  }

  bool _unarchiving = false;

  /// "Show on profile" from the archived banner.
  Future<void> _unarchive(Post post) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _unarchiving = true);
    try {
      final updated = await _api.unarchivePost(await AuthManager.instance.getValidToken(), post.id);
      _store.post = post.copyWith(archivedAt: updated.archivedAt, clearArchivedAt: updated.archivedAt == null);
      messenger.showSnackBar(SnackBar(content: Text(l10n.archivePostRestored)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_msg(e))));
    } finally {
      if (mounted) setState(() => _unarchiving = false);
    }
  }

  Widget _archivedBanner(BuildContext context, Post post) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.secondaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(children: [
        Icon(Icons.archive_outlined, size: 18, color: cs.onSecondaryContainer),
        const SizedBox(width: 10),
        Expanded(
          child: Text(l10n.archivePostBanner, style: TextStyle(color: cs.onSecondaryContainer)),
        ),
        TextButton(
          onPressed: _unarchiving ? null : () => _unarchive(post),
          child: Text(l10n.archivePostUnarchive),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.feedPostTitle)),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final post = _store.post;
          if (post == null) {
            if (_postError == null) return const Center(child: CircularProgressIndicator());
            return _ErrorView(message: l10n.feedPostNotFound, detail: _postError, onRetry: () {
              setState(() => _postError = null);
              _loadPost();
            });
          }
          return Column(children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    if (post.isArchived && post.authorId == AuthManager.instance.profile?.id)
                      SliverToBoxAdapter(child: _archivedBanner(context, post)),
                    SliverToBoxAdapter(
                      child: PostCard(
                        key: ValueKey(post.id),
                        post: post,
                        expandCaption: true,
                        margin: EdgeInsets.zero,
                        onChanged: (p) => _store.post = p,
                        onDeleted: _onDeleted,
                        onArchived: _onArchived,
                        onOpenComments: startComment,
                      ),
                    ),
                    SliverToBoxAdapter(child: _commentsHeader(context, post)),
                    ..._commentSlivers(context),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
            buildComposer(context),
          ]);
        },
      ),
    );
  }

  Widget _commentsHeader(BuildContext context, Post post) {
    final l10n = context.l10n;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
      child: Row(children: [
        Expanded(
          child: Text(
            post.commentCount == 0 ? l10n.feedCommentsHeader : l10n.nutritionCommentsWithCount(post.commentCount),
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Semantics(
          label: l10n.feedSortLabel,
          child: Wrap(spacing: 4, children: [
            for (final s in CommentSort.values)
              ChoiceChip(
                label: Text(s.label(l10n)),
                selected: _store.sort == s,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                showCheckmark: false,
                onSelected: (_) {
                  if (_store.sort != s) _store.load(sort: s);
                },
              ),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _commentSlivers(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (_store.comments.isEmpty) {
      if (_store.loading) {
        return const [
          SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))),
        ];
      }
      if (_store.error != null) {
        return [SliverToBoxAdapter(child: _ErrorView(message: _store.error!, onRetry: () => _store.load()))];
      }
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Column(children: [
              Icon(Icons.chat_bubble_outline, size: 40, color: cs.outline),
              const SizedBox(height: 12),
              Text(l10n.nutritionNoCommentsYet, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(l10n.nutritionStartConversation, style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          ),
        ),
      ];
    }
    return [
      if (_store.loading) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
      buildThread(),
      if (_store.hasMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: _store.loadingMore
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : OutlinedButton(onPressed: _loadMore, child: Text(l10n.feedLoadMoreComments)),
            ),
          ),
        ),
    ];
  }
}

// ── Focused thread ────────────────────────────────────────────────────────────

/// "Continue this thread": one comment and its replies, full width. Shares
/// the [CommentStore] of the [PostDetailPage] it was opened from.
class CommentThreadPage extends StatefulWidget {
  const CommentThreadPage({super.key, required this.store, required this.rootId, this.focusCommentId});

  final CommentStore store;
  final String rootId;

  /// Scroll to and highlight this comment.
  final String? focusCommentId;

  @override
  State<CommentThreadPage> createState() => _CommentThreadPageState();
}

class _CommentThreadPageState extends State<CommentThreadPage> with _CommentsUi<CommentThreadPage> {
  @override
  CommentStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    final id = widget.focusCommentId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        highlight(id);
        threadController.reveal(id);
      });
    }
  }

  @override
  void dispose() {
    disposeComposer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.feedThreadTitle)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final root = store[widget.rootId];
          final parentId = root?.parentId;
          final parent = parentId == null ? null : store[parentId];
          return Column(children: [
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      child: Wrap(spacing: 4, children: [
                        TextButton.icon(
                          icon: const Icon(Icons.forum_outlined, size: 18),
                          label: Text(l10n.feedAllComments),
                          onPressed: () => Navigator.of(context).popUntil((r) => r.settings.name != _threadRouteName),
                        ),
                        if (parent != null)
                          TextButton.icon(
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            label: Text(l10n.feedShowParent),
                            onPressed: () => openThread(parent, focusCommentId: widget.rootId, replace: true),
                          ),
                      ]),
                    ),
                  ),
                  SliverToBoxAdapter(child: Divider(height: 1, color: cs.outlineVariant)),
                  if (root == null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(child: Text(l10n.feedDeletedComment, style: TextStyle(color: cs.onSurfaceVariant))),
                      ),
                    )
                  else
                    buildThread(rootId: widget.rootId),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
            buildComposer(context),
          ]);
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.detail, required this.onRetry});

  final String message;
  final String? detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 40, color: cs.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (detail != null && detail != message) ...[
            const SizedBox(height: 4),
            Text(detail!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
        ]),
      ),
    );
  }
}
