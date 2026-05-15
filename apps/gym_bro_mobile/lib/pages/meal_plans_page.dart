import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'food_item_detail_page.dart';
import 'food_item_form_page.dart';
import 'recipe_detail_page.dart';
import 'recipe_form_page.dart';
import 'daily_meal_plan_detail_page.dart';
import 'daily_meal_plan_form_page.dart';
import 'meal_plan_form_page.dart';

class MealPlansPage extends StatefulWidget {
  const MealPlansPage({super.key});

  @override
  State<MealPlansPage> createState() => _MealPlansPageState();
}

class _MealPlansPageState extends State<MealPlansPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Plans'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Food'),
            Tab(text: 'Recipes'),
            Tab(text: 'Daily Plans'),
            Tab(text: 'My Library'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            onSelected: (v) async {
              switch (v) {
                case 'food':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FoodItemFormPage()),
                  );
                case 'recipe':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecipeFormPage()),
                  );
                case 'daily':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DailyMealPlanFormPage()),
                  );
                case 'plan':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MealPlanFormPage()),
                  );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'food', child: Text('New Food Item')),
              PopupMenuItem(value: 'recipe', child: Text('New Recipe')),
              PopupMenuItem(value: 'daily', child: Text('New Daily Plan')),
              PopupMenuItem(value: 'plan', child: Text('New Meal Plan')),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _FoodTab(mine: false),
          _RecipesTab(mine: false),
          _DailyPlansTab(mine: false),
          _MyLibraryTab(),
        ],
      ),
    );
  }
}

// ── Food tab ──────────────────────────────────────────────────────────────────

class _FoodTab extends StatefulWidget {
  final bool mine;
  const _FoodTab({required this.mine});

  @override
  State<_FoodTab> createState() => _FoodTabState();
}

class _FoodTabState extends State<_FoodTab> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  final _search = TextEditingController();
  FoodItemType? _typeFilter;
  List<FoodItem> _items = [];
  bool _loading = true;
  String? _error;
  int _page = 0;
  bool _hasMore = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 0;
      _hasMore = true;
    }
    if (!_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await _api.getFoodItems(
        token,
        name: _search.text.trim().isEmpty ? null : _search.text.trim(),
        type: _typeFilter,
        mine: widget.mine,
        page: _page,
        pageSize: 20,
      );
      setState(() {
        if (reset) {
          _items = results;
        } else {
          _items.addAll(results);
        }
        _hasMore = results.length == 20;
        _page++;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _SearchBar(controller: _search, onSearch: () => _load(reset: true)),
        _TypeFilterRow(
          selected: _typeFilter,
          onChanged: (t) {
            setState(() => _typeFilter = t);
            _load(reset: true);
          },
        ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return _ErrorRetry(error: _error!, onRetry: () => _load(reset: true));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No food items found'));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!_loading && _hasMore && n.metrics.extentAfter < 200) _load();
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length + (_loading ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final item = _items[i];
          return FoodItemCard(
            item: item,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FoodItemDetailPage(foodItemId: item.id),
                ),
              );
              _load(reset: true);
            },
          );
        },
      ),
    );
  }
}

// ── Recipes tab ───────────────────────────────────────────────────────────────

class _RecipesTab extends StatefulWidget {
  final bool mine;
  const _RecipesTab({required this.mine});

  @override
  State<_RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends State<_RecipesTab>
    with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  final _search = TextEditingController();
  List<Recipe> _items = [];
  bool _loading = true;
  String? _error;
  int _page = 0;
  bool _hasMore = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 0;
      _hasMore = true;
    }
    if (!_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await _api.getRecipes(
        token,
        name: _search.text.trim().isEmpty ? null : _search.text.trim(),
        mine: widget.mine,
        page: _page,
        pageSize: 20,
      );
      setState(() {
        if (reset) {
          _items = results;
        } else {
          _items.addAll(results);
        }
        _hasMore = results.length == 20;
        _page++;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _SearchBar(controller: _search, onSearch: () => _load(reset: true)),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return _ErrorRetry(error: _error!, onRetry: () => _load(reset: true));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No recipes found'));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!_loading && _hasMore && n.metrics.extentAfter < 200) _load();
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length + (_loading ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final recipe = _items[i];
          return RecipeCard(
            recipe: recipe,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeDetailPage(recipeId: recipe.id),
                ),
              );
              _load(reset: true);
            },
          );
        },
      ),
    );
  }
}

// ── Daily Plans tab ───────────────────────────────────────────────────────────

class _DailyPlansTab extends StatefulWidget {
  final bool mine;
  const _DailyPlansTab({required this.mine});

  @override
  State<_DailyPlansTab> createState() => _DailyPlansTabState();
}

class _DailyPlansTabState extends State<_DailyPlansTab>
    with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  final _search = TextEditingController();
  List<DailyMealPlan> _items = [];
  bool _loading = true;
  String? _error;
  int _page = 0;
  bool _hasMore = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 0;
      _hasMore = true;
    }
    if (!_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await _api.getDailyMealPlans(
        token,
        name: _search.text.trim().isEmpty ? null : _search.text.trim(),
        mine: widget.mine,
        page: _page,
        pageSize: 20,
      );
      setState(() {
        if (reset) {
          _items = results;
        } else {
          _items.addAll(results);
        }
        _hasMore = results.length == 20;
        _page++;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _SearchBar(controller: _search, onSearch: () => _load(reset: true)),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return _ErrorRetry(error: _error!, onRetry: () => _load(reset: true));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No daily plans found'));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!_loading && _hasMore && n.metrics.extentAfter < 200) _load();
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length + (_loading ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final plan = _items[i];
          return DailyMealPlanCard(
            plan: plan,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DailyMealPlanDetailPage(dailyMealPlanId: plan.id),
                ),
              );
              _load(reset: true);
            },
          );
        },
      ),
    );
  }
}

