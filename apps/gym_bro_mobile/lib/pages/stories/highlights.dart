import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/mention.dart';
import '../../models/story.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/social_widgets.dart';
import '../../widgets/video_frame_thumb.dart';
import 'story_thumb.dart';
import 'story_viewer_page.dart';

// Story highlights, Instagram-style: named collections of my stories kept on
// my profile after they expire (API: /stories/highlights).
//
// * [HighlightsRow] — the circles on a profile; mine also get "New", and a
//   long-press to edit or delete.
// * [openHighlight] — plays one in the story viewer.
// * [showAddToHighlightSheet] — adds a story of mine to a highlight (or a
//   new one), from the viewer and the archive.
// * [createHighlightFlow] — picks stories from my archive, names them, creates.

/// Bumped whenever a highlight is created, changed or deleted here, so every
/// [HighlightsRow] on screen reloads.
final highlightsRevision = ValueNotifier<int>(0);

void _changed() => highlightsRevision.value++;

String _errText(Object e) => e.toString().replaceFirst('Exception: ', '');

void _snack(ScaffoldMessengerState? messenger, String text) =>
    messenger?.showSnackBar(SnackBar(content: Text(text)));

/// Loads [highlight] and plays it. Expired stories in it are watch-only.
Future<void> openHighlight(BuildContext context, StoryHighlight highlight) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  StoryHighlightDetail detail;
  try {
    final token = await AuthManager.instance.getValidToken();
    detail = await ApiService().getHighlight(token, highlight.id);
  } catch (_) {
    _snack(messenger, l10n.storyUnavailable);
    return;
  }
  if (detail.stories.isEmpty) return _snack(messenger, l10n.storyUnavailable);
  if (context.mounted) await openStoryList(context, detail.stories, title: detail.title);
}

/// Asks for a highlight's name (1–30 characters); null when cancelled.
Future<String?> askHighlightTitle(BuildContext context, {String initial = ''}) => showDialog<String>(
  context: context,
  builder: (_) => _TitleDialog(initial: initial),
);

class _TitleDialog extends StatefulWidget {
  const _TitleDialog({required this.initial});

  final String initial;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _done() {
    if (_text.text.trim().isNotEmpty) Navigator.pop(context, _text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.initial.isEmpty ? l10n.storyHighlightNewTitle : l10n.storyHighlightRename),
      content: TextField(
        key: const ValueKey('highlight-title'),
        controller: _text,
        autofocus: true,
        maxLength: 30,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l10n.storyHighlightNameLabel),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: _text.text.trim().isEmpty ? null : _done, child: Text(l10n.commonSave)),
      ],
    );
  }
}

/// Picks stories from my archive ([initial] preselected), asks for a name and
/// creates the highlight. Returns it, or null when cancelled / failed.
Future<StoryHighlight?> createHighlightFlow(BuildContext context, {List<Story> initial = const []}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  final stories = await Navigator.of(context).push<List<Story>>(MaterialPageRoute(
    builder: (_) => HighlightStoryPickerPage(initial: initial),
  ));
  if (stories == null || stories.isEmpty || !context.mounted) return null;
  final title = await askHighlightTitle(context);
  if (title == null) return null;
  try {
    final token = await AuthManager.instance.getValidToken();
    final created = await ApiService().createHighlight(token, title, [for (final s in stories) s.id]);
    _changed();
    _snack(messenger, l10n.storyHighlightCreated(created.title));
    return created;
  } catch (e) {
    _snack(messenger, _errText(e));
    return null;
  }
}

