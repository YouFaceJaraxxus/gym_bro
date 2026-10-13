import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/order.dart';
import '../../models/payment.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'order_detail_page.dart';
import 'order_widgets.dart';

/// A shop's orders for its owners and vendors, filterable by status, with
/// quick actions to mark paid / fulfilled or cancel.
class ShopOrdersPage extends StatefulWidget {
  const ShopOrdersPage({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  final String shopId;
  final String shopName;

  @override
  State<ShopOrdersPage> createState() => _ShopOrdersPageState();
}

class _ShopOrdersPageState extends State<ShopOrdersPage> {
  final _api = ApiService();
  List<ShopOrder> _orders = [];
  String _currency = PaymentsConfigCache.current.currency;

  /// null = all statuses.
  OrderStatus? _filter = OrderStatus.pending;
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

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
      final results = await Future.wait([
        _api.getShopOrders(token, widget.shopId, status: _filter),
        PaymentsConfigCache.get(_api, token),
      ]);
      if (mounted) {
        setState(() {
          _orders = results[0] as List<ShopOrder>;
          _currency = PaymentsConfigCache.current.currency;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _loading = false;
        });
      }
    }
  }

  void _setFilter(OrderStatus? s) {
    if (_filter == s) return;
    setState(() => _filter = s);
    _load();
  }

  Future<void> _open(ShopOrder order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(orderId: order.id, asStaff: true),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _setStatus(ShopOrder order, OrderStatus to) async {
    final l10n = context.l10n;
    final total = formatMoney(
      order.total,
      _currency,
      Localizations.localeOf(context).toString(),
    );
    final buyer = order.buyerName;
    final (title, message, label, destructive) = switch (to) {
      OrderStatus.paid => (
        l10n.businessShopMarkAsPaidTitle,
        buyer != null
            ? l10n.businessShopConfirmBuyerPaid(buyer, total)
            : l10n.businessShopConfirmCustomerPaid(total),
        l10n.businessShopMarkPaid,
        false,
      ),
      OrderStatus.fulfilled => (
        l10n.businessShopMarkAsFulfilledTitle,
        buyer != null
            ? l10n.businessShopBuyerPickedUp(buyer)
            : l10n.businessShopCustomerPickedUpOrder,
        l10n.businessShopMarkFulfilled,
        false,
      ),
      _ => (
        l10n.businessShopCancelOrderTitle,
        [
          l10n.businessShopItemsBackInStock,
          if (order.paymentStatus == 'succeeded')
            l10n.businessShopCardOfAmountWillBeRefunded(total),
        ].join(' '),
        l10n.businessShopCancelOrder,
        true,
      ),
    };
    if (!await confirmAction(
      context,
      title: title,
      message: message,
      confirmLabel: label,
      destructive: destructive,
    )) {
      return;
    }
    setState(() => _busy.add(order.id));
    try {
      final token = await AuthManager.instance.getValidToken();
      final updated = await _api.updateOrderStatus(token, order.id, to);
      if (!mounted) return;
      final refund = switch (updated.refundStatus) {
        'refunded' => l10n.businessShopRefundDone,
        'failed' => l10n.businessShopRefundFailed,
        'manual' => l10n.businessShopRefundManual,
        _ => null,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            [
              l10n.businessShopOrderIdStatusChanged(
                updated.status.apiValue,
                shortOrderId(order.id),
              ),
              ?refund,
            ].join(' '),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorText(e))));
      }
    }
    if (!mounted) return;
    setState(() => _busy.remove(order.id));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.businessShopOrders),
            Text(widget.shopName, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                for (final s in <OrderStatus?>[
                  OrderStatus.pending,
                  OrderStatus.paid,
                  OrderStatus.fulfilled,
                  OrderStatus.cancelled,
                  null,
                ]) ...[
                  FilterChip(
                    label: Text(s?.label(l10n) ?? l10n.businessShopFilterAll),
                    selected: _filter == s,
                    onSelected: (_) => _setFilter(s),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ShopErrorState(message: _error!, onRetry: _load);
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: _load,
      child: _orders.isEmpty
          ? ShopEmptyState(
              icon: Icons.inbox_outlined,
              title: _filter == null
                  ? l10n.businessShopNoOrdersYet
                  : l10n.businessShopNoOrdersWithStatus(_filter!.apiValue),
              message: _filter == OrderStatus.pending
                  ? l10n.businessShopNewOrdersHint
                  : null,
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _orders.length,
              itemBuilder: (context, i) => _orderCard(_orders[i]),
            ),
    );
  }

  Widget _orderCard(ShopOrder order) {
    final busy = _busy.contains(order.id);
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final actions = <Widget>[
      if (order.status == OrderStatus.pending ||
          order.status == OrderStatus.paid)
        TextButton(
          onPressed: busy
              ? null
              : () => _setStatus(order, OrderStatus.cancelled),
          style: TextButton.styleFrom(foregroundColor: cs.error),
          child: Text(l10n.commonCancel),
        ),
      if (order.status == OrderStatus.pending)
        FilledButton.tonal(
          onPressed: busy ? null : () => _setStatus(order, OrderStatus.paid),
          child: Text(l10n.businessShopMarkPaid),
        ),
      if (order.status == OrderStatus.paid)
        FilledButton.tonal(
          onPressed: busy
              ? null
              : () => _setStatus(order, OrderStatus.fulfilled),
          child: Text(l10n.businessShopMarkFulfilled),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrderTile(
          order: order,
          currency: _currency,
          showBuyer: true,
          onTap: () => _open(order),
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 0, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                for (final a in actions) ...[const SizedBox(width: 8), a],
              ],
            ),
          ),
      ],
    );
  }
}
