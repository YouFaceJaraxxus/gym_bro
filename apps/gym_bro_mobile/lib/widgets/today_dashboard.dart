import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/food_log.dart';
import '../models/gym_class.dart';
import '../models/plan_entry.dart';
import '../models/progress.dart';
import '../models/training.dart';
import '../models/user_profile.dart';
import '../models/water.dart';
import '../pages/classes/class_detail_page.dart';
import '../pages/nutrition/food_diary_page.dart';
import '../pages/plans/plan_entry_sheet.dart';
import '../pages/progress/progress_page.dart';
import '../pages/session_log_page.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../services/health_sync_service.dart';
import '../services/home_widget_service.dart';
import '../services/settings_service.dart';
import '../services/water_service.dart';
import '../theme.dart';
import '../utils/device_timezone.dart';
import 'health_today_card.dart';
import 'home_streak_card.dart';
import 'sparkline.dart';
import 'training_picker_sheet.dart';
import 'water_widgets.dart';

/// The top of Home: a picture of the user's day. Greeting, streak, today's
/// training with a Start button, water and calorie rings, weight trend and
/// the next booked class. Every piece loads in parallel and hides when it
/// can't load; [TodayDashboardState.refresh] reloads them all.
class TodayDashboard extends StatefulWidget {
  const TodayDashboard({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<TodayDashboard> createState() => TodayDashboardState();
}

class TodayDashboardState extends State<TodayDashboard> {
  final _api = ApiService();
  final _streak = GlobalKey<HomeStreakCardState>();

  // Null while loading the first time; `_failed` hides a card.
  List<PlanEntry>? _workouts;
  FoodLogSummary? _food;
  List<BodyMeasurement>? _weights;
  GymClass? _nextClass;
  bool _classesLoaded = false;
  final Set<String> _failed = {};
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    streakChanges.addListener(_onWorkoutChange);
    _load();
  }

  @override
  void dispose() {
    streakChanges.removeListener(_onWorkoutChange);
    super.dispose();
  }

  /// A finished or deleted workout: today's plan and the water goal moved.
  void _onWorkoutChange() {
    _loadTraining();
    WaterService.instance.refresh().then((_) {}, onError: (Object _) {});
  }

  /// Reloads every card (pull to refresh).
  Future<void> refresh() => _load(withStreak: true);

  Future<void> _load({bool withStreak = false}) async {
    await Future.wait([
      _loadTraining(),
      _loadWater(),
      _loadFood(),
      _loadWeight(),
      _loadNextClass(),
      if (withStreak && _streak.currentState != null) _streak.currentState!.refresh(),
      if (withStreak) HealthSyncService.instance.refreshToday(force: true),
    ]);
  }

  /// Runs [load]; on failure marks [card] failed (hidden) instead of throwing.
  Future<void> _soft(String card, Future<void> Function() load) async {
    try {
      await load();
      if (mounted && _failed.contains(card)) setState(() => _failed.remove(card));
    } catch (e) {
      debugPrint('Today: $card failed: $e');
      if (mounted) setState(() => _failed.add(card));
    }
  }

  Future<void> _loadTraining() => _soft('training', () async {
        final token = await AuthManager.instance.getValidToken();
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final entries = await _api.getPlanEntries(
          token,
          from: start,
          to: DateTime(now.year, now.month, now.day + 1),
          timezone: await deviceTimezone(),
        );
        final workouts = entries.where((e) => e.isWorkout).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        HomeWidgetService.instance.setTodayWorkouts(workouts);
        if (mounted) setState(() => _workouts = workouts);
      });

  Future<void> _loadWater() => _soft('water', () => WaterService.instance.refresh());

  Future<void> _loadFood() => _soft('food', () async {
        final token = await AuthManager.instance.getValidToken();
        final summary = await _api.getFoodLogSummary(token, DateTime.now());
        if (mounted) setState(() => _food = summary);
      });

  Future<void> _loadWeight() => _soft('weight', () async {
        final token = await AuthManager.instance.getValidToken();
        final list = await _api.getBodyMeasurements(
          token,
          from: DateTime.now().subtract(const Duration(days: 90)),
        );
        if (mounted) setState(() => _weights = list.where((m) => m.weightKg != null).toList());
      });

  Future<void> _loadNextClass() => _soft('class', () async {
        final token = await AuthManager.instance.getValidToken();
        final now = DateTime.now();
        final classes = await _api.getClasses(token, mine: true, from: now, to: now.add(const Duration(days: 14)));
        final upcoming = classes
            .where((c) =>
                c.cancelledAt == null &&
                c.startsAt.isAfter(now) &&
                (c.myBookingStatus == BookingStatus.booked || c.myBookingStatus == BookingStatus.waitlisted))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        if (mounted) {
          setState(() {
            _nextClass = upcoming.firstOrNull;
            _classesLoaded = true;
          });
        }
      });

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  /// Opens the live logger: for [entry]'s training, or (without one) after
  /// picking what to follow, like Sessions' "New session".
  Future<void> _startWorkout(PlanEntry? entry) async {
    if (_starting) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    String? trainingId = entry?.trainingId;
    if (trainingId == null) {
      final pick = await showTrainingPicker(context, title: l10n.trainingSessionsNew, noneLabel: l10n.trainingSessionFree);
      if (pick == null || !mounted) return;
      trainingId = pick.training?.id;
    }
    Training? training;
    if (trainingId != null) {
      setState(() => _starting = true);
      try {
        final token = await AuthManager.instance.getValidToken();
        training = await _api.getTraining(token, trainingId);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.todayStartFailed(e.toString().replaceFirst('Exception: ', '')))),
        );
        return;
      } finally {
        if (mounted) setState(() => _starting = false);
      }
    }
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SessionLogPage(training: training, planEntryId: entry?.id)));
    if (mounted) _onWorkoutChange();
  }

  Future<void> _openEntry(PlanEntry entry) async {
    final changed = await showPlanEntrySheet(context, entry);
    if (changed && mounted) _onWorkoutChange();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _Greeting(name: widget.profile.name),
      HomeStreakCard(key: _streak),
      if (!_failed.contains('training'))
        _workouts == null
            ? const _Placeholder(height: 148)
            : _TrainingCard(
                workouts: _workouts!,
                starting: _starting,
                onStart: _startWorkout,
                onOpen: _openEntry,
              ),
      if (!(_failed.contains('water') && _failed.contains('food')))
        ValueListenableBuilder<WaterDay?>(
          valueListenable: WaterService.instance.today,
          builder: (context, water, _) => _RingsRow(
            water: _failed.contains('water') ? null : water,
            waterLoading: water == null && !_failed.contains('water'),
            food: _failed.contains('food') ? null : _food,
            foodLoading: _food == null && !_failed.contains('food'),
            onOpenDiary: () async {
              await _open(const FoodDiaryPage());
              _loadFood();
            },
          ),
        ),
      // Steps and sleep (hides itself unless Health is connected).
      const HealthTodayCard(),
      if (!_failed.contains('weight') && (_weights?.isNotEmpty ?? false))
        _WeightCard(
          weights: _weights!,
          onTap: () async {
            await _open(const ProgressPage());
            _loadWeight();
          },
        ),
      if (!_failed.contains('class') && _classesLoaded && _nextClass != null)
        _NextClassCard(
          gymClass: _nextClass!,
          onTap: () async {
            await _open(ClassDetailPage(classId: _nextClass!.id));
            _loadNextClass();
          },
        ),
    ];
    final calm = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, card) in cards.indexed)
          calm
              ? card
              : card
                  .animate(key: ValueKey(card.runtimeType))
                  .fadeIn(delay: (60 * i).ms, duration: 380.ms, curve: Curves.easeOut)
                  .slideY(begin: 0.08, end: 0, delay: (60 * i).ms, duration: 380.ms, curve: Curves.easeOutCubic),
      ],
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────────

