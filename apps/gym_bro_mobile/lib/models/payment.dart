// Payments (Stripe Checkout) for membership invoices, shop orders and
// self-serve membership purchases.
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// Formats [amount] in [currency] (ISO code, any case) for [locale]
/// (e.g. `Localizations.localeOf(context).toString()`), e.g. `$12.50` in
/// English or `12,50 US$` in Serbian. Without a locale, intl's current
/// default locale is used.
String formatMoney(double amount, [String currency = 'usd', String? locale]) {
  try {
    return NumberFormat.simpleCurrency(
      locale: locale,
      name: currency.toUpperCase(),
    ).format(amount);
  } catch (_) {
    return '${amount.toStringAsFixed(2)} ${currency.toUpperCase()}';
  }
}

double _num(dynamic v) => v == null ? 0 : double.parse(v.toString());

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());

/// GET /payments/config
class PaymentsConfig {
  final bool enabled;
  final String currency;

  const PaymentsConfig({required this.enabled, required this.currency});

  static const disabled = PaymentsConfig(enabled: false, currency: 'usd');

  factory PaymentsConfig.fromJson(Map<String, dynamic> json) => PaymentsConfig(
    enabled: json['enabled'] as bool? ?? false,
    currency: (json['currency'] as String?) ?? 'usd',
  );

  String format(double amount, [String? locale]) =>
      formatMoney(amount, currency, locale);
}

enum PaymentStatus {
  pending,
  succeeded,
  failed,
  cancelled,
  refunded;

  static PaymentStatus fromString(String? s) => PaymentStatus.values.firstWhere(
    (v) => v.name == s,
    orElse: () => PaymentStatus.pending,
  );

  String label(AppLocalizations l10n) => switch (this) {
    PaymentStatus.pending => l10n.businessPaymentStatusPending,
    PaymentStatus.succeeded => l10n.businessPaymentStatusPaid,
    PaymentStatus.failed => l10n.businessPaymentStatusFailed,
    PaymentStatus.cancelled => l10n.businessPaymentStatusCancelled,
    PaymentStatus.refunded => l10n.businessPaymentStatusRefunded,
  };
}

/// What a payment is for: 'invoice' | 'order' | 'membership'.
class Payment {
  final String id;
  final String? userId;
  final String kind;
  final String? membershipInvoiceId;
  final String? orderId;
  final String? membershipTypeId;
  final String? membershipId;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Payment({
    required this.id,
    this.userId,
    required this.kind,
    this.membershipInvoiceId,
    this.orderId,
    this.membershipTypeId,
    this.membershipId,
    required this.amount,
    required this.currency,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == PaymentStatus.pending;
  bool get isSucceeded => status == PaymentStatus.succeeded;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as String,
    userId: json['user_id'] as String?,
    kind: json['kind'] as String? ?? 'order',
    membershipInvoiceId: json['membership_invoice_id'] as String?,
    orderId: json['order_id'] as String?,
    membershipTypeId: json['membership_type_id'] as String?,
    membershipId: json['membership_id'] as String?,
    amount: _num(json['amount']),
    currency: json['currency'] as String? ?? 'usd',
    status: PaymentStatus.fromString(json['status'] as String?),
    createdAt: _date(json['created_at']),
    updatedAt: _date(json['updated_at']),
  );
}

/// POST /payments/checkout → where to send the user, and what to poll.
class CheckoutSession {
  final String url;
  final String paymentId;

  const CheckoutSession({required this.url, required this.paymentId});

  factory CheckoutSession.fromJson(Map<String, dynamic> json) =>
      CheckoutSession(
        url: json['url'] as String,
        paymentId: json['payment_id'] as String,
      );
}

/// A membership type offered for self-serve purchase (GET /payments/gyms).
class PurchasableMembershipType {
  final String id;
  final String name;
  final double monthlyCost;

  const PurchasableMembershipType({
    required this.id,
    required this.name,
    required this.monthlyCost,
  });

  factory PurchasableMembershipType.fromJson(Map<String, dynamic> json) =>
      PurchasableMembershipType(
        id: json['id'] as String,
        name: json['name'] as String,
        monthlyCost: _num(json['monthly_cost']),
      );
}

/// A gym with the membership types a member can buy in the app.
class PurchasableGym {
  final String id;
  final String name;
  final String location;
  final String? logo;
  final List<PurchasableMembershipType> types;

  const PurchasableGym({
    required this.id,
    required this.name,
    required this.location,
    this.logo,
    required this.types,
  });

  factory PurchasableGym.fromJson(Map<String, dynamic> json) => PurchasableGym(
    id: json['id'] as String,
    name: json['name'] as String,
    location: json['location'] as String? ?? '',
    logo: json['logo'] as String?,
    types: ((json['types'] as List?) ?? [])
        .map(
          (e) => PurchasableMembershipType.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
  );
}
