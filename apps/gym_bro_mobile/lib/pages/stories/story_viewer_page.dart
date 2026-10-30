import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/l10n.dart';
import '../../models/reaction.dart';
import '../../models/shared_content.dart';
import '../../models/social.dart';
import '../../models/story.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/share_sheet.dart';
import '../../widgets/shared_content_card.dart';
import '../../widgets/social_widgets.dart';

// The full-screen story viewer, Instagram-style: one page per person (swipe
// sideways between people, with a cube turn), segmented progress bars, tap
// right / left for the next / previous story, hold to pause, swipe down to
// close. On someone else's story, swipe up for quick emoji reactions (sent
// to their DMs as "Reacted 🔥 to your story"), reply below, or like it. On
// my own, swipe up (or "Activity") for who watched it.

/// Opens the viewer on [users]' live stories (the tray order), starting at
/// [initialIndex] and each person's first unwatched story. Resolves when it
/// closes; [onSeen] reports a person whose stories were all watched.
Future<void> openUserStories(
  BuildContext context,
  List<SocialUser> users, {
  int initialIndex = 0,
  void Function(String userId)? onSeen,
}) async {
  if (users.isEmpty) return;
  await Navigator.of(context).push(_route(StoryViewerPage(
    reels: [for (final u in users) StoryReel.user(u)],
    initialIndex: initialIndex.clamp(0, users.length - 1),
    onSeen: onSeen,
  )));
}

/// Opens the viewer on a fixed list of stories (one author — e.g. the
/// archive), starting at [initialIndex].
Future<void> openStoryList(BuildContext context, List<Story> stories, {int initialIndex = 0}) async {
  if (stories.isEmpty) return;
  await Navigator.of(context).push(_route(StoryViewerPage(
    reels: [StoryReel.fixed(stories, initialIndex: initialIndex.clamp(0, stories.length - 1))],
  )));
}

/// Loads and opens one story (a notification, a story reply in chat);
/// explains when it's gone.
Future<void> openStoryById(BuildContext context, String storyId) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  Story story;
  try {
    final token = await AuthManager.instance.getValidToken();
    story = await ApiService().getStory(token, storyId);
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(l10n.storyUnavailable)));
    return;
  }
  if (context.mounted) await openStoryList(context, [story]);
}

Route<void> _route(Widget page) => PageRouteBuilder<void>(
  opaque: true,
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, animation, _, child) => FadeTransition(
    opacity: animation,
    child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(animation), child: child),
  ),
);

/// One person's stories in the viewer: loaded on demand ([user]) or given.
class StoryReel {
  StoryReel.user(SocialUser this.user)
    : stories = null,
      initialIndex = null;

  StoryReel.fixed(List<Story> this.stories, {this.initialIndex = 0}) : user = stories.first.author;

  final SocialUser? user;
  final List<Story>? stories;

  /// Fixed reels start here; loaded ones at the first unwatched story.
  final int? initialIndex;
}

class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({super.key, required this.reels, this.initialIndex = 0, this.onSeen});

  final List<StoryReel> reels;
  final int initialIndex;
  final void Function(String userId)? onSeen;

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _current = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_current + 1 >= widget.reels.length) return _close();
    _pages.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
  }

  void _previous() {
    if (_current == 0) return;
    _pages.previousPage(duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
  }

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: PageView.builder(
          controller: _pages,
          itemCount: widget.reels.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (context, i) => AnimatedBuilder(
            animation: _pages,
            builder: (context, child) {
              // A cube turn between people.
              final page = _pages.hasClients && _pages.position.haveDimensions ? _pages.page ?? _current.toDouble() : _current.toDouble();
              final delta = (i - page).clamp(-1.0, 1.0);
              return Transform(
                alignment: delta > 0 ? Alignment.centerLeft : Alignment.centerRight,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(delta * math.pi / 2.6),
                child: child,
              );
            },
            child: _ReelView(
              key: ValueKey(i),
              reel: widget.reels[i],
              active: i == _current,
              onNextReel: _next,
              onPreviousReel: _previous,
              onClose: _close,
              onAllSeen: widget.onSeen,
            ),
          ),
        ),
      ),
    );
  }
}

