import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/user_settings.dart';
import '../../theme.dart';
import '../../widgets/streak_widgets.dart';

// Building blocks of the first-run flow (see onboarding_page.dart).

// ── Goals ─────────────────────────────────────────────────────────────────────

String goalLabel(AppLocalizations l10n, FitnessGoal g) => switch (g) {
  FitnessGoal.loseFat => l10n.onboardingGoalLoseFat,
  FitnessGoal.buildMuscle => l10n.onboardingGoalBuildMuscle,
  FitnessGoal.getStronger => l10n.onboardingGoalGetStronger,
  FitnessGoal.stayFit => l10n.onboardingGoalStayFit,
  FitnessGoal.endurance => l10n.onboardingGoalEndurance,
};

String goalHint(AppLocalizations l10n, FitnessGoal g) => switch (g) {
  FitnessGoal.loseFat => l10n.onboardingGoalLoseFatHint,
  FitnessGoal.buildMuscle => l10n.onboardingGoalBuildMuscleHint,
  FitnessGoal.getStronger => l10n.onboardingGoalGetStrongerHint,
  FitnessGoal.stayFit => l10n.onboardingGoalStayFitHint,
  FitnessGoal.endurance => l10n.onboardingGoalEnduranceHint,
};

IconData goalIcon(FitnessGoal g) => switch (g) {
  FitnessGoal.loseFat => Icons.local_fire_department_rounded,
  FitnessGoal.buildMuscle => Icons.fitness_center_rounded,
  FitnessGoal.getStronger => Icons.bolt_rounded,
  FitnessGoal.stayFit => Icons.favorite_rounded,
  FitnessGoal.endurance => Icons.directions_run_rounded,
};

/// Each goal gets its own accent so the cards read at a glance.
Color goalColor(BuildContext context, FitnessGoal g) {
  final cs = Theme.of(context).colorScheme;
  final app = context.appColors;
  return switch (g) {
    FitnessGoal.loseFat => cs.tertiary,
    FitnessGoal.buildMuscle => cs.primary,
    FitnessGoal.getStronger => app.warning,
    FitnessGoal.stayFit => app.success,
    FitnessGoal.endurance => waterColor(context),
  };
}

/// A water blue that stays legible in both themes.
Color waterColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF7CC4FA) : const Color(0xFF1976D2);

/// A number format in the app language (e.g. "2,75" in Serbian), without grouping.
NumberFormat onboardingNumberFormat(BuildContext context, {int maxDecimals = 1}) {
  final l = Localizations.localeOf(context);
  final tag = Intl.canonicalizedLocale(l.toString());
  final locale = NumberFormat.localeExists(tag)
      ? tag
      : (NumberFormat.localeExists(l.languageCode) ? l.languageCode : 'en');
  return NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = maxDecimals
    ..turnOffGrouping();
}

// ── Progress ──────────────────────────────────────────────────────────────────

/// One pill per step; the ones done and the current one are filled.
class OnboardingProgress extends StatelessWidget {
  final int current;
  final int total;

  const OnboardingProgress({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final calm = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: context.l10n.onboardingProgress(current + 1, total),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < total; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: calm ? Duration.zero : const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  height: 6,
                  margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i < current
                        ? cs.primary
                        : i == current
                            ? cs.primary.withValues(alpha: 0.55)
                            : cs.surfaceContainerHighest,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Welcome hero ──────────────────────────────────────────────────────────────

/// A dumbbell in a glowing disc, with the streak flame popping in beside it.
class WelcomeHero extends StatelessWidget {
  const WelcomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final calm = MediaQuery.disableAnimationsOf(context);

    Widget glow = Container(
      width: 230,
      height: 230,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [cs.primary.withValues(alpha: 0.28), cs.primary.withValues(alpha: 0)],
        ),
      ),
    );
    Widget disc = Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primaryContainer, cs.tertiaryContainer],
        ),
        boxShadow: [
          BoxShadow(color: cs.primary.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 12)),
        ],
      ),
    );
    Widget dumbbell = Icon(Icons.fitness_center_rounded, size: 76, color: cs.onPrimaryContainer);
    Widget flame = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: const Center(child: StreakFlame(size: 38)),
    );
    Widget spark(double size) => Icon(Icons.auto_awesome_rounded, size: size, color: cs.tertiary);
    Widget sparkA = spark(22);
    Widget sparkB = spark(16);

    if (!calm) {
      glow = glow
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(0.88, 0.88), end: const Offset(1.06, 1.06), duration: 1800.ms, curve: Curves.easeInOut);
      disc = disc
          .animate()
          .scale(begin: const Offset(0.4, 0.4), duration: 700.ms, curve: Curves.elasticOut)
          .fadeIn(duration: 250.ms);
      dumbbell = dumbbell
          .animate()
          .rotate(begin: -0.12, end: 0, delay: 150.ms, duration: 700.ms, curve: Curves.elasticOut)
          .fadeIn(delay: 150.ms, duration: 250.ms)
          .then(delay: 400.ms)
          .shake(hz: 3, rotation: 0.06, duration: 500.ms);
      flame = flame
          .animate(delay: 550.ms)
          .scale(begin: const Offset(0, 0), duration: 600.ms, curve: Curves.elasticOut)
          // A slow flicker once it's in.
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 900.ms, curve: Curves.easeInOut);
      sparkA = sparkA
          .animate(delay: 800.ms, onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 700.ms)
          .scale(begin: const Offset(0.6, 0.6), duration: 700.ms);
      sparkB = sparkB
          .animate(delay: 1100.ms, onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 800.ms)
          .scale(begin: const Offset(0.5, 0.5), duration: 800.ms);
    }

    return ExcludeSemantics(
      child: SizedBox(
        width: 230,
        height: 230,
        child: Stack(
          alignment: Alignment.center,
          children: [
            glow,
            disc,
            dumbbell,
            Positioned(right: 22, top: 26, child: flame),
            Positioned(left: 30, top: 44, child: sparkA),
            Positioned(left: 52, bottom: 30, child: sparkB),
          ],
        ),
      ),
    );
  }
}

