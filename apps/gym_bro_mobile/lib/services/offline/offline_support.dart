import 'dart:async';

import 'package:flutter/foundation.dart';

import 'caching_client.dart';
import 'connectivity_service.dart';
import 'outbox.dart';

export 'caching_client.dart' show CachingClient, isNetworkError, isOfflineResponse;
export 'connectivity_service.dart' show ConnectivityService;
export 'outbox.dart' show Outbox, OutboxEntry, QueuedOfflineException;

/// Wires the offline pieces together: connectivity monitoring, the shared
/// caching HTTP client and the outbox of queued writes.
class OfflineSupport {
  OfflineSupport._();

  /// Supplies a fresh access token for replays (null = signed out). Set by
  /// `ApiService` so this library doesn't depend on the auth layer.
  static Future<String?> Function() tokenProvider = () async => null;

  /// The app's outbox. Replays with the current session's token.
  static final Outbox outbox = Outbox(
    tokenProvider: () => tokenProvider(),
    client: CachingClient.shared,
  );

  static Future<void>? _started;
  static StreamSubscription<void>? _backOnlineSub;

  /// Starts connectivity monitoring, loads the outbox and replays it, and
  /// replays again whenever the device comes back online. Idempotent — called
  /// lazily by `ApiService` and `OfflineBanner`; calling it from `main()` is
  /// fine too.
  static Future<void> ensureStarted({Future<String?> Function()? tokenProvider}) {
    if (tokenProvider != null && tokenProvider != OfflineSupport.tokenProvider) {
      OfflineSupport.tokenProvider = tokenProvider;
      // Started earlier without a way to authenticate: retry the queue now.
      final started = _started;
      if (started != null) unawaited(started.then((_) => _replay()));
    }
    return _started ??= _start();
  }

  static Future<void> _start() async {
    try {
      await ConnectivityService.instance.start();
      _backOnlineSub ??= ConnectivityService.instance.onBackOnline.listen((_) => _replay());
      await outbox.load();
      unawaited(_replay());
    } catch (e) {
      debugPrint('OfflineSupport: start failed: $e');
    }
  }

  static Future<void> _replay() async {
    try {
      await outbox.replay();
    } catch (e) {
      debugPrint('OfflineSupport: replay failed: $e');
    }
  }

  /// Sends queued writes now (e.g. right after sign-in or on pull-to-refresh).
  static Future<void> syncNow() => _replay();

  /// Call on logout: deletes cached responses and drops queued writes so the
  /// next user never sees (or sends) the previous user's data.
  static Future<void> clearOnLogout() async {
    await CachingClient.clearAll();
    await outbox.clear();
  }
}
