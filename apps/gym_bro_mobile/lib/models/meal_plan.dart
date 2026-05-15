// ── Enums ──────────────────────────────────────────────────────────────────────

enum FoodItemType {
  food, spice, drink;

  static const _api = {food: 'food', spice: 'spice', drink: 'drink'};
  static const _display = {food: 'Food', spice: 'Spice', drink: 'Drink'};

  String get apiValue => _api[this]!;
  String get displayName => _display[this]!;

  static FoodItemType? fromApiValue(String v) =>
      _api.entries.where((e) => e.value == v).map((e) => e.key).firstOrNull;
}

enum FoodSubtype {
  vegetable, fruit, mushroom, herbFresh,
  meatBeef, meatPork, meatLamb, meatGame, poultry,
  fish, seafood, egg,
  dairyMilk, dairyCheese, dairyYogurt, dairyCream, dairyButter, plantMilk,
  grainCereal, pastaNoodle, rice, breadBakery, potatoTuber, cornMaize,
  legumeBean, legumeLentil, nut, seed,
  oilFat,
  cannedFood, frozenFood, processedMeat, readyMeal,
  snackChips, snackBar, cerealBar,
  chocolateCandy, biscuitCookie, sweetener, jamSpread, bakingIngredient,
  sauceCondiment, dressing,
  babyFood, supplementPowder, otherFood;

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

  static const _display = {
    FoodSubtype.vegetable: 'Vegetable',
    FoodSubtype.fruit: 'Fruit',
    FoodSubtype.mushroom: 'Mushroom',
    FoodSubtype.herbFresh: 'Fresh Herb',
    FoodSubtype.meatBeef: 'Beef',
    FoodSubtype.meatPork: 'Pork',
    FoodSubtype.meatLamb: 'Lamb',
    FoodSubtype.meatGame: 'Game Meat',
    FoodSubtype.poultry: 'Poultry',
    FoodSubtype.fish: 'Fish',
    FoodSubtype.seafood: 'Seafood',
    FoodSubtype.egg: 'Egg',
    FoodSubtype.dairyMilk: 'Milk',
    FoodSubtype.dairyCheese: 'Cheese',
    FoodSubtype.dairyYogurt: 'Yogurt',
    FoodSubtype.dairyCream: 'Cream',
    FoodSubtype.dairyButter: 'Butter',
    FoodSubtype.plantMilk: 'Plant Milk',
    FoodSubtype.grainCereal: 'Grain / Cereal',
    FoodSubtype.pastaNoodle: 'Pasta / Noodle',
    FoodSubtype.rice: 'Rice',
    FoodSubtype.breadBakery: 'Bread / Bakery',
    FoodSubtype.potatoTuber: 'Potato / Tuber',
    FoodSubtype.cornMaize: 'Corn / Maize',
    FoodSubtype.legumeBean: 'Beans',
    FoodSubtype.legumeLentil: 'Lentils',
    FoodSubtype.nut: 'Nuts',
    FoodSubtype.seed: 'Seeds',
    FoodSubtype.oilFat: 'Oil / Fat',
    FoodSubtype.cannedFood: 'Canned Food',
    FoodSubtype.frozenFood: 'Frozen Food',
    FoodSubtype.processedMeat: 'Processed Meat',
    FoodSubtype.readyMeal: 'Ready Meal',
    FoodSubtype.snackChips: 'Chips / Crisps',
    FoodSubtype.snackBar: 'Snack Bar',
    FoodSubtype.cerealBar: 'Cereal Bar',
    FoodSubtype.chocolateCandy: 'Chocolate / Candy',
    FoodSubtype.biscuitCookie: 'Biscuit / Cookie',
    FoodSubtype.sweetener: 'Sweetener',
    FoodSubtype.jamSpread: 'Jam / Spread',
    FoodSubtype.bakingIngredient: 'Baking',
    FoodSubtype.sauceCondiment: 'Sauce / Condiment',
    FoodSubtype.dressing: 'Dressing',
    FoodSubtype.babyFood: 'Baby Food',
    FoodSubtype.supplementPowder: 'Supplement Powder',
    FoodSubtype.otherFood: 'Other',
  };

  String get apiValue => _api[this]!;
  String get displayName => _display[this]!;

  static FoodSubtype? fromApiValue(String v) =>
      _api.entries.where((e) => e.value == v).map((e) => e.key).firstOrNull;
}

