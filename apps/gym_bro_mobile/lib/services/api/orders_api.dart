part of '../api_service.dart';

/// Shop storefront and orders.
extension OrdersApi on ApiService {
  /// GET /orders/shops — every shop with its active item count.
  Future<List<StorefrontShop>> getStorefrontShops(String token) async {
    final r = await _client.get(
      Uri.parse('$_base/orders/shops'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => StorefrontShop.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /orders. [items] maps shop item id → quantity. Throws with the
  /// server's message on 409 (out of stock / no longer available) and 400.
  Future<ShopOrder> createOrder(
    String token, {
    required String shopId,
    required Map<String, int> items,
    required OrderPaymentMethod paymentMethod,
    String? note,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/orders'),
      headers: _headers(token),
      body: jsonEncode({
        'shop_id': shopId,
        'items': [
          for (final e in items.entries)
            {'shop_item_id': e.key, 'quantity': e.value},
        ],
        'payment_method': paymentMethod.apiValue,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );
    _check(r);
    return ShopOrder.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// GET /orders — the caller's own orders.
  Future<List<ShopOrder>> getMyOrders(String token,
      {OrderStatus? status}) async {
    final q = status == null ? '' : '?status=${status.apiValue}';
    final r = await _client.get(
      Uri.parse('$_base/orders$q'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => ShopOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /orders?shop_id= — a shop's orders (owners and vendors).
  Future<List<ShopOrder>> getShopOrders(String token, String shopId,
      {OrderStatus? status}) async {
    final params = [
      'shop_id=$shopId',
      if (status != null) 'status=${status.apiValue}',
    ];
    final r = await _client.get(
      Uri.parse('$_base/orders?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => ShopOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShopOrder> getOrder(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/orders/$id'),
      headers: _headers(token),
    );
    _check(r);
    return ShopOrder.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// PUT /orders/:id/status.
  Future<ShopOrder> updateOrderStatus(
      String token, String id, OrderStatus status) async {
    final r = await _client.put(
      Uri.parse('$_base/orders/$id/status'),
      headers: _headers(token),
      body: jsonEncode({'status': status.apiValue}),
    );
    _check(r);
    return ShopOrder.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
