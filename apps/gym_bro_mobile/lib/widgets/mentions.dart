import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/mention.dart';
import '../pages/people/user_profile_page.dart';
import '../pages/posts_page.dart';
import '../pages/shop/storefront_shop_page.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'social_widgets.dart';

// "@" mentions in text fields and text (Instagram-style):
//
// * [MentionTextEditingController] — shows mentions as "@Name" while keeping
//   where each one is; [MentionTextEditingController.markup] is the stored
//   form (`@[Name](kind:id)`), [MentionTextEditingController.markup] = … loads
//   it back for editing.
// * [MentionAutocomplete] — wraps the field: typing "@" drops down people,
//   gyms/shops and products (GET /posts/mention-search); picking one inserts it.
// * [MentionText] — renders stored text with tappable mentions.

class _Range {
  _Range(this.start, this.end, this.mention);

  int start;
  int end;
  final Mention mention;
}

/// A text controller whose text shows mentions as "@Name". Typing inside a
/// mention turns it back into plain text; deleting into one removes it whole.
class MentionTextEditingController extends TextEditingController {
  MentionTextEditingController({String markup = ''}) {
    this.markup = markup;
  }

  final List<_Range> _ranges = [];

  /// The mentions in the text, in order, with where each one is shown.
  List<({int start, int end, Mention mention})> get mentions => [
    for (final r in _ranges) (start: r.start, end: r.end, mention: r.mention),
  ];

  /// The text in its stored form, mentions as markup.
  String get markup {
    final t = text;
    final out = StringBuffer();
    var last = 0;
    for (final r in _ranges) {
      out
        ..write(t.substring(last, r.start))
        ..write(r.mention.markup);
      last = r.end;
    }
    out.write(t.substring(last));
    return out.toString();
  }

  /// Replaces the text with stored text [value] (markup → "@Name"), the
  /// cursor at the end.
  set markup(String value) {
    _ranges.clear();
    final out = StringBuffer();
    for (final seg in parseMentions(value)) {
      final start = out.length;
      out.write(seg.text);
      if (seg.mention != null) _ranges.add(_Range(start, out.length, seg.mention!));
    }
    final t = out.toString();
    super.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  @override
  void clear() {
    _ranges.clear();
    super.clear();
  }

  @override
  set value(TextEditingValue newValue) {
    final old = super.value;
    if (_ranges.isEmpty || newValue.text == old.text) {
      super.value = newValue;
      return;
    }
    final a = old.text, b = newValue.text;
    // The edit: old [from, oldTo) became new [from, newTo).
    var from = 0;
    final shorter = math.min(a.length, b.length);
    while (from < shorter && a.codeUnitAt(from) == b.codeUnitAt(from)) {
      from++;
    }
    var tail = 0;
    while (tail < a.length - from &&
        tail < b.length - from &&
        a.codeUnitAt(a.length - 1 - tail) == b.codeUnitAt(b.length - 1 - tail)) {
      tail++;
    }
    final oldTo = a.length - tail;
    final newTo = b.length - tail;

    if (from == oldTo) {
      // Pure insertion at [from]: before a mention shifts it, inside one
      // makes it plain text.
      final delta = newTo - from;
      _ranges.removeWhere((r) => r.start < from && from < r.end);
      for (final r in _ranges) {
        if (r.start >= from) {
          r.start += delta;
          r.end += delta;
        }
      }
      super.value = newValue;
      return;
    }

    final touched = _ranges.where((r) => r.start < oldTo && r.end > from).toList();
    if (newTo == from && touched.isNotEmpty) {
      // A deletion reaching into mentions takes them whole.
      final start = math.min(from, touched.map((r) => r.start).reduce(math.min));
      final end = math.max(oldTo, touched.map((r) => r.end).reduce(math.max));
      _ranges.removeWhere(touched.contains);
      for (final r in _ranges) {
        if (r.start >= end) {
          r.start -= end - start;
          r.end -= end - start;
        }
      }
      super.value = TextEditingValue(
        text: a.substring(0, start) + a.substring(end),
        selection: TextSelection.collapsed(offset: start),
      );
      return;
    }

    // A replacement: touched mentions become plain text, later ones shift.
    final delta = (newTo - from) - (oldTo - from);
    _ranges.removeWhere(touched.contains);
    for (final r in _ranges) {
      if (r.start >= oldTo) {
        r.start += delta;
        r.end += delta;
      }
    }
    super.value = newValue;
  }

  /// The "@query" being typed at the cursor: where its "@" is and the text
  /// after it. Null when the cursor isn't right after one (an "@" must start
  /// a word; the query ends at whitespace).
  ({int start, String query})? get mentionQuery {
    final sel = selection;
    if (!sel.isValid || !sel.isCollapsed) return null;
    final t = text;
    final cursor = math.min(sel.baseOffset, t.length);
    for (var i = cursor - 1; i >= 0 && cursor - i <= 31; i--) {
      final c = t[i];
      if (c == '@') {
        if (i > 0 && !_isSpace(t[i - 1])) return null;
        if (_ranges.any((r) => i >= r.start && i < r.end)) return null;
        return (start: i, query: t.substring(i + 1, cursor));
      }
      if (_isSpace(c)) return null;
    }
    return null;
  }

  static bool _isSpace(String c) => c.trim().isEmpty;

  /// Replaces the "@query" at the cursor (or inserts at the cursor) with
  /// [mention], followed by a space.
  void insertMention(Mention mention) {
    final t = text;
    final sel = selection;
    final cursor = sel.isValid ? math.min(sel.baseOffset, t.length) : t.length;
    final start = mentionQuery?.start ?? cursor;
    final shown = mention.display;
    final rest = t.substring(cursor);
    final insert = rest.startsWith(' ') ? shown : '$shown ';
    final delta = insert.length - (cursor - start);
    for (final r in _ranges) {
      if (r.start >= cursor) {
        r.start += delta;
        r.end += delta;
      }
    }
    _ranges
      ..add(_Range(start, start + shown.length, mention))
      ..sort((x, y) => x.start.compareTo(y.start));
    final caret = start + insert.length + (rest.startsWith(' ') ? 1 : 0);
    super.value = TextEditingValue(
      text: t.substring(0, start) + insert + rest,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (_ranges.isEmpty) return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    final linkStyle = mentionLinkStyle(context, style);
    final t = text;
    final children = <TextSpan>[];
    var last = 0;
    for (final r in _ranges) {
      if (r.start < last || r.end > t.length) continue;
      if (r.start > last) children.add(TextSpan(text: t.substring(last, r.start)));
      children.add(TextSpan(text: t.substring(r.start, r.end), style: linkStyle));
      last = r.end;
    }
    if (last < t.length) children.add(TextSpan(text: t.substring(last)));
    return TextSpan(style: style, children: children);
  }
}

/// How a mention looks: [base] in the primary color, semi-bold.
TextStyle mentionLinkStyle(BuildContext context, TextStyle? base) =>
    (base ?? const TextStyle()).copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600);

// ── Autocomplete ──────────────────────────────────────────────────────────────

/// Finds suggestions for a query (defaults to GET /posts/mention-search).
typedef MentionSearch = Future<List<MentionSuggestion>> Function(String query);

/// Wraps a text field using [controller]: while an "@query" is being typed
/// it shows matching people, gyms/shops and products in a dropdown (above
/// the field when there's room, else below); picking one inserts it.
class MentionAutocomplete extends StatefulWidget {
  const MentionAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.child,
    this.kinds = const {MentionKind.user, MentionKind.business, MentionKind.shopItem},
    this.search,
    this.maxHeight = 280,
  });

  final MentionTextEditingController controller;
  final FocusNode focusNode;

  /// The text field.
  final Widget child;
  final Set<MentionKind> kinds;
  final MentionSearch? search;
  final double maxHeight;

  @override
  State<MentionAutocomplete> createState() => _MentionAutocompleteState();
}