/// A feature line on the welcome step: tinted icon + text.
class WelcomeFeature extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const WelcomeFeature({super.key, required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

// ── Choice cards ──────────────────────────────────────────────────────────────

/// A big selectable card: tinted icon, title, one line, and a check when picked.
class ChoiceCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const ChoiceCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = cs.brightness == Brightness.dark;
    final calm = MediaQuery.disableAnimationsOf(context);
    final duration = calm ? Duration.zero : const Duration(milliseconds: 220);
    final radius = BorderRadius.circular(20);
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: selected
              ? cs.primaryContainer.withValues(alpha: isDark ? 0.7 : 0.9)
              : (isDark ? cs.surfaceContainerLow : cs.surfaceContainerLowest),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: isDark ? 1 : 0.7),
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(selected ? 13 : 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: selected ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: text.titleMedium?.copyWith(
                            color: selected ? cs.onPrimaryContainer : cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: text.bodyMedium?.copyWith(
                            color: selected ? cs.onPrimaryContainer.withValues(alpha: 0.8) : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedScale(
                    duration: duration,
                    curve: Curves.easeOutBack,
                    scale: selected ? 1 : 0,
                    child: Icon(Icons.check_circle_rounded, color: cs.primary, size: 26),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Training days ─────────────────────────────────────────────────────────────

/// 1–7 as a row of circles; everything up to the pick is lit.
class DaysSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const DaysSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final calm = MediaQuery.disableAnimationsOf(context);
    final duration = calm ? Duration.zero : const Duration(milliseconds: 220);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = ((constraints.maxWidth - 6 * 8) / 7).clamp(36.0, 52.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 1; i <= 7; i++)
              Semantics(
                selected: i == value,
                button: true,
                inMutuallyExclusiveGroup: true,
                label: l10n.onboardingDaysValue(i),
                child: ExcludeSemantics(
                  child: GestureDetector(
                    onTap: () => onChanged(i),
                    child: AnimatedScale(
                      duration: duration,
                      curve: Curves.easeOutBack,
                      scale: i == value ? 1.12 : 1,
                      child: AnimatedContainer(
                        duration: duration,
                        width: size,
                        height: size,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == value
                              ? cs.primary
                              : i < value
                                  ? cs.primaryContainer
                                  : Colors.transparent,
                          border: Border.all(
                            color: i <= value ? Colors.transparent : cs.outlineVariant,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '$i',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: i == value
                                ? cs.onPrimary
                                : i < value
                                    ? cs.onPrimaryContainer
                                    : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A tinted note with an icon (the streak explainer, the goal-weight hint).
class OnboardingNote extends StatelessWidget {
  final Widget icon;
  final String text;
  final Color? color;

  const OnboardingNote({super.key, required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tint = color ?? cs.tertiary;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

// ── Water ─────────────────────────────────────────────────────────────────────

/// Glasses of 250 ml filling up to the goal.
class WaterGlasses extends StatelessWidget {
  final int ml;

  const WaterGlasses({super.key, required this.ml});

  @override
  Widget build(BuildContext context) {
    final color = waterColor(context);
    final calm = MediaQuery.disableAnimationsOf(context);
    final count = (ml / 250).round().clamp(1, 24);
    return ExcludeSemantics(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedSwitcher(
              duration: calm ? Duration.zero : const Duration(milliseconds: 200),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: Icon(
                Icons.local_drink_rounded,
                key: ValueKey(i),
                size: 26,
                color: color.withValues(alpha: 0.55 + 0.45 * ((i + 1) / count)),
              ),
            ),
        ],
      ),
    );
  }
}
