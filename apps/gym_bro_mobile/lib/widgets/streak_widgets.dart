import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/streak.dart';

/// Building blocks for workout streaks: the tier gems (on avatars, the
/// profile shelf and the streak screen), the flame with the count, the
/// freeze cubes and the streak chip.

// ── Tier look ─────────────────────────────────────────────────────────────────

extension StreakTierLook on StreakTier {
  /// Main facet colour.
  Color get color => switch (this) {
        StreakTier.bronze => const Color(0xFFC77B3A),
        StreakTier.silver => const Color(0xFFA9B4BE),
        StreakTier.gold => const Color(0xFFF2B921),
        StreakTier.ruby => const Color(0xFFD7194F),
        StreakTier.emerald => const Color(0xFF14A86B),
        StreakTier.sapphire => const Color(0xFF2456D6),
        StreakTier.diamond => const Color(0xFF8FDDF2),
      };

  /// Lit facets.
  Color get light => switch (this) {
        StreakTier.bronze => const Color(0xFFF0B37E),
        StreakTier.silver => const Color(0xFFEFF3F7),
        StreakTier.gold => const Color(0xFFFFE795),
        StreakTier.ruby => const Color(0xFFFF7FA3),
        StreakTier.emerald => const Color(0xFF7AF0BC),
        StreakTier.sapphire => const Color(0xFF86AEFF),
        StreakTier.diamond => const Color(0xFFFFFFFF),
      };

  /// Shadowed facets and the outline.
  Color get dark => switch (this) {
        StreakTier.bronze => const Color(0xFF7E4519),
        StreakTier.silver => const Color(0xFF66717C),
        StreakTier.gold => const Color(0xFFA9740A),
        StreakTier.ruby => const Color(0xFF8A0C33),
        StreakTier.emerald => const Color(0xFF07623D),
        StreakTier.sapphire => const Color(0xFF102F86),
        StreakTier.diamond => const Color(0xFF4FA6C4),
      };

  String label(AppLocalizations l10n) => switch (this) {
        StreakTier.bronze => l10n.streakTierBronze,
        StreakTier.silver => l10n.streakTierSilver,
        StreakTier.gold => l10n.streakTierGold,
        StreakTier.ruby => l10n.streakTierRuby,
        StreakTier.emerald => l10n.streakTierEmerald,
        StreakTier.sapphire => l10n.streakTierSapphire,
        StreakTier.diamond => l10n.streakTierDiamond,
      };
}

// ── Gem ───────────────────────────────────────────────────────────────────────

/// A cut gem in [tier]'s colours. [locked] draws it greyed out (badges not
/// earned yet); [shimmer] sweeps a glint across it now and then.
class StreakGem extends StatefulWidget {
  final StreakTier tier;
  final double size;
  final bool locked;
  final bool shimmer;

  const StreakGem({super.key, required this.tier, this.size = 24, this.locked = false, this.shimmer = false});

  @override
  State<StreakGem> createState() => _StreakGemState();
}

class _StreakGemState extends State<StreakGem> with SingleTickerProviderStateMixin {
  AnimationController? _glint;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(StreakGem old) {
    super.didUpdateWidget(old);
    if (old.shimmer != widget.shimmer || old.locked != widget.locked) _sync();
  }

  void _sync() {
    final on = widget.shimmer && !widget.locked;
    if (on && _glint == null) {
      _glint = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    } else if (!on && _glint != null) {
      _glint!.dispose();
      _glint = null;
    }
  }

  @override
  void dispose() {
    _glint?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(widget.size, widget.size * 0.9);
    final glint = _glint;
    final cs = Theme.of(context).colorScheme;
    if (glint == null || MediaQuery.of(context).disableAnimations) {
      return CustomPaint(size: size, painter: _GemPainter(widget.tier, widget.locked, cs.outline));
    }
    return AnimatedBuilder(
      animation: glint,
      builder: (_, _) => CustomPaint(size: size, painter: _GemPainter(widget.tier, false, cs.outline, glint.value)),
    );
  }
}

class _GemPainter extends CustomPainter {
  final StreakTier tier;
  final bool locked;
  final Color lockedColor;

  /// 0…1 position of the glint over its cycle (it crosses during the first 40%).
  final double? glint;

  _GemPainter(this.tier, this.locked, this.lockedColor, [this.glint]);

