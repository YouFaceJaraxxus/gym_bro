import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/challenge.dart';
import '../services/settings_service.dart';

/// How each metric looks: its icon, its gradient and its words.
extension ChallengeMetricLook on ChallengeMetric {
  IconData get icon => switch (this) {
        ChallengeMetric.workouts => Icons.fitness_center_rounded,
        ChallengeMetric.activeDays => Icons.event_available_rounded,
        ChallengeMetric.minutes => Icons.timer_rounded,
        ChallengeMetric.volumeKg => Icons.scale_rounded,
        ChallengeMetric.checkIns => Icons.qr_code_2_rounded,
      };

  /// Start and end of the metric's gradient (rings, headers, medals).
  List<Color> get colors => switch (this) {
        ChallengeMetric.workouts => const [Color(0xFFFF7A1A), Color(0xFFFF3D71)],
        ChallengeMetric.activeDays => const [Color(0xFF12B886), Color(0xFF7BD86B)],
        ChallengeMetric.minutes => const [Color(0xFF2F80ED), Color(0xFF56CCF2)],
        ChallengeMetric.volumeKg => const [Color(0xFF7F3CFF), Color(0xFFD45CFF)],
        ChallengeMetric.checkIns => const [Color(0xFFE8457C), Color(0xFFFF9A62)],
      };

  Color get color => colors.first;

  String label(AppLocalizations l10n) => switch (this) {
        ChallengeMetric.workouts => l10n.challengeMetricWorkouts,
        ChallengeMetric.activeDays => l10n.challengeMetricActiveDays,
        ChallengeMetric.minutes => l10n.challengeMetricMinutes,
        ChallengeMetric.volumeKg => l10n.challengeMetricVolume,
        ChallengeMetric.checkIns => l10n.challengeMetricCheckIns,
      };

  /// What counts, in a sentence.
  String rule(AppLocalizations l10n, {String? gymName}) => switch (this) {
        ChallengeMetric.workouts => l10n.challengeRuleWorkouts,
        ChallengeMetric.activeDays => l10n.challengeRuleActiveDays,
        ChallengeMetric.minutes => l10n.challengeRuleMinutes,
        ChallengeMetric.volumeKg => l10n.challengeRuleVolume,
        ChallengeMetric.checkIns => l10n.challengeRuleCheckIns(gymName ?? ''),
      };

  /// [value] with its unit: "12 workouts", "300 min", "12,500 kg".
  String amount(AppLocalizations l10n, int value) {
    final n = NumberFormat.decimalPattern(l10n.localeName).format(value);
    return switch (this) {
      ChallengeMetric.workouts => '$n ${l10n.challengeUnitWorkouts(value)}',
      ChallengeMetric.activeDays => '$n ${l10n.challengeUnitActiveDays(value)}',
      ChallengeMetric.minutes => '$n ${l10n.challengeUnitMinutes}',
      ChallengeMetric.volumeKg => SettingsService.instance.formatWeight(value.toDouble(), decimals: 0),
      ChallengeMetric.checkIns => '$n ${l10n.challengeUnitCheckIns(value)}',
    };
  }

  /// Just the number, in the user's units (volume in kg or lb).
  String number(AppLocalizations l10n, int value) {
    final v = this == ChallengeMetric.volumeKg ? SettingsService.instance.toDisplayWeight(value.toDouble()) : value;
    return NumberFormat.decimalPattern(l10n.localeName).format(v.round());
  }

  /// The unit under a big number.
  String unit(AppLocalizations l10n, int value) => switch (this) {
        ChallengeMetric.workouts => l10n.challengeUnitWorkouts(value),
        ChallengeMetric.activeDays => l10n.challengeUnitActiveDays(value),
        ChallengeMetric.minutes => l10n.challengeUnitMinutes,
        ChallengeMetric.volumeKg => SettingsService.instance.weightUnit.value,
        ChallengeMetric.checkIns => l10n.challengeUnitCheckIns(value),
      };
}

