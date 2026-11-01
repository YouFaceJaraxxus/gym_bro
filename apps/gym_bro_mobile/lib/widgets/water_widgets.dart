import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/user_settings.dart';
import '../models/water.dart';
import '../pages/water/water_page.dart';
import '../services/settings_service.dart';
import '../services/water_service.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import 'app_bottom_sheet.dart';

// ── Colours ─────────────────────────────────────────────────────────────────

/// Water's own blues (the theme has no role for them), legible in both themes.
class WaterColors {
  final Color water;
  final Color light;
  final Color deep;
  final Color container;
  final Color onContainer;

  const WaterColors._(this.water, this.light, this.deep, this.container, this.onContainer);

  static const _lightTheme = WaterColors._(
    Color(0xFF2F8BE0),
    Color(0xFF8CC8FF),
    Color(0xFF1667B8),
    Color(0xFFE3F0FC),
    Color(0xFF0B3D6E),
  );
  static const _darkTheme = WaterColors._(
    Color(0xFF5DB3FF),
    Color(0xFF9AD0FF),
    Color(0xFF2F8BE0),
    Color(0xFF15293D),
    Color(0xFFCDE6FF),
  );

  factory WaterColors.of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _darkTheme : _lightTheme;
}

// ── Logging ─────────────────────────────────────────────────────────────────

/// Logs [ml] with a light haptic, then shows what it added with an Undo that
/// deletes it again. Errors show in a snackbar.
Future<void> logWater(BuildContext context, int ml) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  HapticFeedback.lightImpact();
  try {
    final added = await WaterService.instance.add(ml);
    final crossed = added.today.reached && added.today.totalMl - ml < added.today.goalMl;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            crossed ? l10n.waterAddedGoal(waterAmount(l10n, ml)) : l10n.waterAdded(waterAmount(l10n, ml)),
          ),
          action: SnackBarAction(
            label: l10n.waterUndo,
            onPressed: () => WaterService.instance.remove(added.entry.id).catchError((Object e) {
              messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
            }),
          ),
        ),
      );
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.waterAddFailed(_errorText(e)))));
  }
}

String _errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

/// Asks for a custom amount (1–3000 ml). Null when dismissed.
Future<int?> showCustomWaterSheet(BuildContext context) {
  return showAppBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CustomWaterSheet(),
  );
}

class _CustomWaterSheet extends StatefulWidget {
  const _CustomWaterSheet();

  @override
  State<_CustomWaterSheet> createState() => _CustomWaterSheetState();
}

class _CustomWaterSheetState extends State<_CustomWaterSheet> {
  final _ctl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _submit() {
    final ml = int.tryParse(_ctl.text.trim());
    if (ml == null || ml < 1 || ml > 3000) {
      setState(() => _error = context.l10n.waterCustomInvalid);
      return;
    }
    Navigator.pop(context, ml);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final water = WaterColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.waterCustomTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _ctl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: InputDecoration(
              labelText: l10n.waterCustomLabel,
              prefixIcon: Icon(Icons.water_drop_outlined, color: water.water),
              suffixText: 'ml',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final ml in const [150, 330, 750, 1000])
                ActionChip(
                  label: Text(waterAmount(l10n, ml)),
                  onPressed: () => Navigator.pop(context, ml),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.add),
            label: Text(l10n.waterAdd),
          ),
        ],
      ),
    );
  }
}

// ── Quick add ───────────────────────────────────────────────────────────────

/// A button per cup size (from settings) plus "Custom".
class WaterQuickAdd extends StatelessWidget {
  const WaterQuickAdd({super.key, this.compact = false, this.alignment = WrapAlignment.center});

