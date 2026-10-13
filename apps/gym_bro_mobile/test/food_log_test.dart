import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/food_log.dart';
import 'package:gym_bro_mobile/models/meal_plan.dart';

FoodItem _food({String unit = 'g'}) => FoodItem.fromJson({
      'id': 'f1',
      'name': 'Oats',
      'type': 'food',
      'food_subtype': 'grain_cereal',
      'serving_unit': unit,
      'kcal_per_100': '389.00',
      'protein_per_100': '16.90',
      'carb_per_100': '66.30',
      'fat_per_100': '6.90',
      'fiber_per_100': '10.60',
      'is_public': true,
      'is_system': false,
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
    });

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final sr = lookupAppLocalizations(const Locale('sr'));

  group('dates', () {
    test('apiDate pads and ignores time', () {
      expect(apiDate(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
    });

    test('parseApiDate round-trips to a local midnight', () {
      final d = parseApiDate('2026-10-13');
      expect(d, DateTime(2026, 10, 13));
      expect(apiDate(d), '2026-10-13');
    });
  });

  group('fmtAmount', () {
    test('drops trailing zeros', () {
      expect(fmtAmount(100), '100');
      expect(fmtAmount(1.5), '1.5');
      expect(fmtAmount(0.25), '0.25');
      expect(fmtAmount(2.10), '2.1');
    });
  });

  group('LogUnit', () {
    test('labels', () {
      expect(LogUnit.g.label(l10n, 120), '120 g');
      expect(LogUnit.ml.label(l10n, 250), '250 ml');
      expect(LogUnit.serving.label(l10n, 1), '1 serving');
      expect(LogUnit.serving.label(l10n, 1.5), '1.5 servings');
    });

    test('Serbian labels', () {
      expect(LogUnit.serving.label(sr, 1), '1 porcija');
      expect(LogUnit.serving.label(sr, 2), '2 porcije');
      expect(LogUnit.serving.label(sr, 5), '5 porcija');
      expect(LogUnit.g.label(sr, 1.5), '1,5 g');
    });

    test('from food item serving unit', () {
      expect(LogUnit.forFoodItem(_food()), LogUnit.g);
      expect(LogUnit.forFoodItem(_food(unit: 'ml')), LogUnit.ml);
    });
  });

  group('MacroTotals', () {
    test('food item macros scale per 100', () {
      final m = MacroTotals.forFoodItem(_food(), 50);
      expect(m.kcal, closeTo(194.5, 1e-9));
      expect(m.protein, closeTo(8.45, 1e-9));
      expect(m.fiber, closeTo(5.3, 1e-9));
    });

    test('addition and pcf label', () {
      final m = const MacroTotals(kcal: 100, protein: 10.4, carb: 20.6, fat: 3) +
          const MacroTotals(kcal: 50, protein: 5, carb: 0, fat: 1);
      expect(m.kcal, 150);
      expect(m.pcfLabel(l10n), 'P 15 · C 21 · F 4');
    });

    test('progressFraction clamps and handles no target', () {
      expect(progressFraction(50, 100), 0.5);
      expect(progressFraction(150, 100), 1.0);
      expect(progressFraction(50, null), 0);
      expect(progressFraction(50, 0), 0);
    });
  });

  group('parsing', () {
    test('FoodLog parses string numerics and per-unit macros', () {
      final log = FoodLog.fromJson({
        'id': 'l1',
        'user_id': 'u1',
        'log_date': '2026-10-13',
        'slot_type': 'post_workout',
        'food_item_id': null,
        'recipe_id': 'r1',
        'name': 'Protein Pancakes',
        'amount': '2.00',
        'unit': 'serving',
        'kcal': '679.90',
        'protein': '55.74',
        'carb': '68.42',
        'fat': '21.40',
        'fiber': '9.26',
        'note': null,
        'created_at': '2026-10-13T07:10:11.280Z',
      });
      expect(log.slotType, MealSlotType.postWorkout);
      expect(log.unit, LogUnit.serving);
      expect(log.amountLabel(l10n), '2 servings');
      expect(log.perUnit.kcal, closeTo(339.95, 1e-9));
      expect(log.canEditAmount, isTrue);
    });

    test('FoodLogSummary without a plan', () {
      final s = FoodLogSummary.fromJson({
        'date': '2026-10-13',
        'user_id': 'u1',
        'totals': {'kcal': 0, 'protein': 0, 'carb': 0, 'fat': 0, 'fiber': 0},
        'slots': [],
        'targets': null,
        'plan': null,
        'planned': [],
      });
      expect(s.targets, isNull);
      expect(s.hasPlannedMeals, isFalse);
      expect(s.plannedFor(MealSlotType.lunch), isNull);
    });

    test('FoodLogSummary with targets and planned slots', () {
      final s = FoodLogSummary.fromJson({
        'date': '2026-10-13',
        'user_id': 'u1',
        'totals': {'kcal': 934.9, 'protein': 64.86, 'carb': 120.38, 'fat': 23.86, 'fiber': 15.98},
        'slots': [
          {'slot_type': 'dinner', 'count': 1, 'kcal': 679.9, 'protein': 55.74, 'carb': 68.42, 'fat': 21.4, 'fiber': 9.26},
        ],
        'targets': {'kcal': 2076.86, 'protein': 168.71, 'carb': 223.61, 'fat': 59.29, 'fiber': 25.44},
        'plan': {
          'assignment_id': 'a1',
          'meal_plan_id': 'm1',
          'meal_plan_name': '4-Week Lean Bulk',
          'start_date': '2026-09-15',
          'week_number': 1,
          'day_of_week': 1,
          'daily_meal_plan_id': 'd1',
          'daily_meal_plan_name': 'Fuel Day',
        },
        'planned': [
          {
            'slot_type': 'pre_workout',
            'position': 1,
            'note': null,
            'entries': [
              {'food_item_id': 'f1', 'recipe_id': null, 'name': 'Banana', 'amount': 120, 'unit': 'g', 'note': null,
                'kcal': 106.8, 'protein': 1.32, 'carb': 27.36, 'fat': 0.36, 'fiber': 3.12},
              {'food_item_id': 'f2', 'recipe_id': null, 'name': 'Bread', 'amount': 60, 'unit': 'g', 'note': null,
                'kcal': 148.2, 'protein': 7.8, 'carb': 24.6, 'fat': 2.1, 'fiber': 3.6},
            ],
          },
        ],
      });
      expect(s.targets!.kcal, 2076.86);
      expect(s.plan!.dayLabel(l10n), 'Week 1 · Day 1');
      expect(s.slots.single.slotType, MealSlotType.dinner);
      expect(s.hasPlannedMeals, isTrue);
      final pre = s.plannedFor(MealSlotType.preWorkout)!;
      expect(pre.entries.first.amountLabel(l10n), '120 g');
      expect(pre.macros.kcal, closeTo(255.0, 1e-9));
    });

    test('NutrientReference', () {
      final n = NutrientReference.fromJson({
        'vitamins': [
          {'id': 'v1', 'name': 'Vitamin C', 'symbol': 'C', 'default_unit': 'mg'},
        ],
        'minerals': [
          {'id': 'm1', 'name': 'Selenium', 'symbol': 'Se', 'default_unit': 'µg'},
        ],
      });
      expect(n.vitamins.single.name, 'Vitamin C');
      expect(n.minerals.single.defaultUnit, 'µg');
    });
  });
}
