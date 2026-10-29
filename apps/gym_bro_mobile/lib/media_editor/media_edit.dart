import 'dart:math' as math;

/// Instagram-style adjustments. Every one maps to a color matrix except
/// [vignette], which darkens the edges (an overlay), so photo and video
/// exports look exactly like the preview.
enum Adjustment {
  brightness,
  contrast,
  saturation,
  warmth,
  tint,
  fade,
  vignette;

  /// Fade and vignette go 0…1; the others −1…1 around 0.
  bool get isOneSided => this == fade || this == vignette;
  double get min => isOneSided ? 0 : -1;
}

/// A look preset: a color matrix the user can dial from 0 to 100 %.
class FilterPreset {
  final String id;
  final List<double> matrix;

  const FilterPreset._(this.id, this.matrix);

  static final none = FilterPreset._('normal', ColorMatrix.identity);

  static final all = <FilterPreset>[
    none,
    FilterPreset._('vivid', ColorMatrix.chain([ColorMatrix.saturation(0.35), ColorMatrix.contrast(0.15)])),
    FilterPreset._('punch', ColorMatrix.chain([ColorMatrix.contrast(0.4), ColorMatrix.saturation(0.25)])),
    FilterPreset._('golden', ColorMatrix.chain([ColorMatrix.warmth(0.55), ColorMatrix.saturation(0.1), ColorMatrix.brightness(0.05)])),
    FilterPreset._('arctic', ColorMatrix.chain([ColorMatrix.warmth(-0.5), ColorMatrix.tint(-0.1), ColorMatrix.contrast(0.05)])),
    FilterPreset._('rose', ColorMatrix.chain([ColorMatrix.tint(0.3), ColorMatrix.warmth(0.15), ColorMatrix.fade(0.2)])),
    FilterPreset._('vintage', ColorMatrix.chain([ColorMatrix.saturation(-0.25), ColorMatrix.warmth(0.35), ColorMatrix.contrast(-0.1), ColorMatrix.fade(0.5)])),
    FilterPreset._('matte', ColorMatrix.chain([ColorMatrix.contrast(-0.15), ColorMatrix.saturation(-0.1), ColorMatrix.fade(0.6)])),
    FilterPreset._('dramatic', ColorMatrix.chain([ColorMatrix.saturation(-0.35), ColorMatrix.contrast(0.3), ColorMatrix.brightness(-0.08)])),
    FilterPreset._('sepia', ColorMatrix.sepia),
    FilterPreset._('mono', ColorMatrix.chain([ColorMatrix.saturation(-1), ColorMatrix.contrast(0.1)])),
    FilterPreset._('noir', ColorMatrix.chain([ColorMatrix.saturation(-1), ColorMatrix.contrast(0.45), ColorMatrix.brightness(-0.05)])),
  ];

  static FilterPreset byId(String id) => all.firstWhere((f) => f.id == id, orElse: () => none);
}

/// 4×5 color matrices in Flutter's `ColorFilter.matrix` layout (row-major,
/// offsets in 0…255) — the same layout pro_video_editor applies to video.
abstract final class ColorMatrix {
  static const identity = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  static const sepia = <double>[
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0, //
    0.272, 0.534, 0.131, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  static List<double> _scaleOffset(double r, double g, double b, double ro, double go, double bo) => [
    r, 0, 0, 0, ro, //
    0, g, 0, 0, go, //
    0, 0, b, 0, bo, //
    0, 0, 0, 1, 0, //
  ];

  static List<double> brightness(double v) => _scaleOffset(1 + 0.15 * v, 1 + 0.15 * v, 1 + 0.15 * v, 30 * v, 30 * v, 30 * v);

  static List<double> contrast(double v) {
    final s = v >= 0 ? 1 + 0.6 * v : 1 + 0.45 * v;
    final o = 127.5 * (1 - s);
    return _scaleOffset(s, s, s, o, o, o);
  }

  /// Rec. 709 luma weights; −1 is grayscale, 1 doubles saturation.
  static List<double> saturation(double v) {
    final s = 1 + v;
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final i = 1 - s;
    return [
      lr * i + s, lg * i, lb * i, 0, 0, //
      lr * i, lg * i + s, lb * i, 0, 0, //
      lr * i, lg * i, lb * i + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// Positive is warmer (amber), negative cooler (blue).
  static List<double> warmth(double v) => _scaleOffset(1 + 0.12 * v, 1, 1 - 0.12 * v, 10 * v, 0, -10 * v);

  /// Positive is magenta, negative green.
  static List<double> tint(double v) => _scaleOffset(1, 1 - 0.1 * v, 1, 0, -8 * v, 0);

  /// Lifts the blacks and softens the highlights (0…1).
  static List<double> fade(double v) => _scaleOffset(1 - 0.22 * v, 1 - 0.22 * v, 1 - 0.22 * v, 30 * v, 30 * v, 30 * v);

  /// `b` applied after `a`.
  static List<double> then(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        var sum = col == 4 ? b[row * 5 + 4] : 0.0;
        for (var k = 0; k < 4; k++) {
          sum += b[row * 5 + k] * a[k * 5 + col];
        }
        out[row * 5 + col] = sum;
      }
    }
    return out;
  }

  /// Applies the matrices in order.
  static List<double> chain(List<List<double>> matrices) => matrices.fold(identity, then);

  /// `identity` at 0, `m` at 1.
  static List<double> blend(List<double> m, double amount) =>
      [for (var i = 0; i < 20; i++) identity[i] + (m[i] - identity[i]) * amount];

  static bool isIdentity(List<double> m) {
    for (var i = 0; i < 20; i++) {
      if ((m[i] - identity[i]).abs() > 1e-6) return false;
    }
    return true;
  }
}

/// Non-destructive edits on one photo or video: a filter at some strength,
/// adjustments and (videos) a trim. The original file is never touched;
/// the edits are baked in only when the media is uploaded.
class MediaEdit {
  final String filter;

