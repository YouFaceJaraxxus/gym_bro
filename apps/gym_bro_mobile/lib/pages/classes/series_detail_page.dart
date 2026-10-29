import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/class_series.dart';
import '../../models/gym_class.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/social_widgets.dart';
import 'class_detail_page.dart';
import 'person_picker_sheet.dart';
import 'schedule_widgets.dart';
import 'series_format.dart';
import 'series_form_page.dart';
import 'series_list_tab.dart';

/// One class (timetable): details, an Active switch, its next sessions and
/// the people in it or invited, with invite / remove for whoever can edit it.
class SeriesDetailPage extends StatefulWidget {
  const SeriesDetailPage({super.key, required this.seriesId});

  final String seriesId;

  @override
  State<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends State<SeriesDetailPage> {
  static const _sessionDays = 14;
  static const _sessionsShown = 5;

  final _api = ApiService();
  ClassSeries? _series;
  List<GymClass> _sessions = [];
  bool _loading = true;
  String? _error;
  bool _busy = false;
  final Set<String> _rowBusy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _series == null;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final s = await _api.getClassSeriesDetail(token, widget.seriesId);
      final now = DateTime.now();
      List<GymClass> sessions = [];
      try {
        sessions = (await _api.getClasses(
          token,
          gymId: s.gymId,
          from: now,
          to: now.add(const Duration(days: _sessionDays)),
        )).where((c) => c.seriesId == s.id).toList();
      } catch (_) {
        // The class itself still shows; sessions are a bonus.
      }
      if (!mounted) return;
      setState(() {
        _series = s;
        _sessions = sessions;
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

  Future<void> _edit() async {
    final s = _series;
    if (s == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SeriesFormPage(existing: s)),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _setActive(bool active) async {
    final s = _series;
    if (s == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!active) {
      final ok = await confirmDialog(
        context,
        title: l10n.classSeriesPauseTitle,
        message: l10n.classSeriesPauseMessage,
        confirmLabel: l10n.classSeriesPause,
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.updateClassSeries(token, s.id, {'active': active});
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            active ? l10n.classSeriesResumedDone : l10n.classSeriesPausedDone,
          ),
        ),
      );
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    final s = _series;
    if (s == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final taken = {
      for (final e in s.enrollments ?? const <SeriesEnrollment>[])
        if (e.status != EnrollmentStatus.declined) e.userId,
    };
    final person = await showPersonPicker(
      context,
      title: l10n.classSeriesInviteTitle(s.title),
      hint: l10n.classSeriesInviteHint,
      excludeIds: taken,
    );
    if (person == null || !mounted) return;
    await _sendInvite(
      person.id,
      person.fullName.isEmpty ? '@${person.username}' : person.fullName,
      messenger,
    );
  }

  Future<void> _sendInvite(
    String userId,
    String name,
    ScaffoldMessengerState messenger,
  ) async {
    final s = _series;
    if (s == null) return;
    final l10n = context.l10n;
    setState(() => _rowBusy.add(userId));
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.inviteToClassSeries(token, s.id, userId);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.classSeriesInviteSent(name))),
      );
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _rowBusy.remove(userId));
    }
  }

  Future<void> _remove(SeriesEnrollment e) async {
    final s = _series;
    if (s == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final name = e.fullName.isEmpty ? '@${e.username}' : e.fullName;
    final pending = e.status == EnrollmentStatus.pending;
    final ok = await confirmDialog(
      context,
      title: pending
          ? l10n.classSeriesCancelInviteTitle(name)
          : l10n.classSeriesRemoveTitle(name),
      message: pending
          ? l10n.classSeriesCancelInviteMessage
          : l10n.classSeriesRemoveMessage,
      confirmLabel: pending
          ? l10n.classSeriesCancelInvite
          : l10n.classSeriesRemove,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _rowBusy.add(e.userId));
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.removeClassSeriesEnrollment(token, s.id, e.userId);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.classSeriesRemoved(name))),
      );
      await _load();
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(err))));
    } finally {
      if (mounted) setState(() => _rowBusy.remove(e.userId));
    }
  }

  Future<void> _openSession(GymClass c) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => ClassDetailPage(classId: c.id)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = _series;
    return Scaffold(
      appBar: AppBar(
        title: Text(s?.title ?? ''),
        actions: [
          if (s != null && s.canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.classSeriesEdit,
              onPressed: _edit,
            ),
        ],
      ),
      floatingActionButton: s != null && s.canEdit && s.active
          ? FloatingActionButton.extended(
              heroTag: 'series-invite-fab',
              onPressed: _invite,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.classSeriesInvite),
            )
          : null,
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
    if (_error != null && _series == null) {
      return ScheduleError(message: _error!, onRetry: _load);
    }
    final s = _series!;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final locale = localeOf(context);
    final muted = ts.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final dateRange = s.repeat == ClassRepeat.none
        ? null
        : '${DateFormat.yMMMd(locale).format(s.startsOn)} – '
              '${s.endsOn == null ? l10n.classSeriesNoEndDate : DateFormat.yMMMd(locale).format(s.endsOn!)}';
    final enrollments = s.enrollments ?? const <SeriesEnrollment>[];
    final shown = _sessions.take(_sessionsShown).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          children: [
            Expanded(child: Text(s.title, style: ts.headlineSmall)),
            const SizedBox(width: 8),
            SeriesStateChip(state: s.state),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.repeat),
                title: Text(seriesScheduleSummary(context, s)),
                subtitle: Text(
                  [?dateRange, l10n.classSeriesTimezone(s.timezone)].join('\n'),
                ),
                isThreeLine: dateRange != null,
              ),
              ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text(s.gymName),
                subtitle: s.location == null ? null : Text(s.location!),
              ),
              ListTile(
                leading: const Icon(Icons.sports),
                title: Text(s.trainerName ?? l10n.classSeriesNoTrainer),
                subtitle: Text(l10n.classSeriesTrainer),
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: Text(l10n.classSeriesSpots(s.capacity)),
                subtitle: Text(
                  [
                    l10n.classSeriesUpcomingCount(s.upcomingCount),
                    l10n.classSeriesDoneCount(s.completedCount),
                  ].join(' · '),
                ),
              ),
            ],
          ),
        ),
        if (s.description != null) ...[
          const SizedBox(height: 16),
          Text(s.description!, style: ts.bodyMedium),
        ],
        if (s.canEdit) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.classSeriesActive),
            subtitle: Text(
              s.active
                  ? l10n.classSeriesActiveHint
                  : l10n.classSeriesPausedHint,
            ),
            value: s.active,
            onChanged: _busy ? null : _setActive,
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.classSeriesUpcomingSessions, style: ts.titleMedium),
        const SizedBox(height: 4),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.classSeriesNoSessionsSoon, style: muted),
          )
        else
          for (final c in shown)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(
                '${formatDayLabel(context, c.startsAt)}, ${formatTimeRange(context, c.startsAt, c.endsAt)}',
              ),
              trailing: Text('${c.bookedCount}/${c.capacity}', style: muted),
              onTap: () => _openSession(c),
            ),
        const SizedBox(height: 16),
        Text(l10n.classSeriesPeople, style: ts.titleMedium),
        const SizedBox(height: 4),
        if (enrollments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.classSeriesNoPeople, style: muted),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [for (final e in enrollments) _personRow(s, e)],
            ),
          ),
      ],
    );
  }

  Widget _personRow(ClassSeries s, SeriesEnrollment e) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final busy = _rowBusy.contains(e.userId);
    final (label, color) = switch (e.status) {
      EnrollmentStatus.accepted => (l10n.classSeriesStatusAccepted, cs.primary),
      EnrollmentStatus.pending => (l10n.classSeriesStatusPending, cs.tertiary),
      EnrollmentStatus.declined => (
        l10n.classSeriesStatusDeclined,
        cs.onSurfaceVariant,
      ),
    };
    final name = e.fullName.isEmpty ? '@${e.username}' : e.fullName;
    return ListTile(
      leading: UserAvatar(url: e.avatarUrl, initials: e.initials),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(label, style: TextStyle(color: color)),
      trailing: !s.canEdit
          ? null
          : busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PopupMenuButton<String>(
              tooltip: l10n.classSeriesMore,
              onSelected: (v) {
                if (v == 'remove') _remove(e);
                if (v == 'invite') {
                  _sendInvite(e.userId, name, ScaffoldMessenger.of(context));
                }
              },
              itemBuilder: (_) => [
                if (e.status == EnrollmentStatus.declined && s.active)
                  PopupMenuItem(
                    value: 'invite',
                    child: Text(l10n.classSeriesInviteAgain),
                  ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    e.status == EnrollmentStatus.pending
                        ? l10n.classSeriesCancelInvite
                        : l10n.classSeriesRemove,
                  ),
                ),
              ],
            ),
    );
  }
}
