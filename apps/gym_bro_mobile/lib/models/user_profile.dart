import '../l10n/app_localizations.dart';

enum UserRole {
  owner,
  trainer,
  employee,
  employeeTrainer,
  member,
  shopVendor,
  superUser;

  static UserRole fromString(String value) {
    return switch (value) {
      'owner' => UserRole.owner,
      'trainer' => UserRole.trainer,
      'employee' => UserRole.employee,
      'employee_trainer' => UserRole.employeeTrainer,
      'member' => UserRole.member,
      'shop_vendor' => UserRole.shopVendor,
      'super_user' => UserRole.superUser,
      _ => UserRole.member,
    };
  }

  /// The value stored in `users.role` on the API side.
  String get apiValue => switch (this) {
    UserRole.owner => 'owner',
    UserRole.trainer => 'trainer',
    UserRole.employee => 'employee',
    UserRole.employeeTrainer => 'employee_trainer',
    UserRole.member => 'member',
    UserRole.shopVendor => 'shop_vendor',
    UserRole.superUser => 'super_user',
  };

  /// Localized role name for display.
  String label(AppLocalizations l10n) => switch (this) {
    UserRole.owner => l10n.shellRoleOwner,
    UserRole.trainer => l10n.shellRoleTrainer,
    UserRole.employee => l10n.shellRoleEmployee,
    UserRole.employeeTrainer => l10n.shellRoleEmployeeTrainer,
    UserRole.member => l10n.shellRoleMember,
    UserRole.shopVendor => l10n.shellRoleShopVendor,
    UserRole.superUser => l10n.shellRoleSuperUser,
  };
}

class UserProfile {
  final String id;
  final String username;
  final String email;
  final String name;
  final String lastName;
  final UserRole role;
  final String? avatarUrl;

  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.name,
    required this.lastName,
    required this.role,
    this.avatarUrl,
  });

  String get fullName => '$name $lastName'.trim();

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      // Omitted when the caller may not see it (GET /users/:id for others).
      email: json['email'] as String? ?? '',
      name: json['name'] as String,
      lastName: json['last_name'] as String,
      role: UserRole.fromString(json['role'] as String? ?? 'member'),
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  /// The user embedded in a gym/shop role row (GET /members, /employees,
  /// /employee-trainers, /trainers, /gym-owners, /shop-vendors): the user's
  /// id is `user_id`, and `email` is only present for staff of that business.
  factory UserProfile.fromRoleRow(Map<String, dynamic> row) {
    return UserProfile(
      id: row['user_id'] as String,
      username: row['username'] as String? ?? '',
      email: row['email'] as String? ?? '',
      name: row['name'] as String? ?? '',
      lastName: row['last_name'] as String? ?? '',
      role: UserRole.fromString(row['role'] as String? ?? 'member'),
      avatarUrl: row['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'name': name,
    'last_name': lastName,
    'avatar_url': avatarUrl,
    'role': role.apiValue,
  };
}
