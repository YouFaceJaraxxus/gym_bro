import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import 'food_log.dart' show fmtAmount;

// Postgres numeric columns are serialized as JSON strings by the API, so these
// fields can arrive as either a String or a num depending on the endpoint.
double? _toDouble(dynamic v) => v == null ? null : double.parse(v.toString());

/// Short weekday name for ISO [dayOfWeek] (1 = Monday) in [locale].
String shortWeekdayName(int dayOfWeek, String locale) =>
    // 2024-01-01 was a Monday.
    DateFormat.E(locale).format(DateTime(2024, 1, dayOfWeek));

// ── Enums ──────────────────────────────────────────────────────────────────────

enum FoodItemType {
  food,
  spice,
  drink;

  static const _api = {food: 'food', spice: 'spice', drink: 'drink'};

  String get apiValue => _api[this]!;
  String label(AppLocalizations l10n) => switch (this) {
    FoodItemType.food => l10n.nutritionTypeFood,
    FoodItemType.spice => l10n.nutritionTypeSpice,
    FoodItemType.drink => l10n.nutritionTypeDrink,
  };

  static FoodItemType? fromApiValue(String v) =>
      _api.entries.where((e) => e.value == v).map((e) => e.key).firstOrNull;
}

enum FoodSubtype {
  vegetable,
  fruit,
  mushroom,
  herbFresh,
  meatBeef,
  meatPork,
  meatLamb,
  meatGame,
  poultry,
  fish,
  seafood,
  egg,
  dairyMilk,
  dairyCheese,
  dairyYogurt,
  dairyCream,
  dairyButter,
  plantMilk,
  grainCereal,
  pastaNoodle,
  rice,
  breadBakery,
  potatoTuber,
  cornMaize,
  legumeBean,
  legumeLentil,
  nut,
  seed,
  oilFat,
  cannedFood,
  frozenFood,
  processedMeat,
  readyMeal,
  snackChips,
  snackBar,
  cerealBar,
  chocolateCandy,
  biscuitCookie,
  sweetener,
  jamSpread,
  bakingIngredient,
  sauceCondiment,
  dressing,
  babyFood,
  supplementPowder,
  otherFood;

  static const _api = {
    FoodSubtype.vegetable: 'vegetable',
    FoodSubtype.fruit: 'fruit',
    FoodSubtype.mushroom: 'mushroom',
    FoodSubtype.herbFresh: 'herb_fresh',
    FoodSubtype.meatBeef: 'meat_beef',
    FoodSubtype.meatPork: 'meat_pork',
    FoodSubtype.meatLamb: 'meat_lamb',
    FoodSubtype.meatGame: 'meat_game',
    FoodSubtype.poultry: 'poultry',
    FoodSubtype.fish: 'fish',
    FoodSubtype.seafood: 'seafood',
    FoodSubtype.egg: 'egg',
    FoodSubtype.dairyMilk: 'dairy_milk',
    FoodSubtype.dairyCheese: 'dairy_cheese',
    FoodSubtype.dairyYogurt: 'dairy_yogurt',
    FoodSubtype.dairyCream: 'dairy_cream',
    FoodSubtype.dairyButter: 'dairy_butter',
    FoodSubtype.plantMilk: 'plant_milk',
    FoodSubtype.grainCereal: 'grain_cereal',
    FoodSubtype.pastaNoodle: 'pasta_noodle',
    FoodSubtype.rice: 'rice',
    FoodSubtype.breadBakery: 'bread_bakery',
    FoodSubtype.potatoTuber: 'potato_tuber',
    FoodSubtype.cornMaize: 'corn_maize',
    FoodSubtype.legumeBean: 'legume_bean',
    FoodSubtype.legumeLentil: 'legume_lentil',
    FoodSubtype.nut: 'nut',
    FoodSubtype.seed: 'seed',
    FoodSubtype.oilFat: 'oil_fat',
    FoodSubtype.cannedFood: 'canned_food',
    FoodSubtype.frozenFood: 'frozen_food',
    FoodSubtype.processedMeat: 'processed_meat',
    FoodSubtype.readyMeal: 'ready_meal',
    FoodSubtype.snackChips: 'snack_chips',
    FoodSubtype.snackBar: 'snack_bar',
    FoodSubtype.cerealBar: 'cereal_bar',
    FoodSubtype.chocolateCandy: 'chocolate_candy',
    FoodSubtype.biscuitCookie: 'biscuit_cookie',
    FoodSubtype.sweetener: 'sweetener',
    FoodSubtype.jamSpread: 'jam_spread',
    FoodSubtype.bakingIngredient: 'baking_ingredient',
    FoodSubtype.sauceCondiment: 'sauce_condiment',
    FoodSubtype.dressing: 'dressing',
    FoodSubtype.babyFood: 'baby_food',
    FoodSubtype.supplementPowder: 'supplement_powder',
    FoodSubtype.otherFood: 'other_food',
  };

