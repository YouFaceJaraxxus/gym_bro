import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/l10n.dart';
import '../../models/streak.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../utils/device_timezone.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/social_widgets.dart';
import '../../widgets/streak_widgets.dart';
import '../people/user_profile_page.dart';

/// A gym's boards: streak (right now), workouts and check-ins (last 30
/// days). The top three stand on a podium, everyone else follows, and my own
/// place stays pinned at the bottom with what it takes to move up.
class GymBoardPage extends StatefulWidget {
  final String gymId;
  final String gymName;
  final GymBoardKind initial;

  const GymBoardPage({super.key, required this.gymId, required this.gymName, this.initial = GymBoardKind.streak});

  @override
  State<GymBoardPage> createState() => _GymBoardPageState();
}

class _GymBoardPageState extends State<GymBoardPage> {
  final _api = ApiService();
  late GymBoardKind _kind = widget.initial;

  /// Loaded boards, kept while switching tabs.
  final _boards = <GymBoardKind, GymBoard>{};
  String? _error;
  bool _notMember = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final kind = _kind;
    setState(() => _error = null);
    try {
      final token = await AuthManager.instance.getValidToken();
      final board = await _api.getGymBoard(token, widget.gymId, kind, tz: await deviceTimezone());
      if (!mounted) return;
      setState(() => _boards[kind] = board);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        // The API's 403 for people who aren't members.
        _notMember = message.startsWith('Gym boards are for');
        _error = message;
      });
    }
  }

  void _select(GymBoardKind kind) {
    if (kind == _kind) return;
    setState(() => _kind = kind);
    _load();
  }

  void _openProfile(String userId) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: userId)));

  void _showInfo() {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget row(IconData icon, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: cs.primary),
              const SizedBox(width: 14),
              Expanded(child: Text(body, style: text.bodyMedium)),
            ],
          ),
        );
    showAppBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.gymBoardInfoTitle, style: text.titleLarge),
            const SizedBox(height: 16),
            row(Icons.local_fire_department_outlined, l10n.gymBoardInfoStreak),
            row(Icons.date_range_outlined, l10n.gymBoardInfoPeriod),
            row(Icons.groups_outlined, l10n.gymBoardInfoMembers),
            row(Icons.visibility_off_outlined, l10n.gymBoardInfoHide),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final board = _boards[_kind];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.gymBoardTitle),
            Text(widget.gymName, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.gymBoardInfoTooltip,
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<GymBoardKind>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: GymBoardKind.streak,
                    icon: const Icon(Icons.local_fire_department_outlined),
                    label: Text(l10n.gymBoardTabStreak),
                  ),
                  ButtonSegment(
                    value: GymBoardKind.workouts,
                    icon: const Icon(Icons.fitness_center),
                    label: Text(l10n.gymBoardTabWorkouts),
                  ),
                  ButtonSegment(
                    value: GymBoardKind.checkIns,
                    icon: const Icon(Icons.qr_code_2),
                    label: Text(l10n.gymBoardTabCheckIns),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => _select(s.first),
              ),
            ),
          ),
          Text(
            _kind == GymBoardKind.streak ? l10n.gymBoardPeriodStreak : l10n.gymBoardPeriodLast30,
            style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _body(board),
            ),
          ),
        ],
      ),
      bottomNavigationBar: board == null ? null : _MyPlaceBar(board: board),
    );
  }

  Widget _body(GymBoard? board) {
    final l10n = context.l10n;
    if (board == null && _error != null) {
      return _Message(
        icon: _notMember ? Icons.lock_outline : Icons.cloud_off_outlined,
        text: _notMember ? l10n.gymBoardNotMember(widget.gymName) : l10n.gymBoardLoadFailed,
        action: _notMember ? null : TextButton(onPressed: _load, child: Text(l10n.commonRetry)),
      );
    }
    if (board == null) return const _SkeletonList();
    if (board.entries.isEmpty) {
      return _Message(icon: Icons.emoji_events_outlined, text: l10n.gymBoardEmpty);
    }
    final me = AuthManager.instance.profile?.id;
    final podium = board.entries.take(3).toList();
    final rest = board.entries.skip(3).toList();
    return ListView(
      // Keyed by board so switching tabs replays the podium.
      key: ValueKey(board.kind),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _Podium(entries: podium, kind: board.kind, meId: me, onTap: _openProfile),
        const SizedBox(height: 12),
        for (final (i, e) in rest.indexed)
          _BoardRow(entry: e, kind: board.kind, isMe: e.user?.id == me, onTap: _openProfile)
              .maybeAnimate(context, delay: (40 * i.clamp(0, 10)).ms, (a) => a.fadeIn(duration: 250.ms).slideY(begin: 0.15)),
      ],
    );
  }
}

