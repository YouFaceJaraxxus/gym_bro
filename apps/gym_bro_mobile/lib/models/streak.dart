// Workout streaks, freezes, badges and gym boards (GET /streaks…).
//
// A streak counts finished workouts, not days. A missed planned workout (or,
// in weeks without one, ending the week under the weekly target) ends it
// unless a banked freeze covers the miss. Badges follow STREAK_TIERS on the
// server: bronze 10 · silver 50 · gold 100 · ruby 200 · emerald 365 ·
// sapphire 500 · diamond 1000.

import 'social.dart';

int _toInt(Object? v) => v == null ? 0 : int.tryParse(v.toString()) ?? double.tryParse(v.toString())?.toInt() ?? 0;

int? _toIntOrNull(Object? v) => v == null ? null : int.tryParse(v.toString());

/// 'YYYY-MM-DD' → a local date at midnight.
DateTime _day(Object? v) {
  final s = v.toString();
  final p = s.substring(0, 10).split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

enum StreakTier {
  bronze(10),
  silver(50),
  gold(100),
  ruby(200),
  emerald(365),
  sapphire(500),
  diamond(1000);

  const StreakTier(this.at);

  /// Workouts in a row it takes.
  final int at;

  static StreakTier? fromApi(Object? v) {
    for (final t in values) {
      if (t.name == v) return t;
    }
    return null;
  }

  /// The badge for a streak of [n].
  static StreakTier? forStreak(int n) {
    StreakTier? tier;
    for (final t in values) {
      if (n >= t.at) tier = t;
    }
    return tier;
  }

  /// The next badge above a streak of [n], or null past diamond.
  static StreakTier? nextAbove(int n) {
    for (final t in values) {
      if (t.at > n) return t;
    }
    return null;
  }
}

class StreakWeekEntry {
  final String id;
  final DateTime day;
  final String? name;
  final bool done;
  final bool skipped;

  const StreakWeekEntry({required this.id, required this.day, this.name, this.done = false, this.skipped = false});

  factory StreakWeekEntry.fromJson(Map<String, dynamic> j) => StreakWeekEntry(
        id: j['id'].toString(),
        day: _day(j['day']),
        name: j['name'] as String?,
        done: j['done'] == true,
        skipped: j['skipped'] == true,
      );
}

/// This week's progress: the planned workouts, or the weekly target when
/// nothing is planned.
class StreakWeek {
  final DateTime start;
  final bool planned;
  final int target;

  /// The target, prorated when the streak started this week.
  final int required;
  final int done;
  final List<StreakWeekEntry> entries;

  const StreakWeek({
    required this.start,
    required this.planned,
    required this.target,
    required this.required,
    required this.done,
    this.entries = const [],
  });

  factory StreakWeek.fromJson(Map<String, dynamic> j) => StreakWeek(
        start: _day(j['start']),
        planned: j['planned'] == true,
        target: _toInt(j['target']),
        required: _toInt(j['required']),
        done: _toInt(j['done']),
        entries: [
          for (final e in j['entries'] as List? ?? const []) StreakWeekEntry.fromJson(e as Map<String, dynamic>),
        ],
      );

  /// Workouts (or planned ones) still to do this week.
  int get remaining => planned ? entries.where((e) => !e.done).length : (required - done).clamp(0, required);
}

/// 'freeze_earned' · 'freeze_used' · 'broken' · 'tier'.
class StreakEvent {
  final String kind;
  final DateTime onDate;
  final int streak;
  final StreakTier? tier;

  const StreakEvent({required this.kind, required this.onDate, required this.streak, this.tier});

  factory StreakEvent.fromJson(Map<String, dynamic> j) => StreakEvent(
        kind: j['kind'].toString(),
        onDate: _day(j['on_date']),
        streak: _toInt(j['streak']),
        tier: StreakTier.fromApi(j['tier']),
      );
}

/// Where someone stands on a gym's streak board.
class GymRank {
  final String gymId;
  final String gymName;
  final int rank;
  final int total;
  final int value;

  /// Before the workout that was just logged (StreakUpdate only).
  final int? previousRank;

  const GymRank({
    required this.gymId,
    required this.gymName,
    required this.rank,
    required this.total,
    required this.value,
    this.previousRank,
  });

  factory GymRank.fromJson(Map<String, dynamic> j) => GymRank(
        gymId: j['gym_id'].toString(),
        gymName: j['gym_name'] as String? ?? '',
        rank: _toInt(j['rank']),
        total: _toInt(j['total']),
        value: _toInt(j['value']),
        previousRank: _toIntOrNull(j['previous_rank']),
      );

  /// Places climbed (positive) since [previousRank].
  int get climbed => previousRank == null ? 0 : previousRank! - rank;
}

/// My streak (GET /streaks).
class StreakStatus {
  final int current;
  final DateTime? since;
  final int best;
  final int freezes;
  final int maxFreezes;
  final StreakTier? tier;
  final StreakTier? bestTier;
  final DateTime today;
  final StreakWeek week;

  /// Planned workouts on still-open days (today, or yesterday until midnight).
  final List<StreakWeekEntry> atRisk;

  /// Workouts still needed this week when nothing is planned.
  final int weekRemaining;
  final List<StreakEvent> events;

  /// Gym streak boards I'm on, best rank first.
  final List<GymRank> ranks;

  const StreakStatus({
    required this.current,
    this.since,
    required this.best,
    required this.freezes,
    this.maxFreezes = 2,
    this.tier,
    this.bestTier,
    required this.today,
    required this.week,
    this.atRisk = const [],
    this.weekRemaining = 0,
    this.events = const [],
    this.ranks = const [],
  });

  factory StreakStatus.fromJson(Map<String, dynamic> j) => StreakStatus(
        current: _toInt(j['current']),
        since: j['since'] == null ? null : _day(j['since']),
        best: _toInt(j['best']),
        freezes: _toInt(j['freezes']),
        maxFreezes: _toIntOrNull(j['max_freezes']) ?? 2,
        tier: StreakTier.fromApi(j['tier']),
        bestTier: StreakTier.fromApi(j['best_tier']),
        today: _day(j['today']),
        week: StreakWeek.fromJson(j['week'] as Map<String, dynamic>),
        atRisk: [
          for (final e in j['at_risk'] as List? ?? const []) StreakWeekEntry.fromJson(e as Map<String, dynamic>),
        ],
        weekRemaining: _toInt(j['week_remaining']),
        events: [for (final e in j['events'] as List? ?? const []) StreakEvent.fromJson(e as Map<String, dynamic>)],
        ranks: [for (final r in j['ranks'] as List? ?? const []) GymRank.fromJson(r as Map<String, dynamic>)],
      );

  StreakTier? get nextTier => StreakTier.nextAbove(current);

  /// Needs a workout today to stay alive.
  bool get needsWorkoutToday {
    if (current == 0) return false;
    if (atRisk.isNotEmpty) return true;
    final daysLeft = 8 - today.weekday;
    return !week.planned && weekRemaining > 0 && weekRemaining >= daysLeft;
  }
}

/// Someone's public streak (GET /streaks?user_id=).
class StreakSummary {
  final String userId;
  final int current;
  final int best;
  final StreakTier? tier;
  final StreakTier? bestTier;
  final GymRank? gymRank;

  const StreakSummary({
    required this.userId,
    required this.current,
    required this.best,
    this.tier,
    this.bestTier,
    this.gymRank,
  });

  factory StreakSummary.fromJson(Map<String, dynamic> j) => StreakSummary(
        userId: j['user_id'].toString(),
        current: _toInt(j['current']),
        best: _toInt(j['best']),
        tier: StreakTier.fromApi(j['tier']),
        bestTier: StreakTier.fromApi(j['best_tier']),
        gymRank: j['gym_rank'] is Map<String, dynamic> ? GymRank.fromJson(j['gym_rank'] as Map<String, dynamic>) : null,
      );

  factory StreakSummary.of(StreakStatus s, String userId) => StreakSummary(
        userId: userId,
        current: s.current,
        best: s.best,
        tier: s.tier,
        bestTier: s.bestTier,
        gymRank: s.ranks.isEmpty ? null : s.ranks.first,
      );
}

/// How a workout just logged moved the streak (the `streak` of a finished
/// training session response).
class StreakUpdate {
  final int previous;
  final int current;
  final int best;
  final int freezes;
  final StreakTier? tier;
  final StreakTier? previousTier;
  final StreakWeek? week;
  final List<GymRank> ranks;

  const StreakUpdate({
    required this.previous,
    required this.current,
    required this.best,
    required this.freezes,
    this.tier,
    this.previousTier,
    this.week,
    this.ranks = const [],
  });

  factory StreakUpdate.fromJson(Map<String, dynamic> j) => StreakUpdate(
        previous: _toInt(j['previous']),
        current: _toInt(j['current']),
        best: _toInt(j['best']),
        freezes: _toInt(j['freezes']),
        tier: StreakTier.fromApi(j['tier']),
        previousTier: StreakTier.fromApi(j['previous_tier']),
        week: j['week'] is Map<String, dynamic> ? StreakWeek.fromJson(j['week'] as Map<String, dynamic>) : null,
        ranks: [for (final r in j['ranks'] as List? ?? const []) GymRank.fromJson(r as Map<String, dynamic>)],
      );

  static StreakUpdate? maybeFromJson(Object? j) => j is Map<String, dynamic> ? StreakUpdate.fromJson(j) : null;

  /// The workout counted (logged in time, with sets).
  bool get grew => current > previous;

  /// A badge reached with this workout.
  StreakTier? get newTier => tier != null && tier != previousTier ? tier : null;

  /// A round number reached with this workout (every 10).
  bool get milestone => grew && current > 0 && current % 10 == 0;

  /// The best climb on a gym board, if any.
  GymRank? get bestClimb {
    GymRank? best;
    for (final r in ranks) {
      if (r.climbed > 0 && (best == null || r.climbed > best.climbed)) best = r;
    }
    return best;
  }
}

enum GymBoardKind {
  streak('streak'),
  workouts('workouts'),
  checkIns('check_ins');

  const GymBoardKind(this.apiValue);
  final String apiValue;
}

class GymBoardEntry {
  final int rank;
  final int value;
  final SocialUser? user;

  /// More it takes to pass the next person up (my row only).
  final int gap;

  const GymBoardEntry({required this.rank, required this.value, this.user, this.gap = 0});

  factory GymBoardEntry.fromJson(Map<String, dynamic> j) => GymBoardEntry(
        rank: _toInt(j['rank']),
        value: _toInt(j['value']),
        user: SocialUser.maybeFromJson(j['user']),
        gap: _toInt(j['gap']),
      );
}

/// A gym's board (GET /streaks/boards/:gymId).
class GymBoard {
  final String gymId;
  final String gymName;
  final String? gymLogo;
  final GymBoardKind kind;
  final int total;
  final List<GymBoardEntry> entries;
  final GymBoardEntry? me;

  const GymBoard({
    required this.gymId,
    required this.gymName,
    this.gymLogo,
    required this.kind,
    required this.total,
    this.entries = const [],
    this.me,
  });

  factory GymBoard.fromJson(Map<String, dynamic> j) {
    final gym = j['gym'] as Map<String, dynamic>? ?? const {};
    return GymBoard(
      gymId: gym['id'].toString(),
      gymName: gym['name'] as String? ?? '',
      gymLogo: gym['logo'] as String?,
      kind: GymBoardKind.values.firstWhere((k) => k.apiValue == j['board'], orElse: () => GymBoardKind.streak),
      total: _toInt(j['total']),
      entries: [for (final e in j['entries'] as List? ?? const []) GymBoardEntry.fromJson(e as Map<String, dynamic>)],
      me: j['me'] is Map<String, dynamic> ? GymBoardEntry.fromJson(j['me'] as Map<String, dynamic>) : null,
    );
  }
}
