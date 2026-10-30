// Food diary entries, daily summaries, barcode lookups and nutrient reference.
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import 'meal_plan.dart';

// Postgres numeric columns arrive as JSON strings.
double _d(dynamic v, [double fallback = 0]) =>
    v == null ? fallback : double.parse(v.toString());

/// YYYY-MM-DD for the API (local calendar date, no time zone shift).
String apiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Parses a YYYY-MM-DD string into a local date at midnight.
DateTime parseApiDate(String s) {
  final p = s.substring(0, 10).split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Formats amounts without trailing zeros: 100 → "100", 1.5 → "1.5".
/// With a [locale], uses that locale's separators (sr: "1,5").
String fmtAmount(double v, [String? locale]) {
  if (locale != null) {
    return (NumberFormat.decimalPattern(
      locale,
    )..maximumFractionDigits = 2).format(v);
  }
  if (v == v.roundToDouble()) return v.toInt().toString();
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

// ── Units ─────────────────────────────────────────────────────────────────────

enum LogUnit {
  g,
  ml,
  serving;

  static LogUnit fromApiValue(String? v) => switch (v) {
    'ml' => ml,
    'serving' => serving,
    _ => g,
  };

  static LogUnit forFoodItem(FoodItem item) =>
      item.servingUnit == ServingUnit.ml ? ml : g;

  /// "100 g", "250 ml", "1 serving", "1.5 servings".
  String label(AppLocalizations l10n, double amount) {
    final n = fmtAmount(amount, l10n.localeName);
    return switch (this) {
      g => '$n g',
      ml => '$n ml',
      serving => l10n.nutritionServingsAmount(amount, n),
    };
  }

  String shortLabel(AppLocalizations l10n) => switch (this) {
    g => 'g',
    ml => 'ml',
    serving => l10n.nutritionUnitServings,
  };
}

// ── Macros ────────────────────────────────────────────────────────────────────

class MacroTotals {
  final double kcal;
  final double protein;
  final double carb;
  final double fat;
  final double fiber;

  const MacroTotals({
    this.kcal = 0,
    this.protein = 0,
    this.carb = 0,
    this.fat = 0,
    this.fiber = 0,
  });

  static const zero = MacroTotals();

  factory MacroTotals.fromJson(Map<String, dynamic> json) => MacroTotals(
    kcal: _d(json['kcal']),
    protein: _d(json['protein']),
    carb: _d(json['carb']),
    fat: _d(json['fat']),
    fiber: _d(json['fiber']),
  );

  /// Macros for [amount] g/ml of a food item (values stored per 100).
  factory MacroTotals.forFoodItem(FoodItem item, double amount) {
    final f = amount / 100;
    return MacroTotals(
      kcal: item.kcalPer100 * f,
      protein: item.proteinPer100 * f,
      carb: item.carbPer100 * f,
      fat: item.fatPer100 * f,
      fiber: item.fiberPer100 * f,
    );
  }

  /// Macros for [servings] servings of a recipe.
  factory MacroTotals.forRecipe(Recipe recipe, double servings) => MacroTotals(
    kcal: recipe.kcalPerServing * servings,
    protein: recipe.proteinPerServing * servings,
    carb: recipe.carbPerServing * servings,
    fat: recipe.fatPerServing * servings,
    fiber: recipe.fiberPerServing * servings,
  );

  MacroTotals operator +(MacroTotals o) => MacroTotals(
    kcal: kcal + o.kcal,
    protein: protein + o.protein,
    carb: carb + o.carb,
    fat: fat + o.fat,
    fiber: fiber + o.fiber,
  );

  /// "P 12 · C 30 · F 5"
  String pcfLabel(AppLocalizations l10n) =>
      l10n.nutritionPcfShort(protein.round(), carb.round(), fat.round());
}

/// Fraction of [target] reached by [value], clamped to 0..1 (0 when no target).
double progressFraction(double value, double? target) {
  if (target == null || target <= 0) return 0;
  return (value / target).clamp(0.0, 1.0);
}

// ── Food log entry ────────────────────────────────────────────────────────────

class FoodLog {
  final String id;
  final String userId;
  final DateTime logDate;
  final MealSlotType slotType;
  final String? foodItemId;
  final String? recipeId;
  final String name;
  final double amount;
  final LogUnit unit;
  final MacroTotals macros;
  final String? note;

  /// When it was eaten (local); null on older entries (then the slot's usual
  /// time applies).
  final DateTime? eatenAt;

  /// The planned meal this entry logs, if any.
  final String? planEntryId;
  final DateTime createdAt;

  const FoodLog({
    required this.id,
    required this.userId,
    required this.logDate,
    required this.slotType,
    this.foodItemId,
    this.recipeId,
    required this.name,
    required this.amount,
    required this.unit,
    required this.macros,
    this.note,
    this.eatenAt,
    this.planEntryId,
    required this.createdAt,
  });

  factory FoodLog.fromJson(Map<String, dynamic> json) => FoodLog(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    logDate: parseApiDate(json['log_date'] as String),
    slotType:
        MealSlotType.fromApiValue(json['slot_type'] as String) ??
        MealSlotType.breakfast,
    foodItemId: json['food_item_id'] as String?,
    recipeId: json['recipe_id'] as String?,
    name: json['name'] as String? ?? 'Item',
    amount: _d(json['amount']),
    unit: LogUnit.fromApiValue(json['unit'] as String?),
    macros: MacroTotals.fromJson(json),
    note: json['note'] as String?,
    eatenAt: json['eaten_at'] == null
        ? null
        : DateTime.parse(json['eaten_at'] as String).toLocal(),
    planEntryId: json['plan_entry_id'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  String amountLabel(AppLocalizations l10n) => unit.label(l10n, amount);

  /// Item still exists, so the amount can be edited (snapshot recomputed).
  bool get canEditAmount => foodItemId != null || recipeId != null;

  /// Macros per one unit of amount — used to preview edits without refetching.
  MacroTotals get perUnit => amount <= 0
      ? MacroTotals.zero
      : MacroTotals(
          kcal: macros.kcal / amount,
          protein: macros.protein / amount,
          carb: macros.carb / amount,
          fat: macros.fat / amount,
          fiber: macros.fiber / amount,
        );
}

// ── Summary ───────────────────────────────────────────────────────────────────

class SlotTotals {
  final MealSlotType slotType;
  final int count;
  final MacroTotals macros;

  const SlotTotals({
    required this.slotType,
    required this.count,
    required this.macros,
  });

  factory SlotTotals.fromJson(Map<String, dynamic> json) => SlotTotals(
    slotType:
        MealSlotType.fromApiValue(json['slot_type'] as String) ??
        MealSlotType.breakfast,
    count: (json['count'] as num?)?.toInt() ?? 0,
    macros: MacroTotals.fromJson(json),
  );
}

class DiaryPlanInfo {
  final String assignmentId;
  final String mealPlanId;
  final String mealPlanName;
  final int weekNumber;
  final int dayOfWeek;
  final String? dailyMealPlanId;
  final String? dailyMealPlanName;

  const DiaryPlanInfo({
    required this.assignmentId,
    required this.mealPlanId,
    required this.mealPlanName,
    required this.weekNumber,
    required this.dayOfWeek,
    this.dailyMealPlanId,
    this.dailyMealPlanName,
  });

  factory DiaryPlanInfo.fromJson(Map<String, dynamic> json) => DiaryPlanInfo(
    assignmentId: json['assignment_id'] as String,
    mealPlanId: json['meal_plan_id'] as String,
    mealPlanName: json['meal_plan_name'] as String? ?? 'Meal plan',
    weekNumber: (json['week_number'] as num?)?.toInt() ?? 1,
    dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 1,
    dailyMealPlanId: json['daily_meal_plan_id'] as String?,
    dailyMealPlanName: json['daily_meal_plan_name'] as String?,
  );

  String dayLabel(AppLocalizations l10n) =>
      l10n.nutritionWeekDay(weekNumber, dayOfWeek);
}

class PlannedEntry {
  final String? foodItemId;
  final String? recipeId;
  final String name;
  final double amount;
  final LogUnit unit;
  final MacroTotals macros;

  const PlannedEntry({
    this.foodItemId,
    this.recipeId,
    required this.name,
    required this.amount,
    required this.unit,
    required this.macros,
  });

  factory PlannedEntry.fromJson(Map<String, dynamic> json) => PlannedEntry(
    foodItemId: json['food_item_id'] as String?,
    recipeId: json['recipe_id'] as String?,
    name: json['name'] as String? ?? 'Item',
    amount: _d(json['amount']),
    unit: LogUnit.fromApiValue(json['unit'] as String?),
    macros: MacroTotals.fromJson(json),
  );

  String amountLabel(AppLocalizations l10n) => unit.label(l10n, amount);
}

class PlannedSlot {
  final MealSlotType slotType;
  final String? note;
  final List<PlannedEntry> entries;

  const PlannedSlot({required this.slotType, this.note, required this.entries});

  factory PlannedSlot.fromJson(Map<String, dynamic> json) => PlannedSlot(
    slotType:
        MealSlotType.fromApiValue(json['slot_type'] as String) ??
        MealSlotType.breakfast,
    note: json['note'] as String?,
    entries: (json['entries'] as List<dynamic>? ?? [])
        .map((e) => PlannedEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  MacroTotals get macros =>
      entries.fold(MacroTotals.zero, (sum, e) => sum + e.macros);
}

class FoodLogSummary {
  final DateTime date;
  final String userId;
  final MacroTotals totals;
  final List<SlotTotals> slots;

  /// Null when no meal plan (or no planned day) is active on [date].
  final MacroTotals? targets;
  final DiaryPlanInfo? plan;
  final List<PlannedSlot> planned;

  const FoodLogSummary({
    required this.date,
    required this.userId,
    required this.totals,
    required this.slots,
    this.targets,
    this.plan,
    required this.planned,
  });

  factory FoodLogSummary.fromJson(Map<String, dynamic> json) => FoodLogSummary(
    date: parseApiDate(json['date'] as String),
    userId: json['user_id'] as String,
    totals: MacroTotals.fromJson(json['totals'] as Map<String, dynamic>? ?? {}),
    slots: (json['slots'] as List<dynamic>? ?? [])
        .map((e) => SlotTotals.fromJson(e as Map<String, dynamic>))
        .toList(),
    targets: json['targets'] != null
        ? MacroTotals.fromJson(json['targets'] as Map<String, dynamic>)
        : null,
    plan: json['plan'] != null
        ? DiaryPlanInfo.fromJson(json['plan'] as Map<String, dynamic>)
        : null,
    planned: (json['planned'] as List<dynamic>? ?? [])
        .map((e) => PlannedSlot.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  bool get hasPlannedMeals => planned.any((s) => s.entries.isNotEmpty);

  PlannedSlot? plannedFor(MealSlotType slot) => planned
      .where((s) => s.slotType == slot && s.entries.isNotEmpty)
      .firstOrNull;
}

// ── Barcode lookup ────────────────────────────────────────────────────────────

class BarcodeLookupResult {
  final FoodItem item;

  /// 'local' (already in the library) or 'openfoodfacts' (just imported).
  final String source;

  const BarcodeLookupResult({required this.item, required this.source});

  bool get imported => source == 'openfoodfacts';
}

/// No product is known for the scanned barcode (API 404).
class BarcodeNotFoundException implements Exception {
  final String code;
  const BarcodeNotFoundException(this.code);

  @override
  String toString() => 'No product found for barcode $code';

  String message(AppLocalizations l10n) => l10n.nutritionBarcodeNotFound(code);
}

// ── Nutrient reference ────────────────────────────────────────────────────────

class NutrientReference {
  final List<Vitamin> vitamins;
  final List<Mineral> minerals;

  const NutrientReference({required this.vitamins, required this.minerals});

  factory NutrientReference.fromJson(Map<String, dynamic> json) =>
      NutrientReference(
        vitamins: (json['vitamins'] as List<dynamic>? ?? [])
            .map((e) => Vitamin.fromJson(e as Map<String, dynamic>))
            .toList(),
        minerals: (json['minerals'] as List<dynamic>? ?? [])
            .map((e) => Mineral.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
