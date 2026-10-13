import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'connectivity_service.dart';

/// Header added to responses served from the offline cache.
const offlineHeader = 'x-gymbro-offline';

/// True for errors that mean "couldn't reach the server" (as opposed to the
/// server answering with an error status).
bool isNetworkError(Object e) =>
    e is SocketException ||
    e is http.ClientException ||
    e is TimeoutException ||
    e is HttpException;

/// True when [r] was served from the offline cache rather than the network.
bool isOfflineResponse(http.BaseResponse r) => r.headers[offlineHeader] == '1';

/// The HTTP client behind `ApiService`.
///
/// - Every request times out after [timeout] (multipart uploads get
///   [uploadTimeout]).
/// - Successful GET responses are cached on disk, keyed by URL + a hash of the
///   caller's identity (JWT `sub`, falling back to the whole Authorization
///   header), capped at [maxEntries] with least-recently-used eviction.
/// - When a GET fails with a network error, the cached response is returned
///   with the `x-gymbro-offline: 1` header; without a cached copy the error is
///   rethrown.
/// - Request outcomes are reported to [ConnectivityService].
class CachingClient extends http.BaseClient {
  CachingClient({
    http.Client? inner,
    this.timeout = const Duration(seconds: 20),
    this.uploadTimeout = const Duration(minutes: 2),
    this.maxEntries = 200,
    Future<Directory?> Function()? cacheDirectory,
    ConnectivityService? connectivity,
  })  : _inner = inner ?? http.Client(),
        _cacheDirectory = cacheDirectory ?? _defaultCacheDirectory,
        _connectivity = connectivity ?? ConnectivityService.instance {
    _instances.add(this);
  }

  /// The single client shared by every `ApiService` instance.
  static final CachingClient shared = CachingClient();

  static final Set<CachingClient> _instances = {};

  /// Deletes every cached response of every client. Call on logout.
  static Future<void> clearAll() async {
    for (final c in _instances.toList()) {
      await c.clear();
    }
  }

  final http.Client _inner;
  final Duration timeout;
  final Duration uploadTimeout;
  final int maxEntries;
  final Future<Directory?> Function() _cacheDirectory;
  final ConnectivityService _connectivity;

  Future<Directory?>? _dirFuture;

  final Set<Future<void>> _pendingWrites = {};

  /// Waits for in-flight cache writes (responses are returned before their
  /// copy hits the disk).
  @visibleForTesting
  Future<void> flush() => Future.wait(_pendingWrites.toList());

  /// Cache key → last access time, oldest first.
  LinkedHashMap<String, DateTime>? _index;

  static Future<Directory?> _defaultCacheDirectory() async {
    try {
      final base = await getApplicationSupportDirectory();
      return Directory('${base.path}${Platform.pathSeparator}http_cache');
    } catch (_) {
      return null; // No path_provider (tests, unsupported platform): no cache.
    }
  }

  Future<Directory?> _dir() => _dirFuture ??= () async {
        try {
          final d = await _cacheDirectory();
          if (d == null) return null;
          await d.create(recursive: true);
          return d;
        } catch (_) {
          return null;
        }
      }();

  // ── Sending ────────────────────────────────────────────────────────────────

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isGet = request.method.toUpperCase() == 'GET';
    final limit = request is http.MultipartRequest ? uploadTimeout : timeout;
    final key = isGet ? _keyFor(request) : null;

    final http.StreamedResponse streamed;
    final Uint8List bytes;
    try {
      (streamed, bytes) = await () async {
        final s = await _inner.send(request);
        return (s, await s.stream.toBytes());
      }()
          .timeout(limit);
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      _connectivity.reportNetworkFailure();
      if (key != null) {
        final cached = await _read(key, request);
        if (cached != null) return cached;
      }
      rethrow;
    }

