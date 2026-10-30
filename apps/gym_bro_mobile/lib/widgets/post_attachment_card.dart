import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../models/food_log.dart';
import '../models/link_access.dart';
import '../models/meal_plan.dart';
import '../models/post.dart';
import '../models/routine.dart';
import '../pages/daily_meal_plan_detail_page.dart';
import '../pages/exercise_detail_page.dart';
import '../pages/food_item_detail_page.dart';
import '../pages/meal_plan_detail_page.dart';
import '../pages/nutrition/food_diary_page.dart';
import '../pages/recipe_detail_page.dart';
import '../pages/routine_detail_page.dart';
import '../pages/session_detail_page.dart';
import '../pages/training_detail_page.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../services/settings_service.dart';
import 'link_access_note.dart';

/// The card of a typed post: what it shares (a logged workout or meal, or a
/// library item), from the snapshot taken when posting. Tapping opens the
/// source where there's a page for it (a workout or meal only for its
/// author). With [access] from the API, a source the viewer can't open (a
/// private plan, or anything deleted) gets a note instead of a dead link.
class PostAttachmentCard extends StatelessWidget {
  const PostAttachmentCard({
    super.key,
    required this.type,
    required this.attachment,
    this.refId,
    this.authorId,
    this.compact = false,
    this.enabled = true,
    this.access,
  });

  final PostType type;
  final PostAttachment attachment;
  final String? refId;

  /// Whether the viewer can open the source (null: not known, e.g. a preview).
  final LinkAccess? access;

  /// Who posted it; their own workouts/meals open for them.
  final String? authorId;

  /// Fewer rows (composer preview).
  final bool compact;

  /// Tapping opens the source.
  final bool enabled;

  bool get _mine => authorId != null && authorId == AuthManager.instance.profile?.id;

  bool get _canOpen => (access == null || access!.canOpen) && switch (type) {
    PostType.generic => false,
    PostType.workout => refId != null && _mine,
    PostType.meal => _mine && attachment.logDate != null,
    _ => refId != null,
  };

