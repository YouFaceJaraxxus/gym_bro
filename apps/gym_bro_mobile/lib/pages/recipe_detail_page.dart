import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'recipe_form_page.dart';

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
        title: const Text('Delete recipe?'),
        content: Text('Remove "${_recipe!.name}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _recipe == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error ?? 'Unknown error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }

    final item = _recipe!;
    final profile = AuthManager.instance.profile;
    final isOwner = profile != null && profile.id == item.authorId;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          if (isOwner) ...[
            IconButton(
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
                        const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
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
                        label: '${item.servings} ${item.servings == 1 ? 'serving' : 'servings'}',
                      ),
                      if (item.timeLabel.isNotEmpty)
                        _MetaChip(icon: Icons.timer_outlined, label: item.timeLabel),
                      _MetaChip(
                        icon: item.isPublic ? Icons.public : Icons.lock_outline,
                        label: item.isPublic ? 'Public' : 'Private',
                        color: item.isPublic ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Macro strip ────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: _MacroChip(label: 'Kcal', value: item.kcalPerServing, color: Colors.orange.shade600)),
                      const SizedBox(width: 6),
                      Expanded(child: _MacroChip(label: 'Protein', value: item.proteinPerServing, color: Colors.blue.shade600, unit: 'g')),
                      const SizedBox(width: 6),
                      Expanded(child: _MacroChip(label: 'Carbs', value: item.carbPerServing, color: Colors.amber.shade700, unit: 'g')),
                      const SizedBox(width: 6),
                      Expanded(child: _MacroChip(label: 'Fat', value: item.fatPerServing, color: Colors.red.shade400, unit: 'g')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text('per serving', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                  const SizedBox(height: 20),

                  // ── Description ────────────────────────────────────────────
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    Text(item.description!, style: const TextStyle(fontSize: 15, height: 1.5)),
                    const SizedBox(height: 20),
                  ],

                  // ── Ingredients ────────────────────────────────────────────
                  if (item.ingredients.isNotEmpty) ...[
                    const Text('Ingredients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: item.ingredients.length,
                      separatorBuilder: (_, i) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final ing = item.ingredients[i];
                        return Padding(
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
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                ing.quantityLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Steps ──────────────────────────────────────────────────
                  if (item.steps.isNotEmpty) ...[
                    const Text('Steps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    const Text('Videos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                              video.title?.isNotEmpty == true ? video.title! : 'Video ${i + 1}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              video.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            onTap: () {/* open URL */},
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
    final display = value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return Container(
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
    final c = color ?? Colors.grey.shade700;
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
