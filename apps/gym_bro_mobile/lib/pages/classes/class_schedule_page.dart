import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/class_series.dart';
import '../../models/gym_class.dart';
import '../../models/people.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/class_calendar.dart';
import '../../widgets/social_widgets.dart';
import 'class_detail_page.dart';
import 'schedule_widgets.dart';
import 'series_format.dart';

/// The Schedule tab: pending invites (to classes, and from trainers) on top,
/// then a calendar of the caller's sessions — highlighted — merged with the
/// other sessions they can book at their gyms (faded), with an "Only mine"
/// filter. Booking happens on a session's page.
///
/// Works as a tab body inside the home Scaffold, pushed inside a Scaffold
/// with an app bar, or pushed on its own (it then brings its own app bar).
class ClassSchedulePage extends StatefulWidget {
  const ClassSchedulePage({super.key});

  @override
  State<ClassSchedulePage> createState() => _ClassSchedulePageState();
}

class _ClassSchedulePageState extends State<ClassSchedulePage> {
  final _api = ApiService();
  final _calendar = GlobalKey<ClassCalendarState>();
  List<ClassSeries> _classInvites = [];
  List<PersonSummary> _trainerInvites = [];
  final Set<String> _busy = {};
  bool _onlyMine = false;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait([
        _api.getClassInvites(token),
        _api.getCustomerInvites(token),
      ]);
      if (!mounted) return;
      setState(() {
        _classInvites = results[0] as List<ClassSeries>;
        _trainerInvites = results[1] as List<PersonSummary>;
      });
    } catch (_) {
      // Invites are extra; the calendar still works without them.
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadInvites(),
      _calendar.currentState?.refresh() ?? Future.value(),
    ]);
  }

  static bool _isMine(GymClass c) =>
      c.myBookingStatus != null && c.myBookingStatus != BookingStatus.cancelled;

  Future<void> _answerClass(ClassSeries s, bool accept) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(s.id));
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.answerClassInvite(token, s.id, accept: accept);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? l10n.classCalendarJoined(s.title)
                : l10n.classCalendarInviteDeclined,
          ),
        ),
      );
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(s.id));
    }
  }

  Future<void> _answerTrainer(PersonSummary t, bool accept) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(t.id));
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.answerCustomerInvite(token, t.id, accept: accept);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? l10n.classCalendarTrainerAccepted(_name(t))
                : l10n.classCalendarInviteDeclined,
          ),
        ),
      );
      // Declining a trainer declines their class invites too.
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(t.id));
    }
  }

  static String _name(PersonSummary p) {
    final n = '${p.name} ${p.lastName}'.trim();
    return n.isEmpty ? '@${p.username}' : n;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parent = Scaffold.maybeOf(context);
    final ownAppBar = parent == null || !parent.hasAppBar;
    final inviteCount = _classInvites.length + _trainerInvites.length;
    return Scaffold(
      appBar: ownAppBar ? AppBar(title: Text(l10n.trainingClassClasses)) : null,
      body: Column(
        children: [
          if (inviteCount > 0) _buildInvites(context, inviteCount),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilterChip(
                avatar: _onlyMine
                    ? null
                    : const Icon(Icons.event_available, size: 18),
                label: Text(l10n.classCalendarOnlyMine),
                selected: _onlyMine,
                onSelected: (v) => setState(() => _onlyMine = v),
              ),
            ),
          ),
          Expanded(
            child: ClassCalendar(
              key: _calendar,
              // The default list covers the caller's gyms plus every class
              // they're booked into (also ones a trainer added them to).
              load: (from, to) async {
                final token = await AuthManager.instance.getValidToken();
                return _api.getClasses(token, from: from, to: to);
              },
              isHighlighted: _isMine,
              filter: _onlyMine ? _isMine : null,
              onTap: (c) async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClassDetailPage(classId: c.id),
                  ),
                );
                if (mounted) _loadInvites();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvites(BuildContext context, int count) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: cs.secondaryContainer,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.35,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.classCalendarInvites(count),
                  style: ts.titleSmall?.copyWith(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            for (final t in _trainerInvites)
              _InviteTile(
                leading: UserAvatar(url: t.avatarUrl, initials: t.initials),
                title: l10n.classCalendarTrainerInvite(_name(t)),
                subtitle: l10n.classCalendarTrainerInviteHint,
                busy: _busy.contains(t.id),
                onAccept: () => _answerTrainer(t, true),
                onDecline: () => _answerTrainer(t, false),
              ),
            for (final s in _classInvites)
              _InviteTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.event_repeat, color: cs.onPrimaryContainer),
                ),
                title: s.title,
                subtitle: [
                  [
                    if (s.invitedBy != null)
                      _name(s.invitedBy!)
                    else if (s.trainerName != null)
                      s.trainerName!,
                    s.gymName,
                  ].where((x) => x.isNotEmpty).join(' · '),
                  seriesScheduleSummary(context, s),
                ].join('\n'),
                busy: _busy.contains(s.id),
                onAccept: () => _answerClass(s, true),
                onDecline: () => _answerClass(s, false),
              ),
          ],
        ),
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ts.titleSmall?.copyWith(
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: ts.bodySmall?.copyWith(
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : onDecline,
                  child: Text(l10n.classCalendarDecline),
                ),
                FilledButton.tonal(
                  onPressed: busy ? null : onAccept,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.classCalendarAccept),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