  Future<void> _open(BuildContext context) async {
    final nav = Navigator.of(context);
    Future<void> push(Widget page) => nav.push<void>(MaterialPageRoute(builder: (_) => page));
    final id = refId;
    switch (type) {
      case PostType.workout:
        await push(SessionDetailPage(sessionId: id!));
      case PostType.meal:
        await push(FoodDiaryPage(initialDate: attachment.logDate));
      case PostType.exercise:
        final messenger = ScaffoldMessenger.of(context);
        final l10n = context.l10n;
        try {
          final token = await AuthManager.instance.getValidToken();
          final exercise = await ApiService().getExercise(token, id!);
          await push(ExerciseDetailPage(exercise: exercise));
        } catch (_) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.postShareSourceUnavailable)));
        }
      case PostType.training:
        await push(TrainingDetailPage(trainingId: id!));
      case PostType.routine:
        await push(RoutineDetailPage(routineId: id!));
      case PostType.recipe:
        await push(RecipeDetailPage(recipeId: id!));
      case PostType.foodItem:
        await push(FoodItemDetailPage(foodItemId: id!));
      case PostType.dailyMealPlan:
        await push(DailyMealPlanDetailPage(dailyMealPlanId: id!));
      case PostType.mealPlan:
        await push(MealPlanDetailPage(mealPlanId: id!));
      case PostType.generic:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tappable = enabled && _canOpen;
    final title = attachment.title ?? postTypeLabel(context.l10n, type);
    return Semantics(
      button: tappable,
      label: '${postTypeLabel(context.l10n, type)}: $title',
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tappable ? () => _open(context) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context),
                const SizedBox(height: 10),
                ..._body(context),
                if (_accessNote != null) ...[
                  const SizedBox(height: 10),
                  LinkAccessNote(access: _accessNote, dense: true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Deleted sources, and private library items; someone else's workout or
  /// meal is private by design (the snapshot is what they shared), so no note.
  LinkAccess? get _accessNote => switch (access) {
    LinkAccess.unavailable => access,
    LinkAccess.private when type != PostType.workout && type != PostType.meal => access,
    _ => null,
  };

  Widget _header(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final when = _when(context);
    final kind = [
      postTypeLabel(l10n, type),
      if (type == PostType.meal && attachment.slotType != null)
        ?MealSlotType.fromApiValue(attachment.slotType!)?.label(l10n),
      ?when,
    ].join(' · ');
    final image = attachment.imageUrl;
    final title = attachment.title ?? (type == PostType.meal ? null : postTypeLabel(l10n, type));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              image,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _TypeBadge(type: type, size: 56),
            ),
          )
        else
          _TypeBadge(type: type, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kind,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
              ),
              if (title != null)
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              if (attachment.brand != null && type == PostType.foodItem)
                Text(attachment.brand!, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        if (enabled && _canOpen) Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      ],
    );
  }

  /// When a workout/meal happened.
  String? _when(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    if (type == PostType.workout && attachment.startedAt != null) {
      return DateFormat.MMMd(locale).add_Hm().format(attachment.startedAt!);
    }
    if (type == PostType.meal && attachment.logDate != null) {
      return DateFormat.MMMd(locale).format(attachment.logDate!);
    }
    return null;
  }

  List<Widget> _body(BuildContext context) {
    final l10n = context.l10n;
    final a = attachment;
    switch (type) {
      case PostType.workout:
        final settings = SettingsService.instance;
        return [
          _Stats([
            if (a.durationMinutes != null) (Icons.timer_outlined, l10n.postShareMinutes(a.durationMinutes!)),
            if (a.exerciseCount != null) (Icons.fitness_center, l10n.postShareExercises(a.exerciseCount!)),
            if (a.setCount != null) (Icons.repeat, l10n.postShareSets(a.setCount!)),
            if (a.volumeKg != null && a.volumeKg! > 0)
              (Icons.scale_outlined, settings.formatWeight(a.volumeKg!, decimals: 0)),
          ]),
          if (!compact)
            for (final e in a.exercises)
              _Line(
                e.name,
                [
                  l10n.postShareSets(e.sets),
                  if (e.bestWeightKg != null && e.bestReps != null)
                    l10n.postShareBestSet(settings.formatWeight(e.bestWeightKg!), e.bestReps!)
                  else if (e.bestReps != null)
                    l10n.postShareBestReps(e.bestReps!),
                ].join(' · '),
              ),
        ];
      case PostType.meal:
        final items = a.items;
        final shown = compact ? items.take(3).toList() : items;
        final more = a.itemCount - shown.length;
        return [
          for (final i in shown)
            _Line(
              i.name,
              [
                if (i.amount != null) LogUnit.fromApiValue(i.unit).label(l10n, i.amount!),
                if (i.kcal != null) l10n.nutritionKcalValue(i.kcal!.round()),
              ].join(' · '),
            ),
          if (more > 0) _Line(l10n.postShareMoreItems(more), ''),
          if (a.totalKcal != null) ...[
            const SizedBox(height: 6),
            _Macros(kcal: a.totalKcal, protein: a.totalProtein, carb: a.totalCarb, fat: a.totalFat),
          ],
        ];
      case PostType.exercise:
        final muscles = [for (final m in a.primaryMuscles) ?MuscleGroup.fromApiValue(m)?.label(l10n)];
        return [
          if (muscles.isNotEmpty) _Stats([(Icons.accessibility_new, muscles.take(4).join(', '))]),
          if (!compact && a.description != null) _Description(a.description!),
        ];
      case PostType.training:
        return [
          _Stats([
            if (a.exerciseCount != null) (Icons.fitness_center, l10n.postShareExercises(a.exerciseCount!)),
            if (a.setCount != null) (Icons.repeat, l10n.postShareSets(a.setCount!)),
          ]),
          if (!compact && a.description != null) _Description(a.description!),
        ];
      case PostType.routine:
        return [
          _Stats([
            if (a.trainingCount != null) (Icons.fitness_center, l10n.postShareWorkouts(a.trainingCount!)),
            if (a.scheduleType == 'fixed_weeks' && a.numWeeks != null)
              (Icons.date_range, l10n.postShareWeeks(a.numWeeks!))
            else if (a.scheduleType != null)
              (Icons.shuffle, RoutineScheduleType.fromApiValue(a.scheduleType!).label(l10n)),
          ]),
          if (!compact && a.description != null) _Description(a.description!),
        ];
      case PostType.recipe:
        return [
          _Stats([if (a.servings != null) (Icons.restaurant, l10n.postShareServings(a.servings!))]),
          if (a.kcalPerServing != null)
            _Macros(
              kcal: a.kcalPerServing,
              protein: a.proteinPerServing,
              carb: a.carbPerServing,
              fat: a.fatPerServing,
              note: l10n.postSharePerServing,
            ),
          if (!compact && a.description != null) _Description(a.description!),
        ];
      case PostType.foodItem:
        return [
          if (a.kcalPer100 != null)
            _Macros(
              kcal: a.kcalPer100,
              protein: a.proteinPer100,
              carb: a.carbPer100,
              fat: a.fatPer100,
              note: l10n.postSharePer100(a.servingUnit ?? 'g'),
            ),
        ];
      case PostType.dailyMealPlan:
        return [
          if (a.kcalTotal != null)
            _Macros(
              kcal: a.kcalTotal,
              protein: a.proteinTotal,
              carb: a.carbTotal,
              fat: a.fatTotal,
              note: l10n.postSharePerDay,
            ),
          if (!compact && a.description != null) _Description(a.description!),
        ];
      case PostType.mealPlan:
        return [
          _Stats([
            if (a.numWeeks != null) (Icons.date_range, l10n.postShareWeeks(a.numWeeks!)),
            if (a.daysPlanned != null) (Icons.event_available_outlined, l10n.postShareDaysPlanned(a.daysPlanned!)),
          ]),
          if (!compact && a.description != null) _Description(a.description!),
        ];
      case PostType.generic:
        return const [];
    }
  }
}

