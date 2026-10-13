import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/business.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

// Shared "pick a member I coach" sheet: used for routine assignment and
// available to any feature that targets one of the caller's members.

/// A gym member the current user coaches (owner, employee, employee-trainer
/// or trainer at one of the member's gyms; super users: everyone).
class CoachedMember {
  final String userId;
  final String name;
  final String email;
  final String? avatarUrl;
  final List<String> gymNames;

  CoachedMember({
    required this.userId,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.gymNames,
  });
}

/// The person chosen in [showCoachedMemberPicker].
class CoachedMemberPick {
  final String userId;

  /// Display name; localized "you" for the caller.
  final String name;
  final bool isSelf;

  const CoachedMemberPick({required this.userId, required this.name, this.isSelf = false});
}

/// Members of every gym where [me] works or trains (super users: every gym),
/// excluding [me], sorted by name.
Future<List<CoachedMember>> loadCoachedMembers(
  ApiService api,
  String token,
  UserProfile me,
) async {
  final isSuper = me.role == UserRole.superUser;
  final results = await Future.wait<Object>([
    api.getBusinesses(token),
    if (!isSuper) ...[
      api.getGymOwners(token, userId: me.id),
      api.getEmployees(token, userId: me.id),
      api.getEmployeeTrainers(token, userId: me.id),
      api.getTrainers(token, userId: me.id),
    ],
  ]);
  final businesses = results[0] as List<Business>;
  final gyms = {
    for (final b in businesses)
      if (b.type == 'gym') b.id: b.name,
  };

  final gymIds = <String>{};
  if (isSuper) {
    gymIds.addAll(gyms.keys);
  } else {
    for (final rows in results.skip(1)) {
      for (final r in rows as List<Map<String, dynamic>>) {
        final gymId = r['gym_id'] as String?;
        if (gymId != null && gyms.containsKey(gymId)) gymIds.add(gymId);
      }
    }
  }
  if (gymIds.isEmpty) return [];

  final ids = gymIds.toList();
  final memberLists = await Future.wait(ids.map((g) => api.getMembers(token, gymId: g)));

  final byUser = <String, CoachedMember>{};
  for (var i = 0; i < ids.length; i++) {
    final gymName = gyms[ids[i]]!;
    for (final row in memberLists[i]) {
      final uid = row['user_id'] as String?;
      if (uid == null || uid == me.id) continue;
      final u = UserProfile.fromRoleRow(row);
      final existing = byUser[uid];
      if (existing != null) {
        if (!existing.gymNames.contains(gymName)) existing.gymNames.add(gymName);
      } else {
        byUser[uid] = CoachedMember(
          userId: uid,
          name: u.fullName.isEmpty ? u.username : u.fullName,
          email: u.email,
          avatarUrl: u.avatarUrl,
          gymNames: [gymName],
        );
      }
    }
  }
  return byUser.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// Bottom sheet: "Myself" (when [includeSelf]) plus a searchable list of
/// members the caller coaches. Returns null when dismissed. [title] defaults
/// to a localized "Choose a member".
Future<CoachedMemberPick?> showCoachedMemberPicker(
  BuildContext context, {
  String? title,
  bool includeSelf = true,
}) {
  return showModalBottomSheet<CoachedMemberPick>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CoachedMemberSheet(
      title: title ?? context.l10n.trainingCoachChooseMember,
      includeSelf: includeSelf,
    ),
  );
}

class _CoachedMemberSheet extends StatefulWidget {
  final String title;
  final bool includeSelf;

  const _CoachedMemberSheet({required this.title, required this.includeSelf});

  @override
  State<_CoachedMemberSheet> createState() => _CoachedMemberSheetState();
}

class _CoachedMemberSheetState extends State<_CoachedMemberSheet> {
  final _api = ApiService();
  final _search = TextEditingController();
  List<CoachedMember> _members = [];
  bool _loading = true;
  String? _error;

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
    final l10n = context.l10n;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      await AuthManager.instance.ensureProfile();
      final me = AuthManager.instance.profile;
      if (me == null) throw Exception(l10n.trainingCoachNotSignedIn);
      final members = await loadCoachedMembers(_api, token, me);
      if (!mounted) return;
      setState(() {
        _members = members;
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

  List<CoachedMember> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _members;
    return _members
        .where((m) =>
            m.name.toLowerCase().contains(q) ||
            m.email.toLowerCase().contains(q) ||
            m.gymNames.any((g) => g.toLowerCase().contains(q)))
        .toList();
  }

  Widget _buildList(ScrollController scroll) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: TextStyle(color: cs.error), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: _load, child: Text(l10n.commonRetry)),
            ],
          ),
        ),
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined, size: 40, color: cs.outline),
              const SizedBox(height: 8),
              Text(
                _members.isEmpty
                    ? l10n.trainingCoachNoMembers
                    : l10n.trainingCoachNoMatches,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: scroll,
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        return ListTile(
          // Decorative: the name is read from the title.
          leading: ExcludeSemantics(
            child: CircleAvatar(
              backgroundImage: m.avatarUrl != null ? NetworkImage(m.avatarUrl!) : null,
              child: m.avatarUrl == null
                  ? Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase())
                  : null,
            ),
          ),
          title: Text(m.name),
          subtitle: Text(m.gymNames.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.pop(context, CoachedMemberPick(userId: m.userId, name: m.name)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthManager.instance.profile;
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          if (widget.includeSelf && me != null)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(l10n.trainingCoachMyself),
              onTap: () => Navigator.pop(
                context,
                CoachedMemberPick(userId: me.id, name: l10n.trainingCoachYou, isSelf: true),
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.trainingCoachSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(child: _buildList(scroll)),
        ],
      ),
    );
  }
}
