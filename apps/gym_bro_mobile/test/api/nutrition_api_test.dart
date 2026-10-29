import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/meal_plan.dart';

import '../helpers/fake_backend.dart';
import 'api_test_utils.dart';

// Bodies captured from the local stack (GET /food-items(/:id), /recipes/:id,
// /daily-meal-plans/:id, /meal-plans/:id, /meal-plan-assignments), trimmed.
// Every numeric column (macros, quantities, servings) arrives as a string.
const elenaId = 'f591534f-a631-4b71-9fd4-b8260e6f3ee6';
const liamId = '8d0b05de-7c18-441b-9536-aaa042eaeaaa';
const almondsId = 'ff93eaf5-72ed-4893-9339-dda2ab96ebf1';
const recipeId = 'f4055f13-e421-4286-af09-3fde822a66d8';
const dayPlanId = '71a9ee83-c1d2-45af-ab18-53f8d60f1533';
const mealPlanId = '7984ff42-0aa9-44a0-81a9-9d974edb2db3';

final almondsJson = {
  'id': almondsId,
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
};

final orangeJuiceJson = {
  'id': '690ab2a7-1c1d-496b-b9d1-8860c03bf60a',
  'name': 'Orange Juice, 100%',
  'brand': 'Tropicana',
  'barcode': '0048500001028',
  'type': 'drink',
  'food_subtype': null,
  'drink_subtype': 'juice_fruit',
  'spice_subtype': null,
  'serving_unit': 'ml',
  'kcal_per_100': '45.00',
  'protein_per_100': '0.70',
  'carb_per_100': '10.40',
  'fat_per_100': '0.20',
  'fiber_per_100': '0.20',
  'author_id': null,
  'is_public': true,
  'is_system': true,
  'created_at': '2026-09-15T16:06:25.152Z',
  'updated_at': '2026-09-15T16:06:25.152Z',
};

final pepperJson = {
  'id': '46f5caa3-c3a2-4220-a8c0-ef4c0670303b',
  'name': 'Black Pepper, Ground',
  'brand': null,
  'barcode': null,
  'type': 'spice',
  'food_subtype': null,
  'drink_subtype': null,
  'spice_subtype': 'spice_ground',
  'serving_unit': 'g',
  'kcal_per_100': '251.00',
  'protein_per_100': '10.40',
  'carb_per_100': '63.90',
  'fat_per_100': '3.30',
  'fiber_per_100': '25.30',
  'author_id': elenaId,
  'is_public': false,
  'is_system': false,
  'created_at': '2026-09-15T16:06:25.156Z',
  'updated_at': '2026-09-15T16:06:25.156Z',
};

final almondsDetailJson = {
  ...almondsJson,
  'vitamins': [
    {
      'vitamin_id': '79d4ce76-cf1b-432a-b57f-3b6a579294eb',
      'vitamin': {'id': '79d4ce76-cf1b-432a-b57f-3b6a579294eb', 'name': 'Vitamin B1 (Thiamine)', 'symbol': 'B1', 'default_unit': 'mg'},
      'amount_per_100': '0.2050',
      'unit': null,
    },
    {
      'vitamin_id': '77839d0b-72a4-4bf4-b129-67e2da1effd3',
      'vitamin': {'id': '77839d0b-72a4-4bf4-b129-67e2da1effd3', 'name': 'Vitamin B9 (Folate)', 'symbol': 'B9', 'default_unit': 'µg'},
      'amount_per_100': '44.0000',
      'unit': 'µg',
    },
  ],
  'minerals': [
    {
      'mineral_id': '6c73401f-17a1-4d50-84ff-232098a7a797',
      'mineral': {'id': '6c73401f-17a1-4d50-84ff-232098a7a797', 'name': 'Calcium', 'symbol': 'Ca', 'default_unit': 'mg'},
      'amount_per_100': '269.0000',
      'unit': null,
    },
  ],
};

final recipeListJson = {
  'id': recipeId,
  'name': 'Post-Workout Smoothie',
  'description': 'A quick blended shake combining whey protein, banana, and peanut butter.',
  'author_id': elenaId,
  'servings': 1,
  'prep_time_minutes': 5,
  'cook_time_minutes': 0,
  'kcal_per_serving': '508.60',
  'protein_per_serving': '38.74',
  'carb_per_serving': '48.97',
  'fat_per_serving': '20.29',
  'fiber_per_serving': '7.76',
  'is_public': true,
  'is_system': false,
  'created_at': '2026-09-15T16:06:25.208Z',
  'updated_at': '2026-09-15T16:06:25.208Z',
};

