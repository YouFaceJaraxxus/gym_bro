import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../models/chat.dart';
import '../../models/people.dart';
import '../../models/reaction.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/media_upload.dart';
import '../../services/realtime_service.dart';
import '../../widgets/reactions.dart';
import '../../widgets/social_widgets.dart';
import '../people/user_profile_page.dart';
import 'chat_composer.dart';
import 'chat_thread_parts.dart';
import 'chat_widgets.dart';
import 'group_info_page.dart';
import 'message_bubble.dart';
import 'shared_media_page.dart';

/// A message being sent: its files, per-file progress and the storage paths
/// already uploaded (so a retry only re-sends what's missing).
class _Outgoing {
  _Outgoing({required this.clientId, this.body, required this.files, this.replyToId})
    : progress = ValueNotifier(List<double>.filled(files.length, 0));

  final String clientId;
  final String? body;
  final List<PickedMedia> files;
  final String? replyToId;
  final ValueNotifier<List<double>> progress;
  final paths = <int, String>{};
}

enum _MsgAction { reply, copy, edit, unsend, report, retry, discard, moreReactions }

enum _Menu { info, media, mute, archive, clear, deleteChat, block, report, leave }

/// One conversation: live messages, typing, read receipts, attachments,
/// replies, reactions, edits and message requests.
class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({super.key, required this.conversationId, this.initial});

  final String conversationId;

  /// Shown immediately while the detail loads (e.g. from the inbox row).
  final Conversation? initial;
  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> with WidgetsBindingObserver {
  static const _pageSize = 40;

  final _api = ApiService();
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _focus = FocusNode();

  Conversation? _conv;

  /// Newest first (the list is reversed). Local (pending/failed) ones lead.
  final _messages = <ChatMessage>[];
  final _outgoing = <String, _Outgoing>{};
  final _readAt = <String, DateTime>{};
  final _keys = <String, GlobalKey>{};
  final _expanded = <String>{};
  List<PickedMedia> _files = const [];
  ChatMessage? _replyTo;
  ChatMessage? _editing;
  String? _highlightId;

  bool _loading = true;
  String? _error;
  bool _loadingOlder = false;
  bool _hasMore = true;
  bool _showJump = false;

  ChatChannel? _channel;
  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _readTimer;
  Timer? _detailTimer;
  Timer? _poll;
  Timer? _highlightTimer;
  AppLifecycleState _life = AppLifecycleState.resumed;

  String get _id => widget.conversationId;
  String get _me => chatMyId;
  bool get _isGroup => _conv?.isGroup ?? false;
  bool get _isRequest => _conv?.isRequest ?? false;

  @override
  void initState() {
    super.initState();
    _conv = widget.initial;
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _load();
    _join();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readTimer?.cancel();
    _detailTimer?.cancel();
    _poll?.cancel();
    _highlightTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    final ch = _channel;
    _channel = null;
    ch?.dispose();
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _life = state;
    if (state == AppLifecycleState.resumed) {
      _catchUp();
      _scheduleDetail();
      _scheduleRead();
    } else if (state == AppLifecycleState.paused) {
      _channel?.setTyping(false);
    }
  }

  // ── Loading ─────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait<Object>([
        _api.getConversation(token, _id),
        _api.getMessages(token, _id, limit: _pageSize),
      ]);
      final detail = results[0] as Conversation;
      final page = results[1] as List<ChatMessage>;
      if (!mounted) return;
      setState(() {
        _conv = detail;
        _seedReads(detail);
        // Keep local messages and anything that arrived live meanwhile.
        final ids = page.map((m) => m.id).toSet();
        final keep = _messages.where((m) =>
            !ids.contains(m.id) && (m.pending || m.failed || page.isEmpty || m.createdAt.isAfter(page.first.createdAt)));
        final merged = [...page, ...keep];
        _messages
          ..clear()
          ..addAll(merged);
        _sort();
        _hasMore = page.length >= _pageSize;
        _loading = false;
        _error = null;
      });
      _scheduleRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = chatErrorText(e);
      });
    }
  }

  void _retryLoad() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  void _seedReads(Conversation c) {
    for (final m in c.members) {
      final at = m.lastReadAt;
      final old = _readAt[m.person.id];
      if (at != null && (old == null || at.isAfter(old))) _readAt[m.person.id] = at;
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _loading) return;
    String? oldestId;
    for (final m in _messages.reversed) {
      if (!m.pending && !m.failed) {
        oldestId = m.id;
        break;
      }
    }
    if (oldestId == null) return;
    setState(() => _loadingOlder = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final older = await _api.getMessages(token, _id, beforeId: oldestId, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        for (final m in older) {
          _upsert(m);
        }
        _hasMore = older.length >= _pageSize;
        _loadingOlder = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  /// Fetches everything after the newest message I have (after a reconnect,
  /// on resume, or by polling when realtime is unavailable).
  Future<void> _catchUp() async {
    if (!mounted || _loading) return;
    String? lastId;
    for (final m in _messages) {
      if (!m.pending && !m.failed) {
        lastId = m.id;
        break;
      }
    }
    if (lastId == null) {
      await _load();
      return;
    }
    try {
      final token = await AuthManager.instance.getValidToken();
      final fresh = await _api.getMessages(token, _id, afterId: lastId, limit: 100);
      if (!mounted || fresh.isEmpty) return;
      setState(() {
        for (final m in fresh) {
          _upsert(m);
        }
      });
      if (fresh.any((m) => m.senderId != _me)) _scheduleRead();
      if (fresh.any((m) => m.isSystem)) _scheduleDetail();
    } catch (_) {}
  }

  void _scheduleDetail() {
    _detailTimer?.cancel();
    _detailTimer = Timer(const Duration(milliseconds: 300), _reloadDetail);
  }

  Future<void> _reloadDetail() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final c = await _api.getConversation(token, _id);
      if (!mounted) return;
      setState(() {
        _conv = c;
        _seedReads(c);
      });
    } catch (_) {}
  }

  /// Settings responses have no member list; keep the one I have.
  void _applySummary(Conversation c) {
    setState(() => _conv = conversationWithMembers(c, _conv?.members ?? const []));
  }

  // ── Realtime ────────────────────────────────────────────────────────────────

  Future<void> _join() async {
    ChatChannel? ch;
    try {
      ch = await RealtimeService.instance.joinChat(_id);
    } catch (_) {}
    if (!mounted) {
      ch?.dispose();
      return;
    }
    if (ch == null) {
      // No socket: poll instead.
      _poll = Timer.periodic(const Duration(seconds: 10), (_) => _catchUp());
      return;
    }
    setState(() => _channel = ch);
    _subs.addAll([
      ch.messages.listen(_onIncoming),
      ch.updates.listen(_onUpdated),
      ch.reads.listen(_onRead),
      ch.conversationUpdated.listen((_) => _scheduleDetail()),
      ch.resubscribed.listen((_) {
        _catchUp();
        _scheduleDetail();
      }),
    ]);
  }

  void _onIncoming(ChatMessage m) {
    if (!mounted) return;
    setState(() {
      _upsert(m);
      // Sending marks the chat read for the sender.
      final sender = m.senderId;
      if (sender != null && !m.isSystem) {
        final old = _readAt[sender];
        if (old == null || m.createdAt.isAfter(old)) _readAt[sender] = m.createdAt;
      }
    });
    if (m.senderId != _me) _scheduleRead();
    if (m.isSystem) _scheduleDetail();
  }

  void _onUpdated(ChatMessage m) {
    if (!mounted) return;
    final i = _messages.indexWhere((x) => x.id == m.id);
    if (i < 0) return;
    setState(() => _messages[i] = m);
  }

  void _onRead(({String userId, DateTime at}) r) {
    final old = _readAt[r.userId];
    if (old != null && !r.at.isAfter(old)) return;
    if (mounted) setState(() => _readAt[r.userId] = r.at);
  }

  // ── List bookkeeping ────────────────────────────────────────────────────────

  /// Inserts or replaces (matching my optimistic copy by clientId, else by id).
  void _upsert(ChatMessage m) {
    var i = m.clientId == null ? -1 : _messages.indexWhere((x) => x.clientId == m.clientId && x.senderId == m.senderId);
    if (i < 0) i = _messages.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      _messages[i] = m;
    } else {
      _messages.add(m);
    }
    _sort();
  }

  void _sort() {
    _messages.sort((a, b) {
      final la = a.pending || a.failed;
      final lb = b.pending || b.failed;
      if (la != lb) return la ? -1 : 1;
      final c = b.createdAt.compareTo(a.createdAt);
      return c != 0 ? c : b.id.compareTo(a.id);
    });
  }

  void _replaceById(ChatMessage m) {
    final i = _messages.indexWhere((x) => x.id == m.id);
    if (i >= 0) setState(() => _messages[i] = m);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels > p.maxScrollExtent - 600) _loadOlder();
    final jump = p.pixels > 800;
    if (jump != _showJump) setState(() => _showJump = jump);
  }

  void _jumpToLatest() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  /// Scrolls (paging through built items) until the message is on screen,
  /// then flashes it.
  Future<void> _scrollToMessage(String id) async {
    final l10n = context.l10n;
    if (!_messages.any((m) => m.id == id)) {
      showChatSnack(context, l10n.chatOriginalNotFound);
      return;
    }
    for (var attempt = 0; attempt < 40; attempt++) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        if (!mounted) return;
        setState(() => _highlightId = id);
        _highlightTimer?.cancel();
        _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _highlightId = null);
        });
        return;
      }
      if (!_scroll.hasClients) return;
      final p = _scroll.position;
      if (p.pixels >= p.maxScrollExtent) break;
      _scroll.jumpTo(math.min(p.pixels + p.viewportDimension * 0.8, p.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    if (mounted) showChatSnack(context, l10n.chatOriginalNotFound);
  }

  // ── Read receipts ───────────────────────────────────────────────────────────

  void _scheduleRead() {
    if (_conv == null || _isRequest) return;
    _readTimer?.cancel();
    _readTimer = Timer(const Duration(milliseconds: 400), _markRead);
  }

  Future<void> _markRead() async {
    if (!mounted || _life != AppLifecycleState.resumed) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.markChatRead(token, _id);
    } catch (_) {}
  }

  // ── Sending ─────────────────────────────────────────────────────────────────

  void _onTextChanged(String text) {
    if (_editing != null) return;
    _channel?.setTyping(text.trim().isNotEmpty);
  }

  Future<void> _send() async {
    if (_editing != null) return _saveEdit();
    final text = _input.text.trim();
    if (text.isEmpty && _files.isEmpty) return;
    final clientId = newChatClientId();
    final reply = _replyTo;
    final out = _Outgoing(clientId: clientId, body: text.isEmpty ? null : text, files: List.of(_files), replyToId: reply?.id);
    _outgoing[clientId] = out;
    final optimistic = ChatMessage(
      id: 'local-$clientId',
      conversationId: _id,
      senderId: _me,
      sender: chatMe(),
      kind: out.files.isEmpty ? 'text' : 'media',
      body: out.body,
      replyTo: reply == null
          ? null
          : ReplyPreview(
              id: reply.id,
              senderId: reply.senderId,
              senderName: reply.sender?.name,
              body: reply.body,
              mediaType: reply.attachments.isEmpty ? null : reply.attachments.first.type,
              deleted: reply.isDeleted,
            ),
      clientId: clientId,
      createdAt: DateTime.now(),
      pending: true,
    );
    setState(() {
      _messages.add(optimistic);
      _sort();
      _files = const [];
      _replyTo = null;
    });
    _input.clear();
    _channel?.setTyping(false);
    _jumpToLatest();
    await _deliver(out);
  }

  Future<void> _deliver(_Outgoing out) async {
    try {
      var token = await AuthManager.instance.getValidToken();
      final attachments = <OutgoingAttachment>[];
      for (var i = 0; i < out.files.length; i++) {
        final f = out.files[i];
        var path = out.paths[i];
        if (path == null) {
          final slot = await _api.requestChatUpload(token, _id, mimeType: f.mimeType, sizeBytes: f.sizeBytes, fileName: f.fileName);
          await uploadFileToSlot(slot, f, onProgress: (p) {
            final next = List<double>.of(out.progress.value);
            if (i < next.length) next[i] = p;
            out.progress.value = next;
          });
          path = slot.path;
          out.paths[i] = path;
        }
        attachments.add(f.attachment(path));
      }
      // Uploads can take a while; make sure the token is still fresh.
      if (out.files.isNotEmpty) token = await AuthManager.instance.getValidToken();
      final sent = await _api.sendMessage(
        token,
        _id,
        body: out.body,
        attachments: attachments,
        replyToId: out.replyToId,
        clientId: out.clientId,
      );
      _outgoing.remove(out.clientId);
      if (!mounted) return;
      setState(() => _upsert(sent));
    } catch (e) {
      if (!mounted) return;
      final i = _messages.indexWhere((m) => m.clientId == out.clientId && m.pending);
      if (i >= 0) setState(() => _messages[i] = _messages[i].copyWith(pending: false, failed: true));
    }
  }

  void _retry(ChatMessage m) {
    final out = _outgoing[m.clientId];
    final i = _messages.indexWhere((x) => x.id == m.id);
    if (out == null || i < 0) return;
    setState(() => _messages[i] = _messages[i].copyWith(pending: true, failed: false));
    _deliver(out);
  }

  void _discard(ChatMessage m) {
    setState(() {
      _messages.removeWhere((x) => x.id == m.id);
      _outgoing.remove(m.clientId);
    });
  }

  void _startReply(ChatMessage m) {
    setState(() {
      _replyTo = m;
      if (_editing != null) {
        _editing = null;
        _input.clear();
      }
    });
    _focus.requestFocus();
  }

  void _startEdit(ChatMessage m) {
    setState(() {
      _editing = m;
      _replyTo = null;
    });
    _input.text = m.body ?? '';
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _focus.requestFocus();
  }

  void _cancelContext() {
    if (_editing != null) _input.clear();
    setState(() {
      _editing = null;
      _replyTo = null;
    });
  }

  Future<void> _saveEdit() async {
    final m = _editing;
    if (m == null) return;
    final text = _input.text.trim();
    if (text.isEmpty || text == m.body) {
      _cancelContext();
      return;
    }
    try {
      final token = await AuthManager.instance.getValidToken();
      final updated = await _api.editMessage(token, m.id, text);
      if (!mounted) return;
      _replaceById(updated);
      setState(() => _editing = null);
      _input.clear();
    } catch (e) {
      if (mounted) showChatSnack(context, chatErrorText(e));
    }
  }

  // ── Message actions ─────────────────────────────────────────────────────────

  Future<void> _react(ChatMessage m, ReactionType? reaction) async {
    final i = _messages.indexWhere((x) => x.id == m.id);
    if (i < 0) return;
    final before = _messages[i];
    if (before.pending || before.failed || before.isDeleted) return;
    HapticFeedback.lightImpact();
    setState(() => _messages[i] = before.copyWith(reactions: [
      ...before.reactions.where((r) => r.userId != _me),
      if (reaction != null) MessageReaction(userId: _me, reaction: reaction),
    ]));
    try {
      final token = await AuthManager.instance.getValidToken();
      final updated = await _api.reactToMessage(token, m.id, reaction);
      if (!mounted) return;
      _replaceById(updated);
    } catch (e) {
      if (!mounted) return;
      _replaceById(before);
      showChatSnack(context, chatErrorText(e));
    }
  }

  void _toggleLove(ChatMessage m) =>
      _react(m, m.reactionOf(_me) == ReactionType.love ? null : ReactionType.love);

  Future<void> _showActions(ChatMessage m, BuildContext anchor) async {
    if (m.isSystem || m.isDeleted || m.pending) return;
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final mine = m.senderId == _me;
    final hasText = m.body?.isNotEmpty ?? false;
    final canModerate = _isGroup && (_conv?.myRole.isAdmin ?? false);
    final current = m.reactionOf(_me);
    HapticFeedback.mediumImpact();
    final result = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (m.failed) ...[
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(l10n.socialRetry),
                onTap: () => Navigator.pop(ctx, _MsgAction.retry),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text(l10n.commonDelete, style: TextStyle(color: cs.error)),
                onTap: () => Navigator.pop(ctx, _MsgAction.discard),
              ),
            ] else ...[
              if (!_isRequest) ...[
                QuickReactionsRow(
                  current: current,
                  onPick: (r) => Navigator.pop(ctx, r),
                  onMore: () => Navigator.pop(ctx, _MsgAction.moreReactions),
                ),
                const Divider(height: 16),
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: Text(l10n.chatReply),
                  onTap: () => Navigator.pop(ctx, _MsgAction.reply),
                ),
              ],
              if (hasText)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: Text(l10n.chatCopy),
                  onTap: () => Navigator.pop(ctx, _MsgAction.copy),
                ),
              if (mine && hasText)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.commonEdit),
                  onTap: () => Navigator.pop(ctx, _MsgAction.edit),
                ),
              if (mine || canModerate)
                ListTile(
                  leading: Icon(Icons.undo_rounded, color: cs.error),
                  title: Text(mine ? l10n.chatUnsend : l10n.chatRemoveMessage, style: TextStyle(color: cs.error)),
                  onTap: () => Navigator.pop(ctx, _MsgAction.unsend),
                ),
              if (!mine)
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(l10n.chatReport),
                  onTap: () => Navigator.pop(ctx, _MsgAction.report),
                ),
            ],
          ]),
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result is ReactionType) {
      _react(m, result == current ? null : result);
      return;
    }
    switch (result as _MsgAction) {
      case _MsgAction.reply:
        _startReply(m);
      case _MsgAction.copy:
        await Clipboard.setData(ClipboardData(text: m.body ?? ''));
        if (mounted) showChatSnack(context, l10n.chatCopied);
      case _MsgAction.edit:
        _startEdit(m);
      case _MsgAction.unsend:
        await _unsend(m);
      case _MsgAction.report:
        await _reportMessage(m);
      case _MsgAction.retry:
        _retry(m);
      case _MsgAction.discard:
        _discard(m);
      case _MsgAction.moreReactions:
        if (!anchor.mounted) return;
        final picked = await showReactionPicker(context, anchor: anchor, current: current);
        if (picked != null && mounted) _react(m, picked == current ? null : picked);
    }
  }

  Future<void> _unsend(ChatMessage m) async {
    final l10n = context.l10n;
    final ok = await confirmChatAction(
      context,
      title: l10n.chatUnsendConfirmTitle,
      body: l10n.chatUnsendConfirmBody,
      confirm: m.senderId == _me ? l10n.chatUnsend : l10n.chatRemoveMessage,
    );
    if (!ok || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      final updated = await _api.unsendMessage(token, m.id);
      if (!mounted) return;
      _replaceById(updated);
      if (_replyTo?.id == m.id) setState(() => _replyTo = null);
    } catch (e) {
      if (mounted) showChatSnack(context, chatErrorText(e));
    }
  }

  Future<void> _reportMessage(ChatMessage m) async {
    final l10n = context.l10n;
    final reason = await pickReportReason(context);
    if (reason == null || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.report(token, messageId: m.id, reason: reason);
      if (mounted) showChatSnack(context, l10n.chatReportSent);
    } catch (e) {
      if (mounted) showChatSnack(context, chatErrorText(e));
    }
  }

  void _showReactors(ChatMessage m) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
          child: ListView(shrinkWrap: true, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(l10n.chatReactions, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final r in m.reactions)
              Builder(builder: (_) {
                final p = _person(r.userId);
                final isMe = r.userId == _me;
                return ListTile(
                  leading: UserAvatar(url: p?.avatarUrl, initials: p?.initials ?? '?'),
                  title: Text(isMe ? l10n.chatYou : (p?.fullName ?? l10n.chatSomeone)),
                  subtitle: isMe ? Text(l10n.chatTapToRemove) : null,
                  trailing: Text(r.reaction.emoji, style: const TextStyle(fontSize: 24)),
                  onTap: isMe
                      ? () {
                          Navigator.pop(ctx);
                          _react(m, null);
                        }
                      : null,
                );
              }),
          ]),
        ),
      ),
    );
  }

  // ── People and navigation ───────────────────────────────────────────────────

  PersonSummary? _person(String? id) {
    if (id == null) return null;
    final c = _conv;
    if (c != null) {
      for (final mem in c.members) {
        if (mem.person.id == id) return mem.person;
      }
      for (final p in c.participants) {
        if (p.id == id) return p;
      }
      if (c.otherUser?.id == id) return c.otherUser;
    }
    if (id == _me) return chatMe();
    for (final m in _messages) {
      if (m.senderId == id && m.sender != null) return m.sender;
    }
    return null;
  }

  String _firstName(String id) => _person(id)?.name ?? context.l10n.chatSomeone;

  PersonSummary? get _other {
    final c = _conv;
    if (c == null || c.isGroup) return null;
    if (c.otherUser != null) return c.otherUser;
    for (final m in c.members) {
      if (m.person.id != _me) return m.person;
    }
    return null;
  }

  DateTime? get _otherLastActive {
    final c = _conv;
    final other = _other;
    if (c == null || other == null) return null;
    for (final m in c.members) {
      if (m.person.id == other.id && m.lastActiveAt != null) return m.lastActiveAt;
    }
    return c.otherLastActiveAt;
  }

  Future<void> _openProfile(String? userId) async {
    if (userId == null) return;
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: userId)));
    if (mounted) _scheduleRead();
  }

  Future<void> _openInfo() async {
    final c = _conv;
    if (c == null) return;
    if (!c.isGroup) return _openProfile(_other?.id);
    final gone = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GroupInfoPage(conversationId: _id)),
    );
    if (!mounted) return;
    if (gone == true) {
      Navigator.pop(context);
      return;
    }
    _scheduleDetail();
    _scheduleRead();
  }

  Future<void> _onMenu(_Menu action) async {
    final c = _conv;
    if (c == null) return;
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    try {
      final token = await AuthManager.instance.getValidToken();
      if (!mounted) return;
      switch (action) {
        case _Menu.info:
          await _openInfo();
        case _Menu.media:
          await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => SharedMediaPage(conversationId: _id)));
        case _Menu.mute:
          final updated = await _api.updateChatSettings(token, _id, muted: !c.muted);
          if (!mounted) return;
          _applySummary(updated);
          showChatSnack(context, updated.muted ? l10n.chatMutedSnack : l10n.chatUnmutedSnack);
        case _Menu.archive:
          final updated = await _api.updateChatSettings(token, _id, archived: !c.archived);
          if (!mounted) return;
          _applySummary(updated);
          showChatSnack(context, updated.archived ? l10n.chatArchivedSnack : l10n.chatUnarchivedSnack);
        case _Menu.clear:
          if (!await confirmChatAction(context, body: l10n.chatClearChatConfirm, confirm: l10n.chatClearChat)) return;
          await _api.clearChat(token, _id);
          if (!mounted) return;
          setState(() {
            _messages.removeWhere((m) => !m.pending && !m.failed);
            _hasMore = false;
          });
          showChatSnack(context, l10n.chatCleared);
        case _Menu.deleteChat:
          if (!await confirmChatAction(context, body: l10n.chatDeleteChatConfirm, confirm: l10n.commonDelete)) return;
          await _api.removeFromChat(token, _id, _me);
          nav.pop();
        case _Menu.leave:
          final title = c.displayTitle(l10n.chatGroupFallback);
          if (!await confirmChatAction(context, body: l10n.chatLeaveGroupConfirm(title), confirm: l10n.chatLeaveGroup)) return;
          await _api.removeFromChat(token, _id, _me);
          nav.pop();
        case _Menu.block:
          await _block(token);
        case _Menu.report:
          final other = _other;
          if (other == null) return;
          final reason = await pickReportReason(context);
          if (reason == null) return;
          await _api.report(token, userId: other.id, reason: reason);
          if (mounted) showChatSnack(context, l10n.chatReportSent);
      }
    } catch (e) {
      if (mounted) showChatSnack(context, chatErrorText(e));
    }
  }

  /// Blocks the other person (direct chats) and leaves the chat.
  Future<void> _block(String token, {bool alsoDecline = false}) async {
    final other = _other;
    if (other == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final ok = await confirmChatAction(
      context,
      title: l10n.chatBlockConfirmTitle(other.fullName),
      body: l10n.chatBlockConfirmBody,
      confirm: l10n.chatBlock,
    );
    if (!ok) return;
    await _api.block(token, other.id);
    if (alsoDecline) {
      try {
        await _api.removeFromChat(token, _id, _me);
      } catch (_) {}
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.chatBlockedSnack(other.fullName))));
    nav.pop();
  }

  // ── Message requests ────────────────────────────────────────────────────────

  Future<void> _acceptRequest() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final c = await _api.acceptMessageRequest(token, _id);
      if (!mounted) return;
      setState(() {
        _conv = c;
        _seedReads(c);
      });
      _scheduleRead();
    } catch (e) {
      if (mounted) showChatSnack(context, chatErrorText(e));
    }
  }

  Future<void> _declineRequest() async {
    final nav = Navigator.of(context);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.removeFromChat(token, _id, _me);
      nav.pop();
    } catch (e) {
      if (mounted) showChatSnack(context, chatErrorText(e));
    }
  }

  Future<void> _blockFromRequest() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      if (!mounted) return;
      await _block(token, alsoDecline: true);
    } catch (e) {
      if (mounted) showChatSnack(context, chatErrorText(e));
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = _conv;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ThreadAppBarTitle(
          conversation: c,
          channel: _channel,
          other: _other,
          otherLastActive: _otherLastActive,
          onTap: c == null ? null : _openInfo,
        ),
        actions: [
          if (c != null)
            PopupMenuButton<_Menu>(
              tooltip: context.l10n.chatMoreOptions,
              onSelected: _onMenu,
              itemBuilder: (_) => _menuItems(c),
            ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: _buildList()),
            Positioned(
              right: 12,
              bottom: 12,
              child: AnimatedScale(
                scale: _showJump ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: context.l10n.chatJumpToLatest,
                  onPressed: _jumpToLatest,
                  child: const Icon(Icons.arrow_downward_rounded),
                ),
              ),
            ),
          ]),
        ),
        if (c != null && c.isRequest)
          MessageRequestBanner(
            conversation: c,
            onAccept: _acceptRequest,
            onDelete: _declineRequest,
            onBlock: c.isGroup ? null : _blockFromRequest,
          )
        else if (c != null)
          ChatComposer(
            controller: _input,
            focusNode: _focus,
            files: _files,
            onFilesChanged: (f) => setState(() => _files = f),
            onChanged: _onTextChanged,
            onSend: _send,
            editing: _editing != null,
            contextBar: _contextBar(),
          ),
      ]),
    );
  }

  List<PopupMenuEntry<_Menu>> _menuItems(Conversation c) {
    final l10n = context.l10n;
    PopupMenuItem<_Menu> item(_Menu v, IconData icon, String text, {bool danger = false}) {
      final color = danger ? Theme.of(context).colorScheme.error : null;
      return PopupMenuItem(
        value: v,
        child: Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Flexible(child: Text(text, style: TextStyle(color: color))),
        ]),
      );
    }

    return [
      item(_Menu.info, c.isGroup ? Icons.info_outline : Icons.person_outline, c.isGroup ? l10n.chatGroupInfo : l10n.chatViewProfile),
      if (!c.isGroup) item(_Menu.media, Icons.perm_media_outlined, l10n.chatSharedMedia),
      if (!c.isRequest) ...[
        item(_Menu.mute, c.muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
            c.muted ? l10n.chatUnmute : l10n.chatMute),
        item(_Menu.archive, c.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            c.archived ? l10n.chatUnarchive : l10n.chatArchive),
        item(_Menu.clear, Icons.cleaning_services_outlined, l10n.chatClearChat),
      ],
      if (c.isGroup)
        item(_Menu.leave, Icons.logout, l10n.chatLeaveGroup, danger: true)
      else ...[
        item(_Menu.deleteChat, Icons.delete_outline, l10n.chatDeleteChat, danger: true),
        item(_Menu.block, Icons.block, l10n.chatBlock, danger: true),
        item(_Menu.report, Icons.flag_outlined, l10n.chatReport, danger: true),
      ],
    ];
  }

  Widget? _contextBar() {
    final l10n = context.l10n;
    final editing = _editing;
    if (editing != null) {
      return ComposerContextBar(
        icon: Icons.edit_outlined,
        title: l10n.chatEditingMessage,
        preview: editing.body,
        onClose: _cancelContext,
      );
    }
    final r = _replyTo;
    if (r == null) return null;
    final title = r.senderId == _me
        ? l10n.chatReplyingToYourself
        : l10n.chatReplyingTo(r.sender?.name ?? _firstName(r.senderId ?? ''));
    final preview = (r.body?.isNotEmpty ?? false)
        ? r.body
        : r.attachments.isNotEmpty
            ? chatMediaLabel(l10n, r.attachments.first.type)
            : null;
    return ComposerContextBar(icon: Icons.reply_rounded, title: title, preview: preview, onClose: _cancelContext);
  }

  Widget _buildList() {
    if (_loading && _messages.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _messages.isEmpty) return ChatErrorState(message: _error!, onRetry: _retryLoad);

    // Rows (newest first): message indexes, day separators (DateTime) and,
    // once all history is loaded, the conversation header (null).
    final rows = <Object?>[];
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      rows.add(i);
      final older = i + 1 < _messages.length ? _messages[i + 1] : null;
      if (older == null ? !_hasMore : !DateUtils.isSameDay(older.createdAt, m.createdAt)) {
        rows.add(DateUtils.dateOnly(m.createdAt));
      }
    }
    if (!_hasMore) rows.add(null);

    // "Seen" goes under my latest message when nobody has written since.
    String? receiptId;
    for (final m in _messages) {
      if (m.isSystem) continue;
      if (m.senderId == _me && !m.pending && !m.failed && !m.isDeleted) receiptId = m.id;
      break;
    }

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: rows.length + 1 + (_loadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) return _typingRow();
        final r = index - 1;
        if (r >= rows.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final row = rows[r];
        if (row == null) return _header();
        if (row is DateTime) return DaySeparator(day: row);
        return _messageRow(row as int, receiptId);
      },
    );
  }

  bool _joins(ChatMessage older, ChatMessage newer) =>
      !older.isSystem &&
      !newer.isSystem &&
      !older.isDeleted &&
      !newer.isDeleted &&
      older.senderId == newer.senderId &&
      DateUtils.isSameDay(older.createdAt, newer.createdAt) &&
      newer.createdAt.difference(older.createdAt).abs() < const Duration(minutes: 3);

  Widget _messageRow(int i, String? receiptId) {
    final l10n = context.l10n;
    final m = _messages[i];
    if (m.isSystem) {
      return KeyedSubtree(
        key: _keyFor(m.id),
        child: SystemMessageLine(
          text: systemEventText(l10n, metadata: m.metadata, actorId: m.senderId, nameOf: _firstName),
        ),
      );
    }
    final older = i + 1 < _messages.length ? _messages[i + 1] : null;
    final newer = i > 0 ? _messages[i - 1] : null;
    final mine = m.senderId == _me;
    final out = _outgoing[m.clientId];
    final local = m.pending || m.failed;
    return MessageBubble(
      key: _keyFor(m.id),
      message: m,
      mine: mine,
      isGroup: _isGroup,
      clusterTop: older == null || !_joins(older, m),
      clusterBottom: newer == null || !_joins(m, newer),
      showTime: _expanded.contains(m.id),
      highlighted: _highlightId == m.id,
      outgoing: local && out != null ? OutgoingFiles(out.files, out.progress) : null,
      status: _statusFor(m, receiptId),
      onTap: () {
        if (m.failed) {
          _retry(m);
          return;
        }
        setState(() {
          if (!_expanded.remove(m.id)) _expanded.add(m.id);
        });
      },
      onDoubleTap: local || m.isDeleted || _isRequest ? null : () => _toggleLove(m),
      onLongPress: (anchor) => _showActions(m, anchor),
      onReply: _isRequest ? null : () => _startReply(m),
      onQuoteTap: m.replyTo == null ? null : () => _scrollToMessage(m.replyTo!.id),
      onReactionsTap: () => _showReactors(m),
      onAvatarTap: mine ? null : () => _openProfile(m.senderId),
    );
  }

  Widget? _statusFor(ChatMessage m, String? receiptId) {
    final l10n = context.l10n;
    if (m.senderId != _me) return null;
    if (m.failed) return ReceiptLine(text: l10n.chatFailed, error: true, onTap: () => _retry(m));
    if (m.pending) return ReceiptLine(text: l10n.chatSending);
    if (m.id != receiptId) return null;
    final c = _conv;
    if (c == null) return null;
    final readers = <PersonSummary>[];
    for (final mem in c.members) {
      if (mem.person.id == _me || mem.status != 'active') continue;
      final at = _readAt[mem.person.id];
      if (at != null && !at.isBefore(m.createdAt)) readers.add(mem.person);
    }
    if (!c.isGroup || readers.isEmpty) return ReceiptLine(text: readers.isNotEmpty ? l10n.chatSeen : l10n.chatSent);
    return ReceiptLine(seenBy: readers);
  }

  Widget _typingRow() {
    final ch = _channel;
    if (ch == null) return const SizedBox.shrink();
    return ValueListenableBuilder<List<TypingUser>>(
      valueListenable: ch.typing,
      builder: (context, typing, _) {
        final first = typing.isEmpty ? null : _person(typing.first.userId);
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.bottomLeft,
          child: typing.isEmpty
              ? const SizedBox(width: double.infinity)
              : Semantics(
                  liveRegion: true,
                  label: typing.length == 1 ? context.l10n.socialTyping(typing.first.name) : context.l10n.socialTypingSeveral,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      SizedBox(
                        width: 28,
                        child: UserAvatar(
                          url: first?.avatarUrl,
                          initials: first?.initials ?? (typing.first.name.isEmpty ? '?' : typing.first.name[0].toUpperCase()),
                          radius: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const TypingBubble(),
                      if (typing.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 4),
                          child: Text('+${typing.length - 1}', style: Theme.of(context).textTheme.labelSmall),
                        ),
                    ]),
                  ),
                ),
        );
      },
    );
  }

  /// Big avatar and name at the very top of the history.
  Widget _header() {
    final c = _conv;
    if (c == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = c.displayTitle(c.isGroup ? l10n.chatGroupFallback : l10n.chatSomeone);
    final other = _other;
    final subtitle = c.isGroup
        ? l10n.chatMembersCount(c.members.isNotEmpty ? c.members.where((m) => m.status == 'active').length : c.participantCount)
        : (other != null && other.username.isNotEmpty ? '@${other.username}' : null);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(children: [
        GestureDetector(onTap: _openInfo, child: ConversationAvatar(conversation: c, radius: 40)),
        const SizedBox(height: 12),
        Text(title, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
        if (_messages.isEmpty) ...[
          const SizedBox(height: 16),
          Text(
            c.isGroup ? l10n.chatSayHiGroup : l10n.chatSayHi(other?.name ?? title),
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ]),
    );
  }
}
