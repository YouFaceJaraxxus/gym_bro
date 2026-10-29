// Classes as trainers manage them (GET /class-series), their invites, and a
// trainer's customers (GET /customers).

import 'people.dart';

DateTime? _dateOrNull(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// A calendar date from the API ("YYYY-MM-DD"), at local midnight.
DateTime? _ymdOrNull(dynamic v) {
  if (v is! String || v.length < 10) return null;
  final p = v.substring(0, 10).split('-').map(int.tryParse).toList();
  if (p.length != 3 || p.contains(null)) return null;
  return DateTime(p[0]!, p[1]!, p[2]!);
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _int(dynamic v, [int fallback = 0]) => v == null ? fallback : int.tryParse(v.toString()) ?? fallback;

enum ClassRepeat {
  none,
  daily,
  weekly;

  static ClassRepeat parse(Object? v) =>
      ClassRepeat.values.firstWhere((r) => r.name == v, orElse: () => ClassRepeat.none);
}

/// active: has (or will get) sessions; paused: switched off by the trainer;
/// ended: past its last date with nothing upcoming.
enum ClassSeriesState {
  active,
  paused,
  ended;

  static ClassSeriesState parse(Object? v) =>
      ClassSeriesState.values.firstWhere((s) => s.name == v, orElse: () => ClassSeriesState.active);
}

enum EnrollmentStatus {
  pending,
  accepted,
  declined;

  static EnrollmentStatus? tryParse(Object? v) {
    for (final s in EnrollmentStatus.values) {
      if (s.name == v) return s;
    }
    return null;
  }
}

/// A class: details plus its timetable. Sessions are generated 90 days ahead.
class ClassSeries {
  final String id;
  final String gymId;
  final String gymName;
  final String? trainerId;
  final String? trainerName;
  final String? trainerAvatarUrl;
  final String title;
  final String? description;
  final String? location;
  final int capacity;
  final int durationMinutes;
  final ClassRepeat repeat;

  /// ISO weekdays (1 = Monday … 7 = Sunday); only for [ClassRepeat.weekly].
  final List<int> weekdays;

  /// Local start times each day it runs, "HH:MM", sorted.
  final List<String> times;

  /// IANA name the timetable runs in, e.g. "Europe/Belgrade".
  final String timezone;
  final DateTime startsOn;

  /// Null: keeps going.
  final DateTime? endsOn;
  final bool active;
  final ClassSeriesState state;
  final DateTime? nextStartsAt;
  final int upcomingCount;
  final int completedCount;
  final int enrolledCount;
  final int pendingCount;
  final bool canEdit;

  /// The caller's own invite/enrollment on this class, if any.
  final EnrollmentStatus? myEnrollmentStatus;

  /// Coaches only (GET /class-series/:id); null otherwise.
  final List<SeriesEnrollment>? enrollments;

  /// Only on GET /class-series/invites.
  final PersonSummary? invitedBy;
  final DateTime? invitedAt;

  const ClassSeries({
    required this.id,
    required this.gymId,
    required this.gymName,
    this.trainerId,
    this.trainerName,
    this.trainerAvatarUrl,
    required this.title,
    this.description,
    this.location,
    required this.capacity,
    required this.durationMinutes,
    required this.repeat,
    this.weekdays = const [],
    required this.times,
    required this.timezone,
    required this.startsOn,
    this.endsOn,
    this.active = true,
    this.state = ClassSeriesState.active,
    this.nextStartsAt,
    this.upcomingCount = 0,
    this.completedCount = 0,
    this.enrolledCount = 0,
    this.pendingCount = 0,
    this.canEdit = false,
    this.myEnrollmentStatus,
    this.enrollments,
    this.invitedBy,
    this.invitedAt,
  });

  factory ClassSeries.fromJson(Map<String, dynamic> j) => ClassSeries(
    id: j['id'] as String,
    gymId: j['gym_id'] as String,
    gymName: j['gym_name'] as String? ?? '',
    trainerId: j['trainer_id'] as String?,
    trainerName: j['trainer_name'] as String?,
    trainerAvatarUrl: j['trainer_avatar_url'] as String?,
    title: j['title'] as String? ?? '',
    description: j['description'] as String?,
    location: j['location'] as String?,
    capacity: _int(j['capacity'], 1),
    durationMinutes: _int(j['duration_minutes'], 60),
    repeat: ClassRepeat.parse(j['repeat']),
    weekdays: (j['weekdays'] as List? ?? const []).map((e) => _int(e)).toList(),
    times: (j['times'] as List? ?? const []).map((e) => e.toString()).toList(),
    timezone: j['timezone'] as String? ?? 'UTC',
    startsOn: _ymdOrNull(j['starts_on']) ?? DateTime.now(),
    endsOn: _ymdOrNull(j['ends_on']),
    active: j['active'] as bool? ?? true,
    state: ClassSeriesState.parse(j['state']),
    nextStartsAt: _dateOrNull(j['next_starts_at']),
    upcomingCount: _int(j['upcoming_count']),
    completedCount: _int(j['completed_count']),
    enrolledCount: _int(j['enrolled_count']),
    pendingCount: _int(j['pending_count']),
    canEdit: j['can_edit'] == true,
    myEnrollmentStatus: EnrollmentStatus.tryParse(j['my_enrollment_status']),
    enrollments: (j['enrollments'] as List?)
        ?.map((e) => SeriesEnrollment.fromJson(e as Map<String, dynamic>))
        .toList(),
    invitedBy: j['invited_by'] is Map<String, dynamic>
        ? PersonSummary.fromJson(j['invited_by'] as Map<String, dynamic>)
        : null,
    invitedAt: _dateOrNull(j['invited_at']),
  );
}

/// Someone invited to a class, and where their invite stands.
class SeriesEnrollment {
  final String userId;
  final String username;
  final String name;
  final String lastName;
  final String? avatarUrl;
  final EnrollmentStatus status;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  const SeriesEnrollment({
    required this.userId,
    required this.username,
    required this.name,
    required this.lastName,
    this.avatarUrl,
    required this.status,
    this.createdAt,
    this.respondedAt,
  });

  String get fullName => '$name $lastName'.trim();

  String get initials {
    final s = '${name.isNotEmpty ? name[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  factory SeriesEnrollment.fromJson(Map<String, dynamic> j) => SeriesEnrollment(
    userId: j['user_id'] as String,
    username: j['username'] as String? ?? '',
    name: j['name'] as String? ?? '',
    lastName: j['last_name'] as String? ?? '',
    avatarUrl: j['avatar_url'] as String?,
    status: EnrollmentStatus.tryParse(j['status']) ?? EnrollmentStatus.pending,
    createdAt: _dateOrNull(j['created_at']),
    respondedAt: _dateOrNull(j['responded_at']),
  );
}

/// One of the trainer's classes a customer is invited to or takes.
class CustomerClass {
  final String seriesId;
  final String title;
  final EnrollmentStatus status;
  final bool active;

  const CustomerClass({required this.seriesId, required this.title, required this.status, this.active = true});

  factory CustomerClass.fromJson(Map<String, dynamic> j) => CustomerClass(
    seriesId: j['series_id'] as String,
    title: j['title'] as String? ?? '',
    status: EnrollmentStatus.tryParse(j['status']) ?? EnrollmentStatus.pending,
    active: j['active'] as bool? ?? true,
  );
}

/// A trainer's customer (GET /customers).
class Customer {
  final String userId;
  final String username;
  final String name;
  final String lastName;
  final String? avatarUrl;

  /// Pending until they accept the trainer's invite (or any class invite).
  final bool accepted;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final List<CustomerClass> classes;

  const Customer({
    required this.userId,
    required this.username,
    required this.name,
    required this.lastName,
    this.avatarUrl,
    required this.accepted,
    this.createdAt,
    this.acceptedAt,
    this.classes = const [],
  });

  String get fullName => '$name $lastName'.trim();

  String get initials {
    final s = '${name.isNotEmpty ? name[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    userId: j['user_id'] as String,
    username: j['username'] as String? ?? '',
    name: j['name'] as String? ?? '',
    lastName: j['last_name'] as String? ?? '',
    avatarUrl: j['avatar_url'] as String?,
    accepted: j['status'] == 'accepted',
    createdAt: _dateOrNull(j['created_at']),
    acceptedAt: _dateOrNull(j['accepted_at']),
    classes: (j['classes'] as List? ?? const [])
        .map((e) => CustomerClass.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Someone a trainer can add as a customer (GET /customers/eligible).
class EligibleCustomer {
  final String id;
  final String username;
  final String name;
  final String lastName;
  final String? avatarUrl;
  final bool followsYou;
  final bool isMember;

  /// 'pending' / 'accepted' when already a customer; null otherwise.
  final String? customerStatus;

  const EligibleCustomer({
    required this.id,
    required this.username,
    required this.name,
    required this.lastName,
    this.avatarUrl,
    this.followsYou = false,
    this.isMember = false,
    this.customerStatus,
  });

  String get fullName => '$name $lastName'.trim();

  String get initials {
    final s = '${name.isNotEmpty ? name[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  factory EligibleCustomer.fromJson(Map<String, dynamic> j) => EligibleCustomer(
    id: j['id'] as String,
    username: j['username'] as String? ?? '',
    name: j['name'] as String? ?? '',
    lastName: j['last_name'] as String? ?? '',
    avatarUrl: j['avatar_url'] as String?,
    followsYou: j['follows_you'] as bool? ?? false,
    isMember: j['is_member'] as bool? ?? false,
    customerStatus: j['customer_status'] as String?,
  );
}
