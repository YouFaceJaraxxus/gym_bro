import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/mention.dart';
import '../models/post.dart';
import '../pages/people/user_profile_page.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'mentions.dart';
import 'app_bottom_sheet.dart';

// People pinned on photos (Instagram-style). A pin's x, y are 0–1 of the
// whole photo, so wherever the photo is shown (cropped to fill a feed card,
// letterboxed in the editor) the pin maps through [fittedImageRect].

/// Max people per photo (server limit).
const kMaxPhotoTags = 20;

/// Where an image of [aspectRatio] (w/h) lands inside [box] when drawn with
/// [fit] (cover or contain), centered. Unknown ratio = fills the box.
Rect fittedImageRect(Size box, double? aspectRatio, {BoxFit fit = BoxFit.cover}) {
  if (aspectRatio == null || aspectRatio <= 0 || box.isEmpty) return Offset.zero & box;
  final boxRatio = box.width / box.height;
  final widthBound = fit == BoxFit.cover ? aspectRatio < boxRatio : aspectRatio > boxRatio;
  final size = widthBound ? Size(box.width, box.width / aspectRatio) : Size(box.height * aspectRatio, box.height);
  return Offset((box.width - size.width) / 2, (box.height - size.height) / 2) & size;
}

// ── Showing tags ──────────────────────────────────────────────────────────────

/// Over a photo: the "tagged people" icon at the bottom left and, while
/// [showLabels], a name label at each pin (tap → their profile). The photo
/// fills the box with [fit] and has [aspectRatio].
class PhotoTagsOverlay extends StatelessWidget {
  const PhotoTagsOverlay({
    super.key,
    required this.tags,
    required this.showLabels,
    this.aspectRatio,
    this.fit = BoxFit.cover,
    this.onIconTap,
  });

