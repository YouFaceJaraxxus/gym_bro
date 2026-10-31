import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/chat.dart';
import '../../models/social.dart' show relativeTime;
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/social_widgets.dart';
import 'chat_thread_page.dart';
import 'chat_widgets.dart';

/// Instagram-style notes above the inbox: my bubble first ("Leave a note" or
/// my note), then the notes of people whose audience I'm in. Tapping mine
/// opens the editor; tapping someone's opens it with a reply field (the
/// reply goes to their DMs).

/// Height of [NotesRow] (the inbox lays out its empty state around it).
const kNotesRowHeight = 128.0;

class NotesRow extends StatefulWidget {
  const NotesRow({super.key});

  @override
  State<NotesRow> createState() => NotesRowState();
}

class NotesRowState extends State<NotesRow> {
  final _api = ApiService();
  NotesFeed _feed = NotesFeed.empty;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Refetches the notes (the inbox's pull to refresh calls this).
  Future<void> reload() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final feed = await _api.getNotes(token);
      if (mounted) setState(() => _feed = feed);
    } catch (_) {
      // Keep what's shown; my bubble still works.
    }
  }

  Future<void> _editMine() async {
    final updated = await showAppBottomSheet<NotesFeed>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NoteEditorSheet(current: _feed.mine),
    );
    if (updated != null && mounted) setState(() => _feed = updated);
  }

  Future<void> _open(UserNote note) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final sent = await showAppBottomSheet<ChatMessage>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NoteReplySheet(note: note),
    );
    if (sent == null || !mounted) return;
    final nav = Navigator.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.chatNotesReplySent),
        action: SnackBarAction(
          label: l10n.chatNotesOpenChat,
          onPressed: () => nav.push<void>(MaterialPageRoute(
            builder: (_) => ChatThreadPage(conversationId: sent.conversationId),
          )),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final me = chatMe();
    final mine = _feed.mine;
    return SizedBox(
      height: kNotesRowHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          NoteBubbleAvatar(
            avatarUrl: me?.avatarUrl,
            initials: me?.initials ?? '?',
            text: mine?.body ?? l10n.chatNotesLeaveNote,
            placeholder: mine == null,
            label: l10n.chatNotesYourNote,
            closeFriends: mine?.audience == NoteAudience.closeFriends,
            onTap: _editMine,
          ),
          for (final n in _feed.notes)
            NoteBubbleAvatar(
              avatarUrl: n.user.avatarUrl,
              initials: n.user.initials,
              text: n.body,
              label: n.user.name.isNotEmpty ? n.user.name : n.user.username,
              onTap: () => _open(n),
            ),
        ],
      ),
    );
  }
}

/// An avatar with a small speech bubble above it and a name below.
class NoteBubbleAvatar extends StatelessWidget {
  const NoteBubbleAvatar({
    super.key,
    required this.avatarUrl,
    required this.initials,
    required this.text,
    required this.label,
    this.placeholder = false,
    this.closeFriends = false,
    required this.onTap,
  });

  final String? avatarUrl;
  final String initials;
  final String text;
  final String label;

  /// "Leave a note": muted text instead of a note.
  final bool placeholder;

  /// My note is for close friends only (green ring on the bubble).
  final bool closeFriends;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const width = 84.0;
    return Semantics(
      button: true,
      label: '$label: $text',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: width,
          child: Column(children: [
            SizedBox(
              height: 100,
              child: Stack(alignment: Alignment.topCenter, clipBehavior: Clip.none, children: [
                Positioned(
                  top: 30,
                  child: UserAvatar(url: avatarUrl, initials: initials, radius: 32),
                ),
                Positioned(
                  top: 2,
                  child: _SpeechBubble(
                    text: text,
                    maxWidth: width - 6,
                    muted: placeholder,
                    border: closeFriends ? Colors.green : null,
                    color: cs.surfaceContainerHighest,
                    style: tt.labelSmall?.copyWith(
                      color: placeholder ? cs.onSurfaceVariant : cs.onSurface,
                      fontWeight: placeholder ? null : FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.text,
    required this.maxWidth,
    required this.color,
    this.style,
    this.muted = false,
    this.border,
  });

  final String text;
  final double maxWidth;
  final Color color;
  final TextStyle? style;
  final bool muted;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final side = border == null ? BorderSide.none : BorderSide(color: border!, width: 1.5);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 36),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.fromBorderSide(side),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: style),
      ),
      // The tail: two dots trailing down to the avatar.
      Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      ),
    ]);
  }
}

