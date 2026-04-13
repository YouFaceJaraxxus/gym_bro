import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../gym_members_page.dart';

class OwnerMembersPage extends StatefulWidget {
  const OwnerMembersPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<OwnerMembersPage> createState() => _OwnerMembersPageState();
}

class _OwnerMembersPageState extends State<OwnerMembersPage> {
  final _api = ApiService();

  // Each entry: {gymId, gymName, memberCount}
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

      // 1. Get all gym-owner records for this user.
      final ownerRecords = await _api.getGymOwners(
          token, userId: widget.profile.id);
      final gymIds =
          ownerRecords.map((r) => r['gym_id'] as String).toSet();

      if (gymIds.isEmpty) {
        if (mounted) setState(() { _gyms = []; _loading = false; });
        return;
      }

      // 2. Fetch all businesses and filter to owned gyms.
      final allBusinesses = await _api.getBusinesses(token);
      final ownedGyms = allBusinesses
          .where((b) => gymIds.contains(b.id) && b.type == 'gym')
          .toList();

      // 3. Fetch member counts in parallel.
      final memberLists = await Future.wait(
        ownedGyms.map(
            (g) => _api.getMembers(token, gymId: g.id)),
      );

      if (mounted) {
        setState(() {
          _gyms = List.generate(ownedGyms.length, (i) {
            final b = ownedGyms[i];
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

    if (_gyms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text('No gyms owned yet'),
            const SizedBox(height: 8),
            Text(
              'Create a gym in the Businesses tab first.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
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
                      gymId: entry.gymId,
                      gymName: entry.gymName),
                ),
              );
              _load(); // refresh counts after returning
            },
          ),
        );
      },
    );
  }
}
