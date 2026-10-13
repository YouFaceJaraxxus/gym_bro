import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/progress.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/settings_service.dart';
import '../../widgets/sparkline.dart';
import 'body_measurements_tab.dart';
import 'exercise_progress_page.dart';
import 'progress_format.dart';

/// Training progress for a user (null [userId] = me): summary tiles, recent
/// PRs, per-exercise trends, and a Body tab with the weight log.
class ProgressPage extends StatefulWidget {
  final String? userId;
  final String? displayName;

  const ProgressPage({super.key, this.userId, this.displayName});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  bool get _isMe {
    final me = AuthManager.instance.profile;
    return widget.userId == null || (me != null && me.id == widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = _isMe || widget.displayName == null
        ? l10n.trainingProgressTitle
        : widget.displayName!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.trainingProgressTabTraining),
              Tab(text: l10n.trainingProgressTabBody),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TrainingTab(userId: widget.userId),
            BodyMeasurementsTab(userId: widget.userId, canEdit: _isMe),
          ],
        ),
      ),
    );
  }
}

// ── Training tab ──────────────────────────────────────────────────────────────

class _TrainingTab extends StatefulWidget {
  final String? userId;

  const _TrainingTab({this.userId});

  @override
  State<_TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<_TrainingTab> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  final _settings = SettingsService.instance;
  final _search = TextEditingController();
  ProgressSummary? _summary;
  List<ExerciseProgress> _exercises = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait([
        _api.getProgressSummary(token, userId: widget.userId),
        _api.getExerciseProgressList(token, userId: widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as ProgressSummary;
        _exercises = results[1] as List<ExerciseProgress>;
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

  void _openExercise(String id, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ExerciseProgressPage(exerciseId: id, exerciseName: name, userId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<String>(
      valueListenable: _settings.weightUnit,
      builder: (context, _, _) => _buildContent(),
    );
  }

  Widget _buildContent() {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    if (_loading && _summary == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _summary == null) {
      return ProgressErrorView(message: _error!, onRetry: _load);
    }
    final s = _summary!;

    if (s.sessionsTotal == 0 && _exercises.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            ProgressEmptyView(
              icon: Icons.insights_outlined,
              title: l10n.trainingProgressEmptyTitle,
              message: l10n.trainingProgressEmptyMessage,
            ),
          ],
        ),
      );
    }

    final q = _search.text.trim().toLowerCase();
    final exercises = q.isEmpty
        ? _exercises
        : _exercises.where((e) => e.name.toLowerCase().contains(q)).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.9,
            children: [
              _StatTile(
                icon: Icons.calendar_view_week,
                label: l10n.trainingProgressStatSessions7d,
                value: '${s.sessions7d}',
              ),
              _StatTile(
                icon: Icons.calendar_month,
                label: l10n.trainingProgressStatSessions30d,
                value: '${s.sessions30d}',
              ),
              _StatTile(
                icon: Icons.stacked_bar_chart,
                label: l10n.trainingProgressStatVolume30d,
                value: formatVolume(s.volume30dKg, locale),
              ),
              _StatTile(
                icon: Icons.local_fire_department_outlined,
                label: l10n.trainingProgressStatStreak,
                value: l10n.trainingProgressStreakWeeks(s.streakWeeks),
                hint: s.streakWeeks == 0
                    ? l10n.trainingProgressStreakStart
                    : s.trainedThisWeek
                    ? l10n.trainingProgressStreakDone
                    : l10n.trainingProgressStreakKeep,
              ),
            ],
          ),
          if (s.lastSessionAt != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.trainingProgressLastSession(relativeDay(s.lastSessionAt!, l10n, locale)),
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, size: 20, color: cs.primary),
              const SizedBox(width: 6),
              Text(l10n.trainingProgressRecentPrs, style: text.titleMedium),
              const Spacer(),
              Text(
                l10n.trainingProgressLast30Days,
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (s.recentPrs.isEmpty)
            Card(
              elevation: 0,
              color: cs.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.trainingProgressNoRecentPrs,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: s.recentPrs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _PrChip(
                  pr: s.recentPrs[i],
                  onTap: () =>
                      _openExercise(s.recentPrs[i].exerciseId, s.recentPrs[i].exerciseName),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text(l10n.trainingProgressExercises, style: text.titleMedium)),
              Text(
                '${_exercises.length}',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          if (_exercises.length > 6) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.trainingProgressFilterExercises,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 8),
          if (exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  _exercises.isEmpty
                      ? l10n.trainingProgressNoExercises
                      : l10n.trainingProgressNoExercisesMatch,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            ...exercises.map(
              (e) => _ExerciseTile(exercise: e, onTap: () => _openExercise(e.id, e.name)),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  const _StatTile({required this.icon, required this.label, required this.value, this.hint});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (hint != null)
                Text(
                  hint!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrChip extends StatelessWidget {
  final PersonalRecord pr;
  final VoidCallback onTap;

  const _PrChip({required this.pr, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final settings = SettingsService.instance;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final gain = pr.gainKg;
    return SizedBox(
      width: 176,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cs.tertiaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pr.exerciseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(color: cs.onTertiaryContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.trainingProgressE1rm(settings.formatWeight(pr.e1rm)),
                  style: text.titleMedium?.copyWith(
                    color: cs.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (gain != null)
                  Text(
                    '+${settings.formatWeight(gain)}',
                    style: text.labelMedium?.copyWith(color: cs.onTertiaryContainer),
                  ),
                const Spacer(),
                Text(
                  [
                    if (pr.weightKg != null) '${settings.formatWeight(pr.weightKg!)} × ${pr.reps}',
                    DateFormat.MMMd(locale).format(pr.date.toLocal()),
                  ].join(' · '),
                  style: text.labelSmall?.copyWith(color: cs.onTertiaryContainer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final ExerciseProgress exercise;
  final VoidCallback onTap;

  const _ExerciseTile({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final settings = SettingsService.instance;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final e = exercise;
    final best = e.bestE1rm != null
        ? l10n.trainingProgressE1rm(settings.formatWeight(e.bestE1rm!))
        : e.bestWeightKg != null
        ? l10n.trainingProgressTopWeight(settings.formatWeight(e.bestWeightKg!))
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            l10n.trainingProgressSessionCount(e.sessionCount),
            if (e.lastPerformed != null) relativeDay(e.lastPerformed!, l10n, locale),
            if (e.primaryMuscles.isNotEmpty) muscleLabels(e.primaryMuscles.take(2).toList(), l10n),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Sparkline(
              values: e.trend.map(settings.toDisplayWeight).toList(),
              semanticLabel: e.trend.isEmpty
                  ? null
                  : l10n.trainingProgressTrendSemantics(settings.formatWeight(e.trend.last)),
            ),
            if (best != null) ...[
              const SizedBox(height: 2),
              Text(best, style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
