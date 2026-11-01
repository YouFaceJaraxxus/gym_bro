import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/streak.dart';
import '../pages/streaks/streak_page.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../theme.dart';
import '../utils/device_timezone.dart';
import 'streak_widgets.dart';

/// My streak at the top of Home: flame, count, badge, freezes and what this
/// week still needs (red when today's workout keeps it alive). Opens the
/// streak screen.
class HomeStreakCard extends StatefulWidget {
  const HomeStreakCard({super.key});

  @override
  State<HomeStreakCard> createState() => HomeStreakCardState();
}

class HomeStreakCardState extends State<HomeStreakCard> {
  final _api = ApiService();
  StreakStatus? _status;

  @override
  void initState() {
    super.initState();
    streakChanges.addListener(refresh);
    refresh();
  }

  @override
  void dispose() {
    streakChanges.removeListener(refresh);
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final status = await _api.getStreak(token, tz: await deviceTimezone());
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // Home works without it.
    }
  }

  Future<void> _open() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const StreakPage()));
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final risk = s.needsWorkoutToday;
    final lit = s.current > 0;
    final w = s.week;
    final line = !lit
        ? l10n.streakProgressHintNone
        : risk
        ? l10n.streakProgressHintRisk
        : w.remaining == 0
        ? (w.planned ? l10n.streakWeekPlannedDone : l10n.streakWeekTargetDone(w.done))
        : (w.planned ? l10n.streakWeekPlannedLeft(w.remaining) : l10n.streakWeekTargetLeft(w.done, w.required));
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: risk
          ? cs.errorContainer
          : lit
          ? const Color(0xFFFF7A1A).withValues(alpha: 0.12)
          : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              StreakFlame(size: 44, lit: lit),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${s.current}',
                          style: AppText.stat(size: 34, weight: FontWeight.w800, color: risk ? cs.onErrorContainer : cs.onSurface),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l10n.streakWorkoutsInARow(s.current),
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall,
                          ),
                        ),
                        if (s.tier != null) ...[
                          const SizedBox(width: 6),
                          StreakGem(tier: s.tier!, size: 20, shimmer: true),
                        ],
                      ],
                    ),
                    Text(
                      line,
                      style: text.bodySmall?.copyWith(color: risk ? cs.onErrorContainer : cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              FreezeCubes(freezes: s.freezes, max: s.maxFreezes, size: 18),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
