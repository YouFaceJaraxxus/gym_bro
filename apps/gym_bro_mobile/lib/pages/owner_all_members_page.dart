import 'package:flutter/material.dart';
import '../models/business.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'gym_members_page.dart';

class OwnerAllMembersPage extends StatefulWidget {
  const OwnerAllMembersPage({super.key});

  @override
  State<OwnerAllMembersPage> createState() => _OwnerAllMembersPageState();
}

class _OwnerAllMembersPageState extends State<OwnerAllMembersPage> {
  final _api = ApiService();
  final _search = TextEditingController();

  List<({Business gym, List<({String memberId, UserProfile user})> members})>
      _gymData = [];
  String? _filterGymId;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final userId = AuthManager.instance.profile!.id;

      final ownerRecords = await _api.getGymOwners(token, userId: userId);
      final gymIds =
          ownerRecords.map((r) => r['gym_id'] as String).toSet();

      if (gymIds.isEmpty) {
        if (mounted) setState(() { _gymData = []; _loading = false; });
        return;
      }

      final allBusinesses = await _api.getBusinesses(token);
      final gyms = allBusinesses
          .where((b) => gymIds.contains(b.id) && b.type == 'gym')
          .toList();

      final allUsers = await _api.getUsers(token);
      final userMap = {for (final u in allUsers) u.id: u};
      final memberLists = await Future.wait(
          gyms.map((g) => _api.getMembers(token, gymId: g.id)));

      if (mounted) {
        setState(() {
          _gymData = List.generate(gyms.length, (i) {
            final rows = memberLists[i];
            final members = rows.map((r) {
              final u = userMap[r['user_id'] as String];
              if (u == null) return null;
              return (memberId: r['id'] as String, user: u);
            }).whereType<({String memberId, UserProfile user})>().toList();
            return (gym: gyms[i], members: members);
          });
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

  List<({Business gym, UserProfile user})> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final result = <({Business gym, UserProfile user})>[];
    for (final gd in _gymData) {
      if (_filterGymId != null && gd.gym.id != _filterGymId) continue;
      for (final m in gd.members) {
        if (q.isEmpty ||
            m.user.fullName.toLowerCase().contains(q) ||
            m.user.email.toLowerCase().contains(q)) {
          result.add((gym: gd.gym, user: m.user));
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Members')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(_error!),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final items = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search members…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        })
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_gymData.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  FilterChip(
                    label: const Text('All gyms'),
                    selected: _filterGymId == null,
                    onSelected: (_) => setState(() => _filterGymId = null),
                  ),
                  for (final gd in _gymData) ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(gd.gym.name),
                      selected: _filterGymId == gd.gym.id,
                      onSelected: (_) =>
                          setState(() => _filterGymId = gd.gym.id),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No members found'))
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(item.user.name.isNotEmpty
                                ? item.user.name[0].toUpperCase()
                                : '?'),
                          ),
                          title: Text(item.user.fullName),
                          subtitle:
                              Text('${item.user.email}  ·  ${item.gym.name}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GymMembersPage(
                                    gymId: item.gym.id,
                                    gymName: item.gym.name),
                              ),
                            );
                            _load();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