/// Adds my [story] to one of my highlights, or a new one. True when added.
Future<bool> showAddToHighlightSheet(BuildContext context, Story story) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  final pick = await showAppBottomSheet<_HighlightPick>(
    context: context,
    showDragHandle: true,
    builder: (_) => _AddToHighlightSheet(userId: story.authorId),
  );
  if (pick == null || !context.mounted) return false;
  final api = ApiService();
  try {
    final into = pick.highlight;
    if (into == null) {
      final title = await askHighlightTitle(context);
      if (title == null) return false;
      final created = await api.createHighlight(await AuthManager.instance.getValidToken(), title, [story.id]);
      _snack(messenger, l10n.storyHighlightAddedTo(created.title));
    } else {
      final updated = await api.updateHighlight(await AuthManager.instance.getValidToken(), into.id, addStoryIds: [story.id]);
      _snack(messenger, l10n.storyHighlightAddedTo(updated.title));
    }
    _changed();
    return true;
  } catch (e) {
    _snack(messenger, _errText(e));
    return false;
  }
}

/// The sheet's answer: an existing highlight, or a new one (null).
class _HighlightPick {
  const _HighlightPick(this.highlight);

  final StoryHighlight? highlight;
}

class _AddToHighlightSheet extends StatefulWidget {
  const _AddToHighlightSheet({required this.userId});

  final String userId;

  @override
  State<_AddToHighlightSheet> createState() => _AddToHighlightSheetState();
}

class _AddToHighlightSheetState extends State<_AddToHighlightSheet> {
  late final Future<List<StoryHighlight>> _highlights =
      AuthManager.instance.getValidToken().then((t) => ApiService().getHighlights(t, widget.userId));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(l10n.storyHighlightAddTo, style: Theme.of(context).textTheme.titleMedium),
      ),
      SizedBox(
        height: 112,
        child: FutureBuilder<List<StoryHighlight>>(
          future: _highlights,
          builder: (context, snap) {
            final list = snap.data ?? const <StoryHighlight>[];
            return ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                HighlightBubble(
                  key: const ValueKey('highlight-new'),
                  label: l10n.storyHighlightNew,
                  onTap: () => Navigator.pop(context, const _HighlightPick(null)),
                  child: const _NewCircleIcon(),
                ),
                if (snap.connectionState != ConnectionState.done)
                  const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
                else if (snap.hasError)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: Text(_errText(snap.error!), maxLines: 3)),
                  ),
                for (final h in list)
                  HighlightBubble(
                    label: h.title,
                    onTap: () => Navigator.pop(context, _HighlightPick(h)),
                    child: HighlightCoverImage(cover: h.cover),
                  ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 12),
    ]);
  }
}

// ── The row on a profile ──────────────────────────────────────────────────────

/// [userId]'s highlights as circles under their profile header; tap one to
/// watch it. For me ([isMe]) a "New" circle comes first and a long-press
/// edits or deletes one. Shows nothing when someone else has none. Reload
/// with [HighlightsRowState.refresh] (e.g. via a GlobalKey on pull-to-refresh);
/// changes made in the app reload it by themselves.
class HighlightsRow extends StatefulWidget {
  const HighlightsRow({super.key, required this.userId, required this.isMe});

  final String userId;
  final bool isMe;

  @override
  State<HighlightsRow> createState() => HighlightsRowState();
}

class HighlightsRowState extends State<HighlightsRow> {
  final _api = ApiService();
  List<StoryHighlight>? _highlights;

  @override
  void initState() {
    super.initState();
    highlightsRevision.addListener(refresh);
    refresh();
  }

