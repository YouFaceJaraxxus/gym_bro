// Gym classes and bookings (GET /classes, /classes/:id, /classes/coaching-gyms).

import '../l10n/app_localizations.dart';

int _int(dynamic v, [int fallback = 0]) =>
    v == null ? fallback : int.tryParse(v.toString()) ?? fallback;

int? _intOrNull(dynamic v) => v == null ? null : int.tryParse(v.toString());

DateTime _date(dynamic v) => DateTime.parse(v.toString()).toLocal();

DateTime? _dateOrNull(dynamic v) =>
    v == null ? null : DateTime.parse(v.toString()).toLocal();

/// Booking status, mirroring the API's `booking_status` enum.
enum BookingStatus {
  booked,
  waitlisted,
  cancelled,
  attended,
  noShow;

  static BookingStatus? tryParse(String? value) => switch (value) {
    'booked' => BookingStatus.booked,
    'waitlisted' => BookingStatus.waitlisted,
    'cancelled' => BookingStatus.cancelled,
    'attended' => BookingStatus.attended,
    'no_show' => BookingStatus.noShow,
    _ => null,
  };

  String get apiValue => switch (this) {
    BookingStatus.booked => 'booked',
    BookingStatus.waitlisted => 'waitlisted',
    BookingStatus.cancelled => 'cancelled',
    BookingStatus.attended => 'attended',
    BookingStatus.noShow => 'no_show',
  };

  String label(AppLocalizations l10n) => switch (this) {
    BookingStatus.booked => l10n.trainingBookingBooked,
    BookingStatus.waitlisted => l10n.trainingBookingWaitlisted,
    BookingStatus.cancelled => l10n.trainingBookingCancelled,
    BookingStatus.attended => l10n.trainingBookingAttended,
    BookingStatus.noShow => l10n.trainingBookingNoShow,
  };

  /// True when this booking occupies a seat in the class.
  bool get takesSeat =>
      this == BookingStatus.booked ||
      this == BookingStatus.attended ||
      this == BookingStatus.noShow;
}

/// Someone a coach can add to a class (GET /classes/:id/addable): a member of
/// the gym or one of the coach's approved followers.
class AddablePerson {
  final String id;
  final String username;
  final String name;
  final String lastName;
  final String? avatarUrl;
  final bool isMember;
  final bool followsYou;

  /// Their current booking on the class, if any (never cancelled).
  final BookingStatus? bookingStatus;

  const AddablePerson({
    required this.id,
    required this.username,
    required this.name,
    required this.lastName,
    this.avatarUrl,
    required this.isMember,
    required this.followsYou,
    this.bookingStatus,
  });

  String get fullName => '$name $lastName'.trim();

  String get initials {
    final s = '${name.isNotEmpty ? name[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  factory AddablePerson.fromJson(Map<String, dynamic> j) => AddablePerson(
    id: j['id'] as String,
    username: j['username'] as String? ?? '',
    name: j['name'] as String? ?? '',
    lastName: j['last_name'] as String? ?? '',
    avatarUrl: j['avatar_url'] as String?,
    isMember: j['is_member'] as bool? ?? false,
    followsYou: j['follows_you'] as bool? ?? false,
    bookingStatus: BookingStatus.tryParse(j['booking_status'] as String?),
  );
}

/// One person's booking. Roster entries (from GET /classes/:id for coaches)
/// carry name/avatar; booking responses carry classId and waitlistPosition.
class ClassBooking {
  final String id;
  final String? classId;
  final String userId;
  final String? name;
  final String? lastName;
  final String? avatarUrl;
  final BookingStatus status;
  final DateTime createdAt;
  final int? waitlistPosition;

  const ClassBooking({
    required this.id,
    this.classId,
    required this.userId,
    this.name,
    this.lastName,
    this.avatarUrl,
    required this.status,
    required this.createdAt,
    this.waitlistPosition,
  });

  String get fullName => '${name ?? ''} ${lastName ?? ''}'.trim();

