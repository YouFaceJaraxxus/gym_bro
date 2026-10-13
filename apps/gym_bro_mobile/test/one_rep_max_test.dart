import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/utils/one_rep_max.dart';

void main() {
  group('epleyOneRepMax', () {
    test('applies w × (1 + reps/30)', () {
      expect(epleyOneRepMax(100, 5), closeTo(116.667, 0.001));
      expect(epleyOneRepMax(60, 10), closeTo(80, 1e-9));
      expect(epleyOneRepMax(100, 30), closeTo(200, 1e-9));
    });

    test('a single rep is just above the lifted weight', () {
      expect(epleyOneRepMax(100, 1), closeTo(103.333, 0.001));
    });

    test('is null without reps or weight', () {
      expect(epleyOneRepMax(100, 0), isNull);
      expect(epleyOneRepMax(100, -2), isNull);
      expect(epleyOneRepMax(0, 5), isNull);
      expect(epleyOneRepMax(null, 5), isNull);
      expect(epleyOneRepMax(100, null), isNull);
    });

    test('matches the API rounding for seeded data', () {
      // 73.75 kg × 11 → 100.79 (API rounds to 2 dp).
      expect(double.parse(epleyOneRepMax(73.75, 11)!.toStringAsFixed(2)), 100.79);
    });
  });

  group('epleyWeightForReps', () {
    test('inverts the estimate', () {
      final max = epleyOneRepMax(80, 8)!;
      expect(epleyWeightForReps(max, 8), closeTo(80, 1e-9));
    });

    test('is null for invalid input', () {
      expect(epleyWeightForReps(100, 0), isNull);
      expect(epleyWeightForReps(0, 5), isNull);
    });
  });
}
