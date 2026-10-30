import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../theme.dart';
import '../widgets/open_url.dart';
import 'nutrition/nutrition_widgets.dart';
import 'recipe_form_page.dart';
import '../widgets/share_post.dart';

class RecipeDetailPage extends StatefulWidget {
  final String recipeId;

  const RecipeDetailPage({super.key, required this.recipeId});

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  final _api = ApiService();
  Recipe? _recipe;
  bool _loading = true;
  String? _error;

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
      final r = await _api.getRecipe(token, widget.recipeId);
      setState(() {
        _recipe = r;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.nutritionDeleteRecipeTitle),
        content: Text(ctx.l10n.nutritionRemovePermanently(_recipe!.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(ctx.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteRecipe(token, widget.recipeId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorText(e), style: TextStyle(color: cs.onError)),
            backgroundColor: cs.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _recipe == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error ?? l10n.commonSomethingWentWrong, style: TextStyle(color: cs.error)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: Text(l10n.commonRetry)),
          ]),
        ),
      );
    }

    final item = _recipe!;
    final profile = AuthManager.instance.profile;
    final isOwner = profile != null && profile.id == item.authorId;
    final macroColors = MacroColors.of(context);
    final timeLabel = item.timeLabel(l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          SharePostButton(target: recipeShareTarget(item)),
          if (isOwner) ...[
            IconButton(
              tooltip: l10n.commonEdit,
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.push<Recipe>(
                  context,
                  MaterialPageRoute(builder: (_) => RecipeFormPage(recipe: item)),
                );
                if (updated != null) setState(() => _recipe = updated);
              },
            ),
            IconButton(
              tooltip: l10n.commonDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            // ── Hero image ──────────────────────────────────────────────────────
            if (item.thumbnailUrlOrNull != null) ...[
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: Image.network(
                  item.thumbnailUrlOrNull!,
                  semanticLabel: l10n.nutritionPhotoOf(item.name),
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, s) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title row ──────────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (!item.isPublic) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.lock_outline, size: 18, color: cs.onSurfaceVariant, semanticLabel: l10n.nutritionPrivate),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Meta chips row ─────────────────────────────────────────
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MetaChip(
                        icon: Icons.people_outline,
                        label: l10n.nutritionServingsAmount(item.servings, '${item.servings}'),
                      ),
                      if (timeLabel.isNotEmpty)
                        _MetaChip(icon: Icons.timer_outlined, label: timeLabel),
                      _MetaChip(
                        icon: item.isPublic ? Icons.public : Icons.lock_outline,
                        label: item.isPublic ? l10n.nutritionPublic : l10n.nutritionPrivate,
                        color: item.isPublic ? context.appColors.success : cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Macro strip ────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: _MacroChip(label: l10n.nutritionKcal, value: item.kcalPerServing, color: macroColors.kcal)),
                      const SizedBox(width: 6),
                      Expanded(child: _MacroChip(label: l10n.nutritionProtein, value: item.proteinPerServing, color: macroColors.protein, unit: 'g')),
                      const SizedBox(width: 6),
                      Expanded(child: _MacroChip(label: l10n.nutritionCarbsShort, value: item.carbPerServing, color: macroColors.carb, unit: 'g')),
                      const SizedBox(width: 6),
                      Expanded(child: _MacroChip(label: l10n.nutritionFat, value: item.fatPerServing, color: macroColors.fat, unit: 'g')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(l10n.nutritionPerServing, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 20),

                  // ── Description ────────────────────────────────────────────
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    Text(item.description!, style: const TextStyle(fontSize: 15, height: 1.5)),
                    const SizedBox(height: 20),
                  ],

                  // ── Ingredients ────────────────────────────────────────────
                  if (item.ingredients.isNotEmpty) ...[
                    Text(l10n.nutritionIngredients, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: item.ingredients.length,
                      separatorBuilder: (_, i) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final ing = item.ingredients[i];
                        return MergeSemantics(
                          child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ing.foodItem?.name ?? ing.foodItemId,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    if (ing.note != null && ing.note!.isNotEmpty)
                                      Text(
                                        ing.note!,
                                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                ing.quantityLabel(l10n),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Steps ──────────────────────────────────────────────────
                  if (item.steps.isNotEmpty) ...[
                    Text(l10n.nutritionSteps, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: item.steps.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 14),
                      itemBuilder: (context, i) {
                        final step = item.steps[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(step.instruction, style: const TextStyle(fontSize: 14, height: 1.5)),
                                  if (step.imageUrl != null && step.imageUrl!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        step.imageUrl!,
                                        semanticLabel: l10n.nutritionStepPhoto(i + 1),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, e, s) => const SizedBox.shrink(),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Videos ─────────────────────────────────────────────────
                  if (item.videos.isNotEmpty) ...[
                    Text(l10n.nutritionVideos, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: item.videos.length,
                      itemBuilder: (context, i) {
                        final video = item.videos[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            leading: const Icon(Icons.play_circle_outline, size: 28),
                            title: Text(
                              video.title?.isNotEmpty == true ? video.title! : l10n.nutritionVideoNumber(i + 1),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              video.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            onTap: () => openExternalUrl(context, video.url),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String unit;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    final display = NumberFormat('0.#', Localizations.localeOf(context).toString()).format(value);
    return MergeSemantics(
      child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            '$display$unit',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
        ],
      ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetaChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
