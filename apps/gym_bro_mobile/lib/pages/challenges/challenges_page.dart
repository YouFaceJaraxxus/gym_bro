import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/l10n.dart';
import '../../models/challenge.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../utils/device_timezone.dart';
import '../../utils/haptics.dart';
import '../../widgets/challenge_card.dart';
import '../../widgets/challenge_medals.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';
import 'challenge_detail_page.dart';
import 'challenge_form_page.dart';

/// Challenges: the ones I'm in (with my progress), the ones I can join and
/// my medals. Staff and trainers (and super users) can create new ones.
/// [gymId] narrows the lists to one gym.
class ChallengesPage extends StatefulWidget {
  final String? gymId;
  final int initialTab;

  const ChallengesPage({super.key, this.gymId, this.initialTab = 0});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  final _api = ApiService();
  ChallengeList? _list;
  ChallengeMedals? _medals;
  Object? _error;
  final Set<String> _joining = {};

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
      final tz = await deviceTimezone();
      final results = await Future.wait([
        _api.getChallenges(token, gymId: widget.gymId, tz: tz),
        _api.getChallengeMedals(token),
      ]);
      if (!mounted) return;
      setState(() {
        _list = results[0] as ChallengeList;
        _medals = results[1] as ChallengeMedals;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(Challenge c) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChallengeDetailPage(challengeId: c.id, initial: c)));
    if (mounted) _load();
  }

  Future<void> _join(Challenge c) async {
    setState(() => _joining.add(c.id));
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final token = await AuthManager.instance.getValidToken();
      final joined = await _api.joinChallenge(token, c.id, tz: await deviceTimezone());
      messenger.showSnackBar(SnackBar(content: Text(l10n.challengeJoined)));
      if (mounted) await _open(joined);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _joining.remove(c.id));
    }
  }

  Future<void> _create() async {
    final list = _list;
    if (list == null) return;
    final created = await Navigator.push<Challenge>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChallengeFormPage(gyms: list.creatableGyms, allowPlatform: list.canCreatePlatform, gymId: widget.gymId),
      ),
    );
    if (created != null && mounted) await _open(created);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = _list;
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.challengesTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.challengesTabMine),
              Tab(text: l10n.challengesTabJoin),
              Tab(text: l10n.challengesTabMedals),
            ],
          ),
        ),
        floatingActionButton: list != null && list.canCreate
            ? FloatingActionButton.extended(
                onPressed: _create,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.challengeCreate),
              )
            : null,
        body: list == null
            ? (_error != null
                ? _Message(
                    icon: Icons.cloud_off_rounded,
                    text: l10n.challengesLoadFailed,
                    action: TextButton(onPressed: _load, child: Text(l10n.challengesRetry)),
                  )
                : SkeletonList.cards(count: 4, height: 150))
            : TabBarView(
                children: [
                  _ChallengeList(
                    items: list.mine,
                    empty: Builder(
                      builder: (context) => EmptyState(
                        icon: Icons.flag_rounded,
                        title: l10n.polishEmptyChallengesTitle,
                        message: l10n.challengesEmptyMine,
                        actionLabel: l10n.polishEmptyChallengesAction,
                        actionIcon: Icons.emoji_events_outlined,
                        onAction: () => DefaultTabController.of(context).animateTo(1),
                      ),
                    ),
                    onRefresh: _load,
                    onOpen: _open,
                  ),
                  _ChallengeList(
                    items: list.joinable,
                    empty: EmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: l10n.polishEmptyChallengesJoinTitle,
                      message: l10n.challengesEmptyJoin,
                    ),
                    onRefresh: _load,
                    onOpen: _open,
                    onJoin: _join,
                    joining: _joining,
                  ),
                  _MedalsTab(medals: _medals, onRefresh: _load),
                ],
              ),
      ),
    );
  }
}

class _ChallengeList extends StatelessWidget {
  final List<Challenge> items;
  final Widget empty;
  final Future<void> Function() onRefresh;
  final void Function(Challenge) onOpen;
  final void Function(Challenge)? onJoin;
  final Set<String> joining;

  const _ChallengeList({
    required this.items,
    required this.empty,
    required this.onRefresh,
    required this.onOpen,
    this.onJoin,
    this.joining = const {},
  });

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    return RefreshIndicator(
      onRefresh: () => Haptics.refreshed(onRefresh),
      child: items.isEmpty
          ? ListView(children: [const SizedBox(height: 48), empty])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final c = items[i];
                Widget card = ChallengeCard(
                  challenge: c,
                  onTap: () => onOpen(c),
                  onJoin: onJoin == null ? null : () => onJoin!(c),
                  joining: joining.contains(c.id),
                );
                if (!calm && i < 8) {
                  card = card.animate().fadeIn(delay: (i * 60).ms, duration: 300.ms).slideY(begin: 0.08, end: 0);
                }
                return card;
              },
            ),
    );
  }
}

class _MedalsTab extends StatelessWidget {
  final ChallengeMedals? medals;
  final Future<void> Function() onRefresh;

  const _MedalsTab({required this.medals, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final m = medals;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: m == null || m.items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 80),
                _Message(
                  iconWidget: const Opacity(opacity: 0.5, child: ChallengeMedalIcon(metric: ChallengeMetric.workouts, size: 72)),
                  text: l10n.challengesEmptyMedals,
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              children: [
                Row(
                  children: [
                    const ChallengeMedalIcon(metric: ChallengeMetric.workouts, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.challengeMedalsCount(m.count), style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          Text(l10n.challengeMedalsTitle, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                for (final medal in m.items)
                  ChallengeMedalTile(
                    medal: medal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ChallengeDetailPage(challengeId: medal.id)),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String text;
  final Widget? action;

  const _Message({this.icon, this.iconWidget, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget ?? Icon(icon, size: 56, color: cs.outline),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