/// "Good morning, Liam" and today's date.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final first = name.trim().split(RegExp(r'\s+')).first;
    final greeting = now.hour < 12
        ? l10n.todayGreetingMorning(first)
        : now.hour < 18
        ? l10n.todayGreetingAfternoon(first)
        : l10n.todayGreetingEvening(first);
    final date = DateFormat.MMMMEEEEd(Localizations.localeOf(context).toString()).format(now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date.toUpperCase(),
            style: text.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w700, letterSpacing: 1.1),
          ),
          const SizedBox(height: 4),
          Semantics(
            header: true,
            child: Text(greeting, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.15)),
          ),
        ],
      ),
    );
  }
}

/// A card-shaped space while a card loads the first time.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

/// A rounded tonal card like the rest of Home.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.child, this.onTap, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title, required this.color, this.chevron = false});

  final IconData icon;
  final String title;
  final Color color;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (chevron) Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
      ],
    );
  }
}

// ── Training ────────────────────────────────────────────────────────────────

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({
    required this.workouts,
    required this.starting,
    required this.onStart,
    required this.onOpen,
  });

  final List<PlanEntry> workouts;
  final bool starting;
  final void Function(PlanEntry? entry) onStart;
  final void Function(PlanEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final next = workouts.where((e) => e.status == PlanEntryStatus.planned).firstOrNull;
    final allDone = workouts.isNotEmpty && next == null;

    final Widget body;
    if (workouts.isEmpty) {
      body = _Prompt(
        icon: Icons.self_improvement,
        color: cs.secondary,
        title: l10n.todayFreeDay,
        message: l10n.todayFreeDayHint,
      );
    } else {
      body = Column(
        children: [
          for (final e in workouts) _WorkoutRow(entry: e, onTap: () => onOpen(e)),
          if (allDone) ...[
            const SizedBox(height: 8),
            _Prompt(
              icon: Icons.verified,
              color: context.appColors.success,
              title: l10n.todayAllDone,
              message: l10n.todayAllDoneHint,
            ),
          ],
        ],
      );
    }

    final busy = starting
        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : null;
    final Widget button = next != null
        ? FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), textStyle: text.titleSmall),
            onPressed: starting ? null : () => onStart(next),
            icon: busy ?? const Icon(Icons.play_arrow_rounded, size: 26),
            label: Text(l10n.todayStartWorkout),
          )
        : FilledButton.tonalIcon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: starting ? null : () => onStart(null),
            icon: busy ?? const Icon(Icons.play_arrow_rounded),
            label: Text(allDone ? l10n.todayStartAnother : l10n.todayStartAnyway),
          );

    return _TodayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(icon: Icons.fitness_center, title: l10n.todayTraining, color: cs.primary),
          const SizedBox(height: 10),
          body,
          const SizedBox(height: 14),
          button,
        ],
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.icon, required this.color, required this.title, required this.message});

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium),
              Text(message, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.entry, required this.onTap});

  final PlanEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final time = DateFormat.Hm(Localizations.localeOf(context).toString()).format(entry.startsAt);
    final done = entry.status == PlanEntryStatus.done;
    final skipped = entry.status == PlanEntryStatus.skipped;
    final success = context.appColors.success;
    final name = entry.trainingName ?? entry.routineName ?? l10n.todayWorkoutFallback;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: done ? success.withValues(alpha: 0.15) : cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  done ? Icons.check_rounded : skipped ? Icons.redo_rounded : Icons.fitness_center,
                  size: 20,
                  color: done ? success : cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        decoration: skipped ? TextDecoration.lineThrough : null,
                        color: skipped ? cs.onSurfaceVariant : null,
                      ),
                    ),
                    Text(
                      [
                        l10n.todayWorkoutWhen(time, entry.durationMinutes),
                        if (entry.routineName != null && entry.routineName != name) entry.routineName!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (done || skipped)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    done ? l10n.todayEntryDone : l10n.todayEntrySkipped,
                    style: text.labelMedium?.copyWith(
                      color: done ? success : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rings ───────────────────────────────────────────────────────────────────

class _RingsRow extends StatelessWidget {
  const _RingsRow({
    required this.water,
    required this.waterLoading,
    required this.food,
    required this.foodLoading,
    required this.onOpenDiary,
  });

  final WaterDay? water;
  final bool waterLoading;
  final FoodLogSummary? food;
  final bool foodLoading;
  final VoidCallback onOpenDiary;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (water != null)
        _WaterTile(day: water!)
      else if (waterLoading)
        const _Placeholder(height: 196),
      if (food != null)
        _FoodTile(summary: food!, onTap: onOpenDiary)
      else if (foodLoading)
        const _Placeholder(height: 196),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, t) in tiles.indexed) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: t),
          ],
        ],
      ),
    );
  }
}

