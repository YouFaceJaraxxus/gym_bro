// Challenges: time-boxed goals people join together (GET /challenges…).
//
// A platform challenge (no business) is for everyone; a gym challenge is for
// the gym's active members and team. Progress counts like streaks: finished
// workouts with a logged set, inside the challenge's dates.

import 'social.dart';

int _toInt(Object? v) => v == null ? 0 : int.tryParse(v.toString()) ?? double.tryParse(v.toString())?.round() ?? 0;

/// 'YYYY-MM-DD' → a local date at midnight.
DateTime _day(Object? v) {
  final p = v.toString().substring(0, 10).split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime? _time(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

String _dayString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum ChallengeMetric {
  workouts('workouts'),
  activeDays('active_days'),
  minutes('minutes'),
  volumeKg('volume_kg'),
  checkIns('check_ins');

  const ChallengeMetric(this.apiValue);

  final String apiValue;

  static ChallengeMetric fromApi(Object? v) {
    for (final m in values) {
      if (m.apiValue == v) return m;
    }
    return workouts;
  }

  /// Check-ins only make sense at one gym.
  bool get gymOnly => this == checkIns;
}

enum ChallengeStatus {
  upcoming,
  active,
  past;

  static ChallengeStatus fromApi(Object? v) => switch (v) {
        'upcoming' => upcoming,
        'past' => past,
        _ => active,
      };
}

class ChallengeGym {
  final String id;
  final String name;
  final String? logo;

  const ChallengeGym({required this.id, required this.name, this.logo});

  factory ChallengeGym.fromJson(Map<String, dynamic> j) =>
      ChallengeGym(id: j['id'].toString(), name: j['name'] as String? ?? '', logo: j['logo'] as String?);

  static ChallengeGym? maybe(Object? j) => j is Map<String, dynamic> ? ChallengeGym.fromJson(j) : null;
}

/// My place in a challenge.
class ChallengeMine {
  final bool joined;
  final int progress;
  final DateTime? joinedAt;
  final DateTime? completedAt;

  const ChallengeMine({this.joined = false, this.progress = 0, this.joinedAt, this.completedAt});

  bool get completed => completedAt != null;

  factory ChallengeMine.fromJson(Map<String, dynamic>? j) => j == null
      ? const ChallengeMine()
      : ChallengeMine(
          joined: j['joined'] == true,
          progress: _toInt(j['progress']),
          joinedAt: _time(j['joined_at']),
          completedAt: _time(j['completed_at']),
        );
}

class ChallengeBoardEntry {
  final int rank;
  final int progress;
  final DateTime? completedAt;
  final SocialUser? user;

  const ChallengeBoardEntry({required this.rank, required this.progress, this.completedAt, this.user});

  factory ChallengeBoardEntry.fromJson(Map<String, dynamic> j) => ChallengeBoardEntry(
        rank: _toInt(j['rank']),
        progress: _toInt(j['progress']),
        completedAt: _time(j['completed_at']),
        user: SocialUser.maybeFromJson(j['user']),
      );
}

class Challenge {
  final String id;
  final String title;
  final String? description;
  final ChallengeMetric metric;
  final int target;
  final DateTime startsOn;
  final DateTime endsOn;

  /// `monthly:YYYY-MM:<metric>` for the automatic monthly ones.
  final String? autoKey;
  final String? createdBy;

  /// Null for a platform-wide challenge.
  final ChallengeGym? gym;
  final ChallengeStatus status;

  /// Active: days left including today. Upcoming: days until it starts.
  final int daysLeft;
  final int participants;
  final ChallengeMine me;
  final bool canEdit;

  // Detail only.
  final SocialUser? creator;
  final List<ChallengeBoardEntry> leaderboard;
  final int? myRank;

  const Challenge({
    required this.id,
    required this.title,
    this.description,
    required this.metric,
    required this.target,
    required this.startsOn,
    required this.endsOn,
    this.autoKey,
    this.createdBy,
    this.gym,
    this.status = ChallengeStatus.active,
    this.daysLeft = 0,
    this.participants = 0,
    this.me = const ChallengeMine(),
    this.canEdit = false,
    this.creator,
    this.leaderboard = const [],
    this.myRank,
  });

  bool get isPlatform => gym == null;

  /// Automatic monthly challenges have their title made by the app (localized).
  bool get isMonthly => autoKey?.startsWith('monthly:') ?? false;

  /// The month of a monthly challenge.
  DateTime? get month {
    final k = autoKey;
    if (k == null || !isMonthly) return null;
    final p = k.split(':');
    if (p.length < 2) return null;
    final ym = p[1].split('-');
    final y = int.tryParse(ym.first), m = ym.length > 1 ? int.tryParse(ym[1]) : null;
    return y == null || m == null ? null : DateTime(y, m);
  }

  /// 0…1, my progress towards the target.
  double get fraction => target <= 0 ? 0 : (me.progress / target).clamp(0.0, 1.0);

  /// Whole days the challenge runs.
  int get lengthDays => endsOn.difference(startsOn).inDays + 1;

  bool get canJoin => status != ChallengeStatus.past && !me.joined;
  bool get canLeave => status != ChallengeStatus.past && me.joined;

  /// Finished in the last few days: time to celebrate.
  bool completedRecently(DateTime now) {
    final c = me.completedAt;
    return c != null && now.difference(c).inDays < 7;
  }

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: j['id'].toString(),
        title: j['title'] as String? ?? '',
        description: j['description'] as String?,
        metric: ChallengeMetric.fromApi(j['metric']),
        target: _toInt(j['target']),
        startsOn: _day(j['starts_on']),
        endsOn: _day(j['ends_on']),
        autoKey: j['auto_key'] as String?,
        createdBy: j['created_by'] as String?,
        gym: ChallengeGym.maybe(j['business']),
        status: ChallengeStatus.fromApi(j['status']),
        daysLeft: _toInt(j['days_left']),
        participants: _toInt(j['participants']),
        me: ChallengeMine.fromJson(j['me'] as Map<String, dynamic>?),
        canEdit: j['can_edit'] == true,
        creator: SocialUser.maybeFromJson(j['creator']),
        leaderboard: [
          for (final e in j['leaderboard'] as List? ?? const []) ChallengeBoardEntry.fromJson(e as Map<String, dynamic>),
        ],
        myRank: j['my_rank'] == null ? null : _toInt(j['my_rank']),
      );
}

/// GET /challenges: what I can see, and what I may create.
class ChallengeList {
  final DateTime? today;
  final List<Challenge> items;
  final bool canCreatePlatform;
  final List<ChallengeGym> creatableGyms;

  const ChallengeList({this.today, this.items = const [], this.canCreatePlatform = false, this.creatableGyms = const []});

  bool get canCreate => canCreatePlatform || creatableGyms.isNotEmpty;

  /// Ones I'm in that are still running or about to.
  List<Challenge> get mine => items.where((c) => c.me.joined).toList();

  /// Ones I could join.
  List<Challenge> get joinable => items.where((c) => c.canJoin).toList();

  factory ChallengeList.fromJson(Map<String, dynamic> j) => ChallengeList(
        today: j['today'] == null ? null : _day(j['today']),
        items: [for (final c in j['items'] as List? ?? const []) Challenge.fromJson(c as Map<String, dynamic>)],
        canCreatePlatform: j['can_create_platform'] == true,
        creatableGyms: [
          for (final g in j['creatable_gyms'] as List? ?? const []) ChallengeGym.fromJson(g as Map<String, dynamic>),
        ],
      );
}

/// A completed challenge: a medal on a profile.
class ChallengeMedal {
  final String id;
  final String title;
  final ChallengeMetric metric;
  final int target;
  final DateTime endsOn;
  final String? autoKey;
  final ChallengeGym? gym;
  final DateTime? completedAt;

  const ChallengeMedal({
    required this.id,
    required this.title,
    required this.metric,
    required this.target,
    required this.endsOn,
    this.autoKey,
    this.gym,
    this.completedAt,
  });

  factory ChallengeMedal.fromJson(Map<String, dynamic> j) => ChallengeMedal(
        id: j['id'].toString(),
        title: j['title'] as String? ?? '',
        metric: ChallengeMetric.fromApi(j['metric']),
        target: _toInt(j['target']),
        endsOn: _day(j['ends_on']),
        autoKey: j['auto_key'] as String?,
        gym: ChallengeGym.maybe(j['business']),
        completedAt: _time(j['completed_at']),
      );
}

/// GET /challenges/completed?user_id=.
class ChallengeMedals {
  final String userId;
  final int count;
  final List<ChallengeMedal> items;

  /// A private account I don't follow: the count only.
  final bool isPrivate;

  const ChallengeMedals({required this.userId, this.count = 0, this.items = const [], this.isPrivate = false});

  factory ChallengeMedals.fromJson(Map<String, dynamic> j) => ChallengeMedals(
        userId: j['user_id'].toString(),
        count: _toInt(j['count']),
        items: [for (final m in j['items'] as List? ?? const []) ChallengeMedal.fromJson(m as Map<String, dynamic>)],
        isPrivate: j['private'] == true,
      );
}

/// The body of POST /challenges (and, with only what changed, PATCH).
class ChallengeDraft {
  final String? gymId;
  final String title;
  final String? description;
  final ChallengeMetric metric;
  final int target;
  final DateTime startsOn;
  final DateTime endsOn;

  const ChallengeDraft({
    this.gymId,
    required this.title,
    this.description,
    required this.metric,
    required this.target,
    required this.startsOn,
    required this.endsOn,
  });

  Map<String, dynamic> toJson() => {
        'business_id': ?gymId,
        'title': title.trim(),
        'description': (description?.trim().isEmpty ?? true) ? null : description!.trim(),
        'metric': metric.apiValue,
        'target': target,
        'starts_on': _dayString(startsOn),
        'ends_on': _dayString(endsOn),
      };

  /// What an edit of [original] changes (PATCH sends only that).
  Map<String, dynamic> changesFrom(Challenge original) {
    final all = toJson()..remove('business_id');
    final before = {
      'title': original.title,
      'description': original.description,
      'metric': original.metric.apiValue,
      'target': original.target,
      'starts_on': _dayString(original.startsOn),
      'ends_on': _dayString(original.endsOn),
    };
    return {
      for (final e in all.entries)
        if (before[e.key] != e.value) e.key: e.value,
    };
  }
}
