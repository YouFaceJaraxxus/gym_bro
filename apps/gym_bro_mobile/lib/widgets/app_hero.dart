import 'package:flutter/material.dart';

/// A [Hero] that stands down when [tag] is null (the screen wasn't opened
/// from a matching source) or the user asked the OS to reduce motion.
///
/// Tags must be unique on a screen, so list sources scope theirs (see
/// [postMediaHeroTag]) and hand the same tag to the page they open.
class AppHero extends StatelessWidget {
  const AppHero({super.key, required this.tag, required this.child, this.flightChild});

  final Object? tag;
  final Widget child;

  /// What flies instead of [child], e.g. a plain photo instead of a whole
  /// carousel, so nothing interactive is rebuilt mid-flight.
  final Widget? flightChild;

  @override
  Widget build(BuildContext context) {
    final tag = this.tag;
    if (tag == null || MediaQuery.disableAnimationsOf(context)) return child;
    final flight = flightChild;
    return Hero(
      tag: tag,
      flightShuttleBuilder: flight == null ? null : (_, _, _, _, _) => flight,
      child: child,
    );
  }
}

/// A post's media flying between a list and its detail page. [scope] says
/// where it's shown ("feed", "grid", "tagged", …) so a post that appears in
/// two places on one screen never has two heroes with one tag.
String postMediaHeroTag(String scope, String postId) => 'post-media-$scope-$postId';

/// An avatar flying into a profile header; scoped like [postMediaHeroTag].
String avatarHeroTag(String scope, String id) => 'avatar-$scope-$id';

/// An avatar hero handed to the profile it opens: the [tag] plus what the
/// source showed, so the profile can draw the same avatar (the flight's
/// landing spot) before the profile itself has loaded.
class AvatarHeroInfo {
  const AvatarHeroInfo({required this.tag, this.url, required this.initials});

  final String tag;
  final String? url;
  final String initials;
}
