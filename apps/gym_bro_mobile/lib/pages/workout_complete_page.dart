import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/l10n.dart';
import '../models/shared_content.dart';
import '../models/streak.dart';
import '../models/training.dart';
import '../models/training_session.dart';
import '../services/settings_service.dart';
import '../widgets/share_post.dart';
import '../widgets/share_sheet.dart';
import '../widgets/streak_widgets.dart';
import 'streaks/gym_board_page.dart';
import 'streaks/streak_page.dart';

/// Full-screen celebration after a workout is finished (or a past one is
/// logged): confetti, the session's numbers counting up, and how it moved the
/// streak — the flame ticking up, a badge reveal, freezes, this week and a
/// climb on a gym board. "Share workout" opens the share sheet.
///
/// [prCount] is the PRs seen while logging live (past logs don't detect
/// them). With [clientName] a trainer ran it for a client: the streak is
/// theirs, so it isn't shown.
class WorkoutCompletePage extends StatefulWidget {
  final TrainingSession session;
  final int? prCount;
  final String? clientName;

  const WorkoutCompletePage({super.key, required this.session, this.prCount, this.clientName});

  @override
  State<WorkoutCompletePage> createState() => _WorkoutCompletePageState();
}

class _WorkoutCompletePageState extends State<WorkoutCompletePage> {
  final _confetti = ConfettiController(duration: const Duration(milliseconds: 1400));
  final _settings = SettingsService.instance;

