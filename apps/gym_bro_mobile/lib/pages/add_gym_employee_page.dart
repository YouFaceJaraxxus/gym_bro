import 'package:flutter/material.dart';
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

  // ── form fields ───────────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  String _employeeType = 'employee';

  // ── existing employee emails for duplicate check ───────────────────────────
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
      final results = await Future.wait([
        _api.getEmployees(token, gymId: widget.gymId),
        _api.getEmployeeTrainers(token, gymId: widget.gymId),
      ]);
      final emails = <String>{};
      for (final row in [...results[0], ...results[1]]) {
        final e = row['email'] as String?;
        if (e != null) emails.add(e.toLowerCase());
      }
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

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.addEmployee(
        token,
        email: _emailCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        gymId: widget.gymId,
        employeeType: _employeeType,
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
      appBar: AppBar(title: const Text('Add Employee')),
      body: _loadingEmails
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Email ─────────────────────────────────────────────────
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: const OutlineInputBorder(),
                      errorText: isDuplicate ? 'Email already in use' : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Name fields ───────────────────────────────────────────
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
                  const SizedBox(height: 20),

                  // ── Role ──────────────────────────────────────────────────
                  Text('Role', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'employee',
                          label: Text('Employee'),
                          icon: Icon(Icons.badge_outlined)),
                      ButtonSegment(
                          value: 'employee_trainer',
                          label: Text('Emp. Trainer'),
                          icon: Icon(Icons.fitness_center)),
                    ],
                    selected: {_employeeType},
                    onSelectionChanged: (s) =>
                        setState(() => _employeeType = s.first),
                  ),
                  const SizedBox(height: 24),

                  // ── Add button ────────────────────────────────────────────
                  FilledButton(
                    onPressed: _canSubmit ? _add : null,
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
                        : const Text('Add'),
                  ),
                  if (isDuplicate) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Email already in use',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.error, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
