import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// App-wide online/offline state.
///
/// [online] is false when the device reports no network interface
/// (connectivity_plus) OR when the most recent API request failed with a
/// network error (reported by `CachingClient`). The next successful request,
/// or the device regaining connectivity, flips it back to true.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  /// What the screens listen to.
  final ValueNotifier<bool> online = ValueNotifier(true);

  /// Fired every time the app transitions from offline to online (used to
  /// replay the outbox).
  final _backOnline = StreamController<void>.broadcast();
  Stream<void> get onBackOnline => _backOnline.stream;

  bool _deviceConnected = true;
  bool _lastRequestFailed = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _started = false;

  /// Starts listening to the platform. Safe to call more than once; failures
  /// (e.g. in tests or on unsupported platforms) leave the device assumed online.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final connectivity = Connectivity();
      _sub = connectivity.onConnectivityChanged.listen(
        _onPlatformChange,
        onError: (Object _) {},
      );
      _onPlatformChange(await connectivity.checkConnectivity());
    } catch (_) {
      // Plugin unavailable — rely on request outcomes only.
    }
  }

  void _onPlatformChange(List<ConnectivityResult> results) {
    final connected = results.any((r) => r != ConnectivityResult.none);
    if (connected && !_deviceConnected) {
      // Give the network the benefit of the doubt; the next request confirms.
      _lastRequestFailed = false;
    }
    _deviceConnected = connected;
    _update();
  }

  /// Called by the HTTP layer when a request failed with a network error.
  void reportNetworkFailure() {
    if (_lastRequestFailed) return;
    _lastRequestFailed = true;
    _update();
  }

  /// Called by the HTTP layer when a request reached the server.
  void reportNetworkSuccess() {
    if (!_lastRequestFailed && _deviceConnected) return;
    _lastRequestFailed = false;
    // A response arrived, so the device evidently has a network even if the
    // platform disagrees (e.g. emulators reporting "none").
    _deviceConnected = true;
    _update();
  }

  void _update() {
    final next = _deviceConnected && !_lastRequestFailed;
    if (next == online.value) return;
    online.value = next;
    if (next) _backOnline.add(null);
  }

  @visibleForTesting
  void resetForTest() {
    _deviceConnected = true;
    _lastRequestFailed = false;
    online.value = true;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