extension on Widget {
  /// Runs [effects] unless the platform asked for reduced motion.
  Widget maybeAnimate(BuildContext context, Animate Function(Animate) effects, {Duration delay = Duration.zero}) =>
      MediaQuery.of(context).disableAnimations ? this : effects(animate(delay: delay));
}

/// The value on a board, with its unit.
class _Value extends StatelessWidget {
  final int value;
  final GymBoardKind kind;
  final TextStyle? style;

  const _Value({required this.value, required this.kind, this.style});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = (style ?? Theme.of(context).textTheme.labelLarge)
        ?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]);
    return switch (kind) {
      GymBoardKind.streak => Row(mainAxisSize: MainAxisSize.min, children: [
          StreakFlame(size: (s?.fontSize ?? 14) + 4),
          const SizedBox(width: 2),
          Text('$value', style: s),
        ]),
      GymBoardKind.workouts => Text(l10n.gymBoardWorkoutsValue(value), style: s),
      GymBoardKind.checkIns => Text(l10n.gymBoardCheckInsValue(value), style: s),
    };
  }
}

// ── Podium ────────────────────────────────────────────────────────────────────

/// Medal colours of the first three places.
StreakTier _medal(int place) => switch (place) {
      0 => StreakTier.gold,
      1 => StreakTier.silver,
      _ => StreakTier.bronze,
    };

class _Podium extends StatelessWidget {
  final List<GymBoardEntry> entries;
  final GymBoardKind kind;
  final String? meId;
  final void Function(String userId) onTap;

  const _Podium({required this.entries, required this.kind, required this.meId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Second, first, third.
    final order = [1, 0, 2].where((i) => i < entries.length).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final i in order)
          Expanded(
            child: _Step(
              entry: entries[i],
              place: i,
              kind: kind,
              isMe: entries[i].user?.id == meId,
              onTap: onTap,
            ),
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final GymBoardEntry entry;

  /// 0 = first.
  final int place;
  final GymBoardKind kind;
  final bool isMe;
  final void Function(String userId) onTap;

  const _Step({required this.entry, required this.place, required this.kind, required this.isMe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final medal = _medal(place);
    final user = entry.user;
    final radius = place == 0 ? 36.0 : 28.0;
    final barHeight = switch (place) { 0 => 112.0, 1 => 84.0, _ => 64.0 };
    // Rising bars, first place last so it lands as the finale.
    final delay = switch (place) { 0 => 280, 1 => 140, _ => 0 }.ms;

    final person = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: user == null ? null : () => onTap(user.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          children: [
            if (place == 0) Icon(Icons.workspace_premium, color: medal.color, size: 28),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [medal.light, medal.color, medal.dark]),
              ),
              child: UserAvatar(
                url: user?.avatarUrl,
                initials: user?.initials ?? '?',
                radius: radius,
                streakTier: user?.streakTier,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isMe ? l10n.gymBoardYou : (user?.name.isNotEmpty == true ? user!.name : user?.username ?? ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelLarge?.copyWith(fontWeight: isMe ? FontWeight.w800 : FontWeight.w600),
            ),
            const SizedBox(height: 2),
            _Value(value: entry.value, kind: kind, style: text.labelMedium),
          ],
        ),
      ),
    );

    final bar = Container(
      height: barHeight,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [medal.color, Color.lerp(medal.dark, cs.surface, 0.35)!],
        ),
        border: isMe ? Border.all(color: cs.primary, width: 2) : null,
      ),
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '${entry.rank}',
        style: text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, shadows: [
          Shadow(color: medal.dark, blurRadius: 4),
        ]),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        person.maybeAnimate(
          context,
          delay: delay + 250.ms,
          (a) => a.fadeIn(duration: 300.ms).slideY(begin: 0.4, curve: Curves.easeOutBack),
        ),
        bar.maybeAnimate(
          context,
          delay: delay,
          (a) => a.scaleY(begin: 0, alignment: Alignment.bottomCenter, duration: 500.ms, curve: Curves.easeOutCubic),
        ),
      ],
    );
  }
}

