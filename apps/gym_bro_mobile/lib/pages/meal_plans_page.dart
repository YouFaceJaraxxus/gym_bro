import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/draft.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/drafts.dart';
import '../widgets/meal_plan_assign.dart';
import 'food_item_detail_page.dart';
import 'food_item_form_page.dart';
import 'recipe_detail_page.dart';
import 'recipe_form_page.dart';
import 'daily_meal_plan_detail_page.dart';
import 'daily_meal_plan_form_page.dart';
import 'meal_plan_detail_page.dart';
import 'meal_plan_form_page.dart';
import 'nutrition/barcode_scan_page.dart';
import 'nutrition/food_diary_page.dart';
import 'nutrition/nutrition_widgets.dart';

class MealPlansPage extends StatefulWidget {
  const MealPlansPage({super.key});

  @override
  State<MealPlansPage> createState() => _MealPlansPageState();
}

class _MealPlansPageState extends State<MealPlansPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Bumped after creating an item so the (keep-alive) tabs of that kind
  // rebuild and reload.
  int _foodV = 0;
  int _recipeV = 0;
  int _dailyV = 0;
  int _planV = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nutritionMealPlansTitle),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l10n.nutritionTabPlans),
            Tab(text: l10n.nutritionTabAssigned),
            Tab(text: l10n.nutritionTabFood),
            Tab(text: l10n.nutritionRecipes),
            Tab(text: l10n.nutritionTabDailyPlans),
            Tab(text: l10n.nutritionTabMyLibrary),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.nutritionFoodDiary,
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FoodDiaryPage()),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: l10n.nutritionCreate,
            icon: const Icon(Icons.add),
            onSelected: (v) async {
              switch (v) {
                case 'food':
                  await openCreateWithDrafts<FoodItem>(
                    context,
                    kind: DraftKind.foodItem,
                    builder: (draft) => FoodItemFormPage(draft: draft),
                  );
                  if (mounted) setState(() => _foodV++);
                case 'recipe':
                  await openCreateWithDrafts<Recipe>(
                    context,
                    kind: DraftKind.recipe,
                    builder: (draft) => RecipeFormPage(draft: draft),
                  );
                  if (mounted) setState(() => _recipeV++);
                case 'daily':
                  await openCreateWithDrafts<DailyMealPlan>(
                    context,
                    kind: DraftKind.dailyMealPlan,
                    builder: (draft) => DailyMealPlanFormPage(draft: draft),
                  );
                  if (mounted) setState(() => _dailyV++);
                case 'plan':
                  final created = await openCreateWithDrafts<MealPlan>(
                    context,
                    kind: DraftKind.mealPlan,
                    builder: (draft) => MealPlanFormPage(draft: draft),
                  );
                  if (created != null && mounted) setState(() => _planV++);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'food', child: Text(l10n.nutritionNewFoodItemTitle)),
              PopupMenuItem(value: 'recipe', child: Text(l10n.nutritionNewRecipeTitle)),
              PopupMenuItem(value: 'daily', child: Text(l10n.nutritionNewDailyPlanMenu)),
              PopupMenuItem(value: 'plan', child: Text(l10n.nutritionNewMealPlanTitle)),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MealPlansTab(key: ValueKey('plans-$_planV'), mine: false),
          const _AssignedTab(),
          _FoodTab(key: ValueKey('food-$_foodV'), mine: false),
          _RecipesTab(key: ValueKey('recipes-$_recipeV'), mine: false),
          _DailyPlansTab(key: ValueKey('daily-$_dailyV'), mine: false),
          _MyLibraryTab(
            foodV: _foodV,
            recipeV: _recipeV,
            dailyV: _dailyV,
            planV: _planV,
          ),
        ],
      ),
    );
  }
}

// ── Food tab ──────────────────────────────────────────────────────────────────