  /// 0…1, how much of [filter] to apply.
  final double filterStrength;
  final Map<Adjustment, double> adjust;
  final Duration? trimStart;
  final Duration? trimEnd;

  const MediaEdit({
    this.filter = 'normal',
    this.filterStrength = 1,
    this.adjust = const {},
    this.trimStart,
    this.trimEnd,
  });

  static const none = MediaEdit();

  double value(Adjustment a) => adjust[a] ?? 0;
  double get vignette => value(Adjustment.vignette);
  bool get hasFilter => filter != 'normal' && filterStrength > 0;
  bool get hasTrim => (trimStart ?? Duration.zero) > Duration.zero || trimEnd != null;
  bool get hasLook => hasFilter || adjust.values.any((v) => v != 0);
  bool get isIdentity => !hasLook && !hasTrim;

  /// Filter, then brightness → contrast → saturation → warmth → tint → fade.
  List<double> get colorMatrix => ColorMatrix.chain([
    if (hasFilter) ColorMatrix.blend(FilterPreset.byId(filter).matrix, filterStrength),
    if (value(Adjustment.brightness) != 0) ColorMatrix.brightness(value(Adjustment.brightness)),
    if (value(Adjustment.contrast) != 0) ColorMatrix.contrast(value(Adjustment.contrast)),
    if (value(Adjustment.saturation) != 0) ColorMatrix.saturation(value(Adjustment.saturation)),
    if (value(Adjustment.warmth) != 0) ColorMatrix.warmth(value(Adjustment.warmth)),
    if (value(Adjustment.tint) != 0) ColorMatrix.tint(value(Adjustment.tint)),
    if (value(Adjustment.fade) != 0) ColorMatrix.fade(value(Adjustment.fade)),
  ]);

  bool get hasColorMatrix => !ColorMatrix.isIdentity(colorMatrix);

  MediaEdit withFilter(String id, double strength) =>
      MediaEdit(filter: id, filterStrength: strength, adjust: adjust, trimStart: trimStart, trimEnd: trimEnd);

  MediaEdit withAdjustment(Adjustment a, double v) => MediaEdit(
    filter: filter,
    filterStrength: filterStrength,
    adjust: {...adjust, a: v}..removeWhere((_, value) => value == 0),
    trimStart: trimStart,
    trimEnd: trimEnd,
  );

  /// `null` end means "to the end of the video".
  MediaEdit withTrim(Duration? start, Duration? end) =>
      MediaEdit(filter: filter, filterStrength: filterStrength, adjust: adjust, trimStart: start, trimEnd: end);

  /// This edit's trim with [other]'s filter and adjustments.
  MediaEdit withLookOf(MediaEdit other) =>
      MediaEdit(filter: other.filter, filterStrength: other.filterStrength, adjust: other.adjust, trimStart: trimStart, trimEnd: trimEnd);

  /// Same filter and adjustments (ignores trim).
  bool sameLook(MediaEdit other) =>
      filter == other.filter &&
      filterStrength == other.filterStrength &&
      adjust.length == other.adjust.length &&
      adjust.entries.every((e) => other.adjust[e.key] == e.value);

