import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../l10n/l10n.dart';
import '../services/media_upload.dart';
import 'app_bottom_sheet.dart';

/// Shared building blocks for people, chat and posts: avatars with an
/// online dot, the "typing…" dots, private-media images/videos and the
/// camera/gallery/file picker.

// ── Avatar ────────────────────────────────────────────────────────────────────

class UserAvatar extends StatelessWidget {
  final String? url;
  final String initials;
  final double radius;

  /// Green dot at the bottom right (active now).
  final bool online;

  const UserAvatar({super.key, this.url, required this.initials, this.radius = 20, this.online = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      foregroundImage: url == null || url!.isEmpty ? null : NetworkImage(url!),
      child: Text(
        initials,
        style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600, fontSize: radius * 0.7),
      ),
    );
    if (!online) return avatar;
    final dot = (radius * 0.55).clamp(8.0, 16.0);
    return Stack(clipBehavior: Clip.none, children: [
      avatar,
      Positioned(
        right: -1,
        bottom: -1,
        child: Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(
            color: const Color(0xFF2EB86B),
            shape: BoxShape.circle,
            border: Border.all(color: cs.surface, width: 2),
          ),
        ),
      ),
    ]);
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

/// Three bouncing dots in a bubble, like iMessage / Messenger.
class TypingDots extends StatefulWidget {
  final Color? color;
  final double dotSize;

  const TypingDots({super.key, this.color, this.dotSize = 7});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.25),
              child: Transform.translate(
                offset: Offset(0, -_bounce((_c.value - i * 0.15) % 1) * widget.dotSize * 0.8),
                child: Opacity(
                  opacity: 0.4 + 0.6 * _bounce((_c.value - i * 0.15) % 1),
                  child: Container(
                    width: widget.dotSize,
                    height: widget.dotSize,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 0 → 1 → 0 over the first half of the cycle, rest still.
  static double _bounce(double t) {
    if (t < 0 || t > 0.5) return 0;
    final x = t / 0.5;
    return x < 0.5 ? Curves.easeOut.transform(x * 2) : Curves.easeIn.transform((1 - x) * 2);
  }
}

/// [TypingDots] in a chat bubble.
class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: const TypingDots(),
    );
  }
}

// ── Private media ─────────────────────────────────────────────────────────────

/// A network image cached by its URL *without* the query string, so a
/// re-signed URL (new token, same file) hits the image cache instead of
/// re-downloading and flickering.
class StableNetworkImage extends ImageProvider<StableNetworkImage> {
  final String url;

  const StableNetworkImage(this.url);

  String get _key => url.split('?').first;

  @override
  Future<StableNetworkImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(StableNetworkImage key, ImageDecoderCallback decode) {
    final network = NetworkImage(key.url);
    return network.loadImage(network, decode);
  }

  @override
  bool operator ==(Object other) => other is StableNetworkImage && other._key == _key;

  @override
  int get hashCode => _key.hashCode;
}

/// An image from a (signed) URL with a placeholder and error state.
class MediaImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? aspectRatio;

  const MediaImage({super.key, required this.url, this.fit = BoxFit.cover, this.aspectRatio});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final image = Image(
      image: StableNetworkImage(url),
      fit: fit,
      width: double.infinity,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) => sync || frame != null
          ? child
          : Container(color: cs.surfaceContainerHigh),
      errorBuilder: (context, _, _) => Container(
        color: cs.surfaceContainerHigh,
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
      ),
    );
    return aspectRatio == null ? image : AspectRatio(aspectRatio: aspectRatio!, child: image);
  }
}

/// Inline video: first frame with a play button; tap to play/pause.
/// [autoplayMuted] for feeds (Instagram-style).
class InlineVideo extends StatefulWidget {
  final String url;
  final double? aspectRatio;
  final bool autoplayMuted;
  final bool showControls;

  const InlineVideo({super.key, required this.url, this.aspectRatio, this.autoplayMuted = false, this.showControls = true});

  @override
  State<InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<InlineVideo> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _ready = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) async {
      if (!mounted) return;
      await _c.setLooping(widget.autoplayMuted);
      if (widget.autoplayMuted) {
        await _c.setVolume(0);
        await _c.play();
      }
      setState(() => _ready = true);
    }).catchError((Object _) {
      if (mounted) setState(() => _error = true);
    });
    _c.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onTick);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ratio = _ready ? _c.value.aspectRatio : (widget.aspectRatio ?? 16 / 9);
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(fit: StackFit.expand, children: [
        Container(color: Colors.black),
        if (_ready) FittedBox(fit: BoxFit.contain, child: SizedBox(width: _c.value.size.width, height: _c.value.size.height, child: VideoPlayer(_c))),
        if (_error) Center(child: Icon(Icons.videocam_off_outlined, color: cs.onInverseSurface)),
        if (!_ready && !_error) const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        if (_ready)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                if (_c.value.isPlaying) {
                  await _c.pause();
                } else {
                  if (_c.value.volume == 0 && widget.autoplayMuted) await _c.setVolume(1);
                  await _c.play();
                }
              },
              child: AnimatedOpacity(
                opacity: _c.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                  ),
                ),
              ),
            ),
          ),
        if (_ready && widget.showControls)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(_c, allowScrubbing: true, padding: const EdgeInsets.only(top: 6)),
          ),
        if (_ready && widget.autoplayMuted)
          Positioned(
            right: 8,
            bottom: 10,
            child: GestureDetector(
              onTap: () => _c.setVolume(_c.value.volume == 0 ? 1 : 0),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: Icon(_c.value.volume == 0 ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 16),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Full-screen viewer for a photo (pinch to zoom) or video.
class MediaViewerPage extends StatelessWidget {
  final String url;
  final bool isVideo;
  final String? title;

  const MediaViewerPage({super.key, required this.url, this.isVideo = false, this.title});

  static Future<void> open(BuildContext context, {required String url, bool isVideo = false, String? title}) =>
      Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MediaViewerPage(url: url, isVideo: isVideo, title: title),
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: title == null ? null : Text(title!, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: isVideo
            ? InlineVideo(url: url)
            : InteractiveViewer(minScale: 1, maxScale: 5, child: MediaImage(url: url, fit: BoxFit.contain)),
      ),
    );
  }
}

