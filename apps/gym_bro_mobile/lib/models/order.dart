// Shop orders (the API's `orders` function, stored as invoice rows).
import '../l10n/app_localizations.dart';

double _num(dynamic v) => v == null ? 0 : double.parse(v.toString());

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());

enum OrderStatus {
  pending,
  paid,
  fulfilled,
  cancelled;

  static OrderStatus fromString(String? s) => OrderStatus.values.firstWhere(
    (v) => v.name == s,
    orElse: () => OrderStatus.pending,
  );

  String get apiValue => name;

  String label(AppLocalizations l10n) => switch (this) {
    OrderStatus.pending => l10n.businessOrderStatusPending,
    OrderStatus.paid => l10n.businessOrderStatusPaid,
    OrderStatus.fulfilled => l10n.businessOrderStatusFulfilled,
    OrderStatus.cancelled => l10n.businessOrderStatusCancelled,
  };
}

enum OrderPaymentMethod {
  card,
  payAtPickup;

  static OrderPaymentMethod fromString(String? s) =>
      s == 'card' ? OrderPaymentMethod.card : OrderPaymentMethod.payAtPickup;

  String get apiValue => switch (this) {
    OrderPaymentMethod.card => 'card',
    OrderPaymentMethod.payAtPickup => 'pay_at_pickup',
  };

  String label(AppLocalizations l10n) => switch (this) {
    OrderPaymentMethod.card => l10n.businessPaymentMethodCard,
    OrderPaymentMethod.payAtPickup => l10n.businessPaymentMethodPayAtPickup,
  };
}

class ShopOrderItem {
  final String id;
  final String shopItemId;
  final String name;
  final String? type;
  final String? imageUrl;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  const ShopOrderItem({
    required this.id,
    required this.shopItemId,
    required this.name,
    this.type,
    this.imageUrl,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory ShopOrderItem.fromJson(Map<String, dynamic> json) => ShopOrderItem(
    id: json['id'] as String,
    shopItemId: json['shop_item_id'] as String,
    name: json['name'] as String? ?? 'Item',
    type: json['type'] as String?,
    imageUrl: json['image_url'] as String?,
    quantity: int.parse(json['quantity'].toString()),
    unitPrice: _num(json['unit_price']),
    lineTotal: _num(json['line_total']),
  );
}

class ShopOrder {
  final String id;
  final String shopId;
  final String? shopName;
  final String? shopLogo;
  final String? userId;
  final String? buyerName;
  final String? buyerEmail;
  final OrderStatus status;
  final OrderPaymentMethod paymentMethod;
  final String? note;
  final double total;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final DateTime? fulfilledAt;
  final DateTime? cancelledAt;

  /// Status of the latest card payment attempt ('pending', 'succeeded', …).
  final String? paymentStatus;
  final List<ShopOrderItem> items;
  final int itemCount;

  /// Only on cancel responses: 'refunded' | 'failed' | 'manual'.
  final String? refundStatus;

  const ShopOrder({
    required this.id,
    required this.shopId,
    this.shopName,
    this.shopLogo,
    this.userId,
    this.buyerName,
    this.buyerEmail,
    required this.status,
    required this.paymentMethod,
    this.note,
    required this.total,
    this.createdAt,
    this.paidAt,
    this.fulfilledAt,
    this.cancelledAt,
    this.paymentStatus,
    this.items = const [],
    this.itemCount = 0,
    this.refundStatus,
  });

  /// A card order that still needs paying.
  bool get awaitingCardPayment =>
      status == OrderStatus.pending &&
      paymentMethod == OrderPaymentMethod.card &&
      paymentStatus != 'succeeded';

  factory ShopOrder.fromJson(Map<String, dynamic> json) {
    final items = ((json['items'] as List?) ?? [])
        .map((e) => ShopOrderItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return ShopOrder(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      shopName: json['shop_name'] as String?,
      shopLogo: json['shop_logo'] as String?,
      userId: json['user_id'] as String?,
      buyerName: json['buyer_name'] as String?,
      buyerEmail: json['buyer_email'] as String?,
      status: OrderStatus.fromString(json['status'] as String?),
      paymentMethod: OrderPaymentMethod.fromString(
        json['payment_method'] as String?,
      ),
      note: json['note'] as String?,
      total: _num(json['total']),
      createdAt: _date(json['created_at']),
      paidAt: _date(json['paid_at']),
      fulfilledAt: _date(json['fulfilled_at']),
      cancelledAt: _date(json['cancelled_at']),
      paymentStatus: json['payment_status'] as String?,
      items: items,
      itemCount: json['item_count'] == null
          ? items.fold(0, (n, i) => n + i.quantity)
          : int.parse(json['item_count'].toString()),
      refundStatus: json['refund_status'] as String?,
    );
  }
}

/// A shop in the storefront list (GET /orders/shops).
class StorefrontShop {
  final String id;
  final String name;
  final String location;
  final String? logo;
  final String? workingHoursFrom;
  final String? workingHoursTo;
  final int activeItemCount;

  const StorefrontShop({
    required this.id,
    required this.name,
    required this.location,
    this.logo,
    this.workingHoursFrom,
    this.workingHoursTo,
    required this.activeItemCount,
  });

  factory StorefrontShop.fromJson(Map<String, dynamic> json) => StorefrontShop(
    id: json['id'] as String,
    name: json['name'] as String,
    location: json['location'] as String? ?? '',
    logo: json['logo'] as String?,
    workingHoursFrom: json['working_hours_from'] as String?,
    workingHoursTo: json['working_hours_to'] as String?,
    activeItemCount:
        int.tryParse(json['active_item_count']?.toString() ?? '') ?? 0,
  );
}