  /// Smaller buttons (food diary card).
  final bool compact;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final water = WaterColors.of(context);
    final density = compact ? VisualDensity.compact : VisualDensity.standard;
    return ValueListenableBuilder<UserSettings>(
      valueListenable: SettingsService.instance.settings,
      builder: (context, s, _) => Wrap(
        alignment: alignment,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final ml in s.waterCups)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                visualDensity: density,
                backgroundColor: water.container,
                foregroundColor: water.onContainer,
              ),
              onPressed: () => logWater(context, ml),
              icon: Icon(_cupIcon(ml), size: compact ? 16 : 18),
              label: Text(waterAmount(l10n, ml), semanticsLabel: l10n.waterAddCup(waterAmount(l10n, ml))),
            ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(visualDensity: density),
            onPressed: () async {
              final ml = await showCustomWaterSheet(context);
              if (ml != null && context.mounted) await logWater(context, ml);
            },
            icon: Icon(Icons.tune, size: compact ? 16 : 18),
            label: Text(l10n.waterCustom),
          ),
        ],
      ),
    );
  }
}

IconData _cupIcon(int ml) => ml >= 700
    ? Icons.water_outlined
    : ml >= 400
    ? Icons.local_drink_outlined
    : Icons.coffee_outlined;

// ── Bottle ──────────────────────────────────────────────────────────────────

/// A bottle filling up to [fraction] with an animated wave that sloshes when
/// water is added, and the percentage on it. Still (no wave motion, no
/// slosh, no fill-up) with reduce motion on.
class WaterBottle extends StatefulWidget {
  const WaterBottle({
    super.key,
    required this.fraction,
    required this.percent,
    this.width = 140,
    this.height = 220,
    this.semanticLabel,
  });

  /// 0..1 of the goal.
  final double fraction;

  /// Shown on the bottle (may pass 100).
  final int percent;
  final double width;
  final double height;
  final String? semanticLabel;

  @override
  State<WaterBottle> createState() => _WaterBottleState();
}

class _WaterBottleState extends State<WaterBottle> with TickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final AnimationController _level = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _slosh = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  double _from = 0;
  double _to = 0;
  bool _calm = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MediaQuery.disableAnimationsOf(context);
    if (_calm) {
      _wave.stop();
      _slosh.value = 1;
      _level.value = 1;
      _from = _to = widget.fraction;
    } else if (!_wave.isAnimating) {
      _wave.repeat();
    }
    if (!_started) {
      _started = true;
      _to = widget.fraction;
      if (_calm) {
        _from = _to;
        _level.value = 1;
      } else {
        _from = 0;
        _level.forward(from: 0);
      }
      _slosh.value = 1;
    }
  }

  @override
  void didUpdateWidget(WaterBottle old) {
    super.didUpdateWidget(old);
    if (old.fraction == widget.fraction) return;
    final current = _currentLevel;
    _from = _calm ? widget.fraction : current;
    _to = widget.fraction;
    if (_calm) {
      _level.value = 1;
      return;
    }
    _level.forward(from: 0);
    if (widget.fraction > old.fraction) _slosh.forward(from: 0);
  }

  double get _currentLevel => _from + (_to - _from) * Curves.easeOutCubic.transform(_level.value);

  @override
  void dispose() {
    _wave.dispose();
    _level.dispose();
    _slosh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final water = WaterColors.of(context);
    final painter = _BottlePainter(
      repaint: Listenable.merge([_wave, _level, _slosh]),
      level: () => _currentLevel,
      phase: () => _wave.value * 2 * math.pi,
      slosh: () => _calm ? 1 : _slosh.value,
      water: water,
      glass: cs.outlineVariant,
      track: water.container.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.7 : 1),
      label: '${widget.percent}%',
      labelStyle: AppText.stat(size: 36, weight: FontWeight.w800),
      labelColor: cs.onSurface,
      labelOnWater: Colors.white,
    );
    return Semantics(
      label: widget.semanticLabel,
      image: widget.semanticLabel != null,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: CustomPaint(painter: painter),
        ),
      ),
    );
  }
}

