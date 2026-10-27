import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:realtime_client/realtime_client.dart';

import '../config.dart';
import '../models/chat.dart';
import 'api_service.dart';
import 'auth_manager.dart';

/// An event on my `user:<id>` topic: `inbox` (a message in any of my chats,
/// or a read), `conversation_added`, `conversation_removed`, `notification`,
/// `relationship`.
class UserEvent {
  final String event;
  final Map<String, dynamic> payload;
  const UserEvent(this.event, this.payload);
}

/// Live updates over Supabase Realtime private channels (authorized by RLS on
/// the server, see migration 000014):
///
/// * `user:<my id>`     — [userEvents], one subscription while signed in.
/// * `chat:<id>`        — server events for an open conversation ([ChatChannel]).
/// * `chat-live:<id>`   — typing and presence between participants.
///
/// The socket authenticates with the user's access token, refreshed before
/// it expires. Everything is best effort: the app works (by polling/refresh)
/// when the socket is down.
class RealtimeService {
  RealtimeService._();
  static final instance = RealtimeService._();

  final _api = ApiService();
  RealtimeClient? _client;
  String? _userId;
  Timer? _authTimer;
  Future<void>? _connecting;

  final _userEvents = StreamController<UserEvent>.broadcast();

  /// The conversation open on screen (no foreground push banners for it).
  String? activeConversationId;

  /// Events on my user topic (inbox, notifications, relationships).
  Stream<UserEvent> get userEvents => _userEvents.stream;

  final _connected = ValueNotifier<bool>(false);

  /// Whether the inbox channel is subscribed (for "connecting…" hints).
  ValueListenable<bool> get connected => _connected;

  /// Connects (idempotent). Call after sign-in; [disconnect] on sign-out.
  Future<void> connect() {
    final me = AuthManager.instance.profile?.id;
    if (me == null || !AuthManager.instance.hasSession) return Future.value();
    if (_client != null && _userId == me) return Future.value();
    return _connecting ??= _connect(me).whenComplete(() => _connecting = null);
  }

  Future<void> _connect(String me) async {
    await disconnect();
    try {
      final token = await AuthManager.instance.getValidToken();
      final anonKey = await _api.getRealtimeAnonKey(token);
      final client = RealtimeClient(
        AppConfig.realtimeUrl,
        params: {'apikey': anonKey},
        // The legacy JSON protocol is supported by every Realtime version.
        version: RealtimeProtocolVersion.v1,
      );
      await client.setAuth(token);
      _client = client;
      _userId = me;

      // Hand the socket a fresh token before the current one expires.
      _authTimer = Timer.periodic(const Duration(minutes: 4), (_) async {
        try {
          await _client?.setAuth(await AuthManager.instance.getValidToken());
        } catch (_) {}
      });

      final channel = client.channel('user:$me', const RealtimeChannelConfig(private: true));
      for (final event in const ['inbox', 'conversation_added', 'conversation_removed', 'notification', 'relationship']) {
        channel.onBroadcast(event: event, callback: (p) => _userEvents.add(UserEvent(event, _payloadOf(p))));
      }
      channel.subscribe((status, _) => _connected.value = status == RealtimeSubscribeStatus.subscribed);
    } catch (e) {
      debugPrint('Realtime connect failed: $e');
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    _authTimer?.cancel();
    _authTimer = null;
    final client = _client;
    _client = null;
    _userId = null;
    _connected.value = false;
    if (client != null) {
      try {
        await client.removeAllChannels();
        await client.disconnect();
      } catch (_) {}
    }
  }

  /// Joins a conversation's channels. Dispose the result when the chat closes.
  Future<ChatChannel?> joinChat(String conversationId) async {
    await connect();
    final client = _client;
    final me = _userId;
    if (client == null || me == null) return null;
    activeConversationId = conversationId;
    return ChatChannel._(client, conversationId, me, AuthManager.instance.profile?.name ?? '');
  }
}

/// Broadcast callbacks get `{event, payload, type}`; return the payload.
Map<String, dynamic> _payloadOf(Map<String, dynamic> raw) {
  final inner = raw['payload'];
  return inner is Map ? Map<String, dynamic>.from(inner) : raw;
}

/// Someone currently typing (expires unless refreshed).
class TypingUser {
  final String userId;
  final String name;
  final DateTime until;
  const TypingUser(this.userId, this.name, this.until);
}

/// One open conversation: server events plus typing and presence.
class ChatChannel {
  ChatChannel._(this._client, this.conversationId, this._me, this._myName) {
    _server = _client.channel('chat:$conversationId', const RealtimeChannelConfig(private: true));
    _server
      ..onBroadcast(event: 'message', callback: (p) => _emit(_messages, p))
      ..onBroadcast(event: 'message_updated', callback: (p) => _emit(_updates, p))
      ..onBroadcast(event: 'read', callback: (p) {
        final data = _payloadOf(p);
        final at = DateTime.tryParse(data['last_read_at'] as String? ?? '');
        if (at != null && !_reads.isClosed) _reads.add((userId: data['user_id'] as String, at: at.toLocal()));
      })
      ..onBroadcast(event: 'conversation_updated', callback: (_) {
        if (!_conversationUpdated.isClosed) _conversationUpdated.add(null);
      })
      ..subscribe((status, _) {
        // A re-subscribe after a drop means events may have been missed.
        if (status == RealtimeSubscribeStatus.subscribed) {
          if (_subscribedOnce && !_resubscribed.isClosed) _resubscribed.add(null);
          _subscribedOnce = true;
        }
      });

    _live = _client.channel(
      'chat-live:$conversationId',
      RealtimeChannelConfig(private: true, key: _me, enabled: true),
    );
    _live
      ..onBroadcast(event: 'typing', callback: (p) {
        final data = _payloadOf(p);
        final userId = data['user_id'] as String?;
        if (userId == null || userId == _me) return;
        if (data['typing'] == true) {
          _typing[userId] = TypingUser(userId, data['name'] as String? ?? '', DateTime.now().add(const Duration(seconds: 5)));
        } else {
          _typing.remove(userId);
        }
        _publishTyping();
      })
      ..onPresenceSync((_) => _publishPresence())
      ..onPresenceJoin((_) => _publishPresence())
      ..onPresenceLeave((_) => _publishPresence())
      ..subscribe((status, _) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          try {
            await _live.track({'user_id': _me, 'online_at': DateTime.now().toUtc().toIso8601String()});
          } catch (_) {}
        }
      });

