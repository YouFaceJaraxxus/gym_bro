import 'package:intl/intl.dart';

/// Localized weekday name for an ISO weekday (1 = Monday … 7 = Sunday),
/// e.g. `Mon` / `pon` (or `Monday` / `ponedeljak` with [abbreviated] false).
/// [locale] is usually `Localizations.localeOf(context).toString()`.
String weekdayLabel(int isoWeekday, String locale, {bool abbreviated = true}) {
  // 1 January 2024 was a Monday.
  final day = DateTime(2024, 1, isoWeekday);
  return (abbreviated ? DateFormat.E(locale) : DateFormat.EEEE(locale)).format(
    day,
  );
}

/// What someone is at a business. Staff (front desk / shop staff) is never
/// shown publicly; owners and trainers are.
enum BusinessRole {
  owner,
  staff,
  trainer;

  static BusinessRole? tryParse(String? v) => switch (v) {
    'owner' => BusinessRole.owner,
    'staff' => BusinessRole.staff,
    'trainer' => BusinessRole.trainer,
    _ => null,
  };

  String get apiValue => name;

  static List<BusinessRole> listFrom(dynamic json) => [
    for (final v in (json as List? ?? [])) ?tryParse(v as String?),
  ];
}

/// A business must be approved by a super user before its owner tools work.
enum BusinessStatus {
  pending,
  approved,
  rejected,
  blocked;

  static BusinessStatus parse(String? v) => switch (v) {
    'approved' => BusinessStatus.approved,
    'rejected' => BusinessStatus.rejected,
    'blocked' => BusinessStatus.blocked,
    _ => BusinessStatus.pending,
  };
}

/// A small person reference on a business profile (owners, trainers).
class BusinessPerson {
  final String id;
  final String username;
  final String name;
  final String lastName;
  final String? avatarUrl;

  const BusinessPerson({
    required this.id,
    required this.username,
    required this.name,
    required this.lastName,
    this.avatarUrl,
  });

  String get fullName => '$name $lastName'.trim();

  factory BusinessPerson.fromJson(Map<String, dynamic> json) => BusinessPerson(
    id: json['id'] as String,
    username: json['username'] as String? ?? '',
    name: json['name'] as String? ?? '',
    lastName: json['last_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
  );
}

/// A gym, a shop, or both. GET /businesses/:id adds the profile extras
/// (followers, team, my roles); lists leave them at their defaults.
class Business {
  final String id;
  final String name;
  final String location;
  final String? logo;
  final String workingHoursFrom;
  final String workingHoursTo;
  final List<int> workingWeekdays;
  final bool hasGym;
  final bool hasShop;
  final BusinessStatus status;
  final String? bio;
  final String? website;
  final String? phone;
  final double? latitude;
  final double? longitude;

  /// Why it was rejected or blocked; only for its team and super users.
  final String? reviewNote;
  final int followerCount;
  final bool isFollowing;
  final List<BusinessRole> myRoles;
  final List<BusinessRole> myInvites;
  final List<BusinessPerson> owners;
  final List<BusinessPerson> trainers;

  const Business({
    required this.id,
    required this.name,
    required this.location,
    this.logo,
    required this.workingHoursFrom,
    required this.workingHoursTo,
    required this.workingWeekdays,
    required this.hasGym,
    required this.hasShop,
    this.status = BusinessStatus.approved,
    this.bio,
    this.website,
    this.phone,
    this.latitude,
    this.longitude,
    this.reviewNote,
    this.followerCount = 0,
    this.isFollowing = false,
    this.myRoles = const [],
    this.myInvites = const [],
    this.owners = const [],
    this.trainers = const [],
  });

  bool get isOwner => myRoles.contains(BusinessRole.owner);
  bool get isStaff => myRoles.contains(BusinessRole.staff);
  bool get isTrainer => myRoles.contains(BusinessRole.trainer);
  bool get onTeam => myRoles.isNotEmpty;
  bool get isApproved => status == BusinessStatus.approved;

  /// Owners and staff edit the profile (owners also before approval).
  bool get canEditProfile =>
      (isOwner && status != BusinessStatus.blocked) || (isStaff && isApproved);

