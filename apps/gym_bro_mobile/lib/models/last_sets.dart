import 'training.dart';

/// One logged set (drop) from last time, as GET /training-sessions/last-sets
/// returns it. Weights are in kilograms.
class LastSet {
  final double? weightKg;
  final int? reps;
  final RepType repType;

  const LastSet({this.weightKg, this.reps, this.repType = RepType.count});

  factory LastSet.fromJson(Map<String, dynamic> json) {
    final w = json['weight_kg'];
    final r = json['reps'];
    return LastSet(
      // Postgres numerics may arrive as strings.
      weightKg: w == null ? null : double.tryParse(w.toString()),
      reps: r == null ? null : int.tryParse(r.toString()),
      repType: RepType.fromApiValue(json['rep_type'] as String? ?? 'count'),
    );
  }
}

/// What the user did on [exerciseId] in their most recent finished session.
class LastPerformance {
  final String exerciseId;
  final String sessionId;
  final DateTime startedAt;
  final List<LastSet> sets;

  const LastPerformance({
    required this.exerciseId,
    required this.sessionId,
    required this.startedAt,
    required this.sets,
  });

  factory LastPerformance.fromJson(Map<String, dynamic> json) => LastPerformance(
        exerciseId: json['exercise_id'] as String,
        sessionId: json['session_id'] as String? ?? '',
        startedAt: DateTime.tryParse(json['started_at'] as String? ?? '')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        sets: (json['sets'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(LastSet.fromJson)
            .toList(),
      );
}