  @override
  bool operator ==(Object other) =>
      other is MediaEdit && sameLook(other) && trimStart == other.trimStart && trimEnd == other.trimEnd;

  @override
  int get hashCode => Object.hash(filter, filterStrength, Object.hashAllUnordered(adjust.entries.map((e) => Object.hash(e.key, e.value))), trimStart, trimEnd);

  Map<String, dynamic> toJson() => {
    if (hasFilter) 'filter': filter,
    if (hasFilter) 'filter_strength': filterStrength,
    if (adjust.isNotEmpty) 'adjust': {for (final e in adjust.entries) e.key.name: e.value},
    if (trimStart != null && trimStart! > Duration.zero) 'trim_start_ms': trimStart!.inMilliseconds,
    if (trimEnd != null) 'trim_end_ms': trimEnd!.inMilliseconds,
  };

  factory MediaEdit.fromJson(Map<String, dynamic>? json) {
    if (json == null) return none;
    double clamp(Object? v, double lo) => (double.tryParse(v.toString()) ?? 0).clamp(lo, 1).toDouble();
    final adjust = <Adjustment, double>{};
    final raw = json['adjust'];
    if (raw is Map) {
      for (final a in Adjustment.values) {
        final v = raw[a.name];
        if (v != null && clamp(v, a.min) != 0) adjust[a] = clamp(v, a.min);
      }
    }
    final start = int.tryParse('${json['trim_start_ms']}');
    final end = int.tryParse('${json['trim_end_ms']}');
    return MediaEdit(
      filter: FilterPreset.byId('${json['filter']}').id,
      filterStrength: json['filter_strength'] == null ? 1 : clamp(json['filter_strength'], 0),
      adjust: adjust,
      trimStart: start == null || start <= 0 ? null : Duration(milliseconds: start),
      trimEnd: end == null || end <= 0 ? null : Duration(milliseconds: math.max(end, (start ?? 0) + 1)),
    );
  }
}

/// One setting the user can undo or reset on its own.
sealed class EditSetting {
  const EditSetting();
}

class FilterSetting extends EditSetting {
  const FilterSetting();
  @override
  bool operator ==(Object other) => other is FilterSetting;
  @override
  int get hashCode => 1;
}

class AdjustSetting extends EditSetting {
  final Adjustment adjustment;
  const AdjustSetting(this.adjustment);
  @override
  bool operator ==(Object other) => other is AdjustSetting && other.adjustment == adjustment;
  @override
  int get hashCode => Object.hash(2, adjustment);
}

class TrimSetting extends EditSetting {
  const TrimSetting();
  @override
  bool operator ==(Object other) => other is TrimSetting;
  @override
  int get hashCode => 3;
}

/// Per-setting undo stacks. Each entry is the whole [MediaEdit] before a
/// change to that setting; undoing restores only that setting from it.
class EditHistory {
  final Map<EditSetting, List<MediaEdit>> _stacks = {};

  bool canUndo(EditSetting s) => _stacks[s]?.isNotEmpty ?? false;

  /// Records [before] as the state to go back to, unless [s] didn't change.
  void record(EditSetting s, MediaEdit before, MediaEdit after) {
    if (settingEquals(s, before, after)) return;
    (_stacks[s] ??= []).add(before);
  }

  /// [current] with [s] stepped back one change.
  MediaEdit undo(EditSetting s, MediaEdit current) {
    final previous = _stacks[s]!.removeLast();
    return applySetting(s, from: previous, to: current);
  }

  /// [to] with [s] taken from [from].
  static MediaEdit applySetting(EditSetting s, {required MediaEdit from, required MediaEdit to}) => switch (s) {
    FilterSetting() => to.withFilter(from.filter, from.filterStrength),
    AdjustSetting(:final adjustment) => to.withAdjustment(adjustment, from.value(adjustment)),
    TrimSetting() => to.withTrim(from.trimStart, from.trimEnd),
  };

  static bool settingEquals(EditSetting s, MediaEdit a, MediaEdit b) => switch (s) {
    FilterSetting() => a.filter == b.filter && (!a.hasFilter || a.filterStrength == b.filterStrength),
    AdjustSetting(:final adjustment) => a.value(adjustment) == b.value(adjustment),
    TrimSetting() => a.trimStart == b.trimStart && a.trimEnd == b.trimEnd,
  };

  /// [current] with [s] back at its default (no filter, 0, untrimmed).
  static MediaEdit reset(EditSetting s, MediaEdit current) => applySetting(s, from: MediaEdit.none, to: current);
}
