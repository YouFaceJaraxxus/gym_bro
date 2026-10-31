import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

import '../config.dart';

/// The first moments of a video as a still (decoded once per file and
/// cached), over a dark tile with a play icon while loading or when the frame
/// can't be read.
class VideoFrameThumb extends StatefulWidget {
  const VideoFrameThumb({super.key, required this.url, this.iconSize = 24, this.caption});

  /// Signed (possibly relative) URL of the video; null shows just the tile.
  final String? url;
  final double iconSize;

  /// Small text under the play icon (e.g. the duration).
  final String? caption;

  /// By URL without the query string, so a re-signed URL reuses the frame.
  static final Map<String, Future<Uint8List?>> _cache = {};

  static Future<Uint8List?> _frame(String url) {
    final key = url.split('?').first;
    return _cache.putIfAbsent(key, () async {
      try {
        final frames = await pve.ProVideoEditor.instance.getThumbnails(
          pve.ThumbnailConfigs(
            video: pve.EditorVideo.network(AppConfig.resolveUrl(url)),
            outputSize: const Size.square(240),
            boxFit: pve.ThumbnailBoxFit.cover,
            timestamps: const [Duration(milliseconds: 300)],
          ),
        );
        return frames.isEmpty ? null : frames.first;
      } catch (_) {
        _cache.remove(key); // try again next time
        return null;
      }
    });
  }

  @override
  State<VideoFrameThumb> createState() => _VideoFrameThumbState();
}

class _VideoFrameThumbState extends State<VideoFrameThumb> {
  Future<Uint8List?>? _frame;

  @override
  void initState() {
    super.initState();
    if (widget.url != null) _frame = VideoFrameThumb._frame(widget.url!);
  }

  @override
  void didUpdateWidget(VideoFrameThumb old) {
    super.didUpdateWidget(old);
    if (widget.url?.split('?').first != old.url?.split('?').first) {
      _frame = widget.url == null ? null : VideoFrameThumb._frame(widget.url!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.play_arrow_rounded, color: Colors.white, size: widget.iconSize);
    return FutureBuilder<Uint8List?>(
      future: _frame,
      builder: (context, snap) {
        final bytes = snap.data;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF1C1C1E)),
            if (bytes != null) Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                icon,
                if (widget.caption != null)
                  Text(
                    widget.caption!,
                    style: const TextStyle(color: Colors.white, fontSize: 12, shadows: [Shadow(blurRadius: 4)]),
                  ),
              ]),
            ),
          ],
        );
      },
    );
  }
}