// ── Picking media ─────────────────────────────────────────────────────────────

enum MediaSource { takePhoto, recordVideo, gallery, file }

/// Bottom sheet: camera photo, camera video, gallery (photos and videos,
/// multiple) and — when [allowFiles] — any file. Returns the picked files
/// (empty when cancelled). Files over 50 MB are dropped with a snackbar.
Future<List<PickedMedia>> pickMedia(BuildContext context, {bool allowFiles = true, bool multiple = true}) async {
  final l10n = context.l10n;
  final source = await showAppBottomSheet<MediaSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: Text(l10n.socialTakePhoto),
          onTap: () => Navigator.pop(ctx, MediaSource.takePhoto),
        ),
        ListTile(
          leading: const Icon(Icons.videocam_outlined),
          title: Text(l10n.socialRecordVideo),
          onTap: () => Navigator.pop(ctx, MediaSource.recordVideo),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(l10n.socialGallery),
          onTap: () => Navigator.pop(ctx, MediaSource.gallery),
        ),
        if (allowFiles)
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text(l10n.socialFile),
            onTap: () => Navigator.pop(ctx, MediaSource.file),
          ),
      ]),
    ),
  );
  if (source == null) return const [];
  return pickMediaFrom(source, multiple: multiple, onTooLarge: () {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.socialFileTooLarge)));
    }
  });
}

const kMaxUploadBytes = 50 * 1024 * 1024;

Future<List<PickedMedia>> pickMediaFrom(MediaSource source, {bool multiple = true, VoidCallback? onTooLarge}) async {
  final picker = ImagePicker();
  final paths = <String>[];
  switch (source) {
    case MediaSource.takePhoto:
      final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2048);
      if (x != null) paths.add(x.path);
    case MediaSource.recordVideo:
      final x = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 3));
      if (x != null) paths.add(x.path);
    case MediaSource.gallery:
      if (multiple) {
        paths.addAll((await picker.pickMultipleMedia(imageQuality: 85, maxWidth: 2048, limit: 10)).map((x) => x.path));
      } else {
        final x = await picker.pickMedia(imageQuality: 85, maxWidth: 2048);
        if (x != null) paths.add(x.path);
      }
    case MediaSource.file:
      final result = await FilePicker.platform.pickFiles(allowMultiple: multiple);
      paths.addAll(result?.files.map((f) => f.path).whereType<String>() ?? const []);
  }
  final picked = <PickedMedia>[];
  for (final p in paths) {
    final media = await PickedMedia.fromPath(p);
    if (media.sizeBytes > kMaxUploadBytes) {
      onTooLarge?.call();
      continue;
    }
    picked.add(await _withDimensions(media));
  }
  return picked;
}

/// Reads pixel size (images) or size + duration (videos) so bubbles and
/// grids can reserve space before the file loads.
Future<PickedMedia> readMediaDimensions(PickedMedia m) => _withDimensions(m);

Future<PickedMedia> _withDimensions(PickedMedia m) async {
  try {
    if (m.mimeType.startsWith('image/')) {
      final completer = Completer<ImageInfo>();
      final stream = FileImage(m.file).resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener((info, _) => completer.complete(info), onError: (e, _) => completer.completeError(e));
      stream.addListener(listener);
      final info = await completer.future.timeout(const Duration(seconds: 5));
      stream.removeListener(listener);
      return PickedMedia(
        file: m.file,
        fileName: m.fileName,
        mimeType: m.mimeType,
        sizeBytes: m.sizeBytes,
        width: info.image.width,
        height: info.image.height,
      );
    }
    if (m.mimeType.startsWith('video/') || m.mimeType.startsWith('audio/')) {
      final c = VideoPlayerController.file(File(m.file.path));
      await c.initialize().timeout(const Duration(seconds: 8));
      final v = c.value;
      await c.dispose();
      return PickedMedia(
        file: m.file,
        fileName: m.fileName,
        mimeType: m.mimeType,
        sizeBytes: m.sizeBytes,
        width: v.size.width > 0 ? v.size.width.round() : null,
        height: v.size.height > 0 ? v.size.height.round() : null,
        durationMs: v.duration.inMilliseconds,
      );
    }
  } catch (_) {}
  return m;
}

/// "2.4 MB", "830 KB".
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// "0:42", "12:05".
String formatDuration(int ms) {
  final d = Duration(milliseconds: ms);
  final s = d.inSeconds % 60;
  return '${d.inMinutes}:${s.toString().padLeft(2, '0')}';
}
