import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'caching_client.dart' show isNetworkError;

/// Thrown by API methods that opted into the outbox when the device is
/// offline: the write was saved locally and will be sent automatically once
/// the connection returns. Screens should treat it as a soft success
/// ("Saved offline, will sync").
class QueuedOfflineException implements Exception {
  const QueuedOfflineException([this.message = "Saved offline, will sync when you're back online"]);

  final String message;

  @override
  String toString() => message;
}

/// One queued write. The Authorization header is never stored: a fresh token
/// is attached at replay time.
class OutboxEntry {
  OutboxEntry({
    required this.id,
    required this.method,
    required this.url,
    this.headers = const {},
    this.body,
    required this.createdAt,
    this.attempts = 0,
  });

  final String id;
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String? body;
  final DateTime createdAt;
  int attempts;

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'url': url.toString(),
        'headers': headers,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'attempts': attempts,
      };

  factory OutboxEntry.fromJson(Map<String, dynamic> json) => OutboxEntry(
        id: json['id'] as String,
        method: json['method'] as String,
        url: Uri.parse(json['url'] as String),
        headers: (json['headers'] as Map? ?? const {}).cast<String, String>(),
        body: json['body'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        attempts: json['attempts'] as int? ?? 0,
      );
}

/// Outcome of one [Outbox.replay] run.
class ReplayResult {
  const ReplayResult({this.sent = 0, this.dropped = 0, this.remaining = 0, this.stoppedBy});

  final int sent;

  /// Entries the server permanently rejected (4xx other than 401/408/429).
  final int dropped;
  final int remaining;

  /// Why replay stopped early (network error, auth, server error), if it did.
  final String? stoppedBy;
}

/// A persistent FIFO of write requests made while offline.
///
/// Requests are stored in shared_preferences as JSON and replayed strictly in
/// order. Replay stops at the first entry that can't be delivered right now
/// (network error, 401, 408, 429, 5xx) so later writes never overtake earlier
/// ones; entries the server permanently rejects (other 4xx) are dropped.
///
/// Generic: any API method can opt in by enqueueing its request when it fails
/// with a network error (see `ApiService._sendOrQueue`).
class Outbox {
  Outbox({
    required Future<String?> Function() tokenProvider,
    http.Client? client,
    this.storageKey = 'gymbro.outbox.v1',
  })  : _tokenProvider = tokenProvider,
        _client = client ?? http.Client();

  final Future<String?> Function() _tokenProvider;
  final http.Client _client;
  final String storageKey;

  /// Number of writes waiting to be sent.
  final ValueNotifier<int> pending = ValueNotifier(0);

  /// Message of the last entry the server rejected during replay, if any.
  final ValueNotifier<String?> lastRejection = ValueNotifier(null);

  List<OutboxEntry>? _entries;
  Future<ReplayResult>? _replaying;
  int _seq = 0;

  Future<List<OutboxEntry>> _load() async {
    final cached = _entries;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    var list = <OutboxEntry>[];
    if (raw != null) {
      try {
        list = (jsonDecode(raw) as List)
            .map((e) => OutboxEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Outbox: discarding unreadable queue: $e');
      }
    }
    _entries = list;
    pending.value = list.length;
    return list;
  }

  Future<void> _save() async {
    final list = _entries ?? const <OutboxEntry>[];
    pending.value = list.length;
    final prefs = await SharedPreferences.getInstance();
    if (list.isEmpty) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setString(storageKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    }
  }

  /// Loads the persisted queue (call at startup).
  Future<void> load() => _load();

  /// A snapshot of the queued entries, oldest first.
  Future<List<OutboxEntry>> entries() async => List.unmodifiable(await _load());

  /// Adds a request to the end of the queue and persists it.
  Future<OutboxEntry> enqueue({
    required String method,
    required Uri url,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final list = await _load();
    final entry = OutboxEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
      method: method.toUpperCase(),
      url: url,
      headers: Map.of(headers)..removeWhere((k, _) => k.toLowerCase() == 'authorization'),
      body: body,
      createdAt: DateTime.now(),
    );
    list.add(entry);
    await _save();
    return entry;
  }

  /// Sends queued requests in order. Concurrent calls share one run.
  Future<ReplayResult> replay() => _replaying ??= _replay().whenComplete(() => _replaying = null);

  Future<ReplayResult> _replay() async {
    final list = await _load();
    var sent = 0, dropped = 0;
    String? stoppedBy;
    while (list.isNotEmpty) {
      final entry = list.first;
      String? token;
      try {
        token = await _tokenProvider();
      } catch (_) {
        token = null;
      }
      if (token == null) {
        stoppedBy = 'no_session';
        break;
      }
      final req = http.Request(entry.method, entry.url)
        ..headers.addAll(entry.headers)
        ..headers['Authorization'] = 'Bearer $token';
      if (entry.body != null) req.body = entry.body!;

      http.Response res;
      try {
        res = await http.Response.fromStream(await _client.send(req));
      } catch (e) {
        if (!isNetworkError(e)) debugPrint('Outbox: replay error: $e');
        stoppedBy = 'network';
        break;
      }

      final s = res.statusCode;
      if (s >= 200 && s < 300) {
        list.removeAt(0);
        sent++;
        await _save();
      } else if (s == 401 || s == 408 || s == 429 || s >= 500) {
        entry.attempts++;
        await _save();
        stoppedBy = 'http_$s';
        break;
      } else {
        list.removeAt(0);
        dropped++;
        lastRejection.value = _errorMessage(res);
        await _save();
      }
    }
    return ReplayResult(sent: sent, dropped: dropped, remaining: list.length, stoppedBy: stoppedBy);
  }

  static String _errorMessage(http.Response r) {
    try {
      final d = jsonDecode(r.body);
      if (d is Map && d['error'] != null) return d['error'].toString();
    } catch (_) {}
    return 'A queued change was rejected (${r.statusCode})';
  }

  /// Drops every queued request (e.g. on logout).
  Future<void> clear() async {
    _entries = [];
    lastRejection.value = null;
    await _save();
  }
}
