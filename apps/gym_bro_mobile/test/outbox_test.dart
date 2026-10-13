import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/services/offline/outbox.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'gymbro.outbox.v1';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Uri u(int i) => Uri.parse('http://api.test/functions/v1/training-sessions/s1/sets?i=$i');

  test('persists queued requests without the Authorization header', () async {
    final outbox = Outbox(tokenProvider: () async => 't', client: MockClient((_) async => http.Response('', 201)));
    await outbox.enqueue(
      method: 'post',
      url: u(1),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer secret'},
      body: '{"position":0}',
    );
    expect(outbox.pending.value, 1);

    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString(key)!) as List;
    expect(stored, hasLength(1));
    expect(stored.first['method'], 'POST');
    expect(stored.first['body'], '{"position":0}');
    expect((stored.first['headers'] as Map).keys, isNot(contains('Authorization')));

    // A fresh instance (app restart) sees the same queue.
    final reloaded = Outbox(tokenProvider: () async => 't');
    await reloaded.load();
    expect(reloaded.pending.value, 1);
    expect((await reloaded.entries()).single.url, u(1));
  });

  test('replays in order with a fresh token and empties the queue', () async {
    final sent = <http.BaseRequest>[];
    final bodies = <String>[];
    final outbox = Outbox(
      tokenProvider: () async => 'fresh-token',
      client: MockClient((req) async {
        sent.add(req);
        bodies.add(req.body);
        return http.Response('{}', 201);
      }),
    );
    for (var i = 0; i < 3; i++) {
      await outbox.enqueue(method: 'POST', url: u(i), body: '{"position":$i}');
    }

    final result = await outbox.replay();
    expect(result.sent, 3);
    expect(result.remaining, 0);
    expect(sent.map((r) => r.url), [u(0), u(1), u(2)]);
    expect(bodies, ['{"position":0}', '{"position":1}', '{"position":2}']);
    expect(sent.every((r) => r.headers['Authorization'] == 'Bearer fresh-token'), isTrue);
    expect(outbox.pending.value, 0);
    expect((await SharedPreferences.getInstance()).getString(key), isNull);
  });

  test('stops at the first network error and keeps the rest in order', () async {
    var calls = 0;
    final outbox = Outbox(
      tokenProvider: () async => 't',
      client: MockClient((req) async {
        calls++;
        if (calls == 2) throw const SocketException('offline');
        return http.Response('{}', 201);
      }),
    );
    for (var i = 0; i < 3; i++) {
      await outbox.enqueue(method: 'POST', url: u(i), body: '{}');
    }

    final first = await outbox.replay();
    expect(first.sent, 1);
    expect(first.remaining, 2);
    expect(first.stoppedBy, 'network');
    expect((await outbox.entries()).map((e) => e.url), [u(1), u(2)]);

    final second = await outbox.replay();
    expect(second.sent, 2);
    expect(outbox.pending.value, 0);
  });

  test('keeps entries on 5xx / 401 and drops permanent 4xx rejections', () async {
    final statuses = [503, 400, 201];
    final outbox = Outbox(
      tokenProvider: () async => 't',
      client: MockClient((req) async {
        final s = statuses.removeAt(0);
        return http.Response(s == 400 ? '{"error":"Set position taken"}' : '{}', s);
      }),
    );
    await outbox.enqueue(method: 'POST', url: u(0), body: '{}');
    await outbox.enqueue(method: 'POST', url: u(1), body: '{}');

    final r1 = await outbox.replay(); // 503 → stop, keep both
    expect(r1.stoppedBy, 'http_503');
    expect(outbox.pending.value, 2);
    expect((await outbox.entries()).first.attempts, 1);

    final r2 = await outbox.replay(); // 400 → drop u(0); 201 → send u(1)
    expect(r2.dropped, 1);
    expect(r2.sent, 1);
    expect(outbox.lastRejection.value, 'Set position taken');
    expect(outbox.pending.value, 0);
  });

  test('does nothing without a session', () async {
    var calls = 0;
    final outbox = Outbox(
      tokenProvider: () async => null,
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 201);
      }),
    );
    await outbox.enqueue(method: 'POST', url: u(0), body: '{}');
    final r = await outbox.replay();
    expect(r.stoppedBy, 'no_session');
    expect(calls, 0);
    expect(outbox.pending.value, 1);
  });

  test('clear() drops everything', () async {
    final outbox = Outbox(tokenProvider: () async => 't');
    await outbox.enqueue(method: 'POST', url: u(0), body: '{}');
    await outbox.clear();
    expect(outbox.pending.value, 0);
    expect((await SharedPreferences.getInstance()).getString(key), isNull);
  });

  test('QueuedOfflineException reads as a friendly message', () {
    expect(const QueuedOfflineException().toString(), contains('offline'));
  });
}
