import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/food_log.dart';
import 'package:gym_bro_mobile/models/meal_plan.dart';
import 'package:gym_bro_mobile/services/api_service.dart';
import 'package:http/http.dart' as http;

import '../helpers/fake_backend.dart';

const _token = 'tok-123';

void _expectHeaders(http.Request req, {bool json = true}) {
  expect(req.headers['Authorization'], 'Bearer $_token');
  if (json) expect(req.headers['Content-Type'], startsWith('application/json'));
}

Matcher _throwsMessage(String message) => throwsA(predicate((e) => e is Exception && '$e'.contains(message)));

// Rows captured from the local stack (GET /food-logs?date=).
final _recipeLog = {
  'id': 'fl1',
  'user_id': 'u-liam',
  'log_date': '2026-10-27',
  'slot_type': 'lunch',
  'food_item_id': null,
  'recipe_id': 'r1',
  'name': 'Grilled Chicken & Rice Bowl',
  'amount': '1.00',
  'unit': 'serving',
  'kcal': '535.56',
  'protein': '52.70',
  'carb': '47.57',
  'fat': '13.67',
  'fiber': '2.68',
  'note': null,
  'created_at': '2026-10-27T16:48:00.000Z',
};

final _foodLog = {
  'id': 'fl2',
  'user_id': 'u-liam',
  'log_date': '2026-10-27',
  'slot_type': 'afternoon_snack',
  'food_item_id': 'fi1',
  'recipe_id': null,
  'name': 'Orange Juice, 100% (Tropicana)',
  'amount': '250.00',
  'unit': 'ml',
  'kcal': '112.50',
  'protein': '1.75',
  'carb': '25.75',
  'fat': '0.50',
  'fiber': '0.50',
  'note': 'with breakfast',
  'created_at': '2026-10-27T08:05:00.000Z',
};

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('getFoodLogs', () {
    test('GETs /food-logs?date= and parses entries with numeric strings', () async {
      backend.on('GET /food-logs', ok([_recipeLog, _foodLog]));

      final logs = await api.getFoodLogs(_token, date: DateTime(2026, 10, 27, 22, 30));

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/food-logs');
      expect(req.url.queryParameters, {'date': '2026-10-27'});
      _expectHeaders(req);

      expect(logs, hasLength(2));
      final r = logs[0];
      expect(r.id, 'fl1');
      expect(r.userId, 'u-liam');
      expect(r.logDate, DateTime(2026, 10, 27));
      expect(r.slotType, MealSlotType.lunch);
      expect(r.foodItemId, isNull);
      expect(r.recipeId, 'r1');
      expect(r.name, 'Grilled Chicken & Rice Bowl');
      expect(r.amount, 1.0);
      expect(r.unit, LogUnit.serving);
      expect(r.macros.kcal, 535.56);
      expect(r.macros.protein, 52.70);
      expect(r.macros.carb, 47.57);
      expect(r.macros.fat, 13.67);
      expect(r.macros.fiber, 2.68);
      expect(r.note, isNull);
      expect(r.createdAt, DateTime.utc(2026, 10, 27, 16, 48));
      expect(r.canEditAmount, isTrue);

      final f = logs[1];
      expect(f.slotType, MealSlotType.afternoonSnack);
      expect(f.foodItemId, 'fi1');
      expect(f.recipeId, isNull);
      expect(f.amount, 250.0);
      expect(f.unit, LogUnit.ml);
      expect(f.macros.kcal, 112.5);
      expect(f.note, 'with breakfast');
    });

    test('a range for another user sends from/to/user_id and no date', () async {
      backend.on('GET /food-logs', ok([]));

      await api.getFoodLogs(_token, from: DateTime(2026, 1, 5), to: DateTime(2026, 1, 11), userId: 'u-client');

      expect(backend.only.url.queryParameters, {'from': '2026-01-05', 'to': '2026-01-11', 'user_id': 'u-client'});
    });

    test('no filters sends no parameters', () async {
      backend.on('GET /food-logs', ok([]));
      await api.getFoodLogs(_token);
      expect(backend.only.url.queryParameters, isEmpty);
    });

    test('400 surfaces the message', () async {
      backend.on('GET /food-logs', err(400, "Range can't exceed 62 days"));
      await expectLater(api.getFoodLogs(_token, from: DateTime(2026), to: DateTime(2026, 6)),
          _throwsMessage("Range can't exceed 62 days"));
    });

    test('a non-JSON error body still throws a readable error', () async {
      backend.on('GET /food-logs', ok('upstream timeout', 504));
      await expectLater(api.getFoodLogs(_token), _throwsMessage('Request failed (504)'));
    });
  });

  group('getFoodLogSummary', () {
    test('GETs /food-logs/summary?date= and parses totals, slots, plan, targets and planned meals', () async {
      backend.on(
        'GET /food-logs/summary',
        ok({
          'date': '2026-10-20',
          'user_id': 'u-liam',
          'totals': {'kcal': 1164.26, 'protein': 107.9, 'carb': 121.2, 'fat': 27.71, 'fiber': 12.7},
          'slots': [
            {'slot_type': 'lunch', 'count': 1, 'kcal': 535.56, 'protein': 52.7, 'carb': 47.57, 'fat': 13.67, 'fiber': 2.68},
            {'slot_type': 'dinner', 'count': 2, 'kcal': 470.4, 'protein': 39.48, 'carb': 58.3, 'fat': 10.46, 'fiber': 8.58},
          ],
          'targets': {'kcal': 2800, 'protein': 180, 'carb': 320.5, 'fat': 80, 'fiber': 35},
          'plan': {
            'assignment_id': 'a1',
            'meal_plan_id': 'mp1',
            'meal_plan_name': '4-Week Lean Bulk',
            'start_date': '2026-09-15',
            'week_number': 2,
            'day_of_week': 2,
            'daily_meal_plan_id': 'dmp1',
            'daily_meal_plan_name': 'Training day',
          },
          'planned': [
            {
              'slot_type': 'breakfast',
              'position': 0,
              'note': 'Before 9',
              'entries': [
                {
                  'food_item_id': 'fi-oats',
                  'recipe_id': null,
                  'name': 'Rolled Oats (Quaker)',
                  'amount': 80,
                  'unit': 'g',
                  'note': null,
                  'kcal': 303.2,
                  'protein': 10.5,
                  'carb': 54.2,
                  'fat': 5.3,
                  'fiber': 8,
                },
                {
                  'food_item_id': null,
                  'recipe_id': 'r-omelette',
                  'name': 'Veggie Omelette',
                  'amount': 1.5,
                  'unit': 'serving',
                  'note': null,
                  'kcal': 425.1,
                  'protein': 30.84,
                  'carb': 8.24,
                  'fat': 29.34,
                  'fiber': 2.9,
                },
              ],
            },
          ],
        }),
      );

      final s = await api.getFoodLogSummary(_token, DateTime(2026, 10, 20, 9));

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/food-logs/summary');
      expect(req.url.queryParameters, {'date': '2026-10-20'});
      _expectHeaders(req);

      expect(s.date, DateTime(2026, 10, 20));
      expect(s.userId, 'u-liam');
      expect(s.totals.kcal, 1164.26);
      expect(s.totals.fiber, 12.7);
      expect(s.slots.map((x) => (x.slotType, x.count, x.macros.kcal)),
          [(MealSlotType.lunch, 1, 535.56), (MealSlotType.dinner, 2, 470.4)]);
      expect(s.targets!.kcal, 2800);
      expect(s.targets!.carb, 320.5);
      final plan = s.plan!;
      expect(plan.assignmentId, 'a1');
      expect(plan.mealPlanId, 'mp1');
      expect(plan.mealPlanName, '4-Week Lean Bulk');
      expect(plan.weekNumber, 2);
      expect(plan.dayOfWeek, 2);
      expect(plan.dailyMealPlanId, 'dmp1');
      expect(plan.dailyMealPlanName, 'Training day');
      final slot = s.planned.single;
      expect(slot.slotType, MealSlotType.breakfast);
      expect(slot.note, 'Before 9');
      expect(slot.entries, hasLength(2));
      expect(slot.entries[0].foodItemId, 'fi-oats');
      expect(slot.entries[0].name, 'Rolled Oats (Quaker)');
      expect(slot.entries[0].amount, 80);
      expect(slot.entries[0].unit, LogUnit.g);
      expect(slot.entries[0].macros.kcal, 303.2);
      expect(slot.entries[1].recipeId, 'r-omelette');
      expect(slot.entries[1].amount, 1.5);
      expect(slot.entries[1].unit, LogUnit.serving);
      expect(s.hasPlannedMeals, isTrue);
      expect(s.plannedFor(MealSlotType.breakfast), same(slot));
    });

    test('passes user_id for a coach viewing a client', () async {
      backend.on(
        'GET /food-logs/summary',
        ok({
          'date': '2026-10-28',
          'user_id': 'u-client',
          'totals': {'kcal': 0, 'protein': 0, 'carb': 0, 'fat': 0, 'fiber': 0},
          'slots': [],
          'targets': null,
          'plan': null,
          'planned': [],
        }),
      );

      final s = await api.getFoodLogSummary(_token, DateTime(2026, 10, 28), userId: 'u-client');

      expect(backend.only.url.queryParameters, {'date': '2026-10-28', 'user_id': 'u-client'});
      expect(s.userId, 'u-client');
      expect(s.targets, isNull);
      expect(s.plan, isNull);
      expect(s.hasPlannedMeals, isFalse);
    });

    test('403 surfaces the message', () async {
      backend.on('GET /food-logs/summary', err(403, 'Forbidden'));
      await expectLater(api.getFoodLogSummary(_token, DateTime(2026, 10, 28), userId: 'u-x'), _throwsMessage('Forbidden'));
    });
  });

  group('createFoodLog', () {
    test('POSTs a food item entry with the note', () async {
      backend.on('POST /food-logs', ok(_foodLog, 201));

      final log = await api.createFoodLog(
        _token,
        date: DateTime(2026, 10, 27, 8),
        slotType: MealSlotType.afternoonSnack,
        foodItemId: 'fi1',
        amount: 250,
        note: 'with breakfast',
      );

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/food-logs');
      _expectHeaders(req);
      expect(
        bodyOf(req),
        equals({
          'log_date': '2026-10-27',
          'slot_type': 'afternoon_snack',
          'food_item_id': 'fi1',
          'amount': 250,
          'note': 'with breakfast',
        }),
      );
      expect(log.id, 'fl2');
      expect(log.amount, 250);
    });

    test('a recipe entry omits food_item_id and an empty note', () async {
      backend.on('POST /food-logs', ok(_recipeLog, 201));

      for (final note in [null, '']) {
        await api.createFoodLog(_token,
            date: DateTime(2026, 10, 27), slotType: MealSlotType.preWorkout, recipeId: 'r1', amount: 1.5, note: note);
      }

      expect(backend.requests, hasLength(2));
      for (final req in backend.requests) {
        expect(
          bodyOf(req),
          equals({'log_date': '2026-10-27', 'slot_type': 'pre_workout', 'recipe_id': 'r1', 'amount': 1.5}),
        );
      }
    });

    test('400 surfaces the message', () async {
      backend.on('POST /food-logs', err(400, 'amount must be a positive number'));
      await expectLater(
        api.createFoodLog(_token, date: DateTime(2026), slotType: MealSlotType.lunch, foodItemId: 'fi1', amount: 0),
        _throwsMessage('amount must be a positive number'),
      );
    });
  });

  group('updateFoodLog', () {
    test('PUTs every given field to /food-logs/:id', () async {
      backend.on('PUT /food-logs/fl2', ok({..._foodLog, 'amount': '300.00', 'slot_type': 'dinner'}));

      final log = await api.updateFoodLog(_token, 'fl2',
          amount: 300, slotType: MealSlotType.eveningSnack, date: DateTime(2026, 10, 26), note: 'late');

      final req = backend.only;
      expect(req.method, 'PUT');
      expect(pathOf(req), '/food-logs/fl2');
      _expectHeaders(req);
      expect(
        bodyOf(req),
        equals({'amount': 300, 'slot_type': 'evening_snack', 'log_date': '2026-10-26', 'note': 'late'}),
      );
      expect(log.amount, 300);
      expect(log.slotType, MealSlotType.dinner);
    });

    test('omits null fields (amount only)', () async {
      backend.on('PUT /food-logs/fl2', ok(_foodLog));
      await api.updateFoodLog(_token, 'fl2', amount: 125.5);
      expect(bodyOf(backend.only), equals({'amount': 125.5}));
    });

    test('an empty note is sent (the API clears it)', () async {
      backend.on('PUT /food-logs/fl2', ok(_foodLog));
      await api.updateFoodLog(_token, 'fl2', note: '');
      expect(bodyOf(backend.only), equals({'note': ''}));
    });

    test('409 surfaces the message', () async {
      backend.on('PUT /food-logs/fl2',
          err(409, 'The logged item no longer exists; delete this entry and log it again'));
      await expectLater(api.updateFoodLog(_token, 'fl2', amount: 10), _throwsMessage('no longer exists'));
    });
  });

  group('deleteFoodLog', () {
    test('DELETEs /food-logs/:id and accepts 204', () async {
      backend.on('DELETE /food-logs/fl1', ok('', 204));

      await api.deleteFoodLog(_token, 'fl1');

      final req = backend.only;
      expect(req.method, 'DELETE');
      expect(pathOf(req), '/food-logs/fl1');
      _expectHeaders(req);
      expect(req.body, isEmpty);
    });

    test('404 surfaces the message', () async {
      backend.on('DELETE /food-logs/fl1', err(404, 'Food log entry not found'));
      await expectLater(api.deleteFoodLog(_token, 'fl1'), _throwsMessage('Food log entry not found'));
    });
  });

  group('logPlannedMeals', () {
    test('POSTs {date} to /food-logs/from-plan and parses the created entries', () async {
      backend.on('POST /food-logs/from-plan', ok([_recipeLog, _foodLog], 201));

      final logs = await api.logPlannedMeals(_token, DateTime(2026, 10, 27, 12));

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/food-logs/from-plan');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'date': '2026-10-27'}));
      expect(logs.map((l) => l.id), ['fl1', 'fl2']);
    });

    test('one slot only sends slot_type', () async {
      backend.on('POST /food-logs/from-plan', ok([_recipeLog], 201));
      await api.logPlannedMeals(_token, DateTime(2026, 10, 27), slotType: MealSlotType.morningSnack);
      expect(bodyOf(backend.only), equals({'date': '2026-10-27', 'slot_type': 'morning_snack'}));
    });

    test('404 (nothing planned) surfaces the message', () async {
      backend.on('POST /food-logs/from-plan', err(404, 'No planned meals for this date'));
      await expectLater(api.logPlannedMeals(_token, DateTime(2026, 10, 27)), _throwsMessage('No planned meals for this date'));
    });
  });

  group('lookupBarcode', () {
    // Captured from GET /food-items/barcode/0041333018058 (trimmed).
    Map<String, dynamic> almonds(String source) => {
          'id': 'fi-almonds',
          'name': 'Almonds, Raw',
          'brand': null,
          'barcode': '0041333018058',
          'type': 'food',
          'food_subtype': 'nut',
          'drink_subtype': null,
          'spice_subtype': null,
          'serving_unit': 'g',
          'kcal_per_100': '579.00',
          'protein_per_100': '21.20',
          'carb_per_100': '21.60',
          'fat_per_100': '49.90',
          'fiber_per_100': '12.50',
          'author_id': null,
          'is_public': true,
          'is_system': true,
          'created_at': '2026-09-15T16:06:25.140Z',
          'updated_at': '2026-09-15T16:06:25.140Z',
          'vitamins': [
            {
              'vitamin_id': 'v-b1',
              'vitamin': {'id': 'v-b1', 'name': 'Vitamin B1 (Thiamine)', 'symbol': 'B1', 'default_unit': 'mg'},
              'amount_per_100': '0.2050',
              'unit': null,
            },
          ],
          'minerals': [
            {
              'mineral_id': 'm-ca',
              'mineral': {'id': 'm-ca', 'name': 'Calcium', 'symbol': 'Ca', 'default_unit': 'mg'},
              'amount_per_100': '269.0000',
              'unit': null,
            },
          ],
          'source': source,
        };

    test('GETs /food-items/barcode/:code and parses the item and source', () async {
      backend.on('GET /food-items/barcode/0041333018058', ok(almonds('local')));

      final res = await api.lookupBarcode(_token, '0041333018058');

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/food-items/barcode/0041333018058');
      _expectHeaders(req);
      expect(res.source, 'local');
      expect(res.imported, isFalse);
      final i = res.item;
      expect(i.id, 'fi-almonds');
      expect(i.name, 'Almonds, Raw');
      expect(i.brand, isNull);
      expect(i.barcode, '0041333018058');
      expect(i.type, FoodItemType.food);
      expect(i.foodSubtype, FoodSubtype.nut);
      expect(i.drinkSubtype, isNull);
      expect(i.spiceSubtype, isNull);
      expect(i.servingUnit, ServingUnit.g);
      expect(i.kcalPer100, 579.0);
      expect(i.proteinPer100, 21.2);
      expect(i.carbPer100, 21.6);
      expect(i.fatPer100, 49.9);
      expect(i.fiberPer100, 12.5);
      expect(i.authorId, isNull);
      expect(i.isPublic, isTrue);
      expect(i.isSystem, isTrue);
      expect(i.createdAt, DateTime.utc(2026, 9, 15, 16, 6, 25, 140));
      expect(i.vitamins.single.vitaminId, 'v-b1');
      expect(i.vitamins.single.vitamin!.name, 'Vitamin B1 (Thiamine)');
      expect(i.vitamins.single.amountPer100, 0.205);
      expect(i.vitamins.single.displayUnit, 'mg');
      expect(i.minerals.single.mineralId, 'm-ca');
      expect(i.minerals.single.mineral!.symbol, 'Ca');
      expect(i.minerals.single.amountPer100, 269.0);
    });

    test('an Open Food Facts import (201) is flagged as imported', () async {
      backend.on('GET /food-items/barcode/5449000000996', ok(almonds('openfoodfacts'), 201));
      final res = await api.lookupBarcode(_token, '5449000000996');
      expect(res.source, 'openfoodfacts');
      expect(res.imported, isTrue);
    });

    test('a missing source defaults to local', () async {
      backend.on('GET /food-items/barcode/0041333018058', ok(almonds('local')..remove('source')));
      expect((await api.lookupBarcode(_token, '0041333018058')).source, 'local');
    });

    test('URI-encodes the scanned code into one path segment', () async {
      backend.on('GET /food-items/barcode/AB%2012%2F34%3F', ok(almonds('local')));
      await api.lookupBarcode(_token, 'AB 12/34?');
      final req = backend.only;
      expect(req.url.pathSegments.last, 'AB 12/34?');
      expect(req.url.path, endsWith('/food-items/barcode/AB%2012%2F34%3F'));
      expect(req.url.hasQuery, isFalse);
    });

    test('404 throws BarcodeNotFoundException with the code', () async {
      backend.on('GET /food-items/barcode/123', err(404, 'No product found for this barcode'));
      await expectLater(
        api.lookupBarcode(_token, '123'),
        throwsA(isA<BarcodeNotFoundException>().having((e) => e.code, 'code', '123')),
      );
    });

    test('502 (Open Food Facts down) surfaces the message', () async {
      backend.on('GET /food-items/barcode/123', err(502, 'Open Food Facts is unavailable'));
      await expectLater(api.lookupBarcode(_token, '123'), _throwsMessage('Open Food Facts is unavailable'));
    });
  });

  group('getNutrients', () {
    test('GETs /food-items/nutrients and parses vitamins and minerals', () async {
      backend.on(
        'GET /food-items/nutrients',
        ok({
          'vitamins': [
            {'id': 'v-a', 'name': 'Vitamin A', 'symbol': 'A', 'default_unit': 'µg'},
            {'id': 'v-b1', 'name': 'Vitamin B1 (Thiamine)', 'symbol': 'B1', 'default_unit': 'mg'},
          ],
          'minerals': [
            {'id': 'm-ca', 'name': 'Calcium', 'symbol': 'Ca', 'default_unit': 'mg'},
            {'id': 'm-x', 'name': 'Trace', 'symbol': null, 'default_unit': null},
          ],
        }),
      );

      final ref = await api.getNutrients(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/food-items/nutrients');
      _expectHeaders(req);
      expect(ref.vitamins.map((v) => (v.id, v.name, v.symbol, v.defaultUnit)),
          [('v-a', 'Vitamin A', 'A', 'µg'), ('v-b1', 'Vitamin B1 (Thiamine)', 'B1', 'mg')]);
      expect(ref.minerals[0].name, 'Calcium');
      expect(ref.minerals[1].symbol, isNull);
      expect(ref.minerals[1].defaultUnit, 'mg');
    });

    test('401 surfaces the message', () async {
      backend.on('GET /food-items/nutrients', err(401, 'Unauthorized'));
      await expectLater(api.getNutrients(_token), _throwsMessage('Unauthorized'));
    });
  });
}
