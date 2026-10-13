import 'package:intl/intl.dart';

// Barbell plate math. Pure functions: no Flutter imports, unit-agnostic
// (pass kg plates with kg targets, lb plates with lb targets).

/// Standard plate sets (largest first).
const List<double> kgPlates = [25, 20, 15, 10, 5, 2.5, 1.25];
const List<double> lbPlates = [45, 35, 25, 10, 5, 2.5];

/// Standard bar weights per unit.
const List<double> kgBars = [20, 15];
const List<double> lbBars = [45, 35];

/// How to load a bar for a target weight.
class PlateLoad {
  /// Requested total weight.
  final double target;

  /// Bar weight.
  final double bar;

  /// Plates for ONE side, largest first.
  final List<double> platesPerSide;

  /// Total actually on the bar: bar + 2 × sum(platesPerSide).
  final double achievable;

  const PlateLoad({
    required this.target,
    required this.bar,
    required this.platesPerSide,
    required this.achievable,
  });

  /// True when [achievable] equals [target] (to 0.01).
  bool get isExact => (achievable - target).abs() < 0.005;

  /// achievable − target (negative when lighter than requested).
  double get difference => achievable - target;

  /// Per-side plate counts, e.g. {25: 1, 15: 1}, largest first.
  Map<double, int> get countsPerSide {
    final out = <double, int>{};
    for (final p in platesPerSide) {
      out[p] = (out[p] ?? 0) + 1;
    }
    return out;
  }
}

const int _scale = 100; // work in hundredths to avoid float drift

int _toUnits(double v) => (v * _scale).round();
double _fromUnits(int u) => u / _scale;

int _gcd(int a, int b) {
  while (b != 0) {
    final t = b;
    b = a % b;
    a = t;
  }
  return a.abs();
}

/// Plates per side for [target] on a [bar], using unlimited pairs of [plates].
///
/// When the target can't be loaded exactly, picks the closest achievable
/// weight (ties go to the lighter option) and the fewest plates for it.
/// Targets at or below the bar return an empty bar.
PlateLoad calculatePlates({
  required double target,
  required double bar,
  List<double> plates = kgPlates,
}) {
  final usable = plates.where((p) => p > 0).map(_toUnits).toSet().toList()
    ..sort((a, b) => b.compareTo(a));
  final perSide = (target - bar) / 2;
  if (perSide <= 0 || usable.isEmpty) {
    return PlateLoad(target: target, bar: bar, platesPerSide: const [], achievable: bar);
  }

  // Work in multiples of the plates' common divisor.
  final step = usable.reduce(_gcd);
  final want = _toUnits(target - bar) / 2 / step; // fractional target in steps
  final coins = usable.map((p) => p ~/ step).toList();
  final limit = want.ceil() + coins.first; // never need to go past this

  // Fewest plates to reach every sum 0..limit (−1 = unreachable).
  final best = List<int>.filled(limit + 1, -1);
  final via = List<int>.filled(limit + 1, 0);
  best[0] = 0;
  for (var s = 1; s <= limit; s++) {
    for (final c in coins) {
      if (c <= s && best[s - c] >= 0 && (best[s] < 0 || best[s - c] + 1 < best[s])) {
        best[s] = best[s - c] + 1;
        via[s] = c;
      }
    }
  }

  // Closest reachable sum to `want`; ties → lighter.
  var chosen = 0;
  var bestDist = double.infinity;
  for (var s = 0; s <= limit; s++) {
    if (best[s] < 0) continue;
    final dist = (s - want).abs();
    if (dist < bestDist - 1e-9) {
      bestDist = dist;
      chosen = s;
    }
  }

  final picked = <double>[];
  for (var s = chosen; s > 0; s -= via[s]) {
    picked.add(_fromUnits(via[s] * step));
  }
  picked.sort((a, b) => b.compareTo(a));
  final total = bar + 2 * _fromUnits(chosen * step);
  return PlateLoad(
    target: target,
    bar: bar,
    platesPerSide: List.unmodifiable(picked),
    achievable: double.parse(total.toStringAsFixed(2)),
  );
}

/// One suggested warm-up set.
class WarmupSet {
  /// Fraction of the working weight, e.g. 0.4.
  final double percent;
  final int reps;

  /// Rounded to a loadable weight (never below the bar).
  final double weight;
  final PlateLoad load;

  const WarmupSet({
    required this.percent,
    required this.reps,
    required this.weight,
    required this.load,
  });
}

/// Default ramp: ≈40 % × 8, 60 % × 5, 80 % × 3.
const List<(double, int)> defaultWarmupScheme = [(0.4, 8), (0.6, 5), (0.8, 3)];

/// Warm-up sets for [workingWeight], each rounded to the closest weight that
/// can be loaded with [plates] on [bar].
List<WarmupSet> warmupSets({
  required double workingWeight,
  required double bar,
  List<double> plates = kgPlates,
  List<(double, int)> scheme = defaultWarmupScheme,
}) {
  if (workingWeight <= 0) return const [];
  return [
    for (final (pct, reps) in scheme)
      () {
        final load = calculatePlates(target: workingWeight * pct, bar: bar, plates: plates);
        return WarmupSet(percent: pct, reps: reps, weight: load.achievable, load: load);
      }(),
  ];
}

/// "62.5" / "60" — trims trailing zeros.
/// "2.5", "20", "1.25" — or with [locale], that locale's decimal separator
/// ("2,5" in Serbian).
String formatPlateWeight(double v, [String? locale]) {
  if (locale != null) {
    return (NumberFormat.decimalPattern(locale)
          ..minimumFractionDigits = 0
          ..maximumFractionDigits = 2)
        .format(v);
  }
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}