/// Write, change or delete my note (≤ 60 characters) and pick who sees it.
/// Pops with the updated [NotesFeed].
class NoteEditorSheet extends StatefulWidget {
  const NoteEditorSheet({super.key, this.current});

  final MyNote? current;

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  final _api = ApiService();
  late final _text = TextEditingController(text: widget.current?.body ?? '');
  late NoteAudience _audience = widget.current?.audience ?? NoteAudience.mutuals;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run(Future<NotesFeed> Function(String token) call, String done) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final feed = await call(token);
      nav.pop(feed);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(chatErrorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    Widget option(NoteAudience a, IconData icon, String label) {
      final selected = _audience == a;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: a == NoteAudience.closeFriends ? Colors.green : null),
        title: Text(label),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: selected ? cs.primary : cs.outline,
        ),
        selected: selected,
        onTap: _busy ? null : () => setState(() => _audience = a),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + insets),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l10n.chatNotesEditorTitle, style: tt.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          l10n.chatNotesVisibleFor,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _text,
          autofocus: true,
          maxLength: kNoteMaxLength,
          maxLines: 2,
          minLines: 1,
          enabled: !_busy,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l10n.chatNotesHint,
            filled: true,
            fillColor: cs.surfaceContainerHigh,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 4),
        Text(l10n.chatNotesAudienceLabel, style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
        option(NoteAudience.mutuals, Icons.people_outline, l10n.chatNotesAudienceMutuals),
        option(NoteAudience.closeFriends, Icons.stars_rounded, l10n.chatNotesAudienceCloseFriends),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy || _text.text.trim().isEmpty
              ? null
              : () => _run((t) => _api.setNote(t, _text.text, audience: _audience), l10n.chatNotesShared),
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.chatNotesShare),
        ),
        if (widget.current != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.error),
            onPressed: _busy ? null : () => _run(_api.deleteNote, l10n.chatNotesDeleted),
            child: Text(l10n.chatNotesDelete),
          ),
      ]),
    );
  }
}

/// Someone's note with a reply field; pops with the sent message.
class NoteReplySheet extends StatefulWidget {
  const NoteReplySheet({super.key, required this.note});

  final UserNote note;

  @override
  State<NoteReplySheet> createState() => _NoteReplySheetState();
}

class _NoteReplySheetState extends State<NoteReplySheet> {
  final _api = ApiService();
  final _text = TextEditingController();
  final _clientId = newChatClientId();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final sent = await _api.replyToNote(token, widget.note.userId, body, clientId: _clientId);
      nav.pop(sent);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(chatErrorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final n = widget.note;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + insets),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        UserAvatar(url: n.user.avatarUrl, initials: n.user.initials, radius: 36),
        const SizedBox(height: 8),
        Text(n.user.fullName.isNotEmpty ? n.user.fullName : n.user.username, style: tt.titleSmall),
        if (n.createdAt != null)
          Text(relativeTime(l10n, n.createdAt!), style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
          child: Text(n.body, textAlign: TextAlign.center, style: tt.titleMedium),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _text,
              autofocus: true,
              enabled: !_sending,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.chatNotesReplyHint(n.user.name.isNotEmpty ? n.user.name : n.user.username),
                isDense: true,
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: l10n.chatSend,
            color: cs.primary,
            onPressed: _sending || _text.text.trim().isEmpty ? null : _send,
            icon: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
          ),
        ]),
      ]),
    );
  }
}
