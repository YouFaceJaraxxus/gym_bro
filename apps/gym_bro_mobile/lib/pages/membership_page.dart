import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/membership.dart';
import '../models/payment.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'invoices_page.dart' show InvoiceStatusChip;
import 'shop/buy_membership_page.dart';
import 'shop/order_widgets.dart' show PaymentsConfigCache, confirmAction;
import 'shop/payment_launcher.dart';

/// Member-facing view of their own gym membership: current plan, status,
/// billing history, paying invoices and buying / renewing in the app.
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
  PaymentsConfig _config = PaymentsConfigCache.current;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final token = await AuthManager.instance.getValidToken();
      // Membership types aren't scoped by gym here since we don't know the
      // member's gym up front — fetch them all once and index by id.
      // Invoices are listed across all of the member's memberships.
      final results = await Future.wait([
        _api.getMemberships(token, userId: widget.profile.id),
        _api.getGymMembershipTypes(token),
        _api.getMembershipInvoices(token, userId: widget.profile.id),
        PaymentsConfigCache.get(_api, token),
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
          _config = results[3] as PaymentsConfig;
          _loading = false;
          _error = null;
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

  String _money(double v) => formatMoney(
    v,
    _config.currency,
    Localizations.localeOf(context).toString(),
  );

  Future<void> _payInvoice(MembershipInvoice inv) async {
    setState(() => _busy = true);
    await PaymentLauncher.start(
      context,
      checkout: (api, token) => api.checkoutInvoice(token, inv.id),
      successMessage: context.l10n.businessMgmtInvoicePaidThanks,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _load(quiet: true);
  }

  Future<void> _buyMembership({String? gymId}) async {
    final bought = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BuyMembershipPage(initialGymId: gymId)),
    );
    if (bought == true && mounted) _load(quiet: true);
  }

  Future<void> _turnOffAutoRenew(Membership m) async {
    final ok = await confirmAction(
      context,
      title: context.l10n.businessMgmtTurnOffAutoRenewTitle,
      message: context.l10n.businessMgmtTurnOffAutoRenewMessage(_fmt(m.toDate)),
      confirmLabel: context.l10n.businessMgmtTurnOff,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final turnedOff = context.l10n.businessMgmtAutoRenewTurnedOff;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.cancelMembershipAutoRenew(token, m.id);
      messenger.showSnackBar(SnackBar(content: Text(turnedOff)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _load(quiet: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    if (_memberships.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(quiet: true),
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.card_membership_outlined,
                          size: 48,
                          color: cs.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(l10n.businessMgmtNoActiveMembership),
                        const SizedBox(height: 8),
                        Text(
                          _config.enabled
                              ? l10n.businessMgmtNoMembershipBuyHint
                              : l10n.businessMgmtNoMembershipDeskHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.outline),
                        ),
                        if (_config.enabled) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _buyMembership(),
                            icon: const Icon(Icons.add_card),
                            label: Text(l10n.businessMgmtBuyMembership),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final current = _memberships.firstWhere(
      (m) => m.isActive,
      orElse: () => _memberships.first,
    );
    final type = _typesById[current.currentMembershipTypeId];
    final isValid = current.isActive && !current.isExpired;
    final onCard = isValid ? cs.onPrimaryContainer : cs.onErrorContainer;
    final unpaid = _invoices
        .where((i) => i.status == InvoiceStatus.unpaid)
        .toList();

    return RefreshIndicator(
      onRefresh: () => _load(quiet: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                        color: onCard,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isValid
                            ? l10n.businessMgmtActiveMembership
                            : l10n.businessMgmtMembershipExpired,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: onCard,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    type?.name ?? l10n.businessMgmtMembership,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: onCard),
                  ),
                  if (type != null)
                    Text(
                      l10n.businessMgmtPerMonth(_money(type.monthlyCost)),
                      style: TextStyle(color: onCard),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    '${_fmt(current.fromDate)} – ${_fmt(current.toDate)}',
                    style: TextStyle(color: onCard),
                  ),
                  if (current.autoRenew) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.autorenew, size: 18, color: onCard),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.businessMgmtRenewsMonthly,
                            style: TextStyle(color: onCard),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => _turnOffAutoRenew(current),
                        style: TextButton.styleFrom(
                          foregroundColor: onCard,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(l10n.businessMgmtTurnOffAutoRenew),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_config.enabled)
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _buyMembership(gymId: type?.gymId),
              icon: const Icon(Icons.add_card),
              label: Text(
                isValid
                    ? l10n.businessMgmtExtendOrBuy
                    : l10n.businessMgmtRenewMembership,
              ),
            )
          else
            Row(
              children: [
                Icon(Icons.point_of_sale_outlined, size: 18, color: cs.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.businessMgmtPaymentsAtDesk,
                    style: TextStyle(color: cs.outline),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          Text(
            l10n.businessMgmtBillingHistory,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (unpaid.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l10n.businessMgmtUnpaidSummary(
                unpaid.length,
                _money(unpaid.fold(0.0, (s, i) => s + i.amount)),
              ),
              style: TextStyle(color: cs.error),
            ),
          ],
          const SizedBox(height: 8),
          if (_invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l10n.businessMgmtNoInvoicesYet,
                style: TextStyle(color: cs.outline),
              ),
            )
          else
            for (final inv in _invoices) _invoiceCard(inv),
          if (_memberships.length > 1) ...[
            const SizedBox(height: 24),
            Text(
              l10n.businessMgmtMembershipHistory,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final m in _memberships.where((m) => m.id != current.id))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: MergeSemantics(
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(
                      _typesById[m.currentMembershipTypeId]?.name ??
                          l10n.businessMgmtMembership,
                    ),
                    subtitle: Text('${_fmt(m.fromDate)} – ${_fmt(m.toDate)}'),
                    trailing: m.autoRenew
                        ? Icon(
                            Icons.autorenew,
                            color: cs.primary,
                            semanticLabel: l10n.businessMgmtAutoRenewOn,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _invoiceCard(MembershipInvoice inv) {
    final canPay = _config.enabled && inv.status == InvoiceStatus.unpaid;
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          MergeSemantics(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(_money(inv.amount)),
              subtitle: Text(
                [
                  inv.membershipTypeName ??
                      _typesById[inv.membershipTypeId]?.name ??
                      l10n.businessMgmtMembership,
                  if (inv.gymName != null) inv.gymName!,
                  _fmt(inv.issuedAt),
                ].join(' · '),
              ),
              trailing: InvoiceStatusChip(status: inv.status),
            ),
          ),
          if (canPay)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _payInvoice(inv),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: Text(l10n.businessMgmtPayNow(_money(inv.amount))),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => DateFormat.yMMMd(
    Localizations.localeOf(context).toString(),
  ).format(d.toLocal());
}
