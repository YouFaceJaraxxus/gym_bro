import 'package:flutter/material.dart';
import '../models/membership.dart';
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
    required this.gymId,
  });

  final String memberId;
  final UserProfile user;
  final String gymName;
  final String gymId;

  @override
  State<EditGymMemberPage> createState() => _EditGymMemberPageState();
}

class _EditGymMemberPageState extends State<EditGymMemberPage> {
  final _api = ApiService();
  bool _resending = false;
  bool _removing = false;

  List<GymMembershipType> _types = [];
  Membership? _activeMembership;
  bool _loadingMembership = true;

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    setState(() => _loadingMembership = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait([
        _api.getGymMembershipTypes(token, gymId: widget.gymId, isActive: true),
        _api.getMemberships(token, userId: widget.user.id),
      ]);
      final types = results[0] as List<GymMembershipType>;
      final memberships = results[1] as List<Membership>;
      memberships.sort((a, b) => b.fromDate.compareTo(a.fromDate));
      if (mounted) {
        setState(() {
          _types = types;
          _activeMembership = memberships.where((m) => m.isActive).firstOrNull ??
              memberships.firstOrNull;
          _loadingMembership = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMembership = false);
    }
  }

  Future<void> _assignMembership() async {
    if (_types.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This gym has no membership types yet — add one first.')),
      );
      return;
    }
    GymMembershipType selected = _types.first;
    var months = 1;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Assign Membership'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<GymMembershipType>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Membership type'),
                items: [
                  for (final t in _types)
                    DropdownMenuItem(
                      value: t,
                      child: Text('${t.name} (\$${t.monthlyCost.toStringAsFixed(2)}/mo)'),
                    ),
                ],
                onChanged: (v) => setDialogState(() => selected = v ?? selected),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: months,
                decoration: const InputDecoration(labelText: 'Duration'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 month')),
                  DropdownMenuItem(value: 3, child: Text('3 months')),
                  DropdownMenuItem(value: 6, child: Text('6 months')),
                  DropdownMenuItem(value: 12, child: Text('12 months')),
                ],
                onChanged: (v) => setDialogState(() => months = v ?? months),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Assign')),
          ],
        ),
      ),
    );
    if (saved != true) return;

    try {
      final token = await AuthManager.instance.getValidToken();
      final from = DateTime.now();
      final to = DateTime(from.year, from.month + months, from.day);
      final membership = await _api.createMembership(token, {
        'user_id': widget.user.id,
        'current_membership_type_id': selected.id,
        'from_date': from.toIso8601String().substring(0, 10),
        'to_date': to.toIso8601String().substring(0, 10),
        'is_active': true,
      });
      await _api.createMembershipInvoice(token, {
        'membership_id': membership.id,
        'membership_type_id': selected.id,
        'amount': selected.monthlyCost * months,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membership assigned')),
        );
      }
      _loadMembership();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
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

          // ── Membership card ───────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Membership', style: Theme.of(context).textTheme.titleSmall),
                      TextButton(
                        onPressed: _assignMembership,
                        child: Text(_activeMembership == null ? 'Assign' : 'Renew'),
                      ),
                    ],
                  ),
                  if (_loadingMembership)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    )
                  else if (_activeMembership == null)
                    Text('No membership on file',
                        style: TextStyle(color: cs.onSurfaceVariant))
                  else
                    Row(
                      children: [
                        Icon(
                          _activeMembership!.isActive && !_activeMembership!.isExpired
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          size: 18,
                          color: _activeMembership!.isActive && !_activeMembership!.isExpired
                              ? Colors.green
                              : cs.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Valid until ${_activeMembership!.toDate.day}/${_activeMembership!.toDate.month}/${_activeMembership!.toDate.year}',
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

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
