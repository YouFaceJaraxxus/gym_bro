import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/chat.dart';
import '../../models/people.dart';
import '../../services/auth_manager.dart';
import '../../widgets/shared_content_card.dart';
import '../../widgets/social_widgets.dart';
import '../../widgets/app_bottom_sheet.dart';

/// Small building blocks shared by the chat screens: avatars, badges,
/// previews of system events, dialogs and the swipe-to-reply gesture.

// ── Helpers ───────────────────────────────────────────────────────────────────

/// My users.id ('' when signed out).
String get chatMyId => AuthManager.instance.profile?.id ?? '';

/// Me as a [PersonSummary] (for optimistic bubbles).
PersonSummary? chatMe() {
  final p = AuthManager.instance.profile;
  if (p == null) return null;
  return PersonSummary(id: p.id, username: p.username, name: p.name, lastName: p.lastName, avatarUrl: p.avatarUrl);
}

final _random = Random();

/// Unique per send; makes retries idempotent and matches the realtime echo.
String newChatClientId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_random.nextInt(1 << 31).toRadixString(36)}';

/// Active within the last few minutes ("Active now" / green dot).
bool isRecentlyActive(DateTime? at) => at != null && DateTime.now().difference(at) < const Duration(minutes: 5);

String chatErrorText(Object e) => e.toString().replaceFirst('Exception: ', '');

void showChatSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// "📷 Photo", "🎥 Video", …
String chatMediaLabel(AppLocalizations l10n, AttachmentType type) => switch (type) {
  AttachmentType.image => l10n.chatMediaPhoto,
  AttachmentType.video => l10n.chatMediaVideo,
  AttachmentType.audio => l10n.chatMediaAudio,
  AttachmentType.file => l10n.chatMediaFile,
};

/// Initials of a group title ("Leg Day Crew" → "LD").
String titleInitials(String title) {
  final words = title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  final s = words.take(2).map((w) => w.characters.first).join().toUpperCase();
  return s.isEmpty ? '?' : s;
}

/// The conversation with a fresh member list (settings responses omit it).
Conversation conversationWithMembers(Conversation c, List<ConversationMember> members) => Conversation(
  id: c.id,
  kind: c.kind,
  title: c.title,
  description: c.description,
  avatarUrl: c.avatarUrl,
  createdBy: c.createdBy,
  lastMessageAt: c.lastMessageAt,
  myRole: c.myRole,
  myStatus: c.myStatus,
  muted: c.muted,
  archived: c.archived,
  lastReadAt: c.lastReadAt,
  unreadCount: c.unreadCount,
  participantCount: c.participantCount,
  participants: c.participants,
  otherUser: c.otherUser,
  otherLastActiveAt: c.otherLastActiveAt,
  lastMessage: c.lastMessage,
  members: members,
);

