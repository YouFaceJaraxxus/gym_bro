import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/l10n.dart';
import '../../models/user_settings.dart';
import '../../theme.dart';
import '../../widgets/streak_widgets.dart';
import 'onboarding_widgets.dart';

// The steps of the first-run flow. Each one only shows and edits values;
// OnboardingPage holds them and saves.

const double lbPerKg = 2.2046226218;

/// Title + one line under it, shared by every step.
class _StepHeader extends StatelessWidget {
  final String title;
  final String body;

  const _StepHeader({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(body, style: text.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Fades and slides children in one after another (none with reduce motion).
List<Widget> _stagger(BuildContext context, List<Widget> children) {
  if (MediaQuery.disableAnimationsOf(context)) return children;
  return [
    for (var i = 0; i < children.length; i++)
      children[i]
          .animate(delay: (60 * i).ms)
          .fadeIn(duration: 280.ms)
          .slideY(begin: 0.08, duration: 280.ms, curve: Curves.easeOutCubic),
  ];
}

// ── 1. Welcome ────────────────────────────────────────────────────────────────

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final app = context.appColors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        const Center(child: WelcomeHero()),
        const SizedBox(height: 16),
        ..._stagger(context, [
          Text(
            l10n.onboardingWelcomeTitle,
            textAlign: TextAlign.center,
            style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            child: Text(
              l10n.onboardingWelcomeBody,
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          WelcomeFeature(icon: Icons.fitness_center_rounded, color: cs.primary, text: l10n.onboardingWelcomeTrack),
          WelcomeFeature(icon: Icons.local_fire_department_rounded, color: app.warning, text: l10n.onboardingWelcomeStreak),
          WelcomeFeature(icon: Icons.flag_rounded, color: app.success, text: l10n.onboardingWelcomeGoals),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              l10n.onboardingWelcomeLater,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ]),
      ],
    );
  }
}

// ── 2. Goal ───────────────────────────────────────────────────────────────────

class GoalStep extends StatelessWidget {
  final FitnessGoal? value;
  final ValueChanged<FitnessGoal> onChanged;

  const GoalStep({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _StepHeader(title: l10n.onboardingGoalTitle, body: l10n.onboardingGoalBody),
        ..._stagger(context, [
          for (final g in FitnessGoal.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ChoiceCard(
                icon: goalIcon(g),
                color: goalColor(context, g),
                title: goalLabel(l10n, g),
                subtitle: goalHint(l10n, g),
                selected: value == g,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(g);
                },
              ),
            ),
        ]),
      ],
    );
  }
}

// ── 3. Training days ──────────────────────────────────────────────────────────

class DaysStep extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const DaysStep({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final mood = value <= 2
        ? l10n.onboardingDaysEasy
        : value <= 4
            ? l10n.onboardingDaysSteady
            : l10n.onboardingDaysIntense;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _StepHeader(title: l10n.onboardingDaysTitle, body: l10n.onboardingDaysBody),
        Center(
          child: Text(
            '$value',
            key: const ValueKey('onboarding-days-value'),
            style: text.displayLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Center(child: Text(l10n.onboardingDaysValue(value), style: text.titleMedium)),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 24),
            child: Text(mood, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ),
        ),
        DaysSelector(
          value: value,
          onChanged: (d) {
            HapticFeedback.selectionClick();
            onChanged(d);
          },
        ),
        const SizedBox(height: 28),
        OnboardingNote(
          icon: const StreakFlame(size: 28),
          color: context.appColors.warning,
          text: l10n.onboardingDaysStreak,
        ),
      ],
    );
  }
}

// ── 4. Body ───────────────────────────────────────────────────────────────────

class BodyStep extends StatelessWidget {
  final String unit;
  final ValueChanged<String> onUnitChanged;
  final TextEditingController current;
  final TextEditingController goal;
  final bool goalSuggested;
  final String? currentError;
  final String? goalError;
  final ValueChanged<String> onCurrentChanged;
  final ValueChanged<String> onGoalChanged;

