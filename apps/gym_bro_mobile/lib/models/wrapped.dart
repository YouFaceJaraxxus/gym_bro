// Gym Bro Wrapped: my year in training (GET /wrapped/:year).
//
// The current year opens on December 1; past years whenever they have
// workouts or check-ins. Until then the API answers {available: false,
// available_from}.

import 'streak.dart';

int _toInt(Object? v) => v == null ? 0 : int.tryParse(v.toString()) ?? double.tryParse(v.toString())?.round() ?? 0;

int? _toIntOrNull(Object? v) =>
    v == null ? null : int.tryParse(v.toString()) ?? double.tryParse(v.toString())?.round();

double _toDouble(Object? v) => v == null ? 0 : double.tryParse(v.toString()) ?? 0;

double? _toDoubleOrNull(Object? v) => v == null ? null : double.tryParse(v.toString());

DateTime? _day(Object? v) {
  if (v == null) return null;
  final p = v.toString().split('T').first.split('-').map(int.tryParse).toList();
  if (p.length < 3 || p.contains(null)) return null;
  return DateTime(p[0]!, p[1]!, p[2]!);
}

List<int> _ints(Object? v, int length) {
  final list = [for (final x in v as List? ?? const []) _toInt(x)];
  return [for (var i = 0; i < length; i++) i < list.length ? list[i] : 0];
}

/// Whether a year's recap can be opened.
class WrappedAvailability {
  final int year;
  final bool available;

  /// When it opens (Dec 1 of the year); null for a past year without data.
  final DateTime? availableFrom;

  /// 'not_yet' · 'no_data' (when not available).
  final String? reason;

  const WrappedAvailability({required this.year, required this.available, this.availableFrom, this.reason});

  factory WrappedAvailability.fromJson(Map<String, dynamic> j) => WrappedAvailability(
        year: _toInt(j['year']),
        available: j['available'] == true,
        availableFrom: _day(j['available_from']),
        reason: j['reason'] as String?,
      );
}

/// GET /wrapped: the years there is (or will be) a recap for, newest first.
class WrappedIndex {
  final DateTime? today;
  final int currentYear;
  final List<WrappedAvailability> years;

  const WrappedIndex({this.today, required this.currentYear, this.years = const []});

  factory WrappedIndex.fromJson(Map<String, dynamic> j) => WrappedIndex(
        today: _day(j['today']),
        currentYear: _toInt(j['current_year']),
        years: [for (final y in j['years'] as List? ?? const []) WrappedAvailability.fromJson(y as Map<String, dynamic>)],
      );

  /// The year a banner should offer: this year once it's open, else the
  /// latest past year with a recap that isn't in [viewed].
  int? bannerYear(Set<int> viewed) {
    for (final y in years) {
      if (!y.available) continue;
      if (y.year == currentYear) return y.year;
      if (!viewed.contains(y.year)) return y.year;
    }
    return null;
  }
}

class WrappedTotals {
  final int workouts;
  final int activeDays;
  final int minutes;
  final double volumeKg;
  final int sets;
  final int reps;

  const WrappedTotals({
    this.workouts = 0,
    this.activeDays = 0,
    this.minutes = 0,
    this.volumeKg = 0,
    this.sets = 0,
    this.reps = 0,
  });

  factory WrappedTotals.fromJson(Map<String, dynamic>? j) => j == null
      ? const WrappedTotals()
      : WrappedTotals(
          workouts: _toInt(j['workouts']),
          activeDays: _toInt(j['active_days']),
          minutes: _toInt(j['minutes']),
          volumeKg: _toDouble(j['volume_kg']),
          sets: _toInt(j['sets']),
          reps: _toInt(j['reps']),
        );

  double get hours => minutes / 60;
}

class WrappedExercise {
  final String id;
  final String name;
  final String? imageUrl;
  final int sets;
  final double volumeKg;

  const WrappedExercise({required this.id, required this.name, this.imageUrl, this.sets = 0, this.volumeKg = 0});

  factory WrappedExercise.fromJson(Map<String, dynamic> j) => WrappedExercise(
        id: j['exercise_id'].toString(),
        name: j['name'] as String? ?? '',
        imageUrl: j['image_url'] as String?,
        sets: _toInt(j['sets']),
        volumeKg: _toDouble(j['volume_kg']),
      );
}

/// A best lift of the year (Epley e1RM).
class WrappedLift {
  final String exerciseId;
  final String name;
  final double e1rm;
  final double? weightKg;
  final int? reps;
  final DateTime? on;

  const WrappedLift({required this.exerciseId, required this.name, required this.e1rm, this.weightKg, this.reps, this.on});

  factory WrappedLift.fromJson(Map<String, dynamic> j) => WrappedLift(
        exerciseId: j['exercise_id'].toString(),
        name: j['name'] as String? ?? '',
        e1rm: _toDouble(j['e1rm']),
        weightKg: _toDoubleOrNull(j['weight_kg']),
        reps: _toIntOrNull(j['reps']),
        on: _day(j['on']),
      );
}

class WrappedGym {
  final String id;
  final String name;
  final String? logo;
  final int checkIns;

  const WrappedGym({required this.id, required this.name, this.logo, this.checkIns = 0});

