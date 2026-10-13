part of '../api_service.dart';

/// Stripe checkout for invoices, orders and membership purchases.
extension PaymentsApi on ApiService {
  /// GET /payments/config — whether card payments are available, and the
  /// currency all prices are charged in.
  Future<PaymentsConfig> getPaymentsConfig(String token) async {
    final r = await _client.get(
      Uri.parse('$_base/payments/config'),
      headers: _headers(token),
    );
    _check(r);
    return PaymentsConfig.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// POST /payments/checkout — creates a Stripe Checkout Session.
  Future<CheckoutSession> createCheckout(
      String token, Map<String, dynamic> body) async {
    final r = await _client.post(
      Uri.parse('$_base/payments/checkout'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    _check(r);
    return CheckoutSession.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<CheckoutSession> checkoutInvoice(String token, String invoiceId) =>
      createCheckout(token, {'kind': 'invoice', 'invoice_id': invoiceId});

  Future<CheckoutSession> checkoutOrder(String token, String orderId) =>
      createCheckout(token, {'kind': 'order', 'order_id': orderId});

  /// Buys [months] of a membership type, or a monthly auto-renewing
  /// subscription when [autoRenew] is true.
  Future<CheckoutSession> checkoutMembership(
    String token, {
    required String membershipTypeId,
    int months = 1,
    bool autoRenew = false,
  }) =>
      createCheckout(token, {
        'kind': 'membership',
        'membership_type_id': membershipTypeId,
        if (!autoRenew) 'months': months,
        'auto_renew': autoRenew,
      });

  /// GET /payments — the caller's payments, newest first.
  Future<List<Payment>> getMyPayments(String token) async {
    final r = await _client.get(
      Uri.parse('$_base/payments'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => Payment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /payments/:id — polled after returning from Checkout.
  Future<Payment> getPayment(String token, String id) async {
    final r = await _client.get(
      Uri.parse('$_base/payments/$id'),
      headers: _headers(token),
    );
    _check(r);
    return Payment.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// POST /payments/:id/cancel — the user backed out of Checkout.
  Future<Payment> cancelPayment(String token, String id) async {
    final r = await _client.post(
      Uri.parse('$_base/payments/$id/cancel'),
      headers: _headers(token),
    );
    _check(r);
    return Payment.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// GET /payments/gyms — gyms with membership types for sale.
  Future<List<PurchasableGym>> getPurchasableGyms(String token) async {
    final r = await _client.get(
      Uri.parse('$_base/payments/gyms'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => PurchasableGym.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /payments/memberships/:id/cancel-auto-renew — stops the Stripe
  /// subscription at the end of the paid period.
  Future<Membership> cancelMembershipAutoRenew(
      String token, String membershipId) async {
    final r = await _client.post(
      Uri.parse('$_base/payments/memberships/$membershipId/cancel-auto-renew'),
      headers: _headers(token),
    );
    _check(r);
    return Membership.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
