import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

/// Shown when tapping "Edit Member" from the members list.
/// Displays the member's details and provides actions: resend invite, remove.
class EditGymMemberPage extends StatefulWidget {
  const EditGymMemberPage({
    super.key,
    required this.memberId,
    required this.user,
    required this.gymName,
  });

  final String memberId;
  final UserProfile user;
  final String gymName;

  @override
  State<EditGymMemberPage> createState() => _EditGymMemberPageState();
}

class _EditGymMemberPageState extends State<EditGymMemberPage> {
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
        title: const Text('Remove member?'),
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
      await _api.removeMember(token, widget.memberId);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Member')),
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
                  'Member',
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
                  leading: const Icon(Icons.fitness_center_outlined),
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
            label:
                Text('Remove from Gym', style: TextStyle(color: cs.error)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.error),
            ),
          ),
        ],
      ),
    );
  }
}