enum DrinkSubtype {
  waterStill, waterSparkling, waterFlavoured,
  juiceFruit, juiceVegetable,
  smoothie, shake,
  milkDairy, milkPlant,
  coffee, espresso, teaBlack, teaGreen, teaHerbal,
  soda, energyDrink, sportsDrink, isotonic,
  alcoholBeer, alcoholCider, alcoholWine, alcoholSpirit, alcoholCocktail,
  proteinShake, mealReplacement,
  kombucha, kefirDrink, otherDrink;

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

  static const _display = {
    DrinkSubtype.waterStill: 'Still Water',
    DrinkSubtype.waterSparkling: 'Sparkling Water',
    DrinkSubtype.waterFlavoured: 'Flavoured Water',
    DrinkSubtype.juiceFruit: 'Fruit Juice',
    DrinkSubtype.juiceVegetable: 'Vegetable Juice',
    DrinkSubtype.smoothie: 'Smoothie',
    DrinkSubtype.shake: 'Shake',
    DrinkSubtype.milkDairy: 'Dairy Milk',
    DrinkSubtype.milkPlant: 'Plant Milk',
    DrinkSubtype.coffee: 'Coffee',
    DrinkSubtype.espresso: 'Espresso',
    DrinkSubtype.teaBlack: 'Black Tea',
    DrinkSubtype.teaGreen: 'Green Tea',
    DrinkSubtype.teaHerbal: 'Herbal Tea',
    DrinkSubtype.soda: 'Soda',
    DrinkSubtype.energyDrink: 'Energy Drink',
    DrinkSubtype.sportsDrink: 'Sports Drink',
    DrinkSubtype.isotonic: 'Isotonic',
    DrinkSubtype.alcoholBeer: 'Beer',
    DrinkSubtype.alcoholCider: 'Cider',
    DrinkSubtype.alcoholWine: 'Wine',
    DrinkSubtype.alcoholSpirit: 'Spirit',
    DrinkSubtype.alcoholCocktail: 'Cocktail',
    DrinkSubtype.proteinShake: 'Protein Shake',
    DrinkSubtype.mealReplacement: 'Meal Replacement',
    DrinkSubtype.kombucha: 'Kombucha',
    DrinkSubtype.kefirDrink: 'Kefir Drink',
    DrinkSubtype.otherDrink: 'Other',
  };

  String get apiValue => _api[this]!;
  String get displayName => _display[this]!;

  static DrinkSubtype? fromApiValue(String v) =>
      _api.entries.where((e) => e.value == v).map((e) => e.key).firstOrNull;
}

enum SpiceSubtype {
  herbDried, spiceGround, spiceWhole, spiceSeed,
  seasoningBlend, rub, marinadeDry,
  salt, pepper,
  extractEssence, otherSpice;

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

  static const _display = {
    SpiceSubtype.herbDried: 'Dried Herb',
    SpiceSubtype.spiceGround: 'Ground Spice',
    SpiceSubtype.spiceWhole: 'Whole Spice',
    SpiceSubtype.spiceSeed: 'Spice Seed',
    SpiceSubtype.seasoningBlend: 'Seasoning Blend',
    SpiceSubtype.rub: 'Rub',
    SpiceSubtype.marinadeDry: 'Dry Marinade',
    SpiceSubtype.salt: 'Salt',
    SpiceSubtype.pepper: 'Pepper',
    SpiceSubtype.extractEssence: 'Extract / Essence',
    SpiceSubtype.otherSpice: 'Other',
  };

  String get apiValue => _api[this]!;
  String get displayName => _display[this]!;

  static SpiceSubtype? fromApiValue(String v) =>
      _api.entries.where((e) => e.value == v).map((e) => e.key).firstOrNull;
}

enum ServingUnit {
  g, ml;

  static ServingUnit fromApiValue(String v) => v == 'ml' ? ml : g;
  String get apiValue => name;
  String get displayName => name;
}

enum MealSlotType {
  breakfast, morningSnack, lunch, afternoonSnack, dinner, eveningSnack,
  preWorkout, postWorkout;

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

  static const _display = {
    MealSlotType.breakfast: 'Breakfast',
    MealSlotType.morningSnack: 'Morning Snack',
    MealSlotType.lunch: 'Lunch',
    MealSlotType.afternoonSnack: 'Afternoon Snack',
    MealSlotType.dinner: 'Dinner',
    MealSlotType.eveningSnack: 'Evening Snack',
    MealSlotType.preWorkout: 'Pre-Workout',
    MealSlotType.postWorkout: 'Post-Workout',
  };