class _BottlePainter extends CustomPainter {
  _BottlePainter({
    required Listenable repaint,
    required this.level,
    required this.phase,
    required this.slosh,
    required this.water,
    required this.glass,
    required this.track,
    required this.label,
    required this.labelStyle,
    required this.labelColor,
    required this.labelOnWater,
  }) : super(repaint: repaint);

  final double Function() level;
  final double Function() phase;

  /// 0 right after water was added → 1 when settled.
  final double Function() slosh;
  final WaterColors water;
  final Color glass;
  final Color track;
  final String label;
  final TextStyle labelStyle;
  final Color labelColor;
  final Color labelOnWater;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final capH = h * 0.075;
    final neckH = h * 0.06;
    final shoulder = h * 0.12;
    final neckW = w * 0.42;
    final capW = w * 0.5;
    final r = w * 0.2;
    final cx = w / 2;
    final nl = cx - neckW / 2;
    final nr = cx + neckW / 2;
    final yNeck = capH + neckH;
    final yBody = yNeck + shoulder;

    final body = Path()
      ..moveTo(nl, capH)
      ..lineTo(nl, yNeck)
      ..cubicTo(nl, yNeck + shoulder * 0.55, 0, yNeck + shoulder * 0.35, 0, yBody)
      ..lineTo(0, h - r)
      ..quadraticBezierTo(0, h, r, h)
      ..lineTo(w - r, h)
      ..quadraticBezierTo(w, h, w, h - r)
      ..lineTo(w, yBody)
      ..cubicTo(w, yNeck + shoulder * 0.35, nr, yNeck + shoulder * 0.55, nr, yNeck)
      ..lineTo(nr, capH)
      ..close();

    // Glass
    canvas.drawPath(body, Paint()..color = track);

    // Water
    final lv = level().clamp(0.0, 1.0);
    final top = yBody - shoulder * 0.3;
    final waterY = h - lv * (h - top);
    final t = slosh();
    final settle = math.pow(1 - t, 2).toDouble();
    final amp = lv <= 0 ? 0.0 : (h * 0.011 + h * 0.04 * settle) * (lv >= 1 ? 0.6 : 1);
    final tilt = h * 0.06 * settle * math.sin(t * math.pi * 5);
    final p = phase();

    Path wave(double phaseShift, double ampScale) {
      final path = Path()..moveTo(0, h);
      const steps = 36;
      for (var i = 0; i <= steps; i++) {
        final x = w * i / steps;
        final y = waterY +
            amp * ampScale * math.sin(2 * math.pi * x / (w * 0.95) + p + phaseShift) +
            tilt * (x / w - 0.5) * 2;
        path.lineTo(x, y);
      }
      return path
        ..lineTo(w, h)
        ..close();
    }