final wheyJson = {
  ...almondsJson,
  'id': '6e1463d1-04f0-4c5c-92cf-ff6662ee17a7',
  'name': 'Whey Protein Powder, Vanilla',
  'brand': 'Optimum Nutrition',
  'food_subtype': 'supplement_powder',
  'kcal_per_100': '375.00',
  'protein_per_100': '80.00',
};

final recipeDetailJson = {
  ...recipeListJson,
  'ingredients': [
    {
      'id': '40d3eadc-f48f-431b-84e9-ccc3c2c2eef4',
      'recipe_id': recipeId,
      'food_item_id': '6e1463d1-04f0-4c5c-92cf-ff6662ee17a7',
      'quantity': '30.00',
      'note': null,
      'position': 0,
      'food_item': wheyJson,
    },
    {
      'id': 'ing-2',
      'recipe_id': recipeId,
      'food_item_id': orangeJuiceJson['id'],
      'quantity': '250.00',
      'note': 'Chilled',
      'position': 1,
      'food_item': orangeJuiceJson,
    },
  ],
  'steps': [
    {'id': '24dbc25f-c486-4dfa-98fd-287dc29339c9', 'recipe_id': recipeId, 'position': 0, 'instruction': 'Add all ingredients to a blender.', 'image_url': null},
    {'id': 'step-2', 'recipe_id': recipeId, 'position': 1, 'instruction': 'Blend for 45 seconds.', 'image_url': 'https://example.com/blend.jpg'},
  ],
  'images': [
    {'id': '6e82e608-987e-44ec-9e26-5f09c88f2ead', 'recipe_id': recipeId, 'url': 'https://picsum.photos/seed/recipe-Post-Workout%20Smoothie/800/600', 'is_thumbnail': true, 'position': 0},
  ],
  'videos': [
    {'id': 'vid-1', 'recipe_id': recipeId, 'url': 'https://youtu.be/xyz', 'title': null, 'position': 0},
  ],
};

final dayPlanListJson = {
  'id': dayPlanId,
  'name': 'Vegetarian Reset Day',
  'description': 'A fully plant-based day built around tofu, quinoa, and whole grains.',
  'author_id': elenaId,
  'is_public': true,
  'is_system': false,
  'kcal_total': '1744.30',
  'protein_total': '101.35',
  'carb_total': '193.74',
  'fat_total': '68.13',
  'fiber_total': '35.65',
  'created_at': '2026-09-15T16:06:25.249Z',
  'updated_at': '2026-09-15T16:06:25.249Z',
  'meal_count': 4,
};

final dayPlanDetailJson = {
  ...Map.of(dayPlanListJson)..remove('meal_count'),
  'slots': [
    {
      'id': '81faad83-6224-40f9-be14-be2d1f5b0a6e',
      'daily_meal_plan_id': dayPlanId,
      'slot_type': 'breakfast',
      'position': 0,
      'note': null,
      'entries': [
        {
          'id': 'a533dbde-80ee-4f95-964c-3995d653bd0c',
          'daily_meal_plan_slot_id': '81faad83-6224-40f9-be14-be2d1f5b0a6e',
          'food_item_id': null,
          'recipe_id': recipeId,
          'quantity': null,
          'servings': '1.50',
          'position': 0,
          'note': null,
          'food_item': null,
          'recipe': recipeListJson,
        },
      ],
    },
    {
      'id': '572104e4-b177-4bbf-8407-2b7c4d1ff8b7',
      'daily_meal_plan_id': dayPlanId,
      'slot_type': 'afternoon_snack',
      'position': 2,
      'note': 'Before training',
      'entries': [
        {
          'id': '1d6787b9-0f24-404b-b6f4-639ffb712c3b',
          'daily_meal_plan_slot_id': '572104e4-b177-4bbf-8407-2b7c4d1ff8b7',
          'food_item_id': almondsId,
          'recipe_id': null,
          'quantity': '20.00',
          'servings': null,
          'position': 0,
          'note': null,
          'food_item': almondsJson,
          'recipe': null,
        },
      ],
    },
  ],
};

