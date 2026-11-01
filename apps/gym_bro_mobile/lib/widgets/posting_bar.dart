import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../media_editor/edited_media_view.dart';
import '../services/post_upload_queue.dart';

/// For screens without a [PostingBar]: "Posting…" now, then [posted] once
/// [pending] is out, or "Couldn't post" with Retry. Completes once it's
/// posted (true) or discarded (false).
Future<bool> followPending(ScaffoldMessengerState? messenger, PendingPost pending, {required String posted, PostUploadQueue? queue}) {
  final q = queue ?? PostUploadQueue.instance;
  final l10n = pending.l10n;
  final done = Completer<bool>();
  var lastStatus = pending.status;
  messenger?.showSnackBar(SnackBar(content: Text(l10n.postingInProgress)));
  void check() {
    if (done.isCompleted) return;
    final status = pending.status;
    if (status == PendingPostStatus.posted) {
      q.removeListener(check);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(posted)));
      done.complete(true);
    } else if (!q.items.contains(pending)) {
      q.removeListener(check);
      done.complete(false);
    } else if (status == PendingPostStatus.failed && lastStatus != PendingPostStatus.failed) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${l10n.postingFailed} ${pending.error ?? ''}'.trim()),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(label: l10n.postingRetry, onPressed: () => q.retry(pending)),
        ));
    }
    lastStatus = status;
  }

  q.addListener(check);
  check();
  return done.future;
}

/// Instagram-style "Posting…" rows for the posts in [queue]: the first
/// photo/video, a progress bar, a check once posted (then it collapses), or
/// "Couldn't post. Retry / Discard". Nothing while the queue is empty.
class PostingBar extends StatelessWidget {
  const PostingBar({super.key, this.queue});

  /// Defaults to [PostUploadQueue.instance].
  final PostUploadQueue? queue;

  @override
  Widget build(BuildContext context) {
    final q = queue ?? PostUploadQueue.instance;
    final calm = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: q,
      builder: (context, _) => AnimatedSize(
        duration: calm ? Duration.zero : const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in q.items) _PendingPostRow(key: ValueKey(p.id), pending: p, queue: q),
          ],
        ),
      ),
    );
  }
}

class _PendingPostRow extends StatelessWidget {
  const _PendingPostRow({super.key, required this.pending, required this.queue});

  final PendingPost pending;
  final PostUploadQueue queue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final calm = MediaQuery.disableAnimationsOf(context);
    final p = pending;
    final failed = p.status == PendingPostStatus.failed;
    final posted = p.status == PendingPostStatus.posted;
    final value = p.progress?.overall;
    final title = failed ? l10n.postingFailed : posted ? l10n.postingDone : l10n.postingInProgress;

    final Widget trailing;
    if (failed) {
      trailing = Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: () => queue.discard(p),
          child: Text(l10n.postingDiscard, style: TextStyle(color: cs.onSurfaceVariant)),
        ),
        TextButton(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: () => queue.retry(p),
          child: Text(l10n.postingRetry),
        ),
      ]);
    } else if (posted) {
      trailing = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.check_circle_rounded, color: cs.primary, size: 26, semanticLabel: l10n.postingDone),
      );
    } else {
      trailing = const SizedBox(width: 8);
    }

    return Semantics(
      liveRegion: true,
      label: posted || failed || value == null ? null : l10n.postingProgressLabel((value * 100).round()),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6))),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(children: [
          _Thumb(pending: p),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: failed ? cs.error : null,
                  ),
                ),
                if (failed && p.error != null && p.error!.isNotEmpty)
                  Text(
                    p.error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  )
                else if (!failed) ...[
                  const SizedBox(height: 6),
                  ExcludeSemantics(
                    child: TweenAnimationBuilder<double>(
                      // Smooths the jumps between upload chunks.
                      tween: Tween(end: posted ? 1 : value ?? 0),
                      duration: calm ? Duration.zero : const Duration(milliseconds: 200),
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: posted || value != null ? v : null,
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: calm ? Duration.zero : const Duration(milliseconds: 250),
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: KeyedSubtree(key: ValueKey(p.status), child: trailing),
          ),
        ]),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.pending});

  final PendingPost pending;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cover = pending.cover;
    final Widget child;
    if (cover != null && cover.isImage) {
      child = EditedImage(media: cover, fit: BoxFit.cover, cacheWidth: 120);
    } else if (cover != null) {
      child = Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
      );
    } else {
      child = Container(
        color: cs.secondaryContainer,
        alignment: Alignment.center,
        child: Icon(
          pending.isShare ? Icons.ios_share : (pending.isStory ? Icons.auto_stories_outlined : Icons.notes),
          color: cs.onSecondaryContainer,
          size: 20,
        ),
      );
    }
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(width: 40, height: 40, child: child),
      ),
    );
  }
}
