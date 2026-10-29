// Shared expectations for the ApiService tests in this directory (the request
// recording itself lives in ../helpers/fake_backend.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/services/api_service.dart';
import 'package:http/http.dart' as http;

import '../helpers/fake_backend.dart';

const token = 'test-token';

/// Installs a fresh [FakeBackend] around every test of the enclosing group and
/// returns a getter for it plus a fresh [ApiService].
({FakeBackend Function() backend, ApiService Function() api}) useFakeBackend() {
  late FakeBackend backend;
  late ApiService api;
  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());
  return (backend: () => backend, api: () => api);
}

void expectAuthed(http.BaseRequest r) {
  expect(r.headers['Authorization'], 'Bearer $token', reason: '${describe(r)} sends the bearer token');
}

/// A read: GET [path] with exactly [query] (decoded) and the bearer token.
void expectGet(http.Request r, String path, [Map<String, String> query = const {}]) {
  expect(r.method, 'GET');
  expect(pathOf(r), path);
  expect(r.url.queryParameters, equals(query), reason: 'query of ${describe(r)}');
  expectAuthed(r);
}

/// A JSON write: [method] [path] (no query), bearer token, JSON content type
/// and exactly [body] once decoded (null = no body sent).
void expectJson(http.Request r, String method, String path, Object? body) {
  expect(r.method, method);
  expect(pathOf(r), path);
  expect(r.url.hasQuery, isFalse, reason: '${describe(r)} has no query');
  expectAuthed(r);
  expect(r.headers['Content-Type'], startsWith('application/json'));
  expect(bodyOf(r), equals(body), reason: 'body of ${describe(r)}');
}

/// A DELETE of [path] with the bearer token and no body.
void expectDelete(http.Request r, String path) {
  expect(r.method, 'DELETE');
  expect(pathOf(r), path);
  expect(r.url.hasQuery, isFalse);
  expectAuthed(r);
  expect(r.body, isEmpty);
}

/// Throws an `Exception` whose message is exactly [message].
Matcher throwsApiError(String message) =>
    throwsA(isA<Exception>().having((e) => e.toString(), 'toString()', 'Exception: $message'));

/// One API call for the table-driven error tests: the route it hits and how
/// to invoke it.
typedef ApiCall = (String route, Future<Object?> Function(ApiService api) call);

/// For every call: a `{"error": ...}` body surfaces its message, and a
/// non-JSON error body (an HTML gateway page) becomes "Request failed (502)".
void errorTests(
  ({FakeBackend Function() backend, ApiService Function() api}) ctx,
  Map<String, ApiCall> calls,
) {
  group('errors', () {
    for (final MapEntry(key: method, value: (route, call)) in calls.entries) {
      test('$method ($route) surfaces the API error message', () async {
        ctx.backend().on(route, err(403, 'Forbidden: not your gym'));
        await expectLater(call(ctx.api()), throwsApiError('Forbidden: not your gym'));
        ctx.backend().on(route, ok('<html>Bad gateway</html>', 502));
        await expectLater(call(ctx.api()), throwsApiError('Request failed (502)'));
        expect(ctx.backend().requests.map(describe).toSet().length, 1,
            reason: 'both attempts hit $route');
      });
    }
  });
}
