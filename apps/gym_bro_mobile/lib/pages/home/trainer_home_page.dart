import 'package:flutter/material.dart';
import '../../models/training_session.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../session_detail_page.dart';
import 'home_widgets.dart';
import 'trainer_members_page.dart';

class TrainerHomePage extends StatefulWidget {
  const TrainerHomePage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<TrainerHomePage> createState() => _TrainerHomePageState();
}

class _TrainerHomePageState extends State<TrainerHomePage> {
  int _refreshTick = 0;

  Future<void> _refresh() async => setState(() => _refreshTick++);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          HomeHeader(
            title: 'Welcome, ${widget.profile.name}',
            subtitle: widget.profile.role.displayName,
          ),
          TrainerTodaySection(
            key: ValueKey('trainer-$_refreshTick'),
            profile: widget.profile,
          ),
        ],
      ),
    );
  }
}

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
        _api.getTrainingSessions(token,
            trainerId: widget.profile.id, page: 0, pageSize: 50),
        loadCoachedMembers(_api, token, widget.profile.id),
        _api.getUsers(token),
      ]);
      final sessions = results[0] as List<TrainingSession>;
      final members = results[1] as List<CoachedMember>;
      final users = results[2] as List<UserProfile>;

      final today = DateUtils.dateOnly(DateTime.now());
      final todays = sessions
          .where((s) => DateUtils.isSameDay(s.startedAt.toLocal(), today))
          .toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

      if (mounted) {
        setState(() {
          _today = todays;
          _users = {for (final u in users) u.id: u};
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

  String _time(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
        HomeSectionTitle("Today's sessions",
            trailing: Text('${_today.length}',
                style: Theme.of(context).textTheme.titleMedium)),
        if (_today.isEmpty)
          const HomeEmpty(
              icon: Icons.today_outlined, label: 'No sessions with you today')
        else
          for (final s in _today)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  s.isActive ? Icons.play_circle_outline : Icons.check_circle_outline,
                  color: s.isActive ? cs.primary : cs.outline,
                ),
                title: Text(_users[s.userId]?.fullName ?? 'Member'),
                subtitle: Text(
                  s.isActive
                      ? 'Started ${_time(s.startedAt)} · in progress'
                      : '${_time(s.startedAt)} · ${s.durationLabel}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SessionDetailPage(sessionId: s.id)),
                  );
                  _load();
                },
              ),
            ),
        const SizedBox(height: 16),
        StatTile(
          icon: Icons.people_outline,
          label: 'Members you coach',
          value: '$_memberCount',
          color: cs.primaryContainer,
          onTap: () async {
            await pushTabPage<void>(
                context, 'Members', TrainerMembersPage(profile: widget.profile));
            _load();
          },
        ),
      ],
    );
  }
}
