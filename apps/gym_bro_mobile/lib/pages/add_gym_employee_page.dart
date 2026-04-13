import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

class AddGymEmployeePage extends StatefulWidget {
  const AddGymEmployeePage({super.key, required this.gymId});

  final String gymId;

  @override
  State<AddGymEmployeePage> createState() => _AddGymEmployeePageState();
}

class _AddGymEmployeePageState extends State<AddGymEmployeePage> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();

  List<UserProfile> _available = [];
  List<UserProfile> _filtered = [];
  bool _loading = true;
  String? _error;
  String? _adding; // user id currently being added

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait([
        _api.getUsers(token),
        _api.getEmployees(token, gymId: widget.gymId),
      ]);
      final allUsers = results[0] as List<UserProfile>;
      final employeeRows = results[1] as List<Map<String, dynamic>>;
      final employeeUserIds =
          employeeRows.map((r) => r['user_id'] as String).toSet();

      if (mounted) {
        setState(() {
          _available = allUsers
              .where((u) => !employeeUserIds.contains(u.id))
              .toList();
          _filtered = List.of(_available);
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

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(_available)
          : _available.where((u) {
              return u.fullName.toLowerCase().contains(q) ||
                  u.email.toLowerCase().contains(q) ||
                  u.username.toLowerCase().contains(q);
            }).toList();
    });
  }

  Future<void> _add(UserProfile user) async {
    setState(() => _adding = user.id);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.addEmployee(token, user.id, widget.gymId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _adding = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Employee')),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, email or username',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filter();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 12),
                            FilledButton(
                                onPressed: _load,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Text(
                              _searchCtrl.text.isEmpty
                                  ? 'All users are already employees'
                                  : 'No matching users',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final u = _filtered[i];
                              final isAdding = _adding == u.id;
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(u.name.isNotEmpty
                                      ? u.name[0].toUpperCase()
                                      : '?'),
                                ),
                                title: Text(u.fullName),
                                subtitle: Text(u.email),
                                trailing: isAdding
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : FilledButton.tonal(
                                        onPressed: _adding != null
                                            ? null
                                            : () => _add(u),
                                        child: const Text('Add'),
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