  String get initials {
    final a = (name ?? '').isNotEmpty ? name![0] : '';
    final b = (lastName ?? '').isNotEmpty ? lastName![0] : '';
    final s = '$a$b'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  factory ClassBooking.fromJson(Map<String, dynamic> j) => ClassBooking(
    id: j['id'] as String,
    classId: j['class_id'] as String?,
    userId: j['user_id'] as String,
    name: j['name'] as String?,
    lastName: j['last_name'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    status:
        BookingStatus.tryParse(j['status'] as String?) ?? BookingStatus.booked,
    createdAt: _date(j['created_at']),
    waitlistPosition: _intOrNull(j['waitlist_position']),
  );

  ClassBooking copyWith({BookingStatus? status}) => ClassBooking(
    id: id,
    classId: classId,
    userId: userId,
    name: name,
    lastName: lastName,
    avatarUrl: avatarUrl,
    status: status ?? this.status,
    createdAt: createdAt,
    waitlistPosition: waitlistPosition,
  );
}

class GymClass {
  final String id;
  final String gymId;
  final String? trainerId;
  final String title;
  final String? description;
  final String? location;

  /// Local time.
  final DateTime startsAt;

  /// Local time.
  final DateTime endsAt;
  final int capacity;

  /// The class (timetable) this session belongs to; every session has one.
  final String? seriesId;

  /// True when the session's class repeats (a one-off has a series too).
  final bool isRecurring;
  final DateTime? cancelledAt;
  final String? createdBy;
  final String gymName;
  final String? trainerName;
  final String? trainerAvatarUrl;
  final int bookedCount;
  final int waitlistCount;
  final String? myBookingId;
  final BookingStatus? myBookingStatus;
  final int? myWaitlistPosition;

  /// True when the caller coaches/staffs at this class's gym.
  final bool canCoach;

  /// Roster — only present on GET /classes/:id for coaches.
  final List<ClassBooking>? bookings;

  const GymClass({
    required this.id,
    required this.gymId,
    this.trainerId,
    required this.title,
    this.description,
    this.location,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    this.seriesId,
    this.isRecurring = false,
    this.cancelledAt,
    this.createdBy,
    required this.gymName,
    this.trainerName,
    this.trainerAvatarUrl,
    required this.bookedCount,
    required this.waitlistCount,
    this.myBookingId,
    this.myBookingStatus,
    this.myWaitlistPosition,
    this.canCoach = false,
    this.bookings,
  });

  bool get isCancelled => cancelledAt != null;
  bool get isSeries => isRecurring;
  bool get hasStarted => !startsAt.isAfter(DateTime.now());
  bool get isPast => !endsAt.isAfter(DateTime.now());
  bool get isFull => bookedCount >= capacity;
  int get spotsLeft => (capacity - bookedCount).clamp(0, capacity);
  Duration get duration => endsAt.difference(startsAt);

  /// Booked or waitlisted (an active booking the caller can cancel).
  bool get hasActiveBooking =>
      myBookingStatus == BookingStatus.booked ||
      myBookingStatus == BookingStatus.waitlisted;

  factory GymClass.fromJson(Map<String, dynamic> j) => GymClass(
    id: j['id'] as String,
    gymId: j['gym_id'] as String,
    trainerId: j['trainer_id'] as String?,
    title: j['title'] as String? ?? '',
    description: j['description'] as String?,
    location: j['location'] as String?,
    startsAt: _date(j['starts_at']),
    endsAt: _date(j['ends_at']),
    capacity: _int(j['capacity'], 1),
    seriesId: j['series_id'] as String?,
    // Older API responses only had series_id for repeating classes.
    isRecurring: (j['is_recurring'] as bool?) ?? j['series_id'] != null,
    cancelledAt: _dateOrNull(j['cancelled_at']),
    createdBy: j['created_by'] as String?,
    gymName: j['gym_name'] as String? ?? '',
    trainerName: j['trainer_name'] as String?,
    trainerAvatarUrl: j['trainer_avatar_url'] as String?,
    bookedCount: _int(j['booked_count']),
    waitlistCount: _int(j['waitlist_count']),
    myBookingId: j['my_booking_id'] as String?,
    myBookingStatus: BookingStatus.tryParse(j['my_booking_status'] as String?),
    myWaitlistPosition: _intOrNull(j['my_waitlist_position']),
    canCoach: j['can_coach'] == true,
    bookings: (j['bookings'] as List?)
        ?.map((e) => ClassBooking.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// A trainer who can be assigned to classes at a gym.
class ClassTrainer {
  final String userId;
  final String name;
  final String lastName;

  const ClassTrainer({
    required this.userId,
    required this.name,
    required this.lastName,
  });

  String get fullName => '$name $lastName'.trim();

  factory ClassTrainer.fromJson(Map<String, dynamic> j) => ClassTrainer(
    userId: j['user_id'] as String,
    name: j['name'] as String? ?? '',
    lastName: j['last_name'] as String? ?? '',
  );
}

/// A gym where the caller can create classes (GET /classes/coaching-gyms).
class CoachingGym {
  final String gymId;
  final String gymName;

  /// Owner/front-desk staff: may assign any trainer, not only themselves.
  final bool canStaff;
  final List<ClassTrainer> trainers;

  const CoachingGym({
    required this.gymId,
    required this.gymName,
    required this.canStaff,
    required this.trainers,
  });

  factory CoachingGym.fromJson(Map<String, dynamic> j) => CoachingGym(
    gymId: j['gym_id'] as String,
    gymName: j['gym_name'] as String? ?? '',
    canStaff: j['can_staff'] == true,
    trainers: ((j['trainers'] as List?) ?? const [])
        .map((e) => ClassTrainer.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