    final front = wave(0, 1);
    canvas.save();
    canvas.clipPath(body);
    if (lv > 0) {
      canvas.drawPath(wave(math.pi * 0.75, 0.8), Paint()..color = water.light.withValues(alpha: 0.55));
      canvas.drawPath(
        front,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [water.water, water.deep],
          ).createShader(Rect.fromLTWH(0, waterY - amp, w, h - waterY + amp)),
      );
      // A few bubbles rising in the water.
      final bubble = Paint()..color = Colors.white.withValues(alpha: 0.28);
      for (final (fx, fy, rad) in const [(0.28, 0.82, 3.0), (0.66, 0.9, 2.2), (0.5, 0.7, 1.8), (0.78, 0.76, 2.6)]) {
        final y = h - (h - waterY) * (1 - fy) - 6;
        if (y > waterY + 8) canvas.drawCircle(Offset(w * fx, y), rad, bubble);
      }
    }
    canvas.restore();

    // Ticks at 25 / 50 / 75 %
    final tick = Paint()
      ..color = glass
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final f in const [0.25, 0.5, 0.75]) {
      final y = h - f * (h - top);
      canvas.drawLine(Offset(w - w * 0.14, y), Offset(w - w * 0.06, y), tick);
    }

    // Outline, shine and cap
    canvas.drawPath(
      body,
      Paint()
        ..color = glass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.1, yBody + h * 0.04, w * 0.1 + 5, h - r * 0.9, const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(cx - capW / 2, 0, cx + capW / 2, capH + 2, Radius.circular(capH * 0.35)),
      Paint()..color = water.deep,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(cx - capW / 2 + 4, capH * 0.3, cx + capW / 2 - 4, capH * 0.45, const Radius.circular(2)),
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );

    // The percentage: dark on glass, white where the water covers it.
    // Scaled down on small bottles.
    final style = labelStyle.copyWith(fontSize: math.min(labelStyle.fontSize ?? 28, w * 0.24));
    final tp = TextPainter(
      text: TextSpan(text: label, style: style.copyWith(color: labelColor)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w);
    final at = Offset(cx - tp.width / 2, yBody + (h - yBody) * 0.5 - tp.height / 2);
    tp.paint(canvas, at);
    if (lv > 0) {
      canvas.save();
      canvas.clipPath(Path.combine(PathOperation.intersect, front, body));
      final white = TextPainter(
        text: TextSpan(text: label, style: style.copyWith(color: labelOnWater)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w);
      white.paint(canvas, at);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BottlePainter old) =>
      old.label != label || old.water != water || old.glass != glass || old.labelColor != labelColor;
}

// ── Ring ────────────────────────────────────────────────────────────────────

/// A progress ring with a round cap ([fraction] 0..1, animated), optionally
/// with water filling its middle to the same level.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.fraction,
    required this.color,
    this.size = 96,
    this.stroke = 9,
    this.fill,
    this.child,
  });

  final double fraction;
  final Color color;
  final double size;
  final double stroke;

  /// Water inside the ring (its colour), or null for an empty middle.
  final Color? fill;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final calm = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction.clamp(0.0, 1.0)),
        duration: calm ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => CustomPaint(
          painter: _RingPainter(v, color, cs.surfaceContainerHighest, stroke, fill),
          child: child,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track, this.stroke, this.fill);

  final double value;
  final Color color;
  final Color track;
  final double stroke;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: c, radius: radius);
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (fill != null && value > 0) {
      final inner = radius - stroke / 2 - 4;
      final y = c.dy + inner - 2 * inner * value;
      final path = Path()..moveTo(c.dx - inner, c.dy + inner);
      for (var i = 0; i <= 24; i++) {
        final x = c.dx - inner + 2 * inner * i / 24;
        path.lineTo(x, y + inner * 0.06 * math.sin(i / 24 * 2 * math.pi + 0.6));
      }
      path
        ..lineTo(c.dx + inner, c.dy + inner)
        ..close();
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: inner)));
      canvas.drawPath(path, Paint()..color = fill!.withValues(alpha: 0.18));
      canvas.restore();
    }
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          transform: const GradientRotation(-math.pi / 2),
          colors: [Color.lerp(color, Colors.white, 0.25)!, color],
          stops: [0, value.clamp(0.01, 1.0)],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color || old.track != track || old.fill != fill;
}

/// Today's water as a ring for Home: tap adds the first cup size, a long
/// press opens the Water page.
class WaterRing extends StatelessWidget {
  const WaterRing({super.key, required this.day, this.size = 96});

