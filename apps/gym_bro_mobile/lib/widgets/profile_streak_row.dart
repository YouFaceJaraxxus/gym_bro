import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/streak.dart';
import '../pages/streaks/gym_board_page.dart';
import '../pages/streaks/streak_page.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../utils/device_timezone.dart';
import 'streak_widgets.dart';

/// The streak line on a profile: flame + count + current badge, their best
/// gym rank, and every badge they've ever earned (the trophy shelf). Mine
/// opens my streak; the rank opens that gym's board. Hidden for someone
/// who never had a streak.
class ProfileStreakRow extends StatefulWidget {
  final String userId;
  final bool isMe;

  const ProfileStreakRow({super.key, required this.userId, required this.isMe});

  @override
  State<ProfileStreakRow> createState() => _ProfileStreakRowState();
}

class _ProfileStreakRowState extends State<ProfileStreakRow> {
  final _api = ApiService();
  StreakSummary? _streak;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProfileStreakRow old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) _load();
  }

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final s = widget.isMe
          ? StreakSummary.of(await _api.getStreak(token, tz: await deviceTimezone()), widget.userId)
          : await _api.getUserStreak(token, widget.userId);
      if (mounted) setState(() => _streak = s);
    } catch (_) {
      // Decoration only: the profile works without it.
    }
  }

  Future<void> _openMine() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const StreakPage()));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _streak;
    if (s == null || (!widget.isMe && s.best == 0)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final rank = s.gymRank;
    final earned = [for (final t in StreakTier.values) if (s.best >= t.at) t];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StreakChip(current: s.current, tier: s.tier, onTap: widget.isMe ? _openMine : null),
          if (rank != null)
            ActionChip(
              avatar: const Icon(Icons.leaderboard_outlined, size: 18),
              label: Text(l10n.streakRankAt(rank.rank, rank.gymName)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GymBoardPage(gymId: rank.gymId, gymName: rank.gymName)),
              ),
            ),
          if (earned.isNotEmpty)
            Semantics(
              label: '${l10n.streakProfileBadges}: ${earned.map((t) => t.label(l10n)).join(', ')}',
              child: Tooltip(
                message: earned.map((t) => t.label(l10n)).join(' · '),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in earned)
                      Padding(padding: const EdgeInsets.only(right: 2), child: StreakGem(tier: t, size: 18)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