/// "Today", "Yesterday", "Monday", "12 Mar 2026".
String chatDayLabel(AppLocalizations l10n, DateTime day) {
  final today = DateUtils.dateOnly(DateTime.now());
  final d = DateUtils.dateOnly(day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return l10n.commonToday;
  if (diff == 1) return l10n.chatYesterday;
  if (diff < 7) return DateFormat.EEEE(l10n.localeName).format(d);
  if (d.year == today.year) return DateFormat.MMMd(l10n.localeName).format(d);
  return DateFormat.yMMMd(l10n.localeName).format(d);
}

/// Inbox row time: "14:05" today, weekday this week, else a short date.
String chatListTime(AppLocalizations l10n, DateTime at) {
  final today = DateUtils.dateOnly(DateTime.now());
  final d = DateUtils.dateOnly(at);
  final diff = today.difference(d).inDays;
  if (diff == 0) return DateFormat.Hm(l10n.localeName).format(at);
  if (diff < 7) return DateFormat.E(l10n.localeName).format(at);
  return DateFormat.MMMd(l10n.localeName).format(at);
}

String chatClockTime(AppLocalizations l10n, DateTime at) => DateFormat.Hm(l10n.localeName).format(at);

/// The sentence for a system message (created / added / removed / left /
/// renamed / photo_changed / role_changed). [nameOf] maps a user id to a
/// first name.
String systemEventText(
  AppLocalizations l10n, {
  required Map<String, dynamic> metadata,
  required String? actorId,
  String? actorName,
  required String Function(String userId) nameOf,
}) {
  final me = chatMyId;
  final who = actorId != null && actorId == me ? 'me' : 'other';
  final name = actorName ?? (actorId == null ? l10n.chatSomeone : nameOf(actorId));
  String target(Object? id) => id is String ? (id == me ? l10n.chatYouObject : nameOf(id)) : l10n.chatSomeone;
  switch (metadata['event']) {
    case 'created':
      return l10n.chatSysCreated(who, name);
    case 'added':
      final ids = (metadata['user_ids'] as List<dynamic>? ?? const []).map(target).toList();
      return l10n.chatSysAdded(who, name, ids.isEmpty ? l10n.chatSomeone : ids.join(', '));
    case 'removed':
      return l10n.chatSysRemoved(who, name, target(metadata['user_id']));
    case 'left':
      return l10n.chatSysLeft(who, name);
    case 'renamed':
      final title = metadata['title'];
      return title is String && title.isNotEmpty ? l10n.chatSysRenamed(who, name, title) : l10n.chatSysNameCleared(who, name);
    case 'photo_changed':
      return l10n.chatSysPhoto(who, name);
    case 'role_changed':
      final t = target(metadata['user_id']);
      return switch (metadata['role']) {
        'admin' => l10n.chatSysMadeAdmin(who, name, t),
        'owner' => l10n.chatSysMadeOwner(who, name, t),
        _ => l10n.chatSysRemovedAdmin(who, name, t),
      };
    default:
      return l10n.chatSysUpdated(who, name);
  }
}

/// Inbox row preview and whether it should be italic (system / unsent).
({String text, bool italic}) lastMessagePreview(AppLocalizations l10n, Conversation c) {
  final m = c.lastMessage;
  if (m == null) return (text: '', italic: false);
  final me = chatMyId;
  if (m.deleted) return (text: l10n.chatMessageUnsent, italic: true);
  if (m.kind == 'system') {
    String nameOf(String id) {
      if (id == m.senderId && m.senderName != null) return m.senderName!;
      for (final p in c.participants) {
        if (p.id == id) return p.name;
      }
      return l10n.chatSomeone;
    }

    return (
      text: systemEventText(l10n, metadata: m.metadata, actorId: m.senderId, actorName: m.senderName, nameOf: nameOf),
      italic: true,
    );
  }
  final raw = m.preview ?? '';
  var text = switch ((m.kind, raw)) {
    ('media', 'image') => l10n.chatMediaPhoto,
    ('media', 'video') => l10n.chatMediaVideo,
    ('media', 'audio') => l10n.chatMediaAudio,
    ('media', 'file') => l10n.chatMediaFile,
    _ => raw.replaceAll('\n', ' '),
  };
  if (m.storyMode == 'reaction') {
    text = l10n.sharedStoryReactedPreview(raw);
  } else if (m.storyMode == 'reply') {
    text = l10n.sharedStoryRepliedPreview(text);
  } else if (raw.isEmpty && m.shareKind != null) {
    text = sharedPreviewText(l10n, m.shareKind!);
  }
  if (m.senderId == me) return (text: l10n.chatPreviewYou(text), italic: false);
  if (c.isGroup && m.senderName != null) return (text: l10n.chatPreviewSender(m.senderName!, text), italic: false);
  return (text: text, italic: false);
}

String reportReasonLabel(AppLocalizations l10n, ReportReason r) => switch (r) {
  ReportReason.spam => l10n.chatReportSpam,
  ReportReason.harassment => l10n.chatReportHarassment,
  ReportReason.inappropriate => l10n.chatReportInappropriate,
  ReportReason.impersonation => l10n.chatReportImpersonation,
  ReportReason.other => l10n.chatReportOther,
};

Future<ReportReason?> pickReportReason(BuildContext context) {
  final l10n = context.l10n;
  return showAppBottomSheet<ReportReason>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(l10n.chatReportTitle, style: Theme.of(ctx).textTheme.titleMedium),
        ),
        for (final r in ReportReason.values)
          ListTile(title: Text(reportReasonLabel(l10n, r)), onTap: () => Navigator.pop(ctx, r)),
      ]),
    ),
  );
}

