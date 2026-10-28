import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/reaction.dart';
import '../models/social.dart';
import '../pages/feed/reactions_sheet.dart';
import '../pages/people/user_profile_page.dart';
import 'reactions.dart';
import 'social_widgets.dart';

/// Reddit-style threaded comments.
///
/// The API returns a page of top-level comments plus every reply under them
/// as one flat list; [CommentTree] rebuilds the tree from `parentId` and
/// [CommentThreadView] renders it as a *sliver* (put it in a
/// `CustomScrollView`): thin guide lines per level (tap one, or a comment, to
/// collapse that subtree), 12 px indentation, "Show N more replies" for long
/// sibling lists and "Continue this thread →" past
/// [CommentThreadView.maxVisibleDepth]. Every comment starts collapsed to its
/// header; expanding one shows its body and its (still collapsed) replies, and
/// collapsing it collapses everything below again.

enum CommentSort {
  top('top'),
  newest('new'),
  oldest('old');

  const CommentSort(this.apiValue);
  final String apiValue;

  String label(AppLocalizations l10n) => switch (this) {
    CommentSort.top => l10n.feedSortTop,
    CommentSort.newest => l10n.feedSortNew,
    CommentSort.oldest => l10n.feedSortOld,
  };
}

class CommentNode {
  CommentNode(this.comment);

  final PostComment comment;
  CommentNode? parent;
  final List<CommentNode> children = [];

  String get id => comment.id;

  /// Replies at any depth below this comment.
  int get descendantCount {
    var n = 0;
    for (final c in children) {
      n += 1 + c.descendantCount;
    }
    return n;
  }
}

class CommentTree {
  CommentTree._(this.roots, this.byId);

  /// Builds the tree and sorts every sibling list by [sort]. [pinned] ids
  /// (comments I just wrote) go first among their siblings, newest first.
  /// A comment whose parent isn't loaded becomes a root.
  factory CommentTree.build(Iterable<PostComment> comments, {CommentSort sort = CommentSort.top, Set<String> pinned = const {}}) {
    final byId = <String, CommentNode>{for (final c in comments) c.id: CommentNode(c)};
    final roots = <CommentNode>[];
    for (final n in byId.values) {
      final parentId = n.comment.parentId;
      final parent = parentId == null || parentId == n.id ? null : byId[parentId];
      if (parent == null) {
        roots.add(n);
      } else {
        n.parent = parent;
        parent.children.add(n);
      }
    }
    int cmp(CommentNode a, CommentNode b) {
      final pa = pinned.contains(a.id), pb = pinned.contains(b.id);
      if (pa != pb) return pa ? -1 : 1;
      if (pa) return b.comment.createdAt.compareTo(a.comment.createdAt);
      final ca = a.comment, cb = b.comment;
      return switch (sort) {
        CommentSort.top => cb.score != ca.score ? cb.score.compareTo(ca.score) : ca.createdAt.compareTo(cb.createdAt),
        CommentSort.newest => cb.createdAt.compareTo(ca.createdAt),
        CommentSort.oldest => ca.createdAt.compareTo(cb.createdAt),
      };
    }

    roots.sort(cmp);
    for (final n in byId.values) {
      n.children.sort(cmp);
    }
    return CommentTree._(roots, byId);
  }

  final List<CommentNode> roots;
  final Map<String, CommentNode> byId;

  CommentNode? operator [](String id) => byId[id];

  /// [id]'s ancestors from the top-level comment down (excluding itself).
  List<CommentNode> ancestorsOf(String id) {
    final out = <CommentNode>[];
    var n = byId[id]?.parent;
    while (n != null && out.length <= kMaxCommentDepth + 1) {
      out.add(n);
      n = n.parent;
    }
    return out.reversed.toList();
  }
}

/// Lets a page expand and scroll to a comment (a new reply, a notification).
class CommentThreadController {
  _CommentThreadViewState? _state;