String _capitalized(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// The title to show: automatic monthly challenges are worded in the app's
/// language, the rest as their creator wrote them.
String challengeTitle(AppLocalizations l10n, {required String title, String? autoKey, required int target}) {
  final month = _monthOf(autoKey);
  if (month == null) return title;
  final name = DateFormat.MMMM(l10n.localeName).format(month);
  if (autoKey!.endsWith(':workouts')) return _capitalized(l10n.challengeMonthlyWorkoutsTitle(name, target));
  if (autoKey.endsWith(':active_days')) return _capitalized(l10n.challengeMonthlyActiveDaysTitle(name, target));
  return title;
}

String? challengeDescription(AppLocalizations l10n, Challenge c) {
  final month = c.month;
  if (month == null) return c.description;
  final name = DateFormat.MMMM(l10n.localeName).format(month);
  if (c.metric == ChallengeMetric.workouts) return l10n.challengeMonthlyWorkoutsDescription(name, c.target);
  if (c.metric == ChallengeMetric.activeDays) return l10n.challengeMonthlyActiveDaysDescription(name, c.target);
  return c.description;
}

DateTime? _monthOf(String? autoKey) {
  if (autoKey == null || !autoKey.startsWith('monthly:')) return null;
  final ym = autoKey.split(':')[1].split('-');
  final y = int.tryParse(ym.first), m = ym.length > 1 ? int.tryParse(ym[1]) : null;
  return y == null || m == null ? null : DateTime(y, m);
}

extension ChallengeText on Challenge {
  String displayTitle(AppLocalizations l10n) => challengeTitle(l10n, title: title, autoKey: autoKey, target: target);

  /// "Ironclad Fitness" or "Gym Bro".
  String host(AppLocalizations l10n) => gym?.name ?? l10n.challengePlatform;

  /// "5 days left", "Last day", "Starts tomorrow", "Ended 30 Nov".
  String timing(AppLocalizations l10n) => switch (status) {
        ChallengeStatus.active => daysLeft <= 1 ? l10n.challengeLastDay : l10n.challengeDaysLeft(daysLeft),
        ChallengeStatus.upcoming => daysLeft <= 1 ? l10n.challengeStartsTomorrow : l10n.challengeStartsIn(daysLeft),
        ChallengeStatus.past => l10n.challengeEndedOn(DateFormat.MMMd(l10n.localeName).format(endsOn)),
      };
}

/// A progress ring in the metric's gradient, sweeping in from empty (or
/// drawn full at once when animations are off). [child] sits in the middle.
class ChallengeRing extends StatelessWidget {
  final double fraction;
  final List<Color> colors;
  final double size;
  final double stroke;
  final Widget? child;

  /// Lighter track for rings on a coloured background.
  final Color? trackColor;

  const ChallengeRing({
    super.key,
    required this.fraction,
    required this.colors,
    this.size = 64,
    this.stroke = 7,
    this.child,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    final track = trackColor ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    final value = fraction.clamp(0.0, 1.0);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: calm ? value : 0, end: value),
        duration: calm ? Duration.zero : const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => CustomPaint(
          painter: _RingPainter(fraction: v, colors: colors, stroke: stroke, track: track),
          child: child,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final List<Color> colors;
  final double stroke;
  final Color track;

  _RingPainter({required this.fraction, required this.colors, required this.stroke, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (fraction <= 0) return;
    final sweep = math.pi * 2 * fraction;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [colors.first, colors.last, colors.last],
        stops: [0, fraction.clamp(0.05, 1.0), 1],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, paint);
    // A soft glow once it's full.
    if (fraction >= 1) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 1.8
          ..color = colors.last.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.colors != colors || old.stroke != stroke || old.track != track;
}

/// The metric's icon on its gradient, in a rounded square.
class ChallengeMetricIcon extends StatelessWidget {
  final ChallengeMetric metric;
  final double size;

  const ChallengeMetricIcon({super.key, required this.metric, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: metric.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(metric.icon, color: Colors.white, size: size * 0.55),
    );
  }
}
