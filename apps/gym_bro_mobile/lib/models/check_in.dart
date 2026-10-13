// Gym check-ins.

int _int(Object? v) => v == null ? 0 : int.parse(v.toString());

DateTime _time(Object? v) => DateTime.parse(v as String).toLocal();

/// A gym the caller can check in at (GET /check-ins/gyms).
class CheckInGym {
  final String gymId;
  final String name;
  final String? logo;
  final bool isMember;
  final bool isStaff;

  const CheckInGym({
    required this.gymId,
    required this.name,
    this.logo,
    required this.isMember,
    required this.isStaff,
  });

  factory CheckInGym.fromJson(Map<String, dynamic> json) => CheckInGym(
    gymId: json['gym_id'] as String,
    name: json['name'] as String? ?? '',
    logo: json['logo'] as String?,
    isMember: json['is_member'] as bool? ?? false,
    isStaff: json['is_staff'] as bool? ?? false,
  );
}

/// Signed, short-lived QR payload (GET /check-ins/token).
class CheckInToken {
  final String token;
  final DateTime expiresAt;
  final int ttlSeconds;
  final String gymId;
  final String gymName;

  const CheckInToken({
    required this.token,
    required this.expiresAt,
    required this.ttlSeconds,
    required this.gymId,
    required this.gymName,
  });

  factory CheckInToken.fromJson(Map<String, dynamic> json) => CheckInToken(
    token: json['token'] as String,
    expiresAt: _time(json['expires_at']),
    ttlSeconds: _int(json['ttl_seconds'] ?? 300),
    gymId: json['gym_id'] as String? ?? '',
    gymName: json['gym_name'] as String? ?? '',
  );

