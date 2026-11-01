import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/streak.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/settings_service.dart';
import '../../utils/device_timezone.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/streak_widgets.dart';
import 'gym_board_page.dart';

/// My workout streak: flame, freezes, this week, the next badge, the badge
/// shelf, gym ranks and what happened lately.
class StreakPage extends StatefulWidget {
  const StreakPage({super.key});

  @override
  State<StreakPage> createState() => _StreakPageState();
}

class _StreakPageState extends State<StreakPage> {
  final _api = ApiService();
  StreakStatus? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _status == null;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final status = await _api.getStreak(token, tz: await deviceTimezone());
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _editSettings() async {
    final changed = await showStreakSettingsSheet(context);
    if (changed && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.streakTitle),
        actions: [
          IconButton(
            tooltip: l10n.streakSettingsTitle,
            icon: const Icon(Icons.tune),
            onPressed: _editSettings,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    final s = _status;
    if (s == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? l10n.streakLoadFailed, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: _load, child: Text(l10n.commonRetry)),
            ],
          ),
        ),
      );
    }
    final cards = <Widget>[
      _Hero(status: s),
      if (s.needsWorkoutToday) _AtRiskBanner(status: s),
      _WeekCard(status: s, onEditTarget: _editSettings),
      _FreezesCard(status: s),
      if (s.nextTier != null) _NextBadgeCard(status: s),
      _BadgeShelf(best: s.best, current: s.tier),
      if (s.ranks.isNotEmpty) _RanksCard(ranks: s.ranks),
      if (s.events.isNotEmpty) _HistoryCard(events: s.events),
      const _RulesCard(),
    ];
    final animate = !MediaQuery.of(context).disableAnimations;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          for (final (i, c) in cards.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: animate
                  ? c.animate().fadeIn(delay: (60 * i).ms, duration: 300.ms).slideY(begin: 0.08, curve: Curves.easeOut)
                  : c,
            ),
        ],
      ),
    );
  }
}

// ── Settings sheet ────────────────────────────────────────────────────────────

/// Weekly target and gym-board visibility. True when something was saved.
Future<bool> showStreakSettingsSheet(BuildContext context) async {
  final saved = await showAppBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _StreakSettingsSheet(),
  );
  return saved == true;
}

class _StreakSettingsSheet extends StatefulWidget {
  const _StreakSettingsSheet();

  @override
  State<_StreakSettingsSheet> createState() => _StreakSettingsSheetState();
}

