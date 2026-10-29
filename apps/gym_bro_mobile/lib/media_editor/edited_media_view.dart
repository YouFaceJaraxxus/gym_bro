import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../l10n/l10n.dart';
import 'editable_media.dart';
import 'media_edit.dart';

/// [child] with [edit]'s color matrix and vignette, laid out at [size] and
/// scaled by [fit] — so the vignette hugs the media, not the box around it.
class _Edited extends StatelessWidget {
  const _Edited({required this.edit, required this.size, required this.fit, required this.child});

  final MediaEdit edit;
  final Size? size;
  final BoxFit fit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget content = edit.hasColorMatrix ? ColorFiltered(colorFilter: ColorFilter.matrix(edit.colorMatrix), child: child) : child;
    if (edit.vignette > 0) {
      content = Stack(fit: StackFit.expand, children: [
        content,
        IgnorePointer(child: CustomPaint(painter: _VignettePainter(edit.vignette))),
      ]);
    }
    if (size == null) return content;
    return ClipRect(
      child: FittedBox(
        fit: fit,
        child: SizedBox(width: size!.width, height: size!.height, child: content),
      ),
    );
  }
}

class _VignettePainter extends CustomPainter {
  _VignettePainter(this.amount);

  final double amount;

  @override
  void paint(Canvas canvas, Size size) => paintVignette(canvas, size, amount);

  @override
  bool shouldRepaint(_VignettePainter old) => old.amount != amount;
}

/// A picked photo as it will be posted.
class EditedImage extends StatelessWidget {
  const EditedImage({super.key, required this.media, this.edit, this.fit = BoxFit.contain, this.cacheWidth, this.semanticLabel});

  final EditableMedia media;

  /// Defaults to the media's own edits.
  final MediaEdit? edit;
  final BoxFit fit;
  final int? cacheWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final w = media.original.width, h = media.original.height;
    final size = w != null && h != null ? Size(w.toDouble(), h.toDouble()) : null;
    return _Edited(
      edit: edit ?? media.edit,
      size: size,
      fit: fit,
      child: Image.file(
        media.original.file,
        fit: size == null ? fit : BoxFit.fill,
        cacheWidth: cacheWidth,
        semanticLabel: semanticLabel,
        gaplessPlayback: true,
      ),
    );
  }
}

/// A video player that loops inside a trim range. Polls the position while
/// playing (the plugin only reports it twice a second), and lets the trim
/// editor scrub frame by frame.
class TrimmedVideoController extends ChangeNotifier {
  TrimmedVideoController(File file) : video = VideoPlayerController.file(file);

  final VideoPlayerController video;
  Duration _start = Duration.zero;
  Duration? _end;
  bool _scrubbing = false;
  bool _ready = false;
  bool _disposed = false;
  Timer? _ticker;
  Duration? _pendingSeek;
  bool _seeking = false;

  /// Current playback position, for the trim playhead.
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);

  bool get ready => _ready;
  bool get isPlaying => video.value.isPlaying;
  Duration get duration => video.value.duration;
  Duration get start => _start;
  Duration get end => _end ?? duration;
  Size get size => video.value.size;

  Future<void> initialize({Duration? start, Duration? end}) async {
    _start = start ?? Duration.zero;
    _end = end;
    try {
      await video.initialize();
    } catch (_) {
      return;
    }
    if (_disposed) return;
    await video.setLooping(false);
    await video.seekTo(_start);
    _ready = true;
    video.addListener(_onVideo);
    notifyListeners();
  }

  void setTrim(Duration? start, Duration? end) {
    _start = start ?? Duration.zero;
    _end = end;
  }

  void _onVideo() {
    if (_disposed) return;
    final playing = video.value.isPlaying;
    if (playing && _ticker == null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
    } else if (!playing && _ticker != null && !_scrubbing) {
      _ticker?.cancel();
      _ticker = null;
    }
    // The plugin stops at the file's end; loop back to the trim start.
    if (!_scrubbing && video.value.isCompleted) {
      video.seekTo(_start).then((_) => video.play());
    }
    notifyListeners();
  }

  Future<void> _tick() async {
    final p = await video.position;
    if (_disposed || p == null) return;
    position.value = p;
    if (!_scrubbing && video.value.isPlaying && (p >= end || p < _start - const Duration(milliseconds: 200))) {
      await video.seekTo(_start);
    }
  }

  Future<void> play() async {
    if (!_ready) return;
    final p = await video.position ?? Duration.zero;
    if (p >= end || p < _start) await video.seekTo(_start);
    await video.play();
  }

  Future<void> pause() => video.pause();

  Future<void> toggle() => isPlaying ? pause() : play();

  /// Shows the frame at [at] while a trim handle is dragged. Seeks are
  /// coalesced so a fast drag doesn't queue hundreds of them.
  Future<void> scrubTo(Duration at) async {
    if (!_ready) return;
    if (!_scrubbing) {
      _scrubbing = true;
      await video.pause();
    }
    position.value = at;
    _pendingSeek = at;
    if (_seeking) return;
    _seeking = true;
    while (_pendingSeek != null && !_disposed) {
      final target = _pendingSeek!;
      _pendingSeek = null;
      await video.seekTo(target);
    }
    _seeking = false;
  }

  /// Ends a scrub: back to the trim start and playing.
  Future<void> endScrub() async {
    _scrubbing = false;
    if (!_ready) return;
    await video.seekTo(_start);
    position.value = _start;
    await video.play();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    video.removeListener(_onVideo);
    video.dispose();
    position.dispose();
    super.dispose();
  }
}

/// A [TrimmedVideoController]'s picture with [edit] applied.
class EditedVideo extends StatelessWidget {
  const EditedVideo({super.key, required this.controller, required this.edit, this.fit = BoxFit.contain});

  final TrimmedVideoController controller;
  final MediaEdit edit;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.ready || controller.size.isEmpty) {
          return const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return ColoredBox(
          color: Colors.black,
          child: _Edited(edit: edit, size: controller.size, fit: fit, child: VideoPlayer(controller.video)),
        );
      },
    );
  }
}

/// A picked video as it will be posted: trimmed, edited, tap to play/pause.
class EditedVideoPreview extends StatefulWidget {
  const EditedVideoPreview({super.key, required this.media, this.fit = BoxFit.contain});

  final EditableMedia media;
  final BoxFit fit;

  @override
  State<EditedVideoPreview> createState() => _EditedVideoPreviewState();
}

class _EditedVideoPreviewState extends State<EditedVideoPreview> {
  late final TrimmedVideoController _c = TrimmedVideoController(widget.media.original.file);

  @override
  void initState() {
    super.initState();
    _c.initialize(start: widget.media.edit.trimStart, end: widget.media.edit.trimEnd);
  }

  @override
  void didUpdateWidget(EditedVideoPreview old) {
    super.didUpdateWidget(old);
    final e = widget.media.edit;
    _c.setTrim(e.trimStart, e.trimEnd);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.feedVideo,
      button: true,
      child: GestureDetector(
        onTap: () => _c.toggle(),
        child: Stack(fit: StackFit.expand, children: [
          EditedVideo(controller: _c, edit: widget.media.edit, fit: widget.fit),
          ListenableBuilder(
            listenable: _c,
            builder: (context, _) => _c.ready && !_c.isPlaying ? const Center(child: PlayBadge()) : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }
}

class PlayBadge extends StatelessWidget {
  const PlayBadge({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: size),
    );
  }
}
