import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../add_gym_member_page.dart';

/// Members tab for the employee role.
/// Looks up the employee's gym then shows that gym's members inline.
class EmployeeMembersPage extends StatefulWidget {
  const EmployeeMembersPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<EmployeeMembersPage> createState() => _EmployeeMembersPageState();
}

class _EmployeeMembersPageState extends State<EmployeeMembersPage> {
  final _api = ApiService();

  String? _gymId;
  String? _gymName;
  List<({String memberId, UserProfile user})> _members = [];
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

      // Find the employee's gym assignment.
      final empRecords = await _api.getEmployees(
          token, userId: widget.profile.id);
      if (empRecords.isEmpty) {
        if (mounted) {
          setState(() {
            _gymId = null;
            _loading = false;
          });
        }
        return;
      }

      final gymId = empRecords.first['gym_id'] as String;

      // Fetch gym name + member list + user details in parallel.
      final results = await Future.wait([
        _api.getBusiness(token, gymId),
        _api.getMembers(token, gymId: gymId),
        _api.getUsers(token),
      ]);

      final business = results[0] as dynamic; // Business
      final memberRows = results[1] as List<Map<String, dynamic>>;
      final allUsers = results[2] as List<UserProfile>;
      final userMap = {for (final u in allUsers) u.id: u};

      if (mounted) {
        setState(() {
          _gymId = gymId;
          _gymName = (business as dynamic).name as String;
          _members = memberRows
              .map((r) {
                final u = userMap[r['user_id'] as String];
                if (u == null) return null;
                return (memberId: r['id'] as String, user: u);
              })
              .whereType<({String memberId, UserProfile user})>()
              .toList();
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

  Future<void> _removeMember(String memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove member?'),
        content:
            const Text('This will remove the member from this gym.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.removeMember(token, memberId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_gymId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text('Not assigned to a gym yet'),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: _members.isEmpty
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
                              Icon(Icons.people_outline,
                                  size: 48,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline),
                              const SizedBox(height: 16),
                              const Text('No members yet'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 16, bottom: 88),
                  itemCount: _members.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.fitness_center,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary),
                          const SizedBox(width: 8),
                          Text(
                            _gymName ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary),
                          ),
                        ],
                      ),
                    );
                  }
                  final entry = _members[i - 1];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(entry.user.name.isNotEmpty
                            ? entry.user.name[0].toUpperCase()
                            : '?'),
                      ),
                      title: Text(entry.user.fullName),
                      subtitle: Text(entry.user.email),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Theme.of(context).colorScheme.error,
                        tooltip: 'Remove',
                        onPressed: () =>
                            _removeMember(entry.memberId),
                      ),
                    ),
                  );
                },
              ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: () async {
              final added = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AddGymMemberPage(gymId: _gymId!),
                ),
              );
              if (added == true) _load();
            },
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add Member'),
          ),
        ),
      ],
    );
  }
}
