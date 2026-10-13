import 'package:flutter/material.dart';
import '../models/business.dart';
import '../models/membership.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

/// Membership invoices for owners, super users and gym staff.
///
/// Pass [gymId] to lock the page to one gym (e.g. from the gym detail page).
/// Otherwise the gyms the user manages/staffs are resolved and, when there is
/// more than one, a gym filter is shown.
class InvoicesPage extends StatefulWidget {
  const InvoicesPage({
    super.key,
    this.gymId,
    this.gymName,
    this.initialStatus = InvoiceStatus.unpaid,
  });

  final String? gymId;
  final String? gymName;

  /// Initial status filter; `null` means "All".
  final InvoiceStatus? initialStatus;

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _api = ApiService();

  /// Gyms the user can see invoices for (empty until resolved).
  List<Business> _gyms = [];
  bool _isSuper = false;
  String? _selectedGymId;
  late InvoiceStatus? _status = widget.initialStatus;

  List<MembershipInvoice> _invoices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedGymId = widget.gymId;
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.gymId == null) await _resolveGyms();
      await _loadInvoices();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  /// Collects every gym the user owns or works at (super user: all gyms).
  Future<void> _resolveGyms() async {
    final token = await AuthManager.instance.getValidToken();
    final profile = AuthManager.instance.profile;
    if (profile == null) throw Exception('No profile');
    _isSuper = profile.role == UserRole.superUser;

    List<Business> gyms;
    if (_isSuper) {
      gyms = (await _api.getBusinesses(
        token,
      )).where((b) => b.type == 'gym').toList();
    } else {
      final rows = await Future.wait([
        _api.getGymOwners(token, userId: profile.id),
        _api.getEmployees(token, userId: profile.id),
        _api.getEmployeeTrainers(token, userId: profile.id),
      ]);
      final ids = {
        for (final list in rows)
          for (final r in list) r['gym_id'] as String,
      };
      gyms = await Future.wait(ids.map((id) => _api.getBusiness(token, id)));
      gyms.sort((a, b) => a.name.compareTo(b.name));
    }
    if (mounted) setState(() => _gyms = gyms);
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      // A single gym the user works at needs no filter UI, but we still scope
      // the request to it.
      final gymId =
          _selectedGymId ?? (_gyms.length == 1 ? _gyms.first.id : null);
      var invoices = await _api.getMembershipInvoices(
        token,
        gymId: gymId,
        status: _status,
      );
      // Without a gym filter the API also returns the caller's own invoices
      // as a member — keep only invoices of gyms the user manages/staffs.
      if (gymId == null && !_isSuper) {
        final ids = _gyms.map((g) => g.id).toSet();
        invoices = invoices.where((i) => ids.contains(i.gymId)).toList();
      }
      invoices.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
      if (mounted) {
        setState(() {
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

  Future<void> _openActions(MembershipInvoice inv) async {
    final picked = await showModalBottomSheet<InvoiceStatus>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '${inv.memberFullName.isEmpty ? 'Invoice' : inv.memberFullName}'
                ' · \$${inv.amount.toStringAsFixed(2)}',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final s in InvoiceStatus.values)
              ListTile(
                leading: Icon(_statusIcon(s)),
                title: Text('Mark ${s.displayName.toLowerCase()}'),
                trailing: s == inv.status ? const Icon(Icons.check) : null,
                enabled: s != inv.status,
                onTap: () => Navigator.pop(ctx, s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || picked == inv.status) return;

    try {
      final token = await AuthManager.instance.getValidToken();
      final updated = await _api.updateMembershipInvoiceStatus(
        token,
        inv.id,
        picked,
      );
      if (!mounted) return;
      setState(() {
        if (_status != null && updated.status != _status) {
          // No longer matches the active filter.
          _invoices = _invoices.where((i) => i.id != inv.id).toList();
        } else {
          _invoices = [for (final i in _invoices) i.id == inv.id ? updated : i];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice marked ${picked.displayName.toLowerCase()}'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  IconData _statusIcon(InvoiceStatus s) => switch (s) {
    InvoiceStatus.paid => Icons.check_circle_outline,
    InvoiceStatus.unpaid => Icons.schedule_outlined,
    InvoiceStatus.voided => Icons.block_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.gymName != null ? '${widget.gymName} — Invoices' : 'Invoices',
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final showGymFilter = widget.gymId == null && _gyms.length > 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showGymFilter)
            DropdownButtonFormField<String?>(
              key: ValueKey(_selectedGymId),
              initialValue: _selectedGymId,
              decoration: const InputDecoration(
                labelText: 'Gym',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All gyms')),
                for (final g in _gyms)
                  DropdownMenuItem(value: g.id, child: Text(g.name)),
              ],
              onChanged: (v) {
                setState(() => _selectedGymId = v);
                _loadInvoices();
              },
            ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (label, value) in <(String, InvoiceStatus?)>[
                  ('Unpaid', InvoiceStatus.unpaid),
                  ('Paid', InvoiceStatus.paid),
                  ('Void', InvoiceStatus.voided),
                  ('All', null),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _status == value,
                      onSelected: (_) {
                        if (_status == value) return;
                        setState(() => _status = value);
                        _loadInvoices();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _gyms.isEmpty && widget.gymId == null
                    ? _init
                    : _loadInvoices,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_invoices.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadInvoices,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: cs.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _status == null
                            ? 'No invoices yet'
                            : 'No ${_status!.displayName.toLowerCase()} invoices',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final showGym = widget.gymId == null && _gyms.length != 1;
    return RefreshIndicator(
      onRefresh: _loadInvoices,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _invoices.length,
        itemBuilder: (_, i) {
          final inv = _invoices[i];
          final details = [
            if (showGym && inv.gymName != null) inv.gymName!,
            if (inv.membershipTypeName != null) inv.membershipTypeName!,
            'Issued ${formatDate(inv.issuedAt)}',
          ];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _openActions(inv),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      inv.memberFullName.isEmpty
                          ? 'Unknown member'
                          : inv.memberFullName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '\$${inv.amount.toStringAsFixed(2)}',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: cs.primary),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(details.join(' · '))),
                    const SizedBox(width: 8),
                    InvoiceStatusChip(status: inv.status),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// Small coloured chip showing an invoice's status.
class InvoiceStatusChip extends StatelessWidget {
  const InvoiceStatusChip({super.key, required this.status});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      InvoiceStatus.paid => (cs.primaryContainer, cs.onPrimaryContainer),
      InvoiceStatus.unpaid => (cs.tertiaryContainer, cs.onTertiaryContainer),
      InvoiceStatus.voided => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
