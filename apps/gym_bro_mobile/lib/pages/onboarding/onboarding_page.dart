import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../models/user_settings.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/settings_service.dart';
import '../../theme.dart';
import 'onboarding_steps.dart';
import 'onboarding_widgets.dart';

/// The first-run flow: welcome, goal, training days, body, water, done.
///
/// Each step's values are saved when moving forward, so leaving half-way
/// keeps them. Finishing or skipping marks the user onboarded (`onboarded`
/// in settings); [OnboardingGate] decides when to show it. Settings → "Redo
/// setup" opens it again prefilled.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

/// A goal weight to start from (kg, to the half): a little lighter to lose
/// fat, a little heavier to build muscle; none for the other goals.
double? suggestGoalWeightKg(FitnessGoal? goal, double currentKg) {
  final factor = switch (goal) {
    FitnessGoal.loseFat => 0.92,
    FitnessGoal.buildMuscle => 1.05,
    _ => null,
  };
  if (factor == null) return null;
  return (currentKg * factor * 2).round() / 2;
}

enum _Step { welcome, goal, days, body, water, done }

class _OnboardingPageState extends State<OnboardingPage> {
  final _api = ApiService();
  final _settings = SettingsService.instance;
  final _confetti = ConfettiController(duration: const Duration(milliseconds: 1400));
  final _current = TextEditingController();
  final _goal = TextEditingController();

  _Step _step = _Step.welcome;
  bool _forward = true;
  bool _busy = false;

  FitnessGoal? _fitnessGoal;
  late int _days;
  late String _unit;
  // What's saved on the server, so a step only writes what changed.
  double? _savedCurrentKg;
  double? _savedGoalKg;
  bool _goalSuggested = false;
  bool _goalTouched = false;
  String? _currentError;
  String? _goalError;
  int? _waterMl; // null: auto