  const BodyStep({
    super.key,
    required this.unit,
    required this.onUnitChanged,
    required this.current,
    required this.goal,
    required this.goalSuggested,
    required this.currentError,
    required this.goalError,
    required this.onCurrentChanged,
    required this.onGoalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    InputDecoration field(String label, String? error) => InputDecoration(
          labelText: label,
          helperText: l10n.onboardingOptional,
          errorText: error,
          suffixText: unit,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        );
    final formatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _StepHeader(title: l10n.onboardingBodyTitle, body: l10n.onboardingBodyBody),
        Text(l10n.onboardingUnits, style: text.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'kg', label: Text('kg')),
            ButtonSegment(value: 'lb', label: Text('lb')),
          ],
          selected: {unit},
          onSelectionChanged: (s) => onUnitChanged(s.first),
        ),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey('onboarding-current-weight'),
          controller: current,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: formatters,
          decoration: field(l10n.onboardingCurrentWeight, currentError),
          onChanged: onCurrentChanged,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('onboarding-goal-weight'),
          controller: goal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: formatters,
          decoration: field(l10n.onboardingGoalWeight, goalError),
          onChanged: onGoalChanged,
        ),
        if (goalSuggested) ...[
          const SizedBox(height: 12),
          OnboardingNote(
            icon: Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.tertiary),
            text: l10n.onboardingGoalWeightSuggested,
          ),
        ],
      ],
    );
  }
}

// ── 5. Water ──────────────────────────────────────────────────────────────────

class WaterStep extends StatelessWidget {
  /// The goal shown (ml): the custom one, or the auto one.
  final int ml;
  final bool auto;
  final bool hasWeight;
  final ValueChanged<int> onChanged;
  final VoidCallback onUseAuto;

  const WaterStep({
    super.key,
    required this.ml,
    required this.auto,
    required this.hasWeight,
    required this.onChanged,
    required this.onUseAuto,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final blue = waterColor(context);
    final liters = onboardingNumberFormat(context, maxDecimals: 2).format(ml / 1000);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _StepHeader(title: l10n.onboardingWaterTitle, body: l10n.onboardingWaterBody),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              tooltip: l10n.onboardingWaterLess,
              onPressed: ml > 500 ? () => onChanged(ml - 250) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 150,
              child: Text(
                l10n.onboardingWaterLiters(liters),
                key: const ValueKey('onboarding-water-value'),
                textAlign: TextAlign.center,
                style: text.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: blue,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 16),
            IconButton.filledTonal(
              tooltip: l10n.onboardingWaterMore,
              onPressed: ml < 8000 ? () => onChanged(ml + 250) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            l10n.onboardingWaterGlasses((ml / 250).round()),
            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 20),
        WaterGlasses(ml: ml),
        const SizedBox(height: 24),
        if (auto)
          OnboardingNote(
            icon: Icon(Icons.water_drop_rounded, color: blue),
            color: blue,
            text: hasWeight ? l10n.onboardingWaterAuto : l10n.onboardingWaterAutoNoWeight,
          )
        else
          Row(
            children: [
              Icon(Icons.tune_rounded, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.onboardingWaterCustom, style: text.bodyMedium)),
              TextButton(onPressed: onUseAuto, child: Text(l10n.onboardingWaterUseAuto)),
            ],
          ),
      ],
    );
  }
}

// ── 6. Done ───────────────────────────────────────────────────────────────────

class SummaryItem {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  const SummaryItem({required this.icon, required this.color, required this.label, required this.value, required this.onTap});
}

class DoneStep extends StatelessWidget {
  final List<SummaryItem> items;

  const DoneStep({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget badge = Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(shape: BoxShape.circle, color: context.appColors.success.withValues(alpha: 0.16)),
      child: Icon(Icons.check_rounded, size: 56, color: context.appColors.success),
    );
    if (!MediaQuery.disableAnimationsOf(context)) {
      badge = badge.animate().scale(begin: const Offset(0.3, 0.3), duration: 650.ms, curve: Curves.elasticOut);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Center(child: ExcludeSemantics(child: badge)),
        const SizedBox(height: 16),
        Text(
          l10n.onboardingDoneTitle,
          textAlign: TextAlign.center,
          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.onboardingDoneBody,
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        ..._stagger(context, [
          for (final item in items)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: item.onTap,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color),
                ),
                title: Text(item.label, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                subtitle: Text(item.value, style: text.titleMedium),
                trailing: Icon(Icons.edit_outlined, size: 20, color: cs.onSurfaceVariant),
              ),
            ),
        ]),
      ],
    );
  }
}
