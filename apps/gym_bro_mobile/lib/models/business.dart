class Business {
  final String id;
  final String name;
  final String location;
  final String? logo;
  final String workingHoursFrom;
  final String workingHoursTo;
  final List<int> workingWeekdays;
  final String type; // 'gym' | 'shop'

  const Business({
    required this.id,
    required this.name,
    required this.location,
    this.logo,
    required this.workingHoursFrom,
    required this.workingHoursTo,
    required this.workingWeekdays,
    required this.type,
  });

  factory Business.fromJson(Map<String, dynamic> json) => Business(
        id: json['id'] as String,
        name: json['name'] as String,
        location: json['location'] as String,
        logo: json['logo'] as String?,
        workingHoursFrom: json['working_hours_from'] as String,
        workingHoursTo: json['working_hours_to'] as String,
        workingWeekdays: List<int>.from(json['working_weekdays'] as List),
        type: json['type'] as String,
      );
}

/// One row of `expiring_soon` in GET /businesses/stats.
class ExpiringMembership {
  final String membershipId;
  final String userId;
  final String name;
  final String lastName;
  final String gymId;
  final String gymName;
  final DateTime toDate;

  const ExpiringMembership({
    required this.membershipId,
    required this.userId,
    required this.name,
    required this.lastName,
    required this.gymId,
    required this.gymName,
    required this.toDate,
  });

  String get fullName => '$name $lastName'.trim();

  factory ExpiringMembership.fromJson(Map<String, dynamic> json) =>
      ExpiringMembership(
        membershipId: json['membership_id'] as String,
        userId: json['user_id'] as String,
        name: json['name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        gymId: json['gym_id'] as String,
        gymName: json['gym_name'] as String? ?? '',
        toDate: DateTime.parse(json['to_date'].toString()),
      );
}

/// Aggregates over the gyms the caller manages (GET /businesses/stats).
class BusinessStats {
  final int gyms;
  final int membersTotal;
  final int activeMemberships;
  final int staffTotal;
  final int invoicesMonthCount;
  final double invoicesMonthTotal;
  final int unpaidInvoicesCount;
  final List<ExpiringMembership> expiringSoon;

  const BusinessStats({
    required this.gyms,
    required this.membersTotal,
    required this.activeMemberships,
    required this.staffTotal,
    required this.invoicesMonthCount,
    required this.invoicesMonthTotal,
    required this.unpaidInvoicesCount,
    required this.expiringSoon,
  });

  // Postgres count()/sum() may arrive as strings — parse defensively.
  static int _int(dynamic v) => v == null ? 0 : int.parse(v.toString());

  factory BusinessStats.fromJson(Map<String, dynamic> json) => BusinessStats(
        gyms: _int(json['gyms']),
        membersTotal: _int(json['members_total']),
        activeMemberships: _int(json['active_memberships']),
        staffTotal: _int(json['staff_total']),
        invoicesMonthCount: _int(json['invoices_month_count']),
        invoicesMonthTotal: json['invoices_month_total'] == null
            ? 0
            : double.parse(json['invoices_month_total'].toString()),
        unpaidInvoicesCount: _int(json['unpaid_invoices_count']),
        expiringSoon: (json['expiring_soon'] as List? ?? [])
            .map((e) => ExpiringMembership.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
