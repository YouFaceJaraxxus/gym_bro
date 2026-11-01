import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/l10n.dart';
import '../../models/post.dart';
import '../../models/reaction.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/mentions.dart';
import '../../widgets/reactions.dart';
import '../../widgets/share_sheet.dart';
import '../../widgets/social_widgets.dart';
import '../feed/post_detail_page.dart';
import '../people/user_profile_page.dart';
import '../saved/save_collection_sheet.dart';

/// Full-screen vertical video player over the reels feed (GET
/// /posts/feed?mode=reels): swipe up/down between posts that open with a
/// video. The current one autoplays and loops; tap pauses, double tap reacts
/// ❤️, the side buttons react, open comments, share and save. Only the
/// current video and its neighbours keep a player.
class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> with WidgetsBindingObserver {
  static const _pageSize = 10;

  /// Players are kept for the current page ± this many.
  static const _keep = 1;

  final _api = ApiService();
  final _pages = PageController();
  final Map<String, VideoPlayerController> _players = {};
  final Set<String> _failed = {};
  List<Post> _posts = const [];
  int _index = 0;
  int _page = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _muted = false;

  /// Paused by the user (a tap); cleared when moving to another reel.
  bool _userPaused = false;

  /// Away from the page (detail page, app in background).
  bool _away = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _players.values) {
      c.dispose();
    }
    _players.clear();
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final away = state != AppLifecycleState.resumed;
    if (away == _away) return;
    _away = away;
    _syncPlayback();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  static PostImage? _videoOf(Post p) {
    final media = [...p.images]..sort((a, b) => a.position.compareTo(b.position));
    return media.isNotEmpty && media.first.isVideo ? media.first : null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final posts = await _api.getFeed(token, mode: FeedMode.reels, pageSize: _pageSize);
      if (!mounted) return;
      for (final c in _players.values) {
        c.dispose();
      }
      _players.clear();
      _failed.clear();
      setState(() {
        _posts = posts.where((p) => _videoOf(p) != null).toList();
        _page = 0;
        _hasMore = posts.length >= _pageSize;
        _loading = false;
        _index = 0;
        _userPaused = false;
      });
      if (_pages.hasClients) _pages.jumpToPage(0);
      _updatePlayers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _msg(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final more = await _api.getFeed(token, mode: FeedMode.reels, page: _page + 1, pageSize: _pageSize);
      if (!mounted) return;
      final known = _posts.map((p) => p.id).toSet();
      setState(() {
        _posts = [..._posts, ...more.where((p) => !known.contains(p.id) && _videoOf(p) != null)];
        _page++;
        _hasMore = more.length >= _pageSize;
        _loadingMore = false;
      });
      _updatePlayers();
    } catch (_) {
      // Scrolling to the end again retries.
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onPageChanged(int i) {
    setState(() {
      _index = i;
      _userPaused = false;
    });
    _updatePlayers();
    if (i >= _posts.length - 3) _loadMore();
  }

  /// Creates players around the current page, disposes the ones far away.
  void _updatePlayers() {
    final wanted = <String>{};
    for (var i = _index - _keep; i <= _index + _keep; i++) {
      if (i < 0 || i >= _posts.length) continue;
      final post = _posts[i];
      wanted.add(post.id);
      if (_players.containsKey(post.id) || _failed.contains(post.id)) continue;
      final video = _videoOf(post);
      if (video == null) continue;
      final c = VideoPlayerController.networkUrl(Uri.parse(video.url));
      _players[post.id] = c;
      c.initialize().then((_) async {
        if (!mounted || _players[post.id] != c) return;
        await c.setLooping(true);
        await c.setVolume(_muted ? 0 : 1);
        if (mounted) setState(() {});
        _syncPlayback();
      }).catchError((Object _) {
        if (!mounted || _players[post.id] != c) return;
        _players.remove(post.id);
        c.dispose();
        setState(() => _failed.add(post.id));
      });
    }
    for (final id in _players.keys.where((id) => !wanted.contains(id)).toList()) {
      _players.remove(id)!.dispose();
    }
    _syncPlayback();
  }

  /// Plays the current reel (unless paused or away), pauses the rest.
  void _syncPlayback() {
    final current = _index < _posts.length ? _posts[_index].id : null;
    for (final e in _players.entries) {
      final c = e.value;
      if (!c.value.isInitialized) continue;
      final play = e.key == current && !_userPaused && !_away;
      if (play && !c.value.isPlaying) {
        c.play();
      } else if (!play && c.value.isPlaying) {
        c.pause();
        if (e.key != current) c.seekTo(Duration.zero);
      }
    }
  }

  void _togglePause() {
    setState(() => _userPaused = !_userPaused);
    _syncPlayback();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    for (final c in _players.values) {
      if (c.value.isInitialized) c.setVolume(_muted ? 0 : 1);
    }
  }

  void _replace(Post updated) {
    if (!mounted) return;
    setState(() => _posts = [for (final p in _posts) p.id == updated.id ? updated : p]);
  }

  void _remove(String id) {
    if (!mounted) return;
    final i = _posts.indexWhere((p) => p.id == id);
    if (i < 0) return;
    _players.remove(id)?.dispose();
    setState(() {
      _posts = [..._posts]..removeAt(i);
      if (_index >= _posts.length) _index = (_posts.length - 1).clamp(0, 1 << 30);
    });
    _updatePlayers();
  }

  Future<void> _openDetail(Post post) async {
    _away = true;
    _syncPlayback();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PostDetailPage(
        postId: post.id,
        initial: post,
        onChanged: _replace,
        onDeleted: () => _remove(post.id),
      ),
    ));
    if (!mounted) return;
    _away = false;
    _syncPlayback();
  }

  Future<void> _openAuthor(Post post) async {
    final author = post.author;
    if (author == null) return;
    _away = true;
    _syncPlayback();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserProfilePage(userId: author.id)));
    if (!mounted) return;
    _away = false;
    _syncPlayback();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(l10n.postsReels, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              tooltip: _muted ? l10n.postsUnmute : l10n.postsMute,
              icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
              onPressed: _toggleMute,
            ),
          ],
        ),
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    if (_posts.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator(color: Colors.white));
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(_error != null ? Icons.cloud_off_outlined : Icons.movie_outlined, size: 52, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              _error ?? l10n.postsNoReelsTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            if (_error == null) ...[
              const SizedBox(height: 6),
              Text(l10n.postsNoReelsBody, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            ],
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: _load, child: Text(l10n.commonRetry)),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: PageView.builder(
        controller: _pages,
        scrollDirection: Axis.vertical,
        itemCount: _posts.length + (_loadingMore ? 1 : 0),
        onPageChanged: _onPageChanged,
        itemBuilder: (context, i) {
          if (i >= _posts.length) return const Center(child: CircularProgressIndicator(color: Colors.white));
          final post = _posts[i];
          return _Reel(
            key: ValueKey(post.id),
            post: post,
            controller: _players[post.id],
            failed: _failed.contains(post.id),
            paused: i == _index && _userPaused,
            onTogglePause: _togglePause,
            onChanged: _replace,
            onOpenComments: () => _openDetail(post),
            onOpenAuthor: () => _openAuthor(post),
          );
        },
      ),
    );
  }
}

