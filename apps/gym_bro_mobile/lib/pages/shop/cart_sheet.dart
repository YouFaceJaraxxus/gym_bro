import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/order.dart';
import '../../models/payment.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'cart_service.dart';
import 'order_detail_page.dart';
import 'order_widgets.dart';
import '../../widgets/app_bottom_sheet.dart';

/// Opens the cart for [shopId] as a bottom sheet. After a successful order it
/// opens the order (and starts card checkout when paying by card).
/// [onStockProblem] is called when the order is rejected so the caller can
/// refresh stock.
Future<void> showCartSheet(
  BuildContext context, {
  required String shopId,
  required String shopName,
  required PaymentsConfig config,
  VoidCallback? onStockProblem,
}) async {
  final navigator = Navigator.of(context);
  final order = await showAppBottomSheet<ShopOrder>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _CartSheet(
      shopId: shopId,
      shopName: shopName,
      config: config,
      onStockProblem: onStockProblem,
    ),
  );
  if (order == null || !navigator.mounted) return;
  navigator.push(
    MaterialPageRoute(
      builder: (_) => OrderDetailPage(
        orderId: order.id,
        autoPay: order.paymentMethod == OrderPaymentMethod.card,
      ),
    ),
  );
}

class _CartSheet extends StatefulWidget {
  const _CartSheet({
    required this.shopId,
    required this.shopName,
    required this.config,
    this.onStockProblem,
  });

  final String shopId;
  final String shopName;
  final PaymentsConfig config;
  final VoidCallback? onStockProblem;

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final _api = ApiService();
  final _cart = CartService.instance;
  final _noteCtrl = TextEditingController();
  late OrderPaymentMethod _method = widget.config.enabled
      ? OrderPaymentMethod.card
      : OrderPaymentMethod.payAtPickup;
  bool _placing = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  String _money(double v) => formatMoney(
    v,
    widget.config.currency,
    Localizations.localeOf(context).toString(),
  );

  Future<void> _placeOrder() async {
    final lines = _cart.linesFor(widget.shopId);
    if (lines.isEmpty) return;
    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final order = await _api.createOrder(
        token,
        shopId: widget.shopId,
        items: {for (final l in lines) l.itemId: l.quantity},
        paymentMethod: _method,
        note: _noteCtrl.text,
      );
      _cart.clear(widget.shopId);
      if (mounted) Navigator.pop(context, order);
    } catch (e) {
      // 409: out of stock / no longer sold; 400: card unavailable, etc.
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _placing = false;
        });
      }
      widget.onStockProblem?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _cart,
      builder: (context, _) {
        final lines = _cart.linesFor(widget.shopId);
        final total = _cart.totalFor(widget.shopId);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.businessShopYourCart, style: tt.titleLarge),
                Text(
                  widget.shopName,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                if (lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 48,
                          color: cs.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(l10n.businessShopCartEmpty),
                        const SizedBox(height: 4),
                        Text(
                          l10n.businessShopCartEmptyHint,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                else ...[
                  for (final line in lines) _lineRow(line),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Text(l10n.businessShopTotal, style: tt.titleMedium),
                      const Spacer(),
                      Text(
                        _money(total),
                        style: tt.titleLarge?.copyWith(color: cs.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(l10n.businessShopPayment, style: tt.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<OrderPaymentMethod>(
                    segments: [
                      ButtonSegment(
                        value: OrderPaymentMethod.card,
                        icon: const Icon(Icons.credit_card),
                        label: Text(l10n.businessShopPayByCard),
                        enabled: widget.config.enabled,
                      ),
                      ButtonSegment(
                        value: OrderPaymentMethod.payAtPickup,
                        icon: const Icon(Icons.storefront_outlined),
                        label: Text(OrderPaymentMethod.payAtPickup.label(l10n)),
                      ),
                    ],
                    selected: {_method},
                    onSelectionChanged: _placing
                        ? null
                        : (s) => setState(() => _method = s.first),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    !widget.config.enabled
                        ? l10n.businessShopCardUnavailablePayAtPickup
                        : _method == OrderPaymentMethod.card
                        ? l10n.businessShopCardPaymentHint
                        : l10n.businessShopPickupPaymentHint,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteCtrl,
                    enabled: !_placing,
                    maxLength: 500,
                    maxLines: 2,
                    minLines: 1,
                    decoration: InputDecoration(
                      labelText: l10n.businessShopNoteForShop,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: cs.onErrorContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: cs.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _placing ? null : _placeOrder,
                    icon: _placing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _method == OrderPaymentMethod.card
                                ? Icons.lock_outline
                                : Icons.check,
                          ),
                    label: Text(
                      _method == OrderPaymentMethod.card
                          ? l10n.businessShopPlaceOrderAndPay(_money(total))
                          : l10n.businessShopPlaceOrderTotal(_money(total)),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  TextButton(
                    onPressed: _placing
                        ? null
                        : () => _cart.clear(widget.shopId),
                    child: Text(l10n.businessShopEmptyCart),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _lineRow(CartLine line) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: line.imageUrl != null
                  ? Image.network(
                      line.imageUrl!,
                      fit: BoxFit.cover,
                      // Decorative: the product name is right next to it.
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyLarge,
                ),
                Text(
                  l10n.businessShopPriceEachLineTotal(
                    _money(line.price),
                    _money(line.lineTotal),
                  ),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: line.quantity <= 1
                ? l10n.businessShopRemove
                : l10n.businessShopDecreaseQuantity,
            icon: Icon(
              line.quantity <= 1 ? Icons.delete_outline : Icons.remove,
            ),
            onPressed: _placing
                ? null
                : () => _cart.setQuantity(
                    widget.shopId,
                    line.itemId,
                    line.quantity - 1,
                  ),
          ),
          SizedBox(
            width: 28,
            child: Semantics(
              label: l10n.businessShopQuantityValue(line.quantity),
              excludeSemantics: true,
              child: Text(
                '${line.quantity}',
                textAlign: TextAlign.center,
                style: tt.titleMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.businessShopIncreaseQuantity,
            icon: const Icon(Icons.add),
            onPressed: _placing || line.quantity >= line.maxQuantity
                ? null
                : () => _cart.setQuantity(
                    widget.shopId,
                    line.itemId,
                    line.quantity + 1,
                  ),
          ),
        ],
      ),
    );
  }
}
