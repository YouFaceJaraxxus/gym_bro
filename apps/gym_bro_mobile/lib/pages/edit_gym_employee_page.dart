import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
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

  String _roleLabel(AppLocalizations l10n, String type) =>
      type == 'employee_trainer'
          ? l10n.businessGymRoleEmployeeTrainer
          : l10n.businessGymRoleEmployee;

  Future<void> _changeRole(String newType) async {
    if (newType == _staffType) return;
    final l10n = context.l10n;
    final label = _roleLabel(l10n, newType);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.businessGymChangeRoleTitle),
        content: Text(
          l10n.businessGymChangeRoleMessage(
            widget.user.fullName,
            label,
            widget.gymName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.businessGymChange),
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
      ).showSnackBar(
        SnackBar(content: Text(l10n.businessGymRoleChangedTo(label))),
      );
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
          SnackBar(
            content: Text(context.l10n.businessGymInviteResentSuccess),
          ),
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
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.businessGymRemoveStaffTitle),
        content: Text(
          l10n.businessGymRemoveFromGymMessage(
            widget.user.fullName,
            widget.gymName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.businessGymRemove),
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
    final l10n = context.l10n;
    final typeLabel = _roleLabel(l10n, _staffType);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _roleChanged ? 'changed' : null);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.businessGymEditEmployee)),
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
                    title: Text(l10n.businessGymEmail),
                    subtitle: Text(widget.user.email),
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    leading: const Icon(Icons.alternate_email),
                    title: Text(l10n.businessGymUsername),
                    subtitle: Text(widget.user.username),
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: Text(l10n.businessGymGym),
                    subtitle: Text(widget.gymName),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Role ───────────────────────────────────────────────────────────
            Text(l10n.businessGymRole,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'employee',
                  label: Text(l10n.businessGymRoleEmployee),
                  icon: const Icon(Icons.badge_outlined),
                ),
                ButtonSegment(
                  value: 'employee_trainer',
                  label: Text(l10n.businessGymRoleEmployeeTrainer),
                  icon: const Icon(Icons.sports_gymnastics_outlined),
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
              label: Text(l10n.businessGymResendInvite),
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
              label: Text(
                l10n.businessGymRemoveFromGym,
                style: TextStyle(color: cs.error),
              ),
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
