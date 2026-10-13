import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/utils/plate_calculator.dart';

void main() {
  group('calculatePlates (kg)', () {
    test('loads an exact weight with the fewest plates', () {
      final load = calculatePlates(target: 100, bar: 20);
      expect(load.platesPerSide, [25, 15]);
      expect(load.achievable, 100);
      expect(load.isExact, isTrue);
    });

    test('uses small plates', () {
      final load = calculatePlates(target: 102.5, bar: 20);
      expect(load.platesPerSide, [25, 15, 1.25]);
      expect(load.isExact, isTrue);
    });

    test('repeats plates when needed', () {
      final load = calculatePlates(target: 180, bar: 20);
      expect(load.platesPerSide, [25, 25, 25, 5]);
      expect(load.countsPerSide, {25: 3, 5: 1});
    });

    test('works with the 15 kg bar', () {
      final load = calculatePlates(target: 45, bar: 15);
      expect(load.platesPerSide, [15]);
    });

    test('rounds to the closest achievable weight', () {
      final load = calculatePlates(target: 101, bar: 20);
      expect(load.isExact, isFalse);
      expect(load.achievable, 100);
      expect(load.difference, -1);

      final up = calculatePlates(target: 102, bar: 20);
      expect(up.achievable, 102.5);
    });

    test('ties go to the lighter weight', () {
      // 1.25 kg off either way → lighter.
      final load = calculatePlates(target: 23.75, bar: 20);
      expect(load.achievable, 22.5);
    });

    test('target at or below the bar is an empty bar', () {
      expect(calculatePlates(target: 20, bar: 20).platesPerSide, isEmpty);
      final light = calculatePlates(target: 10, bar: 20);
      expect(light.platesPerSide, isEmpty);
      expect(light.achievable, 20);
      expect(light.isExact, isFalse);
    });

    test('respects a custom plate set', () {
      final load = calculatePlates(target: 60, bar: 20, plates: const [10]);
      expect(load.platesPerSide, [10, 10]);
      final off = calculatePlates(target: 65, bar: 20, plates: const [10]);
      expect(off.achievable, 60);
    });
  });

  group('calculatePlates (lb)', () {
    test('two plates a side', () {
      final load = calculatePlates(target: 225, bar: 45, plates: lbPlates);
      expect(load.platesPerSide, [45, 45]);
    });

    test('mixed plates', () {
      final load = calculatePlates(target: 185, bar: 45, plates: lbPlates);
      expect(load.platesPerSide, [45, 25]);
    });

    test('closest when not loadable', () {
      final load = calculatePlates(target: 137, bar: 45, plates: lbPlates);
      expect(load.achievable, 135);
      final load2 = calculatePlates(target: 138, bar: 45, plates: lbPlates);
      expect(load2.achievable, 140);
    });

    test('35 lb bar', () {
      expect(calculatePlates(target: 125, bar: 35, plates: lbPlates).platesPerSide, [45]);
    });
  });

  group('warmupSets', () {
    test('40/60/80 % ramp rounded to loadable weights', () {
      final sets = warmupSets(workingWeight: 100, bar: 20);
      expect(sets.map((s) => s.reps), [8, 5, 3]);
      expect(sets.map((s) => s.weight), [40, 60, 80]);
    });

    test('rounds odd weights', () {
      final sets = warmupSets(workingWeight: 87.5, bar: 20);
      // 35, 52.5, 70 are all loadable with 1.25 kg plates.
      expect(sets.map((s) => s.weight), [35, 52.5, 70]);
      final lb = warmupSets(workingWeight: 205, bar: 45, plates: lbPlates);
      // 82 → 80, 123 → 125, 164 → 165
      expect(lb.map((s) => s.weight), [80, 125, 165]);
    });

    test('never below the bar', () {
      final sets = warmupSets(workingWeight: 30, bar: 20);
      expect(sets.first.weight, 20);
    });

    test('empty for no working weight', () {
      expect(warmupSets(workingWeight: 0, bar: 20), isEmpty);
    });
  });

  test('formatPlateWeight trims zeros', () {
    expect(formatPlateWeight(2.5), '2.5');
    expect(formatPlateWeight(20), '20');
    expect(formatPlateWeight(1.25), '1.25');
  });
}