  Duration remaining([DateTime? now]) {
    final d = expiresAt.difference(now ?? DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  /// Refresh a little before expiry so a code on screen is never stale when
  /// scanned (also covers small clock skew between phone and server).
  bool shouldRefresh([DateTime? now]) =>
      remaining(now) <= const Duration(seconds: 20);
}

/// Person shown with a check-in.
class CheckInPerson {
  final String id;
  final String name;
  final String lastName;
  final String? email;
  final String? avatarUrl;

  const CheckInPerson({
    required this.id,
    required this.name,
    required this.lastName,
    this.email,
    this.avatarUrl,
  });

  String get fullName => '$name $lastName'.trim();

  String get initials {
    final s =
        '${name.isNotEmpty ? name[0] : ''}'
                '${lastName.isNotEmpty ? lastName[0] : ''}'
            .toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  factory CheckInPerson.fromJson(Map<String, dynamic> json) => CheckInPerson(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    lastName: json['last_name'] as String? ?? '',
    email: json['email'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );
}

class CheckIn {
  final String id;
  final String gymId;
  final String userId;
  final DateTime checkedInAt;
  final String? checkedInBy;
  final String method; // 'qr' | 'manual'

  /// Present on own history (GET /check-ins?mine=true).
  final String? gymName;

  /// Present on a gym's day list (staff).
  final String? name;
  final String? lastName;
  final String? avatarUrl;

  const CheckIn({
    required this.id,
    required this.gymId,
    required this.userId,
    required this.checkedInAt,
    this.checkedInBy,
    required this.method,
    this.gymName,
    this.name,
    this.lastName,
    this.avatarUrl,
  });

  String get memberName => '${name ?? ''} ${lastName ?? ''}'.trim();

  bool get isManual => method == 'manual';

  factory CheckIn.fromJson(Map<String, dynamic> json) => CheckIn(
    id: json['id'] as String,
    gymId: json['gym_id'] as String,
    userId: json['user_id'] as String,
    checkedInAt: _time(json['checked_in_at']),
    checkedInBy: json['checked_in_by'] as String?,
    method: json['method'] as String? ?? 'qr',
    gymName: json['gym_name'] as String?,
    name: json['name'] as String?,
    lastName: json['last_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );
}

class CheckInMembership {
  final bool isActive;
  final String toDate; // YYYY-MM-DD
  final String typeName;

  const CheckInMembership({
    required this.isActive,
    required this.toDate,
    required this.typeName,
  });

  factory CheckInMembership.fromJson(Map<String, dynamic> json) =>
      CheckInMembership(
        isActive: json['is_active'] as bool? ?? false,
        toDate: json['to_date']?.toString() ?? '',
        typeName: json['type_name'] as String? ?? '',
      );
}

/// What the scanner shows after a scan.
enum CheckInOutcome { checkedIn, noActiveMembership, duplicate, invalid }

/// Response of POST /check-ins.
class CheckInResult {
  final CheckIn checkIn;
  final bool duplicate;
  final CheckInPerson member;
  final CheckInMembership? membership;
  final String? warning;

  const CheckInResult({
    required this.checkIn,
    required this.duplicate,
    required this.member,
    this.membership,
    this.warning,
  });

  /// Duplicate wins over the membership warning: the member is already in.
  CheckInOutcome get outcome {
    if (duplicate) return CheckInOutcome.duplicate;
    if (warning == 'no_active_membership' || membership?.isActive != true) {
      return CheckInOutcome.noActiveMembership;
    }
    return CheckInOutcome.checkedIn;
  }

  factory CheckInResult.fromJson(Map<String, dynamic> json) => CheckInResult(
    checkIn: CheckIn.fromJson(json['check_in'] as Map<String, dynamic>),
    duplicate: json['duplicate'] as bool? ?? false,
    member: CheckInPerson.fromJson(json['member'] as Map<String, dynamic>),
    membership: json['membership'] is Map<String, dynamic>
        ? CheckInMembership.fromJson(json['membership'] as Map<String, dynamic>)
        : null,
    warning: json['warning'] as String?,
  );
}

/// API error with the machine-readable `code` (token_expired, token_invalid,
/// wrong_gym, not_configured…).
class CheckInException implements Exception {
  final String message;
  final String? code;
  final int statusCode;

  const CheckInException(this.message, {this.code, required this.statusCode});

  bool get isNotConfigured => code == 'not_configured';

  @override
  String toString() => message;
}

class MyCheckInStats {
  final int total;
  final int thisMonth;
  final int thisWeek;
  final DateTime? lastCheckInAt;

  const MyCheckInStats({
    required this.total,
    required this.thisMonth,
    required this.thisWeek,
    this.lastCheckInAt,
  });

  factory MyCheckInStats.fromJson(Map<String, dynamic> json) => MyCheckInStats(
    total: _int(json['total']),
    thisMonth: _int(json['this_month']),
    thisWeek: _int(json['this_week']),
    lastCheckInAt: json['last_check_in_at'] == null
        ? null
        : _time(json['last_check_in_at']),
  );
}

class DayCount {
  final DateTime date; // local calendar day
  final int count;
  const DayCount(this.date, this.count);

  factory DayCount.fromJson(Map<String, dynamic> json) =>
      DayCount(DateTime.parse(json['date'] as String), _int(json['count']));
}

class TopMember {
  final CheckInPerson person;
  final int visits;
  final DateTime? lastCheckInAt;

  const TopMember({
    required this.person,
    required this.visits,
    this.lastCheckInAt,
  });

  factory TopMember.fromJson(Map<String, dynamic> json) => TopMember(
    person: CheckInPerson.fromJson(json),
    visits: _int(json['visits']),
    lastCheckInAt: json['last_check_in_at'] == null
        ? null
        : _time(json['last_check_in_at']),
  );
}

/// GET /check-ins/stats?gym_id= (staff).
class GymAttendanceStats {
  final int days;
  final int today;
  final int thisWeek;
  final int total;
  final int uniqueMembers;
  final List<DayCount> perDay;

  /// 24 entries, index = local hour.
  final List<int> busiestHours;
  final List<TopMember> topMembers;

  const GymAttendanceStats({
    required this.days,
    required this.today,
    required this.thisWeek,
    required this.total,
    required this.uniqueMembers,
    required this.perDay,
    required this.busiestHours,
    required this.topMembers,
  });

  factory GymAttendanceStats.fromJson(Map<String, dynamic> json) {
    final hours = List<int>.filled(24, 0);
    for (final h in (json['busiest_hours'] as List? ?? [])) {
      final m = h as Map<String, dynamic>;
      final hour = _int(m['hour']);
      if (hour >= 0 && hour < 24) hours[hour] = _int(m['count']);
    }
    return GymAttendanceStats(
      days: _int(json['days']),
      today: _int(json['today']),
      thisWeek: _int(json['this_week']),
      total: _int(json['total']),
      uniqueMembers: _int(json['unique_members']),
      perDay: (json['per_day'] as List? ?? [])
          .map((e) => DayCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      busiestHours: hours,
      topMembers: (json['top_members'] as List? ?? [])
          .map((e) => TopMember.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  double get averagePerDay => perDay.isEmpty ? 0 : total / perDay.length;

  /// The hours with the most check-ins, busiest first (ties: earlier hour).
  List<int> peakHours([int n = 3]) {
    final idx =
        List<int>.generate(
          24,
          (i) => i,
        ).where((h) => busiestHours[h] > 0).toList()..sort((a, b) {
          final c = busiestHours[b].compareTo(busiestHours[a]);
          return c != 0 ? c : a.compareTo(b);
        });
    return idx.take(n).toList();
  }
}

/// "07:00–08:00" style label for an hour bucket.
String hourRangeLabel(int hour) {
  String two(int h) => (h % 24).toString().padLeft(2, '0');
  return '${two(hour)}:00–${two(hour + 1)}:00';
}

/// Counts the visits in [history] that fall in the same calendar month as [now].
int visitsInMonth(Iterable<CheckIn> history, DateTime now) => history
    .where(
      (c) => c.checkedInAt.year == now.year && c.checkedInAt.month == now.month,
    )
    .length;

/// A round step for a chart's count axis so it shows at most ~[ticks] labels
/// (1, 2, 5, 10, 20, 50…).
int niceAxisStep(int maxValue, {int ticks = 4}) {
  if (maxValue <= ticks) return 1;
  final raw = maxValue / ticks;
  var magnitude = 1;
  while (magnitude * 10 <= raw) {
    magnitude *= 10;
  }
  for (final m in const [1, 2, 5, 10]) {
    if (m * magnitude >= raw) return m * magnitude;
  }
  return 10 * magnitude;
}
