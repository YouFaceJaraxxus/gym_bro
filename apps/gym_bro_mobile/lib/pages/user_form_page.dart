import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

class UserFormPage extends StatefulWidget {
  const UserFormPage({super.key, this.user});

  /// Null = create mode, non-null = edit mode.
  final UserProfile? user;

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;
  final _passwordCtrl = TextEditingController();

  late UserRole _role;
  bool _loading = false;
  String? _error;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u?.name ?? '');
    _lastNameCtrl = TextEditingController(text: u?.lastName ?? '');
    _usernameCtrl = TextEditingController(text: u?.username ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _role = u?.role ?? UserRole.member;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _roleToString(UserRole role) => switch (role) {
        UserRole.owner => 'owner',
        UserRole.trainer => 'trainer',
        UserRole.employee => 'employee',
        UserRole.employeeTrainer => 'employee_trainer',
        UserRole.member => 'member',
        UserRole.superUser => 'super_user',
      };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await AuthManager.instance.getValidToken();

      if (_isEditing) {
        await _api.updateUser(token, widget.user!.id, {
          'name': _nameCtrl.text.trim(),
          'last_name': _lastNameCtrl.text.trim(),
          'username': _usernameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'role': _roleToString(_role),
        });
      } else {
        await _api.createUser(
          token,
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          username: _usernameCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          role: _roleToString(_role),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(_isEditing ? 'Edit User' : 'New User')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'First Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Last Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Username'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Minimum 6 characters'
                      : null,
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                key: ValueKey(_role),
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final role in UserRole.values)
                    DropdownMenuItem(
                        value: role, child: Text(role.displayName)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _role = v);
                },
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error),
                  ),
                ),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEditing ? 'Save Changes' : 'Create User'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
