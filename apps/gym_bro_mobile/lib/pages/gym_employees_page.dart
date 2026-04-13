import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'add_gym_employee_page.dart';

class GymEmployeesPage extends StatefulWidget {
  const GymEmployeesPage(
      {super.key, required this.gymId, required this.gymName});

  final String gymId;
  final String gymName;

  @override
  State<GymEmployeesPage> createState() => _GymEmployeesPageState();
}

class _GymEmployeesPageState extends State<GymEmployeesPage> {
  final _api = ApiService();

  List<({String employeeId, UserProfile user})> _employees = [];
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
        _api.getUsers(token),
      ]);
      final employeeRows = results[0] as List<Map<String, dynamic>>;
      final allUsers = results[1] as List<UserProfile>;
      final userMap = {for (final u in allUsers) u.id: u};

      if (mounted) {
        setState(() {
          _employees = employeeRows
              .map((r) {
                final u = userMap[r['user_id'] as String];
                if (u == null) return null;
                return (employeeId: r['id'] as String, user: u);
              })
              .whereType<({String employeeId, UserProfile user})>()
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

  Future<void> _removeEmployee(String employeeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove employee?'),
        content:
            const Text('This will remove the employee from this gym.'),
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
      await _api.removeEmployee(token, employeeId);
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
    return Scaffold(
      appBar: AppBar(title: Text('${widget.gymName} — Staff')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AddGymEmployeePage(gymId: widget.gymId),
            ),
          );
          if (added == true) _load();
        },
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Employee'),
      ),
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

  Widget _buildList() {
    if (_employees.isEmpty) {
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
                      Icon(Icons.badge_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      const Text('No employees yet'),
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
        padding:
            const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
        itemCount: _employees.length,
        itemBuilder: (_, i) {
          final entry = _employees[i];
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
                onPressed: () => _removeEmployee(entry.employeeId),
              ),
            ),
          );
        },
      ),
    );
  }
}
