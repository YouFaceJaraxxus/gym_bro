import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

class InviteGymMemberPage extends StatefulWidget {
  const InviteGymMemberPage({super.key, required this.gymId});

  final String gymId;

  @override
  State<InviteGymMemberPage> createState() => _InviteGymMemberPageState();
}

class _InviteGymMemberPageState extends State<InviteGymMemberPage> {
  final _api = ApiService();

  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  Set<String> _existingEmails = {};
  bool _loadingEmails = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(() => setState(() {}));
    _loadExistingEmails();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingEmails() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final memberRows = await _api.getMembers(token, gymId: widget.gymId);
      // member rows don't embed email; fetch users to cross-reference
      final allUsers = await _api.getUsers(token);
      final memberUserIds = memberRows.map((r) => r['user_id'] as String).toSet();
      final emails = allUsers
          .where((u) => memberUserIds.contains(u.id))
          .map((u) => u.email.toLowerCase())
          .toSet();
      if (mounted) setState(() { _existingEmails = emails; _loadingEmails = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingEmails = false);
    }
  }

  bool get _emailDuplicate =>
      _existingEmails.contains(_emailCtrl.text.trim().toLowerCase());

  bool get _canSubmit =>
      !_loadingEmails &&
      !_adding &&
      !_emailDuplicate &&
      _emailCtrl.text.trim().isNotEmpty &&
      _nameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      _usernameCtrl.text.trim().isNotEmpty;

  Future<void> _invite() async {
    setState(() => _adding = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.inviteMember(
        token,
        email: _emailCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        gymId: widget.gymId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _adding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDuplicate = _emailDuplicate;

    return Scaffold(
      appBar: AppBar(title: const Text('Invite Member')),
      body: _loadingEmails
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: const OutlineInputBorder(),
                      errorText: isDuplicate ? 'Already a member' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'First name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lastNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Last name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _canSubmit ? _invite : null,
                    style: isDuplicate
                        ? FilledButton.styleFrom(
                            backgroundColor: cs.surfaceContainerHighest,
                            foregroundColor: cs.onSurfaceVariant,
                          )
                        : null,
                    child: _adding
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Send Invite'),
                  ),
                ],
              ),
            ),
    );
  }
}
