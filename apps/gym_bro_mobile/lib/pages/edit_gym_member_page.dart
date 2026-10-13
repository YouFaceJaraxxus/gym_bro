import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/membership.dart';
import '../models/payment.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../theme.dart';
import 'member_progress_page.dart';

/// Shown when tapping "Edit Member" from the members list.
/// Displays the member's details, their memberships at this gym (assign,
/// extend, cancel, delete), a link to their progress, and actions: resend
/// invite, remove.
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

  /// Active types — offered when assigning a new membership.
  List<GymMembershipType> _types = [];

  /// Every type of this gym (incl. inactive) for labelling existing rows.
  Map<String, GymMembershipType> _typesById = {};
  List<Membership> _memberships = [];
  bool _loadingMembership = true;
  String? _membershipError;

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    setState(() {
      _loadingMembership = true;
      _membershipError = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait([
        _api.getGymMembershipTypes(token, gymId: widget.gymId),
        _api.getMemberships(token, userId: widget.user.id, gymId: widget.gymId),
      ]);
      final types = results[0] as List<GymMembershipType>;
      final typeIds = {for (final t in types) t.id};
      // Keep only this gym's memberships (in case gym_id isn't honored).
      final memberships = (results[1] as List<Membership>)
          .where((m) => typeIds.contains(m.currentMembershipTypeId))
          .toList();
      // Active first, then most recent.
      memberships.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return b.toDate.compareTo(a.toDate);
      });
      if (mounted) {
        setState(() {
          _types = types.where((t) => t.isActive).toList();
          _typesById = {for (final t in types) t.id: t};
          _memberships = memberships;
          _loadingMembership = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _membershipError = e.toString().replaceFirst('Exception: ', '');
          _loadingMembership = false;
        });
      }
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
  }

  String _date(DateTime d) => d.toIso8601String().substring(0, 10);

  /// Extends [m] by N months from its end date (or from today if it already
  /// ended), re-activates it, and issues an invoice for the extension.
  Future<void> _extend(Membership m) async {
    final l10n = context.l10n;
    final type = _typesById[m.currentMembershipTypeId];
    if (type == null) {
      _showError(l10n.businessGymMembershipTypeNotFound);
      return;
    }
    final months = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.businessGymExtendMembership),
        children: [
          for (final n in const [1, 3, 6, 12])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, n),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${l10n.businessGymPlusMonths(n)}  ·  '
                  '${_money(type.monthlyCost * n)}',
                ),
              ),
            ),
        ],
      ),
    );
    if (months == null) return;

    try {
      final token = await AuthManager.instance.getValidToken();
      final today = DateTime.now();
      final start = m.toDate.isAfter(today) ? m.toDate : today;
      final to = DateTime(start.year, start.month + months, start.day);
      await _api.updateMembership(token, m.id, {
        'to_date': _date(to),
        'is_active': true,
      });
      await _api.createMembershipInvoice(token, {
        'membership_id': m.id,
        'membership_type_id': type.id,
        'amount': type.monthlyCost * months,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(context.l10n.businessGymExtendedUntil(_fmt(to))),
          ),
        );
      }
      _loadMembership();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _cancelMembership(Membership m) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.businessGymCancelMembershipTitle),
        content: Text(
          l10n.businessGymCancelMembershipMessage(
            widget.user.fullName,
            _typeName(m),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.businessGymKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.businessGymCancelMembership),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.updateMembership(token, m.id, {'is_active': false});
      _loadMembership();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteMembership(Membership m) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.businessGymDeleteMembershipTitle),
        content: Text(l10n.businessGymDeleteMembershipMessage(_typeName(m))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonBack),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteMembership(token, m.id);
      _loadMembership();
    } catch (e) {
      _showError(e);
    }
  }

  String _typeName(Membership m) =>
      _typesById[m.currentMembershipTypeId]?.name ??
      context.l10n.businessGymMembershipFallback;

  String get _locale => Localizations.localeOf(context).toString();

  String _fmt(DateTime d) => DateFormat.yMMMd(_locale).format(d);

  // Gym currency isn't loaded on this page; keeps the previous USD default.
  String _money(double v) => formatMoney(v, 'usd', _locale);

  Future<void> _assignMembership() async {
    final l10n = context.l10n;
    if (_types.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.businessGymNoMembershipTypes)),
      );
      return;
    }
    GymMembershipType selected = _types.first;
    var months = 1;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.businessGymAssignMembership),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<GymMembershipType>(
                initialValue: selected,
                decoration: InputDecoration(
                  labelText: l10n.businessGymMembershipType,
                ),
                items: [
                  for (final t in _types)
                    DropdownMenuItem(
                      value: t,
                      child: Text(
                        l10n.businessGymTypePerMonth(
                          t.name,
                          _money(t.monthlyCost),
                        ),
                      ),
                    ),
                ],
                onChanged: (v) =>
                    setDialogState(() => selected = v ?? selected),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: months,
                decoration: InputDecoration(labelText: l10n.businessGymDuration),
                items: [
                  for (final n in const [1, 3, 6, 12])
                    DropdownMenuItem(
                      value: n,
                      child: Text(l10n.businessGymMonths(n)),
                    ),
                ],
                onChanged: (v) => setDialogState(() => months = v ?? months),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.businessGymAssign),
            ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(context.l10n.businessGymMembershipAssigned)),
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
        title: Text(l10n.businessGymRemoveMemberTitle),
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

  Widget _membershipTile(Membership m, ColorScheme cs) {
    final l10n = context.l10n;
    final valid = m.isActive && !m.isExpired;
    final status = valid
        ? l10n.businessGymStatusActive
        : m.isActive
        ? l10n.businessGymStatusExpired
        : l10n.businessGymStatusCancelled;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        valid ? Icons.check_circle_outline : Icons.error_outline,
        // Status is also spelled out in the subtitle (not color-only).
        color: valid ? context.appColors.success : cs.error,
      ),
      title: Text(_typeName(m)),
      subtitle: Text('$status · ${_fmt(m.fromDate)} – ${_fmt(m.toDate)}'),
      trailing: PopupMenuButton<String>(
        tooltip: l10n.businessGymMembershipActions,
        onSelected: (action) => switch (action) {
          'extend' => _extend(m),
          'cancel' => _cancelMembership(m),
          'delete' => _deleteMembership(m),
          _ => null,
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'extend',
            child: ListTile(
              leading: const Icon(Icons.update),
              title: Text(l10n.businessGymExtend),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (m.isActive)
            PopupMenuItem(
              value: 'cancel',
              child: ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: Text(l10n.businessGymCancelMembership),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: cs.error),
              title: Text(
                l10n.commonDelete,
                style: TextStyle(color: cs.error),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.businessGymEditMember)),
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
                  l10n.businessGymRoleMember,
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
                  leading: const Icon(Icons.fitness_center_outlined),
                  title: Text(l10n.businessGymGym),
                  subtitle: Text(widget.gymName),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Memberships ───────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.businessGymMemberships,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      TextButton.icon(
                        onPressed: _loadingMembership
                            ? null
                            : _assignMembership,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l10n.businessGymAssign),
                      ),
                    ],
                  ),
                  if (_loadingMembership)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(0, 8, 8, 8),
                      child: LinearProgressIndicator(),
                    )
                  else if (_membershipError != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _membershipError!,
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadMembership,
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    )
                  else if (_memberships.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.businessGymNoMembershipAt(widget.gymName),
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  else
                    for (final m in _memberships) _membershipTile(m, cs),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Progress ───────────────────────────────────────────────────────
          FilledButton.tonalIcon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberProgressPage(
                  userId: widget.user.id,
                  displayName: widget.user.fullName,
                  gymId: widget.gymId,
                ),
              ),
            ),
            icon: const Icon(Icons.insights_outlined),
            label: Text(l10n.businessGymViewProgress),
          ),

          const SizedBox(height: 12),

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
            label: Text(l10n.businessGymResendInvite),
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
                      strokeWidth: 2,
                      color: cs.error,
                    ),
                  )
                : Icon(Icons.person_remove_outlined, color: cs.error),
            label: Text(
              l10n.businessGymRemoveFromGym,
              style: TextStyle(color: cs.error),
            ),
            style: OutlinedButton.styleFrom(side: BorderSide(color: cs.error)),
          ),
        ],
      ),
    );
  }
}