class _StreakSettingsSheetState extends State<_StreakSettingsSheet> {
  final _settings = SettingsService.instance;
  late int _target = _settings.settings.value.weeklyWorkoutTarget;
  late bool _onBoards = _settings.settings.value.showOnGymBoards;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await _settings.update(weeklyWorkoutTarget: _target, showOnGymBoards: _onBoards);
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.streakSettingsTitle, style: text.titleLarge),
          const SizedBox(height: 16),
          Text(l10n.streakTargetLabel, style: text.titleSmall),
          const SizedBox(height: 4),
          Text(l10n.streakTargetHelp, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: l10n.streakTargetLess,
                onPressed: _target > 1 ? () => setState(() => _target--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 140,
                child: Text(
                  l10n.streakTargetValue(_target),
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton.filledTonal(
                tooltip: l10n.streakTargetMore,
                onPressed: _target < 14 ? () => setState(() => _target++) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _onBoards,
            onChanged: (v) => setState(() => _onBoards = v),
            title: Text(l10n.streakShowOnBoards),
            subtitle: Text(l10n.streakShowOnBoardsHelp),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.commonSave),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cards ─────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final Color? color;

  const _Card({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: color ?? cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _Hero extends StatelessWidget {
  final StreakStatus status;

  const _Hero({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = status;
    final lit = s.current > 0;
    final animate = !MediaQuery.of(context).disableAnimations;
    Widget flame = StreakFlame(size: 96, lit: lit);
    if (lit && animate) {
      flame = flame
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 0.94, end: 1.06, duration: 900.ms, curve: Curves.easeInOut);
    }
    return _Card(
      color: lit ? const Color(0xFFFF7A1A).withValues(alpha: 0.10) : null,
      child: Column(
        children: [
          flame,
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: animate ? 0 : s.current, end: s.current),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              '$v',
              style: text.displayMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            lit ? l10n.streakWorkoutsInARow(s.current) : l10n.streakNone,
            style: text.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (s.tier != null)
                Chip(
                  avatar: StreakGem(tier: s.tier!, size: 20, shimmer: true),
                  label: Text(s.tier!.label(l10n)),
                ),
              Chip(
                avatar: Icon(Icons.emoji_events_outlined, size: 18, color: cs.primary),
                label: Text(l10n.streakBest(s.best)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AtRiskBanner extends StatelessWidget {
  final StreakStatus status;

  const _AtRiskBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = status;
    final today = s.atRisk.where((e) => e.day == s.today).toList();
    final yesterday = s.atRisk.where((e) => e.day.isBefore(s.today)).toList();
    final lines = <String>[
      for (final e in today) l10n.streakAtRiskToday(e.name ?? l10n.streakPlannedWorkout),
      for (final e in yesterday) l10n.streakAtRiskYesterday(e.name ?? l10n.streakPlannedWorkout),
      if (s.atRisk.isEmpty) l10n.streakAtRiskWeek(s.weekRemaining),
    ];
    return _Card(
      color: cs.errorContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.streakAtRiskTitle,
                  style: text.titleSmall?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w700),
                ),
                for (final line in lines)
                  Text(line, style: text.bodyMedium?.copyWith(color: cs.onErrorContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  final StreakStatus status;
  final VoidCallback onEditTarget;

  const _WeekCard({required this.status, required this.onEditTarget});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final w = status.week;
    final today = status.today;
    final days = [for (var i = 0; i < 7; i++) w.start.add(Duration(days: i))];

    Widget dayDot(DateTime d) {
      final entries = w.entries.where((e) => e.day == d).toList();
      final past = d.isBefore(today);
      final isToday = d == today;
      final planned = entries.isNotEmpty;
      final done = planned && entries.every((e) => e.done);
      final missed = planned && past && !done && d.isBefore(today.subtract(const Duration(days: 1)));
      final (Color bg, Widget? icon) = done
          ? (const Color(0xFFFF7A1A), const Icon(Icons.local_fire_department_rounded, size: 18, color: Colors.white))
          : missed
          ? (cs.errorContainer, Icon(Icons.close_rounded, size: 16, color: cs.onErrorContainer))
          : planned
          ? (cs.surfaceContainerHighest, Icon(Icons.fitness_center, size: 14, color: cs.onSurfaceVariant))
          : (cs.surfaceContainerHigh, null);
      return Column(
        children: [
          Text(
            DateFormat.E(locale).format(d).substring(0, 1).toUpperCase(),
            style: text.labelSmall?.copyWith(
              color: isToday ? cs.primary : cs.onSurfaceVariant,
              fontWeight: isToday ? FontWeight.w800 : null,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: isToday ? Border.all(color: cs.primary, width: 2) : null,
            ),
            alignment: Alignment.center,
            child: icon,
          ),
        ],
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.streakThisWeek, style: text.titleMedium)),
              if (!w.planned)
                TextButton(onPressed: onEditTarget, child: Text(l10n.streakTargetValue(w.target))),
            ],
          ),
          const SizedBox(height: 8),
          if (w.planned)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (final d in days) dayDot(d)],
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: w.required == 0 ? 1 : (w.done / w.required).clamp(0.0, 1.0),
                minHeight: 12,
                color: const Color(0xFFFF7A1A),
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text(
            w.planned
                ? (w.remaining == 0 ? l10n.streakWeekPlannedDone : l10n.streakWeekPlannedLeft(w.remaining))
                : (w.remaining == 0
                    ? l10n.streakWeekTargetDone(w.done)
                    : l10n.streakWeekTargetLeft(w.done, w.required)),
            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _FreezesCard extends StatelessWidget {
  final StreakStatus status;

  const _FreezesCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _Card(
      child: Row(
        children: [
          FreezeCubes(freezes: status.freezes, max: status.maxFreezes, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.streakFreezes(status.freezes), style: text.titleMedium),
                Text(
                  l10n.streakFreezesHelp(status.maxFreezes),
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextBadgeCard extends StatelessWidget {
  final StreakStatus status;

  const _NextBadgeCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final next = status.nextTier!;
    final from = status.tier?.at ?? 0;
    final progress = ((status.current - from) / (next.at - from)).clamp(0.0, 1.0);
    return _Card(
      child: Row(
        children: [
          StreakGem(tier: next, size: 44, locked: true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.streakNextBadge(next.label(l10n)), style: text.titleMedium),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      color: next.color,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.streakToGo(next.at - status.current, next.at),
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Every badge: earned ones (by best streak) in colour, the rest locked.
class _BadgeShelf extends StatelessWidget {
  final int best;
  final StreakTier? current;

  const _BadgeShelf({required this.best, this.current});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.streakBadges, style: text.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 12,
            children: [
              for (final t in StreakTier.values)
                SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      StreakGem(tier: t, size: 40, locked: best < t.at, shimmer: t == current),
                      const SizedBox(height: 6),
                      Text(
                        t.label(l10n),
                        style: text.labelMedium?.copyWith(
                          fontWeight: t == current ? FontWeight.w800 : null,
                          color: best < t.at ? cs.onSurfaceVariant : null,
                        ),
                      ),
                      Text(
                        l10n.streakBadgeAt(t.at),
                        style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RanksCard extends StatelessWidget {
  final List<GymRank> ranks;

  const _RanksCard({required this.ranks});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.streakGymBoards, style: text.titleMedium),
          for (final r in ranks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('#${r.rank}')),
              title: Text(r.gymName),
              subtitle: Text(l10n.streakRankOf(r.rank, r.total)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GymBoardPage(gymId: r.gymId, gymName: r.gymName)),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final List<StreakEvent> events;

  const _HistoryCard({required this.events});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.streakHistory, style: text.titleMedium),
          for (final e in events.take(12))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: switch (e.kind) {
                'tier' when e.tier != null => StreakGem(tier: e.tier!, size: 26),
                'freeze_earned' => const Icon(Icons.ac_unit_rounded, color: FreezeCubes.iceColor),
                'freeze_used' => const Icon(Icons.shield_outlined, color: FreezeCubes.iceColor),
                _ => Icon(Icons.heart_broken_outlined, color: cs.error),
              },
              title: Text(switch (e.kind) {
                'tier' when e.tier != null => l10n.streakEventTier(e.tier!.label(l10n), e.streak),
                'freeze_earned' => l10n.streakEventFreezeEarned,
                'freeze_used' => l10n.streakEventFreezeUsed(e.streak),
                _ => l10n.streakEventBroken(e.streak),
              }),
              trailing: Text(
                DateFormat.MMMd(locale).format(e.onDate),
                style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return _Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(l10n.streakRulesTitle, style: text.titleMedium),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final rule in [
              l10n.streakRuleCount,
              l10n.streakRulePlanned,
              l10n.streakRuleTarget,
              l10n.streakRuleLate,
              l10n.streakRuleFreezes,
              l10n.streakRuleBadges,
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    Expanded(child: Text(rule, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
