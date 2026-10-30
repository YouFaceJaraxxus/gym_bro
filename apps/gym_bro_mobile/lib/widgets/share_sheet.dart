import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/chat.dart';
import '../models/people.dart';
import '../models/post.dart';
import '../models/shared_content.dart';
import '../pages/chat/chat_widgets.dart';
import '../pages/stories/story_composer_page.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'post_attachment_card.dart';
import 'share_post.dart';
import 'shared_content_card.dart';
import 'social_widgets.dart';

// Instagram's share sheet: pick people and chats (recent chats by default,
// people search while typing), add a note, send — one message each. Quick
// actions above: "Add to story" and "Share as post" where they apply.

enum _QuickAction { story, post }

/// Sending a post: titled by who posted it, previewed by its first photo.
ShareRequest postShareRequest(Post p) => ShareRequest.of(
  ShareKind.post,
  p.id,
  title: p.business?.name ?? p.author?.fullName,
  // Shaped like the server's post preview, so the story composer's card
  // looks like the post before it's posted.
  preview: PostAttachment({
    'image_url': ?(p.images.firstOrNull?.isVideo == false ? p.imageUrl : null),
    'thumbnail_url': ?p.imageUrl,
    'media_type': ?p.images.firstOrNull?.mediaType,
    'media_count': p.images.length,
    'caption': p.content,
    'post_type': p.postType.apiValue,
    'attachment': ?p.attachment?.json,
    if (p.author != null)
      'author': {
        'id': p.author!.id,
        'username': p.author!.username,
        'name': p.author!.name,
        'last_name': p.author!.lastName,
        'avatar_url': p.author!.avatarUrl,
      },
  }),
);

/// The share sheet: send [request] to people / chats (one message each, with
/// an optional note), "Add to story" when it can go in a story, and "Share as
/// post" when it can be posted.
Future<void> showShareSheet(BuildContext context, ShareRequest request) async {
  final l10n = context.l10n;
  if (request.isFuture()) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l10n.postShareFutureBlocked)));
    return;
  }
  final action = await showModalBottomSheet<_QuickAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => ShareSheet(request: request),
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case _QuickAction.story:
      await openStoryComposer(context, share: request);
    case _QuickAction.post:
      await sharePost(context, request.postTarget!);
  }
}

/// The sheet's content (public for tests). Pops with a quick action to run
/// after it closes, or nothing once sent.
class ShareSheet extends StatefulWidget {
  const ShareSheet({super.key, required this.request});

  final ShareRequest request;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

/// One row: a person (their direct chat) or a group chat.
class _Target {
  const _Target.person(this.person) : conversation = null;
  const _Target.group(Conversation this.conversation) : person = null;

  final PersonSummary? person;
  final Conversation? conversation;

  /// Direct chats count as the person, so they're never sent twice.
  String get key => person != null ? 'u:${person!.id}' : 'c:${conversation!.id}';
}

class _ShareSheetState extends State<ShareSheet> {
  final _api = ApiService();
  final _search = TextEditingController();
  final _note = TextEditingController();
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
    _note.dispose();
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
      final results = await _api.shareToChats(
        token,
        widget.request,
        userIds: [for (final t in targets) ?t.person?.id],
        conversationIds: [for (final t in targets) ?t.conversation?.id],
        body: _note.text,
      );
      final sent = results.where((r) => r.sent).length;
      final failed = [
        for (final r in results)
          if (!r.sent) _nameOf(targets, r) ?? l10n.chatSomeone,
      ];
      nav.pop();
      messenger?.showSnackBar(SnackBar(
        content: Text(failed.isEmpty ? l10n.shareSheetSent(sent) : l10n.shareSheetSomeFailed(failed.join(', '))),
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
    final r = widget.request;
    final list = _query.isEmpty ? _recent : _results;
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _Header(request: r),
        ),
        if (r.kind.storyable || r.postTarget != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              if (r.kind.storyable)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.add_circle_outline, size: 18),
                    label: Text(l10n.shareSheetAddToStory),
                    onPressed: () => Navigator.of(context).pop(_QuickAction.story),
                  ),
                ),
              if (r.postTarget != null)
                ActionChip(
                  avatar: const Icon(Icons.dynamic_feed_outlined, size: 18),
                  label: Text(l10n.shareSheetShareAsPost),
                  onPressed: () => Navigator.of(context).pop(_QuickAction.post),
                ),
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
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ),
        Expanded(child: _list(context, scroll, list)),
        const Divider(height: 1),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + insets),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _note,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l10n.shareSheetMessageHint,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _selected.isEmpty || _sending ? null : _send,
              child: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_selected.length > 1 ? l10n.shareSheetSendTo(_selected.length) : l10n.shareSheetSend),
            ),
          ]),
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

/// What's being shared, as one compact row.
class _Header extends StatelessWidget {
  const _Header({required this.request});

  final ShareRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final r = request;
    final type = r.kind.postType;
    final image = r.preview.imageUrl ?? r.preview.json['avatar_url']?.toString() ?? r.preview.json['media_url']?.toString();
    final title = r.title ?? r.preview.title ?? shareKindLabel(l10n, r.kind);
    return Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(r.kind == ShareKind.user ? 22 : 10),
        child: SizedBox(
          width: 44,
          height: 44,
          child: image != null
              ? MediaImage(url: image)
              : Container(
                  color: cs.primaryContainer,
                  child: Icon(
                    type != null ? postTypeIcon(type) : _kindIcon(r.kind),
                    color: cs.onPrimaryContainer,
                  ),
                ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.shareSheetTitle, style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleMedium),
        ]),
      ),
    ]);
  }

  static IconData _kindIcon(ShareKind k) => switch (k) {
    ShareKind.post => Icons.grid_on,
    ShareKind.story => Icons.amp_stories_outlined,
    ShareKind.user => Icons.person_outline,
    ShareKind.business => Icons.fitness_center,
    ShareKind.shopItem => Icons.shopping_bag_outlined,
    _ => Icons.ios_share,
  };
}
