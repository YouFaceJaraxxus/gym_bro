import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/services/offline/caching_client.dart';
import 'package:gym_bro_mobile/services/offline/connectivity_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _jwt(String sub) {
  String seg(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg({'sub': sub, 'exp': 1})}.sig';
}

final _networkError = predicate<Object>(isNetworkError, 'a network error');

void main() {
  late Directory tmp;
  final connectivity = ConnectivityService.instance;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('caching_client_test');
    connectivity.resetForTest();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// A mock backend that can be switched offline.
  ({CachingClient client, void Function(bool) setOnline, List<http.BaseRequest> seen}) build({
    Duration timeout = const Duration(seconds: 20),
    int maxEntries = 200,
    Future<http.Response> Function(http.Request req)? handler,
  }) {
    var online = true;
    final seen = <http.BaseRequest>[];
    final mock = MockClient((req) async {
      seen.add(req);
      if (!online) throw const SocketException('Network is unreachable');
      if (handler != null) return handler(req);
      return http.Response(jsonEncode({'path': req.url.path, 'n': seen.length}), 200,
          headers: {'content-type': 'application/json'});
    });
    final client = CachingClient(
      inner: mock,
      timeout: timeout,
      maxEntries: maxEntries,
      cacheDirectory: () async => Directory('${tmp.path}/cache'),
      connectivity: connectivity,
    );
    return (client: client, setOnline: (v) => online = v, seen: seen);
  }

  final url = Uri.parse('http://api.test/functions/v1/businesses');
  final token = _jwt('user-1');

  test('passes successful responses through unchanged', () async {
    final b = build();
    final r = await b.client.get(url, headers: {'Authorization': 'Bearer $token'});
    expect(r.statusCode, 200);
    expect(jsonDecode(r.body)['path'], '/functions/v1/businesses');
    expect(isOfflineResponse(r), isFalse);
  });

  test('serves the cached GET with x-gymbro-offline when the network fails', () async {
    final b = build();
    final online = await b.client.get(url, headers: {'Authorization': 'Bearer $token'});
    await b.client.flush();

    b.setOnline(false);
    final offline = await b.client.get(url, headers: {'Authorization': 'Bearer $token'});
    expect(offline.statusCode, 200);
    expect(offline.body, online.body);
    expect(offline.headers[offlineHeader], '1');
    expect(isOfflineResponse(offline), isTrue);
    expect(connectivity.online.value, isFalse, reason: 'network failure is reported');

    b.setOnline(true);
    await b.client.get(url, headers: {'Authorization': 'Bearer $token'});
    expect(connectivity.online.value, isTrue, reason: 'next success clears the offline state');
  });

  test('rethrows the network error when nothing is cached', () async {
    final b = build();
    b.setOnline(false);
    await expectLater(
      b.client.get(url, headers: {'Authorization': 'Bearer $token'}),
      throwsA(_networkError),
    );
  });

  test('never falls back to the cache for writes', () async {
    final b = build();
    await b.client.get(url, headers: {'Authorization': 'Bearer $token'});
    await b.client.flush();
    b.setOnline(false);
    await expectLater(
      b.client.post(url, headers: {'Authorization': 'Bearer $token'}, body: '{}'),
      throwsA(_networkError),
    );
  });

  test('does not cache error responses', () async {
    final b = build(handler: (req) async => http.Response('{"error":"nope"}', 500));
    final r = await b.client.get(url, headers: {'Authorization': 'Bearer $token'});
    expect(r.statusCode, 500);
    await b.client.flush();
    expect(await b.client.cachedCount(), 0);
  });

  test('cache is per user and survives token refreshes for the same user', () async {
    final b = build();
    await b.client.get(url, headers: {'Authorization': 'Bearer $token'});
    await b.client.flush();
    b.setOnline(false);

    // Same subject, new token (hourly refresh) → hit.
    final refreshed = _jwt('user-1').replaceFirst('sig', 'other-sig');
    final hit = await b.client.get(url, headers: {'Authorization': 'Bearer $refreshed'});
    expect(isOfflineResponse(hit), isTrue);

    // Different user → miss.
    await expectLater(
      b.client.get(url, headers: {'Authorization': 'Bearer ${_jwt('user-2')}'}),
      throwsA(_networkError),
    );
  });

  test('identityFor uses the JWT subject, else the raw header', () {
    expect(CachingClient.identityFor('Bearer $token'), 'sub:user-1');
    expect(CachingClient.identityFor('Bearer not-a-jwt'), 'hdr:Bearer not-a-jwt');
    expect(CachingClient.identityFor(null), 'anon');
  });

  test('times out slow requests and falls back to the cache', () async {
    var slow = false;
    final b = build(
      timeout: const Duration(milliseconds: 100),
      handler: (req) async {
        if (slow) await Completer<void>().future; // never answers
        return http.Response('{"ok":true}', 200);
      },
    );
    await b.client.get(url, headers: {'Authorization': 'Bearer $token'});
    await b.client.flush();

    slow = true;
    final r = await b.client.get(url, headers: {'Authorization': 'Bearer $token'});
    expect(isOfflineResponse(r), isTrue);
    expect(r.body, '{"ok":true}');

    final other = Uri.parse('http://api.test/functions/v1/never-cached');
    await expectLater(
      b.client.get(other, headers: {'Authorization': 'Bearer $token'}),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('evicts the least recently used entries beyond maxEntries', () async {
    final b = build(maxEntries: 2);
    Uri u(int i) => Uri.parse('http://api.test/functions/v1/items/$i');
    final h = {'Authorization': 'Bearer $token'};
    await b.client.get(u(1), headers: h);
    await b.client.flush();
    await b.client.get(u(2), headers: h);
    await b.client.flush();
    await b.client.get(u(3), headers: h);
    await b.client.flush();
    expect(await b.client.cachedCount(), 2);

    b.setOnline(false);
    expect(isOfflineResponse(await b.client.get(u(3), headers: h)), isTrue);
    expect(isOfflineResponse(await b.client.get(u(2), headers: h)), isTrue);
    await expectLater(b.client.get(u(1), headers: h), throwsA(_networkError));
  });

  test('clear() and clearAll() remove cached responses', () async {
    final b = build();
    await b.client.get(url, headers: {'Authorization': 'Bearer $token'});
    await b.client.flush();
    expect(await b.client.cachedCount(), 1);
    await CachingClient.clearAll();
    expect(await b.client.cachedCount(), 0);
    b.setOnline(false);
    await expectLater(
      b.client.get(url, headers: {'Authorization': 'Bearer $token'}),
      throwsA(_networkError),
    );
  });

  test('works without a cache directory (no path_provider)', () async {
    final client = CachingClient(
      inner: MockClient((_) async => http.Response('ok', 200)),
      cacheDirectory: () async => null,
      connectivity: connectivity,
    );
    expect((await client.get(url)).body, 'ok');
    await client.flush();
    expect(await client.cachedCount(), 0);
  });
}
