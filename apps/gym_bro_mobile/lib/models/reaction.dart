import '../l10n/app_localizations.dart';

/// The ten reactions shared by posts, comments and chat messages
/// (API `reaction_type`).
enum ReactionType {
  like('like', '👍'),
  love('love', '❤️'),
  haha('haha', '😂'),
  wow('wow', '😮'),
  sad('sad', '😢'),
  angry('angry', '😡'),
  fire('fire', '🔥'),
  strong('strong', '💪'),
  clap('clap', '👏'),
  celebrate('celebrate', '🎉');

  const ReactionType(this.apiValue, this.emoji);

  final String apiValue;
  final String emoji;

  static ReactionType? tryParse(Object? value) {
    for (final r in values) {
      if (r.apiValue == value) return r;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
    ReactionType.like => l10n.reactionLike,
    ReactionType.love => l10n.reactionLove,
    ReactionType.haha => l10n.reactionHaha,
    ReactionType.wow => l10n.reactionWow,
    ReactionType.sad => l10n.reactionSad,
    ReactionType.angry => l10n.reactionAngry,
    ReactionType.fire => l10n.reactionFire,
    ReactionType.strong => l10n.reactionStrong,
    ReactionType.clap => l10n.reactionClap,
    ReactionType.celebrate => l10n.reactionCelebrate,
  };
}

/// Per-type counts on a post or comment, plus the top three types to show.
class ReactionSummary {
  final Map<ReactionType, int> counts;
  final int total;
  final List<ReactionType> top;

  const ReactionSummary({this.counts = const {}, this.total = 0, this.top = const []});

  static const empty = ReactionSummary();

  factory ReactionSummary.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return empty;
    final counts = <ReactionType, int>{};
    final raw = json['counts'];
    if (raw is Map<String, dynamic>) {
      for (final e in raw.entries) {
        final type = ReactionType.tryParse(e.key);
        if (type != null) counts[type] = int.parse(e.value.toString());
      }
    }
    return ReactionSummary(
      counts: counts,
      total: int.parse((json['total'] ?? 0).toString()),
      top: (json['top'] as List<dynamic>? ?? [])
          .map(ReactionType.tryParse)
          .whereType<ReactionType>()
          .toList(),
    );
  }

  /// The summary after the caller's reaction changes from [from] to [to]
  /// (either may be null), for optimistic updates.
  ReactionSummary switched(ReactionType? from, ReactionType? to) {
    final next = Map<ReactionType, int>.from(counts);
    var nextTotal = total;
    if (from != null && (next[from] ?? 0) > 0) {
      next[from] = next[from]! - 1;
      if (next[from] == 0) next.remove(from);
      nextTotal--;
    }
    if (to != null) {
      next[to] = (next[to] ?? 0) + 1;
      nextTotal++;
    }
    final sorted = next.entries.toList()
      ..sort((a, b) => b.value != a.value
          ? b.value.compareTo(a.value)
          : a.key.index.compareTo(b.key.index));
    return ReactionSummary(
      counts: next,
      total: nextTotal < 0 ? 0 : nextTotal,
      top: sorted.take(3).map((e) => e.key).toList(),
    );
  }
}
