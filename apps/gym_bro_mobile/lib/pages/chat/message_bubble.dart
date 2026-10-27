import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/chat.dart';
import '../../models/people.dart';
import '../../models/reaction.dart';
import '../../services/media_upload.dart';
import '../../widgets/social_widgets.dart';
import 'chat_attachments.dart';
import 'chat_widgets.dart';

/// Local files of a message being sent, with per-file upload progress.
class OutgoingFiles {
  final List<PickedMedia> files;
  final ValueListenable<List<double>> progress;

  const OutgoingFiles(this.files, this.progress);
}

/// One message row: avatar (others), sender name (groups), reply quote,
/// attachments, text bubble, reactions pill and an optional status line.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool isGroup;

  /// First / last message of a run by the same sender.
  final bool clusterTop;
  final bool clusterBottom;
  final bool showTime;
  final bool highlighted;
  final OutgoingFiles? outgoing;

  /// Under the bubble ("Seen", seen-by avatars, "Sending…").
  final Widget? status;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final void Function(BuildContext anchor)? onLongPress;
  final VoidCallback? onReply;
  final VoidCallback? onQuoteTap;
  final VoidCallback? onReactionsTap;
  final VoidCallback? onAvatarTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.isGroup,
    this.clusterTop = true,
    this.clusterBottom = true,
    this.showTime = false,
    this.highlighted = false,
    this.outgoing,
    this.status,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onReply,
    this.onQuoteTap,
    this.onReactionsTap,
    this.onAvatarTap,
  });

  static const _avatarRadius = 14.0;

  BorderRadius _radius() {
    const big = Radius.circular(18);
    const small = Radius.circular(5);
    return mine
        ? BorderRadius.only(
            topLeft: big,
            bottomLeft: big,
            topRight: clusterTop ? big : small,
            bottomRight: clusterBottom ? big : small,
          )
        : BorderRadius.only(
            topRight: big,
            bottomRight: big,
            topLeft: clusterTop ? big : small,
            bottomLeft: clusterBottom ? big : small,
          );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;
    final m = message;
    final sender = m.sender;

    final content = <Widget>[];
    if (m.isDeleted) {
      content.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: _radius(),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text(
          l10n.chatMessageUnsent,
          style: tt.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: cs.onSurfaceVariant),
        ),
      ));
    } else {
      if (m.replyTo != null) content.add(_ReplyQuote(reply: m.replyTo!, mine: mine, onTap: onQuoteTap));
      if (outgoing != null && outgoing!.files.isNotEmpty) {
        content.add(LocalAttachments(
          files: outgoing!.files,
          progress: outgoing!.progress,
          failed: m.failed,
          maxWidth: maxWidth,
        ));
      } else if (m.attachments.isNotEmpty) {
        content.add(MessageAttachments(attachments: m.attachments, mine: mine, maxWidth: maxWidth));
      }
      final body = m.body;
      if (body != null && body.isNotEmpty) {
        content.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: mine ? cs.primary : cs.surfaceContainerHigh, borderRadius: _radius()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(body, style: tt.bodyLarge?.copyWith(color: mine ? cs.onPrimary : cs.onSurface, height: 1.3)),
              if (m.editedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    l10n.chatEdited,
                    style: tt.labelSmall?.copyWith(
                      color: (mine ? cs.onPrimary : cs.onSurfaceVariant).withValues(alpha: 0.75),
                    ),
                  ),
                ),
            ],
          ),
        ));
      }
    }

    Widget column = Column(
      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, c) in content.indexed) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 3), child: c),
      ],
    );
    if (m.pending) column = Opacity(opacity: 0.75, child: column);

    // Gestures on the bubble itself (not the whole row width).
    final bubble = Builder(
      builder: (anchor) => GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress == null ? null : () => onLongPress!(anchor),
        child: column,
      ),
    );

    final reactions = m.isDeleted || m.reactions.isEmpty
        ? null
        : Transform.translate(
            offset: const Offset(0, -4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ReactionsPill(reactions: m.reactions, onTap: onReactionsTap),
            ),
          );

    final showName = isGroup && !mine && clusterTop && sender != null;
    final stack = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showName)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(sender.name, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
          bubble,
          ?reactions,
          if (showTime)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
              child: Text(
                chatClockTime(l10n, m.createdAt),
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          if (status != null) Padding(padding: const EdgeInsets.fromLTRB(6, 2, 4, 0), child: status),
        ],
      ),
    );

    final row = Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!mine) ...[
          SizedBox(
            width: _avatarRadius * 2,
            child: clusterBottom && sender != null
                ? Padding(
                    // Line the avatar up with the bubble, not the pill/status.
                    padding: EdgeInsets.only(bottom: (reactions != null ? 14 : 0) + (showTime ? 18 : 0)),
                    child: GestureDetector(
                      onTap: onAvatarTap,
                      child: UserAvatar(url: sender.avatarUrl, initials: sender.initials, radius: _avatarRadius),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(child: stack),
        if (mine && m.failed)
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Icon(Icons.error, size: 18, color: cs.error),
          ),
      ],
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: highlighted ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
      padding: EdgeInsets.fromLTRB(12, clusterTop ? 8 : 1, 12, clusterBottom ? 2 : 1),
      child: SwipeToReply(onReply: m.isDeleted || m.pending || m.failed ? null : onReply, child: row),
    );
  }
}