/// One person's stories: progress, playback and the overlays.
class _ReelView extends StatefulWidget {
  const _ReelView({
    super.key,
    required this.reel,
    required this.active,
    required this.onNextReel,
    required this.onPreviousReel,
    required this.onClose,
    this.onAllSeen,
  });

  final StoryReel reel;

  /// The page on screen: plays only then.
  final bool active;
  final VoidCallback onNextReel;
  final VoidCallback onPreviousReel;
  final VoidCallback onClose;
  final void Function(String userId)? onAllSeen;

  @override
  State<_ReelView> createState() => _ReelViewState();
}

class _ReelViewState extends State<_ReelView> with TickerProviderStateMixin {
  final _api = ApiService();
  final _reply = TextEditingController();
  final _replyFocus = FocusNode();
  late final AnimationController _progress = AnimationController(vsync: this)..addStatusListener(_onProgressStatus);
  late final AnimationController _sentAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  List<Story>? _stories;
  int _index = 0;
  String? _error;

  /// Reasons to hold the progress (holding a finger, typing, a sheet…).
  bool _holding = false;
  bool _reactionsOpen = false;
  bool _sheetOpen = false;
  bool _mediaReady = false;
  VideoPlayerController? _video;
  String? _sentEmoji;
  String? _sentText;
  final _viewed = <String>{};

  Story? get _story => _stories == null || _stories!.isEmpty ? null : _stories![_index];

  bool get _paused => _holding || _reactionsOpen || _sheetOpen || _replyFocus.hasFocus || !widget.active || !_mediaReady;

  @override
  void initState() {
    super.initState();
    _replyFocus.addListener(_syncPlayback);
    _load();
  }

