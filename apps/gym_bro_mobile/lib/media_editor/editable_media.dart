import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

import '../services/media_upload.dart';
import 'media_edit.dart';

/// A picked photo or video plus its edits. The original stays as picked;
/// [export] bakes the edits into a new file right before upload.
class EditableMedia {
  EditableMedia(this.original, {this.edit = MediaEdit.none, this.uploadedPath});

  final PickedMedia original;
  MediaEdit edit;

  /// Per-setting undo stacks, kept so reopening the editor can still undo.
  final EditHistory history = EditHistory();
  final Key key = UniqueKey();

  /// Storage path of [original] when it's already uploaded (a draft's media).
  /// Reused as-is when the media is published without edits.
  String? uploadedPath;

  MediaEdit? _exportedFor;
  PickedMedia? _exported;

  bool get isVideo => original.mimeType.startsWith('video/');
  bool get isImage => original.mimeType.startsWith('image/');

  /// GIFs would lose their animation; everything else photo/video is editable.
  bool get canEdit => isVideo || (isImage && original.mimeType != 'image/gif');

  Duration? get duration => original.durationMs == null ? null : Duration(milliseconds: original.durationMs!);

  /// Width / height, or null when unknown.
  double? get aspectRatio {
    final w = original.width, h = original.height;
    return w != null && h != null && w > 0 && h > 0 ? w / h : null;
  }

  /// The file to upload: [original] when unedited, else a rendered copy
  /// (cached until the edits change).
  Future<PickedMedia> export({void Function(double progress)? onProgress}) async {
    if (edit.isIdentity || !canEdit) return original;
    if (_exported != null && _exportedFor == edit) return _exported!;
    final target = edit;
    final out = isVideo ? await renderVideo(original, target, onProgress: onProgress) : await renderImage(original, target);
    _exportedFor = target;
    _exported = out;
    return out;
  }
}

Future<File> _tempFile(String extension) async {
  final dir = await getTemporaryDirectory();
  return File('${dir.path}/edited_${DateTime.now().microsecondsSinceEpoch}.$extension');
}

/// Darkens the edges: a radial falloff reaching the corners, so it scales
/// with the frame and looks the same on a preview and on the full size file.
void paintVignette(Canvas canvas, Size size, double amount) {
  if (amount <= 0) return;
  final rect = Offset.zero & size;
  final radius = math.sqrt(size.width * size.width + size.height * size.height) / 2;
  final paint = Paint()
    ..shader = ui.Gradient.radial(
      rect.center,
      radius,
      [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.85 * amount)],
      const [0, 0.45, 1],
    );
  canvas.drawRect(rect, paint);
}

/// Bakes [edit]'s color matrix and vignette into a JPEG.
Future<PickedMedia> renderImage(PickedMedia src, MediaEdit edit) async {
  final codec = await ui.instantiateImageCodec(await src.file.readAsBytes());
  final image = (await codec.getNextFrame()).image;
  final w = image.width, h = image.height;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(
    image,
    Offset.zero,
    Paint()
      ..colorFilter = ColorFilter.matrix(edit.colorMatrix)
      ..filterQuality = FilterQuality.none,
  );
  paintVignette(canvas, Size(w.toDouble(), h.toDouble()), edit.vignette);
  final rendered = await recorder.endRecording().toImage(w, h);
  final rgba = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  rendered.dispose();
  codec.dispose();
  final buffer = rgba!.buffer;
  final jpg = await Isolate.run(
    () => img.encodeJpg(
      img.Image.fromBytes(width: w, height: h, bytes: buffer, numChannels: 4, order: img.ChannelOrder.rgba),
      quality: 90,
    ),
  );
  final file = await _tempFile('jpg');
  await file.writeAsBytes(jpg, flush: true);
  return PickedMedia(
    file: file,
    fileName: '${_stem(src.fileName)}.jpg',
    mimeType: 'image/jpeg',
    sizeBytes: jpg.length,
    width: w,
    height: h,
  );
}

/// A transparent PNG of the vignette, stretched over the video on export.
Future<Uint8List> _vignettePng(Size size, double amount) async {
  final recorder = ui.PictureRecorder();
  paintVignette(Canvas(recorder), size, amount);
  final image = await recorder.endRecording().toImage(size.width.round(), size.height.round());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}

/// Trims and color-grades a video natively (AVFoundation / Media3).
Future<PickedMedia> renderVideo(PickedMedia src, MediaEdit edit, {void Function(double progress)? onProgress}) async {
  final aspect = (src.width ?? 16) / math.max(1, src.height ?? 9);
  const overlayWidth = 720.0;
  final layers = edit.vignette > 0
      ? [
          pve.ImageLayer(
            image: pve.EditorLayerImage.memory(await _vignettePng(Size(overlayWidth, (overlayWidth / aspect).roundToDouble()), edit.vignette)),
          ),
        ]
      : null;
  final duration = src.durationMs == null ? null : Duration(milliseconds: src.durationMs!);
  final start = edit.trimStart != null && edit.trimStart! > Duration.zero ? edit.trimStart : null;
  final end = edit.trimEnd != null && (duration == null || edit.trimEnd! < duration) ? edit.trimEnd : null;
  final data = pve.VideoRenderData(
    videoSegments: [pve.VideoSegment(video: pve.EditorVideo.file(src.file))],
    startTime: start,
    endTime: end,
    colorFilters: edit.hasColorMatrix ? [pve.ColorFilter(matrix: edit.colorMatrix)] : const [],
    imageLayers: layers,
    shouldOptimizeForNetworkUse: true,
  );
  final file = await _tempFile('mp4');
  final progress = pve.ProVideoEditor.instance.progressStreamById(data.id).listen((p) => onProgress?.call(p.progress));
  try {
    await pve.ProVideoEditor.instance.renderVideoToFile(file.path, data);
  } finally {
    await progress.cancel();
  }
  final outLength = (end ?? duration);
  return PickedMedia(
    file: file,
    fileName: '${_stem(src.fileName)}.mp4',
    mimeType: 'video/mp4',
    sizeBytes: await file.length(),
    width: src.width,
    height: src.height,
    durationMs: outLength == null ? null : (outLength - (start ?? Duration.zero)).inMilliseconds,
  );
}

String _stem(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot > 0 ? fileName.substring(0, dot) : fileName;
}

/// Evenly spaced frames of a video (cached per file and count), for the trim
/// filmstrip and filter thumbnails.
class VideoFrames {
  static final Map<String, Future<List<Uint8List>>> _cache = {};

  static Future<List<Uint8List>> of(File video, Duration duration, int count, {double size = 120}) {
    return _cache.putIfAbsent('${video.path}#$count', () async {
      final step = duration.inMicroseconds / math.max(1, count);
      try {
        return await pve.ProVideoEditor.instance.getThumbnails(
          pve.ThumbnailConfigs(
            video: pve.EditorVideo.file(video),
            outputSize: Size.square(size),
            boxFit: pve.ThumbnailBoxFit.cover,
            timestamps: [for (var i = 0; i < count; i++) Duration(microseconds: (step * (i + 0.5)).round())],
          ),
        );
      } catch (_) {
        _cache.remove('${video.path}#$count');
        return const [];
      }
    });
  }
}