  String get apiValue => _api[this]!;
  String label(AppLocalizations l10n) => switch (this) {
    FoodSubtype.vegetable => l10n.nutritionFoodVegetable,
    FoodSubtype.fruit => l10n.nutritionFoodFruit,
    FoodSubtype.mushroom => l10n.nutritionFoodMushroom,
    FoodSubtype.herbFresh => l10n.nutritionFoodHerbFresh,
    FoodSubtype.meatBeef => l10n.nutritionFoodBeef,
    FoodSubtype.meatPork => l10n.nutritionFoodPork,
    FoodSubtype.meatLamb => l10n.nutritionFoodLamb,
    FoodSubtype.meatGame => l10n.nutritionFoodGameMeat,
    FoodSubtype.poultry => l10n.nutritionFoodPoultry,
    FoodSubtype.fish => l10n.nutritionFoodFish,
    FoodSubtype.seafood => l10n.nutritionFoodSeafood,
    FoodSubtype.egg => l10n.nutritionFoodEgg,
    FoodSubtype.dairyMilk => l10n.nutritionFoodMilk,
    FoodSubtype.dairyCheese => l10n.nutritionFoodCheese,
    FoodSubtype.dairyYogurt => l10n.nutritionFoodYogurt,
    FoodSubtype.dairyCream => l10n.nutritionFoodCream,
    FoodSubtype.dairyButter => l10n.nutritionFoodButter,
    FoodSubtype.plantMilk => l10n.nutritionFoodPlantMilk,
    FoodSubtype.grainCereal => l10n.nutritionFoodGrainCereal,
    FoodSubtype.pastaNoodle => l10n.nutritionFoodPastaNoodle,
    FoodSubtype.rice => l10n.nutritionFoodRice,
    FoodSubtype.breadBakery => l10n.nutritionFoodBreadBakery,
    FoodSubtype.potatoTuber => l10n.nutritionFoodPotatoTuber,
    FoodSubtype.cornMaize => l10n.nutritionFoodCorn,
    FoodSubtype.legumeBean => l10n.nutritionFoodBeans,
    FoodSubtype.legumeLentil => l10n.nutritionFoodLentils,
    FoodSubtype.nut => l10n.nutritionFoodNuts,
    FoodSubtype.seed => l10n.nutritionFoodSeeds,
    FoodSubtype.oilFat => l10n.nutritionFoodOilFat,
    FoodSubtype.cannedFood => l10n.nutritionFoodCanned,
    FoodSubtype.frozenFood => l10n.nutritionFoodFrozen,
    FoodSubtype.processedMeat => l10n.nutritionFoodProcessedMeat,
    FoodSubtype.readyMeal => l10n.nutritionFoodReadyMeal,
    FoodSubtype.snackChips => l10n.nutritionFoodChips,
    FoodSubtype.snackBar => l10n.nutritionFoodSnackBar,
    FoodSubtype.cerealBar => l10n.nutritionFoodCerealBar,
    FoodSubtype.chocolateCandy => l10n.nutritionFoodChocolateCandy,
    FoodSubtype.biscuitCookie => l10n.nutritionFoodBiscuitCookie,
    FoodSubtype.sweetener => l10n.nutritionFoodSweetener,
    FoodSubtype.jamSpread => l10n.nutritionFoodJamSpread,
    FoodSubtype.bakingIngredient => l10n.nutritionFoodBaking,
    FoodSubtype.sauceCondiment => l10n.nutritionFoodSauceCondiment,
    FoodSubtype.dressing => l10n.nutritionFoodDressing,
    FoodSubtype.babyFood => l10n.nutritionFoodBabyFood,
    FoodSubtype.supplementPowder => l10n.nutritionFoodSupplementPowder,
    FoodSubtype.otherFood => l10n.nutritionSubtypeOther,
  };

  static FoodSubtype? fromApiValue(String v) =>
      _api.entries.where((e) => e.value == v).map((e) => e.key).firstOrNull;
}

enum DrinkSubtype {
  waterStill,
  waterSparkling,
  waterFlavoured,
  juiceFruit,
  juiceVegetable,
  smoothie,
  shake,
  milkDairy,
  milkPlant,
  coffee,
  espresso,
  teaBlack,
  teaGreen,
  teaHerbal,
  soda,
  energyDrink,
  sportsDrink,
  isotonic,
  alcoholBeer,
  alcoholCider,
  alcoholWine,
  alcoholSpirit,
  alcoholCocktail,
  proteinShake,
  mealReplacement,
  kombucha,
  kefirDrink,
  otherDrink;

  static const _api = {
    DrinkSubtype.waterStill: 'water_still',
    DrinkSubtype.waterSparkling: 'water_sparkling',
    DrinkSubtype.waterFlavoured: 'water_flavoured',
    DrinkSubtype.juiceFruit: 'juice_fruit',
    DrinkSubtype.juiceVegetable: 'juice_vegetable',
    DrinkSubtype.smoothie: 'smoothie',
    DrinkSubtype.shake: 'shake',
    DrinkSubtype.milkDairy: 'milk_dairy',
    DrinkSubtype.milkPlant: 'milk_plant',
    DrinkSubtype.coffee: 'coffee',
    DrinkSubtype.espresso: 'espresso',
    DrinkSubtype.teaBlack: 'tea_black',
    DrinkSubtype.teaGreen: 'tea_green',
    DrinkSubtype.teaHerbal: 'tea_herbal',
    DrinkSubtype.soda: 'soda',
    DrinkSubtype.energyDrink: 'energy_drink',
    DrinkSubtype.sportsDrink: 'sports_drink',
    DrinkSubtype.isotonic: 'isotonic',
    DrinkSubtype.alcoholBeer: 'alcohol_beer',
    DrinkSubtype.alcoholCider: 'alcohol_cider',
    DrinkSubtype.alcoholWine: 'alcohol_wine',
    DrinkSubtype.alcoholSpirit: 'alcohol_spirit',
    DrinkSubtype.alcoholCocktail: 'alcohol_cocktail',
    DrinkSubtype.proteinShake: 'protein_shake',
    DrinkSubtype.mealReplacement: 'meal_replacement',
    DrinkSubtype.kombucha: 'kombucha',
    DrinkSubtype.kefirDrink: 'kefir_drink',
    DrinkSubtype.otherDrink: 'other_drink',
  };

