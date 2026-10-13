import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:flutter/services.dart';
import '../services/auth_manager.dart';
import '../services/auth_service.dart';

class VerifyInvitePage extends StatefulWidget {
  const VerifyInvitePage({super.key, this.initialEmail});

  /// Prefills the email field (e.g. when coming from signup with a pending
  /// invite).
  final String? initialEmail;

  @override
  State<VerifyInvitePage> createState() => _VerifyInvitePageState();
}

class _VerifyInvitePageState extends State<VerifyInvitePage> {
  final _formKey = GlobalKey<FormState>();
  late final _emailCtrl = TextEditingController(text: widget.initialEmail);
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _authService.verifyInvite(
        email: _emailCtrl.text.trim(),
        token: _codeCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      await AuthManager.instance.setSession(
        data,
        profileData: data['profile'] as Map<String, dynamic>?,
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
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
      appBar: AppBar(title: Text(l10n.shellActivateInviteTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.shellActivateInviteIntro,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // ── Email ─────────────────────────────────────────────────────
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.shellAuthEmail),
                validator: (v) => (v == null || !v.contains('@'))
                    ? l10n.shellAuthInvalidEmail
                    : null,
              ),
              const SizedBox(height: 12),

              // ── OTP code ──────────────────────────────────────────────────
              TextFormField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: l10n.shellInviteCode,
                  hintText: l10n.shellInviteCodeHint,
                  counterText: '',
                ),
                validator: (v) => (v == null || v.length != 6)
                    ? l10n.shellInviteCodeInvalid
                    : null,
              ),
              const SizedBox(height: 12),

              // ── New password ──────────────────────────────────────────────
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: l10n.shellNewPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip: _obscurePassword
                        ? l10n.shellShowPassword
                        : l10n.shellHidePassword,
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? l10n.shellAuthPasswordMin(6)
                    : null,
              ),
              const SizedBox(height: 12),

              // ── Confirm password ──────────────────────────────────────────
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: l10n.shellConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip: _obscureConfirm
                        ? l10n.shellShowPassword
                        : l10n.shellHidePassword,
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) => v != _passwordCtrl.text
                    ? l10n.shellPasswordsDontMatch
                    : null,
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
                    : Text(l10n.shellActivateAccount),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.commonBack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
