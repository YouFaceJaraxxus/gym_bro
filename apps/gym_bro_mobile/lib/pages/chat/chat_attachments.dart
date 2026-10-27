import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/l10n.dart';
import '../../models/chat.dart';
import '../../services/media_upload.dart';
import '../../widgets/open_url.dart';
import '../../widgets/social_widgets.dart';

/// How a message's files render: photos/videos as one tile or a 2-column
/// grid, audio as a compact player, anything else as a file row.

const _kRadius = 16.0;

IconData fileIconFor(String mime, String? fileName) {
  final name = (fileName ?? '').toLowerCase();
  if (mime == 'application/pdf' || name.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
  if (mime.contains('zip') || mime.contains('compressed') || name.endsWith('.zip') || name.endsWith('.rar')) {
    return Icons.folder_zip_outlined;
  }
  if (mime.contains('sheet') || mime.contains('excel') || name.endsWith('.csv') || name.endsWith('.xlsx')) {
    return Icons.table_chart_outlined;
  }
  if (mime.contains('presentation') || mime.contains('powerpoint')) return Icons.slideshow_outlined;
  if (mime.startsWith('text/') || mime.contains('word') || mime.contains('document')) return Icons.description_outlined;
  if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
  if (mime.startsWith('video/')) return Icons.movie_outlined;
  if (mime.startsWith('image/')) return Icons.image_outlined;
  return Icons.insert_drive_file_outlined;
}

/// The attachments of a sent message.
class MessageAttachments extends StatelessWidget {
  final List<ChatAttachment> attachments;
  final bool mine;
  final double maxWidth;

  const MessageAttachments({super.key, required this.attachments, required this.mine, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final visual = attachments.where((a) => a.type == AttachmentType.image || a.type == AttachmentType.video).toList();
    final audio = attachments.where((a) => a.type == AttachmentType.audio).toList();
    final files = attachments.where((a) => a.type == AttachmentType.file).toList();
    final children = <Widget>[
      if (visual.isNotEmpty)
        _VisualGrid(
          count: visual.length,
          maxWidth: maxWidth,
          singleAspect: visual.first.aspectRatio,
          tile: (i, w, h) => _RemoteTile(attachment: visual[i], width: w, height: h),
        ),
      for (final a in audio) AudioAttachment(url: a.url, durationMs: a.durationMs, mine: mine),
      for (final a in files) FileAttachmentTile(attachment: a, mine: mine),
    ];
    return Column(
      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, c) in children.indexed) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 4), child: c),
      ],
    );
  }
}

/// Lays out [count] visual tiles: one tile keeps its aspect ratio; several
/// make a 2-column grid of squares (an odd last tile spans both columns).
class _VisualGrid extends StatelessWidget {
  final int count;
  final double maxWidth;
  final double? singleAspect;
  final Widget Function(int index, double width, double height) tile;

  const _VisualGrid({required this.count, required this.maxWidth, required this.singleAspect, required this.tile});

  @override
  Widget build(BuildContext context) {
    if (count == 1) {
      final w = maxWidth.clamp(120.0, 260.0);
      final aspect = (singleAspect ?? 4 / 3).clamp(0.6, 1.9);
      return ClipRRect(borderRadius: BorderRadius.circular(_kRadius), child: tile(0, w, w / aspect));
    }
    const gap = 3.0;
    final w = maxWidth.clamp(160.0, 260.0);
    final cell = (w - gap) / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kRadius),
      child: SizedBox(
        width: w,
        child: Wrap(spacing: gap, runSpacing: gap, children: [
          for (var i = 0; i < count; i++)
            if (i == count - 1 && count.isOdd) tile(i, w, cell) else tile(i, cell, cell),
        ]),
      ),
    );
  }
}

class _RemoteTile extends StatelessWidget {
  final ChatAttachment attachment;
  final double width;
  final double height;

  const _RemoteTile({required this.attachment, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final url = attachment.url;
    if (url == null) {
      return Container(
        width: width,
        height: height,
        color: cs.surfaceContainerHigh,
        child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
      );
    }
    final isVideo = attachment.type == AttachmentType.video;
    final videoAspect = attachment.aspectRatio ?? 16 / 9;
    return Semantics(
      button: true,
      label: isVideo ? l10n.chatVideoMessage : l10n.chatPhotoMessage,
      child: GestureDetector(
        onTap: () => MediaViewerPage.open(context, url: url, isVideo: isVideo),
        child: SizedBox(
          width: width,
          height: height,
          child: isVideo
              ? Stack(fit: StackFit.expand, children: [
                  Container(color: Colors.black),
                  ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: 320,
                        height: 320 / videoAspect,
                        child: InlineVideo(url: url, aspectRatio: videoAspect, showControls: false),
                      ),
                    ),
                  ),
                  // Swallow taps so the tile opens full screen instead of
                  // playing inline.
                  const Positioned.fill(child: ColoredBox(color: Colors.transparent)),
                  if (attachment.durationMs != null) Positioned(left: 6, bottom: 6, child: DurationBadge(ms: attachment.durationMs!)),
                ])
              : MediaImage(url: url),
        ),
      ),
    );
  }
}

/// "0:42" on a dark pill (video tiles).
class DurationBadge extends StatelessWidget {
  final int ms;

