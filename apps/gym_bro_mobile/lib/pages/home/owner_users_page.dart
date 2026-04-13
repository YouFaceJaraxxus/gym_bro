import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../user_form_page.dart';

class OwnerUsersPage extends StatefulWidget {
  const OwnerUsersPage({super.key});

  @override
  State<OwnerUsersPage> createState() => _OwnerUsersPageState();
}

class _OwnerUsersPageState extends State<OwnerUsersPage> {
  final _api = ApiService();
  List<UserProfile> _users = [];
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
      final users = await _api.getUsers(token);
      if (mounted) {
        setState(() {
          _users = users;
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

  Future<void> _openForm({UserProfile? user}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => UserFormPage(user: user)),
    );
    if (saved == true) _load();
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

    return Stack(
      children: [
        _users.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.manage_accounts_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    const Text('No users yet'),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, top: 16, bottom: 88),
                itemCount: _users.length,
                itemBuilder: (_, i) => _UserTile(
                  user: _users[i],
                  onEdit: () => _openForm(user: _users[i]),
                ),
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add User'),
          ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onEdit});

  final UserProfile user;
  final VoidCallback onEdit;

  Color _roleColor(BuildContext context, UserRole role) {
    final cs = Theme.of(context).colorScheme;
    return switch (role) {
      UserRole.owner => cs.primaryContainer,
      UserRole.superUser => cs.errorContainer,
      _ => cs.secondaryContainer,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
        ),
        title: Text(user.fullName),
        subtitle: Text(user.email),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(user.role.displayName),
              backgroundColor: _roleColor(context, user.role),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
          ],
        ),
      ),
    );
  }
}
