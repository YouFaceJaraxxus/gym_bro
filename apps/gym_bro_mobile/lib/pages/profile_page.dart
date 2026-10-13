import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/image_upload_field.dart';
import 'typed_confirm_dialog.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.profile, this.onUpdated});

  final UserProfile profile;
  final void Function(UserProfile updated)? onUpdated;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  late UserProfile _profile;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _lastNameCtrl;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _nameCtrl = TextEditingController(text: _profile.name);
    _lastNameCtrl = TextEditingController(text: _profile.lastName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveField(Map<String, dynamic> data) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final updated = await _api.updateUser(token, _profile.id, data);
      await AuthManager.instance.updateProfile(updated);
      if (mounted) {
        setState(() {
          _profile = updated;
          _dirty = false;
        });
      }
      widget.onUpdated?.call(updated);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onAvatarUploaded(String url) => _saveField({'avatar_url': url});

  Future<void> _saveNames() async {
    if (!_formKey.currentState!.validate()) return;
    await _saveField({
      'name': _nameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
    });
    if (mounted && _error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    }
  }

  Future<void> _logout() async {
    await AuthManager.instance.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/signup');
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const TypedConfirmDialog(
        title: 'Delete account?',
        message: 'This permanently deletes your account, memberships and '
            'billing history. This cannot be undone.',
        confirmText: 'DELETE',
        actionLabel: 'Delete account',
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteUser(token, _profile.id);
      await AuthManager.instance.clear();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/signup', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        // 409 when the user still owns a gym or shop — show the API message.
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Couldn't delete account"),
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          children: [
            Center(
              child: AvatarPicker(
                imageUrl: _profile.avatarUrl,
                folder: _profile.id,
                radius: 52,
                onUploaded: _onAvatarUploaded,
              ),
            ),
            const SizedBox(height: 12),
            Text(_profile.fullName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(_profile.email, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Chip(
              label: Text(_profile.role.displayName),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 32),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'First name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastNameCtrl,
                    decoration: const InputDecoration(labelText: 'Last name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _profile.username,
                    decoration: const InputDecoration(labelText: 'Username'),
                    enabled: false,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: cs.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: (_saving || !_dirty) ? null : _saveNames,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save changes'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _saving ? null : _changePassword,
            ),
            ListTile(
              leading: Icon(Icons.logout, color: cs.error),
              title: Text('Log out', style: TextStyle(color: cs.error)),
              onTap: _logout,
            ),
            const SizedBox(height: 8),
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: cs.error),
              title: Text('Delete account', style: TextStyle(color: cs.error)),
              subtitle: const Text('Permanently remove your account'),
              onTap: _saving ? null : _deleteAccount,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Change password dialog ────────────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.changePassword(
        token,
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final toggle = IconButton(
      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
      onPressed: () => setState(() => _obscure = !_obscure),
    );
    return AlertDialog(
      title: const Text('Change password'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  suffixIcon: toggle,
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newCtrl,
                obscureText: _obscure,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscure,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
                validator: (v) =>
                    v != _newCtrl.text ? 'Passwords do not match' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: cs.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Change'),
        ),
      ],
    );
  }
}