  @override
  void paint(Canvas canvas, Size s) {
    Offset p(double x, double y) => Offset(x * s.width, y * s.height);
    Path poly(List<Offset> pts) => Path()..addPolygon(pts, true);

    final base = locked ? lockedColor.withValues(alpha: 0.35) : tier.color;
    final light = locked ? lockedColor.withValues(alpha: 0.22) : tier.light;
    final dark = locked ? lockedColor.withValues(alpha: 0.55) : tier.dark;
    final mid = Color.lerp(base, light, 0.45)!;

    final outline = poly([p(0.22, 0.10), p(0.78, 0.10), p(1, 0.38), p(0.5, 0.98), p(0, 0.38)]);
    final facets = <(Path, Color)>[
      (poly([p(0.22, 0.10), p(0.40, 0.10), p(0.28, 0.38), p(0, 0.38)]), light),
      (poly([p(0.40, 0.10), p(0.60, 0.10), p(0.72, 0.38), p(0.28, 0.38)]), mid),
      (poly([p(0.60, 0.10), p(0.78, 0.10), p(1, 0.38), p(0.72, 0.38)]), base),
      (poly([p(0, 0.38), p(0.28, 0.38), p(0.5, 0.98)]), base),
      (poly([p(0.28, 0.38), p(0.72, 0.38), p(0.5, 0.98)]), mid),
      (poly([p(0.72, 0.38), p(1, 0.38), p(0.5, 0.98)]), dark),
    ];
    for (final (path, color) in facets) {
      canvas.drawPath(path, Paint()..color = color);
    }

    // Diamonds catch a little rainbow.
    if (!locked && tier == StreakTier.diamond) {
      canvas.drawPath(
        outline,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x33FF8AD8), Color(0x2296F7FF), Color(0x33FFE38A)],
          ).createShader(Offset.zero & s),
      );
    }

    final g = glint;
    if (g != null && g < 0.4) {
      final t = g / 0.4;
      final x = -0.6 + t * 2.2;
      canvas.save();
      canvas.clipPath(outline);
      canvas.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(x - 0.35, -1),
            end: Alignment(x + 0.35, 1),
            colors: const [Color(0x00FFFFFF), Color(0xAAFFFFFF), Color(0x00FFFFFF)],
          ).createShader(Offset.zero & s),
      );
      canvas.restore();
    }

    final stroke = (s.width * 0.045).clamp(0.8, 2.5);
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke
        ..color = dark,
    );
    if (!locked && s.width >= 18) {
      // A sparkle on the lit facet.
      final c = p(0.24, 0.24);
      final r = s.width * 0.07;
      final sparkle = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = s.width * 0.03
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), sparkle);
      canvas.drawLine(c - Offset(0, r), c + Offset(0, r), sparkle);
    }
  }

  @override
  bool shouldRepaint(_GemPainter old) =>
      old.tier != tier || old.locked != locked || old.glint != glint || old.lockedColor != lockedColor;
}

/// The gem in a small round badge, for the corner of an avatar.
class StreakGemBadge extends StatelessWidget {
  final StreakTier tier;
  final double size;

  const StreakGemBadge({super.key, required this.tier, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: StreakGem(tier: tier, size: size * 0.74),
    );
  }
}

// ── Flame ─────────────────────────────────────────────────────────────────────

const kFlameGradient = LinearGradient(
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
  colors: [Color(0xFFE53935), Color(0xFFFF7A1A), Color(0xFFFFD54F)],
);

/// The streak flame; grey while there's no streak.
class StreakFlame extends StatelessWidget {
  final double size;
  final bool lit;

  const StreakFlame({super.key, this.size = 24, this.lit = true});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.local_fire_department_rounded, size: size, color: Colors.white);
    if (!lit) {
      return Icon(Icons.local_fire_department_rounded, size: size, color: Theme.of(context).colorScheme.outline);
    }
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => kFlameGradient.createShader(r),
      child: icon,
    );
  }
}

/// Banked freezes as ice cubes: [freezes] filled out of [max].
class FreezeCubes extends StatelessWidget {
  final int freezes;
  final int max;
  final double size;

  const FreezeCubes({super.key, required this.freezes, this.max = 2, this.size = 20});

  static const iceColor = Color(0xFF4FC3F7);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Padding(
            padding: EdgeInsets.only(right: i == max - 1 ? 0 : size * 0.2),
            child: Icon(
              Icons.ac_unit_rounded,
              size: size,
              color: i < freezes ? iceColor : cs.outlineVariant,
            ),
          ),
      ],
    );
  }
}

/// A pill with the flame, the count and the tier gem.
class StreakChip extends StatelessWidget {
  final int current;
  final StreakTier? tier;
  final String? trailing;
  final VoidCallback? onTap;

  const StreakChip({super.key, required this.current, this.tier, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lit = current > 0;
    return Material(
      color: lit ? const Color(0xFFFF7A1A).withValues(alpha: 0.12) : cs.surfaceContainerHigh,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreakFlame(size: 18, lit: lit),
              const SizedBox(width: 4),
              Text(
                '$current',
                style: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (tier != null) ...[
                const SizedBox(width: 6),
                StreakGem(tier: tier!, size: 16),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    trailing!,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
