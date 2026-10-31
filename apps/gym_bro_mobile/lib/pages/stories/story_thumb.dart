import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

import '../../config.dart';
import '../../models/mention.dart';
import '../../models/shared_content.dart';
import '../../models/story.dart';
import '../../widgets/social_widgets.dart';

/// What a story looks like small: its photo, a frame of its video, or its
/// colour with the text / shared thing's icon.
class StoryThumb extends StatelessWidget {
  const StoryThumb({super.key, required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final s = story;
    if (s.hasMedia && !s.isVideo) return MediaImage(url: s.mediaUrl!);
    if (s.isVideo) return VideoFrameThumb(url: s.mediaUrl, iconSize: 22);
    return Container(
      color: s.backgroundColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: s.share != null
          ? Icon(shareKindIcon(s.share!.kind), color: Colors.white, size: 18)
          : Text(
              mentionPlainText(s.caption ?? ''),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
            ),
    );
  }
}

/// The first moments of a video as a still (decoded once per file and
/// cached), over a dark tile with a play icon while loading or when the frame
/// can't be read.
class VideoFrameThumb extends StatefulWidget {
  const VideoFrameThumb({super.key, required this.url, this.iconSize = 24});

  /// Signed (possibly relative) URL of the video; null shows just the tile.
  final String? url;
  final double iconSize;

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
            Center(child: icon),
          ],
        );
      },
    );
  }
}

/// An icon for what a story / message shares.
IconData shareKindIcon(ShareKind kind) => switch (kind) {
  ShareKind.post => Icons.grid_on_rounded,
  ShareKind.story => Icons.amp_stories_outlined,
  ShareKind.user => Icons.person_outline,
  ShareKind.business => Icons.storefront_outlined,
  ShareKind.shopItem => Icons.shopping_bag_outlined,
  ShareKind.workout || ShareKind.training || ShareKind.exercise || ShareKind.routine => Icons.fitness_center,
  ShareKind.meal || ShareKind.recipe || ShareKind.foodItem || ShareKind.dailyMealPlan || ShareKind.mealPlan =>
    Icons.restaurant_outlined,
};

/// The green star marking close-friends stories.
class CloseFriendsStar extends StatelessWidget {
  const CloseFriendsStar({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(size * 0.15),
    decoration: const BoxDecoration(color: kCloseFriendsGreen, shape: BoxShape.circle),
    child: Icon(Icons.star_rounded, size: size, color: Colors.white),
  );
}

/// The green "★ Close friends" pill on a close-friends story.
class CloseFriendsBadge extends StatelessWidget {
  const CloseFriendsBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(5, 2, 8, 2),
    decoration: BoxDecoration(color: kCloseFriendsGreen, borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, size: 13, color: Colors.white),
      const SizedBox(width: 2),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}
