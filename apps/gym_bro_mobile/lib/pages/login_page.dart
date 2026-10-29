import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../services/auth_service.dart';
import '../services/auth_manager.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/password_form_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
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
      final data = await _authService.signin(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      await AuthManager.instance.setSession(
        data,
        profileData: data['profile'] as Map<String, dynamic>?,
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
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
      appBar: AppBar(title: Text(l10n.shellLogIn)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailCtrl,
                decoration: InputDecoration(labelText: l10n.shellAuthEmail),
                autofillHints: const [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@'))
                    ? l10n.shellAuthInvalidEmail
                    : null,
              ),
              const SizedBox(height: 12),
              PasswordFormField(
                controller: _passwordCtrl,
                labelText: l10n.shellAuthPassword,
                autofillHints: const [AutofillHints.password],
                validator: (v) =>
                    (v == null || v.isEmpty) ? l10n.commonRequired : null,
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
                    : Text(l10n.shellLogIn),
              ),
              GoogleSignInButton(enabled: !_loading),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/forgot-password'),
                child: Text(l10n.shellForgotPasswordLink),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/signup'),
                child: Text(l10n.shellNoAccountSignUp),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/verify-invite'),
                child: Text(l10n.shellHaveInviteCode),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