  /// Expands every collapsed ancestor of [commentId], reveals it among its
  /// siblings and (with [scroll]) scrolls to it. Returns false when the
  /// comment isn't in this view or sits deeper than the view shows — open a
  /// focused thread for it instead. Call after the view has rebuilt with the
  /// comment (e.g. in a post-frame callback).
  bool reveal(String commentId, {bool scroll = true}) => _state?._reveal(commentId, scroll: scroll) ?? false;

  /// Collapses or expands one comment's subtree.
  void toggle(String commentId) => _state?._toggle(commentId);
}

/// The comment thread as a sliver. Owns only view state (expanded
/// comments, how many replies are revealed); the comments and every action
/// belong to the parent.
class CommentThreadView extends StatefulWidget {
  const CommentThreadView({
    super.key,
    required this.comments,
    this.sort = CommentSort.top,
    this.rootId,
    this.opAuthorId,
    this.controller,
    this.highlightId,
    this.pinnedIds = const {},
    this.pendingIds = const {},
    this.maxVisibleDepth,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onReact,
    this.onContinueThread,
  });

  /// Flat list (any order) — top-level comments and their replies.
  final List<PostComment> comments;
  final CommentSort sort;

  /// Render only this comment and its replies (a "continue this thread" view).
  final String? rootId;

  /// The post's author: their comments get an "OP" badge.
  final String? opAuthorId;
  final CommentThreadController? controller;

  /// Tinted background (the comment a notification pointed at, a new reply).
  final String? highlightId;

  /// Shown first among their siblings (comments I just wrote).
  final Set<String> pinnedIds;

  /// Optimistic comments not yet confirmed by the server: dimmed, no actions.
  final Set<String> pendingIds;

  /// Deepest level (relative to the view's top, 0-based) rendered inline;
  /// deeper replies get "Continue this thread". Defaults to 5 on phones and
  /// all ten levels on wider screens.
  final int? maxVisibleDepth;

  final ValueChanged<PostComment>? onReply;
  final ValueChanged<PostComment>? onEdit;
  final ValueChanged<PostComment>? onDelete;
  final void Function(PostComment comment, ReactionType? reaction)? onReact;

  /// Open a focused view rooted at this comment.
  final ValueChanged<PostComment>? onContinueThread;

  @override
  State<CommentThreadView> createState() => _CommentThreadViewState();
}

sealed class _Row {
  const _Row(this.level, this.lines);

  final int level;

  /// Ancestor ids, one per guide line (length == level).
  final List<String> lines;
}

class _CommentRow extends _Row {
  const _CommentRow(this.node, super.level, super.lines, {required this.collapsed});

  final CommentNode node;
  final bool collapsed;
}

class _MoreRow extends _Row {
  const _MoreRow(this.parentKey, super.level, super.lines, this.remaining);

  final String parentKey;
  final int remaining;
}

class _ContinueRow extends _Row {
  const _ContinueRow(this.node, super.level, super.lines);

  final CommentNode node;
}

class _CommentThreadViewState extends State<CommentThreadView> {
  static const _rootKey = '';

  /// Replies shown under a comment before "Show N more replies".
  static const _initialReplies = 4;
  static const _moreStep = 10;
  static const _unit = 12.0;

  /// Comments not in here are collapsed — the thread opens fully collapsed.
  final Set<String> _expanded = {};
  final Map<String, int> _shown = {};
  final Map<String, GlobalKey> _keys = {};

