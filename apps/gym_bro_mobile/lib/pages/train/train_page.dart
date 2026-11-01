import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/training.dart';
import '../../models/training_session.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../theme.dart';
import '../../utils/haptics.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/training_picker_sheet.dart';
import '../challenges/challenges_page.dart';
import '../exercises_page.dart';
import '../progress/progress_page.dart';
import '../session_detail_page.dart';
import '../session_log_page.dart';
import '../sessions_page.dart';
import '../workouts_page.dart';

/// The Train tab (a body inside the home shell): one big Start workout
/// button, the last week at a glance, recent sessions, and the way into
/// routines, progress and PRs, the exercise library and challenges.
class TrainPage extends StatefulWidget {
  const TrainPage({super.key});

  @override
  State<TrainPage> createState() => TrainPageState();
}

class TrainPageState extends State<TrainPage> {
  static const _recentCount = 3;

  final _api = ApiService();

  /// The last sessions, newest first; null while loading the first time.
  List<TrainingSession>? _sessions;
  String? _error;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    // A workout finished or deleted anywhere: the list and stats moved.
    streakChanges.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    streakChanges.removeListener(_load);
    super.dispose();
  }

  /// Reloads the recent sessions (pull to refresh).
  Future<void> refresh() => _load();

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await _api.getTrainingSessions(token, pageSize: 20);
      if (!mounted) return;
      setState(() {
        _sessions = rows;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  /// Picks what to follow (or a free session) and opens the live logger,
  /// the same flow as Home's Start button and Sessions' "New session".
  Future<void> _start() async {
    if (_starting) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final pick = await showTrainingPicker(context, title: l10n.trainingSessionsNew, noneLabel: l10n.trainingSessionFree);
    if (pick == null || !mounted) return;
    Training? training;
    if (pick.training != null) {
      setState(() => _starting = true);
      try {
        final token = await AuthManager.instance.getValidToken();
        training = await _api.getTraining(token, pick.training!.id);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.todayStartFailed(e.toString().replaceFirst('Exception: ', '')))),
        );
        return;
      } finally {
        if (mounted) setState(() => _starting = false);
      }
    }
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SessionLogPage(training: training)));
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: () => Haptics.refreshed(_load),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _StartCard(starting: _starting, onStart: _start),
          const SizedBox(height: 4),
          _SectionHeader(title: l10n.polishTrainLast7Days),
          _WeekStats(sessions: _sessions),
          const SizedBox(height: 4),
          _SectionHeader(
            title: l10n.polishTrainRecent,
            action: _sessions?.isNotEmpty == true ? l10n.polishSeeAll : null,
            onAction: () => _push(const SessionsPage()),
          ),
          ..._recent(context),
          const SizedBox(height: 8),
          _SectionHeader(title: l10n.polishTrainPlanTrack),
          _ShortcutGrid(
            items: [
              _Shortcut(Icons.menu_book_outlined, l10n.shellHubWorkouts, l10n.polishTrainRoutinesSubtitle,
                  () => _push(const WorkoutsPage())),
              _Shortcut(Icons.show_chart, l10n.polishTrainProgress, l10n.polishTrainProgressSubtitle,
                  () => _push(const ProgressPage())),
              _Shortcut(Icons.sports_gymnastics_outlined, l10n.shellHubExercises, l10n.polishTrainExercisesSubtitle,
                  () => _push(const ExercisesPage())),
              _Shortcut(Icons.emoji_events_outlined, l10n.challengesTitle, l10n.polishTrainChallengesSubtitle,
                  () => _push(const ChallengesPage())),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _recent(BuildContext context) {
    final l10n = context.l10n;
    final sessions = _sessions;
    if (sessions == null && _error == null) {
      return [
        Skeleton(
          child: Column(children: [for (var i = 0; i < _recentCount; i++) const SkeletonTile(square: true)]),
        ),
      ];
    }
    if (sessions == null) {
      return [
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: Text(_error!, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: TextButton(onPressed: _load, child: Text(l10n.commonRetry)),
          ),
        ),
      ];
    }
    if (sessions.isEmpty) {
      return [
        Card(
          child: EmptyState(
            compact: true,
            icon: Icons.fitness_center,
            title: l10n.polishEmptyWorkoutsTitle,
            message: l10n.polishEmptyWorkoutsBody,
            actionLabel: l10n.polishEmptyWorkoutsAction,
            actionIcon: Icons.play_arrow_rounded,
            onAction: _start,
          ),
        ),
      ];
    }
    return [
      for (final s in sessions.take(_recentCount))
        _SessionRow(
          session: s,
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: s.id)));
            if (mounted) unawaited(_load());
          },
        ),
    ];
  }
}