  final WaterDay day;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final water = WaterColors.of(context);
    final cups = SettingsService.instance.settings.value.waterCups;
    final cup = cups.isEmpty ? 250 : cups.first;
    return Semantics(
      button: true,
      label: l10n.waterBottleSemantics(waterAmount(l10n, day.totalMl), waterAmount(l10n, day.goalMl), day.percent),
      hint: l10n.waterRingHint(waterAmount(l10n, cup)),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => logWater(context, cup),
        onLongPress: () => openWaterPage(context),
        child: ProgressRing(
          fraction: day.fraction,
          color: water.water,
          fill: water.water,
          size: size,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(day.reached ? Icons.check_circle : Icons.water_drop, color: water.water, size: size * 0.22),
              Text(
                '${day.percent}%',
                style: AppText.stat(size: 20, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the Water page.
Future<void> openWaterPage(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const WaterPage()));

// ── Food diary card ─────────────────────────────────────────────────────────

/// Today's water for the food diary: a small bottle, the total and quick
/// adds. Loads itself; hides when it can't.
class WaterDiaryCard extends StatefulWidget {
  const WaterDiaryCard({super.key});

  @override
  State<WaterDiaryCard> createState() => _WaterDiaryCardState();
}

class _WaterDiaryCardState extends State<WaterDiaryCard> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WaterService.instance.refresh().then((_) {}, onError: (Object _) {
      if (mounted && WaterService.instance.today.value == null) setState(() => _failed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    return ValueListenableBuilder<WaterDay?>(
      valueListenable: WaterService.instance.today,
      builder: (context, day, _) {
        if (day == null) return const SizedBox.shrink();
        final l10n = context.l10n;
        final text = Theme.of(context).textTheme;
        final water = WaterColors.of(context);
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openWaterPage(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  WaterBottle(
                    fraction: day.fraction,
                    percent: day.percent,
                    width: 58,
                    height: 92,
                    semanticLabel: l10n.waterBottleSemantics(
                      waterAmount(l10n, day.totalMl),
                      waterAmount(l10n, day.goalMl),
                      day.percent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.water_drop, size: 18, color: water.water),
                            const SizedBox(width: 6),
                            Text(l10n.waterTitle, style: text.titleMedium),
                            const Spacer(),
                            Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          day.reached
                              ? l10n.waterGoalReached
                              : l10n.waterProgress(waterAmount(l10n, day.totalMl), waterAmount(l10n, day.goalMl)),
                          style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        const WaterQuickAdd(compact: true, alignment: WrapAlignment.start),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Settings ────────────────────────────────────────────────────────────────

/// The Water section of Settings: daily goal (automatic, showing what it
/// works out to, or custom), quick-add cup sizes and reminders.
class WaterSettingsCard extends StatefulWidget {
  const WaterSettingsCard({super.key, required this.settings});

  final UserSettings settings;

  @override
  State<WaterSettingsCard> createState() => _WaterSettingsCardState();
}

class _WaterSettingsCardState extends State<WaterSettingsCard> {
  @override
  void initState() {
    super.initState();
    // For the body weight the automatic goal is worked out from.
    if (WaterService.instance.today.value == null) {
      WaterService.instance.refresh().then((_) {}, onError: (Object _) {});
    }
  }

  Future<void> _save(Future<void> Function() change) async {
    try {
      await change();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.shellSettingsSaveFailed(_errorText(e)))),
      );
    }
  }

  Future<void> _setReminders(bool on) async {
    Haptics.select();
    if (on && !await WaterService.instance.requestPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.waterSettingsPermissionDenied)),
      );
      return;
    }
    await _save(() => SettingsService.instance.update(waterReminders: on));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = widget.settings;
    final water = WaterColors.of(context);
    return ValueListenableBuilder<WaterDay?>(
      valueListenable: WaterService.instance.today,
      builder: (context, day, _) {
        final goal = s.waterGoalFor(day?.weightKg);
        return Card(
          margin: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.water_drop_outlined, color: water.water),
                title: Text(l10n.waterSettingsGoal),
                subtitle: Text(
                  s.waterGoalMl == null
                      ? l10n.waterSettingsGoalAuto(waterAmount(l10n, goal))
                      : l10n.waterSettingsGoalCustom(waterAmount(l10n, goal)),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAppBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => _WaterGoalSheet(autoGoal: UserSettings.defaults.waterGoalFor(day?.weightKg)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.local_drink_outlined),
                title: Text(l10n.waterSettingsCups),
                subtitle: Text(s.waterCups.map((ml) => waterAmount(l10n, ml)).join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAppBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => const _WaterCupsSheet(),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: Text(l10n.waterSettingsReminders),
                subtitle: Text(l10n.waterSettingsRemindersHelp),
                value: s.waterReminders,
                onChanged: _setReminders,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A big number with − / + buttons.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.label,
    required this.onLess,
    required this.onMore,
  });

  final int value;
  final String label;
  final VoidCallback? onLess;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          tooltip: l10n.waterSettingsLess,
          onPressed: onLess,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 140,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.stat(size: 30, weight: FontWeight.w700),
          ),
        ),
        IconButton.filledTonal(
          tooltip: l10n.waterSettingsMore,
          onPressed: onMore,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _WaterGoalSheet extends StatefulWidget {
  const _WaterGoalSheet({required this.autoGoal});

  /// What the automatic goal works out to now.
  final int autoGoal;

  @override
  State<_WaterGoalSheet> createState() => _WaterGoalSheetState();
}

class _WaterGoalSheetState extends State<_WaterGoalSheet> {
  late final UserSettings _s = SettingsService.instance.settings.value;
  late bool _auto = _s.waterGoalMl == null;
  late int _custom = _s.waterGoalMl ?? widget.autoGoal;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await (_auto
          ? SettingsService.instance.update(autoWaterGoal: true)
          : SettingsService.instance.update(waterGoalMl: _custom));
      // The goal moved: today's total is measured against the new one.
      WaterService.instance.refresh().then((_) {}, onError: (Object _) {});
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.shellSettingsSaveFailed(_errorText(e)))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.waterSettingsGoalTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: true, icon: const Icon(Icons.auto_awesome_outlined), label: Text(l10n.waterSettingsUseAuto)),
              ButtonSegment(value: false, icon: const Icon(Icons.edit_outlined), label: Text(l10n.waterSettingsUseCustom)),
            ],
            selected: {_auto},
            onSelectionChanged: (v) => setState(() => _auto = v.first),
          ),
          const SizedBox(height: 20),
          if (_auto)
            Text(
              waterAmount(l10n, widget.autoGoal),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            )
          else
            _Stepper(
              value: _custom,
              label: waterAmount(l10n, _custom),
              onLess: _custom > 500 ? () => setState(() => _custom = math.max(500, _custom - 100)) : null,
              onMore: _custom < 8000 ? () => setState(() => _custom = math.min(8000, _custom + 100)) : null,
            ),
          const SizedBox(height: 8),
          Text(
            _auto ? l10n.waterSettingsGoalAutoHelp : l10n.waterSettingsGoalCustomHelp,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}

class _WaterCupsSheet extends StatefulWidget {
  const _WaterCupsSheet();

  @override
  State<_WaterCupsSheet> createState() => _WaterCupsSheetState();
}

class _WaterCupsSheetState extends State<_WaterCupsSheet> {
  late final List<int> _cups = [...SettingsService.instance.settings.value.waterCups];
  bool _saving = false;

  void _step(int i, int by) => setState(() => _cups[i] = (_cups[i] + by).clamp(50, 2000));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SettingsService.instance.update(waterCups: _cups);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.shellSettingsSaveFailed(_errorText(e)))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final water = WaterColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.waterSettingsCups, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(l10n.waterSettingsCupsHelp, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (var i = 0; i < _cups.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(_cupIcon(_cups[i]), color: water.water),
                  Expanded(
                    child: _Stepper(
                      value: _cups[i],
                      label: waterAmount(l10n, _cups[i]),
                      onLess: _cups[i] > 50 ? () => _step(i, -50) : null,
                      onMore: _cups[i] < 2000 ? () => _step(i, 50) : null,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.waterSettingsRemoveCup,
                    onPressed: _cups.length > 1 ? () => setState(() => _cups.removeAt(i)) : null,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          if (_cups.length < 4)
            TextButton.icon(
              onPressed: () => setState(() => _cups.add(_cups.isEmpty ? 250 : math.min(2000, _cups.last + 250))),
              icon: const Icon(Icons.add),
              label: Text(l10n.waterSettingsAddCup),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}
