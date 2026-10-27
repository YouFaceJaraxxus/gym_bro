import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/chat.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/realtime_service.dart';
import 'chat_thread_page.dart';
import 'chat_widgets.dart';
import 'new_chat_page.dart';

/// Ticks whenever the lists should refetch (realtime events, returning
/// from a thread, a pull elsewhere).
class _RefreshSignal extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Messenger-style inbox: Chats / Requests tabs, search, swipe actions and
/// an Archived view; updates live from my realtime user topic.
class ChatInboxPage extends StatefulWidget {
  const ChatInboxPage({super.key});

  @override
  State<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _search = TextEditingController();
  final _refresh = _RefreshSignal();
  StreamSubscription<UserEvent>? _sub;
  Timer? _debounce;
  String _query = '';
  int _requestCount = 0;

  @override
  void initState() {
    super.initState();
    RealtimeService.instance.connect();
    _sub = RealtimeService.instance.userEvents.listen((e) {
      if (e.event == 'inbox' || e.event == 'conversation_added' || e.event == 'conversation_removed') {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), _refresh.ping);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    _tabs.dispose();
    _search.dispose();
    _refresh.dispose();
    super.dispose();
  }

  Future<void> _newChat() async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const NewChatPage()));
    _refresh.ping();
  }

  void _openArchived() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(context.l10n.chatArchivedTitle)),
          body: ConversationList(box: ChatBox.archived, refresh: _refresh),
        ),
      ),
    ).then((_) => _refresh.ping());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatInboxTitle),
        actions: [
          PopupMenuButton<int>(
            tooltip: l10n.chatMoreOptions,
            onSelected: (_) => _openArchived(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 0,
                child: Row(children: [
                  const Icon(Icons.archive_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(l10n.chatArchived),
                ]),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.chatTabChats),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(l10n.chatTabRequests),
                if (_requestCount > 0) ...[
                  const SizedBox(width: 6),
                  UnreadBadge(count: _requestCount),
                ],
              ]),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.chatNewMessage,
        onPressed: _newChat,
        child: const Icon(Icons.edit_square),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.chatSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.commonClose,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            ConversationList(box: ChatBox.inbox, query: _query, refresh: _refresh),
            ConversationList(
              box: ChatBox.requests,
              query: _query,
              refresh: _refresh,
              onCount: (n) {
                if (mounted && n != _requestCount) setState(() => _requestCount = n);
              },
            ),
          ]),
        ),
      ]),
    );
  }
}

enum _RowAction { mute, archive, markRead, delete, accept, block }

/// One inbox box (inbox, requests or archived): paginated, pull to refresh,
/// filtered by [query], refetched when [refresh] ticks.
class ConversationList extends StatefulWidget {
  final ChatBox box;
  final String query;
  final Listenable? refresh;

  /// Loaded row count (for the Requests badge).
  final ValueChanged<int>? onCount;

  const ConversationList({super.key, required this.box, this.query = '', this.refresh, this.onCount});

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> with AutomaticKeepAliveClientMixin {
  static const _pageSize = 30;
  final _api = ApiService();
  final _items = <Conversation>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(_reload);
    _load();
  }