  CommentTree? _tree;
  List<PostComment>? _treeSource;
  CommentSort? _treeSort;
  Set<String> _treePinned = const {};

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    // A focused thread opens on its root comment.
    if (widget.rootId != null) _expanded.add(widget.rootId!);
  }

  @override
  void didUpdateWidget(CommentThreadView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._state == this) old.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    super.dispose();
  }

  CommentTree get _currentTree {
    final stale = _tree == null ||
        !identical(_treeSource, widget.comments) ||
        _treeSort != widget.sort ||
        !setEquals(_treePinned, widget.pinnedIds);
    if (stale) {
      _tree = CommentTree.build(widget.comments, sort: widget.sort, pinned: widget.pinnedIds);
      _treeSource = widget.comments;
      _treeSort = widget.sort;
      _treePinned = {...widget.pinnedIds};
    }
    return _tree!;
  }

  int _maxLevel(BuildContext context) =>
      widget.maxVisibleDepth ?? (MediaQuery.sizeOf(context).width < 600 ? 5 : kMaxCommentDepth);

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  List<_Row> _flatten(CommentTree tree, int maxLevel) {
    final rows = <_Row>[];
    final List<CommentNode> top;
    if (widget.rootId != null) {
      final root = tree[widget.rootId!];
      top = root == null ? const [] : [root];
    } else {
      top = tree.roots;
    }

    void visit(List<CommentNode> siblings, int level, List<String> lines, String parentKey) {
      final limit = level == 0 ? siblings.length : math.min(siblings.length, _shown[parentKey] ?? _initialReplies);
      for (var i = 0; i < limit; i++) {
        final n = siblings[i];
        final collapsed = !_expanded.contains(n.id);
        rows.add(_CommentRow(n, level, lines, collapsed: collapsed));
        if (collapsed || n.children.isEmpty) continue;
        final childLines = [...lines, n.id];
        if (level + 1 > maxLevel) {
          rows.add(_ContinueRow(n, level + 1, childLines));
        } else {
          visit(n.children, level + 1, childLines, n.id);
        }
      }
      if (siblings.length > limit) rows.add(_MoreRow(parentKey, level, lines, siblings.length - limit));
    }

    visit(top, 0, const [], _rootKey);
    return rows;
  }

  void _toggle(String id) {
    final collapsing = _expanded.contains(id);
    setState(() {
      if (!collapsing) {
        _expanded.add(id);
        return;
      }
      // Collapse the whole subtree so re-expanding starts from scratch.
      void collapse(CommentNode n) {
        _expanded.remove(n.id);
        _shown.remove(n.id);
        n.children.forEach(collapse);
      }

      final node = _currentTree[id];
      node == null ? _expanded.remove(id) : collapse(node);
    });
    if (collapsing) {
      // Collapsing from a guide line deep below can leave the comment above
      // the viewport: bring its header back.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[id]?.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 200),
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          );
        }
      });
    }
  }

  bool _reveal(String id, {bool scroll = true}) {
    if (!mounted) return false;
    final tree = _currentTree;
    final node = tree[id];
    if (node == null) return false;
    final chain = [...tree.ancestorsOf(id), node];
    var start = 0;
    if (widget.rootId != null) {
      start = chain.indexWhere((n) => n.id == widget.rootId);
      if (start < 0) return false;
    }
    final path = chain.sublist(start);
    setState(() {
      for (var i = 0; i < path.length; i++) {
        _expanded.add(path[i].id);
        if (i > 0) {
          final parent = path[i - 1];
          final idx = parent.children.indexOf(path[i]);
          _shown[parent.id] = math.max(_shown[parent.id] ?? _initialReplies, idx + 1);
        }
      }
    });
    if (path.length - 1 > _maxLevel(context)) return false;
    if (scroll) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(id));
    return true;
  }

  /// Rows are built lazily, so step through the list until the comment's
  /// row exists, then center it.
  Future<void> _scrollTo(String id) async {
    var wrapped = false;
    for (var i = 0; i < 60; i++) {
      if (!mounted) return;
      final ctx = _keys[id]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        return;
      }
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable == null) return;
      final pos = scrollable.position;
      if (pos.pixels >= pos.maxScrollExtent) {
        if (wrapped) return;
        wrapped = true;
        pos.jumpTo(pos.minScrollExtent);
      } else {
        pos.jumpTo(math.min(pos.pixels + pos.viewportDimension * 0.8, pos.maxScrollExtent));
      }
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxLevel = _maxLevel(context);
    final rows = _flatten(_currentTree, maxLevel);
    final width = MediaQuery.sizeOf(context).width;
    // Keep indentation narrow: at most ~30% of the width for the deepest level.
    final unit = math.min(_unit, (width * 0.3) / math.max(1, maxLevel + 1));
    return SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) => _buildRow(context, rows[i], unit),
    );
  }

  Widget _buildRow(BuildContext context, _Row row, double unit) {
    final l10n = context.l10n;
    final Widget child = switch (row) {
      _CommentRow r => KeyedSubtree(
        key: _keyFor(r.node.id),
        child: _CommentTile(
          node: r.node,
          collapsed: r.collapsed,
          isOp: widget.opAuthorId != null && r.node.comment.authorId == widget.opAuthorId,
          highlighted: r.node.id == widget.highlightId,
          pending: widget.pendingIds.contains(r.node.id),
          onToggle: () => _toggle(r.node.id),
          onReply: widget.onReply,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
          onReact: widget.onReact,
        ),
      ),
      _MoreRow r => _LinkRow(
        icon: Icons.expand_more,
        label: l10n.feedShowMoreReplies(r.remaining),
        onTap: () => setState(() => _shown[r.parentKey] = (_shown[r.parentKey] ?? _initialReplies) + _moreStep),
      ),
      _ContinueRow r => _LinkRow(
        icon: Icons.subdirectory_arrow_right,
        label: l10n.feedContinueThread,
        trailing: l10n.feedReplyCount(r.node.descendantCount),
        onTap: widget.onContinueThread == null ? null : () => widget.onContinueThread!(r.node.comment),
      ),
    };
    return _Guides(lines: row.lines, unit: unit, onTapLine: _toggle, child: child);
  }
}

