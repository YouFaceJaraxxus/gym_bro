import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/challenge.dart';
import '../theme.dart';
import 'challenge_ring.dart';

/// One challenge in a list: my progress ring (or the metric when I'm not in
/// it), its title and host, how far I am and the time left. [onJoin] adds a
/// Join button for ones I'm not in.
class ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback onTap;
  final VoidCallback? onJoin;
  final bool joining;

  const ChallengeCard({super.key, required this.challenge, required this.onTap, this.onJoin, this.joining = false});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final c = challenge;
    final m = c.metric;
    final joined = c.me.joined;
    final done = c.me.completed;
    final pct = (c.fraction * 100).round();

    final ring = ChallengeRing(
      fraction: joined ? c.fraction : 0,
      colors: m.colors,
      size: 62,
      stroke: 6,
      child: joined
          ? (done
              ? Icon(Icons.emoji_events_rounded, color: m.colors.last, size: 28)
              : Text(
                  '$pct%',
                  style: AppText.stat(size: 19, weight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
                ))
          : Icon(m.icon, color: m.color, size: 26),
    );

    final statusChip = _Pill(
      label: done ? l10n.challengeCompleted : c.timing(l10n),
      icon: done
          ? Icons.check_circle_rounded
          : c.status == ChallengeStatus.upcoming
              ? Icons.schedule_rounded
              : Icons.hourglass_bottom_rounded,
      color: done ? const Color(0xFF12B886) : (c.status == ChallengeStatus.active && c.daysLeft <= 3 ? cs.error : cs.onSurfaceVariant),
    );

    return MergeSemantics(
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // A thin strip of the metric's colours along the left edge.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: m.colors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Row(
                  children: [
                    ring,
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.displayTitle(l10n),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(c.isPlatform ? Icons.public_rounded : Icons.fitness_center_rounded, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${c.host(l10n)} · ${l10n.challengeParticipants(c.participants)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            joined
                                ? '${m.number(l10n, c.me.progress)} / ${m.amount(l10n, c.target)}'
                                : l10n.challengeGoal(m.amount(l10n, c.target)),
                            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                          const SizedBox(height: 8),
                          statusChip,
                        ],
                      ),
                    ),
                    if (onJoin != null) ...[
                      const SizedBox(width: 8),
                      joining
                          ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : FilledButton.tonal(onPressed: onJoin, child: Text(l10n.challengeJoin)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _Pill({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
