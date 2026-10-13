import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';

/// Countdown between sets. Owned by the session page; [RestTimerBanner]
/// renders it. When the countdown reaches zero it vibrates and plays the
/// system alert sound.
class RestTimerController extends ChangeNotifier {
  static const presets = [60, 90, 120, 180];

  RestTimerController({this.defaultSeconds = 90});

  /// Duration used by [start] when no explicit value is given.
  int defaultSeconds;

  Timer? _timer;
  DateTime? _endsAt;
  int _total = 0;
  int _remaining = 0;

  bool get isRunning => _timer != null;
  int get remaining => _remaining;
  int get total => _total;

  /// 1.0 → 0.0 as time runs out.
  double get fraction => _total == 0 ? 0 : _remaining / _total;

  void start([int? seconds]) {
    final s = seconds ?? defaultSeconds;
    _total = s;
    _endsAt = DateTime.now().add(Duration(seconds: s));
    _remaining = s;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    notifyListeners();
  }

  /// Changes the default and restarts the countdown with it.
  void setPreset(int seconds) {
    defaultSeconds = seconds;
    start(seconds);
  }

  void addSeconds(int seconds) {
    if (_endsAt == null) return;
    _endsAt = _endsAt!.add(Duration(seconds: seconds));
    _total += seconds;
    _tick();
  }

  void skip() => _stop();

  void _tick() {
    final left = _endsAt!.difference(DateTime.now());
    final secs = (left.inMilliseconds / 1000).ceil();
    if (secs <= 0) {
      _stop();
      _alert();
      return;
    }
    if (secs != _remaining) {
      _remaining = secs;
      notifyListeners();
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _endsAt = null;
    _remaining = 0;
    notifyListeners();
  }

  Future<void> _alert() async {
    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.alert);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

String formatRestTime(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Countdown banner: time left, progress, preset chips, +15 s and Skip.
/// Collapses to nothing while the timer isn't running.
class RestTimerBanner extends StatelessWidget {
  final RestTimerController controller;

  const RestTimerBanner({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: !controller.isRunning
              ? const SizedBox(width: double.infinity)
              : Material(
                  color: cs.primaryContainer,
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.timer_outlined, color: cs.onPrimaryContainer),
                              const SizedBox(width: 8),
                              Text(
                                l10n.trainingRestTitle,
                                style: text.titleSmall?.copyWith(color: cs.onPrimaryContainer),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                formatRestTime(controller.remaining),
                                semanticsLabel: l10n.trainingRestRemaining(
                                  formatRestTime(controller.remaining),
                                ),
                                style: text.headlineSmall?.copyWith(
                                  color: cs.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const Spacer(),
                              Tooltip(
                                message: l10n.trainingRestAddSecondsTooltip(15),
                                child: TextButton(
                                  onPressed: () => controller.addSeconds(15),
                                  style: TextButton.styleFrom(
                                    foregroundColor: cs.onPrimaryContainer,
                                  ),
                                  child: Text(l10n.trainingRestAddSeconds(15)),
                                ),
                              ),
                              TextButton(
                                onPressed: controller.skip,
                                style: TextButton.styleFrom(foregroundColor: cs.onPrimaryContainer),
                                child: Text(l10n.trainingRestSkip),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: controller.fraction,
                              minHeight: 4,
                              color: cs.primary,
                              backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.12),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final p in RestTimerController.presets)
                                ChoiceChip(
                                  label: Text(formatRestTime(p)),
                                  tooltip: l10n.trainingRestPresetTooltip(formatRestTime(p)),
                                  visualDensity: VisualDensity.compact,
                                  selected: controller.defaultSeconds == p,
                                  onSelected: (_) => controller.setPreset(p),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
