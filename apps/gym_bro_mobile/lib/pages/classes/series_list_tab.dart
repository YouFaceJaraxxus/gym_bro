import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/class_series.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'schedule_widgets.dart';
import 'series_format.dart';
import 'series_detail_page.dart';
import 'series_form_page.dart';

/// The classes the trainer runs (timetables): each with its schedule, state,
/// people and next session, plus a button to create one.
class ClassSeriesListTab extends StatefulWidget {
  const ClassSeriesListTab({super.key});

  @override
  State<ClassSeriesListTab> createState() => _ClassSeriesListTabState();
}

class _ClassSeriesListTabState extends State<ClassSeriesListTab>
    with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  List<ClassSeries> _series = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _series.isEmpty;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final series = await _api.getClassSeries(token);
      if (!mounted) return;
      setState(() {
        _series = series;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SeriesFormPage()),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _open(ClassSeries s) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => SeriesDetailPage(seriesId: s.id)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'class-series-fab',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(l10n.classSeriesNew),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading),
      );
    }
    if (_error != null) return ScheduleError(message: _error!, onRetry: _load);
    if (_series.isEmpty) {
      return ScheduleEmpty(
        icon: Icons.sports,
        title: l10n.classSeriesEmptyTitle,
        message: l10n.classSeriesEmptyMessage,
        action: FilledButton.tonalIcon(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: Text(l10n.classSeriesCreateOne),
        ),
      );
    }
    final multipleGyms = _series.map((s) => s.gymId).toSet().length > 1;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: _series.length,
      itemBuilder: (_, i) => SeriesCard(
        series: _series[i],
        showGym: multipleGyms,
        onTap: () => _open(_series[i]),
      ),
    );
  }
}

// ── Shared pieces (also used by the detail page) ──────────────────────────────

class SeriesStateChip extends StatelessWidget {
  const SeriesStateChip({super.key, required this.state});

  final ClassSeriesState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final (bg, fg, label) = switch (state) {
      ClassSeriesState.active => (
        cs.primaryContainer,
        cs.onPrimaryContainer,
        l10n.classSeriesStateActive,
      ),
      ClassSeriesState.paused => (
        cs.tertiaryContainer,
        cs.onTertiaryContainer,
        l10n.classSeriesStatePaused,
      ),
      ClassSeriesState.ended => (
        cs.surfaceContainerHighest,
        cs.onSurfaceVariant,
        l10n.classSeriesStateEnded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}

class SeriesCard extends StatelessWidget {
  const SeriesCard({
    super.key,
    required this.series,
    required this.onTap,
    this.showGym = false,
  });

  final ClassSeries series;
  final VoidCallback onTap;
  final bool showGym;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final s = series;
    final muted = ts.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final where = [
      if (showGym || s.location == null) s.gymName,
      if (s.location != null) s.location!,
    ].join(' · ');
    final next = s.nextStartsAt;

    Widget stat(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: muted),
      ],
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: s.state == ClassSeriesState.active ? 1 : 0.7,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.title,
                        style: ts.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SeriesStateChip(state: s.state),
                  ],
                ),
                const SizedBox(height: 4),
                Text(seriesScheduleSummary(context, s), style: ts.bodyMedium),
                if (where.isNotEmpty)
                  Text(
                    where,
                    style: muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    stat(
                      Icons.group_outlined,
                      l10n.classSeriesInClass(s.enrolledCount),
                    ),
                    if (s.pendingCount > 0)
                      stat(
                        Icons.mail_outline,
                        l10n.classSeriesInvitedCount(s.pendingCount),
                      ),
                    stat(
                      Icons.event_outlined,
                      l10n.classSeriesUpcomingCount(s.upcomingCount),
                    ),
                    if (s.completedCount > 0)
                      stat(
                        Icons.task_alt,
                        l10n.classSeriesDoneCount(s.completedCount),
                      ),
                  ],
                ),
                if (s.state == ClassSeriesState.active) ...[
                  const SizedBox(height: 6),
                  Text(
                    next == null
                        ? l10n.classSeriesNoUpcoming
                        : l10n.classSeriesNext(
                            '${formatDayLabel(context, next)}, ${formatTime(context, next)}',
                          ),
                    style: ts.labelMedium?.copyWith(
                      color: next == null ? cs.onSurfaceVariant : cs.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
