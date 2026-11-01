import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/pages/progress/progress_chart.dart';
import 'package:gym_bro_mobile/utils/body_units.dart';
import 'package:gym_bro_mobile/utils/weight_trend.dart';

TrendPoint _p(int day, double v) => TrendPoint(DateTime(2026, 1, day), v);

void main() {
  group('weightTrend', () {
    test('empty in, empty out', () {
      expect(weightTrend(const []), isEmpty);
    });

    test('starts at the first weigh-in and moves 10% a day toward new ones', () {
      final t = weightTrend([_p(1, 80), _p(2, 81), _p(3, 81)]);
      expect(t.map((p) => p.date), [DateTime(2026, 1, 1), DateTime(2026, 1, 2), DateTime(2026, 1, 3)]);
      expect(t[0].value, 80);
      expect(t[1].value, closeTo(80.1, 1e-9));
      expect(t[2].value, closeTo(80.19, 1e-9));
    });

    test('gap-aware: a 7-day gap weighs like 7 daily steps', () {
      final t = weightTrend([_p(1, 80), _p(8, 78)]);
      final a = 1 - math.pow(0.9, 7);
      expect(t.last.value, closeTo(80 + a * (78 - 80), 1e-9));
      // ... which is more than a single day would move it.
      expect(t.last.value, lessThan(80 - 0.1 * 2));
    });

    test('several weigh-ins on one day are averaged; input order is irrelevant', () {
      final t = weightTrend([
        TrendPoint(DateTime(2026, 1, 2, 20), 82),
        TrendPoint(DateTime(2026, 1, 1, 7), 80),
        TrendPoint(DateTime(2026, 1, 2, 7), 80),
      ]);
      expect(t, hasLength(2));
      expect(t.last.value, closeTo(80.1, 1e-9));
    });

    test('a single outlier barely moves the trend', () {
      final raw = [for (var d = 1; d <= 20; d++) _p(d, 80), _p(21, 85)];
      expect(weightTrend(raw).last.value, closeTo(80.5, 1e-9));
    });

    test('custom alpha and non-finite values are skipped', () {
      final t = weightTrend([_p(1, 80), _p(2, double.nan), _p(3, 90)], alpha: 0.5);
      expect(t, hasLength(2));
      // two-day gap: 1 - 0.5^2 = 0.75
      expect(t.last.value, closeTo(87.5, 1e-9));
    });

    test('DST change in between counts calendar days', () {
      expect(calendarDaysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
      expect(calendarDaysBetween(DateTime(2026, 10, 24, 23), DateTime(2026, 10, 26, 1)), 2);
    });
  });

  group('weeklyRate', () {
    test('null without enough history', () {
      expect(weeklyRate(const []), isNull);
      expect(weeklyRate([_p(1, 80)]), isNull);
      expect(weeklyRate([_p(1, 80), _p(4, 79)]), isNull); // spans 3 days
    });

    test('slope of a straight line, per week', () {
      final trend = [for (var d = 1; d <= 29; d++) _p(d, 80 - 0.1 * (d - 1))];
      expect(weeklyRate(trend), closeTo(-0.7, 1e-9));
    });

    test('only the last window counts', () {
      // Gaining for 60 days, then losing 0.05/day for the last 28.
      final trend = [
        for (var d = 0; d < 60; d++) TrendPoint(DateTime(2026, 1, 1 + d), 70 + 0.1 * d),
        for (var d = 1; d <= 28; d++) TrendPoint(DateTime(2026, 1, 60 + d), 75.9 - 0.05 * d),
      ];
      expect(weeklyRate(trend), closeTo(-0.35, 0.02));
      expect(weeklyRate(trend, windowDays: 7), closeTo(-0.35, 1e-9));
    });
  });

  group('goalEta', () {
    final today = DateTime(2026, 11, 1, 15, 30);

    test('no data', () {
      expect(goalEta(current: null, goal: 75, ratePerWeek: -0.5, today: today).kind, GoalEtaKind.noData);
      expect(goalEta(current: 80, goal: 75, ratePerWeek: null, today: today).kind, GoalEtaKind.noData);
    });

    test('reached within the tolerance (even without a rate)', () {
      expect(goalEta(current: 75.2, goal: 75, ratePerWeek: null, today: today).kind, GoalEtaKind.reached);
      expect(goalEta(current: 74.8, goal: 75, ratePerWeek: 0.4, today: today).kind, GoalEtaKind.reached);
    });

    test('flat', () {
      expect(goalEta(current: 80, goal: 75, ratePerWeek: -0.02, today: today).kind, GoalEtaKind.flat);
    });

    test('wrong way, losing and gaining', () {
      expect(goalEta(current: 80, goal: 75, ratePerWeek: 0.3, today: today).kind, GoalEtaKind.wrongWay);
      expect(goalEta(current: 70, goal: 75, ratePerWeek: -0.3, today: today).kind, GoalEtaKind.wrongWay);
    });

    test('on track: date from today (time of day ignored)', () {
      final eta = goalEta(current: 80, goal: 78, ratePerWeek: -0.5, today: today);
      expect(eta.kind, GoalEtaKind.onTrack);
      expect(eta.weeks, closeTo(4, 1e-9));
      expect(eta.date, DateTime(2026, 11, 29));
      final gain = goalEta(current: 70, goal: 72, ratePerWeek: 0.25, today: today);
      expect(gain.kind, GoalEtaKind.onTrack);
      expect(gain.date, DateTime(2026, 12, 27));
    });

    test('too far', () {
      final eta = goalEta(current: 120, goal: 80, ratePerWeek: -0.1, today: today);
      expect(eta.kind, GoalEtaKind.tooFar);
      expect(eta.date, isNull);
    });
  });

  group('body units', () {
    test('cm for kg users, inches for lb users', () {
      expect(lengthUnitFor('kg'), 'cm');
      expect(lengthUnitFor('lb'), 'in');
      expect(toDisplayLength(84, 'kg'), 84);
      expect(toDisplayLength(25.4, 'lb'), closeTo(10, 1e-9));
    });

    test('back to cm with one decimal, round-tripping displayed inches', () {
      expect(fromDisplayLength(33.2, 'lb'), 84.3);
      expect(fromDisplayLength(84.26, 'kg'), 84.3);
      final shown = double.parse(toDisplayLength(84.3, 'lb').toStringAsFixed(1));
      expect(fromDisplayLength(shown, 'lb'), 84.3);
    });
  });

  group('crowdsAxisEdge', () {
    test('drops interval labels that would overlap the edge labels, keeps the edges', () {
      expect(crowdsAxisEdge(0, 0, 100, 30), isFalse);
      expect(crowdsAxisEdge(100, 0, 100, 30), isFalse);
      expect(crowdsAxisEdge(10, 0, 100, 30), isTrue);
      expect(crowdsAxisEdge(95, 0, 100, 30), isTrue);
      expect(crowdsAxisEdge(45, 0, 100, 30), isFalse);
    });
  });

  group('revealSpots', () {
    const spots = [FlSpot(0, 10), FlSpot(10, 20), FlSpot(20, 0)];

    test('everything once the cut passes the end', () {
      expect(revealSpots(spots, 20), spots);
      expect(revealSpots(spots, 99), spots);
    });

    test('ends with a point interpolated at the cut', () {
      expect(revealSpots(spots, 5), const [FlSpot(0, 10), FlSpot(5, 15)]);
      expect(revealSpots(spots, 15), const [FlSpot(0, 10), FlSpot(10, 20), FlSpot(15, 10)]);
    });

    test('never empty', () {
      expect(revealSpots(spots, -5), const [FlSpot(0, 10)]);
      expect(revealSpots(const [], 3), isEmpty);
    });
  });
}
