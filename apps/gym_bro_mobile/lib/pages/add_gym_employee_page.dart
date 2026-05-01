import 'package:flutter/material.dart';
import '../models/user_search_result.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/user_search_field.dart';

class AddGymEmployeePage extends StatefulWidget {
  const AddGymEmployeePage({super.key, required this.gymId});

  final String gymId;

  @override
  State<AddGymEmployeePage> createState() => _AddGymEmployeePageState();
}

class _AddGymEmployeePageState extends State<AddGymEmployeePage> {
  final _api = ApiService();

  String _employeeType = 'employee';

  // ── existing employee ids for exclusion / duplicate check ────────────────
  Set<String> _existingUserIds = {};
  Set<String> _existingEmails = {};
  bool _loadingExisting = true;

  // ── search-and-add state ─────────────────────────────────────────────────
  String? _addingUserId;

  // ── invite-new-user form ─────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _inviting = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(() => setState(() {}));
    _loadExisting();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait([
        _api.getEmployees(token, gymId: widget.gymId),
        _api.getEmployeeTrainers(token, gymId: widget.gymId),
      ]);
      final userIds = <String>{};
      final emails = <String>{};
      for (final row in [...results[0], ...results[1]]) {
        final uid = row['user_id'] as String?;
        final em = row['email'] as String?;
        if (uid != null) userIds.add(uid);
        if (em != null) emails.add(em.toLowerCase());
      }
      if (mounted) {
        setState(() {
          _existingUserIds = userIds;
          _existingEmails = emails;
          _loadingExisting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  Future<void> _addExisting(UserSearchResult user) async {
    setState(() => _addingUserId = user.id);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.addEmployee(
        token,
        userId: user.id,
        gymId: widget.gymId,
        employeeType: _employeeType,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _addingUserId = null);
      }
    }
  }

  bool get _emailDuplicate =>
      _existingEmails.contains(_emailCtrl.text.trim().toLowerCase());

  bool get _canInvite =>
      !_loadingExisting &&
      !_inviting &&
      !_emailDuplicate &&
      _emailCtrl.text.trim().isNotEmpty &&
      _nameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      _usernameCtrl.text.trim().isNotEmpty;

  Future<void> _invite() async {
    setState(() => _inviting = true);
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
        setState(() => _inviting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDuplicate = _emailDuplicate;
    final busy = _addingUserId != null || _inviting;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Employee')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Role selector (applies to both search and invite paths) ───
            Text('Role', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'employee',
                  label: Text('Employee'),
                  icon: Icon(Icons.badge_outlined),
                ),
                ButtonSegment(
                  value: 'employee_trainer',
                  label: Text('Emp. Trainer'),
                  icon: Icon(Icons.fitness_center),
                ),
              ],
              selected: {_employeeType},
              onSelectionChanged:
                  busy ? null : (s) => setState(() => _employeeType = s.first),
            ),
            const SizedBox(height: 20),

            // ── Search existing users ─────────────────────────────────────
            UserSearchField(
              excludeUserIds: _existingUserIds,
              enabled: !busy,
              addingUserId: _addingUserId,
              onSelect: _addExisting,
            ),
            const SizedBox(height: 16),

            // ── Invite new user ───────────────────────────────────────────
            ExpansionTile(
              title: const Text("Can't find them? Invite a new user"),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: _emailCtrl,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: const OutlineInputBorder(),
                    errorText: isDuplicate ? 'Already an employee at this gym' : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'First name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lastNameCtrl,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Last name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameCtrl,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _canInvite ? _invite : null,
                  child: _inviting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Invite & Add'),
                ),
                if (isDuplicate) ...[
                  const SizedBox(height: 8),
                  Text(
                    'This email is already employed at this gym',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
