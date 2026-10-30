import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/food_log.dart';
import '../../models/meal_plan.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'barcode_scan_page.dart';
import 'nutrition_widgets.dart';

/// Search food items / recipes (or scan a barcode) and log one to [date].
/// Pops with `true` when something was logged.
///
/// [eatenAt] records when it was (or will be) eaten, e.g. the hour tapped on
/// the Schedule; [planEntryId] logs it against a planned meal.
class AddFoodLogPage extends StatefulWidget {
  final DateTime date;
  final MealSlotType initialSlot;
  final DateTime? eatenAt;
  final String? planEntryId;

  const AddFoodLogPage({
    super.key,
    required this.date,
    required this.initialSlot,
    this.eatenAt,
    this.planEntryId,
  });

  @override
  State<AddFoodLogPage> createState() => _AddFoodLogPageState();
}

class _AddFoodLogPageState extends State<AddFoodLogPage> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _search = TextEditingController();
  late final TabController _tabs = TabController(length: 2, vsync: this);
  Timer? _debounce;

  List<FoodItem> _foods = [];
  List<Recipe> _recipes = [];
  bool _loadingFoods = true;
  bool _loadingRecipes = true;
  String? _foodsError;
  String? _recipesError;
  bool _saving = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
    setState(() {}); // refresh clear button
  }

  /// Loads public + own items in parallel, own first, without duplicates.
  Future<void> _load() async {
    final id = ++_requestId;
    final q = _search.text.trim().isEmpty ? null : _search.text.trim();
    setState(() {
      _loadingFoods = true;
      _loadingRecipes = true;
      _foodsError = null;
      _recipesError = null;
    });
    final token = await AuthManager.instance.getValidToken();

    Future<void> foods() async {
      try {
        final r = await Future.wait([
          _api.getFoodItems(token, name: q, mine: true, pageSize: 30),
          _api.getFoodItems(token, name: q, pageSize: 30),
        ]);
        final seen = <String>{};
        final merged = [...r[0], ...r[1]].where((f) => seen.add(f.id)).toList();
        if (mounted && id == _requestId) setState(() => _foods = merged);
      } catch (e) {
        if (mounted && id == _requestId) setState(() => _foodsError = errorText(e));
      } finally {
        if (mounted && id == _requestId) setState(() => _loadingFoods = false);
      }
    }

    Future<void> recipes() async {
      try {
        final r = await Future.wait([
          _api.getRecipes(token, name: q, mine: true, pageSize: 30),
          _api.getRecipes(token, name: q, pageSize: 30),
        ]);
        final seen = <String>{};
        final merged = [...r[0], ...r[1]].where((x) => seen.add(x.id)).toList();
        if (mounted && id == _requestId) setState(() => _recipes = merged);
      } catch (e) {
        if (mounted && id == _requestId) setState(() => _recipesError = errorText(e));
      } finally {
        if (mounted && id == _requestId) setState(() => _loadingRecipes = false);
      }
    }

    await Future.wait([foods(), recipes()]);
  }

  Future<void> _logFood(FoodItem item) async {
    final unit = LogUnit.forFoodItem(item);
    final l10n = context.l10n;
    final result = await showLogAmountSheet(
      context,
      title: item.name,
      subtitle: [item.brand, l10n.nutritionKcalPer100(item.kcalPer100.round(), item.servingUnitLabel(l10n))]
          .whereType<String>()
          .join(' · '),
      unit: unit,
      perUnit: MacroTotals.forFoodItem(item, 1),
      initialAmount: 100,
      initialSlot: widget.initialSlot,
    );
    if (result == null) return;
    await _create(result, foodItemId: item.id, name: item.name);
  }

  Future<void> _logRecipe(Recipe recipe) async {
    final result = await showLogAmountSheet(
      context,
      title: recipe.name,
      subtitle: context.l10n.nutritionKcalPerServing(recipe.kcalPerServing.round()),
      unit: LogUnit.serving,
      perUnit: MacroTotals.forRecipe(recipe, 1),
      initialAmount: 1,
      initialSlot: widget.initialSlot,
    );
    if (result == null) return;
    await _create(result, recipeId: recipe.id, name: recipe.name);
  }

  Future<void> _create(LogAmountResult result, {String? foodItemId, String? recipeId, required String name}) async {
    final messenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.createFoodLog(
        token,
        date: widget.date,
        slotType: result.slot,
        foodItemId: foodItemId,
        recipeId: recipeId,
        amount: result.amount,
        eatenAt: widget.eatenAt,
        planEntryId: widget.planEntryId,
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.nutritionLoggedItemToSlot(name, result.slot.label(l10n)))));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
        content: Text(errorText(e), style: TextStyle(color: cs.onError)),
        backgroundColor: cs.error,
      ));
    }
  }

  Future<void> _scan() async {
    final item = await scanFoodItem(context);
    if (item != null && mounted) await _logFood(item);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nutritionAddFoodTitle),
        actions: [
          IconButton(
            tooltip: l10n.nutritionScanBarcode,
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _saving ? null : _scan,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(116),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.nutritionSearchFoodsAndRecipes,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.nutritionClearSearch,
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _search.clear();
                              _load();
                              setState(() {});
                            },
                          ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    isDense: true,
                  ),
                  onChanged: _onQueryChanged,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    _load();
                  },
                ),
              ),
              TabBar(
                controller: _tabs,
                tabs: [Tab(text: l10n.nutritionFoods), Tab(text: l10n.nutritionRecipes)],
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabs,
            children: [
              _ResultList(
                loading: _loadingFoods,
                error: _foodsError,
                isEmpty: _foods.isEmpty,
                emptyIcon: Icons.no_food_outlined,
                emptyTitle: l10n.nutritionNoFoodsFound,
                emptyMessage: l10n.nutritionNoFoodsFoundHint,
                onRetry: _load,
                itemCount: _foods.length,
                itemBuilder: (context, i) {
                  final f = _foods[i];
                  final mine = f.authorId != null && f.authorId == AuthManager.instance.profile?.id;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(f.type == FoodItemType.drink ? Icons.local_drink_outlined : Icons.restaurant),
                    ),
                    title: Text(f.name),
                    subtitle: Text(
                      [f.brand, l10n.nutritionKcalPer100(f.kcalPer100.round(), f.servingUnitLabel(l10n)), if (mine) l10n.nutritionMine]
                          .whereType<String>()
                          .join(' · '),
                    ),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: _saving ? null : () => _logFood(f),
                  );
                },
              ),
              _ResultList(
                loading: _loadingRecipes,
                error: _recipesError,
                isEmpty: _recipes.isEmpty,
                emptyIcon: Icons.menu_book_outlined,
                emptyTitle: l10n.nutritionNoRecipesFound,
                emptyMessage: l10n.nutritionTryAnotherSearch,
                onRetry: _load,
                itemCount: _recipes.length,
                itemBuilder: (context, i) {
                  final r = _recipes[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)),
                    title: Text(r.name),
                    subtitle: Text(
                      '${l10n.nutritionKcalPerServing(r.kcalPerServing.round())} · '
                      '${l10n.nutritionPcfShort(r.proteinPerServing.round(), r.carbPerServing.round(), r.fatPerServing.round())}',
                    ),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: _saving ? null : () => _logRecipe(r),
                  );
                },
              ),
            ],
          ),
          if (_saving) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool isEmpty;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function() onRetry;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const _ResultList({
    required this.loading,
    required this.error,
    required this.isEmpty,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRetry,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && isEmpty) return const Center(child: CircularProgressIndicator());
    if (error != null && isEmpty) return NutritionErrorView(message: error!, onRetry: onRetry);
    return RefreshIndicator(
      onRefresh: onRetry,
      child: isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [NutritionEmptyView(icon: emptyIcon, title: emptyTitle, message: emptyMessage)],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: itemCount,
              itemBuilder: itemBuilder,
            ),
    );
  }
}