final mealPlanListJson = {
  'id': mealPlanId,
  'name': '1-Week Vegetarian Kickstart',
  'description': 'A one-week introductory plan for members trying a meat-free approach.',
  'author_id': elenaId,
  'is_public': true,
  'is_system': false,
  'num_weeks': 1,
  'created_at': '2026-09-15T16:06:25.269Z',
  'updated_at': '2026-09-15T16:06:25.269Z',
  'images': [
    {
      'id': '6a15b9fe-6d5a-4b76-8d3b-55a143293a38',
      'meal_plan_id': mealPlanId,
      'url': 'https://picsum.photos/seed/mealplan-1-Week%20Vegetarian%20Kickstart/800/600',
      'is_thumbnail': true,
      'position': 0,
    },
  ],
};

final mealPlanDetailJson = {
  ...mealPlanListJson,
  'days': [
    {
      'id': 'b96713ef-b5ec-4261-ae30-682e6023b301',
      'meal_plan_id': mealPlanId,
      'daily_meal_plan_id': dayPlanId,
      'week_number': 1,
      'day_of_week': 1,
      'note': null,
      'daily_meal_plan': Map.of(dayPlanListJson)..remove('meal_count'),
    },
    {
      'id': 'day-2',
      'meal_plan_id': mealPlanId,
      'daily_meal_plan_id': dayPlanId,
      'week_number': 1,
      'day_of_week': 2,
      'note': 'Rest day',
      'daily_meal_plan': null,
    },
  ],
};

final assignmentJson = {
  'id': '8b70097a-abc0-49a9-8167-aee330d773bc',
  'meal_plan_id': '98b62413-47de-4917-9ab8-d4726e1f81eb',
  'user_id': liamId,
  'assigned_by_id': elenaId,
  'start_date': '2026-09-15T00:00:00.000Z',
  'end_date': null,
  'note': null,
  'created_at': '2026-09-15T16:06:25.275Z',
  'meal_plan': {
    'id': '98b62413-47de-4917-9ab8-d4726e1f81eb',
    'name': '4-Week Lean Bulk',
    'description': 'A four-week progressive nutrition plan.',
    'author_id': elenaId,
    'is_public': true,
    'is_system': false,
    'num_weeks': 4,
    'created_at': '2026-09-15T16:06:25.258Z',
    'updated_at': '2026-09-15T16:06:25.258Z',
  },
  'meal_plan_name': '4-Week Lean Bulk',
  'assigned_by_name': 'Elena Vasquez',
  'user_name': "Liam O'Connor",
};

