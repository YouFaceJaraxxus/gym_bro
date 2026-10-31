// Hashtags ("#legday") in captions and comments, matching the API's
// _shared/hashtags.ts: a "#" not inside a word (nor after "&", "/" or "#"),
// then 1–50 letters, digits or underscores (any script) containing at least
// one letter. Tags are compared lowercased.

final _hashtagRe = RegExp(r'(^|[^\p{L}\p{N}_&/#])#([\p{L}\p{N}_]{1,50})', unicode: true);
final _letterRe = RegExp(r'\p{L}', unicode: true);
final _tagRe = RegExp(r'^[\p{L}\p{N}_]{1,50}$', unicode: true);

/// Where a hashtag is in a text: [start] is the "#", [end] is exclusive;
/// [tag] is lowercased, without the "#".
typedef HashtagMatch = ({int start, int end, String tag});

/// The hashtags in [text], in order. [before] is the character just before
/// [text] when it's a piece of a longer text (so "a#b" split after "a" still
/// isn't a tag).
List<HashtagMatch> findHashtags(String text, {String? before}) {
  final prefix = (before == null || before.isEmpty) ? '' : before.substring(before.length - 1);
  final source = prefix + text;
  final out = <HashtagMatch>[];
  for (final m in _hashtagRe.allMatches(source)) {
    final tag = m.group(2)!;
    if (!_letterRe.hasMatch(tag)) continue;
    final hash = m.start + m.group(1)!.length - prefix.length;
    if (hash < 0) continue;
    out.add((start: hash, end: hash + 1 + tag.length, tag: tag.toLowerCase()));
  }
  return out;
}

/// Unique lowercased hashtags in [text], in order of appearance.
List<String> parseHashtags(String text) {
  final out = <String>[];
  for (final m in findHashtags(text)) {
    if (!out.contains(m.tag)) out.add(m.tag);
  }
  return out;
}

/// Whether [text] has a hashtag.
bool hasHashtags(String text) => text.contains('#') && findHashtags(text).isNotEmpty;

/// A search term or link as a tag ("#LegDay" → "legday"); null when it
/// can't be one.
String? normalizeHashtag(String raw) {
  final tag = raw.trim().replaceFirst(RegExp(r'^#'), '').toLowerCase();
  return _tagRe.hasMatch(tag) ? tag : null;
}

/// A row of GET /posts/hashtags?q= and the body of GET /posts/hashtags/:tag.
class HashtagInfo {
  final String tag;
  final int postCount;

  const HashtagInfo({required this.tag, this.postCount = 0});

  factory HashtagInfo.fromJson(Map<String, dynamic> json) => HashtagInfo(
    tag: json['tag']?.toString() ?? '',
    postCount: double.tryParse('${json['post_count'] ?? 0}')?.round() ?? 0,
  );
}