class _FoodTab extends StatefulWidget {
  final bool mine;
  const _FoodTab({super.key, required this.mine});

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
        Row(
          children: [
            Expanded(
              child: _SearchBar(controller: _search, onSearch: () => _load(reset: true)),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: IconButton(
                tooltip: context.l10n.nutritionScanBarcode,
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scan,
              ),
            ),
          ],
        ),
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

  /// Scans a barcode and opens the found (or freshly imported) item.
  Future<void> _scan() async {
    final item = await scanFoodItem(context);
    if (item == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FoodItemDetailPage(foodItemId: item.id)),
    );
    if (mounted) _load(reset: true);
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return _ErrorRetry(error: _error!, onRetry: () => _load(reset: true));
    }
    if (_items.isEmpty) {
      return Center(child: Text(context.l10n.nutritionNoFoodItemsFound));
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
  const _RecipesTab({super.key, required this.mine});

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
      return Center(child: Text(context.l10n.nutritionNoRecipesFound));
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
  const _DailyPlansTab({super.key, required this.mine});

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
      return Center(child: Text(context.l10n.nutritionNoDailyPlansFound));
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

// ── Meal Plans tab ────────────────────────────────────────────────────────────

class _MealPlansTab extends StatefulWidget {
  final bool mine;
  const _MealPlansTab({super.key, required this.mine});

  @override
  State<_MealPlansTab> createState() => _MealPlansTabState();
}

class _MealPlansTabState extends State<_MealPlansTab>
    with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  final _search = TextEditingController();
  List<MealPlan> _items = [];
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
      final results = await _api.getMealPlans(
        token,
        name: _search.text.trim().isEmpty ? null : _search.text.trim(),
        mine: widget.mine,
        page: _page,
        pageSize: 20,
      );
      if (!mounted) return;
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
      if (!mounted) return;
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
      return Center(
        child: Text(widget.mine
            ? context.l10n.nutritionNoOwnMealPlans
            : context.l10n.nutritionNoMealPlansFound),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: NotificationListener<ScrollNotification>(
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
            return MealPlanCard(
              plan: plan,
              onTap: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MealPlanDetailPage(mealPlanId: plan.id),
                  ),
                );
                if (changed == true) _load(reset: true);
              },
            );
          },
        ),
      ),
    );
  }
}

// ── Assigned tab ──────────────────────────────────────────────────────────────

class _AssignedTab extends StatefulWidget {
  const _AssignedTab();

  @override
  State<_AssignedTab> createState() => _AssignedTabState();
}

class _AssignedTabState extends State<_AssignedTab>
    with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  bool _byMe = false;
  List<MealPlanAssignment> _items = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      await AuthManager.instance.ensureProfile();
      final me = AuthManager.instance.profile;
      if (me == null) throw Exception('Not signed in');
      List<MealPlanAssignment> items;
      if (_byMe) {
        items = (await _api.getMealPlanAssignments(token))
            .where((a) => a.assignedById == me.id && a.userId != me.id)
            .toList();
      } else {
        items = await _api.getMealPlanAssignments(token, userId: me.id);
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _remove(MealPlanAssignment a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.nutritionRemoveAssignmentTitle),
        content: Text(ctx.l10n.nutritionRemoveAssignmentMessage(a.localizedPlanName(ctx.l10n))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(ctx.l10n.nutritionRemove),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteMealPlanAssignment(token, a.id);
      _load();
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''), style: TextStyle(color: cs.onError)),
            backgroundColor: cs.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(context.l10n.nutritionAssignedToMe)),
                ButtonSegment(value: true, label: Text(context.l10n.nutritionAssignedByMe)),
              ],
              selected: {_byMe},
              onSelectionChanged: (s) {
                if (s.isEmpty || s.first == _byMe) return;
                setState(() {
                  _byMe = s.first;
                  _items = [];
                });
                _load();
              },
            ),
          ),
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
      return _ErrorRetry(error: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.assignment_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _byMe
                    ? context.l10n.nutritionNoAssignmentsByMe
                    : context.l10n.nutritionNoAssignmentsToMe,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }
    final myId = AuthManager.instance.profile?.id;
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final a = _items[i];
          final String who;
          if (_byMe) {
            who = l10n.nutritionAssignmentFor(a.userName ?? l10n.nutritionMemberFallback);
          } else if (a.assignedById == null || a.assignedById == myId) {
            who = l10n.nutritionSelfAssigned;
          } else {
            who = l10n.nutritionAssignedBy(a.assignedByName ?? l10n.nutritionYourCoachFallback);
          }
          return AssignmentCard(
            assignment: a,
            subtitle: who,
            onTap: () async {
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => MealPlanDetailPage(mealPlanId: a.mealPlanId),
                ),
              );
              _load();
            },
            onRemove: () => _remove(a),
          );
        },
      ),
    );
  }
}