/// The quoted message above a reply (tap jumps to it).
class _ReplyQuote extends StatelessWidget {
  final ReplyPreview reply;
  final bool mine;
  final VoidCallback? onTap;

  const _ReplyQuote({required this.reply, required this.mine, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final text = reply.deleted
        ? l10n.chatMessageUnsent
        : (reply.body?.isNotEmpty ?? false)
            ? reply.body!
            : reply.mediaType != null
                ? chatMediaLabel(l10n, reply.mediaType!)
                : '';
    final who = reply.senderId == chatMyId ? l10n.chatYou : (reply.senderName ?? l10n.chatSomeone);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: cs.primary, width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.reply_rounded, size: 13, color: cs.onSurfaceVariant),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                who,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 1),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontStyle: reply.deleted ? FontStyle.italic : null,
            ),
          ),
        ]),
      ),
    );
  }
}

/// The emojis on a message (most used first) and a count.
class ReactionsPill extends StatelessWidget {
  final List<MessageReaction> reactions;
  final VoidCallback? onTap;

  const ReactionsPill({super.key, required this.reactions, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final counts = <ReactionType, int>{};
    for (final r in reactions) {
      counts[r.reaction] = (counts[r.reaction] ?? 0) + 1;
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.index.compareTo(b.key.index));
    final mineReacted = reactions.any((r) => r.userId == chatMyId);
    return Semantics(
      button: true,
      label: context.l10n.reactionCount(reactions.length),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: mineReacted ? cs.primaryContainer : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.surface, width: 2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final e in top.take(3)) Text(e.key.emoji, style: const TextStyle(fontSize: 13)),
            if (reactions.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Text(
                  '${reactions.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mineReacted ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// A centered grey line for system events.
class SystemMessageLine extends StatelessWidget {
  final String text;

  const SystemMessageLine({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// "Today", "Monday", … between days.
class DaySeparator extends StatelessWidget {
  final DateTime day;

  const DaySeparator({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Center(
        child: Text(
          chatDayLabel(context.l10n, day),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// "Seen" / "Sent" / seen-by avatars under my latest message.
class ReceiptLine extends StatelessWidget {
  final String? text;
  final List<PersonSummary> seenBy;
  final bool error;
  final VoidCallback? onTap;

  const ReceiptLine({super.key, this.text, this.seenBy = const [], this.error = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: error ? cs.error : cs.onSurfaceVariant);
    final child = seenBy.isNotEmpty ? TinyAvatarRow(people: seenBy) : Text(text ?? '', style: style);
    return onTap == null ? child : GestureDetector(onTap: onTap, child: child);
  }
}
