import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/social.dart';
import '../../models/story.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/social_widgets.dart';
import 'story_composer_page.dart';
import 'story_viewer_page.dart';

/// The ring around an avatar: none, unwatched stories (gradient) or all
/// watched (grey).
enum StoryRing { none, unseen, seen }

/// The Instagram story gradient.
const kStoryGradient = SweepGradient(
  colors: [Color(0xFFFEDA75), Color(0xFFFA7E1E), Color(0xFFD62976), Color(0xFF962FBF), Color(0xFF4F5BD5), Color(0xFFFEDA75)],
);

/// [child] (an avatar of [radius]) inside a story ring, tappable when
/// [onTap] is set. With [onAdd] a small "+" badge sits at the bottom right.
class StoryRingAvatar extends StatelessWidget {
  const StoryRingAvatar({
    super.key,
    required this.child,
    required this.radius,
    this.ring = StoryRing.none,
    this.onTap,
    this.onLongPress,
    this.onAdd,
    this.semanticLabel,
  });

  final Widget child;
  final double radius;
  final StoryRing ring;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAdd;
  final String? semanticLabel;

  /// The ring for someone with [hasStory] / [hasUnseen] live stories.
  static StoryRing ringFor({required bool hasStory, required bool hasUnseen}) =>
      !hasStory ? StoryRing.none : (hasUnseen ? StoryRing.unseen : StoryRing.seen);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stroke = (radius * 0.08).clamp(2.0, 3.5);
    final gap = (radius * 0.06).clamp(2.0, 3.0);
    Widget avatar = Container(
      padding: EdgeInsets.all(stroke),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ring == StoryRing.unseen ? kStoryGradient : null,
        color: ring == StoryRing.seen ? cs.outlineVariant : Colors.transparent,
      ),
      child: Container(
        padding: EdgeInsets.all(gap),
        decoration: BoxDecoration(shape: BoxShape.circle, color: ring == StoryRing.none ? Colors.transparent : cs.surface),
        child: child,
      ),
    );
    if (onAdd != null) {
      final badge = (radius * 0.5).clamp(16.0, 24.0);
      avatar = Stack(clipBehavior: Clip.none, children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: onAdd,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle, border: Border.all(color: cs.surface, width: 2)),
              child: Icon(Icons.add, size: badge * 0.7, color: cs.onPrimary),
            ),
          ),
        ),
      ]);
    }
    if (onTap == null && onLongPress == null) return avatar;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(onTap: onTap, onLongPress: onLongPress, child: avatar),
    );
  }
}

/// The stories row at the top of the feed: "Your story" first (tap to watch
/// yours, or the + to add one), then the people I follow with live stories
/// — unwatched ones (gradient ring) first. Call [StoryTrayState.refresh]
/// to reload (pull-to-refresh).
class StoryTray extends StatefulWidget {
  const StoryTray({super.key});

  @override
  State<StoryTray> createState() => StoryTrayState();
}

class StoryTrayState extends State<StoryTray> {
  final _api = ApiService();
  List<StoryTrayEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final entries = await _api.getStoryTray(token);
      if (mounted) setState(() => _entries = entries);
    } catch (_) {
      // The tray is a nicety: keep what's shown.
    }
  }

  StoryTrayEntry? get _mine => _entries.where((e) => e.isMe).firstOrNull;
  List<StoryTrayEntry> get _others => _entries.where((e) => !e.isMe).toList();

  SocialUser? get _me {
    final mine = _mine;
    if (mine != null) return mine.user;
    final p = AuthManager.instance.profile;
    return p == null ? null : SocialUser(id: p.id, username: p.username, name: p.name, lastName: p.lastName, avatarUrl: p.avatarUrl);
  }

  Future<void> _compose() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final story = await openStoryComposer(context);
    if (story == null || !mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.storyPosted)));
    refresh();
  }

  Future<void> _openMine() async {
    final me = _me;
    if (_mine == null || me == null) return _compose();
    await openUserStories(context, [me]);
    if (mounted) refresh();
  }

  Future<void> _openOther(int index) async {
    final others = _others;
    await openUserStories(
      context,
      [for (final e in others) e.user],
      initialIndex: index,
      onSeen: (userId) {
        if (!mounted) return;
        setState(() => _entries = [for (final e in _entries) e.user.id == userId ? e.seenAll() : e]);
      },
    );
    if (mounted) refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final me = _me;
    final others = _others;
    return SizedBox(
      height: 98,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          if (me != null)
            _TrayItem(
              user: me,
              label: l10n.storyYourStory,
              ring: _mine == null ? StoryRing.none : StoryRing.unseen,
              onTap: _openMine,
              onLongPress: _compose,
              onAdd: _compose,
              semanticLabel: _mine == null ? l10n.storyAddTooltip : l10n.storyYourStory,
            ),
          for (final (i, e) in others.indexed)
            _TrayItem(
              user: e.user,
              label: e.user.username.isNotEmpty ? e.user.username : e.user.fullName,
              ring: e.hasUnseen ? StoryRing.unseen : StoryRing.seen,
              onTap: () => _openOther(i),
              semanticLabel: e.hasUnseen ? l10n.storyTrayUnseen(e.user.fullName) : l10n.storyTraySeen(e.user.fullName),
            ),
        ],
      ),
    );
  }
}

class _TrayItem extends StatelessWidget {
  const _TrayItem({
    required this.user,
    required this.label,
    required this.ring,
    required this.onTap,
    this.onLongPress,
    this.onAdd,
    this.semanticLabel,
  });

  final SocialUser user;
  final String label;
  final StoryRing ring;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAdd;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 76,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(children: [
          StoryRingAvatar(
            radius: 28,
            ring: ring,
            onTap: onTap,
            onLongPress: onLongPress,
            onAdd: onAdd,
            semanticLabel: semanticLabel,
            child: ExcludeSemantics(child: UserAvatar(url: user.avatarUrl, initials: user.initials, radius: 28)),
          ),
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ring == StoryRing.seen ? cs.onSurfaceVariant : cs.onSurface,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