/// One thin vertical line per ancestor level; tapping a line collapses that
/// ancestor.
class _Guides extends StatelessWidget {
  const _Guides({required this.lines, required this.unit, required this.onTapLine, required this.child});

  final List<String> lines;
  final double unit;
  final ValueChanged<String> onTapLine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return Padding(padding: const EdgeInsets.only(left: 8), child: child);
    final cs = Theme.of(context).colorScheme;
    return Stack(children: [
      Padding(padding: EdgeInsets.only(left: 8 + lines.length * unit), child: child),
      for (var i = 0; i < lines.length; i++)
        Positioned(
          left: 8 + i * unit,
          top: 0,
          bottom: 0,
          width: unit,
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTapLine(lines[i]),
              child: Align(
                alignment: const Alignment(-0.2, 0),
                child: Container(width: 1.5, color: cs.outlineVariant),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, this.trailing, this.onTap});

  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
          child: Row(children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, style: tt.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              Text(trailing!, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ]),
        ),
      ),
    );
  }
}

enum _CommentAction { edit, delete, copy }

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.node,
    required this.collapsed,
    required this.isOp,
    required this.highlighted,
    required this.pending,
    required this.onToggle,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onReact,
  });

  final CommentNode node;
  final bool collapsed;
  final bool isOp;
  final bool highlighted;
  final bool pending;
  final VoidCallback onToggle;
  final ValueChanged<PostComment>? onReply;
  final ValueChanged<PostComment>? onEdit;
  final ValueChanged<PostComment>? onDelete;
  final void Function(PostComment comment, ReactionType? reaction)? onReact;

  void _openAuthor(BuildContext context) {
    final author = node.comment.author;
    if (author == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserProfilePage(userId: author.id)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final c = node.comment;
    final placeholder = c.deleted || c.hidden;
    final name = c.deleted
        ? l10n.feedDeletedComment
        : c.hidden
        ? l10n.feedHiddenComment
        : c.authorName(l10n);
    final replies = node.descendantCount;
    final meta = [
      if (pending) l10n.feedSending else relativeTime(l10n, c.createdAt),
      if (c.isEdited && !placeholder) l10n.nutritionEditedLower,
      if (collapsed && replies > 0) l10n.feedReplyCount(replies),
    ].join(' · ');
    final actions = <_CommentAction>[
      if (c.canEdit && onEdit != null) _CommentAction.edit,
      if (c.canDelete && onDelete != null) _CommentAction.delete,
      if (!placeholder && c.body.isNotEmpty) _CommentAction.copy,
    ];
    final canReply = c.canReply && !placeholder && c.depth < kMaxCommentDepth && onReply != null;
    final interactive = !pending && !placeholder;

    final avatar = placeholder || c.author == null
        ? CircleAvatar(
            radius: 11,
            backgroundColor: cs.surfaceContainerHighest,
            child: Icon(c.hidden ? Icons.visibility_off_outlined : Icons.person_outline, size: 13, color: cs.onSurfaceVariant),
          )
        : GestureDetector(
            onTap: () => _openAuthor(context),
            child: UserAvatar(url: c.author!.avatarUrl, initials: c.author!.initials, radius: 11),
          );

    final header = Semantics(
      button: true,
      expanded: !collapsed,
      hint: collapsed ? l10n.feedExpandThread : l10n.feedCollapseThread,
      child: InkWell(
        onTap: pending ? null : onToggle,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            if (collapsed) Icon(Icons.arrow_right, size: 18, color: cs.onSurfaceVariant),
            ExcludeSemantics(child: avatar),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelLarge?.copyWith(
                  fontWeight: placeholder ? FontWeight.w500 : FontWeight.w700,
                  color: placeholder ? cs.onSurfaceVariant : null,
                  fontStyle: placeholder ? FontStyle.italic : null,
                ),
              ),
            ),
            if (isOp && !placeholder) ...[const SizedBox(width: 4), const _OpBadge()],
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '· $meta',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ]),
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: highlighted ? cs.primaryContainer.withValues(alpha: 0.45) : cs.primaryContainer.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.only(right: 4, top: 2),
      child: Opacity(
        opacity: pending ? 0.55 : 1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: header),
            if (!collapsed && actions.isNotEmpty && !pending)
              SizedBox(
                width: 36,
                height: 28,
                child: PopupMenuButton<_CommentAction>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  tooltip: l10n.nutritionCommentOptions,
                  icon: Icon(Icons.more_horiz, color: cs.onSurfaceVariant),
                  onSelected: (a) async {
                    switch (a) {
                      case _CommentAction.edit:
                        onEdit!(c);
                      case _CommentAction.delete:
                        onDelete!(c);
                      case _CommentAction.copy:
                        await Clipboard.setData(ClipboardData(text: c.body));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.feedCopied)));
                        }
                    }
                  },
                  itemBuilder: (_) => [
                    for (final a in actions)
                      PopupMenuItem(
                        value: a,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(switch (a) {
                            _CommentAction.edit => Icons.edit_outlined,
                            _CommentAction.delete => Icons.delete_outline,
                            _CommentAction.copy => Icons.copy_rounded,
                          }),
                          title: Text(switch (a) {
                            _CommentAction.edit => l10n.commonEdit,
                            _CommentAction.delete => l10n.commonDelete,
                            _CommentAction.copy => l10n.feedCopyText,
                          }),
                        ),
                      ),
                  ],
                ),
              ),
          ]),
          if (!collapsed) ...[
            if (!placeholder && c.body.isNotEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: pending ? null : onToggle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 28, right: 4),
                  child: Text(c.body, style: tt.bodyMedium),
                ),
              ),
            if (interactive)
              Padding(
                padding: const EdgeInsets.only(left: 22, bottom: 2),
                child: Row(children: [
                  ReactionButton(
                    dense: true,
                    current: c.myReaction,
                    onChanged: (r) => onReact?.call(c, r),
                  ),
                  if (canReply)
                    InkWell(
                      onTap: () => onReply!(c),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.reply_rounded, size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            l10n.feedReply,
                            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                          ),
                        ]),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: ReactionSummaryView(
                      dense: true,
                      summary: c.reactions,
                      onTap: () => showReactionBreakdownSheet(context, c.reactions),
                    ),
                  ),
                ]),
              )
            else
              const SizedBox(height: 4),
          ],
        ]),
      ),
    );
  }
}

class _OpBadge extends StatelessWidget {
  const _OpBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.l10n.feedOriginalPoster,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(4)),
        child: Text(
          context.l10n.feedOp,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800, fontSize: 10),
        ),
      ),
    );
  }
}
