import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/chat.dart';
import '../../models/people.dart';
import '../../models/reaction.dart';
import '../../models/social.dart' show relativeTime;
import '../../services/realtime_service.dart';
import 'chat_widgets.dart';

/// Pieces of the thread screen: the app bar title, the quick reaction row
/// of the long-press sheet and the message request banner.

/// Avatar, title and a live subtitle (typing / active / member count).
class ThreadAppBarTitle extends StatelessWidget {
  final Conversation? conversation;
  final ChatChannel? channel;
  final PersonSummary? other;
  final DateTime? otherLastActive;
  final VoidCallback? onTap;

  const ThreadAppBarTitle({super.key, required this.conversation, required this.channel, required this.other, required this.otherLastActive, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ch = channel;
    if (ch == null) return _build(context, const [], const {});
    return ListenableBuilder(
      listenable: Listenable.merge([ch.typing, ch.online]),
      builder: (context, _) => _build(context, ch.typing.value, ch.online.value),
    );
  }

  Widget _build(BuildContext context, List<TypingUser> typing, Set<String> online) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final c = conversation;
    if (c == null) return const SizedBox.shrink();
    final title = c.displayTitle(c.isGroup ? l10n.chatGroupFallback : l10n.chatSomeone);
    final active = !c.isGroup && other != null && (online.contains(other!.id) || isRecentlyActive(otherLastActive));
    String? subtitle;
    var highlight = false;
    if (typing.isNotEmpty) {
      subtitle = typing.length == 1 ? l10n.socialTyping(typing.first.name) : l10n.socialTypingSeveral;
      highlight = true;
    } else if (c.isGroup) {
      subtitle = l10n.chatMembersCount(
        c.members.isNotEmpty ? c.members.where((m) => m.status == 'active').length : math.max(c.participantCount, 1),
      );
    } else if (active) {
      subtitle = l10n.socialActiveNow;
    } else if (otherLastActive != null) {
      subtitle = l10n.socialActiveAgo(relativeTime(l10n, otherLastActive!));
    }
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            ConversationAvatar(conversation: c, radius: 18, online: active),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (c.muted) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.notifications_off_outlined, size: 14, color: cs.onSurfaceVariant),
                  ],
                ]),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelSmall?.copyWith(color: highlight || active ? cs.primary : cs.onSurfaceVariant),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The reaction row at the top of the long-press sheet; "+" opens the full
/// floating picker anchored to the bubble.
class QuickReactionsRow extends StatelessWidget {
  static const _quick = [
    ReactionType.love,
    ReactionType.haha,
    ReactionType.wow,
    ReactionType.sad,
    ReactionType.fire,
    ReactionType.like,
  ];

  final ReactionType? current;
  final ValueChanged<ReactionType> onPick;
  final VoidCallback onMore;

  const QuickReactionsRow({super.key, required this.current, required this.onPick, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        for (final r in _quick)
          Tooltip(
            message: r.label(l10n),
            child: Semantics(
              button: true,
              selected: r == current,
              label: r.label(l10n),
              excludeSemantics: true,
              child: InkResponse(
                onTap: () => onPick(r),
                radius: 26,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: r == current ? BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle) : null,
                  child: Text(r.emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
            ),
          ),
        IconButton.filledTonal(
          tooltip: l10n.chatReactions,
          onPressed: onMore,
          icon: const Icon(Icons.add_reaction_outlined),
        ),
      ]),
    );
  }
}

/// Replaces the composer while the chat is a message request.
class MessageRequestBanner extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onAccept;
  final VoidCallback onDelete;
  final VoidCallback? onBlock;

  const MessageRequestBanner({super.key, required this.conversation, required this.onAccept, required this.onDelete, this.onBlock});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final c = conversation;
    final title = c.isGroup
        ? l10n.chatGroupRequestBanner
        : l10n.chatRequestBanner(c.displayTitle(l10n.chatSomeone));
    return Material(
      color: cs.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, textAlign: TextAlign.center, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              c.isGroup ? l10n.chatGroupRequestHint : l10n.chatRequestBannerHint,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(children: [
              if (onBlock != null) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: cs.error),
                    onPressed: onBlock,
                    child: Text(l10n.chatBlock),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: OutlinedButton(onPressed: onDelete, child: Text(l10n.commonDelete))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton(onPressed: onAccept, child: Text(l10n.chatAccept))),
            ]),
          ]),
        ),
      ),
    );
  }
}
