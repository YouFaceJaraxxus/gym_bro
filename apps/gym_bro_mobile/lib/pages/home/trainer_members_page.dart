import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../member_progress_page.dart';

/// Ids of every gym where [userId] coaches (trainer or employee-trainer).
Future<Set<String>> loadCoachGymIds(
  ApiService api,
  String token,
  String userId,
) async {
  final rows = await Future.wait([
    api.getTrainers(token, userId: userId),
    api.getEmployeeTrainers(token, userId: userId),
  ]);
  return {
    for (final list in rows)
      for (final r in list) r['gym_id'] as String,
  };
}

typedef CoachedMember = ({UserProfile user, String gymId, String gymName});

/// Every member of every gym where [userId] coaches, sorted by name.
Future<List<CoachedMember>> loadCoachedMembers(
  ApiService api,
  String token,
  String userId,
) async {
  final gymIds = await loadCoachGymIds(api, token, userId);
  if (gymIds.isEmpty) return [];
  final ids = gymIds.toList();
  final results = await Future.wait([
    Future.wait(ids.map((id) => api.getBusiness(token, id))),
    Future.wait(ids.map((id) => api.getMembers(token, gymId: id))),
  ]);
  final gyms = results[0] as List<Business>;
  final memberLists = results[1] as List<List<Map<String, dynamic>>>;

  final out = <CoachedMember>[];
  for (var i = 0; i < ids.length; i++) {
    final gymName = gyms[i].name;
    for (final row in memberLists[i]) {
      final u = UserProfile.fromRoleRow(row);
      if (u.id == userId) continue;
      out.add((user: u, gymId: ids[i], gymName: gymName));
    }
  }
  out.sort(
    (a, b) =>
        a.user.fullName.toLowerCase().compareTo(b.user.fullName.toLowerCase()),
  );
  return out;
}

/// Trainer "Members" tab: searchable list of the members they coach.
/// Tapping a member opens their progress.
class TrainerMembersPage extends StatefulWidget {
  const TrainerMembersPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<TrainerMembersPage> createState() => _TrainerMembersPageState();
}

class _TrainerMembersPageState extends State<TrainerMembersPage> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();

  List<CoachedMember> _members = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _members.isEmpty;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final members = await loadCoachedMembers(_api, token, widget.profile.id);
      if (mounted) {
        setState(() {
          _members = members;
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

  List<CoachedMember> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _members;
    return _members
        .where(
          (m) =>
              m.user.fullName.toLowerCase().contains(q) ||
              m.user.email.toLowerCase().contains(q) ||
              m.user.username.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null && _members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: Text(l10n.commonRetry)),
            ],
          ),
        ),
      );
    }

    final filtered = _filtered;
    final multipleGyms = _members.map((m) => m.gymId).toSet().length > 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: l10n.shellSearchMembers,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.shellClearSearch,
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: filtered.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: constraints.maxHeight,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 48,
                                  color: cs.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _members.isEmpty
                                      ? l10n.shellNoCoachedMembers
                                      : l10n.shellNoMembersMatch(_query),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final m = filtered[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          // Decorative: the name is the tile title.
                          leading: ExcludeSemantics(
                            child: CircleAvatar(
                              backgroundImage: m.user.avatarUrl != null
                                  ? NetworkImage(m.user.avatarUrl!)
                                  : null,
                              child: m.user.avatarUrl == null
                                  ? Text(
                                      m.user.name.isNotEmpty
                                          ? m.user.name[0].toUpperCase()
                                          : '?',
                                    )
                                  : null,
                            ),
                          ),
                          title: Text(m.user.fullName),
                          subtitle: Text(
                            multipleGyms
                                ? '${m.gymName} · ${m.user.email}'
                                : m.user.email,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MemberProgressPage(
                                userId: m.user.id,
                                displayName: m.user.fullName,
                                gymId: m.gymId,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
