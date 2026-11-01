import 'business.dart';

/// A gym membership row of a search result.
class MemberEntry {
  final String id;
  final String gymId;

  const MemberEntry({required this.id, required this.gymId});

  factory MemberEntry.fromJson(Map<String, dynamic> json) => MemberEntry(
    id: json['id'] as String,
    gymId: json['gym_id'] as String,
  );
}

/// A role (held or offered) on a business's team, from a search result.
class TeamEntry {
  final String businessId;
  final BusinessRole role;

  /// 'active' or 'invited'.
  final String status;

  const TeamEntry({
    required this.businessId,
    required this.role,
    required this.status,
  });

  bool get isActive => status == 'active';
}

/// A row of GET /search-users (owners, staff and super users only).
class UserSearchResult {
  final String id;
  final String username;
  final String email;
  final String name;
  final String lastName;
  final bool isTrainer;
  final List<MemberEntry> memberEntries;
  final List<TeamEntry> teamEntries;

  const UserSearchResult({
    required this.id,
    required this.username,
    required this.email,
    required this.name,
    required this.lastName,
    this.isTrainer = false,
    this.memberEntries = const [],
    this.teamEntries = const [],
  });

  String get fullName => '$name $lastName'.trim();

  /// Whether they hold [role] (accepted, not just invited) anywhere.
  bool holds(BusinessRole role) =>
      teamEntries.any((e) => e.role == role && e.isActive);

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> rows(Object? raw) => [
      if (raw is List)
        for (final e in raw)
          if (e is Map<String, dynamic>) e,
    ];

    return UserSearchResult(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String,
      lastName: json['last_name'] as String,
      isTrainer: json['is_trainer'] as bool? ?? false,
      memberEntries: rows(json['member_entries']).map(MemberEntry.fromJson).toList(),
      teamEntries: [
        for (final e in rows(json['team_entries']))
          if (BusinessRole.tryParse(e['role'] as String?) case final role?)
            TeamEntry(
              businessId: e['business_id'] as String,
              role: role,
              status: e['status'] as String? ?? 'active',
            ),
      ],
    );
  }
}
