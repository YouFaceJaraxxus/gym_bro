import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import 'package:intl/intl.dart';
import '../../models/membership.dart';
import '../../models/training_session.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../membership_page.dart';
import '../sessions_page.dart';
import 'home_widgets.dart';

class MemberHomePage extends StatefulWidget {
  const MemberHomePage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<MemberHomePage> createState() => _MemberHomePageState();
}

class _MemberHomePageState extends State<MemberHomePage> {
  final _api = ApiService();
  Membership? _membership;
  TrainingSession? _nextSession;
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
        _api.getMemberships(token, userId: widget.profile.id),
        _api.getTrainingSessions(token, page: 0, pageSize: 5),
      ]);
      final memberships = results[0] as List<Membership>;
      final sessions = results[1] as List<TrainingSession>;
      memberships.sort((a, b) => b.fromDate.compareTo(a.fromDate));
      final upcoming = sessions.where((s) => s.isActive).firstOrNull;
      if (mounted) {
        setState(() {
          _membership = memberships.where((m) => m.isActive).firstOrNull;
          _nextSession = upcoming;
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final membership = _membership;
    final isValid = membership != null && !membership.isExpired;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l10n.shellHey(widget.profile.name),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            widget.profile.role.label(context.l10n),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 32),
          if (_error != null) ...[
            HomeError(message: _error!, onRetry: _load),
            const SizedBox(height: 16),
          ],
          MergeSemantics(
            child: Semantics(
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  await pushTabPage<void>(
                    context,
                    l10n.shellTabMembership,
                    MembershipPage(profile: widget.profile),
                  );
                  _load();
                },
                child: Card(
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.card_membership_outlined,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l10n.shellMyMembership,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_loading)
                          SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: l10n.commonLoading,
                            ),
                          )
                        else if (_error != null)
                          Text(l10n.shellMembershipLoadFailed)
                        else if (!isValid)
                          Text(l10n.shellNoActiveMembership)
                        else
                          Text(
                            l10n.shellMembershipValidUntil(
                              membership.membershipType?.name ??
                                  l10n.shellMembershipActive,
                              DateFormat.yMMMd(
                                Localizations.localeOf(context).toString(),
                              ).format(membership.toDate),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(l10n.shellUpcomingClasses),
              subtitle: Text(
                _loading
                    ? l10n.commonLoading
                    : _error != null
                    ? l10n.shellUnavailable
                    : _nextSession != null
                    ? l10n.shellSessionInProgress
                    : l10n.shellNoneScheduled,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SessionsPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