// ── Rows ──────────────────────────────────────────────────────────────────────

class _BoardRow extends StatelessWidget {
  final GymBoardEntry entry;
  final GymBoardKind kind;
  final bool isMe;
  final void Function(String userId) onTap;

  const _BoardRow({required this.entry, required this.kind, required this.isMe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final user = entry.user;
    final name = user == null ? '' : (user.fullName.isNotEmpty ? user.fullName : user.username);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isMe ? cs.primaryContainer.withValues(alpha: 0.55) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: user == null ? null : () => onTap(user.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    '${entry.rank}',
                    style: text.titleMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                UserAvatar(
                  url: user?.avatarUrl,
                  initials: user?.initials ?? '?',
                  radius: 20,
                  streakTier: user?.streakTier,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? '$name · ${l10n.gymBoardYou}' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(fontWeight: isMe ? FontWeight.w800 : null),
                      ),
                      if (user != null && user.username.isNotEmpty)
                        Text(
                          '@${user.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Value(value: entry.value, kind: kind),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// My place, pinned under the board.
class _MyPlaceBar extends StatelessWidget {
  final GymBoard board;

  const _MyPlaceBar({required this.board});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final me = board.me;

    final String line;
    if (me == null) {
      line = switch (board.kind) {
        GymBoardKind.streak => l10n.gymBoardNotOnStreak,
        GymBoardKind.workouts => l10n.gymBoardNotOnWorkouts,
        GymBoardKind.checkIns => l10n.gymBoardNotOnCheckIns,
      };
    } else if (me.rank == 1) {
      line = l10n.gymBoardYouLead;
    } else if (me.gap <= 0) {
      line = l10n.gymBoardTiedAhead;
    } else {
      // The next person up: the lowest place still ahead of me.
      var next = me.rank - 1;
      for (final e in board.entries) {
        if (e.value > me.value) next = e.rank;
      }
      line = board.kind == GymBoardKind.checkIns
          ? l10n.gymBoardGapCheckIns(me.gap, next)
          : l10n.gymBoardGapWorkouts(me.gap, next);
    }

    return Material(
      color: cs.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              if (me != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '#${me.rank}',
                    style: text.titleMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                StreakFlame(size: 28, lit: false),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (me != null) Text(l10n.gymBoardYourRank(me.rank), style: text.titleSmall),
                    Text(line, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              if (me != null) _Value(value: me.value, kind: board.kind),
            ],
          ),
        ),
      ),
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────────

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Scrollable so pull-to-refresh still works.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
      children: [
        Icon(icon, size: 56, color: cs.outline),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        if (action != null) ...[const SizedBox(height: 12), Center(child: action)],
      ],
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget box(double w, double h, {double r = 8}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(r)),
        );
    final skeleton = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final h in [84.0, 112.0, 64.0])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(children: [
                    box(56, 56, r: 28),
                    const SizedBox(height: 8),
                    box(60, 10),
                    const SizedBox(height: 8),
                    box(double.infinity, h, r: 14),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              box(24, 14),
              const SizedBox(width: 12),
              box(40, 40, r: 20),
              const SizedBox(width: 12),
              Expanded(child: box(double.infinity, 14)),
              const SizedBox(width: 24),
              box(48, 14),
            ]),
          ),
      ],
    );
    return MediaQuery.of(context).disableAnimations
        ? skeleton
        : skeleton.animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: cs.surface.withValues(alpha: 0.5));
  }
}