  final List<PhotoTag> tags;
  final bool showLabels;
  final double? aspectRatio;
  final BoxFit fit;
  final VoidCallback? onIconTap;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        final rect = fittedImageRect(box, aspectRatio, fit: fit);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (showLabels)
              for (final t in tags)
                _PinnedLabel(
                  box: box,
                  at: Offset(rect.left + t.x * rect.width, rect.top + t.y * rect.height),
                  child: TagLabel(
                    text: t.handle,
                    onTap: () => Navigator.of(
                      context,
                    ).push<void>(MaterialPageRoute(builder: (_) => UserProfilePage(userId: t.userId))),
                  ),
                ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Semantics(
                button: onIconTap != null,
                label: l10n.tagsTaggedPeople(tags.length),
                child: GestureDetector(
                  onTap: onIconTap,
                  child: const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.person, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A dark name bubble with a little arrow on top pointing at the pin.
class TagLabel extends StatelessWidget {
  const TagLabel({super.key, required this.text, this.onTap, this.trailing});

  final String text;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(size: const Size(12, 6), painter: _ArrowPainter()),
          Container(
            constraints: const BoxConstraints(maxWidth: 180),
            padding: EdgeInsets.fromLTRB(10, 6, trailing == null ? 10 : 4, 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.78));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Places [child] (a [TagLabel]) with its arrow tip at [at], kept inside
/// [box] horizontally.
class _PinnedLabel extends StatelessWidget {
  const _PinnedLabel({required this.box, required this.at, required this.child});

  final Size box;
  final Offset at;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (at.dx < 0 || at.dy < 0 || at.dx > box.width || at.dy > box.height) return const SizedBox.shrink();
    return Positioned.fill(
      child: CustomSingleChildLayout(delegate: _PinLayout(at), child: child),
    );
  }
}

class _PinLayout extends SingleChildLayoutDelegate {
  _PinLayout(this.at);

  final Offset at;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (at.dx - childSize.width / 2).clamp(
      4.0,
      (size.width - childSize.width - 4).clamp(4.0, double.infinity),
    );
    final top = at.dy.clamp(0.0, (size.height - childSize.height).clamp(0.0, double.infinity));
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_PinLayout old) => old.at != at;
}

// ── Editing tags ──────────────────────────────────────────────────────────────

/// One photo in [PhotoTagEditorPage].
class TagEditorPhoto {
  const TagEditorPhoto({required this.image, required this.provider, this.aspectRatio, this.tags = const []});

  /// Draws the whole photo filling its box (the box has the photo's ratio).
  final Widget image;

  /// Used to find the ratio when [aspectRatio] is unknown.
  final ImageProvider provider;
  final double? aspectRatio;
  final List<PhotoTag> tags;
}

/// Tag people on photos: tap a photo to drop a pin and pick a person, drag a
/// pin to move it, × to remove. Swipe between photos. Pops with the tags of
/// every photo (same order) on "Done", null when cancelled.
class PhotoTagEditorPage extends StatefulWidget {
  const PhotoTagEditorPage({super.key, required this.photos, this.initialIndex = 0, this.search});

  final List<TagEditorPhoto> photos;
  final int initialIndex;

  /// People search (defaults to GET /posts/mention-search?kinds=user).
  final MentionSearch? search;

  static Future<List<List<PhotoTag>>?> open(
    BuildContext context,
    List<TagEditorPhoto> photos, {
    int initialIndex = 0,
  }) => Navigator.of(context).push<List<List<PhotoTag>>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoTagEditorPage(photos: photos, initialIndex: initialIndex),
    ),
  );

  @override
  State<PhotoTagEditorPage> createState() => _PhotoTagEditorPageState();
}

class _PhotoTagEditorPageState extends State<PhotoTagEditorPage> {
  late final List<List<PhotoTag>> _tags = [
    for (final p in widget.photos) [...p.tags],
  ];
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _page = widget.initialIndex;
  bool _dragging = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _addAt(Offset relative) async {
    final tags = _tags[_page];
    final l10n = context.l10n;
    if (tags.length >= kMaxPhotoTags) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.tagsLimit(kMaxPhotoTags))));
      return;
    }
    final person = await showPersonPicker(context, search: widget.search);
    if (person == null || !mounted) return;
    setState(() {
      final x = relative.dx.clamp(0.0, 1.0), y = relative.dy.clamp(0.0, 1.0);
      final i = tags.indexWhere((t) => t.userId == person.id);
      // Tagging someone again just moves their pin.
      if (i >= 0) {
        tags[i] = tags[i].moved(x, y);
      } else {
        tags.add(PhotoTag(userId: person.id, username: person.username ?? '', name: person.label, x: x, y: y));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = _tags[_page];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.photos.length > 1 ? l10n.tagsTitleOf(_page + 1, widget.photos.length) : l10n.tagsTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _tags),
            child: Text(
              l10n.tagsDone,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              physics: _dragging ? const NeverScrollableScrollPhysics() : null,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _EditablePhoto(
                photo: widget.photos[i],
                tags: _tags[i],
                onTapAt: _addAt,
                onDragging: (v) => setState(() => _dragging = v),
                onMoved: (j, x, y) => setState(() => _tags[i][j] = _tags[i][j].moved(x, y)),
                onRemove: (j) => setState(() => _tags[i].removeAt(j)),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    current.isEmpty ? l10n.tagsTapToTag : l10n.tagsDragHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (current.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final (j, t) in current.indexed)
                          InputChip(
                            label: Text(t.displayName),
                            onDeleted: () => setState(() => current.removeAt(j)),
                            deleteButtonTooltipMessage: l10n.tagsRemovePerson(t.displayName),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditablePhoto extends StatefulWidget {
  const _EditablePhoto({
    required this.photo,
    required this.tags,
    required this.onTapAt,
    required this.onDragging,
    required this.onMoved,
    required this.onRemove,
  });

  final TagEditorPhoto photo;
  final List<PhotoTag> tags;
  final ValueChanged<Offset> onTapAt;
  final ValueChanged<bool> onDragging;
  final void Function(int index, double x, double y) onMoved;
  final ValueChanged<int> onRemove;

  @override
  State<_EditablePhoto> createState() => _EditablePhotoState();
}

class _EditablePhotoState extends State<_EditablePhoto> {
  late double? _aspect = widget.photo.aspectRatio;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_aspect == null && _stream == null) {
      _stream = widget.photo.provider.resolve(createLocalImageConfiguration(context));
      _listener = ImageStreamListener(
        (info, _) {
          if (mounted) setState(() => _aspect = info.image.width / info.image.height);
        },
        onError: (_, _) {
          if (mounted) setState(() => _aspect = 1);
        },
      );
      _stream!.addListener(_listener!);
    }
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _aspect;
    if (aspect == null) return const Center(child: CircularProgressIndicator());
    final l10n = context.l10n;
    return Center(
      child: AspectRatio(
        aspectRatio: aspect,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => widget.onTapAt(Offset(d.localPosition.dx / size.width, d.localPosition.dy / size.height)),
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  widget.photo.image,
                  for (final (j, t) in widget.tags.indexed)
                    _PinnedLabel(
                      box: size,
                      at: Offset(t.x * size.width, t.y * size.height),
                      child: GestureDetector(
                        onPanStart: (_) => widget.onDragging(true),
                        onPanUpdate: (d) =>
                            widget.onMoved(j, t.x + d.delta.dx / size.width, t.y + d.delta.dy / size.height),
                        onPanEnd: (_) => widget.onDragging(false),
                        onPanCancel: () => widget.onDragging(false),
                        child: TagLabel(
                          text: t.handle,
                          trailing: Semantics(
                            button: true,
                            label: l10n.tagsRemovePerson(t.displayName),
                            child: GestureDetector(
                              onTap: () => widget.onRemove(j),
                              child: const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.close, size: 16, color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A bottom sheet to search for a person (mention search, people only).
Future<MentionSuggestion?> showPersonPicker(BuildContext context, {MentionSearch? search}) =>
    showAppBottomSheet<MentionSuggestion>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _PersonPickerSheet(search: search),
    );

class _PersonPickerSheet extends StatefulWidget {
  const _PersonPickerSheet({this.search});

  final MentionSearch? search;

  @override
  State<_PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends State<_PersonPickerSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  int _seq = 0;
  List<MentionSuggestion> _results = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(q.trim()));
  }

  Future<void> _run(String q) async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<MentionSuggestion> results;
      if (widget.search != null) {
        results = await widget.search!(q);
      } else {
        final token = await AuthManager.instance.getValidToken();
        results = await ApiService().searchMentions(token, q, kinds: const {MentionKind.user});
      }
      if (!mounted || seq != _seq) return;
      setState(() {
        _results = results.where((r) => r.kind == MentionKind.user).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: l10n.tagsSearchPeople,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                  isDense: true,
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Text(_error!, style: TextStyle(color: cs.error)),
                    )
                  : _results.isEmpty && !_loading
                  ? Center(
                      child: Text(l10n.tagsNoPeople, style: TextStyle(color: cs.onSurfaceVariant)),
                    )
                  : ListView(
                      children: [
                        for (final s in _results)
                          MentionSuggestionTile(suggestion: s, onTap: () => Navigator.pop(context, s)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