  static WrappedGym? maybe(Object? j) => j is Map<String, dynamic>
      ? WrappedGym(id: j['id'].toString(), name: j['name'] as String? ?? '', logo: j['logo'] as String?, checkIns: _toInt(j['check_ins']))
      : null;
}

class WrappedBadge {
  final StreakTier tier;
  final DateTime? on;

  const WrappedBadge({required this.tier, this.on});
}

class WrappedChallenge {
  final String id;
  final String title;
  final String? autoKey;
  final String? gymName;

  const WrappedChallenge({required this.id, required this.title, this.autoKey, this.gymName});

  factory WrappedChallenge.fromJson(Map<String, dynamic> j) => WrappedChallenge(
        id: j['id'].toString(),
        title: j['title'] as String? ?? '',
        autoKey: j['auto_key'] as String?,
        gymName: j['gym_name'] as String?,
      );
}

/// A year's recap (available) — or just why it isn't ([available] false).
class Wrapped {
  final int year;
  final bool available;
  final DateTime? availableFrom;
  final String? reason;

  final WrappedTotals totals;
  final DateTime? firstWorkoutOn;

  /// Workouts per ISO weekday (Mon…Sun), hour (0…23) and month (Jan…Dec).
  final List<int> byWeekday;
  final List<int> byHour;
  final List<int> byMonth;

  /// 1 = Monday … 7 = Sunday.
  final int? busiestWeekday;
  final int? favouriteHour;

  /// 1 = January … 12 = December.
  final int? bestMonth;

  final List<WrappedExercise> topBySets;
  final List<WrappedExercise> topByVolume;
  final int prCount;
  final List<WrappedLift> bestLifts;

  final int checkIns;
  final int classesAttended;
  final WrappedGym? favouriteGym;

  final int longestStreak;
  final List<WrappedBadge> badges;
  final List<WrappedChallenge> challenges;

  const Wrapped({
    required this.year,
    this.available = true,
    this.availableFrom,
    this.reason,
    this.totals = const WrappedTotals(),
    this.firstWorkoutOn,
    this.byWeekday = const [0, 0, 0, 0, 0, 0, 0],
    this.byHour = const [],
    this.byMonth = const [],
    this.busiestWeekday,
    this.favouriteHour,
    this.bestMonth,
    this.topBySets = const [],
    this.topByVolume = const [],
    this.prCount = 0,
    this.bestLifts = const [],
    this.checkIns = 0,
    this.classesAttended = 0,
    this.favouriteGym,
    this.longestStreak = 0,
    this.badges = const [],
    this.challenges = const [],
  });

  /// Nothing logged that year.
  bool get isEmpty => totals.workouts == 0 && checkIns == 0;

  bool get hasGymSlide => checkIns > 0 || classesAttended > 0;
  bool get hasStreakSlide => longestStreak > 0 || badges.isNotEmpty || challenges.isNotEmpty;

  factory Wrapped.fromJson(Map<String, dynamic> j) {
    final prs = j['prs'] as Map<String, dynamic>? ?? const {};
    final gym = j['gym'] as Map<String, dynamic>? ?? const {};
    final streak = j['streak'] as Map<String, dynamic>? ?? const {};
    final ch = j['challenges'] as Map<String, dynamic>? ?? const {};
    return Wrapped(
      year: _toInt(j['year']),
      available: j['available'] == true,
      availableFrom: _day(j['available_from']),
      reason: j['reason'] as String?,
      totals: WrappedTotals.fromJson(j['totals'] as Map<String, dynamic>?),
      firstWorkoutOn: _day(j['first_workout_on']),
      byWeekday: _ints(j['by_weekday'], 7),
      byHour: _ints(j['by_hour'], 24),
      byMonth: _ints(j['by_month'], 12),
      busiestWeekday: _toIntOrNull(j['busiest_weekday']),
      favouriteHour: _toIntOrNull(j['favourite_hour']),
      bestMonth: _toIntOrNull(j['best_month']),
      topBySets: [
        for (final e in j['top_exercises_by_sets'] as List? ?? const []) WrappedExercise.fromJson(e as Map<String, dynamic>),
      ],
      topByVolume: [
        for (final e in j['top_exercises_by_volume'] as List? ?? const [])
          WrappedExercise.fromJson(e as Map<String, dynamic>),
      ],
      prCount: _toInt(prs['count']),
      bestLifts: [for (final l in prs['best_lifts'] as List? ?? const []) WrappedLift.fromJson(l as Map<String, dynamic>)],
      checkIns: _toInt(gym['check_ins']),
      classesAttended: _toInt(gym['classes_attended']),
      favouriteGym: WrappedGym.maybe(gym['favourite']),
      longestStreak: _toInt(streak['longest']),
      badges: [
        for (final b in j['badges'] as List? ?? const [])
          if (StreakTier.fromApi((b as Map<String, dynamic>)['tier']) case final tier?)
            WrappedBadge(tier: tier, on: _day(b['on_date'])),
      ],
      challenges: [
        for (final c in ch['items'] as List? ?? const []) WrappedChallenge.fromJson(c as Map<String, dynamic>),
      ],
    );
  }
}