class _MentionAutocompleteState extends State<MentionAutocomplete> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  Timer? _debounce;
  String? _query;
  int _seq = 0;
  List<MentionSuggestion> _results = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.focusNode.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(MentionAutocomplete old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onChanged);
      widget.focusNode.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    widget.focusNode.removeListener(_onChanged);
    super.dispose();
  }

  Future<List<MentionSuggestion>> _search(String q) async {
    if (widget.search != null) return widget.search!(q);
    final token = await AuthManager.instance.getValidToken();
    return ApiService().searchMentions(token, q, kinds: widget.kinds);
  }

  void _onChanged() {
    final q = widget.focusNode.hasFocus ? widget.controller.mentionQuery?.query : null;
    if (q == _query) return;
    _query = q;
    _debounce?.cancel();
    if (q == null) {
      _seq++;
      _hide();
      return;
    }
    final seq = ++_seq;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (mounted) setState(() => _loading = true);
      try {
        final results = await _search(q);
        if (!mounted || seq != _seq) return;
        setState(() {
          _results = results;
          _loading = false;
        });
        results.isEmpty ? _hide() : _show();
      } catch (_) {
        // Suggestions are a convenience; typing goes on.
        if (!mounted || seq != _seq) return;
        setState(() => _loading = false);
        _hide();
      }
    });
  }

  void _show() {
    if (!_portal.isShowing) _portal.show();
  }

  void _hide() {
    if (_portal.isShowing) _portal.hide();
  }

  void _pick(MentionSuggestion s) {
    _seq++;
    _query = null;
    _hide();
    widget.controller.insertMention(s.mention);
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildDropdown,
      child: CompositedTransformTarget(link: _link, child: widget.child),
    );
  }

  Widget _buildDropdown(BuildContext overlayContext) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return const SizedBox.shrink();
    final mq = MediaQuery.of(overlayContext);
    final topLeft = box.localToGlobal(Offset.zero);
    final spaceAbove = topLeft.dy - mq.padding.top - 8;
    final spaceBelow = mq.size.height - mq.viewInsets.bottom - topLeft.dy - box.size.height - 8;
    final above = spaceAbove >= math.min(widget.maxHeight, 160) || spaceAbove >= spaceBelow;
    final height = math.max(56.0, math.min(widget.maxHeight, above ? spaceAbove : spaceBelow));
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      left: 0,
      top: 0,
      width: box.size.width,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: above ? Alignment.topLeft : Alignment.bottomLeft,
        followerAnchor: above ? Alignment.bottomLeft : Alignment.topLeft,
        offset: Offset(0, above ? -4 : 4),
        child: TextFieldTapRegion(
          child: Material(
            elevation: 6,
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                reverse: above,
                children: [
                  for (final s in _results) MentionSuggestionTile(suggestion: s, onTap: () => _pick(s)),
                  if (_loading) const LinearProgressIndicator(minHeight: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One suggestion: avatar / logo / product photo, name and a subtitle.
class MentionSuggestionTile extends StatelessWidget {
  const MentionSuggestionTile({super.key, required this.suggestion, required this.onTap});

  final MentionSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final s = suggestion;
    final kindLabel = switch (s.kind) {
      MentionKind.user => null,
      MentionKind.business => s.businessType == 'shop' ? l10n.tagsKindShop : l10n.tagsKindGym,
      MentionKind.shopItem => l10n.tagsKindProduct,
    };
    final subtitle = [?kindLabel, if (s.subtitle?.isNotEmpty == true) s.subtitle!].join(' · ');
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: MentionThumb(suggestion: s),
      title: Text(
        s.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
    );
  }
}

/// A person's avatar (round) or a business logo / product photo (rounded
/// square), with an icon when there's no picture.
class MentionThumb extends StatelessWidget {
  const MentionThumb({super.key, required this.suggestion, this.size = 36});

  final MentionSuggestion suggestion;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    final cs = Theme.of(context).colorScheme;
    if (s.kind == MentionKind.user) {
      final parts = s.label.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
      return UserAvatar(
        url: s.imageUrl,
        initials: parts.isEmpty ? '?' : parts.map((p) => p[0].toUpperCase()).join(),
        radius: size / 2,
      );
    }
    final icon = Icon(
      switch (s.kind) {
        MentionKind.shopItem => Icons.shopping_bag_outlined,
        _ => s.businessType == 'shop' ? Icons.storefront_outlined : Icons.fitness_center,
      },
      size: size * 0.55,
      color: cs.onSecondaryContainer,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: cs.secondaryContainer,
        alignment: Alignment.center,
        child: s.imageUrl == null || s.imageUrl!.isEmpty
            ? icon
            : Image.network(s.imageUrl!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => icon),
      ),
    );
  }
}

// ── Rendering ─────────────────────────────────────────────────────────────────

/// Stored text with its mentions shown as tappable "@Name" (tap → profile,
/// gym/shop or product, see [openMention]).
class MentionText extends StatefulWidget {
  const MentionText(this.text, {super.key, this.style, this.maxLines, this.overflow, this.textAlign});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  List<MentionSegment> _segments = const [];
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(MentionText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _parse();
  }

  void _parse() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    _segments = parseMentions(widget.text);
    for (final s in _segments) {
      if (s.mention != null) {
        _recognizers.add(TapGestureRecognizer()..onTap = () => openMention(context, s.mention!));
      }
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    if (_recognizers.isEmpty) {
      return Text(
        widget.text,
        style: style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        textAlign: widget.textAlign,
      );
    }
    final link = mentionLinkStyle(context, style);
    var i = 0;
    return Text.rich(
      TextSpan(
        children: [
          for (final s in _segments)
            s.mention == null
                ? TextSpan(text: s.text)
                : TextSpan(text: s.text, style: link, recognizer: _recognizers[i++], semanticsLabel: s.text),
        ],
      ),
      style: style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}

/// Opens what [mention] points at: a person's profile, a gym's feed or a
/// shop's storefront, or a product in its shop.
Future<void> openMention(BuildContext context, Mention mention) async {
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  Future<void> push(Widget page) => nav.push<void>(MaterialPageRoute(builder: (_) => page));
  if (mention.kind == MentionKind.user) return push(UserProfilePage(userId: mention.id));
  final api = ApiService();
  try {
    final token = await AuthManager.instance.getValidToken();
    if (mention.kind == MentionKind.business) {
      final b = await api.getBusiness(token, mention.id);
      await push(
        b.type == 'shop'
            ? StorefrontShopPage(shopId: b.id, shopName: b.name)
            : PostsPage(businessId: b.id, businessName: b.name),
      );
      return;
    }
    final item = await api.getShopItem(token, mention.id);
    final shop = await api.getBusiness(token, item.shopId);
    await push(StorefrontShopPage(shopId: shop.id, shopName: shop.name, initialItemId: item.id));
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(l10n.tagsOpenFailed(mention.label))));
  }
}