/// "Workout", "Meal", "Workout program", … for [type].
String postTypeLabel(AppLocalizations l10n, PostType type) => switch (type) {
  PostType.generic => l10n.postShareTypeGeneric,
  PostType.workout => l10n.postShareTypeWorkout,
  PostType.meal => l10n.postShareTypeMeal,
  PostType.exercise => l10n.postShareTypeExercise,
  PostType.training => l10n.postShareTypeTraining,
  PostType.routine => l10n.postShareTypeRoutine,
  PostType.recipe => l10n.postShareTypeRecipe,
  PostType.foodItem => l10n.postShareTypeFoodItem,
  PostType.dailyMealPlan => l10n.postShareTypeDailyMealPlan,
  PostType.mealPlan => l10n.postShareTypeMealPlan,
};

IconData postTypeIcon(PostType type) => switch (type) {
  PostType.generic => Icons.article_outlined,
  PostType.workout => Icons.fitness_center,
  PostType.meal => Icons.restaurant,
  PostType.exercise => Icons.sports_gymnastics,
  PostType.training => Icons.list_alt,
  PostType.routine => Icons.calendar_month_outlined,
  PostType.recipe => Icons.menu_book_outlined,
  PostType.foodItem => Icons.egg_alt_outlined,
  PostType.dailyMealPlan => Icons.today_outlined,
  PostType.mealPlan => Icons.event_note_outlined,
};

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, required this.size});

  final PostType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(size / 4)),
      child: Icon(postTypeIcon(type), color: cs.onPrimaryContainer, size: size * 0.5),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats(this.items);

  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final (icon, text) in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(text, style: style),
              ],
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.title, this.trailing);

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodyMedium),
          ),
          if (trailing.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(trailing, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      text,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

/// "520 kcal · P 30g · C 60g · F 12g" (+ a note like "per serving").
class _Macros extends StatelessWidget {
  const _Macros({this.kcal, this.protein, this.carb, this.fat, this.note});

  final double? kcal;
  final double? protein;
  final double? carb;
  final double? fat;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 2,
      children: [
        if (kcal != null)
          Text(l10n.nutritionKcalValue(kcal!.round()), style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        Text(
          l10n.nutritionPcfGrams((protein ?? 0).round(), (carb ?? 0).round(), (fat ?? 0).round()),
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (note != null) Text(note!, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}
