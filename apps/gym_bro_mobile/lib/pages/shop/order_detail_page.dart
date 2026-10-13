import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/order.dart';
import '../../models/payment.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'order_widgets.dart';
import 'payment_launcher.dart';

/// One shop order. The buyer can pay (card orders) or cancel while pending;
/// shop staff move it through paid → fulfilled or cancel it.
class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    super.key,
    required this.orderId,
    this.autoPay = false,
    this.asStaff = false,
  });

  final String orderId;

  /// Start card checkout as soon as the order loads (right after ordering).
  final bool autoPay;

  /// Opened from the shop's order list: show staff actions.
  final bool asStaff;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final _api = ApiService();
  ShopOrder? _order;
  PaymentsConfig _config = PaymentsConfigCache.current;
  bool _loading = true;
  bool _busy = false;
  bool _autoPayDone = false;
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
      final results = await Future.wait([
        _api.getOrder(token, widget.orderId),
        PaymentsConfigCache.get(_api, token),
      ]);
      if (!mounted) return;
      setState(() {
        _order = results[0] as ShopOrder;
        _config = results[1] as PaymentsConfig;
        _loading = false;
        _error = null;
      });
      if (widget.autoPay && !_autoPayDone) {
        _autoPayDone = true;
        if (_canPay) _pay();
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

  String? get _myId => AuthManager.instance.profile?.id;
  bool get _isBuyer => _order != null && _order!.userId == _myId;
  bool get _isStaff => widget.asStaff || (_order != null && !_isBuyer);
  bool get _canPay =>
      _isBuyer && _config.enabled && (_order?.awaitingCardPayment ?? false);

  String get _locale => Localizations.localeOf(context).toString();

  String _money(double v) => formatMoney(v, _config.currency, _locale);

  Future<void> _pay() async {
    setState(() => _busy = true);
    await PaymentLauncher.start(
      context,
      checkout: (api, token) => api.checkoutOrder(token, widget.orderId),
      successMessage: context.l10n.businessShopOrderPaymentSuccess,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _load(quiet: true);
  }

  Future<void> _setStatus(OrderStatus to) async {
    final order = _order!;
    final l10n = context.l10n;
    final (title, message, label, destructive) = switch (to) {
      OrderStatus.paid => (
        l10n.businessShopMarkAsPaidTitle,
        l10n.businessShopConfirmPaidAtCounter(_money(order.total)),
        l10n.businessShopMarkPaid,
        false,
      ),
      OrderStatus.fulfilled => (
        l10n.businessShopMarkAsFulfilledTitle,
        l10n.businessShopCustomerPickedUp,
        l10n.businessShopMarkFulfilled,
        false,
      ),
      OrderStatus.cancelled => (
        l10n.businessShopCancelOrderTitle,
        [
          l10n.businessShopItemsBackInStock,
          if (order.paymentStatus == 'succeeded')
            l10n.businessShopCardWillBeRefunded,
        ].join(' '),
        l10n.businessShopCancelOrder,
        true,
      ),
      OrderStatus.pending => ('', '', '', false),
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
    setState(() => _busy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final updated = await _api.updateOrderStatus(token, order.id, to);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _busy = false;
      });
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
              l10n.businessShopOrderStatusChanged(updated.status.apiValue),
              ?refund,
            ].join(' '),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorText(e))));
      _load(quiet: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          order == null
              ? l10n.businessShopOrder
              : l10n.businessShopOrderWithId(shortOrderId(order.id)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ShopErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: () => _load(quiet: true),
              child: _buildContent(order!),
            ),
      bottomNavigationBar: order == null || _loading || _error != null
          ? null
          : _actions(order),
    );
  }

  Widget _buildContent(ShopOrder order) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.shopName ?? l10n.businessShopShop,
                        style: tt.titleLarge,
                      ),
                    ),
                    OrderStatusChip(status: order.status),
                  ],
                ),
                const SizedBox(height: 8),
                _infoRow(Icons.tag, shortOrderId(order.id)),
                if (order.createdAt != null)
                  _infoRow(
                    Icons.schedule,
                    formatDateTime(order.createdAt!, _locale),
                  ),
                _infoRow(
                  order.paymentMethod == OrderPaymentMethod.card
                      ? Icons.credit_card
                      : Icons.storefront_outlined,
                  [
                    order.paymentMethod.label(l10n),
                    if (order.paymentStatus != null &&
                        order.paymentMethod == OrderPaymentMethod.card)
                      PaymentStatus.fromString(order.paymentStatus).label(l10n),
                  ].join(' · '),
                ),
                if (_isStaff && (order.buyerName ?? order.buyerEmail) != null)
                  _infoRow(
                    Icons.person_outline,
                    [?order.buyerName, ?order.buyerEmail].join(' · '),
                  ),
              ],
            ),
          ),
        ),
        if (order.awaitingCardPayment && _isBuyer) ...[
          const SizedBox(height: 8),
          Card(
            color: cs.tertiaryContainer,
            child: ListTile(
              leading: Icon(Icons.info_outline, color: cs.onTertiaryContainer),
              title: Text(
                _config.enabled
                    ? l10n.businessShopAwaitingYourCardPayment
                    : l10n.businessShopCardUnavailableNow,
                style: TextStyle(color: cs.onTertiaryContainer),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.businessShopItems, style: tt.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final item in order.items)
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: item.imageUrl != null
                          ? Image.network(
                              item.imageUrl!,
                              fit: BoxFit.cover,
                              // Decorative: the item name is the tile title.
                              excludeFromSemantics: true,
                              errorBuilder: (_, _, _) =>
                                  Container(color: cs.surfaceContainerHighest),
                            )
                          : Container(
                              color: cs.surfaceContainerHighest,
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.quantity} × ${_money(item.unitPrice)}',
                  ),
                  trailing: Text(_money(item.lineTotal), style: tt.titleSmall),
                ),
              const Divider(height: 1),
              ListTile(
                title: Text(l10n.businessShopTotal, style: tt.titleMedium),
                trailing: Text(
                  _money(order.total),
                  style: tt.titleLarge?.copyWith(color: cs.primary),
                ),
              ),
            ],
          ),
        ),
        if (order.note != null && order.note!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.businessShopNote, style: tt.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(order.note!),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.businessShopStatus, style: tt.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _Timeline(order: order),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget? _actions(ShopOrder order) {
    final buttons = <Widget>[];
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final cancel = OutlinedButton(
      onPressed: _busy ? null : () => _setStatus(OrderStatus.cancelled),
      style: OutlinedButton.styleFrom(foregroundColor: cs.error),
      child: Text(l10n.businessShopCancelOrder),
    );
    if (_isStaff) {
      if (order.status == OrderStatus.pending) {
        buttons
          ..add(cancel)
          ..add(
            FilledButton(
              onPressed: _busy ? null : () => _setStatus(OrderStatus.paid),
              child: Text(l10n.businessShopMarkPaid),
            ),
          );
      } else if (order.status == OrderStatus.paid) {
        buttons
          ..add(cancel)
          ..add(
            FilledButton(
              onPressed: _busy ? null : () => _setStatus(OrderStatus.fulfilled),
              child: Text(l10n.businessShopMarkFulfilled),
            ),
          );
      }
    } else if (_isBuyer && order.status == OrderStatus.pending) {
      buttons.add(cancel);
      if (_canPay) {
        buttons.add(
          FilledButton.icon(
            onPressed: _busy ? null : _pay,
            icon: const Icon(Icons.lock_outline),
            label: Text(l10n.businessShopPayNow(_money(order.total))),
          ),
        );
      }
    }
    if (buttons.isEmpty) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: buttons[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});

  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final paid = OrderStatus.paid.label(l10n);
    final steps = <(String, IconData, DateTime?, bool)>[
      (
        l10n.businessShopTimelinePlaced,
        Icons.receipt_long_outlined,
        order.createdAt,
        true,
      ),
      if (order.status == OrderStatus.cancelled) ...[
        if (order.paidAt != null)
          (paid, Icons.payments_outlined, order.paidAt, true),
        (
          OrderStatus.cancelled.label(l10n),
          Icons.cancel_outlined,
          order.cancelledAt,
          true,
        ),
      ] else ...[
        (paid, Icons.payments_outlined, order.paidAt, order.paidAt != null),
        (
          OrderStatus.fulfilled.label(l10n),
          Icons.inventory_outlined,
          order.fulfilledAt,
          order.fulfilledAt != null,
        ),
      ],
    ];
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _step(
            context,
            cs,
            steps[i],
            isLast: i == steps.length - 1,
            // The cancelled step is always the last one of a cancelled order.
            cancelled:
                order.status == OrderStatus.cancelled && i == steps.length - 1,
          ),
      ],
    );
  }

  Widget _step(
    BuildContext context,
    ColorScheme cs,
    (String, IconData, DateTime?, bool) s, {
    required bool isLast,
    required bool cancelled,
  }) {
    final (label, icon, at, done) = s;
    final locale = Localizations.localeOf(context).toString();
    final color = cancelled
        ? cs.error
        : (done ? cs.primary : cs.outlineVariant);
    return MergeSemantics(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  Icon(icon, color: color),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: done ? cs.primary : cs.outlineVariant,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: done ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      at != null
                          ? formatDateTime(at, locale)
                          : context.l10n.businessShopNotYet,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
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
}
