import 'business.dart';

class UserProfile {
  final String id;
  final String username;
  final String email;
  final String name;
  final String lastName;
  final String? avatarUrl;

  /// Platform admin: reviews businesses, manages users.
  final bool isSuperUser;

  /// Switched on by the user (or by accepting a gym's trainer invite).
  final bool isTrainer;

  /// Businesses the user is on the team of, with their roles there. Only
  /// present on the signed-in user's own profile.
  final List<MyBusiness> businesses;

  /// Team invites the user hasn't answered yet (own profile only).
  final int pendingInvites;

  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.name,
    required this.lastName,
    this.avatarUrl,
    this.isSuperUser = false,
    this.isTrainer = false,
    this.businesses = const [],
    this.pendingInvites = 0,
  });

  String get fullName => '$name $lastName'.trim();

  /// Approved businesses where the user holds [role].
  Iterable<MyBusiness> businessesAs(BusinessRole role) => businesses.where(
    (b) => b.status == BusinessStatus.approved && b.roles.contains(role),
  );

  /// Approved gyms where the user works (any role): coaching, classes.
  Iterable<MyBusiness> get workGyms => businesses.where(
    (b) => b.status == BusinessStatus.approved && b.hasGym,
  );

  /// Approved gyms where the user is owner or staff (front desk work).
  Iterable<MyBusiness> get staffedGyms => workGyms.where(
    (b) =>
        b.roles.contains(BusinessRole.owner) ||
        b.roles.contains(BusinessRole.staff),
  );

  /// On the team of at least one approved business, or a super user.
  bool get worksAnywhere =>
      isSuperUser ||
      businesses.any((b) => b.status == BusinessStatus.approved);

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      // Omitted when the caller may not see it (GET /users/:id for others).
      email: json['email'] as String? ?? '',
      name: json['name'] as String,
      lastName: json['last_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      isSuperUser: json['is_super_user'] as bool? ?? false,
      isTrainer: json['is_trainer'] as bool? ?? false,
      businesses: (json['businesses'] as List? ?? [])
          .map((e) => MyBusiness.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingInvites: (json['pending_invites'] as num?)?.toInt() ?? 0,
    );
  }

  /// The user embedded in a row joined with users (GET /members,
  /// /businesses/:id/team): the user's id is `user_id`, and `email` is only
  /// present for staff of that business.
  factory UserProfile.fromRoleRow(Map<String, dynamic> row) {
    return UserProfile(
      id: row['user_id'] as String,
      username: row['username'] as String? ?? '',
      email: row['email'] as String? ?? '',
      name: row['name'] as String? ?? '',
      lastName: row['last_name'] as String? ?? '',
      avatarUrl: row['avatar_url'] as String?,
    );
  }

  UserProfile copyWith({
    String? username,
    String? email,
    String? name,
    String? lastName,
    String? avatarUrl,
    bool? isTrainer,
    List<MyBusiness>? businesses,
    int? pendingInvites,
  }) => UserProfile(
    id: id,
    username: username ?? this.username,
    email: email ?? this.email,
    name: name ?? this.name,
    lastName: lastName ?? this.lastName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    isSuperUser: isSuperUser,
    isTrainer: isTrainer ?? this.isTrainer,
    businesses: businesses ?? this.businesses,
    pendingInvites: pendingInvites ?? this.pendingInvites,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'name': name,
    'last_name': lastName,
    'avatar_url': avatarUrl,
    'is_super_user': isSuperUser,
    'is_trainer': isTrainer,
    'businesses': businesses.map((b) => b.toJson()).toList(),
    'pending_invites': pendingInvites,
  };
}