/// A meal plan assignment row: plan name, [subtitle] (who assigned it / who
/// it is for), start date and an optional remove action.
class AssignmentCard extends StatelessWidget {
  final MealPlanAssignment assignment;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const AssignmentCard({
    super.key,
    required this.assignment,
    required this.subtitle,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final dates = [
      if (a.startDate != null) l10n.nutritionStartsOn(formatPlanDate(a.startDate!, locale)),
      if (a.endDate != null) l10n.nutritionEndsOn(formatPlanDate(a.endDate!, locale)),
    ];
    if (dates.isEmpty) dates.add(l10n.nutritionAssignedOn(formatPlanDate(a.createdAt.toLocal(), locale)));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cs.tertiaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.restaurant_menu, color: cs.onTertiaryContainer),
        ),
        title: Text(a.localizedPlanName(l10n),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '$subtitle\n${dates.join(' · ')}'
          '${a.note != null && a.note!.isNotEmpty ? '\n${a.note}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: onRemove == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: l10n.nutritionRemove,
                icon: Icon(Icons.close, color: cs.error),
                onPressed: onRemove,
              ),
        onTap: onTap,
      ),
    );
  }
}

// ── My Library tab ────────────────────────────────────────────────────────────

class _MyLibraryTab extends StatelessWidget {
  final int foodV;
  final int recipeV;
  final int dailyV;
  final int planV;