  String get apiValue => _api[this]!;
  String get displayName => _display[this]!;

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

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'symbol': symbol, 'default_unit': defaultUnit};
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

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'symbol': symbol, 'default_unit': defaultUnit};
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

  factory FoodItemVitamin.fromJson(Map<String, dynamic> json) => FoodItemVitamin(
        vitaminId: json['vitamin_id'] as String,
        vitamin: json['vitamin'] != null
            ? Vitamin.fromJson(json['vitamin'] as Map<String, dynamic>)
            : null,
        amountPer100: (json['amount_per_100'] as num).toDouble(),
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

  factory FoodItemMineral.fromJson(Map<String, dynamic> json) => FoodItemMineral(
        mineralId: json['mineral_id'] as String,
        mineral: json['mineral'] != null
            ? Mineral.fromJson(json['mineral'] as Map<String, dynamic>)
            : null,
        amountPer100: (json['amount_per_100'] as num).toDouble(),
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
        type: FoodItemType.fromApiValue(json['type'] as String) ?? FoodItemType.food,
        foodSubtype: json['food_subtype'] != null
            ? FoodSubtype.fromApiValue(json['food_subtype'] as String)
            : null,
        drinkSubtype: json['drink_subtype'] != null
            ? DrinkSubtype.fromApiValue(json['drink_subtype'] as String)
            : null,
        spiceSubtype: json['spice_subtype'] != null
            ? SpiceSubtype.fromApiValue(json['spice_subtype'] as String)
            : null,
        servingUnit: ServingUnit.fromApiValue(json['serving_unit'] as String? ?? 'g'),
        kcalPer100: (json['kcal_per_100'] as num?)?.toDouble() ?? 0,
        proteinPer100: (json['protein_per_100'] as num?)?.toDouble() ?? 0,
        carbPer100: (json['carb_per_100'] as num?)?.toDouble() ?? 0,
        fatPer100: (json['fat_per_100'] as num?)?.toDouble() ?? 0,
        fiberPer100: (json['fiber_per_100'] as num?)?.toDouble() ?? 0,
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

  String get subtypeLabel {
    if (foodSubtype != null) return foodSubtype!.displayName;
    if (drinkSubtype != null) return drinkSubtype!.displayName;
    if (spiceSubtype != null) return spiceSubtype!.displayName;
    return type.displayName;
  }

  String get servingUnitLabel => servingUnit == ServingUnit.ml ? 'per 100ml' : 'per 100g';
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

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) => RecipeIngredient(
        id: json['id'] as String,
        recipeId: json['recipe_id'] as String,
        foodItemId: json['food_item_id'] as String,
        foodItem: json['food_item'] != null
            ? FoodItem.fromJson(json['food_item'] as Map<String, dynamic>)
            : null,
        quantity: (json['quantity'] as num).toDouble(),
        note: json['note'] as String?,
        position: json['position'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'food_item_id': foodItemId,
        'quantity': quantity,
        'note': note,
        'position': position,
      };

  String get quantityLabel {
    final unit = foodItem?.servingUnit.displayName ?? 'g';
    final q = quantity == quantity.truncateToDouble() ? quantity.toInt().toString() : quantity.toStringAsFixed(1);
    return '$q$unit';
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

  Map<String, dynamic> toJson() => {'url': url, 'title': title, 'position': position};
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
        kcalPerServing: (json['kcal_per_serving'] as num?)?.toDouble() ?? 0,
        proteinPerServing: (json['protein_per_serving'] as num?)?.toDouble() ?? 0,
        carbPerServing: (json['carb_per_serving'] as num?)?.toDouble() ?? 0,
        fatPerServing: (json['fat_per_serving'] as num?)?.toDouble() ?? 0,
        fiberPerServing: (json['fiber_per_serving'] as num?)?.toDouble() ?? 0,
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

  String get thumbnailUrl => images.firstWhere((i) => i.isThumbnail, orElse: () => images.firstOrNull ?? const RecipeImage(id: '', recipeId: '', url: '', isThumbnail: false, position: 0)).url;

  String? get thumbnailUrlOrNull => images.isEmpty ? null : thumbnailUrl;

  String get timeLabel {
    final parts = <String>[];
    if (prepTimeMinutes != null) parts.add('Prep ${prepTimeMinutes}m');
    if (cookTimeMinutes != null) parts.add('Cook ${cookTimeMinutes}m');
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

  factory DailyMealPlanSlotEntry.fromJson(Map<String, dynamic> json) => DailyMealPlanSlotEntry(
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
        quantity: (json['quantity'] as num?)?.toDouble(),
        servings: (json['servings'] as num?)?.toDouble() ?? 1.0,
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

  String get displayName => foodItem?.name ?? recipe?.name ?? 'Item';

  String get amountLabel {
    if (foodItem != null && quantity != null) {
      final unit = foodItem!.servingUnit.displayName;
      final q = quantity! == quantity!.truncateToDouble() ? quantity!.toInt().toString() : quantity!.toStringAsFixed(1);
      return '$q$unit';
    }
    if (recipe != null) {
      return servings == 1.0 ? '1 serving' : '${servings.toStringAsFixed(1)} servings';
    }
    return '';
  }

  double get kcal {
    if (foodItem != null && quantity != null) return foodItem!.kcalPer100 * quantity! / 100;
    if (recipe != null) return recipe!.kcalPerServing * servings;
    return 0;
  }

  double get protein {
    if (foodItem != null && quantity != null) return foodItem!.proteinPer100 * quantity! / 100;
    if (recipe != null) return recipe!.proteinPerServing * servings;
    return 0;
  }

  double get carb {
    if (foodItem != null && quantity != null) return foodItem!.carbPer100 * quantity! / 100;
    if (recipe != null) return recipe!.carbPerServing * servings;
    return 0;
  }

  double get fat {
    if (foodItem != null && quantity != null) return foodItem!.fatPer100 * quantity! / 100;
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

  factory DailyMealPlanSlot.fromJson(Map<String, dynamic> json) => DailyMealPlanSlot(
        id: json['id'] as String,
        dailyMealPlanId: json['daily_meal_plan_id'] as String,
        slotType: MealSlotType.fromApiValue(json['slot_type'] as String) ?? MealSlotType.breakfast,
        position: json['position'] as int? ?? 0,
        note: json['note'] as String?,
        entries: (json['entries'] as List<dynamic>? ?? [])
            .map((e) => DailyMealPlanSlotEntry.fromJson(e as Map<String, dynamic>))
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
        kcalTotal: (json['kcal_total'] as num?)?.toDouble() ?? 0,
        proteinTotal: (json['protein_total'] as num?)?.toDouble() ?? 0,
        carbTotal: (json['carb_total'] as num?)?.toDouble() ?? 0,
        fatTotal: (json['fat_total'] as num?)?.toDouble() ?? 0,
        fiberTotal: (json['fiber_total'] as num?)?.toDouble() ?? 0,
        slots: (json['slots'] as List<dynamic>? ?? [])
            .map((s) => DailyMealPlanSlot.fromJson(s as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

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

  Map<String, dynamic> toJson() => {'url': url, 'is_thumbnail': isThumbnail, 'position': position};
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
            ? DailyMealPlan.fromJson(json['daily_meal_plan'] as Map<String, dynamic>)
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

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String get dayLabel => _dayNames[dayOfWeek - 1];
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
    final thumb = images.firstWhere((i) => i.isThumbnail, orElse: () => images.firstOrNull ?? const MealPlanImage(id: '', mealPlanId: '', url: '', isThumbnail: false, position: 0));
    return thumb.url;
  }

  String? get thumbnailUrlOrNull => images.isEmpty ? null : thumbnailUrl;

  String get weeksLabel => numWeeks == 1 ? '1 Week' : '$numWeeks Weeks';
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
  final DateTime createdAt;

  const MealPlanAssignment({
    required this.id,
    required this.mealPlanId,
    this.mealPlan,
    required this.userId,
    this.assignedById,
    this.startDate,
    this.endDate,
    this.note,
    required this.createdAt,
  });

  factory MealPlanAssignment.fromJson(Map<String, dynamic> json) => MealPlanAssignment(
        id: json['id'] as String,
        mealPlanId: json['meal_plan_id'] as String,
        mealPlan: json['meal_plan'] != null
            ? MealPlan.fromJson(json['meal_plan'] as Map<String, dynamic>)
            : null,
        userId: json['user_id'] as String,
        assignedById: json['assigned_by_id'] as String?,
        startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
        endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'meal_plan_id': mealPlanId,
        'user_id': userId,
        'start_date': startDate?.toIso8601String().substring(0, 10),
        'end_date': endDate?.toIso8601String().substring(0, 10),
        'note': note,
      };
}