  String get apiValue => _api[this]!;
  String label(AppLocalizations l10n) => switch (this) {
    DrinkSubtype.waterStill => l10n.nutritionDrinkStillWater,
    DrinkSubtype.waterSparkling => l10n.nutritionDrinkSparklingWater,
    DrinkSubtype.waterFlavoured => l10n.nutritionDrinkFlavouredWater,
    DrinkSubtype.juiceFruit => l10n.nutritionDrinkFruitJuice,
    DrinkSubtype.juiceVegetable => l10n.nutritionDrinkVegetableJuice,
    DrinkSubtype.smoothie => l10n.nutritionDrinkSmoothie,
    DrinkSubtype.shake => l10n.nutritionDrinkShake,
    DrinkSubtype.milkDairy => l10n.nutritionDrinkDairyMilk,
    DrinkSubtype.milkPlant => l10n.nutritionDrinkPlantMilk,
    DrinkSubtype.coffee => l10n.nutritionDrinkCoffee,
    DrinkSubtype.espresso => l10n.nutritionDrinkEspresso,
    DrinkSubtype.teaBlack => l10n.nutritionDrinkBlackTea,
    DrinkSubtype.teaGreen => l10n.nutritionDrinkGreenTea,
    DrinkSubtype.teaHerbal => l10n.nutritionDrinkHerbalTea,
    DrinkSubtype.soda => l10n.nutritionDrinkSoda,
    DrinkSubtype.energyDrink => l10n.nutritionDrinkEnergy,
    DrinkSubtype.sportsDrink => l10n.nutritionDrinkSports,
    DrinkSubtype.isotonic => l10n.nutritionDrinkIsotonic,
    DrinkSubtype.alcoholBeer => l10n.nutritionDrinkBeer,
    DrinkSubtype.alcoholCider => l10n.nutritionDrinkCider,
    DrinkSubtype.alcoholWine => l10n.nutritionDrinkWine,
    DrinkSubtype.alcoholSpirit => l10n.nutritionDrinkSpirit,
    DrinkSubtype.alcoholCocktail => l10n.nutritionDrinkCocktail,
    DrinkSubtype.proteinShake => l10n.nutritionDrinkProteinShake,
    DrinkSubtype.mealReplacement => l10n.nutritionDrinkMealReplacement,
    DrinkSubtype.kombucha => l10n.nutritionDrinkKombucha,
    DrinkSubtype.kefirDrink => l10n.nutritionDrinkKefir,
    DrinkSubtype.otherDrink => l10n.nutritionSubtypeOther,
  };

  static DrinkSubtype? fromApiValue(String v) =>
      _api.entries.where((e) => e.value == v).map((e) => e.key).firstOrNull;
}

enum SpiceSubtype {
  herbDried,
  spiceGround,
  spiceWhole,
  spiceSeed,
  seasoningBlend,
  rub,
  marinadeDry,
  salt,
  pepper,
  extractEssence,
  otherSpice;

  static const _api = {
    SpiceSubtype.herbDried: 'herb_dried',
    SpiceSubtype.spiceGround: 'spice_ground',
    SpiceSubtype.spiceWhole: 'spice_whole',
    SpiceSubtype.spiceSeed: 'spice_seed',
    SpiceSubtype.seasoningBlend: 'seasoning_blend',
    SpiceSubtype.rub: 'rub',
    SpiceSubtype.marinadeDry: 'marinade_dry',
    SpiceSubtype.salt: 'salt',
    SpiceSubtype.pepper: 'pepper',
    SpiceSubtype.extractEssence: 'extract_essence',
    SpiceSubtype.otherSpice: 'other_spice',
  };

  String get apiValue => _api[this]!;
  String label(AppLocalizations l10n) => switch (this) {
    SpiceSubtype.herbDried => l10n.nutritionSpiceDriedHerb,
    SpiceSubtype.spiceGround => l10n.nutritionSpiceGround,
    SpiceSubtype.spiceWhole => l10n.nutritionSpiceWhole,
    SpiceSubtype.spiceSeed => l10n.nutritionSpiceSeed,
    SpiceSubtype.seasoningBlend => l10n.nutritionSpiceBlend,
    SpiceSubtype.rub => l10n.nutritionSpiceRub,
    SpiceSubtype.marinadeDry => l10n.nutritionSpiceDryMarinade,
    SpiceSubtype.salt => l10n.nutritionSpiceSalt,
    SpiceSubtype.pepper => l10n.nutritionSpicePepper,
    SpiceSubtype.extractEssence => l10n.nutritionSpiceExtract,
    SpiceSubtype.otherSpice => l10n.nutritionSubtypeOther,
  };

  static SpiceSubtype? fromApiValue(String v) =>
      _api.entries.where((e) => e.value == v).map((e) => e.key).firstOrNull;
}

enum ServingUnit {
  g,
  ml;

  static ServingUnit fromApiValue(String v) => v == 'ml' ? ml : g;
  String get apiValue => name;
  String get displayName => name;
}