// ── Start ─────────────────────────────────────────────────────────────────────

class _StartCard extends StatelessWidget {
  const _StartCard({required this.starting, required this.onStart});

  final bool starting;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer,
            // A hint of the coral accent; kept faint at night so it doesn't muddy.
            Color.alphaBlend(
              cs.tertiaryContainer.withValues(alpha: cs.brightness == Brightness.dark ? 0.18 : 0.45),
              cs.primaryContainer,
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.polishTrainHeroTitle,
                      style: tt.headlineSmall?.copyWith(color: cs.onPrimaryContainer),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.polishTrainHeroBody,
                      style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ExcludeSemantics(
                child: Icon(Icons.fitness_center, size: 44, color: cs.onPrimaryContainer.withValues(alpha: 0.35)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: starting ? null : onStart,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              icon: starting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.play_arrow_rounded, size: 28),
              label: Text(l10n.todayStartWorkout),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Last 7 days ───────────────────────────────────────────────────────────────

class _WeekStats extends StatelessWidget {
  const _WeekStats({required this.sessions});

  /// Null while loading.
  final List<TrainingSession>? sessions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final since = DateTime.now().subtract(const Duration(days: 7));
    final week = (sessions ?? const <TrainingSession>[])
        .where((s) => !s.isActive && s.startedAt.toLocal().isAfter(since))
        .toList();
    final minutes = week.fold<int>(0, (sum, s) => sum + (s.duration?.inMinutes ?? 0));
    final sets = week.fold<int>(0, (sum, s) => sum + s.setCount);
    final loading = sessions == null;
    return Row(
      children: [
        Expanded(child: _Stat(value: loading ? null : '${week.length}', label: l10n.polishTrainStatWorkouts)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(value: loading ? null : '$minutes', label: l10n.polishTrainStatMinutes)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(value: loading ? null : '$sets', label: l10n.polishTrainStatSets)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  /// Null while loading.
  final String? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 36,
                child: value == null
                    ? const Skeleton(
                        child: Align(alignment: AlignmentDirectional.centerStart, child: SkeletonBox(width: 36, height: 26)),
                      )
                    : Text(value!, style: AppText.stat(size: 34, weight: FontWeight.w800, color: cs.onSurface)),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recent ────────────────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onTap});

  final TrainingSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final start = session.startedAt.toLocal();
    final date = '${DateFormat.MMMEd(locale).format(start)} · ${DateFormat.Hm(locale).format(start)}';
    final active = session.isActive;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? colors.successContainer : cs.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            active ? Icons.radio_button_checked : Icons.fitness_center,
            size: 22,
            color: active ? colors.onSuccessContainer : cs.onSecondaryContainer,
          ),
        ),
        title: Text(
          session.trainingName ?? (session.trainingId != null ? l10n.trainingSessionPlanned : l10n.trainingSessionFree),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(active ? l10n.trainingSessionInProgress : date, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: active
            ? const Icon(Icons.chevron_right)
            : Text(
                session.durationLabel,
                semanticsLabel: l10n.trainingSessionDurationSemantics(session.durationLabel),
                style: AppText.stat(size: 20, weight: FontWeight.w600, color: cs.onSurfaceVariant),
              ),
        onTap: onTap,
      ),
    );
  }
}

// ── Shortcuts ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class _Shortcut {
  const _Shortcut(this.icon, this.label, this.subtitle, this.onTap);

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
}

/// Two tiles per line.
class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid({required this.items});

  final List<_Shortcut> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final i in items) SizedBox(width: w, child: _ShortcutTile(item: i))],
        );
      },
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.item});

  final _Shortcut item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: item.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, size: 22, color: cs.onSecondaryContainer),
                  ),
                  const SizedBox(height: 12),
                  Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
