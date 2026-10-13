import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../theme.dart';

/// Renders a front/back body silhouette with highlighted muscle regions.
/// [primaryMuscles] use the theme's error color, [secondaryMuscles] the
/// warning color.
class MuscleDiagram extends StatelessWidget {
  final Set<MuscleGroup> primaryMuscles;
  final Set<MuscleGroup> secondaryMuscles;
  final double size;

  const MuscleDiagram({
    super.key,
    required this.primaryMuscles,
    this.secondaryMuscles = const {},
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final colors = _BodyColors(
      primary: cs.error,
      secondary: context.appColors.warning,
      idle: cs.surfaceContainerHighest,
      head: cs.surfaceContainerHigh,
      outline: cs.outline.withValues(alpha: 0.5),
    );
    final primary = primaryMuscles.map((m) => m.region).toSet();
    final secondary = secondaryMuscles.map((m) => m.region).toSet();

    final parts = <String>[l10n.trainingMuscleMapLabel];
    if (primaryMuscles.isNotEmpty) {
      parts.add(l10n.trainingMuscleMapPrimary(
          primaryMuscles.map((m) => m.label(l10n)).join(', ')));
    }
    if (secondaryMuscles.isNotEmpty) {
      parts.add(l10n.trainingMuscleMapSecondary(
          secondaryMuscles.map((m) => m.label(l10n)).join(', ')));
    }
    if (primaryMuscles.isEmpty && secondaryMuscles.isEmpty) {
      parts.add(l10n.trainingMuscleMapNone);
    }

    return Semantics(
      container: true,
      image: true,
      label: parts.join('. '),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BodyView(
            face: _BodyFace.front,
            primary: primary,
            secondary: secondary,
            colors: colors,
            size: size,
          ),
          SizedBox(width: size * 0.08),
          _BodyView(
            face: _BodyFace.back,
            primary: primary,
            secondary: secondary,
            colors: colors,
            size: size,
          ),
        ],
      ),
    );
  }
}

enum _BodyFace { front, back }

@immutable
class _BodyColors {
  final Color primary;
  final Color secondary;
  final Color idle;
  final Color head;
  final Color outline;

  const _BodyColors({
    required this.primary,
    required this.secondary,
    required this.idle,
    required this.head,
    required this.outline,
  });

  @override
  bool operator ==(Object other) =>
      other is _BodyColors &&
      other.primary == primary &&
      other.secondary == secondary &&
      other.idle == idle &&
      other.head == head &&
      other.outline == outline;

  @override
  int get hashCode => Object.hash(primary, secondary, idle, head, outline);
}

class _BodyView extends StatelessWidget {
  final _BodyFace face;
  final Set<BodyRegion> primary;
  final Set<BodyRegion> secondary;
  final _BodyColors colors;
  final double size;