void main() {
  final ctx = useFakeBackend();
  FakeBackend backend() => ctx.backend();

  group('food items', () {
    test('getFoodItems parses food/drink/spice rows with string macros', () async {
      backend().on('GET /food-items', ok([almondsJson, orangeJuiceJson, pepperJson]));
      final items = await ctx.api().getFoodItems(token);
      expectGet(backend().only, '/food-items', {'page': '0', 'page_size': '20'});

      final a = items[0];
      expect(a.id, almondsId);
      expect(a.name, 'Almonds, Raw');
      expect(a.brand, isNull);
      expect(a.barcode, '0041333018058');
      expect(a.type, FoodItemType.food);
      expect(a.foodSubtype, FoodSubtype.nut);
      expect(a.drinkSubtype, isNull);
      expect(a.spiceSubtype, isNull);
      expect(a.servingUnit, ServingUnit.g);
      expect(a.kcalPer100, 579.0);
      expect(a.proteinPer100, 21.2);
      expect(a.carbPer100, 21.6);
      expect(a.fatPer100, 49.9);
      expect(a.fiberPer100, 12.5);
      expect(a.authorId, isNull);
      expect(a.isPublic, isTrue);
      expect(a.isSystem, isTrue);
      expect(a.vitamins, isEmpty);
      expect(a.minerals, isEmpty);
      expect(a.createdAt, DateTime.utc(2026, 9, 15, 16, 6, 25, 140));

      final oj = items[1];
      expect(oj.type, FoodItemType.drink);
      expect(oj.drinkSubtype, DrinkSubtype.juiceFruit);
      expect(oj.foodSubtype, isNull);
      expect(oj.servingUnit, ServingUnit.ml);
      expect(oj.brand, 'Tropicana');
      expect(oj.proteinPer100, 0.7);

      final pepper = items[2];
      expect(pepper.type, FoodItemType.spice);
      expect(pepper.spiceSubtype, SpiceSubtype.spiceGround);
      expect(pepper.barcode, isNull);
      expect(pepper.authorId, elenaId);
      expect(pepper.isPublic, isFalse);
      expect(pepper.isSystem, isFalse);
    });

    test('getFoodItems sends name (encoded), type and mine', () async {
      backend().on('GET /food-items', ok([]));
      await ctx.api().getFoodItems(token, name: 'oats & honey', type: FoodItemType.drink, mine: true, page: 2, pageSize: 40);
      final r = backend().only;
      expectGet(r, '/food-items', {'page': '2', 'page_size': '40', 'name': 'oats & honey', 'type': 'drink', 'mine': 'true'});
      expect(r.url.query, contains('name=oats%20%26%20honey'));
    });

    test('getFoodItems treats 404 as an empty list', () async {
      backend().on('GET /food-items', err(404, 'Not found'));
      expect(await ctx.api().getFoodItems(token), isEmpty);
    });

    test('getFoodItem parses vitamins and minerals', () async {
      backend().on('GET /food-items/$almondsId', ok(almondsDetailJson));
      final f = await ctx.api().getFoodItem(token, almondsId);
      expectGet(backend().only, '/food-items/$almondsId');
      expect(f.vitamins, hasLength(2));
      final b1 = f.vitamins[0];
      expect(b1.vitaminId, '79d4ce76-cf1b-432a-b57f-3b6a579294eb');
      expect(b1.vitamin!.name, 'Vitamin B1 (Thiamine)');
      expect(b1.vitamin!.symbol, 'B1');
      expect(b1.vitamin!.defaultUnit, 'mg');
      expect(b1.amountPer100, 0.205);
      expect(b1.unit, isNull);
      expect(f.vitamins[1].amountPer100, 44.0);
      expect(f.vitamins[1].unit, 'µg');
      final ca = f.minerals.single;
      expect(ca.mineralId, '6c73401f-17a1-4d50-84ff-232098a7a797');
      expect(ca.mineral!.symbol, 'Ca');
      expect(ca.amountPer100, 269.0);
    });

    final foodBody = {
      'name': 'Greek Yogurt 2%',
      'brand': 'Fage',
      'barcode': null,
      'type': 'food',
      'food_subtype': 'dairy_yogurt',
      'drink_subtype': null,
      'spice_subtype': null,
      'serving_unit': 'g',
      'kcal_per_100': 73.0,
      'protein_per_100': 9.9,
      'carb_per_100': 3.9,
      'fat_per_100': 2.0,
      'fiber_per_100': 0.0,
      'is_public': false,
      'vitamins': [
        {'vitamin_id': '79d4ce76-cf1b-432a-b57f-3b6a579294eb', 'amount_per_100': 0.04, 'unit': null},
      ],
      'minerals': <Object>[],
    };

    test('createFoodItem POSTs the body', () async {
      backend().on('POST /food-items', ok({...almondsJson, 'id': 'f-new', 'name': 'Greek Yogurt 2%'}, 201));
      final f = await ctx.api().createFoodItem(token, foodBody);
      expectJson(backend().only, 'POST', '/food-items', foodBody);
      expect(f.id, 'f-new');
    });

    test('updateFoodItem PUTs /food-items/:id', () async {
      backend().on('PUT /food-items/$almondsId', ok(almondsDetailJson));
      final f = await ctx.api().updateFoodItem(token, almondsId, foodBody);
      expectJson(backend().only, 'PUT', '/food-items/$almondsId', foodBody);
      expect(f.minerals, hasLength(1));
    });

    test('deleteFoodItem DELETEs /food-items/:id', () async {
      backend().on('DELETE /food-items/$almondsId', ok('', 204));
      await ctx.api().deleteFoodItem(token, almondsId);
      expectDelete(backend().only, '/food-items/$almondsId');
    });
  });

  group('recipes', () {
    test('getRecipes: list shape, string per-serving macros, filters', () async {
      backend().on('GET /recipes', ok([recipeListJson]));
      final r = (await ctx.api().getRecipes(token)).single;
      expectGet(backend().requests.last, '/recipes', {'page': '0', 'page_size': '20'});
      expect(r.id, recipeId);
      expect(r.name, 'Post-Workout Smoothie');
      expect(r.authorId, elenaId);
      expect(r.servings, 1);
      expect(r.prepTimeMinutes, 5);
      expect(r.cookTimeMinutes, 0);
      expect(r.kcalPerServing, 508.6);
      expect(r.proteinPerServing, 38.74);
      expect(r.carbPerServing, 48.97);
      expect(r.fatPerServing, 20.29);
      expect(r.fiberPerServing, 7.76);
      expect(r.isPublic, isTrue);
      expect(r.isSystem, isFalse);
      expect(r.ingredients, isEmpty);
      expect(r.steps, isEmpty);

      await ctx.api().getRecipes(token, name: 'smoothie', mine: true, page: 1, pageSize: 10);
      expectGet(backend().requests.last, '/recipes', {'page': '1', 'page_size': '10', 'name': 'smoothie', 'mine': 'true'});
    });

    test('getRecipes treats 404 as an empty list', () async {
      backend().on('GET /recipes', err(404, 'Not found'));
      expect(await ctx.api().getRecipes(token), isEmpty);
    });

    test('getRecipe parses ingredients (nested food items), steps, images, videos', () async {
      backend().on('GET /recipes/$recipeId', ok(recipeDetailJson));
      final r = await ctx.api().getRecipe(token, recipeId);
      expectGet(backend().only, '/recipes/$recipeId');

      expect(r.ingredients, hasLength(2));
      final whey = r.ingredients[0];
      expect(whey.id, '40d3eadc-f48f-431b-84e9-ccc3c2c2eef4');
      expect(whey.recipeId, recipeId);
      expect(whey.foodItemId, '6e1463d1-04f0-4c5c-92cf-ff6662ee17a7');
      expect(whey.quantity, 30.0);
      expect(whey.note, isNull);
      expect(whey.position, 0);
      expect(whey.foodItem!.name, 'Whey Protein Powder, Vanilla');
      expect(whey.foodItem!.foodSubtype, FoodSubtype.supplementPowder);
      expect(whey.foodItem!.proteinPer100, 80.0);
      expect(r.ingredients[1].quantity, 250.0);
      expect(r.ingredients[1].note, 'Chilled');
      expect(r.ingredients[1].foodItem!.servingUnit, ServingUnit.ml);

      expect(r.steps.map((s) => (s.position, s.instruction, s.imageUrl)), [
        (0, 'Add all ingredients to a blender.', null),
        (1, 'Blend for 45 seconds.', 'https://example.com/blend.jpg'),
      ]);
      expect(r.images.single.isThumbnail, isTrue);
      expect(r.images.single.recipeId, recipeId);
      expect(r.videos.single.url, 'https://youtu.be/xyz');
      expect(r.videos.single.title, isNull);
    });

    final recipeBody = {
      'name': 'Post-Workout Smoothie',
      'description': null,
      'servings': 2,
      'prep_time_minutes': 5,
      'cook_time_minutes': null,
      'is_public': true,
      'ingredients': [
        {'food_item_id': '6e1463d1-04f0-4c5c-92cf-ff6662ee17a7', 'quantity': 30.0, 'note': null, 'position': 0},
      ],
      'steps': [
        {'position': 0, 'instruction': 'Blend.', 'image_url': null},
      ],
      'images': <Object>[],
      'videos': <Object>[],
    };

    test('createRecipe POSTs the nested body', () async {
      backend().on('POST /recipes', ok(recipeDetailJson, 201));
      final r = await ctx.api().createRecipe(token, recipeBody);
      expectJson(backend().only, 'POST', '/recipes', recipeBody);
      expect(r.ingredients, hasLength(2));
    });

    test('updateRecipe PUTs /recipes/:id', () async {
      backend().on('PUT /recipes/$recipeId', ok(recipeDetailJson));
      await ctx.api().updateRecipe(token, recipeId, recipeBody);
      expectJson(backend().only, 'PUT', '/recipes/$recipeId', recipeBody);
    });

    test('deleteRecipe DELETEs /recipes/:id', () async {
      backend().on('DELETE /recipes/$recipeId', ok('', 204));
      await ctx.api().deleteRecipe(token, recipeId);
      expectDelete(backend().only, '/recipes/$recipeId');
    });
  });

  group('daily meal plans', () {
    test('getDailyMealPlans: totals as strings, meal_count; filters', () async {
      backend().on('GET /daily-meal-plans', ok([dayPlanListJson]));
      final d = (await ctx.api().getDailyMealPlans(token)).single;
      expectGet(backend().requests.last, '/daily-meal-plans', {'page': '0', 'page_size': '20'});
      expect(d.id, dayPlanId);
      expect(d.name, 'Vegetarian Reset Day');
      expect(d.authorId, elenaId);
      expect(d.kcalTotal, 1744.3);
      expect(d.proteinTotal, 101.35);
      expect(d.carbTotal, 193.74);
      expect(d.fatTotal, 68.13);
      expect(d.fiberTotal, 35.65);
      expect(d.mealCount, 4);
      expect(d.slots, isEmpty);

      await ctx.api().getDailyMealPlans(token, name: 'reset', mine: true, page: 3, pageSize: 7);
      expectGet(backend().requests.last, '/daily-meal-plans', {'page': '3', 'page_size': '7', 'name': 'reset', 'mine': 'true'});
    });

    test('getDailyMealPlans treats 404 as an empty list', () async {
      backend().on('GET /daily-meal-plans', err(404, 'Not found'));
      expect(await ctx.api().getDailyMealPlans(token), isEmpty);
    });

    test('getDailyMealPlan parses slots with recipe and food entries', () async {
      backend().on('GET /daily-meal-plans/$dayPlanId', ok(dayPlanDetailJson));
      final d = await ctx.api().getDailyMealPlan(token, dayPlanId);
      expectGet(backend().only, '/daily-meal-plans/$dayPlanId');
      expect(d.mealCount, isNull);
      expect(d.slots, hasLength(2));

      final breakfast = d.slots[0];
      expect(breakfast.id, '81faad83-6224-40f9-be14-be2d1f5b0a6e');
      expect(breakfast.dailyMealPlanId, dayPlanId);
      expect(breakfast.slotType, MealSlotType.breakfast);
      expect(breakfast.position, 0);
      final oats = breakfast.entries.single;
      expect(oats.slotId, breakfast.id);
      expect(oats.foodItemId, isNull);
      expect(oats.foodItem, isNull);
      expect(oats.recipeId, recipeId);
      expect(oats.recipe!.kcalPerServing, 508.6);
      expect(oats.quantity, isNull);
      expect(oats.servings, 1.5);

      final snack = d.slots[1];
      expect(snack.slotType, MealSlotType.afternoonSnack);
      expect(snack.note, 'Before training');
      final almonds = snack.entries.single;
      expect(almonds.foodItemId, almondsId);
      expect(almonds.foodItem!.name, 'Almonds, Raw');
      expect(almonds.recipe, isNull);
      expect(almonds.quantity, 20.0);
      expect(almonds.servings, 1.0, reason: 'null servings default to 1');
    });

    final dayBody = {
      'name': 'Vegetarian Reset Day',
      'description': null,
      'is_public': true,
      'slots': [
        {
          'slot_type': 'morning_snack',
          'position': 0,
          'note': null,
          'entries': [
            {'food_item_id': almondsId, 'recipe_id': null, 'quantity': 20.0, 'servings': null, 'position': 0, 'note': null},
            {'food_item_id': null, 'recipe_id': recipeId, 'quantity': null, 'servings': 1.0, 'position': 1, 'note': null},
          ],
        },
      ],
    };

    test('createDailyMealPlan POSTs the body', () async {
      backend().on('POST /daily-meal-plans', ok(dayPlanDetailJson, 201));
      final d = await ctx.api().createDailyMealPlan(token, dayBody);
      expectJson(backend().only, 'POST', '/daily-meal-plans', dayBody);
      expect(d.slots, hasLength(2));
    });

    test('updateDailyMealPlan PUTs /daily-meal-plans/:id', () async {
      backend().on('PUT /daily-meal-plans/$dayPlanId', ok(dayPlanDetailJson));
      await ctx.api().updateDailyMealPlan(token, dayPlanId, dayBody);
      expectJson(backend().only, 'PUT', '/daily-meal-plans/$dayPlanId', dayBody);
    });

    test('deleteDailyMealPlan DELETEs /daily-meal-plans/:id', () async {
      backend().on('DELETE /daily-meal-plans/$dayPlanId', ok('', 204));
      await ctx.api().deleteDailyMealPlan(token, dayPlanId);
      expectDelete(backend().only, '/daily-meal-plans/$dayPlanId');
    });
  });

  group('meal plans', () {
    test('getMealPlans: list shape with images; filters', () async {
      backend().on('GET /meal-plans', ok([mealPlanListJson]));
      final m = (await ctx.api().getMealPlans(token)).single;
      expectGet(backend().requests.last, '/meal-plans', {'page': '0', 'page_size': '20'});
      expect(m.id, mealPlanId);
      expect(m.name, '1-Week Vegetarian Kickstart');
      expect(m.numWeeks, 1);
      expect(m.isPublic, isTrue);
      expect(m.isSystem, isFalse);
      expect(m.days, isEmpty);
      expect(m.images.single.mealPlanId, mealPlanId);
      expect(m.images.single.isThumbnail, isTrue);

      await ctx.api().getMealPlans(token, name: 'bulk', mine: true);
      expectGet(backend().requests.last, '/meal-plans', {'page': '0', 'page_size': '20', 'name': 'bulk', 'mine': 'true'});
    });

    test('getMealPlans treats 404 as an empty list', () async {
      backend().on('GET /meal-plans', err(404, 'Not found'));
      expect(await ctx.api().getMealPlans(token), isEmpty);
    });

    test('getMealPlan parses days with embedded daily plans', () async {
      backend().on('GET /meal-plans/$mealPlanId', ok(mealPlanDetailJson));
      final m = await ctx.api().getMealPlan(token, mealPlanId);
      expectGet(backend().only, '/meal-plans/$mealPlanId');
      expect(m.days, hasLength(2));
      final d = m.days[0];
      expect(d.id, 'b96713ef-b5ec-4261-ae30-682e6023b301');
      expect(d.mealPlanId, mealPlanId);
      expect(d.dailyMealPlanId, dayPlanId);
      expect(d.weekNumber, 1);
      expect(d.dayOfWeek, 1);
      expect(d.note, isNull);
      expect(d.dailyMealPlan!.kcalTotal, 1744.3);
      expect(m.days[1].dayOfWeek, 2);
      expect(m.days[1].note, 'Rest day');
      expect(m.days[1].dailyMealPlan, isNull);
    });

    final planBody = {
      'name': '1-Week Vegetarian Kickstart',
      'description': null,
      'is_public': false,
      'num_weeks': 1,
      'days': [
        {'daily_meal_plan_id': dayPlanId, 'week_number': 1, 'day_of_week': 1, 'note': null},
      ],
      'images': <Object>[],
    };

    test('createMealPlan POSTs the body', () async {
      backend().on('POST /meal-plans', ok(mealPlanDetailJson, 201));
      final m = await ctx.api().createMealPlan(token, planBody);
      expectJson(backend().only, 'POST', '/meal-plans', planBody);
      expect(m.days, hasLength(2));
    });

    test('updateMealPlan PUTs /meal-plans/:id', () async {
      backend().on('PUT /meal-plans/$mealPlanId', ok(mealPlanDetailJson));
      await ctx.api().updateMealPlan(token, mealPlanId, planBody);
      expectJson(backend().only, 'PUT', '/meal-plans/$mealPlanId', planBody);
    });

    test('deleteMealPlan DELETEs /meal-plans/:id', () async {
      backend().on('DELETE /meal-plans/$mealPlanId', ok('', 204));
      await ctx.api().deleteMealPlan(token, mealPlanId);
      expectDelete(backend().only, '/meal-plans/$mealPlanId');
    });
  });

  group('meal plan assignments', () {
    test('getMealPlanAssignments parses the joined names and dates; filters', () async {
      backend().on('GET /meal-plan-assignments', ok([assignmentJson]));
      final a = (await ctx.api().getMealPlanAssignments(token)).single;
      expectGet(backend().requests.last, '/meal-plan-assignments');
      expect(a.id, '8b70097a-abc0-49a9-8167-aee330d773bc');
      expect(a.mealPlanId, '98b62413-47de-4917-9ab8-d4726e1f81eb');
      expect(a.userId, liamId);
      expect(a.assignedById, elenaId);
      expect(a.startDate, DateTime.utc(2026, 9, 15));
      expect(a.endDate, isNull);
      expect(a.note, isNull);
      expect(a.createdAt, DateTime.utc(2026, 9, 15, 16, 6, 25, 275));
      expect(a.mealPlan!.name, '4-Week Lean Bulk');
      expect(a.mealPlan!.numWeeks, 4);
      expect(a.mealPlanName, '4-Week Lean Bulk');
      expect(a.assignedByName, 'Elena Vasquez');
      expect(a.userName, "Liam O'Connor");

      await ctx.api().getMealPlanAssignments(token, userId: liamId, mealPlanId: mealPlanId);
      expectGet(backend().requests.last, '/meal-plan-assignments', {'user_id': liamId, 'meal_plan_id': mealPlanId});
    });

    test('getMealPlanAssignments treats 404 as an empty list', () async {
      backend().on('GET /meal-plan-assignments', err(404, 'Not found'));
      expect(await ctx.api().getMealPlanAssignments(token), isEmpty);
    });

    test('createMealPlanAssignment POSTs the body', () async {
      final body = {
        'meal_plan_id': mealPlanId,
        'user_id': liamId,
        'start_date': '2026-11-02',
        'end_date': null,
        'note': 'Start Monday',
      };
      backend().on('POST /meal-plan-assignments', ok({
        ...assignmentJson,
        'meal_plan_id': mealPlanId,
        'start_date': '2026-11-02T00:00:00.000Z',
        'note': 'Start Monday',
        'meal_plan': null,
      }, 201));
      final a = await ctx.api().createMealPlanAssignment(token, body);
      expectJson(backend().only, 'POST', '/meal-plan-assignments', body);
      expect(a.mealPlanId, mealPlanId);
      expect(a.startDate, DateTime.utc(2026, 11, 2));
      expect(a.note, 'Start Monday');
      expect(a.mealPlan, isNull);
    });

    test('deleteMealPlanAssignment DELETEs /meal-plan-assignments/:id', () async {
      backend().on('DELETE /meal-plan-assignments/a-1', ok('', 204));
      await ctx.api().deleteMealPlanAssignment(token, 'a-1');
      expectDelete(backend().only, '/meal-plan-assignments/a-1');
    });
  });

  errorTests(ctx, {
    'getFoodItems': ('GET /food-items', (api) => api.getFoodItems(token)),
    'getFoodItem': ('GET /food-items/$almondsId', (api) => api.getFoodItem(token, almondsId)),
    'createFoodItem': ('POST /food-items', (api) => api.createFoodItem(token, {'name': 'x'})),
    'updateFoodItem': ('PUT /food-items/$almondsId', (api) => api.updateFoodItem(token, almondsId, {'name': 'x'})),
    'deleteFoodItem': ('DELETE /food-items/$almondsId', (api) => api.deleteFoodItem(token, almondsId)),
    'getRecipes': ('GET /recipes', (api) => api.getRecipes(token)),
    'getRecipe': ('GET /recipes/$recipeId', (api) => api.getRecipe(token, recipeId)),
    'createRecipe': ('POST /recipes', (api) => api.createRecipe(token, {'name': 'x'})),
    'updateRecipe': ('PUT /recipes/$recipeId', (api) => api.updateRecipe(token, recipeId, {'name': 'x'})),
    'deleteRecipe': ('DELETE /recipes/$recipeId', (api) => api.deleteRecipe(token, recipeId)),
    'getDailyMealPlans': ('GET /daily-meal-plans', (api) => api.getDailyMealPlans(token)),
    'getDailyMealPlan': ('GET /daily-meal-plans/$dayPlanId', (api) => api.getDailyMealPlan(token, dayPlanId)),
    'createDailyMealPlan': ('POST /daily-meal-plans', (api) => api.createDailyMealPlan(token, {'name': 'x'})),
    'updateDailyMealPlan': ('PUT /daily-meal-plans/$dayPlanId', (api) => api.updateDailyMealPlan(token, dayPlanId, {'name': 'x'})),
    'deleteDailyMealPlan': ('DELETE /daily-meal-plans/$dayPlanId', (api) => api.deleteDailyMealPlan(token, dayPlanId)),
    'getMealPlans': ('GET /meal-plans', (api) => api.getMealPlans(token)),
    'getMealPlan': ('GET /meal-plans/$mealPlanId', (api) => api.getMealPlan(token, mealPlanId)),
    'createMealPlan': ('POST /meal-plans', (api) => api.createMealPlan(token, {'name': 'x'})),
    'updateMealPlan': ('PUT /meal-plans/$mealPlanId', (api) => api.updateMealPlan(token, mealPlanId, {'name': 'x'})),
    'deleteMealPlan': ('DELETE /meal-plans/$mealPlanId', (api) => api.deleteMealPlan(token, mealPlanId)),
    'getMealPlanAssignments': ('GET /meal-plan-assignments', (api) => api.getMealPlanAssignments(token)),
    'createMealPlanAssignment': ('POST /meal-plan-assignments', (api) => api.createMealPlanAssignment(token, {'user_id': 'x'})),
    'deleteMealPlanAssignment': ('DELETE /meal-plan-assignments/a-1', (api) => api.deleteMealPlanAssignment(token, 'a-1')),
  });
}
