import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/challenge.dart';
import 'app_bottom_sheet.dart';
import 'challenge_ring.dart';

/// A medal: a gold disc with the metric's icon, hanging from a ribbon in the
/// metric's colours.
class ChallengeMedalIcon extends StatelessWidget {
  final ChallengeMetric metric;
  final double size;

  const ChallengeMedalIcon({super.key, required this.metric, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MedalPainter(ribbon: metric.colors),
        child: Align(
          alignment: const Alignment(0, 0.42),
          child: Icon(metric.icon, size: size * 0.3, color: const Color(0xFF7A4B00)),
        ),
      ),
    );
  }
}

class _MedalPainter extends CustomPainter {
  final List<Color> ribbon;

  _MedalPainter({required this.ribbon});

  static const _gold = [Color(0xFFFFE08A), Color(0xFFFFC233), Color(0xFFE09B00)];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = w * 0.32;
    final center = Offset(w / 2, h - r - h * 0.02);

    // Ribbon: two tails meeting behind the disc.
    final left = Path()
      ..moveTo(w * 0.18, 0)
      ..lineTo(w * 0.42, 0)
      ..lineTo(w * 0.58, center.dy - r * 0.4)
      ..lineTo(w * 0.36, center.dy - r * 0.2)
      ..close();
    final right = Path()
      ..moveTo(w * 0.82, 0)
      ..lineTo(w * 0.58, 0)
      ..lineTo(w * 0.42, center.dy - r * 0.4)
      ..lineTo(w * 0.64, center.dy - r * 0.2)
      ..close();
    canvas.drawPath(left, Paint()..color = ribbon.first);
    canvas.drawPath(right, Paint()..color = ribbon.last);

    // Disc with a rim and a highlight.
    final disc = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center.translate(0, r * 0.08),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()..shader = const LinearGradient(colors: _gold, begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(disc),
    );
    canvas.drawCircle(
      center,
      r * 0.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.08)
        ..color = const Color(0xFFB57A00).withValues(alpha: 0.45),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 0.92),
      math.pi * 1.1,
      math.pi * 0.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1, r * 0.1)
        ..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(_MedalPainter old) => old.ribbon != ribbon;
}

/// "🏅 3 medals" on a profile; opens the medals.
class ChallengeMedalsChip extends StatelessWidget {
  final ChallengeMedals medals;

  const ChallengeMedalsChip({super.key, required this.medals});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final shown = medals.items.take(3).toList();
    return Material(
      color: const Color(0xFFFFC233).withValues(alpha: 0.16),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => showChallengeMedalsSheet(context, medals),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 12, 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (shown.isEmpty)
                const ChallengeMedalIcon(metric: ChallengeMetric.workouts, size: 24)
              else
                for (final m in shown) ChallengeMedalIcon(metric: m.metric, size: 24),
              const SizedBox(width: 4),
              Text(
                l10n.challengeMedalsCount(medals.count),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showChallengeMedalsSheet(BuildContext context, ChallengeMedals medals) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (context) => _MedalsSheet(medals: medals),
  );
}

class _MedalsSheet extends StatelessWidget {
  final ChallengeMedals medals;

  const _MedalsSheet({required this.medals});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.challengeMedalsTitle, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l10n.challengeMedalsCount(medals.count), style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            if (medals.isPrivate)
              Text(l10n.challengeMedalsPrivate, style: text.bodyMedium)
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [for (final m in medals.items) ChallengeMedalTile(medal: m)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One medal in a list: the medal, the challenge and when it was won.
class ChallengeMedalTile extends StatelessWidget {
  final ChallengeMedal medal;
  final VoidCallback? onTap;

  const ChallengeMedalTile({super.key, required this.medal, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final m = medal;
    final when = m.completedAt ?? m.endsOn;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      onTap: onTap,
      leading: ChallengeMedalIcon(metric: m.metric, size: 48),
      title: Text(
        challengeTitle(l10n, title: m.title, autoKey: m.autoKey, target: m.target),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${m.gym?.name ?? l10n.challengePlatform} · ${l10n.challengeCompletedOn(DateFormat.yMMMd(l10n.localeName).format(when))}',
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
    );
  }
}