  StreakUpdate? get _streak => widget.clientName == null ? widget.session.streak : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      if (!MediaQuery.of(context).disableAnimations) _confetti.play();
      // A second thump as the new badge lands.
      if (_streak?.newTier != null) {
        Future.delayed(const Duration(milliseconds: 1100), () {
          if (mounted) HapticFeedback.heavyImpact();
        });
      }
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  /// kg × reps over counted drops.
  double get _volumeKg {
    var total = 0.0;
    for (final s in widget.session.setLogs) {
      for (final d in s.dropLogs) {
        if (d.repTypeActual == RepType.count && d.weightKgActual != null && d.repCountActual != null) {
          total += d.weightKgActual! * d.repCountActual!;
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final calm = MediaQuery.of(context).disableAnimations;
    final session = widget.session;
    final streak = _streak;
    final target = workoutShareTarget(session);
    final minutes = session.duration?.inMinutes ?? 0;

    final tierColors = streak?.tier == null ? <Color>[] : [streak!.tier!.color, streak.tier!.light];

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                    children: [
                      _Header(
                        title: l10n.workoutCompleteTitle,
                        subtitle: widget.clientName != null
                            ? l10n.workoutCompleteForClient(widget.clientName!)
                            : session.trainingName ?? l10n.workoutCompleteSubtitle,
                        calm: calm,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              icon: Icons.timer_outlined,
                              label: l10n.workoutCompleteDuration,
                              value: minutes.toDouble(),
                              format: (v) => l10n.workoutCompleteMinutes(v.round()),
                              delay: 0,
                              calm: calm,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatTile(
                              icon: Icons.repeat_rounded,
                              label: l10n.workoutCompleteSets,
                              value: session.setLogs.length.toDouble(),
                              format: (v) => '${v.round()}',
                              delay: 1,
                              calm: calm,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              icon: Icons.fitness_center_rounded,
                              label: l10n.workoutCompleteVolume,
                              value: _volumeKg,
                              format: (v) => _settings.formatWeight(v, decimals: 0),
                              delay: 2,
                              calm: calm,
                            ),
                          ),
                          if (widget.prCount != null) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatTile(
                                icon: Icons.emoji_events_rounded,
                                label: l10n.workoutCompletePrs,
                                value: widget.prCount!.toDouble(),
                                format: (v) => '${v.round()}',
                                delay: 3,
                                calm: calm,
                                highlight: widget.prCount! > 0,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (streak != null) ...[
                        const SizedBox(height: 24),
                        _StreakBlock(streak: streak, calm: calm),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!target.isFuture())
                        FilledButton.icon(
                          onPressed: () => showShareSheet(context, ShareRequest.fromTarget(target)),
                          icon: const Icon(Icons.ios_share),
                          label: Text(l10n.workoutCompleteShare),
                        ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.workoutCompleteDone),
                      ),
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
              numberOfParticles: 28,
              emissionFrequency: 0.06,
              maxBlastForce: 32,
              minBlastForce: 12,
              gravity: 0.25,
              colors: [cs.primary, cs.tertiary, const Color(0xFFFFC94D), const Color(0xFFFF7A1A), ...tierColors],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool calm;

  const _Header({required this.title, required this.subtitle, required this.calm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget badge = Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
      child: Icon(Icons.check_rounded, size: 52, color: cs.onPrimaryContainer),
    );
    if (!calm) {
      badge = badge
          .animate()
          .scale(begin: const Offset(0.3, 0.3), duration: 600.ms, curve: Curves.elasticOut)
          .fadeIn(duration: 200.ms);
    }
    Widget words = Column(
      children: [
        Text(title, textAlign: TextAlign.center, style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center, style: text.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
    if (!calm) words = words.animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.3, end: 0);
    return Column(children: [badge, const SizedBox(height: 16), words]);
  }
}

// ── Stats ─────────────────────────────────────────────────────────────────────

/// A number that counts up from zero, in a card.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final String Function(double) format;
  final int delay;
  final bool calm;
  final bool highlight;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.format,
    required this.delay,
    required this.calm,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = highlight ? cs.onTertiaryContainer : cs.onSurface;
    final style = text.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: fg,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget tile = Card(
      margin: EdgeInsets.zero,
      color: highlight ? cs.tertiaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: highlight ? fg : cs.primary),
            const SizedBox(height: 8),
            calm
                ? Text(format(value), style: style)
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value),
                    duration: Duration(milliseconds: 900 + delay * 150),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => Text(format(v), style: style),
                  ),
            const SizedBox(height: 2),
            Text(label, style: text.labelMedium?.copyWith(color: highlight ? fg : cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
    if (!calm) {
      tile = tile.animate().fadeIn(delay: (250 + delay * 90).ms, duration: 350.ms).slideY(begin: 0.25, end: 0);
    }
    return tile;
  }
}

// ── Streak ────────────────────────────────────────────────────────────────────

class _StreakBlock extends StatelessWidget {
  final StreakUpdate streak;
  final bool calm;

  const _StreakBlock({required this.streak, required this.calm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final newTier = streak.newTier;
    final next = StreakTier.nextAbove(streak.current);
    final climb = streak.bestClimb;

    Widget card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FlameCount(streak: streak, calm: calm),
            if (!streak.grew) ...[
              const SizedBox(height: 8),
              Text(
                l10n.workoutCompleteNotCounted,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            if (newTier != null) ...[
              const SizedBox(height: 16),
              _TierReveal(tier: newTier, count: streak.current, calm: calm),
            ] else if (streak.milestone) ...[
              const SizedBox(height: 8),
              Text(
                '🎉 ${l10n.workoutCompleteMilestone(streak.current)}',
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
            ],
            if (next != null && streak.current > 0) ...[
              const SizedBox(height: 16),
              _NextTier(current: streak.current, previous: streak.previous, next: next, calm: calm),
            ],
            const Divider(height: 28),
            Row(
              children: [
                Icon(Icons.ac_unit_rounded, size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.workoutCompleteFreezes, style: text.bodyMedium)),
                FreezeCubes(freezes: streak.freezes),
              ],
            ),
            if (streak.week != null) ...[
              const SizedBox(height: 12),
              _WeekLine(week: streak.week!),
            ],
            if (climb != null) ...[
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.arrow_upward_rounded, color: cs.onPrimaryContainer),
                ),
                title: Text(
                  l10n.workoutCompleteRankClimb(climb.rank, climb.gymName),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(l10n.workoutCompleteRankUp(climb.climbed)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => GymBoardPage(gymId: climb.gymId, gymName: climb.gymName),
                )),
              ),
            ],
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StreakPage())),
                child: Text(l10n.workoutCompleteViewStreak),
              ),
            ),
          ],
        ),
      ),
    );
    if (!calm) card = card.animate().fadeIn(delay: 600.ms, duration: 400.ms).slideY(begin: 0.15, end: 0);
    return card;
  }
}

/// The flame and the streak ticking from the previous count to the new one,
/// with a "+1" popping in.
class _FlameCount extends StatelessWidget {
  final StreakUpdate streak;
  final bool calm;

