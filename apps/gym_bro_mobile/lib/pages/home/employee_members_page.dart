import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../gym_members_page.dart';

/// Members tab for both the employee and employee-trainer roles.
/// Lists every gym the user is linked to, with member counts.
/// Tapping a gym opens the full GymMembersPage (add / remove members).
class EmployeeMembersPage extends StatefulWidget {
  const EmployeeMembersPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<EmployeeMembersPage> createState() => _EmployeeMembersPageState();
}

class _EmployeeMembersPageState extends State<EmployeeMembersPage> {
  final _api = ApiService();

  List<({String gymId, String gymName, int memberCount})> _gyms = [];
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

      // Fetch the right staff records based on role.
      final List<Map<String, dynamic>> staffRecords =
          widget.profile.role == UserRole.employeeTrainer
              ? await _api.getEmployeeTrainers(token,
                  userId: widget.profile.id)
              : await _api.getEmployees(token, userId: widget.profile.id);

      final gymIds =
          staffRecords.map((r) => r['gym_id'] as String).toSet();

      if (gymIds.isEmpty) {
        if (mounted) setState(() { _gyms = []; _loading = false; });
        return;
      }

      // Fetch each linked gym by ID (getBusinesses only returns owned businesses).
      final gymList = await Future.wait(
        gymIds.map((id) => _api.getBusiness(token, id)),
      );
      final linkedGyms = gymList.where((b) => b.type == 'gym').toList();

      final memberLists = await Future.wait(
        linkedGyms.map((g) => _api.getMembers(token, gymId: g.id)),
      );

      if (mounted) {
        setState(() {
          _gyms = List.generate(linkedGyms.length, (i) {
            final b = linkedGyms[i];
            return (
              gymId: b.id,
              gymName: b.name,
              memberCount: memberLists[i].length,
            );
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
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

    if (_gyms.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fitness_center_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      const Text('Not assigned to any gym yet'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _gyms.length,
        itemBuilder: (_, i) {
          final entry = _gyms[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Icon(Icons.fitness_center,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer),
              ),
              title: Text(entry.gymName),
              subtitle: Text(
                  '${entry.memberCount} member${entry.memberCount == 1 ? '' : 's'}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GymMembersPage(
                        gymId: entry.gymId, gymName: entry.gymName),
                  ),
                );
                _load(); // refresh counts after returning
              },
            ),
          );
        },
      ),
    );
  }
}
