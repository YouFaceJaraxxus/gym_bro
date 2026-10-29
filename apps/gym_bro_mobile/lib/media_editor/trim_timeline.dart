import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'editable_media.dart';

/// Shortest clip a trim can leave.
const kMinTrim = Duration(seconds: 1);

enum _Drag { start, end, window }

/// A filmstrip with a draggable start and end handle (and the window
/// between them). While a handle moves, [onScrub] reports the time under
/// it so the player can show that frame — the cut is previewed live.
class TrimTimeline extends StatefulWidget {
  const TrimTimeline({
    super.key,
    required this.file,
    required this.duration,
    required this.start,
    required this.end,
    required this.position,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onScrub,
  });

  final File file;
  final Duration duration;
  final Duration start;
  final Duration end;
  final ValueListenable<Duration> position;
  final VoidCallback onChangeStart;
  final void Function(Duration start, Duration end) onChanged;
  final VoidCallback onChangeEnd;
  final ValueChanged<Duration> onScrub;

  @override
  State<TrimTimeline> createState() => _TrimTimelineState();
}

class _TrimTimelineState extends State<TrimTimeline> {
  static const _handle = 18.0;
  static const _height = 56.0;
  static const _frames = 10;

  late Future<List<Uint8List>> _thumbs;
  _Drag? _drag;
  double _dragAnchor = 0;
  Duration _anchorStart = Duration.zero;
  Duration _anchorEnd = Duration.zero;

  @override
  void initState() {
    super.initState();
    _thumbs = VideoFrames.of(widget.file, widget.duration, _frames);
  }

  @override
  void didUpdateWidget(TrimTimeline old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) _thumbs = VideoFrames.of(widget.file, widget.duration, _frames);
  }

  Duration get _minLength => widget.duration < kMinTrim ? widget.duration : kMinTrim;

  void _begin(_Drag drag, double x) {
    _drag = drag;
    _dragAnchor = x;
    _anchorStart = widget.start;
    _anchorEnd = widget.end;
    widget.onChangeStart();
  }

  void _update(double x, double trackWidth) {
    final total = widget.duration.inMicroseconds;
    if (_drag == null || total == 0 || trackWidth <= 0) return;
    final delta = Duration(microseconds: ((x - _dragAnchor) / trackWidth * total).round());
    var start = _anchorStart, end = _anchorEnd;
    switch (_drag!) {
      case _Drag.start:
        start = _clamp(_anchorStart + delta, Duration.zero, end - _minLength);
        widget.onScrub(start);
      case _Drag.end:
        end = _clamp(_anchorEnd + delta, start + _minLength, widget.duration);
        widget.onScrub(end);
      case _Drag.window:
        final length = _anchorEnd - _anchorStart;
        start = _clamp(_anchorStart + delta, Duration.zero, widget.duration - length);
        end = start + length;
        widget.onScrub(start);
    }
    widget.onChanged(start, end);
  }

  void _finish() {
    if (_drag == null) return;
    _drag = null;
    widget.onChangeEnd();
  }

  static Duration _clamp(Duration v, Duration lo, Duration hi) => v < lo ? lo : (v > hi ? hi : v);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return LayoutBuilder(builder: (context, constraints) {
      final track = constraints.maxWidth - _handle * 2;
      final total = math.max(1, widget.duration.inMicroseconds);
      double xOf(Duration d) => _handle + d.inMicroseconds / total * track;
      final left = xOf(widget.start), right = xOf(widget.end);
      return SizedBox(
        height: _height + 8,
        child: Stack(clipBehavior: Clip.none, children: [
          // Filmstrip.
          Positioned(
            left: _handle,
            right: _handle,
            top: 4,
            height: _height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: FutureBuilder<List<Uint8List>>(
                future: _thumbs,
                builder: (context, snap) {
                  final frames = snap.data ?? const [];
                  if (frames.isEmpty) return ColoredBox(color: Colors.white.withValues(alpha: 0.12));
                  return Row(children: [
                    for (final f in frames) Expanded(child: Image.memory(f, fit: BoxFit.cover, height: _height, gaplessPlayback: true)),
                  ]);
                },
              ),
            ),
          ),
          // Dim what gets cut.
          Positioned(left: _handle, width: math.max(0, left - _handle), top: 4, height: _height, child: const ColoredBox(color: Colors.black54)),
          Positioned(left: right, right: _handle, top: 4, height: _height, child: const ColoredBox(color: Colors.black54)),
          // Selection frame; dragging inside moves the whole window.
          Positioned(
            left: left,
            width: math.max(0, right - left),
            top: 4,
            height: _height,
            child: Semantics(
              label: l10n.mediaTrimWindow,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (d) => _begin(_Drag.window, d.globalPosition.dx),
                onHorizontalDragUpdate: (d) => _update(d.globalPosition.dx, track),
                onHorizontalDragEnd: (_) => _finish(),
                onHorizontalDragCancel: _finish,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.symmetric(horizontal: BorderSide(color: cs.primary, width: 3)),
                  ),
                ),
              ),
            ),
          ),
          // Playhead.
          ValueListenableBuilder<Duration>(
            valueListenable: widget.position,
            builder: (context, p, _) {
              final x = xOf(_clamp(p, widget.start, widget.end));
              return Positioned(
                left: x - 1,
                top: 0,
                height: _height + 8,
                width: 2,
                child: const IgnorePointer(child: ColoredBox(color: Colors.white)),
              );
            },
          ),
          _handleAt(left - _handle, isStart: true, track: track, color: cs.primary, label: l10n.mediaTrimStart),
          _handleAt(right, isStart: false, track: track, color: cs.primary, label: l10n.mediaTrimEnd),
        ]),
      );
    });
  }

  Widget _handleAt(double x, {required bool isStart, required double track, required Color color, required String label}) {
    return Positioned(
      left: x,
      top: 4,
      width: _handle,
      height: _height,
      child: Semantics(
        label: label,
        slider: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _begin(isStart ? _Drag.start : _Drag.end, d.globalPosition.dx),
          onHorizontalDragUpdate: (d) => _update(d.globalPosition.dx, track),
          onHorizontalDragEnd: (_) => _finish(),
          onHorizontalDragCancel: _finish,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.horizontal(
                left: isStart ? const Radius.circular(6) : Radius.zero,
                right: isStart ? Radius.zero : const Radius.circular(6),
              ),
            ),
            child: Icon(isStart ? Icons.chevron_left : Icons.chevron_right, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
