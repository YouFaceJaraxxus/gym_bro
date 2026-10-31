import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/chat.dart';
import '../../models/people.dart';
import '../../models/shared_content.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/social_widgets.dart';
import 'chat_widgets.dart';

/// "Forward" from a message's actions: pick people and chats (recent chats by
/// default, people search while typing), then send a copy to each — like
/// the share sheet, minus the note and quick actions.
Future<void> showForwardSheet(BuildContext context, ChatMessage message) => showAppBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => ForwardSheet(message: message),
);

/// One row: a person (their direct chat) or a group chat.
class _Target {
  const _Target.person(this.person) : conversation = null;
  const _Target.group(Conversation this.conversation) : person = null;

  final PersonSummary? person;
  final Conversation? conversation;

  /// Direct chats count as the person, so they're never sent twice.
  String get key => person != null ? 'u:${person!.id}' : 'c:${conversation!.id}';
}

class ForwardSheet extends StatefulWidget {
  const ForwardSheet({super.key, required this.message});

  final ChatMessage message;

  @override
  State<ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends State<ForwardSheet> {
  final _api = ApiService();
  final _search = TextEditingController();
  Timer? _debounce;
  int _searchSeq = 0;

  List<_Target> _recent = const [];
  List<_Target> _results = const [];
  final _selected = <String, _Target>{};
  bool _loading = true;
  bool _searching = false;
  bool _sending = false;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final convs = await _api.getConversations(token, pageSize: 30);
      if (!mounted) return;
      setState(() {
        _recent = [
          for (final c in convs)
            if (c.isGroup)
              _Target.group(c)
            else if (c.otherUser != null)
              _Target.person(c.otherUser!),
        ];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.shareSheetLoadFailed;
      });
    }
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    final q = value.trim();
    setState(() {
      _query = q;
      _searching = q.isNotEmpty;
      if (q.isEmpty) _results = const [];
    });
    if (q.isNotEmpty) _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    final seq = ++_searchSeq;
    try {
      final token = await AuthManager.instance.getValidToken();
      final people = await _api.searchPeople(token, q);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = [for (final p in people) if (p.id != chatMyId) _Target.person(p)];
        _searching = false;
      });
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = const [];
        _searching = false;
      });
    }
  }

  void _toggle(_Target t) => setState(() {
    if (_selected.remove(t.key) == null) _selected[t.key] = t;
  });

  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final nav = Navigator.of(context);
    setState(() => _sending = true);
    final targets = _selected.values.toList();
    try {
      final token = await AuthManager.instance.getValidToken();
      final result = await _api.forwardMessage(
        token,
        widget.message.id,
        userIds: [for (final t in targets) ?t.person?.id],
        conversationIds: [for (final t in targets) ?t.conversation?.id],
      );
      final failed = [
        for (final r in result.results)
          if (!r.sent) _nameOf(targets, r) ?? l10n.chatSomeone,
      ];
      nav.pop();
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(failed.isEmpty ? l10n.shareSheetSent(result.sent) : l10n.shareSheetSomeFailed(failed.join(', '))),
        ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger?.showSnackBar(SnackBar(content: Text(l10n.shareSheetFailed(chatErrorText(e)))));
    }
  }

  String? _nameOf(List<_Target> targets, ShareSendResult r) {
    for (final t in targets) {
      if (r.userId != null && t.person?.id == r.userId) return t.person!.fullName;
      if (r.conversationId != null && t.conversation?.id == r.conversationId) {
        return t.conversation!.displayTitle(context.l10n.chatGroupFallback);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final list = _query.isEmpty ? _recent : _results;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Icon(Icons.shortcut_rounded, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(l10n.chatForwardTitle, style: tt.titleMedium)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            onChanged: _onQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.shareSheetSearchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _query.isEmpty ? l10n.shareSheetRecent : l10n.shareSheetPeople,
              style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ),
        Expanded(child: _list(context, scroll, list)),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selected.isEmpty || _sending ? null : _send,
              child: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_selected.length > 1 ? l10n.shareSheetSendTo(_selected.length) : l10n.shareSheetSend),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _list(BuildContext context, ScrollController scroll, List<_Target> list) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if ((_query.isEmpty && _loading) || _searching) return const Center(child: CircularProgressIndicator());
    // Keep picks visible even when they aren't in the current list.
    final shown = [
      ...list,
      for (final t in _selected.values)
        if (!list.any((x) => x.key == t.key)) t,
    ];
    if (shown.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _query.isNotEmpty ? l10n.shareSheetNoResults : (_error ?? l10n.shareSheetNoChats),
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: scroll,
      itemCount: shown.length,
      itemBuilder: (context, i) {
        final t = shown[i];
        final selected = _selected.containsKey(t.key);
        final p = t.person;
        final c = t.conversation;
        return ListTile(
          onTap: () => _toggle(t),
          leading: p != null
              ? UserAvatar(url: p.avatarUrl, initials: p.initials)
              : ConversationAvatar(conversation: c!, radius: 20),
          title: Text(p?.fullName ?? c!.displayTitle(l10n.chatGroupFallback), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            p != null ? '@${p.username}' : l10n.shareSheetGroupMembers(c!.participantCount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: selected ? cs.primary : cs.outline,
          ),
        );
      },
    );
  }
}
