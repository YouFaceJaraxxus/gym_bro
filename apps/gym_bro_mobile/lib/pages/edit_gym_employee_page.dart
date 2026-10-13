import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

/// Shown when tapping "Edit Employee" from the staff list.
/// Displays the employee's details and provides actions: change role
/// (Employee ↔ Employee Trainer), resend invite, remove.
///
/// Pops `'removed'` after removal, `'changed'` if the role was changed.
class EditGymEmployeePage extends StatefulWidget {
  const EditGymEmployeePage({
    super.key,
    required this.staffId,
    required this.staffType, // 'employee' or 'employee_trainer'
    required this.user,
    required this.gymName,
    required this.gymId,
  });

  final String staffId;
  final String staffType;
  final UserProfile user;
  final String gymName;
  final String gymId;

  @override
  State<EditGymEmployeePage> createState() => _EditGymEmployeePageState();
}

class _EditGymEmployeePageState extends State<EditGymEmployeePage> {
  final _api = ApiService();
  bool _resending = false;
  bool _removing = false;
  bool _changingRole = false;
  bool _roleChanged = false;

  late String _staffId = widget.staffId;
  late String _staffType = widget.staffType;

  bool get _busy => _resending || _removing || _changingRole;

  Future<void> _changeRole(String newType) async {
    if (newType == _staffType) return;
    final label = newType == 'employee_trainer'
        ? 'Employee Trainer'
        : 'Employee';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change role?'),
        content: Text(
          'Make ${widget.user.fullName} an $label at ${widget.gymName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _changingRole = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final row = await _api.changeEmployeeRole(
        token,
        userId: widget.user.id,
        gymId: widget.gymId,
        employeeType: newType,
      );
      if (!mounted) return;
      setState(() {
        _staffId = row['id'] as String? ?? _staffId;
        _staffType = row['employee_type'] as String? ?? newType;
        _roleChanged = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Role changed to $label')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _changingRole = false);
    }
  }

  Future<void> _resendInvite() async {
    setState(() => _resending = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.resendInvite(token, widget.user.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite resent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove staff member?'),
        content: Text(
          'This will remove ${widget.user.fullName} from ${widget.gymName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _removing = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      if (_staffType == 'employee') {
        await _api.removeEmployee(token, _staffId);
      } else {
        await _api.removeEmployeeTrainer(token, _staffId);
      }
      if (mounted) Navigator.pop(context, 'removed');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _removing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typeLabel = _staffType == 'employee_trainer'
        ? 'Employee / Trainer'
        : 'Employee';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _roleChanged ? 'changed' : null);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit Employee')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Avatar + name ──────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    child: Text(
                      widget.user.name.isNotEmpty
                          ? widget.user.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.user.fullName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    typeLabel,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Info card ──────────────────────────────────────────────────────
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(widget.user.email),
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    leading: const Icon(Icons.alternate_email),
                    title: const Text('Username'),
                    subtitle: Text(widget.user.username),
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: const Text('Gym'),
                    subtitle: Text(widget.gymName),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Role ───────────────────────────────────────────────────────────
            Text('Role', style: Theme.of(context).textTheme.titleSmall),
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
                  label: Text('Employee Trainer'),
                  icon: Icon(Icons.sports_gymnastics_outlined),
                ),
              ],
              selected: {_staffType},
              onSelectionChanged: _busy
                  ? null
                  : (sel) => _changeRole(sel.first),
            ),
            if (_changingRole)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),

            const SizedBox(height: 24),

            // ── Resend invite ──────────────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: _busy ? null : _resendInvite,
              icon: _resending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mark_email_unread_outlined),
              label: const Text('Resend Invite'),
            ),

            const SizedBox(height: 12),

            // ── Remove ─────────────────────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: _busy ? null : _remove,
              icon: _removing
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.error,
                      ),
                    )
                  : Icon(Icons.person_remove_outlined, color: cs.error),
              label: Text('Remove from Gym', style: TextStyle(color: cs.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