  @override
  void didUpdateWidget(HighlightsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _highlights = null;
      refresh();
    }
  }

  @override
  void dispose() {
    highlightsRevision.removeListener(refresh);
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final list = await _api.getHighlights(token, widget.userId);
      if (mounted) setState(() => _highlights = list);
    } catch (_) {
      // A nicety on the profile: keep what's shown.
      if (mounted && _highlights == null) setState(() => _highlights = const []);
    }
  }

  Future<void> _create() => createHighlightFlow(context);

  Future<void> _open(StoryHighlight h) async {
    await openHighlight(context, h);
    // Stories may have been deleted from the viewer.
    if (mounted) refresh();
  }

  Future<void> _manage(StoryHighlight h) async {
    final l10n = context.l10n;
    final action = await showAppBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: Text(l10n.storyHighlightEdit),
          onTap: () => Navigator.pop(ctx, 'edit'),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: Text(l10n.storyHighlightDelete),
          onTap: () => Navigator.pop(ctx, 'delete'),
        ),
      ]),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => HighlightEditorPage(highlightId: h.id)));
    } else if (action == 'delete') {
      await confirmDeleteHighlight(context, h.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = _highlights ?? const <StoryHighlight>[];
    if (!widget.isMe && list.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          if (widget.isMe)
            HighlightBubble(
              key: const ValueKey('highlight-new'),
              label: l10n.storyHighlightNew,
              semanticLabel: l10n.storyHighlightNewTitle,
              onTap: _create,
              child: const _NewCircleIcon(),
            ),
          for (final h in list)
            HighlightBubble(
              key: ValueKey('highlight-${h.id}'),
              label: h.title,
              onTap: () => _open(h),
              onLongPress: widget.isMe ? () => _manage(h) : null,
              child: HighlightCoverImage(cover: h.cover),
            ),
        ],
      ),
    );
  }
}

/// Asks, then deletes a highlight of mine. True when deleted.
Future<bool> confirmDeleteHighlight(BuildContext context, String highlightId) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.storyHighlightDeleteTitle),
      content: Text(l10n.storyHighlightDeleteBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.commonDelete)),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await ApiService().deleteHighlight(await AuthManager.instance.getValidToken(), highlightId);
  } catch (e) {
    _snack(messenger, _errText(e));
    return false;
  }
  _changed();
  _snack(messenger, l10n.storyHighlightDeleted);
  return true;
}

