import 'package:flutter/material.dart';

/// A tiny trend line (no axes) with the latest point marked.
/// Draws nothing meaningful for fewer than two values.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final double width;
  final double height;
  final Color? color;

  /// Screen-reader summary (e.g. "Trend, last value 102.5 kg"). When null the
  /// sparkline is treated as decorative and hidden from semantics.
  final String? semanticLabel;

  const Sparkline({
    super.key,
    required this.values,
    this.width = 64,
    this.height = 24,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final chart = SizedBox(
      width: width,
      height: height,
      child: values.length < 2
          ? Center(
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            )
          : CustomPaint(painter: _SparklinePainter(values, c)),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: chart);
    return Semantics(
      label: semanticLabel,
      image: true,
      child: ExcludeSemantics(child: chart),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 3.0;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    Offset at(int i) =>
        Offset(pad + w * i / (values.length - 1), pad + h - (values[i] - minV) / span * h);

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(at(values.length - 1).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();

    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(at(values.length - 1), 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.color != color || old.values != values;
}