  const _BodyView({
    required this.face,
    required this.primary,
    required this.secondary,
    required this.colors,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final w = size * 0.45;
    final h = size;
    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: _BodyPainter(
          face: face,
          primary: primary,
          secondary: secondary,
          colors: colors,
        ),
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  final _BodyFace face;
  final Set<BodyRegion> primary;
  final Set<BodyRegion> secondary;
  final _BodyColors colors;

  const _BodyPainter({
    required this.face,
    required this.primary,
    required this.secondary,
    required this.colors,
  });

  Color colorFor(BodyRegion region) {
    if (primary.contains(region)) return colors.primary;
    if (secondary.contains(region)) return colors.secondary;
    return colors.idle;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void fill(BodyRegion region, Path path) {
      canvas.drawPath(
        path,
        Paint()
          ..color = colorFor(region)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = colors.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }

    if (face == _BodyFace.front) {
      _paintFront(canvas, w, h, fill);
    } else {
      _paintBack(canvas, w, h, fill);
    }
  }

  void _paintFront(
    Canvas canvas,
    double w,
    double h,
    void Function(BodyRegion, Path) fill,
  ) {
    // Head
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.05), width: w * 0.28, height: h * 0.08),
      Paint()
        ..color = colors.head
        ..style = PaintingStyle.fill,
    );

    // Neck
    fill(
      BodyRegion.neck,
      Path()
        ..addRect(
          Rect.fromLTWH(w * 0.43, h * 0.085, w * 0.14, h * 0.04),
        ),
    );

    // Left shoulder (front)
    fill(
      BodyRegion.shoulderFront,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.18, h * 0.17),
          width: w * 0.22,
          height: h * 0.07,
        )),
    );

    // Right shoulder (front)
    fill(
      BodyRegion.shoulderFront,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.82, h * 0.17),
          width: w * 0.22,
          height: h * 0.07,
        )),
    );

    // Chest
    fill(
      BodyRegion.chest,
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.3, h * 0.13, w * 0.4, h * 0.1),
          const Radius.circular(4),
        )),
    );

    // Left bicep
    fill(
      BodyRegion.biceps,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.1, h * 0.265),
          width: w * 0.14,
          height: h * 0.09,
        )),
    );

    // Right bicep
    fill(
      BodyRegion.biceps,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.9, h * 0.265),
          width: w * 0.14,
          height: h * 0.09,
        )),
    );

    // Left forearm
    fill(
      BodyRegion.forearms,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.08, h * 0.37),
          width: w * 0.12,
          height: h * 0.1,
        )),
    );

    // Right forearm
    fill(
      BodyRegion.forearms,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.92, h * 0.37),
          width: w * 0.12,
          height: h * 0.1,
        )),
    );

    // Abs
    fill(
      BodyRegion.abs,
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.36, h * 0.24, w * 0.28, h * 0.11),
          const Radius.circular(3),
        )),
    );

    // Obliques
    fill(
      BodyRegion.obliques,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.28, h * 0.30),
          width: w * 0.1,
          height: h * 0.1,
        ))
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.72, h * 0.30),
          width: w * 0.1,
          height: h * 0.1,
        )),
    );

    // Left quad
    fill(
      BodyRegion.quads,
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.27, h * 0.53, w * 0.18, h * 0.18),
          const Radius.circular(6),
        )),
    );

    // Right quad
    fill(
      BodyRegion.quads,
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.55, h * 0.53, w * 0.18, h * 0.18),
          const Radius.circular(6),
        )),
    );

    // Left calf
    fill(
      BodyRegion.calves,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.35, h * 0.85),
          width: w * 0.14,
          height: h * 0.12,
        )),
    );

    // Right calf
    fill(
      BodyRegion.calves,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.65, h * 0.85),
          width: w * 0.14,
          height: h * 0.12,
        )),
    );
  }

  void _paintBack(
    Canvas canvas,
    double w,
    double h,
    void Function(BodyRegion, Path) fill,
  ) {
    // Head
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.05), width: w * 0.28, height: h * 0.08),
      Paint()
        ..color = colors.head
        ..style = PaintingStyle.fill,
    );

    // Traps
    fill(
      BodyRegion.traps,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.135),
          width: w * 0.42,
          height: h * 0.07,
        )),
    );

    // Left shoulder rear
    fill(
      BodyRegion.shoulderRear,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.18, h * 0.17),
          width: w * 0.22,
          height: h * 0.07,
        )),
    );

    // Right shoulder rear
    fill(
      BodyRegion.shoulderRear,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.82, h * 0.17),
          width: w * 0.22,
          height: h * 0.07,
        )),
    );

    // Lats
    fill(
      BodyRegion.lats,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.28, h * 0.25),
          width: w * 0.18,
          height: h * 0.14,
        ))
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.72, h * 0.25),
          width: w * 0.18,
          height: h * 0.14,
        )),
    );

    // Mid back / rhomboids
    fill(
      BodyRegion.midBack,
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.33, h * 0.18, w * 0.34, h * 0.12),
          const Radius.circular(4),
        )),
    );

    // Left tricep
    fill(
      BodyRegion.triceps,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.1, h * 0.265),
          width: w * 0.14,
          height: h * 0.09,
        )),
    );

    // Right tricep
    fill(
      BodyRegion.triceps,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.9, h * 0.265),
          width: w * 0.14,
          height: h * 0.09,
        )),
    );

    // Left forearm (back)
    fill(
      BodyRegion.forearms,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.08, h * 0.37),
          width: w * 0.12,
          height: h * 0.1,
        )),
    );

    // Right forearm (back)
    fill(
      BodyRegion.forearms,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.92, h * 0.37),
          width: w * 0.12,
          height: h * 0.1,
        )),
    );

    // Glutes
    fill(
      BodyRegion.glutes,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.36, h * 0.485),
          width: w * 0.22,
          height: h * 0.09,
        ))
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.64, h * 0.485),
          width: w * 0.22,
          height: h * 0.09,
        )),
    );

    // Left hamstring
    fill(
      BodyRegion.hamstrings,
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.27, h * 0.53, w * 0.18, h * 0.18),
          const Radius.circular(6),
        )),
    );

    // Right hamstring
    fill(
      BodyRegion.hamstrings,
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.55, h * 0.53, w * 0.18, h * 0.18),
          const Radius.circular(6),
        )),
    );

    // Left calf (back)
    fill(
      BodyRegion.calves,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.35, h * 0.85),
          width: w * 0.14,
          height: h * 0.12,
        )),
    );

    // Right calf (back)
    fill(
      BodyRegion.calves,
      Path()
        ..addOval(Rect.fromCenter(
          center: Offset(w * 0.65, h * 0.85),
          width: w * 0.14,
          height: h * 0.12,
        )),
    );
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.face != face ||
      old.colors != colors ||
      !setEquals(old.primary, primary) ||
      !setEquals(old.secondary, secondary);
}

/// Compact chip row listing targeted muscles.
class MuscleChips extends StatelessWidget {
  final List<MuscleGroup> primary;
  final List<MuscleGroup> secondary;

  const MuscleChips({super.key, required this.primary, this.secondary = const []});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final app = context.appColors;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final m in primary)
          _MuscleChip(
            label: m.label(l10n),
            semanticsLabel: l10n.trainingMuscleMapPrimary(m.label(l10n)),
            background: cs.errorContainer,
            foreground: cs.onErrorContainer,
            border: cs.error,
          ),
        for (final m in secondary)
          _MuscleChip(
            label: m.label(l10n),
            semanticsLabel: l10n.trainingMuscleMapSecondary(m.label(l10n)),
            background: app.warningContainer,
            foreground: app.onWarningContainer,
            border: app.warning,
          ),
      ],
    );
  }
}

class _MuscleChip extends StatelessWidget {
  final String label;
  final String semanticsLabel;
  final Color background;
  final Color foreground;
  final Color border;

  const _MuscleChip({
    required this.label,
    required this.semanticsLabel,
    required this.background,
    required this.foreground,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        semanticsLabel: semanticsLabel,
        style: TextStyle(fontSize: 11, color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Legend row shown below the diagram.
class MuscleDiagramLegend extends StatelessWidget {
  const MuscleDiagramLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(Theme.of(context).colorScheme.error),
        const SizedBox(width: 4),
        Text(l10n.trainingMuscleMapLegendTarget, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 12),
        _dot(context.appColors.warning),
        const SizedBox(width: 4),
        Text(l10n.trainingMuscleMapLegendSecondary, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