/// A circle with a label under it (a highlight, or "New").
class HighlightBubble extends StatelessWidget {
  const HighlightBubble({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.size = 64,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: size + 16,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(children: [
              Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cs.outlineVariant, width: 1.5)),
                child: ClipOval(child: child),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NewCircleIcon extends StatelessWidget {
  const _NewCircleIcon();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(color: cs.surfaceContainerHighest, child: Center(child: Icon(Icons.add, color: cs.onSurface, size: 28)));
  }
}

/// A highlight's cover filling its circle: the photo, a frame of the video,
/// or the story's colour with its first words.
class HighlightCoverImage extends StatelessWidget {
  const HighlightCoverImage({super.key, required this.cover});

  final HighlightCover? cover;

  @override
  Widget build(BuildContext context) {
    final c = cover;
    if (c != null && c.hasMedia && !c.isVideo) return MediaImage(url: c.mediaUrl!);
    if (c != null && c.isVideo) return VideoFrameThumb(url: c.mediaUrl);
    return Container(
      color: c?.backgroundColor ?? const Color(0xFF2B2D42),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        mentionPlainText(c?.caption ?? ''),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Picking stories from the archive ──────────────────────────────────────────

/// My archive (newest first) as a grid to pick stories from, in the order
/// tapped. [exclude] are left out (already in the highlight). Returns the
/// picked stories, or null when backed out.
class HighlightStoryPickerPage extends StatefulWidget {
  const HighlightStoryPickerPage({super.key, this.initial = const [], this.exclude = const {}});

  final List<Story> initial;
  final Set<String> exclude;

  @override
  State<HighlightStoryPickerPage> createState() => _HighlightStoryPickerPageState();
}

class _HighlightStoryPickerPageState extends State<HighlightStoryPickerPage> {
  late final List<Story> _picked = List.of(widget.initial);
  List<Story>? _stories;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final token = await AuthManager.instance.getValidToken();
      final stories = await ApiService().getStoryArchive(token);
      if (mounted) setState(() => _stories = stories.where((s) => !widget.exclude.contains(s.id)).toList());
    } catch (e) {
      if (mounted) setState(() => _error = _errText(e));
    }
  }

  void _toggle(Story s) => setState(() {
    final i = _picked.indexWhere((p) => p.id == s.id);
    i < 0 ? _picked.add(s) : _picked.removeAt(i);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final stories = _stories;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storyHighlightPickTitle),
        actions: [
          TextButton(
            key: const ValueKey('highlight-pick-done'),
            onPressed: _picked.isEmpty ? null : () => Navigator.pop(context, _picked),
            child: Text(l10n.storyHighlightNext),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: Text(l10n.commonRetry)),
              ]),
            )
          : stories == null
          ? const Center(child: CircularProgressIndicator())
          : stories.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.storyHighlightNoArchive, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 9 / 16,
              ),
              itemCount: stories.length,
              itemBuilder: (context, i) {
                final s = stories[i];
                final order = _picked.indexWhere((p) => p.id == s.id);
                return _PickTile(story: s, order: order < 0 ? null : order + 1, onTap: () => _toggle(s));
              },
            ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.story, required this.order, required this.onTap});

  final Story story;

  /// 1-based position among the picked ones; null when not picked.
  final int? order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = MaterialLocalizations.of(context).formatShortMonthDay(story.createdAt);
    return Semantics(
      button: true,
      selected: order != null,
      label: date,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('highlight-pick-${story.id}'),
        onTap: onTap,
        child: Stack(fit: StackFit.expand, children: [
          StoryThumb(story: story),
          if (order != null) ColoredBox(color: Colors.white.withValues(alpha: 0.25)),
          Positioned(
            left: 6,
            bottom: 5,
            child: Text(
              date,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black87, blurRadius: 4)]),
            ),
          ),
          if (story.closeFriends) const Positioned(left: 5, top: 5, child: CloseFriendsStar(size: 12)),
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: order != null ? cs.primary : Colors.black26,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: order == null
                  ? null
                  : Text('$order', style: TextStyle(color: cs.onPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Editing ───────────────────────────────────────────────────────────────────

/// Edits a highlight of mine: its name, its cover (tap a story), which
/// stories it keeps (the check on each), adding more from the archive, or
/// deleting it.
class HighlightEditorPage extends StatefulWidget {
  const HighlightEditorPage({super.key, required this.highlightId});

  final String highlightId;

  @override
  State<HighlightEditorPage> createState() => _HighlightEditorPageState();
}

class _HighlightEditorPageState extends State<HighlightEditorPage> {
  final _api = ApiService();
  final _title = TextEditingController();
  StoryHighlightDetail? _detail;
  String? _error;
  bool _saving = false;

  /// Shown in order: the highlight's stories, then the ones being added.
  List<Story> _stories = [];
  final Set<String> _removed = {};
  final List<String> _added = [];
  String? _cover;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final detail = await _api.getHighlight(await AuthManager.instance.getValidToken(), widget.highlightId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _title.text = detail.title;
        _stories = List.of(detail.stories);
        _cover = detail.highlight.coverStoryId;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _errText(e));
    }
  }

  String? get _shownCover {
    if (_cover != null && !_removed.contains(_cover)) return _cover;
    // The server's default: the newest story kept.
    final kept = _stories.where((s) => !_removed.contains(s.id)).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return kept.firstOrNull?.id;
  }

  Future<void> _addStories() async {
    final picked = await Navigator.of(context).push<List<Story>>(MaterialPageRoute(
      builder: (_) => HighlightStoryPickerPage(exclude: {for (final s in _stories) s.id}),
    ));
    if (picked == null || !mounted) return;
    setState(() {
      for (final s in picked) {
        _stories.add(s);
        _added.add(s.id);
      }
    });
  }

  void _toggleKeep(Story s) => setState(() => _removed.contains(s.id) ? _removed.remove(s.id) : _removed.add(s.id));

  Future<void> _save() async {
    final detail = _detail;
    if (detail == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final title = _title.text.trim();
    if (title.isEmpty) return;
    if (_stories.every((s) => _removed.contains(s.id))) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.storyHighlightNeedsStory)));
      return;
    }
    final cover = _cover != null && _removed.contains(_cover) ? null : _cover;
    final added = _added.where((id) => !_removed.contains(id)).toList();
    final removed = _removed.where((id) => !_added.contains(id)).toList();
    setState(() => _saving = true);
    try {
      await _api.updateHighlight(
        await AuthManager.instance.getValidToken(),
        detail.id,
        title: title == detail.title ? null : title,
        addStoryIds: added.isEmpty ? null : added,
        removeStoryIds: removed.isEmpty ? null : removed,
        coverStoryId: cover != detail.highlight.coverStoryId ? cover : null,
        clearCover: cover == null && detail.highlight.coverStoryId != null,
      );
      _changed();
      messenger.showSnackBar(SnackBar(content: Text(l10n.storyHighlightSaved)));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_errText(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (await confirmDeleteHighlight(context, widget.highlightId) && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final detail = _detail;
    final cover = _shownCover;
    final coverStory = _stories.where((s) => s.id == cover).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storyHighlightEdit),
        actions: [
          IconButton(tooltip: l10n.storyHighlightDelete, icon: const Icon(Icons.delete_outline), onPressed: _saving ? null : _delete),
          TextButton(
            key: const ValueKey('highlight-save'),
            onPressed: detail == null || _saving || _title.text.trim().isEmpty ? null : _save,
            child: Text(l10n.commonSave),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: Text(l10n.commonRetry)),
              ]),
            )
          : detail == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(children: [
                    if (_saving) const LinearProgressIndicator(minHeight: 2),
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cs.outlineVariant, width: 1.5)),
                        child: ClipOval(child: coverStory == null ? const SizedBox.shrink() : StoryThumb(story: coverStory)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('highlight-title'),
                      controller: _title,
                      maxLength: 30,
                      enabled: !_saving,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(labelText: l10n.storyHighlightNameLabel),
                    ),
                    Row(children: [
                      Expanded(child: Text(l10n.storyHighlightStories, style: tt.titleSmall)),
                      TextButton.icon(
                        onPressed: _saving ? null : _addStories,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.storyHighlightAddStories),
                      ),
                    ]),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(l10n.storyHighlightCoverHint, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    childAspectRatio: 9 / 16,
                  ),
                  itemCount: _stories.length,
                  itemBuilder: (context, i) {
                    final s = _stories[i];
                    final kept = !_removed.contains(s.id);
                    return _EditTile(
                      story: s,
                      kept: kept,
                      isCover: s.id == cover,
                      onTap: kept && !_saving ? () => setState(() => _cover = s.id) : null,
                      onToggle: _saving ? null : () => _toggleKeep(s),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ]),
    );
  }
}

class _EditTile extends StatelessWidget {
  const _EditTile({required this.story, required this.kept, required this.isCover, this.onTap, this.onToggle});

  final Story story;
  final bool kept;
  final bool isCover;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      key: ValueKey('highlight-edit-${story.id}'),
      onTap: onTap,
      child: Stack(fit: StackFit.expand, children: [
        Opacity(opacity: kept ? 1 : 0.35, child: StoryThumb(story: story)),
        if (isCover)
          DecoratedBox(decoration: BoxDecoration(border: Border.all(color: cs.primary, width: 3))),
        if (isCover)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(8)),
              child: Text(l10n.storyHighlightCover, style: TextStyle(color: cs.onPrimary, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            tooltip: kept ? l10n.storyHighlightRemoveStory : l10n.storyHighlightKeepStory,
            onPressed: onToggle,
            icon: Icon(
              kept ? Icons.check_circle : Icons.radio_button_unchecked,
              color: kept ? cs.primary : Colors.white,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ),
      ]),
    );
  }
}
