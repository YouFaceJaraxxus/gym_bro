import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'gym_employees_page.dart';
import 'gym_members_page.dart';

class GymDetailPage extends StatefulWidget {
  const GymDetailPage(
      {super.key, required this.gymId, required this.gymName});

  final String gymId;
  final String gymName;

  @override
  State<GymDetailPage> createState() => _GymDetailPageState();
}

class _GymDetailPageState extends State<GymDetailPage> {
  final _api = ApiService();

  List<UserProfile> _employees = [];
  List<UserProfile> _members = [];
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
        _api.getEmployees(token, gymId: widget.gymId),
        _api.getMembers(token, gymId: widget.gymId),
        _api.getUsers(token),
      ]);
      final employeeRows =
          results[0] as List<Map<String, dynamic>>;
      final memberRows =
          results[1] as List<Map<String, dynamic>>;
      final allUsers = results[2] as List<UserProfile>;
      final userMap = {for (final u in allUsers) u.id: u};

      if (mounted) {
        setState(() {
          _employees = employeeRows
              .map((r) => userMap[r['user_id'] as String])
              .whereType<UserProfile>()
              .toList();
          _members = memberRows
              .map((r) => userMap[r['user_id'] as String])
              .whereType<UserProfile>()
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.gymName)),
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
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Overview card ──────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(Icons.fitness_center,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatChip(
                            icon: Icons.people_outline,
                            label: '${_members.length} members'),
                        const SizedBox(height: 4),
                        _StatChip(
                            icon: Icons.badge_outlined,
                            label: '${_employees.length} employees'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Members section ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Members',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GymMembersPage(
                            gymId: widget.gymId,
                            gymName: widget.gymName),
                      ),
                    );
                    _load();
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_members.isEmpty)
              _EmptyHint(
                  icon: Icons.people_outline, label: 'No members yet')
            else
              for (final u in _members.take(5))
                _UserRow(user: u),
            if (_members.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${_members.length - 5} more',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                          color: Theme.of(context).colorScheme.primary),
                ),
              ),
            const SizedBox(height: 24),

            // ── Employees section ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Employees',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GymEmployeesPage(
                            gymId: widget.gymId,
                            gymName: widget.gymName),
                      ),
                    );
                    _load();
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_employees.isEmpty)
              _EmptyHint(
                  icon: Icons.badge_outlined, label: 'No employees yet')
            else
              for (final u in _employees)
                _UserRow(user: u),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16,
            color: Theme.of(context).colorScheme.onSurface),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Text(user.name.isNotEmpty
            ? user.name[0].toUpperCase()
            : '?'),
      ),
      title: Text(user.fullName),
      subtitle: Text(user.email),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }
}
