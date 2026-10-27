import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/chat.dart';
import '../../services/media_upload.dart';
import '../../widgets/social_widgets.dart';
import 'chat_attachments.dart';

/// Max files per message (API limit).
const kMaxChatAttachments = 10;

/// The bottom bar of a thread: context bar (replying / editing), picked
/// files strip, then [attach] [camera] [text field] [send].
class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<PickedMedia> files;
  final ValueChanged<List<PickedMedia>> onFilesChanged;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  /// Editing an existing message: no attachments, "Save" instead of send.
  final bool editing;

  /// "Replying to …" / "Editing message" bar.
  final Widget? contextBar;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.files,
    required this.onFilesChanged,
    required this.onChanged,
    required this.onSend,
    this.editing = false,
    this.contextBar,
  });

  Future<void> _add(BuildContext context, Future<List<PickedMedia>> picking) async {
    final picked = await picking;
    if (picked.isEmpty) return;
    onFilesChanged([...files, ...picked].take(kMaxChatAttachments).toList());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Material(
      color: cs.surface,
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Divider(height: 1, color: cs.outlineVariant),
          ?contextBar,
          if (files.isNotEmpty && !editing)
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                itemCount: files.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _PickedThumb(
                  media: files[i],
                  onRemove: () => onFilesChanged([...files]..removeAt(i)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (!editing) ...[
                IconButton(
                  tooltip: l10n.chatAttach,
                  icon: Icon(Icons.add_circle_rounded, color: cs.primary),
                  onPressed: files.length >= kMaxChatAttachments ? null : () => _add(context, pickMedia(context)),
                ),
                IconButton(
                  tooltip: l10n.socialCamera,
                  icon: Icon(Icons.photo_camera_rounded, color: cs.primary),
                  onPressed: files.length >= kMaxChatAttachments
                      ? null
                      : () => _add(
                          context,
                          pickMediaFrom(MediaSource.takePhoto, onTooLarge: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.socialFileTooLarge)));
                          }),
                        ),
                ),
              ] else
                const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: l10n.chatMessageHint,
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: cs.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final canSend = value.text.trim().isNotEmpty || (!editing && files.isNotEmpty);
                  return IconButton(
                    tooltip: editing ? l10n.chatSaveEdit : l10n.chatSend,
                    onPressed: canSend ? onSend : null,
                    icon: Icon(editing ? Icons.check_circle_rounded : Icons.send_rounded),
                    color: cs.primary,
                  );
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The "Replying to Ana · preview" / "Editing message" bar.
class ComposerContextBar extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? preview;
  final VoidCallback onClose;

  const ComposerContextBar({super.key, required this.icon, required this.title, this.preview, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      child: Row(children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (preview != null && preview!.isNotEmpty)
              Text(
                preview!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
          ]),
        ),
        IconButton(
          tooltip: context.l10n.chatCancel,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close, size: 20),
          onPressed: onClose,
        ),
      ]),
    );
  }
}

class _PickedThumb extends StatelessWidget {
  final PickedMedia media;
  final VoidCallback onRemove;

  const _PickedThumb({required this.media, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final Widget body = switch (media.type) {
      AttachmentType.image => Image.file(media.file, fit: BoxFit.cover, cacheWidth: 200),
      AttachmentType.video => Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.videocam_rounded, color: Colors.white),
          if (media.durationMs != null)
            Text(formatDuration(media.durationMs!), style: const TextStyle(color: Colors.white, fontSize: 11)),
        ]),
      ),
      _ => Container(
        color: cs.surfaceContainerHigh,
        padding: const EdgeInsets.all(6),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(fileIconFor(media.mimeType, media.fileName), color: cs.onSurfaceVariant),
          const SizedBox(height: 2),
          Text(media.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelSmall),
        ]),
      ),
    };
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: body)),
        Positioned(
          top: -6,
          right: -6,
          child: Semantics(
            button: true,
            label: context.l10n.chatRemoveAttachment,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: cs.inverseSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 2),
                ),
                child: Icon(Icons.close, size: 12, color: cs.onInverseSurface),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