enum MealSlotType {
  breakfast,
  morningSnack,
  lunch,
  afternoonSnack,
  dinner,
  eveningSnack,
  preWorkout,
  postWorkout;

  static const _api = {
    MealSlotType.breakfast: 'breakfast',
    MealSlotType.morningSnack: 'morning_snack',
    MealSlotType.lunch: 'lunch',
    MealSlotType.afternoonSnack: 'afternoon_snack',
    MealSlotType.dinner: 'dinner',
    MealSlotType.eveningSnack: 'evening_snack',
    MealSlotType.preWorkout: 'pre_workout',
    MealSlotType.postWorkout: 'post_workout',
  };

  String get apiValue => _api[this]!;
  String label(AppLocalizations l10n) => switch (this) {
    MealSlotType.breakfast => l10n.nutritionSlotBreakfast,
    MealSlotType.morningSnack => l10n.nutritionSlotMorningSnack,
    MealSlotType.lunch => l10n.nutritionSlotLunch,
    MealSlotType.afternoonSnack => l10n.nutritionSlotAfternoonSnack,
    MealSlotType.dinner => l10n.nutritionSlotDinner,
    MealSlotType.eveningSnack => l10n.nutritionSlotEveningSnack,
    MealSlotType.preWorkout => l10n.nutritionSlotPreWorkout,
    MealSlotType.postWorkout => l10n.nutritionSlotPostWorkout,
  };

  static MealSlotType? fromApiValue(String v) =>
      _api.entries.where((e) => e.value == v).map((e) => e.key).firstOrNull;
}

// ── Micronutrient lookup ───────────────────────────────────────────────────────

class Vitamin {
  final String id;
  final String name;
  final String? symbol;
  final String defaultUnit;

  const Vitamin({
    required this.id,
    required this.name,
    this.symbol,
    required this.defaultUnit,
  });

  factory Vitamin.fromJson(Map<String, dynamic> json) => Vitamin(
    id: json['id'] as String,
    name: json['name'] as String,
    symbol: json['symbol'] as String?,
    defaultUnit: json['default_unit'] as String? ?? 'mg',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'symbol': symbol,
    'default_unit': defaultUnit,
  };
}

class Mineral {
  final String id;
  final String name;
  final String? symbol;
  final String defaultUnit;

  const Mineral({
    required this.id,
    required this.name,
    this.symbol,
    required this.defaultUnit,
  });

  factory Mineral.fromJson(Map<String, dynamic> json) => Mineral(
    id: json['id'] as String,
    name: json['name'] as String,
    symbol: json['symbol'] as String?,
    defaultUnit: json['default_unit'] as String? ?? 'mg',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'symbol': symbol,
    'default_unit': defaultUnit,
  };
}

class FoodItemVitamin {
  final String vitaminId;
  final Vitamin? vitamin;
  final double amountPer100;
  final String? unit;

  const FoodItemVitamin({
    required this.vitaminId,
    this.vitamin,
    required this.amountPer100,
    this.unit,
  });

  factory FoodItemVitamin.fromJson(Map<String, dynamic> json) =>
      FoodItemVitamin(
        vitaminId: json['vitamin_id'] as String,
        vitamin: json['vitamin'] != null
            ? Vitamin.fromJson(json['vitamin'] as Map<String, dynamic>)
            : null,
        amountPer100: _toDouble(json['amount_per_100'])!,
        unit: json['unit'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'vitamin_id': vitaminId,
    'amount_per_100': amountPer100,
    'unit': unit,
  };

  String get displayUnit => unit ?? vitamin?.defaultUnit ?? 'mg';
}

class FoodItemMineral {
  final String mineralId;
  final Mineral? mineral;
  final double amountPer100;
  final String? unit;

  const FoodItemMineral({
    required this.mineralId,
    this.mineral,
    required this.amountPer100,
    this.unit,
  });