    _connectivity.reportNetworkSuccess();
    if (key != null && streamed.statusCode >= 200 && streamed.statusCode < 300) {
      final write = _write(key, request.url.toString(), streamed, bytes);
      _pendingWrites.add(write);
      unawaited(write.whenComplete(() => _pendingWrites.remove(write)));
    }
    return http.StreamedResponse(
      Stream.value(bytes),
      streamed.statusCode,
      contentLength: bytes.length,
      request: request,
      headers: streamed.headers,
      isRedirect: streamed.isRedirect,
      persistentConnection: streamed.persistentConnection,
      reasonPhrase: streamed.reasonPhrase,
    );
  }

  // ── Cache keys ─────────────────────────────────────────────────────────────

  String _keyFor(http.BaseRequest request) {
    final identity = _identity(request.headers['Authorization'] ?? request.headers['authorization']);
    return '${_fnv1a('${request.url}', 0x811c9dc5)}${_fnv1a('${request.url}', 0x01000193)}'
        '_${_fnv1a(identity, 0x811c9dc5)}';
  }

  /// The JWT subject when the header carries a parseable bearer token (so the
  /// cache survives hourly token refreshes), else the header itself.
  @visibleForTesting
  static String identityFor(String? authorization) => _identity(authorization);

  static String _identity(String? authorization) {
    if (authorization == null || authorization.isEmpty) return 'anon';
    final token = authorization.replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '');
    final parts = token.split('.');
    if (parts.length == 3) {
      try {
        final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
        if (payload is Map && payload['sub'] is String) return 'sub:${payload['sub']}';
      } catch (_) {/* not a JWT */}
    }
    return 'hdr:$authorization';
  }

  /// 32-bit FNV-1a, hex encoded. Not cryptographic — only used to build file
  /// names; the stored entry is verified against the full URL on read.
  static String _fnv1a(String input, int seed) {
    var h = seed;
    for (final b in utf8.encode(input)) {
      h ^= b;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  // ── Disk cache ─────────────────────────────────────────────────────────────

  File _file(Directory dir, String key) => File('${dir.path}${Platform.pathSeparator}$key.json');

  Future<LinkedHashMap<String, DateTime>> _loadIndex(Directory dir) async {
    final existing = _index;
    if (existing != null) return existing;
    final entries = <MapEntry<String, DateTime>>[];
    try {
      await for (final f in dir.list()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        final name = f.uri.pathSegments.last;
        entries.add(MapEntry(name.substring(0, name.length - 5), await f.lastModified()));
      }
    } catch (_) {/* unreadable dir: start empty */}
    entries.sort((a, b) => a.value.compareTo(b.value));
    return _index = LinkedHashMap.fromEntries(entries);
  }

  void _touch(LinkedHashMap<String, DateTime> index, String key) {
    index.remove(key);
    index[key] = DateTime.now();
  }

  Future<void> _write(String key, String url, http.StreamedResponse r, Uint8List bytes) async {
    try {
      final dir = await _dir();
      if (dir == null) return;
      final index = await _loadIndex(dir);
      final headers = Map<String, String>.from(r.headers)..remove(offlineHeader);
      await _file(dir, key).writeAsString(jsonEncode({
        'url': url,
        'status': r.statusCode,
        'headers': headers,
        'body': base64Encode(bytes),
        'saved_at': DateTime.now().toIso8601String(),
      }));
      _touch(index, key);
      while (index.length > maxEntries) {
        final oldest = index.keys.first;
        index.remove(oldest);
        try {
          await _file(dir, oldest).delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('CachingClient: cache write failed: $e');
    }
  }

  Future<http.StreamedResponse?> _read(String key, http.BaseRequest request) async {
    try {
      final dir = await _dir();
      if (dir == null) return null;
      final file = _file(dir, key);
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (data['url'] != request.url.toString()) return null; // hash collision
      final bytes = base64Decode(data['body'] as String);
      final index = await _loadIndex(dir);
      _touch(index, key);
      unawaited(file.setLastModified(DateTime.now()).catchError((_) {}));
      return http.StreamedResponse(
        Stream.value(bytes),
        data['status'] as int,
        contentLength: bytes.length,
        request: request,
        headers: {
          ...(data['headers'] as Map).cast<String, String>(),
          offlineHeader: '1',
        },
      );
    } catch (e) {
      debugPrint('CachingClient: cache read failed: $e');
      return null;
    }
  }

  /// Number of cached responses (for tests / diagnostics).
  Future<int> cachedCount() async {
    final dir = await _dir();
    if (dir == null) return 0;
    return (await _loadIndex(dir)).length;
  }

  /// Deletes every cached response.
  Future<void> clear() async {
    await flush();
    final dir = await _dir();
    _index = LinkedHashMap();
    if (dir == null) return;
    try {
      await for (final f in dir.list()) {
        if (f is File) await f.delete();
      }
    } catch (_) {}
  }

  @override
  void close() {
    _instances.remove(this);
    _inner.close();
  }
}
