// Mentions in captions and comments, Instagram-style. Stored text carries
// them as markup the app renders as a tappable "@Name":
//
//   @[Elena Vasquez](user:<uuid>)   @[Ironclad Fitness](business:<uuid>)
//   @[Whey Isolate](shop_item:<uuid>)
//
// (same grammar as the API's _shared/mentions.ts). The composer inserts
// markup when a suggestion is picked; see MentionTextEditingController.

/// What a mention points at.
enum MentionKind {
  user('user'),
  business('business'),
  shopItem('shop_item');

  const MentionKind(this.apiValue);
  final String apiValue;

  static MentionKind? tryParse(Object? v) {
    final s = v?.toString().toLowerCase();
    for (final k in values) {
      if (k.apiValue == s) return k;
    }
    return null;
  }
}

/// One mention: who/what and the name shown for it.
class Mention {
  final MentionKind kind;
  final String id;
  final String label;

  const Mention({required this.kind, required this.id, required this.label});

  /// The stored form, `@[label](kind:id)`.
  String get markup => '@[${sanitizeMentionLabel(label)}](${kind.apiValue}:$id)';

  /// What the reader sees.
  String get display => '@${sanitizeMentionLabel(label)}';

  @override
  bool operator ==(Object other) => other is Mention && other.kind == kind && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(kind, id, label);

  @override
  String toString() => markup;
}

final _markupRe = RegExp(
  r'@\[([^\]\n]{1,100})\]\((user|business|shop_item):([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\)',
);

/// A label that fits the markup: no "]" or newlines, at most 100 characters.
String sanitizeMentionLabel(String label) {
  final s = label.replaceAll(RegExp(r'[\]\n\r]'), '').trim();
  return s.length > 100 ? s.substring(0, 100) : s;
}

/// A run of stored text: plain, or one mention.
class MentionSegment {
  final String text;
  final Mention? mention;

  const MentionSegment.text(this.text) : mention = null;
  MentionSegment.mention(Mention this.mention) : text = mention.display;

  bool get isMention => mention != null;
}

/// [text] split into plain runs and mentions, in order.
List<MentionSegment> parseMentions(String text) {
  final out = <MentionSegment>[];
  var last = 0;
  for (final m in _markupRe.allMatches(text)) {
    if (m.start > last) out.add(MentionSegment.text(text.substring(last, m.start)));
    out.add(
      MentionSegment.mention(
        Mention(kind: MentionKind.tryParse(m.group(2))!, id: m.group(3)!.toLowerCase(), label: m.group(1)!),
      ),
    );
    last = m.end;
  }
  if (last < text.length) out.add(MentionSegment.text(text.substring(last)));
  return out;
}

/// [text] with mentions as "@Name" (copying, previews, measuring).
String mentionPlainText(String text) => text.replaceAllMapped(_markupRe, (m) => '@${m.group(1)}');

/// Whether [text] has any mention markup.
bool hasMentions(String text) => _markupRe.hasMatch(text);

/// A row of GET /posts/mention-search.
class MentionSuggestion {
  final MentionKind kind;
  final String id;
  final String label;
  final String? subtitle;
  final String? imageUrl;

  /// People only.
  final String? username;

  /// Businesses only: 'gym' or 'shop'.
  final String? businessType;

  const MentionSuggestion({
    required this.kind,
    required this.id,
    required this.label,
    this.subtitle,
    this.imageUrl,
    this.username,
    this.businessType,
  });

  Mention get mention => Mention(kind: kind, id: id, label: label);

  static MentionSuggestion? maybeFromJson(Map<String, dynamic> json) {
    final kind = MentionKind.tryParse(json['kind']);
    final id = json['id']?.toString();
    if (kind == null || id == null) return null;
    final username = json['username'] as String?;
    final label = (json['label'] as String?)?.trim();
    return MentionSuggestion(
      kind: kind,
      id: id,
      label: label == null || label.isEmpty ? (username ?? '') : label,
      subtitle: json['subtitle'] as String?,
      imageUrl: json['image_url'] as String?,
      username: username,
      businessType: json['business_type'] as String?,
    );
  }
}
