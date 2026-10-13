import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/order.dart';
import '../../models/payment.dart';
import '../../services/api_service.dart';

/// Caches GET /payments/config for the app session.
class PaymentsConfigCache {
  PaymentsConfigCache._();

  static PaymentsConfig? _cached;
  static DateTime? _fetchedAt;

  static PaymentsConfig get current => _cached ?? PaymentsConfig.disabled;

  /// Never throws: falls back to "disabled" when the config can't be loaded.
  static Future<PaymentsConfig> get(
    ApiService api,
    String token, {
    bool refresh = false,
  }) async {
    final fresh =
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < const Duration(minutes: 5);
    if (!refresh && fresh && _cached != null) return _cached!;
    try {
      _cached = await api.getPaymentsConfig(token);
      _fetchedAt = DateTime.now();
    } catch (_) {
      _cached ??= PaymentsConfig.disabled;
    }
    return _cached!;
  }
}

/// The API's error text without Dart's "Exception: " prefix.
String errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

/// Date + time in [locale] (e.g. `Localizations.localeOf(context).toString()`);
/// without a locale, intl's default locale is used.
String formatDateTime(DateTime d, [String? locale]) =>
    DateFormat.yMMMd(locale).add_Hm().format(d.toLocal());

/// Date only, in [locale] (see [formatDateTime]).
String formatDate(DateTime d, [String? locale]) =>
    DateFormat.yMMMd(locale).format(d.toLocal());

String shortOrderId(String id) => '#${id.substring(0, 8).toUpperCase()}';

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      OrderStatus.pending => (cs.tertiaryContainer, cs.onTertiaryContainer),
      OrderStatus.paid => (cs.secondaryContainer, cs.onSecondaryContainer),
      OrderStatus.fulfilled => (cs.primaryContainer, cs.onPrimaryContainer),
      OrderStatus.cancelled => (
        cs.surfaceContainerHighest,
        cs.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label(context.l10n),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// One order in a list (my orders / shop orders).
class OrderTile extends StatelessWidget {
  const OrderTile({
    super.key,
    required this.order,
    required this.currency,
    required this.onTap,
    this.showBuyer = false,
  });

  final ShopOrder order;
  final String currency;
  final VoidCallback onTap;
  final bool showBuyer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final title = showBuyer
        ? (order.buyerName ?? order.buyerEmail ?? l10n.businessShopCustomer)
        : (order.shopName ?? l10n.businessShopShop);
    final summary = order.items.isEmpty
        ? l10n.businessShopItemCount(order.itemCount)
        : order.items
              .map((i) => i.quantity > 1 ? '${i.quantity}× ${i.name}' : i.name)
              .join(', ');
    return MergeSemantics(
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    OrderStatusChip(status: order.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      order.paymentMethod == OrderPaymentMethod.card
                          ? Icons.credit_card
                          : Icons.storefront_outlined,
                      size: 16,
                      color: cs.outline,
                      semanticLabel: order.paymentMethod.label(l10n),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      [
                        shortOrderId(order.id),
                        if (order.createdAt != null)
                          formatDateTime(order.createdAt!, locale),
                      ].join(' · '),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: cs.outline),
                    ),
                    const Spacer(),
                    Text(
                      formatMoney(order.total, currency, locale),
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
                if (order.awaitingCardPayment) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.businessShopAwaitingCardPayment,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered icon + message, scrollable so RefreshIndicator still works.
class ShopEmptyState extends StatelessWidget {
  const ShopEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
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
                    Icon(icon, size: 56, color: cs.outline),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                    if (action != null) ...[
                      const SizedBox(height: 16),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShopErrorState extends StatelessWidget {
  const ShopErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yes/no confirmation; returns true when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonBack),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return ok == true;
}
