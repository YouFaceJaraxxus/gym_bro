class UserRoleEntry {
  final String id;
  final String type; // 'member' | 'employee' | 'employee_trainer' | 'trainer' | 'gym_owner' | 'shop_owner' | 'shop_vendor'
  final String? gymId;
  final String? shopId;

  const UserRoleEntry({
    required this.id,
    required this.type,
    this.gymId,
    this.shopId,
  });

  factory UserRoleEntry.fromJson(Map<String, dynamic> json, String type) =>
      UserRoleEntry(
        id: json['id'] as String,
        type: type,
        gymId: json['gym_id'] as String?,
        shopId: json['shop_id'] as String?,
      );
}

class UserSearchResult {
  final String id;
  final String username;
  final String email;
  final String name;
  final String lastName;
  final String role;
  final List<UserRoleEntry> roleEntries;

  const UserSearchResult({
    required this.id,
    required this.username,
    required this.email,
    required this.name,
    required this.lastName,
    required this.role,
    required this.roleEntries,
  });

  String get fullName => '$name $lastName'.trim();

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    final entries = <UserRoleEntry>[];

    void add(String type, Object? raw) {
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) entries.add(UserRoleEntry.fromJson(e, type));
        }
      }
    }

    add('member', json['member_entries']);
    add('employee', json['employee_entries']);
    add('employee_trainer', json['employee_trainer_entries']);
    add('trainer', json['trainer_entries']);
    add('gym_owner', json['gym_owner_entries']);
    add('shop_owner', json['shop_owner_entries']);
    add('shop_vendor', json['shop_vendor_entries']);

    return UserSearchResult(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      lastName: json['last_name'] as String,
      role: json['role'] as String? ?? 'member',
      roleEntries: entries,
    );
  }
}
