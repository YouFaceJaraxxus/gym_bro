import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/post.dart';
import '../models/reaction.dart';
import '../models/social.dart';
import '../pages/feed/post_detail_page.dart';
import '../pages/feed/reactions_sheet.dart';
import '../pages/people/user_profile_page.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'reactions.dart';
import 'social_widgets.dart';

/// One post as a feed card (Instagram + Facebook): header, media carousel,
/// caption, reaction/comment stats and the action row.
///
/// The card keeps a local copy of [post] so it works on its own, and reports
/// every change (reactions, edits, comment count from the detail page) through
/// [onChanged] so a parent list can keep its state. Callbacks may fire after
/// the card scrolled away, so parents should check `mounted`.
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onChanged,
    this.onDeleted,
    this.onOpenComments,
    this.onEdit,
    this.onBusinessTap,
    this.expandCaption = false,
    this.linkAuthor = true,
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  final Post post;

  /// The post after a reaction, edit or comment-count change.
  final ValueChanged<Post>? onChanged;

  /// The post was deleted (after confirmation and a successful API call).
  final VoidCallback? onDeleted;

  /// "Comment" / "N comments". Defaults to opening [PostDetailPage].
  final VoidCallback? onOpenComments;

  /// Replaces the built-in caption/visibility editor (business posts edit
  /// text + images in their own form).
  final VoidCallback? onEdit;

  /// Tapping a business post's header.
  final VoidCallback? onBusinessTap;

  /// Show the whole caption (detail page) instead of three lines + "more".
  final bool expandCaption;

  /// Tapping the author opens their profile.
  final bool linkAuthor;

  final EdgeInsetsGeometry margin;

  @override
  State<PostCard> createState() => _PostCardState();
}

