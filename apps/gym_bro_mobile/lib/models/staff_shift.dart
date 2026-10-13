// Staff shifts (GET /shifts, /shifts/staff).

import '../l10n/app_localizations.dart';

class StaffShift {
  final String id;
  final String gymId;
  final String userId;

  /// Local time.
  final DateTime startsAt;

  /// Local time.
  final DateTime endsAt;
  final String? note;
  final String gymName;
  final String name;
  final String lastName;
  final String? avatarUrl;

  const StaffShift({
    required this.id,
    required this.gymId,
    required this.userId,
    required this.startsAt,
    required this.endsAt,
    this.note,
    required this.gymName,
    required this.name,
    required this.lastName,
    this.avatarUrl,
  });

  String get fullName => '$name $lastName'.trim();
  Duration get duration => endsAt.difference(startsAt);
  bool get isNow {
    final now = DateTime.now();
    return !startsAt.isAfter(now) && endsAt.isAfter(now);
  }

  factory StaffShift.fromJson(Map<String, dynamic> j) => StaffShift(
    id: j['id'] as String,
    gymId: j['gym_id'] as String,
    userId: j['user_id'] as String,
    startsAt: DateTime.parse(j['starts_at'].toString()).toLocal(),
    endsAt: DateTime.parse(j['ends_at'].toString()).toLocal(),
    note: j['note'] as String?,
    gymName: j['gym_name'] as String? ?? '',
    name: j['name'] as String? ?? '',
    lastName: j['last_name'] as String? ?? '',
    avatarUrl: j['avatar_url'] as String?,
  );
}

/// Someone who can be put on a shift at a gym.
class ShiftStaffMember {
  final String userId;
  final String name;
  final String lastName;
  final String? avatarUrl;

  /// Any of 'employee', 'employee_trainer', 'trainer'.
  final List<String> roles;

  const ShiftStaffMember({
    required this.userId,
    required this.name,
    required this.lastName,
    this.avatarUrl,
    required this.roles,
  });

  String get fullName => '$name $lastName'.trim();

  String roleLabel(AppLocalizations l10n) => roles
      .map(
        (r) => switch (r) {
          'employee' => l10n.trainingStaffRoleEmployee,
          'employee_trainer' => l10n.trainingStaffRoleEmployeeTrainer,
          'trainer' => l10n.trainingStaffRoleTrainer,
          _ => r,
        },
      )
      .join(', ');

  factory ShiftStaffMember.fromJson(Map<String, dynamic> j) => ShiftStaffMember(
    userId: j['user_id'] as String,
    name: j['name'] as String? ?? '',
    lastName: j['last_name'] as String? ?? '',
    avatarUrl: j['avatar_url'] as String?,
    roles: ((j['roles'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
  );
}

/// GET /shifts/staff?gym_id= — whether the caller manages the gym's shifts,
/// plus everyone who can be scheduled.
class GymShiftStaff {
  final bool canManage;
  final List<ShiftStaffMember> staff;

  const GymShiftStaff({required this.canManage, required this.staff});

  factory GymShiftStaff.fromJson(Map<String, dynamic> j) => GymShiftStaff(
    canManage: j['can_manage'] == true,
    staff: ((j['staff'] as List?) ?? const [])
        .map((e) => ShiftStaffMember.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