  const _FlameCount({required this.streak, required this.calm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final lit = streak.current > 0;
    final style = text.displaySmall?.copyWith(
      fontWeight: FontWeight.w900,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget flame = StreakFlame(size: 56, lit: lit);
    Widget count = Text('${streak.current}', style: style);
    if (!calm && streak.grew) {
      flame = flame
          .animate(delay: 900.ms)
          .scale(begin: const Offset(1, 1), end: const Offset(1.25, 1.25), duration: 220.ms, curve: Curves.easeOut)
          .then()
          .scale(begin: const Offset(1.25, 1.25), end: const Offset(1, 1), duration: 380.ms, curve: Curves.elasticOut);
      count = _TickingCount(from: streak.previous, to: streak.current, style: style);
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            flame,
            const SizedBox(width: 6),
            count,
            if (streak.grew)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 18),
                child: _PlusOne(calm: calm),
              ),
          ],
        ),
        Text(l10n.workoutCompleteStreakLabel, style: text.titleSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

/// [from] until the card has landed, then counts up to [to].
class _TickingCount extends StatefulWidget {
  final int from;
  final int to;
  final TextStyle? style;

  const _TickingCount({required this.from, required this.to, this.style});

  @override
  State<_TickingCount> createState() => _TickingCountState();
}

class _TickingCountState extends State<_TickingCount> {
  late int _end = widget.from;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _end = widget.to);
    });
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: widget.from.toDouble(), end: _end.toDouble()),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        builder: (_, v, _) => Text('${v.round()}', style: widget.style),
      );
}

class _PlusOne extends StatelessWidget {
  final bool calm;

  const _PlusOne({required this.calm});

  @override
  Widget build(BuildContext context) {
    final chip = DecoratedBox(
      decoration: const ShapeDecoration(shape: StadiumBorder(), gradient: kFlameGradient),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          '+1',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
    );
    if (calm) return chip;
    return chip
        .animate(delay: 1000.ms)
        .scale(begin: const Offset(0, 0), duration: 450.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 120.ms);
  }
}

/// The new badge growing in with a glow behind it.
class _TierReveal extends StatelessWidget {
  final StreakTier tier;
  final int count;
  final bool calm;

  const _TierReveal({required this.tier, required this.count, required this.calm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    Widget gem = Container(
      width: 140,
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [tier.light.withValues(alpha: 0.55), tier.color.withValues(alpha: 0)]),
      ),
      child: StreakGem(tier: tier, size: 92, shimmer: true),
    );
    if (!calm) {
      gem = gem
          .animate(delay: 1100.ms)
          .scale(begin: const Offset(0, 0), duration: 800.ms, curve: Curves.elasticOut)
          .rotate(begin: -0.08, end: 0, duration: 800.ms, curve: Curves.easeOutBack)
          .fadeIn(duration: 150.ms);
    }
    Widget words = Column(
      children: [
        Text(
          l10n.workoutCompleteTierUnlocked(tier.label(l10n)),
          textAlign: TextAlign.center,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.workoutCompleteTierUnlockedBody(count),
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
    if (!calm) words = words.animate(delay: 1500.ms).fadeIn(duration: 350.ms).slideY(begin: 0.3, end: 0);
    return Column(children: [gem, words]);
  }
}

/// Progress to the next badge, filling from where the streak was.
class _NextTier extends StatelessWidget {
  final int current;
  final int previous;
  final StreakTier next;
  final bool calm;

  const _NextTier({required this.current, required this.previous, required this.next, required this.calm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final floor = StreakTier.forStreak(current)?.at ?? 0;
    double frac(int n) => ((n - floor) / (next.at - floor)).clamp(0.0, 1.0);
    final to = frac(current);
    final from = calm ? to : math.min(frac(math.max(previous, floor)), to);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.workoutCompleteToNextTier(next.at - current, next.label(l10n)),
                style: text.bodyMedium,
              ),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: from, end: to),
                duration: calm ? Duration.zero : 900.ms,
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    color: next.color,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        StreakGem(tier: next, size: 28, locked: true),
      ],
    );
  }
}

/// This week: planned workouts done, or workouts against the target.
class _WeekLine extends StatelessWidget {
  final StreakWeek week;

  const _WeekLine({required this.week});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final total = week.planned ? week.entries.length : week.required;
    final done = week.planned ? week.entries.where((e) => e.done).length : math.min(week.done, week.required);
    final onTrack = week.remaining == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                week.planned
                    ? l10n.workoutCompleteWeekPlanned(done, total)
                    : l10n.workoutCompleteWeekTarget(week.done, week.required),
                style: text.bodyMedium,
              ),
            ),
            if (onTrack)
              Text(
                l10n.workoutCompleteWeekOnTrack,
                style: text.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < total; i++)
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < done ? cs.primary : null,
                    border: Border.all(color: i < done ? cs.primary : cs.outline, width: 1.5),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