enum _PostAction { edit, delete, copy }

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late Post _post = widget.post;
  int _reactSeq = 0;
  bool _deleting = false;

  late final AnimationController _heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void didUpdateWidget(PostCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.post, widget.post)) _post = widget.post;
  }

  @override
  void dispose() {
    _heart.dispose();
    super.dispose();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _setPost(Post p) {
    if (mounted) setState(() => _post = p);
    _post = p;
    widget.onChanged?.call(p);
  }

  Post _withReaction(Post p, ReactionSummary reactions, ReactionType? mine) =>
      p.copyWith(reactions: reactions, myReaction: mine, clearMyReaction: mine == null);

  /// Optimistic: show the new reaction now, reconcile with the server's
  /// counts, roll back (+ snackbar) on failure. Only the latest tap wins.
  Future<void> _react(ReactionType? to) async {
    final before = _post;
    if (before.myReaction == to) return;
    final seq = ++_reactSeq;
    final messenger = ScaffoldMessenger.maybeOf(context);
    _setPost(before.withMyReaction(to));
    try {
      final token = await AuthManager.instance.getValidToken();
      final res = await _api.reactToPost(token, before.id, to);
      if (seq != _reactSeq) return;
      _setPost(_withReaction(_post, res.reactions, res.myReaction));
    } catch (e) {
      if (seq != _reactSeq) return;
      _setPost(_withReaction(_post, before.reactions, before.myReaction));
      messenger?.showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  void _doubleTapLove() {
    HapticFeedback.lightImpact();
    _heart.forward(from: 0);
    // Instagram: a double tap only ever adds, never removes.
    if (_post.myReaction != ReactionType.love) _react(ReactionType.love);
  }

  void _openDetail() {
    if (widget.onOpenComments != null) {
      widget.onOpenComments!();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PostDetailPage(
        postId: _post.id,
        initial: _post,
        onChanged: _setPost,
        onDeleted: widget.onDeleted,
      ),
    ));
  }

  void _openAuthor() {
    final author = _post.author;
    if (author == null || !widget.linkAuthor) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserProfilePage(userId: author.id)));
  }

  Future<void> _onAction(_PostAction action) async {
    switch (action) {
      case _PostAction.copy:
        await Clipboard.setData(ClipboardData(text: _post.content));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.feedCopied)));
        }
      case _PostAction.edit:
        if (widget.onEdit != null) {
          widget.onEdit!();
        } else {
          await _editInline();
        }
      case _PostAction.delete:
        await _delete();
    }
  }

  Future<void> _editInline() async {
    final result = await showModalBottomSheet<(String, PostVisibility)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditPostSheet(post: _post),
    );
    if (result == null || !mounted) return;
    final (content, visibility) = result;
    if (content == _post.content && visibility == _post.visibility) return;
    final before = _post;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    _setPost(before.copyWith(content: content, visibility: visibility));
    try {
      final token = await AuthManager.instance.getValidToken();
      final saved = await SocialApi(_api).updatePost(
        token,
        before.id,
        content: content,
        visibility: before.isPersonal ? visibility : null,
      );
      _setPost(saved);
      messenger.showSnackBar(SnackBar(content: Text(l10n.feedPostUpdated)));
    } catch (e) {
      _setPost(_post.copyWith(content: before.content, visibility: before.visibility));
      messenger.showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.nutritionDeletePostTitle),
        content: Text(ctx.l10n.nutritionCannotBeUndone),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.commonDelete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deletePost(token, _post.id);
      widget.onDeleted?.call();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_msg(e))));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = _post;
    return Card(
      margin: widget.margin,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(),
      child: AnimatedOpacity(
        opacity: _deleting ? 0.4 : 1,
        duration: const Duration(milliseconds: 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, p),
            if (p.content.isNotEmpty && p.images.isEmpty) _captionBlock(p, large: true),
            if (p.images.isNotEmpty)
              _PostMedia(
                images: p.images,
                heart: _heart,
                onDoubleTap: _doubleTapLove,
              ),
            if (p.content.isNotEmpty && p.images.isNotEmpty) _captionBlock(p),
            _stats(context, p),
            Divider(height: 1, indent: 12, endIndent: 12, color: cs.outlineVariant.withValues(alpha: 0.5)),
            _actions(context, p),
          ],
        ),
      ),
    );
  }

  Widget _captionBlock(Post p, {bool large = false}) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
    child: ExpandableCaption(text: p.content, expanded: widget.expandCaption, large: large && p.content.length < 140),
  );

  Widget _header(BuildContext context, Post p) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final business = p.business;
    final author = p.author;
    final isBusiness = !p.isPersonal;

    final String title;
    final Widget avatar;
    if (isBusiness && business != null) {
      title = business.name;
      avatar = UserAvatar(url: business.logo, initials: _initialsOf(business.name), radius: 18);
    } else {
      title = author?.fullName.isNotEmpty == true ? author!.fullName : l10n.nutritionDeletedUser;
      avatar = UserAvatar(url: author?.avatarUrl, initials: author?.initials ?? '?', radius: 18);
    }

    final meta = <String>[
      if (!isBusiness && author != null && author.username.isNotEmpty) '@${author.username}',
      if (isBusiness && author != null && author.fullName.isNotEmpty) l10n.feedPostedBy(author.fullName),
      relativeTime(l10n, p.createdAt.toLocal()),
      if (p.updatedAt.difference(p.createdAt).inMinutes >= 1) l10n.nutritionEditedLower,
    ];

    final onHeaderTap = isBusiness ? widget.onBusinessTap : (widget.linkAuthor && author != null ? _openAuthor : null);
    final actions = <_PostAction>[
      if (p.canEdit) _PostAction.edit,
      if (p.canEdit) _PostAction.delete,
      if (p.content.isNotEmpty) _PostAction.copy,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 0, 6),
      child: Row(children: [
        Expanded(
          child: Semantics(
            button: onHeaderTap != null,
            label: onHeaderTap != null && !isBusiness ? l10n.feedOpenProfile(title) : null,
            child: InkWell(
              onTap: onHeaderTap,
              borderRadius: BorderRadius.circular(8),
              child: Row(children: [
                ExcludeSemantics(child: avatar),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Row(children: [
                      Flexible(
                        child: Text(
                          meta.join(' · '),
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (p.isPersonal) ...[
                        Text(' · ', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        Tooltip(
                          message: p.visibility == PostVisibility.public ? l10n.feedVisibilityPublic : l10n.feedVisibilityFollowers,
                          child: Icon(
                            p.visibility == PostVisibility.public ? Icons.public : Icons.people_alt_outlined,
                            size: 13,
                            color: cs.onSurfaceVariant,
                            semanticLabel: p.visibility == PostVisibility.public
                                ? l10n.feedVisibilityPublic
                                : l10n.feedVisibilityFollowers,
                          ),
                        ),
                      ],
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        if (actions.isEmpty)
          const SizedBox(width: 12)
        else
          PopupMenuButton<_PostAction>(
            tooltip: l10n.feedPostOptions,
            icon: Icon(Icons.more_horiz, color: cs.onSurfaceVariant),
            onSelected: _onAction,
            itemBuilder: (ctx) => [
              for (final a in actions)
                PopupMenuItem(
                  value: a,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(switch (a) {
                      _PostAction.edit => Icons.edit_outlined,
                      _PostAction.delete => Icons.delete_outline,
                      _PostAction.copy => Icons.copy_rounded,
                    }),
                    title: Text(switch (a) {
                      _PostAction.edit => l10n.nutritionEditPost,
                      _PostAction.delete => l10n.nutritionDeletePost,
                      _PostAction.copy => l10n.feedCopyText,
                    }),
                  ),
                ),
            ],
          ),
      ]),
    );
  }

  Widget _stats(BuildContext context, Post p) {
    if (p.reactions.total == 0 && p.commentCount == 0) return const SizedBox(height: 4);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Row(children: [
        ReactionSummaryView(summary: p.reactions, onTap: () => showReactionsSheet(context, p)),
        const Spacer(),
        if (p.commentCount > 0)
          InkWell(
            onTap: _openDetail,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                context.l10n.nutritionCommentCount(p.commentCount),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _actions(BuildContext context, Post p) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(children: [
        Expanded(child: Center(child: ReactionButton(current: p.myReaction, onChanged: _react))),
        Expanded(
          child: Center(
            child: Semantics(
              button: true,
              label: l10n.nutritionComment,
              excludeSemantics: true,
              child: InkWell(
                onTap: _openDetail,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.mode_comment_outlined, size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      l10n.nutritionComment,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((s) => s[0].toUpperCase()).join();
}

// ── Caption ───────────────────────────────────────────────────────────────────

/// Caption text clamped to three lines with a "… more" toggle.
class ExpandableCaption extends StatefulWidget {
  const ExpandableCaption({super.key, required this.text, this.expanded = false, this.large = false, this.maxLines = 3});

  final String text;
  final bool expanded;

  /// Bigger type for short text-only posts (Facebook style).
  final bool large;
  final int maxLines;

  @override
  State<ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<ExpandableCaption> {
  late bool _expanded = widget.expanded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final style = widget.large ? tt.titleMedium : tt.bodyMedium;
    if (_expanded) return SelectableText(widget.text, style: style);
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: widget.maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();
      final text = Text(widget.text, style: style, maxLines: widget.maxLines, overflow: TextOverflow.ellipsis);
      if (!overflows) return text;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _expanded = true),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          text,
          Text(
            context.l10n.feedMore,
            style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
        ]),
      );
    });
  }
}

// ── Media carousel ────────────────────────────────────────────────────────────

/// Images/videos in a swipeable carousel: dot indicator, "1/3" badge,
/// double-tap → ❤️ with a heart pop. The aspect ratio follows the first item,
/// clamped between 4:5 and 1.91:1 (like Instagram).
class _PostMedia extends StatefulWidget {
  const _PostMedia({required this.images, required this.heart, required this.onDoubleTap});

  final List<PostImage> images;
  final Animation<double> heart;
  final VoidCallback onDoubleTap;

  @override
  State<_PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<_PostMedia> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [...widget.images]..sort((a, b) => a.position.compareTo(b.position));
    final first = items.first;
    final ratio = (first.aspectRatio ?? (first.isVideo ? 16 / 9 : 1.0)).clamp(0.8, 1.91);
    final page = _page.clamp(0, items.length - 1);

    return Semantics(
      hint: l10n.feedDoubleTapToLove,
      child: AspectRatio(
        aspectRatio: ratio,
        child: Stack(fit: StackFit.expand, children: [
          GestureDetector(
            onDoubleTap: widget.onDoubleTap,
            child: PageView.builder(
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _MediaItem(
                item: items[i],
                semanticLabel: items.length > 1 ? l10n.nutritionPostPhotoOf(i + 1, items.length) : l10n.nutritionPostPhoto,
              ),
            ),
          ),
          IgnorePointer(child: Center(child: _HeartPop(animation: widget.heart))),
          if (items.length > 1) ...[
            Positioned(
              top: 10,
              right: 10,
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    l10n.feedMediaIndex(page + 1, items.length),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: IgnorePointer(child: DotIndicator(count: items.length, index: page)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _MediaItem extends StatelessWidget {
  const _MediaItem({required this.item, required this.semanticLabel});

  final PostImage item;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (item.isVideo) {
      return Semantics(
        label: context.l10n.feedVideo,
        child: ColoredBox(
          color: Colors.black,
          child: Center(child: InlineVideo(url: item.url, aspectRatio: item.aspectRatio, autoplayMuted: true)),
        ),
      );
    }
    return Semantics(
      image: true,
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: () => MediaViewerPage.open(context, url: item.url),
        child: MediaImage(url: item.url),
      ),
    );
  }
}

/// Carousel dots; the current one is wider. Fades out beyond ten items.
class DotIndicator extends StatelessWidget {
  const DotIndicator({super.key, required this.count, required this.index, this.onMedia = true});

  final int count;
  final int index;

  /// White dots over media; otherwise theme colors.
  final bool onMedia;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = onMedia ? Colors.white : cs.primary;
    final idle = onMedia ? Colors.white54 : cs.outlineVariant;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          width: i == index ? 14 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == index ? active : idle,
            borderRadius: BorderRadius.circular(3),
            boxShadow: onMedia ? const [BoxShadow(color: Colors.black26, blurRadius: 2)] : null,
          ),
        ),
    ]);
  }
}

/// The big ❤️ that pops on double tap.
class _HeartPop extends StatelessWidget {
  const _HeartPop({required this.animation});

  final Animation<double> animation;

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.25).chain(CurveTween(curve: Curves.easeOut)), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 15),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 20),
  ]);
  static final _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
  ]);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        if (t == 0 || t == 1) return const SizedBox.shrink();
        return Opacity(
          opacity: _opacity.transform(t),
          child: Transform.scale(
            scale: _scale.transform(t),
            child: const Text('❤️', style: TextStyle(fontSize: 96, shadows: [Shadow(color: Colors.black38, blurRadius: 12)])),
          ),
        );
      },
    );
  }
}

// ── Edit sheet ────────────────────────────────────────────────────────────────

/// Caption + (personal posts) visibility. Pops with (caption, visibility).
class _EditPostSheet extends StatefulWidget {
  const _EditPostSheet({required this.post});

  final Post post;

  @override
  State<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<_EditPostSheet> {
  late final _caption = TextEditingController(text: widget.post.content);
  late PostVisibility _visibility = widget.post.visibility;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final valid = _caption.text.trim().isNotEmpty || widget.post.images.isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l10n.nutritionEditPostTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _caption,
            autofocus: true,
            minLines: 2,
            maxLines: 8,
            maxLength: kCaptionMaxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l10n.feedCaptionHint, border: const OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          if (widget.post.isPersonal) ...[
            const SizedBox(height: 8),
            VisibilitySelector(value: _visibility, onChanged: (v) => setState(() => _visibility = v)),
          ],
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: valid ? () => Navigator.pop(context, (_caption.text.trim(), _visibility)) : null,
              child: Text(l10n.commonSave),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Server limit for captions.
const kCaptionMaxLength = 2200;

/// Public / Followers segmented control with a one-line explanation.
class VisibilitySelector extends StatelessWidget {
  const VisibilitySelector({super.key, required this.value, required this.onChanged, this.enabled = true});

  final PostVisibility value;
  final ValueChanged<PostVisibility> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.feedVisibilityLabel, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      SegmentedButton<PostVisibility>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: PostVisibility.public, icon: const Icon(Icons.public, size: 18), label: Text(l10n.feedVisibilityPublic)),
          ButtonSegment(
            value: PostVisibility.followers,
            icon: const Icon(Icons.people_alt_outlined, size: 18),
            label: Text(l10n.feedVisibilityFollowers),
          ),
        ],
        selected: {value},
        onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
      ),
      const SizedBox(height: 4),
      Text(
        value == PostVisibility.public ? l10n.feedVisibilityPublicHint : l10n.feedVisibilityFollowersHint,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    ]);
  }
}
