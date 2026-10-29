import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../l10n/l10n.dart';
import '../../media_editor/edited_media_view.dart';
import '../../media_editor/editable_media.dart';
import '../../media_editor/media_edit.dart';
import '../../media_editor/media_editor_page.dart';
import '../../models/draft.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/media_upload.dart';
import '../../widgets/drafts.dart';
import '../../widgets/post_card.dart';
import '../../widgets/social_widgets.dart';

/// Server limit for photos/videos per post.
const kMaxPostMedia = 10;

class _Item {
  _Item(this.media);

  final EditableMedia media;
  Key get key => media.key;
  double progress = 0;

  /// Storage path of the published (edited) file once uploaded, and the
  /// edits it was made with — a retry skips it unless they changed since.
  String? publishedPath;
  MediaEdit? publishedEdit;

  bool get isVideo => media.isVideo;
}

/// Compose a personal post: up to ten photos/videos (reorderable, each
/// editable — or all at once), caption and visibility. Applies the edits,
/// uploads each file to its signed slot with progress, then creates the
/// post and pops with it. Leaving offers to save a draft.
class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key, this.pickOnOpen = false, this.draft});

  /// Open the camera/gallery sheet right away.
  final bool pickOnOpen;

  /// A saved draft to continue.
  final Draft? draft;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> with DraftableForm {
  final _api = ApiService();
  final _caption = TextEditingController();
  final _pages = PageController();
  final List<_Item> _items = [];

  /// Undo steps of "Edit all", kept between visits.
  final _groupHistory = EditHistory();
  PostVisibility _visibility = PostVisibility.public;
  bool _isPrivate = false;
  bool _posting = false;
  int _uploadingIndex = -1;

  /// While posting: applying edits (true) or uploading (false).
  bool _processing = false;

  /// Downloading a draft's photos/videos.
  bool _restoring = false;
  int _preview = 0;

  @override
  void initState() {
    super.initState();
    _caption.addListener(() => setState(() {}));
    _loadPrivacy();
    final draft = widget.draft;
    if (draft != null) {
      _caption.text = draft.data['caption'] as String? ?? '';
      _visibility = PostVisibility.parse(draft.data['visibility']);
      if (draft.media.isNotEmpty) _restoreMedia(draft.media);
    } else if (widget.pickOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addMedia();
      });
    }
  }

  // ── Drafts ──────────────────────────────────────────────────────────────────

  @override
  DraftKind get draftKind => DraftKind.post;
  @override
  Draft? get initialDraft => widget.draft;
  @override
  bool get draftsEnabled => true;
  @override
  bool get hasDraftContent => _dirty;
  @override
  String? draftTitle() => _caption.text.trim().split('\n').first;
  @override
  Map<String, dynamic> draftData() => {'caption': _caption.text, 'visibility': _visibility.apiValue};
  @override
  Object? draftFingerprint() => {
    ...draftData(),
    'media': [for (final it in _items) '${it.media.uploadedPath ?? it.key} ${it.media.edit.toJson()}'],
  };

  /// Uploads originals not on the server yet; edits are saved as settings,
  /// so they stay editable when the draft is continued.
  @override
  Future<List<DraftMedia>> draftMediaForSave() async {
    final out = <DraftMedia>[];
    for (final it in _items) {
      final m = it.media;
      final o = m.original;
      if (m.uploadedPath == null) {
        final token = await AuthManager.instance.getValidToken();
        final slot = await _api.requestPostUpload(token, mimeType: o.mimeType, sizeBytes: o.sizeBytes, fileName: o.fileName);
        await uploadFileToSlot(slot, o);
        m.uploadedPath = slot.path;
      }
      out.add(DraftMedia(
        path: m.uploadedPath!,
        mimeType: o.mimeType,
        fileName: o.fileName,
        sizeBytes: o.sizeBytes,
        width: o.width,
        height: o.height,
        durationMs: o.durationMs,
        edit: m.edit.isIdentity ? null : m.edit.toJson(),
      ));
    }
    return out;
  }

  /// Downloads a draft's originals so they can be previewed and re-edited.
  Future<void> _restoreMedia(List<DraftMedia> media) async {
    setState(() => _restoring = true);
    final dir = await getTemporaryDirectory();
    var failed = 0;
    final restored = <_Item>[];
    for (final m in media) {
      try {
        final r = await http.get(Uri.parse(m.url!));
        if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
        final name = m.fileName ?? m.path.split('/').last;
        final file = File('${dir.path}/draft_${DateTime.now().microsecondsSinceEpoch}_$name');
        await file.writeAsBytes(r.bodyBytes, flush: true);
        final picked = PickedMedia(
          file: file,
          fileName: name,
          mimeType: m.mimeType,
          sizeBytes: r.bodyBytes.length,
          width: m.width,
          height: m.height,
          durationMs: m.durationMs,
        );
        restored.add(_Item(EditableMedia(picked, edit: MediaEdit.fromJson(m.edit), uploadedPath: m.path)));
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() {
      _items.addAll(restored);
      _restoring = false;
    });
    markDraftBaseline();
    if (failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.draftOpenFailed(context.l10n.socialUploadFailed))));
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    _pages.dispose();
    super.dispose();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _loadPrivacy() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final me = await _api.getMyProfile(token);
      if (mounted) setState(() => _isPrivate = me.isPrivate);
    } catch (_) {
      // Only drives an informational note.
    }
  }

  bool get _dirty => _items.isNotEmpty || _caption.text.trim().isNotEmpty;
  bool get _canPost => !_posting && !_restoring && _dirty;
  List<_Item> get _editable => _items.where((it) => it.media.canEdit).toList();

  Future<void> _addMedia() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final remaining = kMaxPostMedia - _items.length;
    if (remaining <= 0) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.feedMediaLimit(kMaxPostMedia))));
      return;
    }
    final picked = (await pickMedia(context, allowFiles: false))
        .where((m) => m.mimeType.startsWith('image/') || m.mimeType.startsWith('video/'))
        .toList();
    if (!mounted || picked.isEmpty) return;
    if (picked.length > remaining) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.feedMediaLimit(kMaxPostMedia))));
    }
    final firstNew = _items.length;
    setState(() {
      _items.addAll(picked.take(remaining).map((m) => _Item(EditableMedia(m))));
      _preview = firstNew;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pages.hasClients) _pages.jumpToPage(firstNew);
    });
  }

  void _remove(int i) {
    setState(() {
      _items.removeAt(i);
      _preview = _items.isEmpty ? 0 : _preview.clamp(0, _items.length - 1);
    });
    if (_pages.hasClients && _items.isNotEmpty) _pages.jumpToPage(_preview);
  }

  void _reorder(int from, int to) {
    if (to > from) to -= 1;
    setState(() {
      final item = _items.removeAt(from);
      _items.insert(to, item);
      _preview = to;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pages.hasClients) _pages.jumpToPage(to);
    });
  }

  Future<void> _edit(int i) async {
    await MediaEditorPage.edit(context, _items[i].media);
    if (mounted) setState(() {});
  }

  Future<void> _editAll() async {
    final items = _editable;
    final current = items.indexOf(_items[_preview]);
    await MediaEditorPage.editAll(context, [for (final it in items) it.media], history: _groupHistory, initialIndex: current < 0 ? 0 : current);
    if (mounted) setState(() {});
  }

  void _showPreview(int i) {
    setState(() => _preview = i);
    if (_pages.hasClients) {
      _pages.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _post() async {
    if (!_canPost) {
      if (!_dirty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.feedPostEmpty)));
      }
      return;
    }
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    setState(() => _posting = true);
    try {
      final published = <PickedMedia>[];
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        final m = item.media;
        // Edits are baked in now; an unedited draft photo is already uploaded.
        setState(() {
          _uploadingIndex = i;
          _processing = !m.edit.isIdentity;
          item.progress = 0;
        });
        final PickedMedia file;
        try {
          file = await m.export(onProgress: (p) {
            if (mounted) setState(() => item.progress = p);
          });
        } catch (_) {
          throw Exception(l10n.mediaEditFailed);
        }
        published.add(file);
        if (item.publishedPath != null && item.publishedEdit == m.edit) continue;
        if (identical(file, m.original) && m.uploadedPath != null) {
          item.publishedPath = m.uploadedPath;
          item.publishedEdit = m.edit;
          continue;
        }
        setState(() {
          _processing = false;
          item.progress = 0;
        });
        final token = await AuthManager.instance.getValidToken();
        final slot = await _api.requestPostUpload(
          token,
          mimeType: file.mimeType,
          sizeBytes: file.sizeBytes,
          fileName: file.fileName,
        );
        try {
          await uploadFileToSlot(slot, file, onProgress: (p) {
            if (mounted) setState(() => item.progress = p);
          });
        } catch (_) {
          throw Exception(l10n.socialUploadFailed);
        }
        item.publishedPath = slot.path;
        item.publishedEdit = m.edit;
        item.progress = 1;
      }
      if (!mounted) return;
      setState(() {
        _uploadingIndex = -1;
        _processing = false;
      });
      final token = await AuthManager.instance.getValidToken();
      final post = await _api.createPersonalPost(
        token,
        caption: _caption.text.trim(),
        visibility: _visibility,
        media: [for (var i = 0; i < _items.length; i++) published[i].attachment(_items[i].publishedPath!)],
      );
      await draftPublished();
      if (!mounted) return;
      Navigator.of(context).pop(post);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _uploadingIndex = -1;
        _processing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final banner = draftBanner(context);
    return draftPopScope(
      busy: _posting,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.feedNewPost),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: _canPost ? _post : null,
                child: _posting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.nutritionPostAction),
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (banner != null) ...[banner, const SizedBox(height: 12)],
                if (_posting) ...[
                  _progress(context),
                  const SizedBox(height: 12),
                ],
                if (_restoring)
                  const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()))
                else if (_items.isEmpty) _emptyMedia(context) else ...[
                  _previewCarousel(context),
                  if (!_posting) _editBar(context),
                  const SizedBox(height: 10),
                  _thumbnails(context),
                  if (_items.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(l10n.feedReorderHint, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _caption,
                  enabled: !_posting,
                  minLines: 3,
                  maxLines: 10,
                  maxLength: kCaptionMaxLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: l10n.feedCaptionHint,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                VisibilitySelector(
                  value: _visibility,
                  enabled: !_posting,
                  onChanged: (v) => setState(() => _visibility = v),
                ),
                if (_isPrivate) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(Icons.lock_outline, size: 20, color: cs.onSecondaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l10n.feedPrivateAccountNote, style: TextStyle(color: cs.onSecondaryContainer)),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progress(BuildContext context) {
    final l10n = context.l10n;
    final uploading = _uploadingIndex >= 0;
    final value = uploading && _items.isNotEmpty
        ? (_uploadingIndex + _items[_uploadingIndex].progress) / _items.length
        : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        !uploading
            ? l10n.feedPublishing
            : _processing
            ? l10n.mediaProcessing(_uploadingIndex + 1, _items.length)
            : l10n.feedUploadingProgress(_uploadingIndex + 1, _items.length),
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 6),
      LinearProgressIndicator(value: value, borderRadius: BorderRadius.circular(4)),
    ]);
  }

  Widget _emptyMedia(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: _posting ? null : _addMedia,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_photo_alternate_outlined, size: 40, color: cs.primary),
            const SizedBox(height: 8),
            Text(l10n.feedAddMedia, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              l10n.feedMediaLimit(kMaxPostMedia),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ]),
        ),
      ),
    );
  }

  /// "Edit" for the photo/video on screen, "Edit all" when there are several.
  Widget _editBar(BuildContext context) {
    final l10n = context.l10n;
    final current = _items[_preview.clamp(0, _items.length - 1)];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        OutlinedButton.icon(
          onPressed: current.media.canEdit ? () => _edit(_preview) : null,
          icon: const Icon(Icons.tune, size: 18),
          label: Text(_items.length > 1 ? l10n.mediaEditItem(_preview + 1) : l10n.mediaEdit),
        ),
        const SizedBox(width: 8),
        if (_editable.length > 1)
          OutlinedButton.icon(
            onPressed: _editAll,
            icon: const Icon(Icons.auto_awesome_motion_outlined, size: 18),
            label: Text(l10n.mediaEditAll),
          ),
      ]),
    );
  }

  Widget _previewCarousel(BuildContext context) {
    final l10n = context.l10n;
    final first = _items.first.media.original;
    final ratio = (first.width != null && first.height != null && first.height! > 0)
        ? (first.width! / first.height!).clamp(0.8, 1.91)
        : 1.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: ratio,
        child: Stack(fit: StackFit.expand, children: [
          PageView.builder(
            controller: _pages,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _preview = i),
            itemBuilder: (context, i) {
              final item = _items[i];
              return item.isVideo
                  ? EditedVideoPreview(key: item.key, media: item.media, fit: BoxFit.cover)
                  : EditedImage(
                      key: item.key,
                      media: item.media,
                      fit: BoxFit.cover,
                      semanticLabel: l10n.nutritionPostPhotoOf(i + 1, _items.length),
                    );
            },
          ),
          if (_items.length > 1) ...[
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  l10n.feedMediaIndex(_preview + 1, _items.length),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: IgnorePointer(child: DotIndicator(count: _items.length, index: _preview)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _thumbnails(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    const size = 76.0;
    return SizedBox(
      height: size + 8,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        itemCount: _items.length,
        onReorder: _posting ? (_, _) {} : _reorder,
        footer: _items.length < kMaxPostMedia && !_posting
            ? Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Tooltip(
                  message: l10n.feedAddMedia,
                  child: InkWell(
                    onTap: _addMedia,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add, color: cs.primary),
                        Text(l10n.feedAddMore, style: Theme.of(context).textTheme.labelSmall),
                      ]),
                    ),
                  ),
                ),
              )
            : null,
        itemBuilder: (context, i) {
          final item = _items[i];
          final selected = i == _preview;
          final uploaded = item.publishedPath != null && item.publishedEdit == item.media.edit;
          final uploading = _posting && (i == _uploadingIndex || (!uploaded && i > _uploadingIndex));
          return ReorderableDelayedDragStartListener(
            key: item.key,
            index: i,
            enabled: !_posting,
            child: Padding(
              padding: const EdgeInsets.only(right: 6, top: 4),
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(children: [
                  Positioned.fill(
                    child: GestureDetector(
                      // A second tap on the selected one opens its editor.
                      onTap: () => selected && !_posting && item.media.canEdit ? _edit(i) : _showPreview(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: item.isVideo
                              ? _VideoThumb(durationMs: _trimmedMs(item.media))
                              : EditedImage(media: item.media, fit: BoxFit.cover, cacheWidth: 240),
                        ),
                      ),
                    ),
                  ),
                  if (!item.media.edit.isIdentity && !_posting)
                    Positioned(
                      left: 4,
                      bottom: 4,
                      child: Semantics(
                        label: l10n.mediaEdited,
                        child: CircleAvatar(
                          radius: 9,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.auto_fix_high, size: 11, color: cs.inversePrimary),
                        ),
                      ),
                    ),
                  if (uploading || uploaded && _posting)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: uploaded
                            ? const Icon(Icons.check_circle, color: Colors.white)
                            : SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                  value: i == _uploadingIndex ? item.progress : 0,
                                ),
                              ),
                      ),
                    ),
                  if (!_posting)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Semantics(
                        button: true,
                        label: l10n.feedRemoveMedia,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _remove(i),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: cs.inverseSurface.withValues(alpha: 0.75),
                              child: Icon(Icons.close, size: 13, color: cs.onInverseSurface),
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A video's length after its trim.
int? _trimmedMs(EditableMedia m) {
  final total = m.original.durationMs;
  if (total == null) return null;
  final start = m.edit.trimStart?.inMilliseconds ?? 0;
  final end = m.edit.trimEnd?.inMilliseconds ?? total;
  return end - start;
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({this.durationMs});

  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28, semanticLabel: context.l10n.feedVideo),
        if (durationMs != null)
          Text(formatDuration(durationMs!), style: const TextStyle(color: Colors.white, fontSize: 11)),
      ]),
    );
  }
}
