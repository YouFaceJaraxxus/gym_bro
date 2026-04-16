import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

/// Shown when tapping "Edit Employee" from the staff list.
/// Displays the employee's details and provides actions: resend invite, remove.
class EditGymEmployeePage extends StatefulWidget {
  const EditGymEmployeePage({
    super.key,
    required this.staffId,
    required this.staffType, // 'employee' or 'employee_trainer'
    required this.user,
    required this.gymName,
  });

  final String staffId;
  final String staffType;
  final UserProfile user;
  final String gymName;

  @override
  State<EditGymEmployeePage> createState() => _EditGymEmployeePageState();
}

class _EditGymEmployeePageState extends State<EditGymEmployeePage> {
  final _api = ApiService();
  bool _resending = false;
  bool _removing = false;

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
            'This will remove ${widget.user.fullName} from ${widget.gymName}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _removing = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      if (widget.staffType == 'employee') {
        await _api.removeEmployee(token, widget.staffId);
      } else {
        await _api.removeEmployeeTrainer(token, widget.staffId);
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
    final typeLabel = widget.staffType == 'employee_trainer'
        ? 'Employee / Trainer'
        : 'Employee';

    return Scaffold(
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
                  style: TextStyle(color: cs.primary, fontWeight: FontWeight.w500),
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

          // ── Resend invite ──────────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: (_resending || _removing) ? null : _resendInvite,
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
            onPressed: (_resending || _removing) ? null : _remove,
            icon: _removing
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.error),
                  )
                : Icon(Icons.person_remove_outlined, color: cs.error),
            label: Text('Remove from Gym',
                style: TextStyle(color: cs.error)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.error),
            ),
          ),
        ],
      ),
    );
  }
}
