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

  factory GymMembershipType.fromJson(Map<String, dynamic> json) => GymMembershipType(
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
  final GymMembershipType? membershipType;

  const Membership({
    required this.id,
    required this.userId,
    required this.currentMembershipTypeId,
    required this.fromDate,
    required this.toDate,
    required this.lastUpdatedDate,
    required this.isActive,
    this.membershipType,
  });

  factory Membership.fromJson(Map<String, dynamic> json, {GymMembershipType? membershipType}) =>
      Membership(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        currentMembershipTypeId: json['current_membership_type_id'] as String,
        fromDate: DateTime.parse(json['from_date'] as String),
        toDate: DateTime.parse(json['to_date'] as String),
        lastUpdatedDate: DateTime.parse(json['last_updated_date'] as String),
        isActive: json['is_active'] as bool? ?? true,
        membershipType: membershipType,
      );

  bool get isExpired => DateTime.now().isAfter(toDate);
}

class MembershipInvoice {
  final String id;
  final String membershipId;
  final String membershipTypeId;
  final DateTime issuedAt;
  final double amount;

  const MembershipInvoice({
    required this.id,
    required this.membershipId,
    required this.membershipTypeId,
    required this.issuedAt,
    required this.amount,
  });

  factory MembershipInvoice.fromJson(Map<String, dynamic> json) => MembershipInvoice(
        id: json['id'] as String,
        membershipId: json['membership_id'] as String,
        membershipTypeId: json['membership_type_id'] as String,
        issuedAt: DateTime.parse(json['issued_at'] as String),
        amount: double.parse(json['amount'].toString()),
      );
}
