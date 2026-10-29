import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import 'package:intl/intl.dart';
import '../../models/training_session.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../session_detail_page.dart';
import 'home_widgets.dart';
import 'trainer_members_page.dart';

/// Today's sessions where the user is the trainer, plus the number of members
/// they coach. Re-create with a new key to reload.
class TrainerTodaySection extends StatefulWidget {
  const TrainerTodaySection({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<TrainerTodaySection> createState() => _TrainerTodaySectionState();
}

class _TrainerTodaySectionState extends State<TrainerTodaySection> {
  final _api = ApiService();
  List<TrainingSession> _today = [];
  Map<String, UserProfile> _users = {};
  int _memberCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait([
        _api.getTrainingSessions(
          token,
          trainerId: widget.profile.id,
          page: 0,
          pageSize: 50,
        ),
        loadCoachedMembers(_api, token, widget.profile.id),
      ]);
      final sessions = results[0] as List<TrainingSession>;
      final members = results[1] as List<CoachedMember>;

      final today = DateUtils.dateOnly(DateTime.now());
      final todays =
          sessions
              .where((s) => DateUtils.isSameDay(s.startedAt.toLocal(), today))
              .toList()
            ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

      if (mounted) {
        setState(() {
          _today = todays;
          _users = {for (final m in members) m.user.id: m.user};
          _memberCount = members.map((m) => m.user.id).toSet().length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  String _time(DateTime d) => DateFormat.Hm(
    Localizations.localeOf(context).toString(),
  ).format(d.toLocal());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: HomeError(message: _error!, onRetry: _load),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          l10n.shellTodaysSessions,
          trailing: Text(
            '${_today.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (_today.isEmpty)
          HomeEmpty(
            icon: Icons.today_outlined,
            label: l10n.shellNoSessionsToday,
          )
        else
          for (final s in _today)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  s.isActive
                      ? Icons.play_circle_outline
                      : Icons.check_circle_outline,
                  color: s.isActive ? cs.primary : cs.outline,
                ),
                title: Text(_users[s.userId]?.fullName ?? l10n.shellRoleMember),
                subtitle: Text(
                  s.isActive
                      ? l10n.shellSessionStartedInProgress(_time(s.startedAt))
                      : '${_time(s.startedAt)} · ${s.durationLabel}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionDetailPage(sessionId: s.id),
                    ),
                  );
                  _load();
                },
              ),
            ),
        const SizedBox(height: 16),
        StatTile(
          icon: Icons.people_outline,
          label: l10n.shellMembersYouCoach,
          value: '$_memberCount',
          color: cs.primaryContainer,
          onTap: () async {
            await pushTabPage<void>(
              context,
              l10n.shellTabMembers,
              TrainerMembersPage(profile: widget.profile),
            );
            _load();
          },
        ),
      ],
    );
  }
}
