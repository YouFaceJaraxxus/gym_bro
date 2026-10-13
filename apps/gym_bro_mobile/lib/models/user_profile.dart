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

  String get displayName => switch (this) {
        UserRole.owner => 'Owner',
        UserRole.trainer => 'Trainer',
        UserRole.employee => 'Employee',
        UserRole.employeeTrainer => 'Employee / Trainer',
        UserRole.member => 'Member',
        UserRole.shopVendor => 'Shop Vendor',
        UserRole.superUser => 'Super User',
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
      email: json['email'] as String,
      name: json['name'] as String,
      lastName: json['last_name'] as String,
      role: UserRole.fromString(json['role'] as String? ?? 'member'),
      avatarUrl: json['avatar_url'] as String?,
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
