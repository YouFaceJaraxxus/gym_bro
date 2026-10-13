// Food diary entries.
part of '../api_service.dart';

/// Food diary, barcode lookup and micronutrients.
extension FoodLogsApi on ApiService {
  /// GET /food-logs?date= (or from/to) — entries ordered by slot, then time.
  Future<List<FoodLog>> getFoodLogs(
    String token, {
    DateTime? date,
    DateTime? from,
    DateTime? to,
    String? userId,
  }) async {
    final params = <String, String>{
      if (date != null) 'date': apiDate(date),
      if (from != null) 'from': apiDate(from),
      if (to != null) 'to': apiDate(to),
      'user_id': ?userId,
    };
    final r = await _client.get(
      Uri.parse('$_base/food-logs').replace(queryParameters: params),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => FoodLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /food-logs/summary — totals per slot and day, plan targets, planned meals.
  Future<FoodLogSummary> getFoodLogSummary(
    String token,
    DateTime date, {
    String? userId,
  }) async {
    final params = <String, String>{
      'date': apiDate(date),
      'user_id': ?userId,
    };
    final r = await _client.get(
      Uri.parse('$_base/food-logs/summary').replace(queryParameters: params),
      headers: _headers(token),
    );
    _check(r);
    return FoodLogSummary.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// POST /food-logs — exactly one of [foodItemId] / [recipeId]; [amount] is
  /// g/ml for food items and servings for recipes. Macros are computed server-side.
  Future<FoodLog> createFoodLog(
    String token, {
    required DateTime date,
    required MealSlotType slotType,
    String? foodItemId,
    String? recipeId,
    required double amount,
    String? note,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/food-logs'),
      headers: _headers(token),
      body: jsonEncode({
        'log_date': apiDate(date),
        'slot_type': slotType.apiValue,
        'food_item_id': ?foodItemId,
        'recipe_id': ?recipeId,
        'amount': amount,
        if (note != null && note.isNotEmpty) 'note': note,
      }),
    );
    _check(r);
    return FoodLog.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// PUT /food-logs/:id — {amount?, slot_type?, log_date?, note?}.
  Future<FoodLog> updateFoodLog(
    String token,
    String id, {
    double? amount,
    MealSlotType? slotType,
    DateTime? date,
    String? note,
  }) async {
    final r = await _client.put(
      Uri.parse('$_base/food-logs/$id'),
      headers: _headers(token),
      body: jsonEncode({
        'amount': ?amount,
        if (slotType != null) 'slot_type': slotType.apiValue,
        if (date != null) 'log_date': apiDate(date),
        'note': ?note,
      }),
    );
    _check(r);
    return FoodLog.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteFoodLog(String token, String id) async {
    final r = await _client.delete(
      Uri.parse('$_base/food-logs/$id'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }

  /// POST /food-logs/from-plan — logs the day's planned meals (optionally one slot).
  Future<List<FoodLog>> logPlannedMeals(
    String token,
    DateTime date, {
    MealSlotType? slotType,
  }) async {
    final r = await _client.post(
      Uri.parse('$_base/food-logs/from-plan'),
      headers: _headers(token),
      body: jsonEncode({
        'date': apiDate(date),
        if (slotType != null) 'slot_type': slotType.apiValue,
      }),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => FoodLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /food-items/barcode/:code — local item, or imported from Open Food
  /// Facts as a private item. Throws [BarcodeNotFoundException] when unknown.
  Future<BarcodeLookupResult> lookupBarcode(String token, String code) async {
    final r = await _client.get(
      Uri.parse('$_base/food-items/barcode/${Uri.encodeComponent(code)}'),
      headers: _headers(token),
    );
    if (r.statusCode == 404) throw BarcodeNotFoundException(code);
    _check(r);
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    return BarcodeLookupResult(
      item: FoodItem.fromJson(body),
      source: body['source'] as String? ?? 'local',
    );
  }

  /// GET /food-items/nutrients — vitamin and mineral reference lists.
  Future<NutrientReference> getNutrients(String token) async {
    final r = await _client.get(
      Uri.parse('$_base/food-items/nutrients'),
      headers: _headers(token),
    );
    _check(r);
    return NutrientReference.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