  @override
  void initState() {
    super.initState();
    final s = _settings.settings.value;
    _fitnessGoal = FitnessGoal.fromApi(s.fitnessGoal);
    _days = s.weeklyWorkoutTarget.clamp(1, 7);
    _unit = s.weightUnit;
    _savedGoalKg = s.goalWeightKg;
    _goalTouched = s.goalWeightKg != null;
    _waterMl = s.waterGoalMl;
    _loadLatestWeight();
  }

  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Formatting needs the locale, so not in initState.
    if (_prefilled) return;
    _prefilled = true;
    if (_savedGoalKg != null) _goal.text = _format(_savedGoalKg!);
  }

  @override
  void dispose() {
    _confetti.dispose();
    _current.dispose();
    _goal.dispose();
    super.dispose();
  }

  /// Prefills the current weight when redoing the setup.
  Future<void> _loadLatestWeight() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final all = await _api.getBodyMeasurements(token, from: DateTime.now().subtract(const Duration(days: 365)));
      final latest = all.lastWhere((m) => m.weightKg != null);
      if (!mounted || _current.text.isNotEmpty) return;
      setState(() {
        _savedCurrentKg = latest.weightKg;
        _current.text = _format(latest.weightKg!);
      });
    } catch (_) {
      // Nothing logged yet (or offline): the field stays empty.
    }
  }

  // ── Units ───────────────────────────────────────────────────────────────────

  double _toDisplay(double kg) => _unit == 'lb' ? kg * lbPerKg : kg;
  double _toKg(double v) => _unit == 'lb' ? v / lbPerKg : v;
  String _format(double kg) => onboardingNumberFormat(context, maxDecimals: 1).format(_toDisplay(kg));

  /// The field's weight in kg; null when empty; NaN when not a valid weight.
  double? _parseKg(String text) {
    final t = text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null) return double.nan;
    final kg = _toKg(v);
    return kg < 20 || kg > 400 ? double.nan : (kg * 10).round() / 10;
  }

  String _rangeError() {
    final f = onboardingNumberFormat(context, maxDecimals: 0);
    return context.l10n.onboardingWeightInvalid('${f.format(_toDisplay(20))} $_unit', '${f.format(_toDisplay(400))} $_unit');
  }

  void _changeUnit(String unit) {
    if (unit == _unit) return;
    final current = _parseKg(_current.text);
    final goal = _parseKg(_goal.text);
    setState(() {
      _unit = unit;
      if (current != null && !current.isNaN) _current.text = _format(current);
      if (goal != null && !goal.isNaN) _goal.text = _format(goal);
    });
  }

  void _onCurrentChanged(String text) {
    setState(() => _currentError = null);
    if (_goalTouched) return;
    final kg = _parseKg(text);
    final suggestion = kg == null || kg.isNaN ? null : suggestGoalWeightKg(_fitnessGoal, kg);
    setState(() {
      _goal.text = suggestion == null ? '' : _format(suggestion);
      _goalSuggested = suggestion != null;
    });
  }

  void _onGoalChanged(String _) => setState(() {
        _goalTouched = true;
        _goalSuggested = false;
        _goalError = null;
      });

  // ── Saving ──────────────────────────────────────────────────────────────────

  int get _autoWaterMl {
    final kg = _parseKg(_current.text);
    return const UserSettings().waterGoalFor(kg == null || kg.isNaN ? null : kg);
  }

  /// Saves what [step] changed. False when its input isn't valid yet.
  Future<bool> _save(_Step step) async {
    switch (step) {
      case _Step.goal:
        if (_fitnessGoal != null) await _settings.update(fitnessGoal: _fitnessGoal);
      case _Step.days:
        await _settings.update(weeklyWorkoutTarget: _days);
      case _Step.body:
        final current = _parseKg(_current.text);
        final goal = _parseKg(_goal.text);
        if ((current?.isNaN ?? false) || (goal?.isNaN ?? false)) {
          setState(() {
            _currentError = (current?.isNaN ?? false) ? _rangeError() : null;
            _goalError = (goal?.isNaN ?? false) ? _rangeError() : null;
          });
          return false;
        }
        if (_unit != _settings.weightUnit.value) await _settings.update(weightUnit: _unit);
        if (current != null && current != _savedCurrentKg) {
          final token = await AuthManager.instance.getValidToken();
          await _api.createBodyMeasurement(token, {'weight_kg': current});
          _savedCurrentKg = current;
        }
        if (goal != _savedGoalKg) {
          await (goal == null ? _settings.update(clearGoalWeight: true) : _settings.update(goalWeightKg: goal));
          _savedGoalKg = goal;
        }
      case _Step.water:
        await (_waterMl == null ? _settings.update(autoWaterGoal: true) : _settings.update(waterGoalMl: _waterMl));
      case _Step.welcome:
      case _Step.done:
        break;
    }
    return true;
  }

  void _showSaveFailed() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.onboardingSaveFailed)));
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _go(_Step step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = step.index > _step.index;
      _step = step;
    });
    if (step == _Step.done && !MediaQuery.disableAnimationsOf(context)) _confetti.play();
  }

  Future<void> _next() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await _save(_step)) return;
    } catch (_) {
      // Keep going: the flow shouldn't trap anyone; what failed can be set later.
      if (mounted) _showSaveFailed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (_step == _Step.done) {
      await _finish();
    } else {
      HapticFeedback.lightImpact();
      _go(_Step.values[_step.index + 1]);
    }
  }

  void _back() {
    if (_step.index > 0) _go(_Step.values[_step.index - 1]);
  }

  /// Done or skipped: never show the flow again, then leave.
  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await _settings.update(onboarded: true);
    } catch (_) {
      if (mounted) _showSaveFailed();
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  Widget _stepView() {
    final l10n = context.l10n;
    final app = context.appColors;
    final cs = Theme.of(context).colorScheme;
    final water = _waterMl ?? _autoWaterMl;
    switch (_step) {
      case _Step.welcome:
        return const WelcomeStep();
      case _Step.goal:
        return GoalStep(value: _fitnessGoal, onChanged: (g) => setState(() => _fitnessGoal = g));
      case _Step.days:
        return DaysStep(value: _days, onChanged: (d) => setState(() => _days = d));
      case _Step.body:
        return BodyStep(
          unit: _unit,
          onUnitChanged: _changeUnit,
          current: _current,
          goal: _goal,
          goalSuggested: _goalSuggested,
          currentError: _currentError,
          goalError: _goalError,
          onCurrentChanged: _onCurrentChanged,
          onGoalChanged: _onGoalChanged,
        );
      case _Step.water:
        final kg = _parseKg(_current.text);
        return WaterStep(
          ml: water,
          auto: _waterMl == null,
          hasWeight: kg != null && !kg.isNaN,
          onChanged: (ml) {
            HapticFeedback.selectionClick();
            setState(() => _waterMl = ml);
          },
          onUseAuto: () => setState(() => _waterMl = null),
        );
      case _Step.done:
        final current = _savedCurrentKg;
        final goal = _savedGoalKg;
        final unit = ' $_unit';
        final weight = current != null && goal != null
            ? l10n.onboardingSummaryWeightGoal('${_format(current)}$unit', '${_format(goal)}$unit')
            : current != null
                ? '${_format(current)}$unit'
                : goal != null
                    ? l10n.onboardingSummaryGoalOnly('${_format(goal)}$unit')
                    : l10n.onboardingSummaryNotSet;
        final liters = '${onboardingNumberFormat(context, maxDecimals: 2).format(water / 1000)} L';
        return DoneStep(items: [
          SummaryItem(
            icon: _fitnessGoal == null ? Icons.flag_rounded : goalIcon(_fitnessGoal!),
            color: _fitnessGoal == null ? cs.primary : goalColor(context, _fitnessGoal!),
            label: l10n.onboardingSummaryGoal,
            value: _fitnessGoal == null ? l10n.onboardingSummaryNotSet : goalLabel(l10n, _fitnessGoal!),
            onTap: () => _go(_Step.goal),
          ),
          SummaryItem(
            icon: Icons.calendar_month_rounded,
            color: app.warning,
            label: l10n.onboardingSummaryDays,
            value: l10n.onboardingDaysValue(_days),
            onTap: () => _go(_Step.days),
          ),
          SummaryItem(
            icon: Icons.monitor_weight_outlined,
            color: app.success,
            label: l10n.onboardingSummaryWeight,
            value: weight,
            onTap: () => _go(_Step.body),
          ),
          SummaryItem(
            icon: Icons.water_drop_rounded,
            color: waterColor(context),
            label: l10n.onboardingSummaryWater,
            value: _waterMl == null ? l10n.onboardingSummaryWaterAuto(liters) : l10n.onboardingSummaryWaterCustom(liters),
            onTap: () => _go(_Step.water),
          ),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final calm = MediaQuery.disableAnimationsOf(context);
    final last = _step == _Step.done;
    final label = switch (_step) {
      _Step.welcome => l10n.onboardingStart,
      _Step.done => l10n.onboardingFinish,
      _ => l10n.onboardingContinue,
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: _step.index > 0
                              ? IconButton(
                                  tooltip: l10n.onboardingBack,
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  onPressed: _busy ? null : _back,
                                )
                              : null,
                        ),
                        Expanded(child: OnboardingProgress(current: _step.index, total: _Step.values.length)),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _busy || last ? null : _finish,
                          child: Text(l10n.onboardingSkip),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: calm ? Duration.zero : const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final incoming = child.key == ValueKey(_step);
                        final dx = (incoming == _forward) ? 0.12 : -0.12;
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(key: ValueKey(_step), child: _stepView()),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        key: const ValueKey('onboarding-next'),
                        onPressed: _busy ? null : _next,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : Text(label),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 28,
                gravity: 0.25,
                shouldLoop: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
