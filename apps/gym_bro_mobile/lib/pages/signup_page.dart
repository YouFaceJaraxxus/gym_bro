import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../services/auth_service.dart';
import '../widgets/google_sign_in_button.dart';
import 'verify_invite_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  String? _error;
  bool _emailTaken = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _emailTaken = false;
    });
    final email = _emailCtrl.text.trim();
    try {
      await _authService.signup(
        email: email,
        password: _passwordCtrl.text,
        username: _usernameCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/check-email');
    } on SignupException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'invite_pending':
          await _onInvitePending(email);
        case 'email_taken':
          setState(() {
            _emailTaken = true;
            _error = context.l10n.shellSignupEmailTaken;
          });
        default:
          setState(() => _error = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The email was invited by a gym/shop but never activated. The API has
  /// re-sent the invite email; send the user to enter its code.
  Future<void> _onInvitePending(String email) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.shellSignupPendingInviteTitle),
        content: Text(ctx.l10n.shellSignupPendingInviteBody(email)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.shellSignupEnterCode),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VerifyInvitePage(initialEmail: email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.shellCreateAccount)),
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
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.commonRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameCtrl,
                decoration: InputDecoration(labelText: l10n.shellAuthLastName),
                textCapitalization: TextCapitalization.words,
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                decoration: InputDecoration(labelText: l10n.shellAuthPassword),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6)
                    ? l10n.shellAuthPasswordMin(6)
                    : null,
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (_emailTaken)
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () =>
                              Navigator.pushReplacementNamed(context, '/login'),
                          child: Text(l10n.shellLogInInstead),
                        ),
                    ],
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
                    : Text(l10n.shellSignUp),
              ),
              GoogleSignInButton(enabled: !_loading),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: Text(l10n.shellHaveAccountLogIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
