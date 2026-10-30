import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/draft.dart';
import '../models/exercise.dart';
import '../models/food_log.dart';
import '../models/meal_plan.dart';
import '../models/post.dart';
import '../models/routine.dart';
import '../models/training.dart';
import '../models/training_session.dart';
import '../pages/feed/create_post_page.dart';
import 'drafts.dart';

// "Share as post": opens the composer with a workout, meal or library item
// attached (see [CreatePostPage.share]). A workout or meal can only be shared
// once it has happened; before that the action explains why it's off.

/// A logged workout to share, previewed from what's known locally.
ShareTarget workoutShareTarget(TrainingSession s) {
  final ended = s.endedAt;
  return ShareTarget.workout(
    s.id,
    startedAt: s.startedAt,
    preview: PostAttachment({
      'title': s.trainingName,
      'started_at': s.startedAt.toUtc().toIso8601String(),
      'ended_at': ?ended?.toUtc().toIso8601String(),
      if (ended != null) 'duration_minutes': ended.difference(s.startedAt).inMinutes,
      if (s.setLogs.isNotEmpty) ...{
        'set_count': s.setLogs.length,
        'exercise_count': s.setLogs.map((l) => l.exerciseId).whereType<String>().toSet().length,
      },
    }),
  );
}

/// The food logged on [date] in [slot] to share, previewed from [logs].
ShareTarget mealShareTarget(DateTime date, MealSlotType slot, List<FoodLog> logs) {
  final total = logs.fold(MacroTotals.zero, (t, l) => t + l.macros);
  return ShareTarget.meal(
    date,
    slot.apiValue,
    preview: PostAttachment({
      'log_date': apiDate(date),
      'slot_type': slot.apiValue,
      'items': [
        for (final l in logs) {'name': l.name, 'amount': l.amount, 'unit': l.unit.name, 'kcal': l.macros.kcal},
      ],
      'item_count': logs.length,
      'totals': {'kcal': total.kcal, 'protein': total.protein, 'carb': total.carb, 'fat': total.fat, 'fiber': total.fiber},
    }),
  );
}

// Library items, previewed from the loaded detail.

ShareTarget exerciseShareTarget(Exercise e) => ShareTarget.item(
  PostType.exercise,
  e.id,
  preview: PostAttachment({
    'title': e.name,
    'description': e.description,
    'image_url': e.imageUrl,
    'primary_muscles': [for (final m in e.primaryMuscles) m.apiValue],
  }),
);

ShareTarget trainingShareTarget(Training t) => ShareTarget.item(
  PostType.training,
  t.id,
  preview: PostAttachment({
    'title': t.name,
    'description': t.description,
    'image_url': (t.thumbnail ?? t.images.firstOrNull)?.url,
    'exercise_count': t.sets.expand((s) => s.exercises).map((e) => e.exerciseId).toSet().length,
    'set_count': t.sets.length,
  }),
);

ShareTarget routineShareTarget(Routine r) => ShareTarget.item(
  PostType.routine,
  r.id,
  preview: PostAttachment({
    'title': r.name,
    'description': r.description,
    'image_url': (r.thumbnail ?? r.images.firstOrNull)?.url,
    'schedule_type': r.scheduleType.apiValue,
    'num_weeks': r.numWeeks,
    'training_count': r.trainings.length,
  }),
);

ShareTarget recipeShareTarget(Recipe r) => ShareTarget.item(
  PostType.recipe,
  r.id,
  preview: PostAttachment({
    'title': r.name,
    'description': r.description,
    'image_url': (r.images.where((i) => i.isThumbnail).firstOrNull ?? r.images.firstOrNull)?.url,
    'servings': r.servings,
    'kcal_per_serving': r.kcalPerServing,
    'protein_per_serving': r.proteinPerServing,
    'carb_per_serving': r.carbPerServing,
    'fat_per_serving': r.fatPerServing,
  }),
);

ShareTarget foodItemShareTarget(FoodItem f) => ShareTarget.item(
  PostType.foodItem,
  f.id,
  preview: PostAttachment({
    'title': f.name,
    'brand': f.brand,
    'serving_unit': f.servingUnit.apiValue,
    'kcal_per_100': f.kcalPer100,
    'protein_per_100': f.proteinPer100,
    'carb_per_100': f.carbPer100,
    'fat_per_100': f.fatPer100,
  }),
);

ShareTarget dailyMealPlanShareTarget(DailyMealPlan d) => ShareTarget.item(
  PostType.dailyMealPlan,
  d.id,
  preview: PostAttachment({
    'title': d.name,
    'description': d.description,
    'kcal_total': d.kcalTotal,
    'protein_total': d.proteinTotal,
    'carb_total': d.carbTotal,
    'fat_total': d.fatTotal,
  }),
);

ShareTarget mealPlanShareTarget(MealPlan m) => ShareTarget.item(
  PostType.mealPlan,
  m.id,
  preview: PostAttachment({
    'title': m.name,
    'description': m.description,
    'image_url': (m.images.where((i) => i.isThumbnail).firstOrNull ?? m.images.firstOrNull)?.url,
    'num_weeks': m.numWeeks,
    'days_planned': m.days.length,
  }),
);

/// Opens the composer sharing [target] and returns the post once shared
/// (null when cancelled, or right away for something in the future).
Future<Post?> sharePost(BuildContext context, ShareTarget target) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (target.isFuture()) {
    messenger?.showSnackBar(SnackBar(content: Text(l10n.postShareFutureBlocked)));
    return null;
  }
  final created = await openCreateWithDrafts<Post>(
    context,
    kind: DraftKind.post,
    fullscreenDialog: true,
    builder: (draft) => CreatePostPage(draft: draft, share: target),
  );
  if (created != null) messenger?.showSnackBar(SnackBar(content: Text(l10n.postSharePosted)));
  return created;
}

/// After logging something: "[message]" with a "Share" action (left out
/// for something in the future). Uses [navigator]'s context, so it works
/// after the logging screen has closed.
void showLoggedWithShare(
  ScaffoldMessengerState messenger,
  NavigatorState navigator, {
  required String message,
  required ShareTarget target,
}) {
  final l10n = navigator.context.l10n;
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    action: target.isFuture()
        ? null
        : SnackBarAction(
            label: l10n.postShareShareAction,
            onPressed: () {
              if (navigator.mounted) sharePost(navigator.context, target);
            },
          ),
  ));
}

/// App bar action: share [target] as a post. Greyed out (tapping explains
/// why) while it's in the future.
class SharePostButton extends StatelessWidget {
  const SharePostButton({super.key, required this.target});

  final ShareTarget target;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final future = target.isFuture();
    return IconButton(
      tooltip: future ? l10n.postShareFutureBlocked : l10n.postShareAction,
      icon: Icon(Icons.ios_share, color: future ? Theme.of(context).disabledColor : null),
      onPressed: () => sharePost(context, target),
    );
  }
}
