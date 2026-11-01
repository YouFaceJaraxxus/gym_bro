import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/social.dart';
import '../models/streak.dart';
import 'social_widgets.dart';
import 'streak_widgets.dart';

/// The Gym tab's way into a gym's board: my streak, where it puts me there
/// ("#3 of 24 at Ironclad") and the faces of the current top three.
class GymBoardCard extends StatelessWidget {
  final String gymName;

  /// My place on the gym's streak board; null when I'm not on it.
  final GymRank? rank;
  final int streak;
  final List<SocialUser> leaders;
  final VoidCallback onTap;

  const GymBoardCard({
    super.key,
    required this.gymName,
    this.rank,
    this.streak = 0,
    this.leaders = const [],
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lit = streak > 0;
    final r = rank;
    // One button for screen readers, like the hub's other cards.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: lit ? const Color(0xFFFF7A1A).withValues(alpha: 0.14) : cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        StreakFlame(size: 26, lit: lit),
                        Text(
                          '$streak',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.gymBoardTitle,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r == null
                              ? l10n.gymBoardCardNoRank(gymName)
                              : l10n.gymBoardCardRank(r.rank, r.total, gymName),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (leaders.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _Leaders(leaders: leaders.take(3).toList()),
                  ],
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The top three's avatars, overlapping, first in front.
class _Leaders extends StatelessWidget {
  final List<SocialUser> leaders;

  const _Leaders({required this.leaders});

  static const _radius = 14.0;
  static const _step = 18.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: _radius * 2 + _step * (leaders.length - 1) + 4,
      height: _radius * 2 + 4,
      child: Stack(
        children: [
          for (var i = leaders.length - 1; i >= 0; i--)
            Positioned(
              left: _step * i,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
                child: UserAvatar(
                  url: leaders[i].avatarUrl,
                  initials: leaders[i].initials,
                  radius: _radius,
                  streakTier: leaders[i].streakTier,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