/// One reel: the video (cover-fitted), tap to pause, double tap → ❤️, the
/// side buttons and the author + caption overlay.
class _Reel extends StatefulWidget {
  const _Reel({
    super.key,
    required this.post,
    required this.controller,
    required this.failed,
    required this.paused,
    required this.onTogglePause,
    required this.onChanged,
    required this.onOpenComments,
    required this.onOpenAuthor,
  });

  final Post post;
  final VideoPlayerController? controller;
  final bool failed;
  final bool paused;
  final VoidCallback onTogglePause;
  final ValueChanged<Post> onChanged;
  final VoidCallback onOpenComments;
  final VoidCallback onOpenAuthor;

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final AnimationController _heart = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  late Post _post = widget.post;
  int _reactSeq = 0;
  int _saveSeq = 0;
  bool _captionOpen = false;

  @override
  void didUpdateWidget(_Reel old) {
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
    widget.onChanged(p);
  }

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
      _setPost(_post.copyWith(reactions: res.reactions, myReaction: res.myReaction, clearMyReaction: res.myReaction == null));
    } catch (e) {
      if (seq != _reactSeq) return;
      _setPost(_post.copyWith(
        reactions: before.reactions,
        myReaction: before.myReaction,
        clearMyReaction: before.myReaction == null,
      ));
      messenger?.showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  void _doubleTap() {
    HapticFeedback.lightImpact();
    _heart.forward(from: 0);
    if (_post.myReaction != ReactionType.love) _react(ReactionType.love);
  }

  Future<void> _toggleSave() async {
    final before = _post.savedByMe;
    final seq = ++_saveSeq;
    final messenger = ScaffoldMessenger.maybeOf(context);
    HapticFeedback.selectionClick();
    _setPost(_post.copyWith(savedByMe: !before));
    try {
      final token = await AuthManager.instance.getValidToken();
      before ? await _api.unsavePost(token, _post.id) : await _api.savePost(token, _post.id);
    } catch (e) {
      if (seq != _saveSeq) return;
      _setPost(_post.copyWith(savedByMe: before));
      messenger?.showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  Future<void> _openCollections() async {
    _saveSeq++;
    await showSaveToCollectionSheet(
      context,
      post: _post,
      onSavedChanged: (saved) {
        if (_post.savedByMe != saved) _setPost(_post.copyWith(savedByMe: saved));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = widget.controller;
    final ready = c != null && c.value.isInitialized;
    final p = _post;
    final author = p.author;
    final hidden = p.hidesCountsFrom(AuthManager.instance.profile?.id);
    const shadow = [Shadow(color: Colors.black54, blurRadius: 6)];

    return Stack(fit: StackFit.expand, children: [
      // Video
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: ready ? widget.onTogglePause : null,
        onDoubleTap: _doubleTap,
        child: Semantics(
          label: l10n.feedVideo,
          hint: l10n.feedDoubleTapToLove,
          child: ColoredBox(
            color: Colors.black,
            child: ready
                ? ClipRect(
                    child: FittedBox(
                      fit: c.value.aspectRatio < 0.75 ? BoxFit.cover : BoxFit.contain,
                      child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
                    ),
                  )
                : Center(
                    child: widget.failed
                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 40),
                            const SizedBox(height: 8),
                            Text(l10n.postsVideoUnavailable, style: const TextStyle(color: Colors.white70)),
                          ])
                        : const CircularProgressIndicator(color: Colors.white),
                  ),
          ),
        ),
      ),
      // Paused indicator + heart pop
      IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: widget.paused ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
            ),
          ),
        ),
      ),
      IgnorePointer(child: Center(child: _ReelHeart(animation: _heart))),
      // Bottom gradient for legibility
      const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.transparent, Colors.black54],
              stops: [0, 0.6, 1],
            ),
          ),
        ),
      ),
      // Side buttons
      Positioned(
        right: 8,
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Builder(
            builder: (anchor) => _SideButton(
              label: (p.myReaction ?? ReactionType.like).label(l10n),
              count: hidden ? null : p.reactions.total,
              onTap: () {
                HapticFeedback.lightImpact();
                // Like the feed card: tap = 👍, double-tap on the video = ❤️.
                _react(p.myReaction == null ? ReactionType.like : null);
              },
              onLongPress: () async {
                final picked = await showReactionPicker(context, anchor: anchor, current: p.myReaction);
                if (picked != null) _react(picked == p.myReaction ? null : picked);
              },
              child: p.myReaction == null
                  ? const Icon(Icons.thumb_up_alt_outlined, color: Colors.white, size: 30, shadows: shadow)
                  : Text(p.myReaction!.emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          _SideButton(
            label: l10n.nutritionComment,
            count: p.commentCount,
            onTap: widget.onOpenComments,
            child: Icon(
              p.commentsDisabled ? Icons.comments_disabled_outlined : Icons.mode_comment_outlined,
              color: Colors.white,
              size: 30,
              shadows: shadow,
            ),
          ),
          _SideButton(
            label: l10n.shareSendAction,
            onTap: () => showShareSheet(context, postShareRequest(p)),
            child: const Icon(Icons.send_outlined, color: Colors.white, size: 30, shadows: shadow),
          ),
          _SideButton(
            label: p.savedByMe ? l10n.postsUnsave : l10n.postsSave,
            onTap: _toggleSave,
            onLongPress: _openCollections,
            child: Icon(
              p.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: Colors.white,
              size: 30,
              shadows: shadow,
            ),
          ),
        ]),
      ),
      // Author + caption
      Positioned(
        left: 12,
        right: 72,
        bottom: 20 + MediaQuery.paddingOf(context).bottom,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (author != null)
            Semantics(
              button: true,
              label: l10n.feedOpenProfile(author.fullName.isNotEmpty ? author.fullName : author.username),
              excludeSemantics: true,
              child: GestureDetector(
                onTap: widget.onOpenAuthor,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  UserAvatar(url: author.avatarUrl, initials: author.initials, radius: 16, streakTier: author.streakTier),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      author.username.isNotEmpty ? author.username : author.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, shadows: shadow),
                    ),
                  ),
                ]),
              ),
            ),
          if (p.locationName != null) ...[
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.place_outlined, size: 14, color: Colors.white70),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  p.locationName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, shadows: shadow),
                ),
              ),
            ]),
          ],
          if (p.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _captionOpen = !_captionOpen),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.35),
                child: SingleChildScrollView(
                  child: MentionText(
                    p.content,
                    style: const TextStyle(color: Colors.white, shadows: shadow),
                    linkStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    maxLines: _captionOpen ? null : 2,
                    overflow: _captionOpen ? null : TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
      if (ready)
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.paddingOf(context).bottom,
          child: VideoProgressIndicator(
            c,
            allowScrubbing: true,
            padding: const EdgeInsets.only(top: 6),
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.white24,
              backgroundColor: Colors.white10,
            ),
          ),
        ),
    ]);
  }
}

/// A side action: icon (or emoji) with an optional count under it.
class _SideButton extends StatelessWidget {
  const _SideButton({required this.label, required this.child, required this.onTap, this.onLongPress, this.count});

  final String label;
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Hidden when null or zero.
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count != null && count! > 0 ? '$label, $count' : label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        onLongPress: onLongPress,
        radius: 28,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 36, height: 36, child: Center(child: child)),
            if (count != null && count! > 0)
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// The ❤️ that pops on double tap.
class _ReelHeart extends StatelessWidget {
  const _ReelHeart({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = animation.value;
      if (t == 0 || t == 1) return const SizedBox.shrink();
      final scale = t < 0.25 ? Curves.easeOut.transform(t / 0.25) * 1.2 : 1.2 - 0.2 * ((t - 0.25) / 0.75).clamp(0.0, 1.0);
      final opacity = t < 0.8 ? 1.0 : 1 - (t - 0.8) / 0.2;
      return Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: const Text('❤️', style: TextStyle(fontSize: 110, shadows: [Shadow(color: Colors.black38, blurRadius: 12)])),
        ),
      );
    },
  );
}
