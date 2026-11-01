import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/challenge.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../theme.dart';
import '../../utils/device_timezone.dart';
import '../../widgets/challenge_medals.dart';
import '../../widgets/challenge_ring.dart';
import '../../widgets/social_widgets.dart';
import 'challenge_celebrations.dart';
import 'challenge_form_page.dart';

/// One challenge: a big ring with my progress on the metric's gradient,
/// joining or leaving, what counts, and the leaderboard. Opening one I just
/// completed (for the first time on this device) throws confetti.
class ChallengeDetailPage extends StatefulWidget {
  final String challengeId;

  /// Shown while the full one (with the leaderboard) loads.
  final Challenge? initial;

  const ChallengeDetailPage({super.key, required this.challengeId, this.initial});

  @override
  State<ChallengeDetailPage> createState() => _ChallengeDetailPageState();
}

enum _Menu { edit, delete }

class _ChallengeDetailPageState extends State<ChallengeDetailPage> {
  final _api = ApiService();
  final _confetti = ConfettiController(duration: const Duration(milliseconds: 1600));
  Challenge? _c;
  Object? _error;
  bool _busy = false;
  bool _celebrating = false;
  final _scroll = ScrollController();

  /// Scrolled past the header: the app bar turns solid.
  bool _solid = false;

  @override
  void initState() {
    super.initState();
    _c = widget.initial;
    _load();
    _scroll.addListener(() {
      final solid = _scroll.hasClients && _scroll.offset > 280;
      if (solid != _solid) setState(() => _solid = solid);
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final c = await _api.getChallenge(token, widget.challengeId, tz: await deviceTimezone());
      if (!mounted) return;
      setState(() {
        _c = c;
        _error = null;
      });
      await _maybeCelebrate(c);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _maybeCelebrate(Challenge c) async {
    if (!c.me.completed || !c.completedRecently(DateTime.now())) return;
    if (await ChallengeCelebrations.isCelebrated(c.id)) return;
    await ChallengeCelebrations.markCelebrated(c.id);
    if (!mounted) return;
    setState(() => _celebrating = true);
    HapticFeedback.heavyImpact();
    if (!MediaQuery.disableAnimationsOf(context)) _confetti.play();
  }

  String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _join() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final c = await _api.joinChallenge(token, widget.challengeId, tz: await deviceTimezone());
      if (!mounted) return;
      setState(() => _c = c);
      messenger.showSnackBar(SnackBar(content: Text(l10n.challengeJoined)));
      // Workouts earlier in its dates count: joining can finish it at once.
      await _maybeCelebrate(c);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_err(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String message, String action) async {
    final l10n = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.challengeCancel)),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _leave() async {
    final c = _c!;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!await _confirm(l10n.challengeLeaveConfirm(c.displayTitle(l10n)), l10n.challengeLeave) || !mounted) return;
    setState(() => _busy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.leaveChallenge(token, c.id);
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_err(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _menu(_Menu action) async {
    final c = _c!;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    switch (action) {
      case _Menu.edit:
        final saved = await nav.push<Challenge>(
          MaterialPageRoute(fullscreenDialog: true, builder: (_) => ChallengeFormPage(existing: c)),
        );
        if (saved != null && mounted) await _load();
      case _Menu.delete:
        if (!await _confirm(l10n.challengeDeleteConfirm(c.displayTitle(l10n)), l10n.challengeDelete)) return;
        try {
          final token = await AuthManager.instance.getValidToken();
          await _api.deleteChallenge(token, c.id);
          messenger.showSnackBar(SnackBar(content: Text(l10n.challengeDeleted)));
          nav.pop();
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(_err(e))));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = _c;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.challengesLoadFailed),
                    TextButton(onPressed: _load, child: Text(l10n.challengesRetry)),
                  ],
                ),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final calm = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: _solid ? c.metric.colors.first : Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: _solid
            ? Text(c.displayTitle(l10n), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white))
            : null,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          if (c.canEdit)
            PopupMenuButton<_Menu>(
              onSelected: _menu,
              itemBuilder: (_) => [
                PopupMenuItem(value: _Menu.edit, child: Text(l10n.challengeEdit)),
                PopupMenuItem(value: _Menu.delete, child: Text(l10n.challengeDelete)),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.zero,
              children: [
                _Header(challenge: c, calm: calm),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_celebrating) ...[
                        _CompletedBanner(challenge: c, calm: calm),
                        const SizedBox(height: 16),
                      ],
                      if (c.canJoin)
                        FilledButton.icon(
                          onPressed: _busy ? null : _join,
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          icon: _busy
                              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.flag_rounded),
                          label: Text(l10n.challengeJoinChallenge),
                        ),
                      if (challengeDescription(l10n, c) case final d? when d.trim().isNotEmpty) ...[
                        if (c.canJoin) const SizedBox(height: 20),
                        Text(d, style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 20),
                      ] else
                        const SizedBox(height: 4),
                      _RuleCard(challenge: c),
                      const SizedBox(height: 28),
                      _Leaderboard(challenge: c, calm: calm),
                      if (c.canLeave) ...[
                        const SizedBox(height: 24),
                        Center(
                          child: TextButton.icon(
                            onPressed: _busy ? null : _leave,
                            style: TextButton.styleFrom(foregroundColor: cs.error),
                            icon: const Icon(Icons.logout_rounded),
                            label: Text(l10n.challengeLeave),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              emissionFrequency: 0.06,
              maxBlastForce: 34,
              minBlastForce: 12,
              gravity: 0.25,
              colors: [...c.metric.colors, const Color(0xFFFFC233), const Color(0xFFFFE08A), cs.primary],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Challenge challenge;
  final bool calm;

  const _Header({required this.challenge, required this.calm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final c = challenge;
    final m = c.metric;
    final dates = '${DateFormat.MMMd(l10n.localeName).format(c.startsOn)} – ${DateFormat.yMMMd(l10n.localeName).format(c.endsOn)}';
    final remaining = (c.target - c.me.progress).clamp(0, c.target);
    const white = Colors.white;
    final soft = white.withValues(alpha: 0.82);

    Widget ring = ChallengeRing(
      fraction: c.me.joined ? c.fraction : 0,
      colors: const [Color(0xFFFFFFFF), Color(0xFFFFF3C4)],
      trackColor: white.withValues(alpha: 0.22),
      size: 196,
      stroke: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.me.completed)
            const Icon(Icons.emoji_events_rounded, color: white, size: 34)
          else
            Icon(m.icon, color: soft, size: 24),
          _CountUp(
            value: c.me.joined ? c.me.progress : 0,
            format: (v) => m.number(l10n, v),
            calm: calm,
            style: AppText.stat(size: 52, weight: FontWeight.w800, color: white, height: 1.05),
          ),
          Text(
            '/ ${m.number(l10n, c.target)} ${m.unit(l10n, c.target)}',
            style: text.labelLarge?.copyWith(color: soft, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: m.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          // Big soft circles for depth.
          Positioned(right: -70, top: -40, child: _Blob(size: 220, alpha: 0.12)),
          Positioned(left: -60, bottom: -50, child: _Blob(size: 180, alpha: 0.10)),
          Padding(
            padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + kToolbarHeight, 24, 28),
            child: Column(
              children: [
                ring,
                const SizedBox(height: 18),
                Text(
                  c.displayTitle(l10n),
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(color: white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text('${c.host(l10n)} · $dates', textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: soft)),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _GlassChip(
                      icon: c.me.completed ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded,
                      label: c.me.completed
                          ? l10n.challengeCompleted
                          : c.me.joined && c.status == ChallengeStatus.active
                              ? '${l10n.challengeToGo(m.amount(l10n, remaining))} · ${c.timing(l10n)}'
                              : c.timing(l10n),
                    ),
                    _GlassChip(icon: Icons.groups_rounded, label: l10n.challengeParticipants(c.participants)),
                    if (c.myRank != null && c.me.joined)
                      _GlassChip(icon: Icons.leaderboard_rounded, label: l10n.challengeYourRank(c.myRank!)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final double alpha;

  const _Blob({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
      );
}

class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GlassChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// A number counting up from 0 (or shown at once when animations are off).
class _CountUp extends StatelessWidget {
  final int value;
  final String Function(int) format;
  final bool calm;
  final TextStyle? style;

  const _CountUp({required this.value, required this.format, required this.calm, this.style});

  @override
  Widget build(BuildContext context) {
    if (calm) return Text(format(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        format(v.round()),
        style: style?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

// ── Completed ─────────────────────────────────────────────────────────────────

class _CompletedBanner extends StatelessWidget {
  final Challenge challenge;
  final bool calm;

  const _CompletedBanner({required this.challenge, required this.calm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    Widget medal = ChallengeMedalIcon(metric: challenge.metric, size: 64);
    if (!calm) {
      medal = medal
          .animate()
          .scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), duration: 600.ms, curve: Curves.elasticOut)
          .then(delay: 200.ms)
          .shimmer(duration: 1200.ms, color: Colors.white70);
    }
    Widget card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF3C4), Color(0xFFFFD66B)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          medal,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.challengeJustCompleted,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF4A3000)),
                ),
                const SizedBox(height: 2),
                Text(l10n.challengeJustCompletedBody, style: text.bodyMedium?.copyWith(color: const Color(0xFF5C4300))),
              ],
            ),
          ),
        ],
      ),
    );
    if (!calm) card = card.animate().fadeIn(duration: 350.ms).slideY(begin: 0.2, end: 0);
    return card;
  }
}

// ── What counts ───────────────────────────────────────────────────────────────

class _RuleCard extends StatelessWidget {
  final Challenge challenge;

  const _RuleCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final c = challenge;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChallengeMetricIcon(metric: c.metric, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.challengeHowItCounts, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '${l10n.challengeGoal(c.metric.amount(l10n, c.target))}. ${c.metric.rule(l10n, gymName: c.gym?.name)} '
                  '${l10n.challengeRuleWindow}',
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (c.creator != null) ...[
                  const SizedBox(height: 8),
                  Text(l10n.challengeCreatedBy(c.creator!.fullName), style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leaderboard ───────────────────────────────────────────────────────────────

class _Leaderboard extends StatelessWidget {
  final Challenge challenge;
  final bool calm;

  const _Leaderboard({required this.challenge, required this.calm});

  static const _podium = [Color(0xFFFFC233), Color(0xFFB8C2CC), Color(0xFFD08A4E)];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final c = challenge;
    final me = AuthManager.instance.profile?.id;
    final entries = c.leaderboard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.challengeLeaderboard, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Text(l10n.challengeLeaderboardEmpty, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
        else
          for (final (i, e) in entries.indexed)
            Builder(builder: (context) {
              final mine = e.user?.id == me;
              final done = e.completedAt != null;
              final fraction = c.target <= 0 ? 0.0 : (e.progress / c.target).clamp(0.0, 1.0);
              Widget row = Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: mine ? c.metric.color.withValues(alpha: 0.12) : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: mine ? Border.all(color: c.metric.color.withValues(alpha: 0.5)) : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: e.rank <= 3
                          ? CircleAvatar(
                              radius: 13,
                              backgroundColor: _podium[e.rank - 1],
                              child: Text(
                                '${e.rank}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF2B2B2B)),
                              ),
                            )
                          : Text(
                              '${e.rank}',
                              textAlign: TextAlign.center,
                              style: text.titleSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                            ),
                    ),
                    const SizedBox(width: 8),
                    UserAvatar(
                      url: e.user?.avatarUrl,
                      initials: e.user?.initials ?? '?',
                      radius: 18,
                      streakTier: e.user?.streakTier,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.user?.fullName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: calm ? fraction : 0, end: fraction),
                              duration: calm ? Duration.zero : Duration(milliseconds: 700 + i * 40),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) => LinearProgressIndicator(
                                value: v,
                                minHeight: 6,
                                backgroundColor: cs.surfaceContainerHighest,
                                color: c.metric.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      c.metric.number(l10n, e.progress),
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                    if (done) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFFFB300)),
                    ],
                  ],
                ),
              );
              if (!calm && i < 10) row = row.animate().fadeIn(delay: (80 + i * 50).ms, duration: 250.ms);
              return row;
            }),
      ],
    );
  }
}
