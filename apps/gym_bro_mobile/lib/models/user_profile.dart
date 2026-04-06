enum UserRole {
  owner,
  trainer,
  employee,
  employeeTrainer,
  member,
  superUser;

  static UserRole fromString(String value) {
    return switch (value) {
      'owner' => UserRole.owner,
      'trainer' => UserRole.trainer,
      'employee' => UserRole.employee,
      'employee_trainer' => UserRole.employeeTrainer,
      'member' => UserRole.member,
      'super_user' => UserRole.superUser,
      _ => UserRole.member,
    };
  }

  String get displayName => switch (this) {
        UserRole.owner => 'Owner',
        UserRole.trainer => 'Trainer',
        UserRole.employee => 'Employee',
        UserRole.employeeTrainer => 'Employee / Trainer',
        UserRole.member => 'Member',
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

  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.name,
    required this.lastName,
    required this.role,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'name': name,
        'last_name': lastName,
        'role': switch (role) {
          UserRole.owner => 'owner',
          UserRole.trainer => 'trainer',
          UserRole.employee => 'employee',
          UserRole.employeeTrainer => 'employee_trainer',
          UserRole.member => 'member',
          UserRole.superUser => 'super_user',
        },
      };
}
