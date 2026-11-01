import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/challenge.dart';
import '../pages/challenges/challenges_page.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../utils/device_timezone.dart';
import 'challenge_ring.dart';

/// The Gym tab's way into challenges: how many I'm in (with a mini ring for
/// each, up to three) and how many are open to join. Loads itself.
class ChallengesHubCard extends StatefulWidget {
  const ChallengesHubCard({super.key});

  @override
  State<ChallengesHubCard> createState() => _ChallengesHubCardState();
}

class _ChallengesHubCardState extends State<ChallengesHubCard> {
  ChallengeList? _list;

  @override
  void initState() {
    super.initState();
    _load();
    challengeChanges.addListener(_load);
  }

  @override
  void dispose() {
    challengeChanges.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final list = await ApiService().getChallenges(token, tz: await deviceTimezone());
      if (mounted) setState(() => _list = list);
    } catch (_) {
      // The card still opens the page; it just shows no numbers.
    }
  }

  Future<void> _open() async {
    final list = _list;
    final tab = list != null && list.mine.isEmpty && list.joinable.isNotEmpty ? 1 : 0;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChallengesPage(initialTab: tab)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final mine = _list?.mine.where((c) => c.status == ChallengeStatus.active).toList() ?? const <Challenge>[];
    final open = _list?.joinable.length ?? 0;
    final subtitle = mine.isNotEmpty
        ? '${l10n.challengeHubIn(mine.length)} · ${l10n.challengeHubOpen(open)}'
        : _list == null
            ? l10n.challengeHubNone
            : '${l10n.challengeHubNone} · ${l10n.challengeHubOpen(open)}';

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _open,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFC233), Color(0xFFFF7A1A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.challengeHubTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  for (final c in mine.take(3))
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChallengeRing(
                        fraction: c.fraction,
                        colors: c.metric.colors,
                        size: 30,
                        stroke: 4,
                        child: Icon(
                          c.me.completed ? Icons.check_rounded : c.metric.icon,
                          size: 13,
                          color: c.metric.color,
                        ),
                      ),
                    ),
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