  const DurationBadge({super.key, required this.ms});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
        Text(formatDuration(ms), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// A compact audio player (play/pause, progress, time). The player is only
/// created on first play.
class AudioAttachment extends StatefulWidget {
  final String? url;
  final int? durationMs;
  final bool mine;

  const AudioAttachment({super.key, required this.url, this.durationMs, required this.mine});

  @override
  State<AudioAttachment> createState() => _AudioAttachmentState();
}

class _AudioAttachmentState extends State<AudioAttachment> {
  VideoPlayerController? _c;
  bool _loading = false;
  bool _error = false;

  @override
  void dispose() {
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    final url = widget.url;
    if (url == null) return;
    var c = _c;
    if (c == null) {
      setState(() {
        _loading = true;
        _error = false;
      });
      c = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await c.initialize();
      } catch (_) {
        await c.dispose();
        if (mounted) {
          setState(() {
            _loading = false;
            _error = true;
          });
        }
        return;
      }
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.addListener(_tick);
      setState(() {
        _c = c;
        _loading = false;
      });
    }
    final v = c.value;
    if (v.isPlaying) {
      await c.pause();
    } else {
      if (v.duration > Duration.zero && v.position >= v.duration) await c.seekTo(Duration.zero);
      await c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final fg = widget.mine ? cs.onPrimary : cs.onSurface;
    final bg = widget.mine ? cs.primary : cs.surfaceContainerHigh;
    final v = _c?.value;
    final total = v != null && v.duration > Duration.zero ? v.duration.inMilliseconds : (widget.durationMs ?? 0);
    final pos = v?.position.inMilliseconds ?? 0;
    final playing = v?.isPlaying ?? false;
    final progress = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      width: 230,
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        IconButton(
          tooltip: playing ? l10n.chatPause : l10n.chatPlay,
          onPressed: _loading ? null : _toggle,
          icon: _loading
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              : Icon(_error ? Icons.error_outline : (playing ? Icons.pause_rounded : Icons.play_arrow_rounded), color: fg),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              color: fg,
              backgroundColor: fg.withValues(alpha: 0.25),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          formatDuration(playing || pos > 0 ? pos : total),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ]),
    );
  }
}

/// A non-media file: icon, name and size; tap opens it.
class FileAttachmentTile extends StatelessWidget {
  final ChatAttachment attachment;
  final bool mine;

  const FileAttachmentTile({super.key, required this.attachment, required this.mine});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = attachment.url;
    return _FileRow(
      icon: fileIconFor(attachment.mimeType, attachment.fileName),
      name: attachment.fileName ?? context.l10n.chatMediaFile,
      size: attachment.sizeBytes,
      fg: mine ? cs.onPrimary : cs.onSurface,
      bg: mine ? cs.primary : cs.surfaceContainerHigh,
      tooltip: context.l10n.chatOpenFile,
      onTap: url == null ? null : () => openExternalUrl(context, url),
    );
  }
}

class _FileRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final int size;
  final Color fg;
  final Color bg;
  final String? tooltip;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _FileRow({
    required this.icon,
    required this.name,
    required this.size,
    required this.fg,
    required this.bg,
    this.tooltip,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final row = Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: fg.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w600)),
                Text(formatBytes(size), style: tt.labelSmall?.copyWith(color: fg.withValues(alpha: 0.75))),
              ]),
            ),
            ?trailing,
          ]),
        ),
      ),
    );
    return tooltip == null ? row : Tooltip(message: tooltip!, child: row);
  }
}

/// Files of a message that's still uploading (or failed), with a progress
/// ring per file.
class LocalAttachments extends StatelessWidget {
  final List<PickedMedia> files;
  final ValueListenable<List<double>> progress;
  final bool failed;
  final double maxWidth;

  const LocalAttachments({super.key, required this.files, required this.progress, required this.failed, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visual = <int>[];
    final other = <int>[];
    for (var i = 0; i < files.length; i++) {
      final t = files[i].type;
      (t == AttachmentType.image || t == AttachmentType.video ? visual : other).add(i);
    }
    Widget overlay(int i) => ValueListenableBuilder<List<double>>(
      valueListenable: progress,
      builder: (context, p, _) {
        final value = i < p.length ? p[i] : 0.0;
        if (!failed && value >= 1) return const SizedBox.shrink();
        return Container(
          color: Colors.black38,
          alignment: Alignment.center,
          child: failed
              ? const Icon(Icons.error_outline, color: Colors.white)
              : SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    value: value <= 0 ? null : value,
                    strokeWidth: 3,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
        );
      },
    );
    final children = <Widget>[
      if (visual.isNotEmpty)
        _VisualGrid(
          count: visual.length,
          maxWidth: maxWidth,
          singleAspect: _aspect(files[visual.first]),
          tile: (k, w, h) {
            final f = files[visual[k]];
            return SizedBox(
              width: w,
              height: h,
              child: Stack(fit: StackFit.expand, children: [
                if (f.type == AttachmentType.image)
                  Image.file(f.file, fit: BoxFit.cover, cacheWidth: 600)
                else
                  Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: const Icon(Icons.videocam_outlined, color: Colors.white70, size: 32),
                  ),
                overlay(visual[k]),
              ]),
            );
          },
        ),
      for (final i in other)
        _FileRow(
          icon: fileIconFor(files[i].mimeType, files[i].fileName),
          name: files[i].fileName,
          size: files[i].sizeBytes,
          fg: cs.onPrimary,
          bg: cs.primary,
          trailing: ValueListenableBuilder<List<double>>(
            valueListenable: progress,
            builder: (context, p, _) {
              final value = i < p.length ? p[i] : 0.0;
              if (failed) return Icon(Icons.error_outline, color: cs.onPrimary);
              if (value >= 1) return const SizedBox.shrink();
              return SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(value: value <= 0 ? null : value, strokeWidth: 2.5, color: cs.onPrimary),
              );
            },
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, c) in children.indexed) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 4), child: c),
      ],
    );
  }

  static double? _aspect(PickedMedia m) =>
      m.width != null && m.height != null && m.width! > 0 && m.height! > 0 ? m.width! / m.height! : null;
}