  static double? _double(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  factory Business.fromJson(Map<String, dynamic> json) => Business(
    id: json['id'] as String,
    name: json['name'] as String,
    location: json['location'] as String? ?? '',
    logo: json['logo'] as String?,
    workingHoursFrom: json['working_hours_from'] as String? ?? '',
    workingHoursTo: json['working_hours_to'] as String? ?? '',
    workingWeekdays: List<int>.from(json['working_weekdays'] as List? ?? []),
    hasGym: json['has_gym'] as bool? ?? false,
    hasShop: json['has_shop'] as bool? ?? false,
    status: BusinessStatus.parse(json['status'] as String?),
    bio: json['bio'] as String?,
    website: json['website'] as String?,
    phone: json['phone'] as String?,
    latitude: _double(json['latitude']),
    longitude: _double(json['longitude']),
    reviewNote: json['review_note'] as String?,
    followerCount: json['follower_count'] == null
        ? 0
        : int.parse(json['follower_count'].toString()),
    isFollowing: json['is_following'] as bool? ?? false,
    myRoles: BusinessRole.listFrom(json['my_roles']),
    myInvites: BusinessRole.listFrom(json['my_invites']),
    owners: (json['owners'] as List? ?? [])
        .map((e) => BusinessPerson.fromJson(e as Map<String, dynamic>))
        .toList(),
    trainers: (json['trainers'] as List? ?? [])
        .map((e) => BusinessPerson.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// A business the signed-in user is on the team of (from their profile).
class MyBusiness {
  final String id;
  final String name;
  final String? logo;
  final bool hasGym;
  final bool hasShop;
  final BusinessStatus status;
  final String? reviewNote;
  final List<BusinessRole> roles;

  const MyBusiness({
    required this.id,
    required this.name,
    this.logo,
    required this.hasGym,
    required this.hasShop,
    required this.status,
    this.reviewNote,
    required this.roles,
  });

  bool get isOwner => roles.contains(BusinessRole.owner);

  factory MyBusiness.fromJson(Map<String, dynamic> json) => MyBusiness(
    id: json['id'] as String,
    name: json['name'] as String,
    logo: json['logo'] as String?,
    hasGym: json['has_gym'] as bool? ?? false,
    hasShop: json['has_shop'] as bool? ?? false,
    status: BusinessStatus.parse(json['status'] as String?),
    reviewNote: json['review_note'] as String?,
    roles: BusinessRole.listFrom(json['roles']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'logo': logo,
    'has_gym': hasGym,
    'has_shop': hasShop,
    'status': status.name,
    'review_note': reviewNote,
    'roles': roles.map((r) => r.apiValue).toList(),
  };
}

/// One person on a business's team, with every role they hold or were
/// offered (GET /businesses/:id/team).
class TeamMember {
  final String userId;
  final String username;
  final String name;
  final String lastName;
  final String? avatarUrl;
  final String? email;
  final List<({BusinessRole role, bool active})> roles;

  const TeamMember({
    required this.userId,
    required this.username,
    required this.name,
    required this.lastName,
    this.avatarUrl,
    this.email,
    required this.roles,
  });

  String get fullName => '$name $lastName'.trim();

  bool holds(BusinessRole role) => roles.any((r) => r.role == role && r.active);
  bool invitedAs(BusinessRole role) =>
      roles.any((r) => r.role == role && !r.active);

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
    userId: json['user_id'] as String,
    username: json['username'] as String? ?? '',
    name: json['name'] as String? ?? '',
    lastName: json['last_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    email: json['email'] as String?,
    roles: [
      for (final r in (json['roles'] as List? ?? []).cast<Map<String, dynamic>>())
        if (BusinessRole.tryParse(r['role'] as String?) case final role?)
          (role: role, active: r['status'] == 'active'),
    ],
  );
}

/// An unanswered invite to join a business's team (GET /businesses/invites).
class BusinessInvite {
  final String businessId;
  final String businessName;
  final String? logo;
  final bool hasGym;
  final bool hasShop;
  final BusinessRole role;
  final String? inviterName;
  final DateTime createdAt;

  const BusinessInvite({
    required this.businessId,
    required this.businessName,
    this.logo,
    required this.hasGym,
    required this.hasShop,
    required this.role,
    this.inviterName,
    required this.createdAt,
  });

  factory BusinessInvite.fromJson(Map<String, dynamic> json) => BusinessInvite(
    businessId: json['business_id'] as String,
    businessName: json['business_name'] as String? ?? '',
    logo: json['logo'] as String?,
    hasGym: json['has_gym'] as bool? ?? false,
    hasShop: json['has_shop'] as bool? ?? false,
    role: BusinessRole.tryParse(json['role'] as String?) ?? BusinessRole.staff,
    inviterName: json['inviter_name'] == null
        ? null
        : '${json['inviter_name']} ${json['inviter_last_name'] ?? ''}'.trim(),
    createdAt: DateTime.parse(json['created_at'].toString()),
  );
}

/// A business in the super user's review queue, with who applied.
class BusinessApplication {
  final Business business;
  final String? applicantId;
  final String? applicantName;
  final String? applicantUsername;
  final String? applicantEmail;
  final String? applicantAvatarUrl;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const BusinessApplication({
    required this.business,
    this.applicantId,
    this.applicantName,
    this.applicantUsername,
    this.applicantEmail,
    this.applicantAvatarUrl,
    required this.createdAt,
    this.reviewedAt,
  });

  factory BusinessApplication.fromJson(Map<String, dynamic> json) =>
      BusinessApplication(
        business: Business.fromJson(json),
        applicantId: json['applicant_id'] as String?,
        applicantName: json['applicant_name'] == null
            ? null
            : '${json['applicant_name']} ${json['applicant_last_name'] ?? ''}'
                  .trim(),
        applicantUsername: json['applicant_username'] as String?,
        applicantEmail: json['applicant_email'] as String?,
        applicantAvatarUrl: json['applicant_avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'].toString()),
        reviewedAt: json['reviewed_at'] == null
            ? null
            : DateTime.parse(json['reviewed_at'].toString()),
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