  const _MyLibraryTab({
    required this.foodV,
    required this.recipeV,
    required this.dailyV,
    required this.planV,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l10n.nutritionTabMyFood),
              Tab(text: l10n.nutritionTabMyRecipes),
              Tab(text: l10n.nutritionTabMyDailyPlans),
              Tab(text: l10n.nutritionTabMyMealPlans),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _FoodTab(key: ValueKey('my-food-$foodV'), mine: true),
                _RecipesTab(key: ValueKey('my-recipes-$recipeV'), mine: true),
                _DailyPlansTab(key: ValueKey('my-daily-$dailyV'), mine: true),
                _MealPlansTab(key: ValueKey('my-plans-$planV'), mine: true),
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

  @override
  Widget build(BuildContext context) {
    final colors = foodTypeColors(context, item.type);
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final dec = NumberFormat('0.0', Localizations.localeOf(context).toString());
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
                  color: colors.container,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.food_bank_outlined, color: colors.onContainer, size: 22),
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
                          Icon(Icons.lock_outline,
                              size: 14, color: cs.onSurfaceVariant, semanticLabel: l10n.nutritionPrivate),
                      ],
                    ),
                    if (item.brand != null) ...[
                      const SizedBox(height: 2),
                      Text(item.brand!,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _TypeChip(label: item.subtypeLabel(l10n), background: colors.container, foreground: colors.onContainer),
                        const Spacer(),
                        _MacroMini(
                            label: l10n.nutritionKcal,
                            semanticsLabel: l10n.nutritionKcal,
                            value: item.kcalPer100.round().toString()),
                        const SizedBox(width: 8),
                        _MacroMini(
                            label: l10n.nutritionProteinLetter,
                            semanticsLabel: l10n.nutritionProtein,
                            value:
                                '${dec.format(item.proteinPer100)}g'),
                        const SizedBox(width: 8),
                        _MacroMini(
                            label: l10n.nutritionCarbsLetter,
                            semanticsLabel: l10n.nutritionCarbs,
                            value: '${dec.format(item.carbPer100)}g'),
                        const SizedBox(width: 8),
                        _MacroMini(
                            label: l10n.nutritionFatLetter,
                            semanticsLabel: l10n.nutritionFat,
                            value: '${dec.format(item.fatPer100)}g'),
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
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final timeLabel = recipe.timeLabel(l10n);
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
                excludeFromSemantics: true,
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
                        Icon(Icons.lock_outline,
                            size: 14, color: cs.onSurfaceVariant, semanticLabel: l10n.nutritionPrivate),
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
                          TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _TypeChip(
                          label: l10n.nutritionServingsAmount(recipe.servings, '${recipe.servings}'),
                          background: cs.secondaryContainer,
                          foreground: cs.onSecondaryContainer),
                      if (timeLabel.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(timeLabel,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: cs.onSurfaceVariant)),
                        ),
                      ],
                      const Spacer(),
                      _MacroMini(
                          label: l10n.nutritionKcal,
                          semanticsLabel: l10n.nutritionKcalPerServingLabel,
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
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final dec = NumberFormat('0.0', Localizations.localeOf(context).toString());
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
                    Icon(Icons.lock_outline,
                        size: 14, color: cs.onSurfaceVariant, semanticLabel: l10n.nutritionPrivate),
                ],
              ),
              if (plan.description != null &&
                  plan.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  plan.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _MacroMini(
                      label: l10n.nutritionKcal,
                      semanticsLabel: l10n.nutritionKcal,
                      value: plan.kcalTotal.round().toString()),
                  const SizedBox(width: 10),
                  _MacroMini(
                      label: l10n.nutritionProteinLetter,
                      semanticsLabel: l10n.nutritionProtein,
                      value: '${dec.format(plan.proteinTotal)}g'),
                  const SizedBox(width: 10),
                  _MacroMini(
                      label: l10n.nutritionCarbsLetter,
                      semanticsLabel: l10n.nutritionCarbs,
                      value: '${dec.format(plan.carbTotal)}g'),
                  const SizedBox(width: 10),
                  _MacroMini(
                      label: l10n.nutritionFatLetter,
                      semanticsLabel: l10n.nutritionFat,
                      value: '${dec.format(plan.fatTotal)}g'),
                  const Spacer(),
                  Text(
                    l10n.nutritionMealCount(plan.displayMealCount),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
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
                excludeFromSemantics: true,
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
                        Icon(Icons.lock_outline,
                            size: 14, color: cs.onSurfaceVariant, semanticLabel: l10n.nutritionPrivate),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _TypeChip(
                          label: plan.weeksLabel(l10n),
                          background: cs.tertiaryContainer,
                          foreground: cs.onTertiaryContainer),
                      if (plan.description != null &&
                          plan.description!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            plan.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurfaceVariant),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          _FilterChip(
            label: context.l10n.nutritionFilterAll,
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          ...FoodItemType.values.map((t) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: t.label(context.l10n),
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
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // 48 dp tall hit area around the compact chip.
      child: SizedBox(
      height: 48,
      child: Center(
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
      ),
      ),
      ),
    );
  }
}

// ── Shared small helpers ──────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _TypeChip({required this.label, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}

class _MacroMini extends StatelessWidget {
  final String label;
  final String value;

  /// Spoken instead of the abbreviated [label] ("Protein" for "P").
  final String semanticsLabel;

  const _MacroMini({required this.label, required this.value, required this.semanticsLabel});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semanticsLabel $value',
      excludeSemantics: true,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text(label,
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
      ),
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
          hintText: context.l10n.nutritionSearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  tooltip: context.l10n.nutritionClearSearch,
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
        ],
      ),
    );
  }
}