/// A confirm dialog; [destructive] paints the action in the error color.
Future<bool> confirmChatAction(
  BuildContext context, {
  String? title,
  required String body,
  required String confirm,
  bool destructive = true,
}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: title == null ? null : Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          TextButton(
            style: destructive ? TextButton.styleFrom(foregroundColor: cs.error) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

// ── Avatars and badges ────────────────────────────────────────────────────────

/// A conversation's avatar: the other person (with an online dot), the
/// group photo, or two overlapping member avatars.
class ConversationAvatar extends StatelessWidget {
  final Conversation conversation;
  final double radius;
  final bool online;

  const ConversationAvatar({super.key, required this.conversation, this.radius = 26, this.online = false});

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    if (!c.isGroup) {
      final other = c.otherUser ?? (c.participants.isEmpty ? null : c.participants.first);
      return UserAvatar(url: other?.avatarUrl, initials: other?.initials ?? '?', radius: radius, online: online);
    }
    if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) {
      return UserAvatar(url: c.avatarUrl, initials: titleInitials(c.title ?? ''), radius: radius);
    }
    final people = c.participants.isNotEmpty ? c.participants : c.members.map((m) => m.person).where((p) => p.id != chatMyId).toList();
    if (people.length < 2) {
      final p = people.isEmpty ? null : people.first;
      return UserAvatar(url: p?.avatarUrl, initials: p?.initials ?? titleInitials(c.title ?? ''), radius: radius);
    }
    return StackedAvatars(people: people.take(2).toList(), size: radius * 2);
  }
}

/// Two overlapping avatars in a [size]×[size] square (group chats).
class StackedAvatars extends StatelessWidget {
  final List<PersonSummary> people;
  final double size;

  const StackedAvatars({super.key, required this.people, required this.size});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final small = size * 0.36;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(children: [
        Positioned(
          top: 0,
          right: 0,
          child: UserAvatar(url: people[0].avatarUrl, initials: people[0].initials, radius: small),
        ),
        Positioned(
          left: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
            child: UserAvatar(url: people[1].avatarUrl, initials: people[1].initials, radius: small),
          ),
        ),
      ]),
    );
  }
}

/// A tiny row of overlapping avatars ("seen by" in groups).
class TinyAvatarRow extends StatelessWidget {
  final List<PersonSummary> people;
  final double radius;
  final int max;

  const TinyAvatarRow({super.key, required this.people, this.radius = 7, this.max = 5});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shown = people.take(max).toList();
    final extra = people.length - shown.length;
    final step = radius * 1.4;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: radius * 2 + (shown.length - 1) * step + 2,
        height: radius * 2 + 2,
        child: Stack(children: [
          for (final (i, p) in shown.indexed)
            Positioned(
              left: i * step,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
                child: UserAvatar(url: p.avatarUrl, initials: p.initials, radius: radius),
              ),
            ),
        ]),
      ),
      if (extra > 0)
        Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Text('+$extra', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        ),
    ]);
  }
}

/// Unread count pill ("3", "99+").
class UnreadBadge extends StatelessWidget {
  final int count;
  final bool muted;

  const UnreadBadge({super.key, required this.count, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? cs.outline : cs.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: muted ? cs.surface : cs.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A small rounded label ("Owner", "Admin", "Invited").
class ChatTag extends StatelessWidget {
  final String text;
  final bool strong;

  const ChatTag(this.text, {super.key, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: strong ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: strong ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A centered "nothing here" block with an icon.
class ChatEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const ChatEmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title, style: tt.titleMedium, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

/// Error text with a retry button.
class ChatErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ChatErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_outlined, size: 44, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
        ]),
      ),
    );
  }
}

// ── Swipe to reply ────────────────────────────────────────────────────────────

/// Drag a message to the right to reply (with a reply icon that fades in and
/// a haptic tick once the threshold is crossed).
class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;

  const SwipeToReply({super.key, required this.child, this.onReply});

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  static const _threshold = 56.0;
  static const _max = 76.0;
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 180))
    ..addListener(() => setState(() => _dx = _from * (1 - Curves.easeOut.transform(_back.value))));
  double _dx = 0;
  double _from = 0;
  bool _armed = false;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _end() {
    if (_armed) widget.onReply?.call();
    _armed = false;
    _from = _dx;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onReply == null) return widget.child;
    final cs = Theme.of(context).colorScheme;
    final t = (_dx / _threshold).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _back.stop(),
      onHorizontalDragUpdate: (d) {
        final next = (_dx + d.delta.dx).clamp(0.0, _max);
        final armed = next >= _threshold;
        if (armed && !_armed) HapticFeedback.selectionClick();
        setState(() {
          _dx = next;
          _armed = armed;
        });
      },
      onHorizontalDragEnd: (_) => _end(),
      onHorizontalDragCancel: _end,
      child: Stack(alignment: Alignment.centerLeft, children: [
        if (_dx > 0)
          Positioned(
            left: 8,
            child: Opacity(
              opacity: t,
              child: Transform.scale(
                scale: 0.6 + 0.4 * t,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
                  child: Icon(Icons.reply_rounded, size: 18, color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ),
        Transform.translate(offset: Offset(_dx, 0), child: widget.child),
      ]),
    );
  }
}
