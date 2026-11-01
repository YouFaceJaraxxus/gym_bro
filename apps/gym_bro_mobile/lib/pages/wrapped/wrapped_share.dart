import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/l10n.dart';
import '../../services/media_upload.dart';
import '../../widgets/posting_bar.dart';
import '../stories/story_composer_page.dart';

/// Renders the summary card under [boundaryKey] (a RepaintBoundary) to a
/// 1080-wide PNG and opens the story composer with it, ready to post.
Future<void> shareWrappedCard(BuildContext context, GlobalKey boundaryKey, {required int year}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failed = context.l10n.wrappedShareFailed;
  final PickedMedia media;
  try {
    media = await renderBoundaryToPng(boundaryKey, name: 'gym_bro_wrapped_$year');
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(failed)));
    return;
  }
  if (!context.mounted) return;
  final storyPosted = context.l10n.storyPosted;
  final pending = await openStoryComposer(context, media: media);
  if (pending != null) await followPending(messenger, pending, posted: storyPosted);
}

/// The boundary as a PNG file in the temp directory.
Future<PickedMedia> renderBoundaryToPng(GlobalKey boundaryKey, {required String name, double width = 1080}) async {
  final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) throw StateError('Nothing to render');
  final ratio = width / boundary.size.width;
  final image = await boundary.toImage(pixelRatio: ratio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes, flush: true);
    return PickedMedia(
      file: file,
      fileName: '$name.png',
      mimeType: 'image/png',
      sizeBytes: bytes.length,
      width: image.width,
      height: image.height,
    );
  } finally {
    image.dispose();
  }
}
