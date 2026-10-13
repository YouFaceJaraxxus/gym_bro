import '../l10n/app_localizations.dart';

class GymMembershipType {
  final String id;
  final String name;
  final double monthlyCost;
  final String gymId;
  final bool isActive;

  const GymMembershipType({
    required this.id,
    required this.name,
    required this.monthlyCost,
    required this.gymId,
    required this.isActive,
  });

  factory GymMembershipType.fromJson(Map<String, dynamic> json) =>
      GymMembershipType(
        id: json['id'] as String,
        name: json['name'] as String,
        monthlyCost: double.parse(json['monthly_cost'].toString()),
        gymId: json['gym_id'] as String,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'monthly_cost': monthlyCost,
    'gym_id': gymId,
    'is_active': isActive,
  };
}

class Membership {
  final String id;
  final String userId;
  final String currentMembershipTypeId;
  final DateTime fromDate;
  final DateTime toDate;
  final DateTime lastUpdatedDate;
  final bool isActive;

  /// Renews monthly through a Stripe subscription.
  final bool autoRenew;
  final GymMembershipType? membershipType;

  const Membership({
    required this.id,
    required this.userId,
    required this.currentMembershipTypeId,
    required this.fromDate,
    required this.toDate,
    required this.lastUpdatedDate,
    required this.isActive,
    this.autoRenew = false,
    this.membershipType,
  });

  factory Membership.fromJson(
    Map<String, dynamic> json, {
    GymMembershipType? membershipType,
  }) => Membership(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    currentMembershipTypeId: json['current_membership_type_id'] as String,
    fromDate: DateTime.parse(json['from_date'] as String),
    toDate: DateTime.parse(json['to_date'] as String),
    lastUpdatedDate: DateTime.parse(json['last_updated_date'] as String),
    isActive: json['is_active'] as bool? ?? true,
    autoRenew: json['auto_renew'] as bool? ?? false,
    membershipType: membershipType,
  );

  bool get isExpired => DateTime.now().isAfter(toDate);
}

enum InvoiceStatus {
  unpaid,
  paid,
  voided;

  static InvoiceStatus fromString(String? s) => switch (s) {
    'paid' => InvoiceStatus.paid,
    'void' => InvoiceStatus.voided,
    _ => InvoiceStatus.unpaid,
  };

  String get apiValue => switch (this) {
    InvoiceStatus.unpaid => 'unpaid',
    InvoiceStatus.paid => 'paid',
    InvoiceStatus.voided => 'void',
  };

  String label(AppLocalizations l10n) => switch (this) {
    InvoiceStatus.unpaid => l10n.businessInvoiceStatusUnpaid,
    InvoiceStatus.paid => l10n.businessInvoiceStatusPaid,
    InvoiceStatus.voided => l10n.businessInvoiceStatusVoid,
  };
}

class MembershipInvoice {
  final String id;
  final String membershipId;
  final String membershipTypeId;
  final DateTime issuedAt;
  final double amount;
  final InvoiceStatus status;
  final DateTime? paidAt;

  // Joined fields (present on GET /membership-invoices and PUT responses).
  final String? userId;
  final String? memberName;
  final String? memberLastName;
  final String? gymId;
  final String? gymName;
  final String? membershipTypeName;

  const MembershipInvoice({
    required this.id,
    required this.membershipId,
    required this.membershipTypeId,
    required this.issuedAt,
    required this.amount,
    this.status = InvoiceStatus.unpaid,
    this.paidAt,
    this.userId,
    this.memberName,
    this.memberLastName,
    this.gymId,
    this.gymName,
    this.membershipTypeName,
  });

  String get memberFullName =>
      '${memberName ?? ''} ${memberLastName ?? ''}'.trim();

  factory MembershipInvoice.fromJson(Map<String, dynamic> json) =>
      MembershipInvoice(
        id: json['id'] as String,
        membershipId: json['membership_id'] as String,
        membershipTypeId: json['membership_type_id'] as String,
        issuedAt: DateTime.parse(json['issued_at'] as String),
        amount: double.parse(json['amount'].toString()),
        status: InvoiceStatus.fromString(json['status'] as String?),
        paidAt: json['paid_at'] == null
            ? null
            : DateTime.tryParse(json['paid_at'].toString()),
        userId: json['user_id'] as String?,
        memberName: json['member_name'] as String?,
        memberLastName: json['member_last_name'] as String?,
        gymId: json['gym_id'] as String?,
        gymName: json['gym_name'] as String?,
        membershipTypeName: json['membership_type_name'] as String?,
      );
}
