import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/payment.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'order_widgets.dart';
import 'payment_launcher.dart';

/// Self-serve membership purchase: pick a gym → membership type → length
/// (1/3/6/12 months, or monthly auto-renew) → Stripe Checkout.
///
/// Pops with `true` when a payment succeeded.
class BuyMembershipPage extends StatefulWidget {
  const BuyMembershipPage({super.key, this.initialGymId});

  /// Preselects a gym (e.g. to renew at the member's current gym).
  final String? initialGymId;

  @override
  State<BuyMembershipPage> createState() => _BuyMembershipPageState();
}

/// null months = monthly auto-renewing subscription.
const _planMonths = <int?>[1, 3, 6, 12, null];

class _BuyMembershipPageState extends State<BuyMembershipPage> {
  final _api = ApiService();
  List<PurchasableGym> _gyms = [];
  PaymentsConfig _config = PaymentsConfigCache.current;
  PurchasableGym? _gym;
  PurchasableMembershipType? _type;
  int? _months = 1;
  String _query = '';
  bool _loading = true;
  bool _paying = false;
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
      final config = await PaymentsConfigCache.get(_api, token, refresh: true);
      final gyms = config.enabled
          ? await _api.getPurchasableGyms(token)
          : <PurchasableGym>[];
      if (!mounted) return;
      setState(() {
        _config = config;
        _gyms = gyms;
        if (_gym == null && widget.initialGymId != null) {
          for (final g in gyms) {
            if (g.id == widget.initialGymId) _selectGym(g);
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _loading = false;
        });
      }
    }
  }

  void _selectGym(PurchasableGym? g) {
    _gym = g;
    _type = g != null && g.types.length == 1 ? g.types.first : null;
    _months = 1;
  }

  String _money(double v) => formatMoney(
    v,
    _config.currency,
    Localizations.localeOf(context).toString(),
  );

  Future<void> _checkout() async {
    final type = _type;
    if (type == null) return;
    setState(() => _paying = true);
    final payment = await PaymentLauncher.start(
      context,
      checkout: (api, token) => api.checkoutMembership(
        token,
        membershipTypeId: type.id,
        months: _months ?? 1,
        autoRenew: _months == null,
      ),
      successMessage: context.l10n.businessShopMembershipPaymentSuccess,
    );
    if (!mounted) return;
    setState(() => _paying = false);
    if (payment?.isSucceeded ?? false) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: _gym == null || _paying,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selectGym(null));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_gym?.name ?? l10n.businessShopBuyMembershipTitle),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ShopErrorState(message: _error!, onRetry: _load)
            : !_config.enabled
            ? ShopEmptyState(
                icon: Icons.point_of_sale_outlined,
                title: l10n.businessShopOnlinePaymentsUnavailable,
                message: l10n.businessShopBuyAtFrontDesk,
              )
            : _gym == null
            ? _gymList()
            : _planPicker(_gym!),
        bottomNavigationBar: _gym != null && _type != null && _config.enabled
            ? _checkoutBar()
            : null,
      ),
    );
  }

  Widget _gymList() {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final q = _query.trim().toLowerCase();
    final gyms = q.isEmpty
        ? _gyms
        : _gyms
              .where(
                (g) =>
                    g.name.toLowerCase().contains(q) ||
                    g.location.toLowerCase().contains(q),
              )
              .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: _gyms.isEmpty
          ? ShopEmptyState(
              icon: Icons.fitness_center,
              title: l10n.businessShopNoMembershipsForSale,
              message: l10n.businessShopNoGymSellsMemberships,
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: l10n.businessShopSearchGyms,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                if (gyms.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.businessShopNoGymsMatch,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                for (final g in gyms)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: g.logo != null
                          ? CircleAvatar(backgroundImage: NetworkImage(g.logo!))
                          : CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              child: Icon(
                                Icons.fitness_center,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                      title: Text(g.name),
                      subtitle: Text(
                        '${g.location}\n${l10n.businessShopFromPricePerMonth(_money(g.types.map((t) => t.monthlyCost).reduce((a, b) => a < b ? a : b)))}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => setState(() => _selectGym(g)),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _planPicker(PurchasableGym gym) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.businessShopMembershipType, style: tt.titleMedium),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: _type?.id,
          onChanged: (id) =>
              setState(() => _type = gym.types.firstWhere((t) => t.id == id)),
          child: Column(
            children: [
              for (final t in gym.types)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: _type?.id == t.id ? cs.secondaryContainer : null,
                  child: RadioListTile<String>(
                    value: t.id,
                    title: Text(t.name),
                    subtitle: Text(
                      l10n.businessShopPricePerMonth(_money(t.monthlyCost)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_type != null) ...[
          const SizedBox(height: 16),
          Text(l10n.businessShopLength, style: tt.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _planMonths)
                ChoiceChip(
                  label: Text(
                    m == null
                        ? l10n.businessShopPlanMonthlyAutoRenew
                        : l10n.businessShopPlanMonths(m),
                  ),
                  selected: _months == m,
                  onSelected: (_) => setState(() => _months = m),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _months == null
                ? l10n.businessShopAutoRenewExplanation(
                    _money(_type!.monthlyCost),
                  )
                : l10n.businessShopOneTimeExplanation(
                    _money(_type!.monthlyCost * _months!),
                    gym.name,
                  ),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _paying ? null : () => setState(() => _selectGym(null)),
          icon: const Icon(Icons.arrow_back),
          label: Text(l10n.businessShopChooseDifferentGym),
        ),
      ],
    );
  }

  Widget _checkoutBar() {
    final type = _type!;
    final total = type.monthlyCost * (_months ?? 1);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _paying ? null : _checkout,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: _paying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_outline),
          label: Text(
            _months == null
                ? context.l10n.businessShopSubscribePerMonth(_money(total))
                : context.l10n.businessShopPayAmount(_money(total)),
          ),
        ),
      ),
    );
  }
}