    // Drop typing users whose last "typing" is stale (e.g. they lost signal).
    _sweep = Timer.periodic(const Duration(seconds: 1), (_) {
      final before = _typing.length;
      _typing.removeWhere((_, t) => t.until.isBefore(DateTime.now()));
      if (_typing.length != before) _publishTyping();
    });
  }

  final RealtimeClient _client;
  final String conversationId;
  final String _me;
  final String _myName;
  late final RealtimeChannel _server;
  late final RealtimeChannel _live;
  late final Timer _sweep;
  bool _subscribedOnce = false;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _typingSent = false;

  final _messages = StreamController<ChatMessage>.broadcast();
  final _updates = StreamController<ChatMessage>.broadcast();
  final _reads = StreamController<({String userId, DateTime at})>.broadcast();
  final _conversationUpdated = StreamController<void>.broadcast();
  final _resubscribed = StreamController<void>.broadcast();
  final _typing = <String, TypingUser>{};

  /// Who's typing right now (never includes me).
  final typing = ValueNotifier<List<TypingUser>>(const []);

  /// User ids with the chat open right now (includes me).
  final online = ValueNotifier<Set<String>>(const {});

  /// New messages (including my own, echoed — match them by clientId).
  Stream<ChatMessage> get messages => _messages.stream;

  /// Edits, unsends and reaction changes.
  Stream<ChatMessage> get updates => _updates.stream;

  /// Read receipts.
  Stream<({String userId, DateTime at})> get reads => _reads.stream;

  /// Title/members changed: reload the conversation detail.
  Stream<void> get conversationUpdated => _conversationUpdated.stream;

  /// The channel came back after a drop: fetch messages after the last one.
  Stream<void> get resubscribed => _resubscribed.stream;

  void _emit(StreamController<ChatMessage> sink, Map<String, dynamic> raw) {
    if (sink.isClosed) return;
    try {
      sink.add(ChatMessage.fromJson(_payloadOf(raw)));
    } catch (e) {
      debugPrint('Bad chat event: $e');
    }
  }

  void _publishTyping() => typing.value = _typing.values.toList();

  void _publishPresence() {
    final ids = <String>{};
    for (final state in _live.presenceState()) {
      for (final p in state.presences) {
        final id = p.payload['user_id'];
        if (id is String) ids.add(id);
      }
    }
    online.value = ids;
  }

  /// Call on every keystroke; sends at most one "typing" every 2 s, and
  /// "stopped" when [isTyping] turns false.
  void setTyping(bool isTyping) {
    final now = DateTime.now();
    if (isTyping) {
      if (_typingSent && now.difference(_lastTypingSent) < const Duration(seconds: 2)) return;
      _lastTypingSent = now;
      _typingSent = true;
    } else {
      if (!_typingSent) return;
      _typingSent = false;
    }
    unawaited(_live
        .sendBroadcastMessage(event: 'typing', payload: {'user_id': _me, 'name': _myName, 'typing': isTyping})
        .catchError((_) => ChannelResponse.error));
  }

  Future<void> dispose() async {
    setTyping(false);
    if (RealtimeService.instance.activeConversationId == conversationId) {
      RealtimeService.instance.activeConversationId = null;
    }
    _sweep.cancel();
    typing.dispose();
    online.dispose();
    await _messages.close();
    await _updates.close();
    await _reads.close();
    await _conversationUpdated.close();
    await _resubscribed.close();
    try {
      await _live.untrack();
    } catch (_) {}
    await _client.removeChannel(_server);
    await _client.removeChannel(_live);
  }
}