  @override
  void didUpdateWidget(_ReelView old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      if (widget.active) {
        _show(_index);
      } else {
        _replyFocus.unfocus();
        _syncPlayback();
      }
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _sentAnim.dispose();
    _video?.dispose();
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final fixed = widget.reel.stories;
    if (fixed != null) {
      setState(() => _stories = List.of(fixed));
      _index = widget.reel.initialIndex ?? 0;
      if (widget.active) _show(_index);
      return;
    }
    try {
      final token = await AuthManager.instance.getValidToken();
      final stories = await _api.getUserStories(token, widget.reel.user!.id);
      if (!mounted) return;
      if (stories.isEmpty) {
        // Expired or deleted since the tray loaded.
        setState(() => _stories = const []);
        if (widget.active) widget.onNextReel();
        return;
      }
      final firstUnseen = stories.indexWhere((s) => !s.seen);
      setState(() => _stories = stories);
      _index = firstUnseen < 0 ? 0 : firstUnseen;
      if (widget.active) _show(_index);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Shows story [i]: resets the progress, prepares the media, records the view.
  void _show(int i) {
    final stories = _stories;
    if (stories == null || stories.isEmpty) return;
    _index = i.clamp(0, stories.length - 1);
    final story = stories[_index];
    _progress
      ..stop()
      ..value = 0
      ..duration = story.displayDuration;
    _video?.dispose();
    _video = null;
    setState(() => _mediaReady = !story.hasMedia);
    if (story.hasMedia) _prepareMedia(story);
    _markViewed(story);
    _syncPlayback();
    _precacheNext();
  }

  Future<void> _prepareMedia(Story story) async {
    if (story.isVideo) {
      final c = VideoPlayerController.networkUrl(Uri.parse(story.mediaUrl!));
      _video = c;
      try {
        await c.initialize();
      } catch (_) {
        // Couldn't load: show the placeholder for the usual time.
      }
      if (!mounted || _video != c || _story?.id != story.id) return;
      final length = c.value.duration;
      if (length > Duration.zero) _progress.duration = length > const Duration(minutes: 1) ? const Duration(minutes: 1) : length;
    } else {
      try {
        await precacheImage(StableNetworkImage(story.mediaUrl!), context);
      } catch (_) {}
      if (!mounted || _story?.id != story.id) return;
    }
    setState(() => _mediaReady = true);
    _syncPlayback();
  }

  void _precacheNext() {
    final stories = _stories!;
    if (_index + 1 < stories.length) {
      final next = stories[_index + 1];
      if (next.hasMedia && !next.isVideo) precacheImage(StableNetworkImage(next.mediaUrl!), context, onError: (_, _) {});
    }
  }

  void _markViewed(Story story) {
    if (story.isMine || !_viewed.add(story.id)) return;
    if (!story.seen) {
      AuthManager.instance.getValidToken().then((t) => _api.markStoryViewed(t, story.id)).catchError((_) {});
      _stories = [for (final s in _stories!) s.id == story.id ? s.copyWith(seen: true) : s];
    }
    if (_stories!.every((s) => s.seen) && widget.reel.user != null) widget.onAllSeen?.call(widget.reel.user!.id);
  }

  void _syncPlayback() {
    if (!mounted) return;
    final video = _video;
    if (_paused) {
      _progress.stop();
      if (video != null && video.value.isInitialized) video.pause();
    } else {
      _progress.forward();
      if (video != null && video.value.isInitialized) video.play();
    }
    setState(() {});
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _next();
  }

  void _next() {
    final stories = _stories;
    if (stories == null || _index + 1 >= stories.length) return widget.onNextReel();
    _show(_index + 1);
  }

  void _previous() {
    if (_index == 0) {
      // Restart the first one, or go back a person.
      if (_progress.value > 0.15 || widget.reel.stories != null) {
        _show(0);
      } else {
        widget.onPreviousReel();
      }
      return;
    }
    _show(_index - 1);
  }

  // ── Actions ──

  Future<String> _token() => AuthManager.instance.getValidToken();

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
  }

  Future<void> _toggleLike() async {
    final story = _story;
    if (story == null) return;
    final to = story.liked ? null : ReactionType.like;
    _replace(story.copyWith(myReaction: to, clearMyReaction: to == null));
    try {
      final r = await _api.reactToStory(await _token(), story.id, to);
      if (mounted) _replace(_story!.copyWith(myReaction: r.myReaction, clearMyReaction: r.myReaction == null));
    } catch (e) {
      if (mounted) _replace(story);
      _showError(e);
    }
  }

  void _replace(Story updated) {
    setState(() => _stories = [for (final s in _stories!) s.id == updated.id ? updated : s]);
  }

  Future<void> _sendReaction(ReactionType reaction) async {
    final story = _story;
    if (story == null) return;
    setState(() => _reactionsOpen = false);
    _celebrate(reaction.emoji, context.l10n.storyReactionSent);
    try {
      await _api.replyToStory(await _token(), story.id, reaction: reaction);
    } catch (e) {
      _showError(e);
    }
    _syncPlayback();
  }

  Future<void> _sendReply() async {
    final story = _story;
    final text = _reply.text.trim();
    if (story == null || text.isEmpty) return;
    _reply.clear();
    _replyFocus.unfocus();
    setState(() => _reactionsOpen = false);
    _celebrate(null, context.l10n.storyReplySent);
    try {
      await _api.replyToStory(await _token(), story.id, body: text);
    } catch (e) {
      _reply.text = text;
      _showError(e);
    }
  }

  /// The brief "Sent" confirmation (with the emoji floating up for a reaction).
  void _celebrate(String? emoji, String text) {
    setState(() {
      _sentEmoji = emoji;
      _sentText = text;
    });
    _sentAnim.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _sentText = null);
    });
  }

  Future<void> _withPause(Future<void> Function() action) async {
    setState(() => _sheetOpen = true);
    _syncPlayback();
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _sheetOpen = false);
        _syncPlayback();
      }
    }
  }

  Future<void> _sendTo() async {
    final story = _story;
    if (story == null) return;
    await _withPause(() => showShareSheet(context, ShareRequest.of(ShareKind.story, story.id, title: story.author?.fullName)));
  }

  Future<void> _delete() async {
    final story = _story;
    if (story == null) return;
    final l10n = context.l10n;
    await _withPause(() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.storyDeleteConfirmTitle),
          content: Text(l10n.storyDeleteConfirmBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.commonDelete)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      try {
        await _api.deleteStory(await _token(), story.id);
      } catch (e) {
        return _showError(e);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.storyDeleted)));
      final rest = _stories!.where((s) => s.id != story.id).toList();
      if (rest.isEmpty) {
        setState(() => _stories = rest);
        widget.onNextReel();
        return;
      }
      setState(() => _stories = rest);
      _show(_index.clamp(0, rest.length - 1));
    });
  }

  Future<void> _openViewers() async {
    final story = _story;
    if (story == null) return;
    await _withPause(() => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => StoryViewersSheet(story: story),
    ));
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v > 300) {
      if (_reactionsOpen) return setState(() => _reactionsOpen = false);
      widget.onClose();
    } else if (v < -300) {
      final story = _story;
      if (story == null) return;
      if (story.isMine) {
        _openViewers();
      } else if (story.isLive) {
        setState(() => _reactionsOpen = true);
        _syncPlayback();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stories = _stories;
    if (_error != null) {
      return _Centered(
        onClose: widget.onClose,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.storyLoadFailed, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        ]),
      );
    }
    if (stories == null) return _Centered(onClose: widget.onClose, child: const CircularProgressIndicator());
    final story = _story;
    if (story == null) return _Centered(onClose: widget.onClose, child: Text(l10n.storyUnavailable));

    return SafeArea(
      child: Stack(children: [
        // The story itself, with the tap / hold / swipe gestures.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              if (_reactionsOpen) return setState(() => _reactionsOpen = false);
              if (_replyFocus.hasFocus) return _replyFocus.unfocus();
              final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
              d.localPosition.dx < width / 3 ? _previous() : _next();
            },
            onLongPressStart: (_) {
              _holding = true;
              _syncPlayback();
            },
            onLongPressEnd: (_) {
              _holding = false;
              _syncPlayback();
            },
            onVerticalDragEnd: _onVerticalDragEnd,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _StoryBody(story: story, video: _video, mediaReady: _mediaReady),
            ),
          ),
        ),
        // Progress + header.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: AnimatedOpacity(
            opacity: _holding ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black45, Colors.transparent]),
              ),
              child: Column(children: [
                _ProgressBars(count: stories.length, index: _index, progress: _progress),
                const SizedBox(height: 8),
                _header(context, story),
              ]),
            ),
          ),
        ),
        if (_reactionsOpen) Positioned.fill(child: _reactionsPanel(context)),
        // Footer.
        Positioned(left: 0, right: 0, bottom: 0, child: story.isMine ? _ownFooter(context, story) : _replyFooter(context, story)),
        if (_sentText != null) Positioned.fill(child: IgnorePointer(child: _sentOverlay())),
      ]),
    );
  }

  Widget _header(BuildContext context, Story story) {
    final l10n = context.l10n;
    final author = story.author ?? widget.reel.user;
    final time = story.isLive ? _ago(l10n, story.createdAt) : MaterialLocalizations.of(context).formatMediumDate(story.createdAt);
    return Row(children: [
      UserAvatar(url: author?.avatarUrl, initials: author?.initials ?? '?', radius: 16),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          author == null ? '' : (author.username.isNotEmpty ? author.username : author.fullName),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(width: 8),
      Text(time, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      if (!story.isLive) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6)),
          child: Text(l10n.storyArchivedLabel, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
      ],
      const Spacer(),
      if (story.isMine)
        PopupMenuButton<String>(
          tooltip: l10n.storyMore,
          icon: const Icon(Icons.more_horiz, color: Colors.white),
          onOpened: () {
            setState(() => _sheetOpen = true);
            _syncPlayback();
          },
          onCanceled: () {
            setState(() => _sheetOpen = false);
            _syncPlayback();
          },
          onSelected: (v) {
            setState(() => _sheetOpen = false);
            _syncPlayback();
            if (v == 'delete') _delete();
            if (v == 'send') _sendTo();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'send',
              child: ListTile(leading: const Icon(Icons.send_outlined), title: Text(l10n.storySendTo), contentPadding: EdgeInsets.zero),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(l10n.storyDelete), contentPadding: EdgeInsets.zero),
            ),
          ],
        ),
      IconButton(
        tooltip: l10n.storyClose,
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: widget.onClose,
      ),
    ]);
  }

  Widget _replyFooter(BuildContext context, Story story) {
    final l10n = context.l10n;
    if (!story.isLive) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _reply,
            focusNode: _replyFocus,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendReply(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l10n.storySendMessageHint,
              hintStyle: const TextStyle(color: Colors.white70),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: Colors.white70)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: Colors.white)),
              suffixIcon: ListenableBuilder(
                listenable: _reply,
                builder: (_, _) => _reply.text.trim().isEmpty
                    ? const SizedBox.shrink()
                    : TextButton(onPressed: _sendReply, child: Text(l10n.storySend)),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: story.liked ? l10n.storyUnlike : l10n.storyLike,
          onPressed: _toggleLike,
          icon: story.liked
              ? const Icon(Icons.favorite, color: Color(0xFFFF3040))
              : const Icon(Icons.favorite_border, color: Colors.white),
        ),
        IconButton(
          tooltip: l10n.storySendTo,
          onPressed: _sendTo,
          icon: const Icon(Icons.send_outlined, color: Colors.white),
        ),
      ]),
    );
  }

  Widget _ownFooter(BuildContext context, Story story) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(children: [
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: _openViewers,
          icon: const Icon(Icons.visibility_outlined),
          label: Text(l10n.storyActivityCount(story.viewCount ?? 0)),
        ),
        if ((story.reactionCount ?? 0) > 0) ...[
          const SizedBox(width: 4),
          const Icon(Icons.favorite, size: 16, color: Color(0xFFFF3040)),
          const SizedBox(width: 4),
          Text('${story.reactionCount}', style: const TextStyle(color: Colors.white)),
        ],
        const Spacer(),
        IconButton(tooltip: l10n.storySendTo, onPressed: _sendTo, icon: const Icon(Icons.send_outlined, color: Colors.white)),
      ]),
    );
  }

  Widget _reactionsPanel(BuildContext context) {
    final l10n = context.l10n;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _reactionsOpen = false);
        _syncPlayback();
      },
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Transform.scale(scale: t, child: child),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.storyQuickReactions, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 18,
              children: [
                for (final r in kStoryQuickReactions)
                  Semantics(
                    button: true,
                    label: r.apiValue,
                    child: InkResponse(
                      key: ValueKey('story-reaction-${r.apiValue}'),
                      radius: 36,
                      onTap: () => _sendReaction(r),
                      child: Text(r.emoji, style: const TextStyle(fontSize: 44)),
                    ),
                  ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sentOverlay() => AnimatedBuilder(
    animation: _sentAnim,
    builder: (context, _) {
      final t = _sentAnim.value;
      final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
      return Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_sentEmoji != null)
            Transform.translate(
              offset: Offset(0, -120 * Curves.easeOut.transform(t)),
              child: Transform.scale(
                scale: 1 + 0.8 * Curves.elasticOut.transform(math.min(1, t * 2)),
                child: Text(_sentEmoji!, style: const TextStyle(fontSize: 64)),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
            child: Text(_sentText ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
    },
  );
}

String _ago(AppLocalizations l10n, DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return l10n.shellTimeNow;
  if (diff.inHours < 1) return l10n.shellTimeMinutesShort(diff.inMinutes);
  if (diff.inDays < 1) return l10n.shellTimeHoursShort(diff.inHours);
  return l10n.shellTimeDaysShort(diff.inDays);
}

/// The segmented bars at the top: done, the current one filling, upcoming.
class _ProgressBars extends StatelessWidget {
  const _ProgressBars({required this.count, required this.index, required this.progress});

  final int count;
  final int index;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) => Row(children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 2.5,
                value: i < index ? 1 : (i == index ? progress.value : 0),
                backgroundColor: Colors.white30,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// What a story shows: its photo/video, or text / a shared thing on its colour.
class _StoryBody extends StatelessWidget {
  const _StoryBody({required this.story, required this.video, required this.mediaReady});

  final Story story;
  final VideoPlayerController? video;
  final bool mediaReady;

  @override
  Widget build(BuildContext context) {
    final caption = story.caption;
    if (story.hasMedia) {
      final v = video;
      return Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Colors.black),
        if (story.isVideo)
          (v != null && v.value.isInitialized)
              ? FittedBox(fit: BoxFit.contain, child: SizedBox(width: v.value.size.width, height: v.value.size.height, child: VideoPlayer(v)))
              : const SizedBox.shrink()
        else
          Image(
            image: StableNetworkImage(story.mediaUrl!),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
          ),
        if (!mediaReady) const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (caption != null && caption.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: Text(
              caption,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
              ),
            ),
          ),
      ]);
    }
    final share = story.share;
    return Container(
      color: story.backgroundColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 96),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: share == null ? 0 : 20),
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: share == null ? 30 : 20, fontWeight: FontWeight.w700, height: 1.2),
              ),
            ),
          if (share != null) SharedContentCard(content: share, onDark: true, maxWidth: 320),
        ]),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child, required this.onClose});

  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Stack(children: [
      Center(child: DefaultTextStyle(style: const TextStyle(color: Colors.white), child: child)),
      Positioned(
        right: 4,
        top: 4,
        child: IconButton(
          tooltip: context.l10n.storyClose,
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: onClose,
        ),
      ),
    ]),
  );
}