  factory FoodItemMineral.fromJson(Map<String, dynamic> json) =>
      FoodItemMineral(
        mineralId: json['mineral_id'] as String,
        mineral: json['mineral'] != null
            ? Mineral.fromJson(json['mineral'] as Map<String, dynamic>)
            : null,
        amountPer100: _toDouble(json['amount_per_100'])!,
        unit: json['unit'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'mineral_id': mineralId,
    'amount_per_100': amountPer100,
    'unit': unit,
  };

  String get displayUnit => unit ?? mineral?.defaultUnit ?? 'mg';
}

// ── Food Item ─────────────────────────────────────────────────────────────────

class FoodItem {
  final String id;
  final String name;
  final String? brand;
  final String? barcode;
  final FoodItemType type;
  final FoodSubtype? foodSubtype;
  final DrinkSubtype? drinkSubtype;
  final SpiceSubtype? spiceSubtype;
  final ServingUnit servingUnit;
  final double kcalPer100;
  final double proteinPer100;
  final double carbPer100;
  final double fatPer100;
  final double fiberPer100;
  final String? authorId;
  final bool isPublic;
  final bool isSystem;
  final List<FoodItemVitamin> vitamins;
  final List<FoodItemMineral> minerals;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FoodItem({
    required this.id,
    required this.name,
    this.brand,
    this.barcode,
    required this.type,
    this.foodSubtype,
    this.drinkSubtype,
    this.spiceSubtype,
    required this.servingUnit,
    required this.kcalPer100,
    required this.proteinPer100,
    required this.carbPer100,
    required this.fatPer100,
    required this.fiberPer100,
    this.authorId,
    required this.isPublic,
    required this.isSystem,
    required this.vitamins,
    required this.minerals,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    id: json['id'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String?,
    barcode: json['barcode'] as String?,
    type:
        FoodItemType.fromApiValue(json['type'] as String) ?? FoodItemType.food,
    foodSubtype: json['food_subtype'] != null
        ? FoodSubtype.fromApiValue(json['food_subtype'] as String)
        : null,
    drinkSubtype: json['drink_subtype'] != null
        ? DrinkSubtype.fromApiValue(json['drink_subtype'] as String)
        : null,
    spiceSubtype: json['spice_subtype'] != null
        ? SpiceSubtype.fromApiValue(json['spice_subtype'] as String)
        : null,
    servingUnit: ServingUnit.fromApiValue(
      json['serving_unit'] as String? ?? 'g',
    ),
    kcalPer100: _toDouble(json['kcal_per_100']) ?? 0,
    proteinPer100: _toDouble(json['protein_per_100']) ?? 0,
    carbPer100: _toDouble(json['carb_per_100']) ?? 0,
    fatPer100: _toDouble(json['fat_per_100']) ?? 0,
    fiberPer100: _toDouble(json['fiber_per_100']) ?? 0,
    authorId: json['author_id'] as String?,
    isPublic: json['is_public'] as bool? ?? true,
    isSystem: json['is_system'] as bool? ?? false,
    vitamins: (json['vitamins'] as List<dynamic>? ?? [])
        .map((v) => FoodItemVitamin.fromJson(v as Map<String, dynamic>))
        .toList(),
    minerals: (json['minerals'] as List<dynamic>? ?? [])
        .map((m) => FoodItemMineral.fromJson(m as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'brand': brand,
    'barcode': barcode,
    'type': type.apiValue,
    'food_subtype': foodSubtype?.apiValue,
    'drink_subtype': drinkSubtype?.apiValue,
    'spice_subtype': spiceSubtype?.apiValue,
    'serving_unit': servingUnit.apiValue,
    'kcal_per_100': kcalPer100,
    'protein_per_100': proteinPer100,
    'carb_per_100': carbPer100,
    'fat_per_100': fatPer100,
    'fiber_per_100': fiberPer100,
    'is_public': isPublic,
    'vitamins': vitamins.map((v) => v.toJson()).toList(),
    'minerals': minerals.map((m) => m.toJson()).toList(),
  };

  String subtypeLabel(AppLocalizations l10n) {
    if (foodSubtype != null) return foodSubtype!.label(l10n);
    if (drinkSubtype != null) return drinkSubtype!.label(l10n);
    if (spiceSubtype != null) return spiceSubtype!.label(l10n);
    return type.label(l10n);
  }

  /// "per 100g" / "na 100g".
  String servingUnitLabel(AppLocalizations l10n) =>
      l10n.nutritionPer100Unit(servingUnit.displayName);
}

// ── Recipe ────────────────────────────────────────────────────────────────────

class RecipeIngredient {
  final String id;
  final String recipeId;
  final String foodItemId;
  final FoodItem? foodItem;
  final double quantity;
  final String? note;
  final int position;

  const RecipeIngredient({
    required this.id,
    required this.recipeId,
    required this.foodItemId,
    this.foodItem,
    required this.quantity,
    this.note,
    required this.position,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        id: json['id'] as String,
        recipeId: json['recipe_id'] as String,
        foodItemId: json['food_item_id'] as String,
        foodItem: json['food_item'] != null
            ? FoodItem.fromJson(json['food_item'] as Map<String, dynamic>)
            : null,
        quantity: _toDouble(json['quantity'])!,
        note: json['note'] as String?,
        position: json['position'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'food_item_id': foodItemId,
    'quantity': quantity,
    'note': note,
    'position': position,
  };

  String quantityLabel(AppLocalizations l10n) {
    final unit = foodItem?.servingUnit.displayName ?? 'g';
    return '${fmtAmount(double.parse(quantity.toStringAsFixed(1)), l10n.localeName)}$unit';
  }
}

class RecipeStep {
  final String id;
  final String recipeId;
  final int position;
  final String instruction;
  final String? imageUrl;

  const RecipeStep({
    required this.id,
    required this.recipeId,
    required this.position,
    required this.instruction,
    this.imageUrl,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
    id: json['id'] as String,
    recipeId: json['recipe_id'] as String,
    position: json['position'] as int? ?? 0,
    instruction: json['instruction'] as String,
    imageUrl: json['image_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'position': position,
    'instruction': instruction,
    'image_url': imageUrl,
  };
}

class RecipeImage {
  final String id;
  final String recipeId;
  final String url;
  final bool isThumbnail;
  final int position;

  const RecipeImage({
    required this.id,
    required this.recipeId,
    required this.url,
    required this.isThumbnail,
    required this.position,
  });

  factory RecipeImage.fromJson(Map<String, dynamic> json) => RecipeImage(
    id: json['id'] as String,
    recipeId: json['recipe_id'] as String,
    url: json['url'] as String,
    isThumbnail: json['is_thumbnail'] as bool? ?? false,
    position: json['position'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'url': url,
    'is_thumbnail': isThumbnail,
    'position': position,
  };
}

class RecipeVideo {
  final String id;
  final String recipeId;
  final String url;
  final String? title;
  final int position;

  const RecipeVideo({
    required this.id,
    required this.recipeId,
    required this.url,
    this.title,
    required this.position,
  });

  factory RecipeVideo.fromJson(Map<String, dynamic> json) => RecipeVideo(
    id: json['id'] as String,
    recipeId: json['recipe_id'] as String,
    url: json['url'] as String,
    title: json['title'] as String?,
    position: json['position'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'position': position,
  };
}

class Recipe {
  final String id;
  final String name;
  final String? description;
  final String? authorId;
  final int servings;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final double kcalPerServing;
  final double proteinPerServing;
  final double carbPerServing;
  final double fatPerServing;
  final double fiberPerServing;
  final bool isPublic;
  final bool isSystem;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final List<RecipeImage> images;
  final List<RecipeVideo> videos;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Recipe({
    required this.id,
    required this.name,
    this.description,
    this.authorId,
    required this.servings,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    required this.kcalPerServing,
    required this.proteinPerServing,
    required this.carbPerServing,
    required this.fatPerServing,
    required this.fiberPerServing,
    required this.isPublic,
    required this.isSystem,
    required this.ingredients,
    required this.steps,
    required this.images,
    required this.videos,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    authorId: json['author_id'] as String?,
    servings: json['servings'] as int? ?? 1,
    prepTimeMinutes: json['prep_time_minutes'] as int?,
    cookTimeMinutes: json['cook_time_minutes'] as int?,
    kcalPerServing: _toDouble(json['kcal_per_serving']) ?? 0,
    proteinPerServing: _toDouble(json['protein_per_serving']) ?? 0,
    carbPerServing: _toDouble(json['carb_per_serving']) ?? 0,
    fatPerServing: _toDouble(json['fat_per_serving']) ?? 0,
    fiberPerServing: _toDouble(json['fiber_per_serving']) ?? 0,
    isPublic: json['is_public'] as bool? ?? false,
    isSystem: json['is_system'] as bool? ?? false,
    ingredients: (json['ingredients'] as List<dynamic>? ?? [])
        .map((i) => RecipeIngredient.fromJson(i as Map<String, dynamic>))
        .toList(),
    steps: (json['steps'] as List<dynamic>? ?? [])
        .map((s) => RecipeStep.fromJson(s as Map<String, dynamic>))
        .toList(),
    images: (json['images'] as List<dynamic>? ?? [])
        .map((i) => RecipeImage.fromJson(i as Map<String, dynamic>))
        .toList(),
    videos: (json['videos'] as List<dynamic>? ?? [])
        .map((v) => RecipeVideo.fromJson(v as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'servings': servings,
    'prep_time_minutes': prepTimeMinutes,
    'cook_time_minutes': cookTimeMinutes,
    'kcal_per_serving': kcalPerServing,
    'protein_per_serving': proteinPerServing,
    'carb_per_serving': carbPerServing,
    'fat_per_serving': fatPerServing,
    'fiber_per_serving': fiberPerServing,
    'is_public': isPublic,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'steps': steps.map((s) => s.toJson()).toList(),
    'images': images.map((i) => i.toJson()).toList(),
    'videos': videos.map((v) => v.toJson()).toList(),
  };

  String get thumbnailUrl => images
      .firstWhere(
        (i) => i.isThumbnail,
        orElse: () =>
            images.firstOrNull ??
            const RecipeImage(
              id: '',
              recipeId: '',
              url: '',
              isThumbnail: false,
              position: 0,
            ),
      )
      .url;

  String? get thumbnailUrlOrNull => images.isEmpty ? null : thumbnailUrl;

  String timeLabel(AppLocalizations l10n) {
    final parts = <String>[];
    if (prepTimeMinutes != null) {
      parts.add(l10n.nutritionRecipePrepTime(prepTimeMinutes!));
    }
    if (cookTimeMinutes != null) {
      parts.add(l10n.nutritionRecipeCookTime(cookTimeMinutes!));
    }
    return parts.join(' · ');
  }

  int get totalTimeMinutes => (prepTimeMinutes ?? 0) + (cookTimeMinutes ?? 0);
}

// ── Daily Meal Plan ───────────────────────────────────────────────────────────

class DailyMealPlanSlotEntry {
  final String id;
  final String slotId;
  final String? foodItemId;
  final FoodItem? foodItem;
  final String? recipeId;
  final Recipe? recipe;
  final double? quantity;
  final double servings;
  final int position;
  final String? note;

  const DailyMealPlanSlotEntry({
    required this.id,
    required this.slotId,
    this.foodItemId,
    this.foodItem,
    this.recipeId,
    this.recipe,
    this.quantity,
    required this.servings,
    required this.position,
    this.note,
  });

  factory DailyMealPlanSlotEntry.fromJson(Map<String, dynamic> json) =>
      DailyMealPlanSlotEntry(
        id: json['id'] as String,
        slotId: json['daily_meal_plan_slot_id'] as String,
        foodItemId: json['food_item_id'] as String?,
        foodItem: json['food_item'] != null
            ? FoodItem.fromJson(json['food_item'] as Map<String, dynamic>)
            : null,
        recipeId: json['recipe_id'] as String?,
        recipe: json['recipe'] != null
            ? Recipe.fromJson(json['recipe'] as Map<String, dynamic>)
            : null,
        quantity: _toDouble(json['quantity']),
        servings: _toDouble(json['servings']) ?? 1.0,
        position: json['position'] as int? ?? 0,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'food_item_id': foodItemId,
    'recipe_id': recipeId,
    'quantity': quantity,
    'servings': servings,
    'position': position,
    'note': note,
  };

  String displayName(AppLocalizations l10n) =>
      foodItem?.name ?? recipe?.name ?? l10n.nutritionItemFallback;

  String amountLabel(AppLocalizations l10n) {
    if (foodItem != null && quantity != null) {
      final unit = foodItem!.servingUnit.displayName;
      return '${fmtAmount(double.parse(quantity!.toStringAsFixed(1)), l10n.localeName)}$unit';
    }
    if (recipe != null) {
      return l10n.nutritionServingsAmount(
        servings,
        fmtAmount(double.parse(servings.toStringAsFixed(1)), l10n.localeName),
      );
    }
    return '';
  }

  double get kcal {
    if (foodItem != null && quantity != null) {
      return foodItem!.kcalPer100 * quantity! / 100;
    }
    if (recipe != null) return recipe!.kcalPerServing * servings;
    return 0;
  }

  double get protein {
    if (foodItem != null && quantity != null) {
      return foodItem!.proteinPer100 * quantity! / 100;
    }
    if (recipe != null) return recipe!.proteinPerServing * servings;
    return 0;
  }

  double get carb {
    if (foodItem != null && quantity != null) {
      return foodItem!.carbPer100 * quantity! / 100;
    }
    if (recipe != null) return recipe!.carbPerServing * servings;
    return 0;
  }

  double get fat {
    if (foodItem != null && quantity != null) {
      return foodItem!.fatPer100 * quantity! / 100;
    }
    if (recipe != null) return recipe!.fatPerServing * servings;
    return 0;
  }
}

class DailyMealPlanSlot {
  final String id;
  final String dailyMealPlanId;
  final MealSlotType slotType;
  final int position;
  final String? note;
  final List<DailyMealPlanSlotEntry> entries;

  const DailyMealPlanSlot({
    required this.id,
    required this.dailyMealPlanId,
    required this.slotType,
    required this.position,
    this.note,
    required this.entries,
  });

  factory DailyMealPlanSlot.fromJson(Map<String, dynamic> json) =>
      DailyMealPlanSlot(
        id: json['id'] as String,
        dailyMealPlanId: json['daily_meal_plan_id'] as String,
        slotType:
            MealSlotType.fromApiValue(json['slot_type'] as String) ??
            MealSlotType.breakfast,
        position: json['position'] as int? ?? 0,
        note: json['note'] as String?,
        entries: (json['entries'] as List<dynamic>? ?? [])
            .map(
              (e) => DailyMealPlanSlotEntry.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'slot_type': slotType.apiValue,
    'position': position,
    'note': note,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  double get kcalTotal => entries.fold(0, (s, e) => s + e.kcal);
  double get proteinTotal => entries.fold(0, (s, e) => s + e.protein);
  double get carbTotal => entries.fold(0, (s, e) => s + e.carb);
  double get fatTotal => entries.fold(0, (s, e) => s + e.fat);
}

class DailyMealPlan {
  final String id;
  final String name;
  final String? description;
  final String? authorId;
  final bool isPublic;
  final bool isSystem;
  final double kcalTotal;
  final double proteinTotal;
  final double carbTotal;
  final double fatTotal;
  final double fiberTotal;
  final List<DailyMealPlanSlot> slots;
  // Only populated by the list endpoint, which omits nested slots for performance.
  final int? mealCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyMealPlan({
    required this.id,
    required this.name,
    this.description,
    this.authorId,
    required this.isPublic,
    required this.isSystem,
    required this.kcalTotal,
    required this.proteinTotal,
    required this.carbTotal,
    required this.fatTotal,
    required this.fiberTotal,
    required this.slots,
    this.mealCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyMealPlan.fromJson(Map<String, dynamic> json) => DailyMealPlan(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    authorId: json['author_id'] as String?,
    isPublic: json['is_public'] as bool? ?? false,
    isSystem: json['is_system'] as bool? ?? false,
    kcalTotal: _toDouble(json['kcal_total']) ?? 0,
    proteinTotal: _toDouble(json['protein_total']) ?? 0,
    carbTotal: _toDouble(json['carb_total']) ?? 0,
    fatTotal: _toDouble(json['fat_total']) ?? 0,
    fiberTotal: _toDouble(json['fiber_total']) ?? 0,
    slots: (json['slots'] as List<dynamic>? ?? [])
        .map((s) => DailyMealPlanSlot.fromJson(s as Map<String, dynamic>))
        .toList(),
    mealCount: json['meal_count'] as int?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  int get displayMealCount => mealCount ?? slots.length;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'is_public': isPublic,
    'kcal_total': kcalTotal,
    'protein_total': proteinTotal,
    'carb_total': carbTotal,
    'fat_total': fatTotal,
    'fiber_total': fiberTotal,
    'slots': slots.map((s) => s.toJson()).toList(),
  };
}

// ── Meal Plan ─────────────────────────────────────────────────────────────────

class MealPlanImage {
  final String id;
  final String mealPlanId;
  final String url;
  final bool isThumbnail;
  final int position;

  const MealPlanImage({
    required this.id,
    required this.mealPlanId,
    required this.url,
    required this.isThumbnail,
    required this.position,
  });

  factory MealPlanImage.fromJson(Map<String, dynamic> json) => MealPlanImage(
    id: json['id'] as String,
    mealPlanId: json['meal_plan_id'] as String,
    url: json['url'] as String,
    isThumbnail: json['is_thumbnail'] as bool? ?? false,
    position: json['position'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'url': url,
    'is_thumbnail': isThumbnail,
    'position': position,
  };
}

class MealPlanDay {
  final String id;
  final String mealPlanId;
  final String dailyMealPlanId;
  final DailyMealPlan? dailyMealPlan;
  final int weekNumber;
  final int dayOfWeek;
  final String? note;

  const MealPlanDay({
    required this.id,
    required this.mealPlanId,
    required this.dailyMealPlanId,
    this.dailyMealPlan,
    required this.weekNumber,
    required this.dayOfWeek,
    this.note,
  });

  factory MealPlanDay.fromJson(Map<String, dynamic> json) => MealPlanDay(
    id: json['id'] as String,
    mealPlanId: json['meal_plan_id'] as String,
    dailyMealPlanId: json['daily_meal_plan_id'] as String,
    dailyMealPlan: json['daily_meal_plan'] != null
        ? DailyMealPlan.fromJson(
            json['daily_meal_plan'] as Map<String, dynamic>,
          )
        : null,
    weekNumber: json['week_number'] as int,
    dayOfWeek: json['day_of_week'] as int,
    note: json['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'daily_meal_plan_id': dailyMealPlanId,
    'week_number': weekNumber,
    'day_of_week': dayOfWeek,
    'note': note,
  };

  /// Short weekday name in [locale] ("Mon" / "pon").
  String dayLabel(String locale) => shortWeekdayName(dayOfWeek, locale);
}

class MealPlan {
  final String id;
  final String name;
  final String? description;
  final String? authorId;
  final bool isPublic;
  final bool isSystem;
  final int numWeeks;
  final List<MealPlanDay> days;
  final List<MealPlanImage> images;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MealPlan({
    required this.id,
    required this.name,
    this.description,
    this.authorId,
    required this.isPublic,
    required this.isSystem,
    required this.numWeeks,
    required this.days,
    required this.images,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) => MealPlan(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    authorId: json['author_id'] as String?,
    isPublic: json['is_public'] as bool? ?? false,
    isSystem: json['is_system'] as bool? ?? false,
    numWeeks: json['num_weeks'] as int? ?? 1,
    days: (json['days'] as List<dynamic>? ?? [])
        .map((d) => MealPlanDay.fromJson(d as Map<String, dynamic>))
        .toList(),
    images: (json['images'] as List<dynamic>? ?? [])
        .map((i) => MealPlanImage.fromJson(i as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'is_public': isPublic,
    'num_weeks': numWeeks,
    'days': days.map((d) => d.toJson()).toList(),
    'images': images.map((i) => i.toJson()).toList(),
  };

  String get thumbnailUrl {
    final thumb = images.firstWhere(
      (i) => i.isThumbnail,
      orElse: () =>
          images.firstOrNull ??
          const MealPlanImage(
            id: '',
            mealPlanId: '',
            url: '',
            isThumbnail: false,
            position: 0,
          ),
    );
    return thumb.url;
  }

  String? get thumbnailUrlOrNull => images.isEmpty ? null : thumbnailUrl;

  String weeksLabel(AppLocalizations l10n) =>
      l10n.nutritionWeeksCount(numWeeks);
}

class MealPlanAssignment {
  final String id;
  final String mealPlanId;
  final MealPlan? mealPlan;
  final String userId;
  final String? assignedById;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? note;

  /// IANA zone planned meals are placed in (null: the viewer's zone).
  final String? timezone;
  final DateTime createdAt;
  // Joined by GET /meal-plan-assignments (may be absent on older responses).
  final String? mealPlanName;
  final String? assignedByName;
  final String? userName;

  const MealPlanAssignment({
    required this.id,
    required this.mealPlanId,
    this.mealPlan,
    required this.userId,
    this.assignedById,
    this.startDate,
    this.endDate,
    this.note,
    this.timezone,
    required this.createdAt,
    this.mealPlanName,
    this.assignedByName,
    this.userName,
  });

  /// Best available plan name: joined field, embedded plan, or a fallback.
  // Kept for callers outside the nutrition area; prefer [localizedPlanName].
  String get planName => mealPlanName ?? mealPlan?.name ?? 'Meal plan';

  String localizedPlanName(AppLocalizations l10n) =>
      mealPlanName ?? mealPlan?.name ?? l10n.nutritionMealPlanFallback;

  bool get isSelfAssigned => assignedById != null && assignedById == userId;

  factory MealPlanAssignment.fromJson(Map<String, dynamic> json) =>
      MealPlanAssignment(
        id: json['id'] as String,
        mealPlanId: json['meal_plan_id'] as String,
        mealPlan: json['meal_plan'] != null
            ? MealPlan.fromJson(json['meal_plan'] as Map<String, dynamic>)
            : null,
        userId: json['user_id'] as String,
        assignedById: json['assigned_by_id'] as String?,
        startDate: json['start_date'] != null
            ? DateTime.parse(json['start_date'] as String)
            : null,
        endDate: json['end_date'] != null
            ? DateTime.parse(json['end_date'] as String)
            : null,
        note: json['note'] as String?,
        timezone: json['timezone'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        mealPlanName: json['meal_plan_name'] as String?,
        assignedByName: json['assigned_by_name'] as String?,
        userName: json['user_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'meal_plan_id': mealPlanId,
    'user_id': userId,
    'start_date': startDate?.toIso8601String().substring(0, 10),
    'end_date': endDate?.toIso8601String().substring(0, 10),
    'note': note,
  };
}
