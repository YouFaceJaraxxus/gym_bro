import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/last_sets.dart';
import 'api_service.dart';
import 'auth_manager.dart';

/// Last time's sets per exercise for one logging screen, fetched in the
/// background in batches. Fails soft: offline, slow or no history just
/// means nothing for that exercise (logging never waits on it).
class OverloadHistory extends ChangeNotifier {
  OverloadHistory({
    ApiService? api,
    this.userId,
    this.before,
    this.timeout = const Duration(seconds: 8),
    Future<String> Function()? token,
  })  : _api = api ?? ApiService(),
        _token = token ?? AuthManager.instance.getValidToken;

  final ApiService _api;
  final Future<String> Function() _token;

  /// Whose history: a client's when a coach logs for them.
  final String? userId;

  /// Only sessions before this (a back-dated workout); null = now.
  final DateTime? before;
  final Duration timeout;

  final Map<String, LastPerformance> _byExercise = {};
  final Set<String> _asked = {};
  bool _disposed = false;

  /// Last time for [exerciseId], once loaded.
  LastPerformance? operator [](String? exerciseId) => exerciseId == null ? null : _byExercise[exerciseId];

  /// Fetches exercises not asked for yet. Never throws; a failed batch can be
  /// asked for again later.
  Future<void> load(Iterable<String?> exerciseIds) async {
    final missing = {
      for (final id in exerciseIds)
        if (id != null && id.isNotEmpty && !_asked.contains(id)) id,
    };
    if (missing.isEmpty) return;
    _asked.addAll(missing);
    try {
      final token = await _token();
      final rows = await _api.getLastSets(token, missing, userId: userId, before: before).timeout(timeout);
      if (_disposed) return;
      for (final r in rows) {
        _byExercise[r.exerciseId] = r;
      }
      if (rows.isNotEmpty) notifyListeners();
    } catch (e) {
      _asked.removeAll(missing);
      debugPrint('OverloadHistory: no history ($e)');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
