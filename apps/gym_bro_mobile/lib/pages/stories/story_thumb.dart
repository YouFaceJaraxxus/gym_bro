import 'package:flutter/material.dart';

import '../../models/mention.dart';
import '../../models/shared_content.dart';
import '../../models/story.dart';
import '../../widgets/social_widgets.dart';
import '../../widgets/video_frame_thumb.dart';

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
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    ]),
  );
}
