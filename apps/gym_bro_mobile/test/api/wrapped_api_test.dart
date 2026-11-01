import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/streak.dart';
import 'package:gym_bro_mobile/models/wrapped.dart';
import 'package:gym_bro_mobile/services/api_service.dart';

import '../helpers/fake_backend.dart';

const _token = 'tok-123';

// Captured from the local stack (GET /wrapped/2026?preview=1 for a seeded member), trimmed.
Map<String, dynamic> wrappedJson() => {
      'year': 2026,
      'available': true,
      'available_from': '2026-12-01',
      'timezone': 'Europe/Belgrade',
      'totals': {'workouts': 7, 'active_days': 7, 'minutes': 599, 'volume_kg': '63040', 'sets': 45, 'reps': 1877},
      'first_workout_on': '2026-10-04',
      'by_weekday': [1, 0, 2, 1, 0, 2, 1],
      'busiest_weekday': 3,
      'by_hour': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 0, 1, 0, 1, 1, 0],
      'favourite_hour': 17,
      'by_month': [0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0],
      'best_month': 10,
      'top_exercises_by_sets': [
        {'exercise_id': 'e1', 'name': 'Dumbbell Bicep Curl', 'image_url': null, 'sets': 4, 'volume_kg': 1435},
        {'exercise_id': 'e2', 'name': 'Barbell Back Squat', 'image_url': null, 'sets': 3, 'volume_kg': '8273'},
      ],
      'top_exercises_by_volume': [
        {'exercise_id': 'e3', 'name': 'Leg Press', 'image_url': null, 'sets': 2, 'volume_kg': 10179},
      ],
      'prs': {
        'count': 19,
        'best_lifts': [
          {'exercise_id': 'e3', 'name': 'Leg Press', 'e1rm': 171.5, 'weight_kg': '122.5', 'reps': 12, 'on': '2026-10-21'},
        ],
      },
      'gym': {
        'check_ins': 12,
        'classes_attended': 8,
        'favourite': {'id': 'g1', 'name': 'Ironclad Fitness', 'logo': null, 'check_ins': 12},
      },
      'streak': {'longest': 7, 'best_ever': 7},
      'badges': [
        {'tier': 'bronze', 'on_date': '2026-10-20'},
        {'tier': 'unobtainium', 'on_date': '2026-10-21'},
      ],
      'challenges': {
        'completed': 1,
        'items': [
          {'id': 'c1', 'title': 'Fall Kickoff', 'metric': 'workouts', 'target': 3, 'auto_key': null, 'gym_name': 'Ironclad Fitness'},
        ],
      },
      'generated_in_ms': 20,
    };

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  test('getWrapped parses the whole recap', () async {
    backend.on('GET /wrapped/2026', ok(wrappedJson()));
    final w = await api.getWrapped(_token, 2026, tz: 'Europe/Belgrade', preview: true);

    final req = backend.only;
    expect(req.url.queryParameters, {'tz': 'Europe/Belgrade', 'preview': '1'});
    expect(w.available, isTrue);
    expect(w.totals.workouts, 7);
    expect(w.totals.volumeKg, 63040);
    expect(w.totals.hours, closeTo(9.98, 0.01));
    expect(w.firstWorkoutOn, DateTime(2026, 10, 4));
    expect(w.byWeekday, hasLength(7));
    expect(w.byHour, hasLength(24));
    expect(w.byMonth[9], 7);
    expect(w.busiestWeekday, 3);
    expect(w.favouriteHour, 17);
    expect(w.bestMonth, 10);
    expect(w.topBySets.first.name, 'Dumbbell Bicep Curl');
    expect(w.topBySets.last.volumeKg, 8273);
    expect(w.topByVolume.single.name, 'Leg Press');
    expect(w.prCount, 19);
    expect(w.bestLifts.single.weightKg, 122.5);
    expect(w.bestLifts.single.on, DateTime(2026, 10, 21));
    expect(w.checkIns, 12);
    expect(w.classesAttended, 8);
    expect(w.favouriteGym?.name, 'Ironclad Fitness');
    expect(w.longestStreak, 7);
    // Unknown tiers (from a newer API) are dropped.
    expect(w.badges.single.tier, StreakTier.bronze);
    expect(w.challenges.single.gymName, 'Ironclad Fitness');
    expect(w.isEmpty, isFalse);
    expect(w.hasGymSlide, isTrue);
    expect(w.hasStreakSlide, isTrue);
  });

  test('a year that is not open yet', () async {
    backend.on('GET /wrapped/2026', ok({'year': 2026, 'available': false, 'available_from': '2026-12-01', 'reason': 'not_yet'}));
    final w = await api.getWrapped(_token, 2026);
    expect(backend.only.url.hasQuery, isFalse);
    expect(w.available, isFalse);
    expect(w.reason, 'not_yet');
    expect(w.availableFrom, DateTime(2026, 12, 1));
    expect(w.isEmpty, isTrue);
  });

  test('getWrappedIndex', () async {
    backend.on(
      'GET /wrapped',
      ok({
        'today': '2026-11-01',
        'current_year': 2026,
        'years': [
          {'year': 2026, 'available': false, 'available_from': '2026-12-01', 'reason': 'not_yet'},
          {'year': 2025, 'available': true, 'available_from': null},
        ],
      }),
    );
    final idx = await api.getWrappedIndex(_token, tz: 'Europe/Belgrade');
    expect(idx.currentYear, 2026);
    expect(idx.years.last.available, isTrue);
    expect(idx.years.last.availableFrom, isNull);
  });

  group('bannerYear', () {
    WrappedIndex index({required bool currentOpen, bool pastYear = true}) => WrappedIndex(
          currentYear: 2026,
          years: [
            WrappedAvailability(year: 2026, available: currentOpen),
            if (pastYear) const WrappedAvailability(year: 2025, available: true),
          ],
        );

    test('this year once it opens, watched or not', () {
      expect(index(currentOpen: true).bannerYear({2026, 2025}), 2026);
    });

    test('a past year until it has been watched', () {
      expect(index(currentOpen: false).bannerYear({}), 2025);
      expect(index(currentOpen: false).bannerYear({2025}), isNull);
    });

    test('nothing to offer', () {
      expect(index(currentOpen: false, pastYear: false).bannerYear({}), isNull);
    });
  });
}
