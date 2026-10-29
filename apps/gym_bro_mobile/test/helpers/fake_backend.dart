import 'dart:convert';

import 'package:gym_bro_mobile/services/api_service.dart';
import 'package:gym_bro_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A canned answer: status + JSON-encodable body (or a raw string).
typedef Reply = ({int status, Object? body});

Reply ok(Object? body, [int status = 200]) => (status: status, body: body);
Reply err(int status, String message, {String? code}) =>
    (status: status, body: {'error': message, 'code': ?code});

/// Records every request ApiService / AuthService send and answers from
/// [routes] (keyed `'METHOD /path'`, path without the `/functions/v1`
/// prefix, query ignored). Unknown routes answer 404 — that also keeps
/// realtime from opening a socket after sign-in.
///
/// ```dart
/// final backend = FakeBackend()..install();
/// addTearDown(backend.uninstall);
/// backend.on('GET /businesses', ok([...]));
/// ```
class FakeBackend {
  final Map<String, Reply Function(http.Request req)> _routes = {};
  final List<http.Request> requests = [];

  late final MockClient client = MockClient((req) async {
    requests.add(req);
    final handler = _routes['${req.method} ${pathOf(req)}'];
    final reply = handler?.call(req) ?? err(404, 'Not found');
    final body = reply.body;
    return http.Response(
      body is String ? body : jsonEncode(body),
      reply.status,
      headers: {'content-type': 'application/json'},
    );
  });

  /// Answers `'METHOD /path'` with [reply] (or computes it from the request).
  void on(String route, Object reply) {
    _routes[route] = reply is Reply ? (_) => reply : reply as Reply Function(http.Request);
  }

  void install() {
    ApiService.debugClientOverride = client;
    AuthService.debugClientOverride = client;
  }

  void uninstall() {
    ApiService.debugClientOverride = null;
    AuthService.debugClientOverride = null;
  }

  /// The single request sent so far (fails if there were none or several).
  http.Request get only {
    if (requests.length != 1) {
      throw StateError('expected 1 request, got ${requests.length}: ${requests.map(describe).toList()}');
    }
    return requests.single;
  }

  /// The last request to `'METHOD /path'`.
  http.Request last(String route) => requests.lastWhere(
        (r) => '${r.method} ${pathOf(r)}' == route,
        orElse: () => throw StateError('no $route in ${requests.map(describe).toList()}'),
      );
}

/// The request path without the `/functions/v1` prefix.
String pathOf(http.BaseRequest r) => r.url.path.replaceFirst(RegExp(r'^/functions/v1'), '');

String describe(http.BaseRequest r) => '${r.method} ${pathOf(r)}${r.url.hasQuery ? '?${r.url.query}' : ''}';

/// The decoded JSON body of [r].
Object? bodyOf(http.Request r) => r.body.isEmpty ? null : jsonDecode(r.body);
