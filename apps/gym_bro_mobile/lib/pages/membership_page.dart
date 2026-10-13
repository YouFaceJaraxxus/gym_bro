import 'package:flutter/material.dart';
import '../models/membership.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'invoices_page.dart' show InvoiceStatusChip;

/// Member-facing view of their own gym membership: current plan, status, and
/// billing history.
class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  final _api = ApiService();
  List<Membership> _memberships = [];
  Map<String, GymMembershipType> _typesById = {};
  List<MembershipInvoice> _invoices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      // Membership types aren't scoped by gym here since we don't know the
      // member's gym up front — fetch them all once and index by id.
      // Invoices are listed across all of the member's memberships.
      final results = await Future.wait([
        _api.getMemberships(token, userId: widget.profile.id),
        _api.getGymMembershipTypes(token),
        _api.getMembershipInvoices(token, userId: widget.profile.id),
      ]);
      final memberships = results[0] as List<Membership>;
      final types = results[1] as List<GymMembershipType>;
      final invoices = results[2] as List<MembershipInvoice>;
      memberships.sort((a, b) => b.fromDate.compareTo(a.fromDate));
      invoices.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
      final typesById = {for (final t in types) t.id: t};

      if (mounted) {
        setState(() {
          _memberships = memberships;
          _typesById = typesById;
          _invoices = invoices;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_memberships.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.card_membership_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            const Text('No active membership'),
            const SizedBox(height: 8),
            Text(
              'Ask your gym to set up your membership plan.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      );
    }

    final current = _memberships.firstWhere(
      (m) => m.isActive,
      orElse: () => _memberships.first,
    );
    final type = _typesById[current.currentMembershipTypeId];
    final cs = Theme.of(context).colorScheme;
    final isValid = current.isActive && !current.isExpired;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          Card(
            color: isValid ? cs.primaryContainer : cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isValid ? Icons.verified_outlined : Icons.error_outline,
                        color: isValid
                            ? cs.onPrimaryContainer
                            : cs.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isValid ? 'Active Membership' : 'Membership Expired',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isValid
                              ? cs.onPrimaryContainer
                              : cs.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    type?.name ?? 'Membership',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: isValid
                          ? cs.onPrimaryContainer
                          : cs.onErrorContainer,
                    ),
                  ),
                  if (type != null)
                    Text(
                      '\$${type.monthlyCost.toStringAsFixed(2)}/month',
                      style: TextStyle(
                        color: isValid
                            ? cs.onPrimaryContainer
                            : cs.onErrorContainer,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    '${_fmt(current.fromDate)} – ${_fmt(current.toDate)}',
                    style: TextStyle(
                      color: isValid
                          ? cs.onPrimaryContainer
                          : cs.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Billing History',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No invoices yet',
                style: TextStyle(color: cs.outline),
              ),
            )
          else
            for (final inv in _invoices)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text('\$${inv.amount.toStringAsFixed(2)}'),
                  subtitle: Text(
                    [
                      inv.membershipTypeName ??
                          _typesById[inv.membershipTypeId]?.name ??
                          'Membership',
                      if (inv.gymName != null) inv.gymName!,
                      _fmt(inv.issuedAt),
                    ].join(' · '),
                  ),
                  trailing: InvoiceStatusChip(status: inv.status),
                ),
              ),
          if (_memberships.length > 1) ...[
            const SizedBox(height: 24),
            Text(
              'Membership History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final m in _memberships.skip(1))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(
                    _typesById[m.currentMembershipTypeId]?.name ?? 'Membership',
                  ),
                  subtitle: Text('${_fmt(m.fromDate)} – ${_fmt(m.toDate)}'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