class _WaterTile extends StatelessWidget {
  const _WaterTile({required this.day});

  final WaterDay day;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final water = WaterColors.of(context);
    final cups = SettingsService.instance.settings.value.waterCups;
    final cup = cups.isEmpty ? 250 : cups.first;
    return _TodayCard(
      onTap: () => openWaterPage(context),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        children: [
          _CardTitle(icon: Icons.water_drop, title: l10n.waterTitle, color: water.water, chevron: true),
          const SizedBox(height: 12),
          WaterRing(day: day, size: 92),
          const SizedBox(height: 10),
          Text(
            l10n.waterProgress(waterAmount(l10n, day.totalMl), waterAmount(l10n, day.goalMl)),
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                backgroundColor: water.container,
                foregroundColor: water.onContainer,
              ),
              onPressed: () => logWater(context, cup),
              icon: const Icon(Icons.add, size: 18),
              label: Text(waterAmount(l10n, cup), semanticsLabel: l10n.waterAddCup(waterAmount(l10n, cup))),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.summary, required this.onTap});

  final FoodLogSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = summary.totals;
    final target = summary.targets;
    final kcalTarget = target != null && target.kcal > 0 ? target.kcal : null;
    final over = kcalTarget != null && t.kcal > kcalTarget;
    final ringColor = over ? cs.error : cs.tertiary;
    return _TodayCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        children: [
          _CardTitle(icon: Icons.local_fire_department, title: l10n.todayCalories, color: cs.tertiary, chevron: true),
          const SizedBox(height: 12),
          Semantics(
            label: kcalTarget == null
                ? l10n.todayKcalSemantics(t.kcal.round())
                : l10n.todayKcalTargetSemantics(t.kcal.round(), kcalTarget.round()),
            hint: l10n.todayOpenDiary,
            excludeSemantics: true,
            child: ProgressRing(
              fraction: kcalTarget == null ? (t.kcal > 0 ? 1 : 0) : progressFraction(t.kcal, kcalTarget),
              color: kcalTarget == null ? cs.tertiary.withValues(alpha: 0.5) : ringColor,
              size: 92,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    NumberFormat.decimalPattern(Localizations.localeOf(context).toString()).format(t.kcal.round()),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text('kcal', style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            kcalTarget == null ? l10n.todayKcalLogged : l10n.todayKcalOf(kcalTarget.round()),
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: Row(
              children: [
                _Macro(label: l10n.todayProteinShort, value: t.protein, target: target?.protein, color: cs.primary),
                const SizedBox(width: 6),
                _Macro(label: l10n.todayCarbShort, value: t.carb, target: target?.carb, color: cs.secondary),
                const SizedBox(width: 6),
                _Macro(label: l10n.todayFatShort, value: t.fat, target: target?.fat, color: cs.tertiary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value, required this.target, required this.color});

  final String label;
  final double value;
  final double? target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hasTarget = target != null && target! > 0;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ${value.round()}g',
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: hasTarget ? progressFraction(value, target) : (value > 0 ? 1 : 0),
              color: hasTarget ? color : color.withValues(alpha: 0.45),
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weight ──────────────────────────────────────────────────────────────────

class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.weights, required this.onTap});

  /// Oldest first, all with a weight.
  final List<BodyMeasurement> weights;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final settings = SettingsService.instance;
    final latest = weights.last;
    final since = DateTime.now().subtract(const Duration(days: 30));
    final recent = weights.where((m) => !m.measuredOn.isBefore(DateTime(since.year, since.month, since.day))).toList();
    final series = recent.length >= 2 ? recent : weights;
    final change = series.length >= 2 ? series.last.weightKg! - series.first.weightKg! : null;
    final String trend;
    if (change == null) {
      trend = l10n.todayWeightOne;
    } else if (change.abs() < 0.05) {
      trend = l10n.todayWeightSteady;
    } else {
      trend = l10n.todayWeightChange('${change > 0 ? '+' : '−'}${settings.formatWeight(change.abs())}');
    }
    return _TodayCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.monitor_weight_outlined, color: cs.onSecondaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.todayWeight, style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                Text(
                  settings.formatWeight(latest.weightKg!),
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(trend, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Sparkline(
            values: [for (final m in series) settings.toDisplayWeight(m.weightKg!)],
            width: 112,
            height: 44,
            color: cs.secondary,
            semanticLabel: l10n.todayWeightTrend,
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

// ── Next class ──────────────────────────────────────────────────────────────

class _NextClassCard extends StatelessWidget {
  const _NextClassCard({required this.gymClass, required this.onTap});

  final GymClass gymClass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final c = gymClass;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(c.startsAt.year, c.startsAt.month, c.startsAt.day);
    final dayLabel = switch (day.difference(today).inDays) {
      0 => l10n.commonToday,
      1 => l10n.todayTomorrow,
      _ => DateFormat.MMMEd(locale).format(c.startsAt),
    };
    final when = '$dayLabel · ${DateFormat.Hm(locale).format(c.startsAt)}';
    return _TodayCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 52,
            decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(14)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat.MMM(locale).format(c.startsAt).toUpperCase(),
                  style: text.labelSmall?.copyWith(color: cs.onTertiaryContainer, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${c.startsAt.day}',
                  style: text.titleLarge?.copyWith(color: cs.onTertiaryContainer, fontWeight: FontWeight.w800, height: 1.1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.todayNextClass, style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                Text(
                  [
                    when,
                    c.gymName,
                    if (c.trainerName != null && c.trainerName!.isNotEmpty) l10n.todayClassWith(c.trainerName!),
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (c.myBookingStatus == BookingStatus.waitlisted)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Chip(
                label: Text(l10n.todayWaitlisted),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}