// ── My Library tab ────────────────────────────────────────────────────────────

class _MyLibraryTab extends StatelessWidget {
  const _MyLibraryTab();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: const [
          TabBar(
            tabs: [
              Tab(text: 'My Food'),
              Tab(text: 'My Recipes'),
              Tab(text: 'My Plans'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _FoodTab(mine: true),
                _RecipesTab(mine: true),
                _DailyPlansTab(mine: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card widgets ──────────────────────────────────────────────────────────────

class FoodItemCard extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onTap;

  const FoodItemCard({super.key, required this.item, required this.onTap});

  Color _typeColor(FoodItemType t) {
    switch (t) {
      case FoodItemType.food:
        return Colors.green;
      case FoodItemType.drink:
        return Colors.blue;
      case FoodItemType.spice:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(item.type);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.food_bank_outlined, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        if (!item.isPublic)
                          const Icon(Icons.lock_outline,
                              size: 14, color: Colors.grey),
                      ],
                    ),
                    if (item.brand != null) ...[
                      const SizedBox(height: 2),
                      Text(item.brand!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _TypeChip(label: item.subtypeLabel, color: color),
                        const Spacer(),
                        _MacroMini(
                            label: 'kcal',
                            value: item.kcalPer100.round().toString()),
                        const SizedBox(width: 8),
                        _MacroMini(
                            label: 'P',
                            value:
                                '${item.proteinPer100.toStringAsFixed(1)}g'),
                        const SizedBox(width: 8),
                        _MacroMini(
                            label: 'C',
                            value: '${item.carbPer100.toStringAsFixed(1)}g'),
                        const SizedBox(width: 8),
                        _MacroMini(
                            label: 'F',
                            value: '${item.fatPer100.toStringAsFixed(1)}g'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeCard({super.key, required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe.thumbnailUrlOrNull != null)
              Image.network(
                recipe.thumbnailUrlOrNull!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context2, err, stack) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (!recipe.isPublic)
                        const Icon(Icons.lock_outline,
                            size: 14, color: Colors.grey),
                    ],
                  ),
                  if (recipe.description != null &&
                      recipe.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      recipe.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _TypeChip(
                          label: '${recipe.servings} serving${recipe.servings == 1 ? '' : 's'}',
                          color: Colors.purple),
                      if (recipe.timeLabel.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(recipe.timeLabel,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                      const Spacer(),
                      _MacroMini(
                          label: 'kcal',
                          value: recipe.kcalPerServing.round().toString()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyMealPlanCard extends StatelessWidget {
  final DailyMealPlan plan;
  final VoidCallback onTap;

  const DailyMealPlanCard(
      {super.key, required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (!plan.isPublic)
                    const Icon(Icons.lock_outline,
                        size: 14, color: Colors.grey),
                ],
              ),
              if (plan.description != null &&
                  plan.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  plan.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _MacroMini(
                      label: 'kcal',
                      value: plan.kcalTotal.round().toString()),
                  const SizedBox(width: 10),
                  _MacroMini(
                      label: 'P',
                      value: '${plan.proteinTotal.toStringAsFixed(1)}g'),
                  const SizedBox(width: 10),
                  _MacroMini(
                      label: 'C',
                      value: '${plan.carbTotal.toStringAsFixed(1)}g'),
                  const SizedBox(width: 10),
                  _MacroMini(
                      label: 'F',
                      value: '${plan.fatTotal.toStringAsFixed(1)}g'),
                  const Spacer(),
                  Text(
                    '${plan.slots.length} meal${plan.slots.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MealPlanCard extends StatelessWidget {
  final MealPlan plan;
  final VoidCallback onTap;

  const MealPlanCard({super.key, required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plan.thumbnailUrlOrNull != null)
              Image.network(
                plan.thumbnailUrlOrNull!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context2, err, stack) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plan.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (!plan.isPublic)
                        const Icon(Icons.lock_outline,
                            size: 14, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _TypeChip(
                          label: plan.weeksLabel, color: Colors.teal),
                      if (plan.description != null &&
                          plan.description!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            plan.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Type filter row ───────────────────────────────────────────────────────────

class _TypeFilterRow extends StatelessWidget {
  final FoodItemType? selected;
  final ValueChanged<FoodItemType?> onChanged;

  const _TypeFilterRow({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          ...FoodItemType.values.map((t) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: t.displayName,
                  selected: selected == t,
                  onTap: () => onChanged(selected == t ? null : t),
                ),
              )),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? cs.onPrimary : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

// ── Shared small helpers ──────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.85)),
      ),
    );
  }
}

class _MacroMini extends StatelessWidget {
  final String label;
  final String value;

  const _MacroMini({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;

  const _SearchBar({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Search…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onSearch();
                  },
                )
              : null,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
        ),
        onSubmitted: (_) => onSearch(),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