/// Who watched my story, those who reacted first (heart / emoji on the right).
class StoryViewersSheet extends StatefulWidget {
  const StoryViewersSheet({super.key, required this.story});

  final Story story;

  @override
  State<StoryViewersSheet> createState() => _StoryViewersSheetState();
}

class _StoryViewersSheetState extends State<StoryViewersSheet> {
  late final Future<List<StoryViewer>> _viewers = AuthManager.instance
      .getValidToken()
      .then((t) => ApiService().getStoryViewers(t, widget.story.id));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: FutureBuilder<List<StoryViewer>>(
          future: _viewers,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) {
              return Center(child: Text(snap.error.toString().replaceFirst('Exception: ', '')));
            }
            final viewers = snap.data!;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(l10n.storyViewsCount(viewers.length), style: Theme.of(context).textTheme.titleMedium),
              ),
              if (viewers.isEmpty)
                Expanded(child: Center(child: Text(l10n.storyNoViewers, style: TextStyle(color: cs.onSurfaceVariant))))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: viewers.length,
                    itemBuilder: (context, i) {
                      final v = viewers[i];
                      return ListTile(
                        leading: UserAvatar(url: v.user.avatarUrl, initials: v.user.initials),
                        title: Text(v.user.fullName.isNotEmpty ? v.user.fullName : v.user.username),
                        subtitle: v.user.username.isEmpty ? null : Text('@${v.user.username}'),
                        trailing: v.reaction == null
                            ? null
                            : v.reaction == ReactionType.like
                            ? const Icon(Icons.favorite, color: Color(0xFFFF3040))
                            : Text(v.reaction!.emoji, style: const TextStyle(fontSize: 22)),
                      );
                    },
                  ),
                ),
            ]);
          },
        ),
      ),
    );
  }
}