  @override
  void didUpdateWidget(ConversationList old) {
    super.didUpdateWidget(old);
    if (old.refresh != widget.refresh) {
      old.refresh?.removeListener(_reload);
      widget.refresh?.addListener(_reload);
    }
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_reload);
    super.dispose();
  }

  /// Refetches the first page (sized to what's loaded) and replaces it.
  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final size = _items.length.clamp(_pageSize, 100);
      final items = await _api.getConversations(token, box: widget.box, pageSize: size);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _hasMore = items.length >= size;
        _loading = false;
        _error = null;
      });
      widget.onCount?.call(_items.length);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = chatErrorText(e);
      });
    }
  }

  void _reload() => _load();

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final page = _items.length ~/ _pageSize;
      final items = await _api.getConversations(token, box: widget.box, page: page, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        final ids = _items.map((c) => c.id).toSet();
        _items.addAll(items.where((c) => !ids.contains(c.id)));
        _hasMore = items.length >= _pageSize;
        _loadingMore = false;
      });
      widget.onCount?.call(_items.length);
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<Conversation> get _visible {
    final q = widget.query.toLowerCase();
    if (q.isEmpty) return _items;
    final l10n = context.l10n;
    return _items.where((c) {
      if (c.displayTitle(l10n.chatGroupFallback).toLowerCase().contains(q)) return true;
      return c.participants.any((p) => p.fullName.toLowerCase().contains(q) || p.username.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _open(Conversation c) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => ChatThreadPage(conversationId: c.id, initial: c)),
    );
    if (mounted) _load();
  }

  void _replace(Conversation c) {
    final i = _items.indexWhere((x) => x.id == c.id);
    if (i >= 0) setState(() => _items[i] = c);
  }

  /// Refetches every list sharing the signal (an item moved between boxes).
  void _pingAll() {
    final signal = widget.refresh;
    if (signal is _RefreshSignal) {
      signal.ping();
    } else {
      _load();
    }
  }

  void _remove(String id) {
    setState(() => _items.removeWhere((x) => x.id == id));
    widget.onCount?.call(_items.length);
  }

  /// Runs a row action; returns whether the row should leave this list.
  Future<bool> _act(Conversation c, _RowAction action) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    void snack(String text, {SnackBarAction? undo}) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text), action: undo));
    }

    try {
      final token = await AuthManager.instance.getValidToken();
      if (!mounted) return false;
      switch (action) {
        case _RowAction.mute:
          final updated = await _api.updateChatSettings(token, c.id, muted: !c.muted);
          _replace(updated);
          snack(updated.muted ? l10n.chatMutedSnack : l10n.chatUnmutedSnack);
          return false;
        case _RowAction.archive:
          final archive = widget.box != ChatBox.archived;
          await _api.updateChatSettings(token, c.id, archived: archive);
          _remove(c.id);
          snack(
            archive ? l10n.chatArchivedSnack : l10n.chatUnarchivedSnack,
            undo: SnackBarAction(
              label: l10n.chatUndo,
              onPressed: () async {
                try {
                  final t = await AuthManager.instance.getValidToken();
                  await _api.updateChatSettings(t, c.id, archived: !archive);
                } catch (_) {}
                _pingAll();
              },
            ),
          );
          return true;
        case _RowAction.markRead:
          await _api.markChatRead(token, c.id);
          await _load();
          return false;
        case _RowAction.delete:
          final confirmed = widget.box == ChatBox.requests ||
              await confirmChatAction(
                context,
                body: c.isGroup
                    ? l10n.chatLeaveGroupConfirm(c.displayTitle(l10n.chatGroupFallback))
                    : l10n.chatDeleteChatConfirm,
                confirm: c.isGroup ? l10n.chatLeaveGroup : l10n.commonDelete,
              );
          if (!confirmed) return false;
          await _api.removeFromChat(token, c.id, chatMyId);
          _remove(c.id);
          return true;
        case _RowAction.accept:
          await _api.acceptMessageRequest(token, c.id);
          _remove(c.id);
          _pingAll();
          return true;
        case _RowAction.block:
          final other = c.otherUser;
          if (other == null) return false;
          final ok = await confirmChatAction(
            context,
            title: l10n.chatBlockConfirmTitle(other.fullName),
            body: l10n.chatBlockConfirmBody,
            confirm: l10n.chatBlock,
          );
          if (!ok) return false;
          await _api.block(token, other.id);
          try {
            await _api.removeFromChat(token, c.id, chatMyId);
          } catch (_) {}
          _remove(c.id);
          snack(l10n.chatBlockedSnack(other.fullName));
          return true;
      }
    } catch (e) {
      snack(chatErrorText(e));
      return false;
    }
  }

  Future<void> _options(Conversation c) async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final requests = widget.box == ChatBox.requests;
    final action = await showModalBottomSheet<_RowAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: ConversationAvatar(conversation: c, radius: 20),
            title: Text(c.displayTitle(l10n.chatGroupFallback), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const Divider(),
          if (requests) ...[
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(l10n.chatAccept),
              onTap: () => Navigator.pop(ctx, _RowAction.accept),
            ),
            if (!c.isGroup)
              ListTile(
                leading: Icon(Icons.block, color: cs.error),
                title: Text(l10n.chatBlock, style: TextStyle(color: cs.error)),
                onTap: () => Navigator.pop(ctx, _RowAction.block),
              ),
          ] else ...[
            if (c.unreadCount > 0)
              ListTile(
                leading: const Icon(Icons.mark_chat_read_outlined),
                title: Text(l10n.chatMarkRead),
                onTap: () => Navigator.pop(ctx, _RowAction.markRead),
              ),
            ListTile(
              leading: Icon(c.muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
              title: Text(c.muted ? l10n.chatUnmute : l10n.chatMute),
              onTap: () => Navigator.pop(ctx, _RowAction.mute),
            ),
            ListTile(
              leading: Icon(widget.box == ChatBox.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
              title: Text(widget.box == ChatBox.archived ? l10n.chatUnarchive : l10n.chatArchive),
              onTap: () => Navigator.pop(ctx, _RowAction.archive),
            ),
          ],
          ListTile(
            leading: Icon(c.isGroup && !requests ? Icons.logout : Icons.delete_outline, color: cs.error),
            title: Text(
              c.isGroup && !requests ? l10n.chatLeaveGroup : (requests ? l10n.commonDelete : l10n.chatDeleteChat),
              style: TextStyle(color: cs.error),
            ),
            onTap: () => Navigator.pop(ctx, _RowAction.delete),
          ),
        ]),
      ),
    );
    if (action != null && mounted) await _act(c, action);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 300) _loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return ChatErrorState(
        message: _error!,
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _load();
        },
      );
    }
    final visible = _visible;
    Widget empty() => switch (widget.box) {
      _ when widget.query.isNotEmpty && _items.isNotEmpty =>
        ChatEmptyState(icon: Icons.search_off, title: l10n.chatNoResults(widget.query)),
      ChatBox.inbox => ChatEmptyState(
        icon: Icons.chat_bubble_outline,
        title: l10n.chatEmptyInbox,
        subtitle: l10n.chatEmptyInboxHint,
      ),
      ChatBox.requests => ChatEmptyState(
        icon: Icons.mark_email_unread_outlined,
        title: l10n.chatEmptyRequests,
        subtitle: l10n.chatEmptyRequestsHint,
      ),
      ChatBox.archived => ChatEmptyState(icon: Icons.archive_outlined, title: l10n.chatEmptyArchived),
    };
    return RefreshIndicator(
      onRefresh: _load,
      child: visible.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(height: constraints.maxHeight, child: empty()),
              ),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 4, bottom: 88),
                itemCount: visible.length + (_loadingMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= visible.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                    );
                  }
                  return _dismissible(visible[i]);
                },
              ),
            ),
    );
  }

  Widget _dismissible(Conversation c) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final requests = widget.box == ChatBox.requests;
    final archived = widget.box == ChatBox.archived;
    Widget bg(Color color, Color fg, IconData icon, String label, Alignment align) => Container(
      color: color,
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: fg),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
    final row = _ConversationTile(
      conversation: c,
      showRequestActions: requests,
      onTap: () => _open(c),
      onLongPress: () => _options(c),
      onAccept: () => _act(c, _RowAction.accept),
      onDecline: () => _act(c, _RowAction.delete),
    );
    return Dismissible(
      key: ValueKey('${widget.box.name}-${c.id}'),
      direction: requests ? DismissDirection.endToStart : DismissDirection.horizontal,
      // Swipe right: mute (the row stays).
      background: requests
          ? bg(cs.errorContainer, cs.onErrorContainer, Icons.delete_outline, l10n.commonDelete, Alignment.centerRight)
          : bg(
              cs.secondaryContainer,
              cs.onSecondaryContainer,
              c.muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
              c.muted ? l10n.chatUnmute : l10n.chatMute,
              Alignment.centerLeft,
            ),
      // Swipe left: archive / unarchive / delete request.
      secondaryBackground: requests
          ? null
          : bg(
              cs.tertiaryContainer,
              cs.onTertiaryContainer,
              archived ? Icons.unarchive_outlined : Icons.archive_outlined,
              archived ? l10n.chatUnarchive : l10n.chatArchive,
              Alignment.centerRight,
            ),
      confirmDismiss: (direction) async {
        // Actions remove the row themselves, so never let it dismiss.
        if (requests) {
          await _act(c, _RowAction.delete);
          return false;
        }
        if (direction == DismissDirection.startToEnd) {
          await _act(c, _RowAction.mute);
          return false;
        }
        await _act(c, _RowAction.archive);
        return false;
      },
      child: row,
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool showRequestActions;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _ConversationTile({
    required this.conversation,
    required this.showRequestActions,
    required this.onTap,
    required this.onLongPress,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final c = conversation;
    final unread = c.unreadCount > 0 && !showRequestActions;
    final preview = lastMessagePreview(l10n, c);
    final online = !c.isGroup && isRecentlyActive(c.otherLastActiveAt);
    final time = c.lastMessage?.createdAt ?? c.lastMessageAt;
    return Semantics(
      button: true,
      hint: unread ? l10n.chatUnreadCount(c.unreadCount) : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            ConversationAvatar(conversation: c, radius: 28, online: online),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      c.displayTitle(c.isGroup ? l10n.chatGroupFallback : l10n.chatSomeone),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(fontWeight: unread ? FontWeight.w800 : FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    chatListTime(l10n, time),
                    style: tt.labelSmall?.copyWith(
                      color: unread ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: unread ? FontWeight.w700 : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Expanded(
                    child: Text(
                      preview.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        color: unread ? cs.onSurface : cs.onSurfaceVariant,
                        fontWeight: unread ? FontWeight.w700 : null,
                        fontStyle: preview.italic ? FontStyle.italic : null,
                      ),
                    ),
                  ),
                  if (c.muted) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.notifications_off_outlined, size: 16, color: cs.onSurfaceVariant),
                  ],
                  if (unread) ...[
                    const SizedBox(width: 6),
                    UnreadBadge(count: c.unreadCount, muted: c.muted),
                  ],
                ]),
              ]),
            ),
            if (showRequestActions) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: l10n.commonDelete,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                onPressed: onDecline,
              ),
              IconButton.filledTonal(
                tooltip: l10n.chatAccept,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.check),
                onPressed: onAccept,
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
