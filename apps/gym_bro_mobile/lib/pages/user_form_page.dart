import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/password_form_field.dart';

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

  /// A super user editing someone else (who isn't a super user) can sign in
  /// as them for support.
  bool get _canImpersonate {
    final me = AuthManager.instance.profile;
    final target = widget.user;
    return target != null &&
        me != null &&
        me.role == UserRole.superUser &&
        !AuthManager.instance.isImpersonating &&
        target.id != me.id &&
        target.role != UserRole.superUser;
  }

  Future<void> _impersonate() async {
    final target = widget.user!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.admin_panel_settings_outlined),
        title: Text(ctx.l10n.shellImpersonateTitle(target.fullName)),
        content: Text(ctx.l10n.shellImpersonateBody(target.email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.shellImpersonateConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final session = await _api.impersonate(token, target.id);
      await AuthManager.instance.startImpersonation(session);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
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
          'role': _role.apiValue,
        });
      } else {
        await _api.createUser(
          token,
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          username: _usernameCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          role: _role.apiValue,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.shellEditUserTitle : l10n.shellNewUserTitle,
        ),
        actions: [
          if (_canImpersonate)
            IconButton(
              icon: const Icon(Icons.login),
              tooltip: l10n.shellSignInAsThisUser,
              onPressed: _loading ? null : _impersonate,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: l10n.shellAuthFirstName),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.commonRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameCtrl,
                decoration: InputDecoration(labelText: l10n.shellAuthLastName),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.commonRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameCtrl,
                decoration: InputDecoration(labelText: l10n.shellAuthUsername),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.commonRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: InputDecoration(labelText: l10n.shellAuthEmail),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@'))
                    ? l10n.shellAuthInvalidEmail
                    : null,
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                PasswordFormField(
                  controller: _passwordCtrl,
                  labelText: l10n.shellAuthPassword,
                  validator: (v) => (v == null || v.length < 6)
                      ? l10n.shellAuthPasswordMin(6)
                      : null,
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                key: ValueKey(_role),
                initialValue: _role,
                decoration: InputDecoration(labelText: l10n.shellRole),
                items: [
                  for (final role in UserRole.values)
                    DropdownMenuItem(
                      value: role,
                      child: Text(role.label(l10n)),
                    ),
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
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: l10n.commonLoading,
                        ),
                      )
                    : Text(
                        _isEditing
                            ? l10n.shellSaveChanges
                            : l10n.shellCreateUser,
                      ),
              ),
              if (_canImpersonate) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _impersonate,
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: Text(l10n.shellSignInAsThisUser),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
