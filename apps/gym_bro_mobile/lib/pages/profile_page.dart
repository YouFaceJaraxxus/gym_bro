import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/image_upload_field.dart';
import 'progress/progress_page.dart';
import 'settings_page.dart';
import 'shop/my_orders_page.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.shellProfileUpdated)));
    }
  }

  Future<void> _logout() async {
    // While impersonating, logging out returns to the admin's own account.
    final stillSignedIn = await AuthManager.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      stillSignedIn ? '/home' : '/signup',
      (_) => false,
    );
  }

  void _open(Widget page) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
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
            Text(
              _profile.fullName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(_profile.email, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Chip(
              label: Text(_profile.role.label(l10n)),
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
                    decoration: InputDecoration(
                      labelText: l10n.shellAuthFirstName,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.commonRequired
                        : null,
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastNameCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.shellAuthLastName,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.commonRequired
                        : null,
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _profile.username,
                    decoration: InputDecoration(
                      labelText: l10n.shellAuthUsername,
                    ),
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
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: l10n.commonLoading,
                            ),
                          )
                        : Text(l10n.shellSaveChanges),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: Text(l10n.shellMyProgress),
              subtitle: Text(l10n.shellMyProgressSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(const ProgressPage()),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l10n.shellMyOrders),
              subtitle: Text(l10n.shellMyOrdersSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(const MyOrdersPage()),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.shellSettings),
              subtitle: Text(l10n.shellSettingsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(const SettingsPage()),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.logout, color: cs.error),
              title: Text(
                AuthManager.instance.isImpersonating
                    ? l10n.shellHomeReturnToAdmin
                    : l10n.shellHomeLogOut,
                style: TextStyle(color: cs.error),
              ),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}
