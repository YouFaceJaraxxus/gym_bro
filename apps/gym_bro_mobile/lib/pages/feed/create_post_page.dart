import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/l10n.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/media_upload.dart';
import '../../widgets/post_card.dart';
import '../../widgets/social_widgets.dart';

/// Server limit for photos/videos per post.
const kMaxPostMedia = 10;

class _Item {
  _Item(this.media);

  final PickedMedia media;
  final Key key = UniqueKey();
  double progress = 0;

  /// Storage path once uploaded (kept so a retry skips it).
  String? uploadedPath;

  bool get isVideo => media.mimeType.startsWith('video/');
}

/// Compose a personal post: up to ten photos/videos (reorderable), caption
/// and visibility. Uploads each file to its signed slot with progress, then
/// creates the post and pops with it.
class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key, this.pickOnOpen = false});

  /// Open the camera/gallery sheet right away.
  final bool pickOnOpen;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _api = ApiService();
  final _caption = TextEditingController();
  final _pages = PageController();
  final List<_Item> _items = [];
  PostVisibility _visibility = PostVisibility.public;
  bool _isPrivate = false;
  bool _posting = false;
  int _uploadingIndex = -1;
  int _preview = 0;

  @override
  void initState() {
    super.initState();
    _caption.addListener(() => setState(() {}));
    _loadPrivacy();
    if (widget.pickOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addMedia();
      });
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
  bool get _canPost => !_posting && _dirty;

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
      _items.addAll(picked.take(remaining).map(_Item.new));
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
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        if (item.uploadedPath != null) continue;
        setState(() {
          _uploadingIndex = i;
          item.progress = 0;
        });
        final token = await AuthManager.instance.getValidToken();
        final slot = await _api.requestPostUpload(
          token,
          mimeType: item.media.mimeType,
          sizeBytes: item.media.sizeBytes,
          fileName: item.media.fileName,
        );
        try {
          await uploadFileToSlot(slot, item.media, onProgress: (p) {
            if (mounted) setState(() => item.progress = p);
          });
        } catch (_) {
          throw Exception(l10n.socialUploadFailed);
        }
        item.uploadedPath = slot.path;
        item.progress = 1;
      }
      if (!mounted) return;
      setState(() => _uploadingIndex = -1);
      final token = await AuthManager.instance.getValidToken();
      final post = await _api.createPersonalPost(
        token,
        caption: _caption.text.trim(),
        visibility: _visibility,
        media: [for (final it in _items) it.media.attachment(it.uploadedPath!)],
      );
      if (!mounted) return;
      Navigator.of(context).pop(post);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _uploadingIndex = -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  Future<void> _confirmDiscard() async {
    if (_posting) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.feedDiscardTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.feedDiscard)),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return PopScope<Object?>(
      canPop: !_dirty && !_posting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
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
                if (_posting) ...[
                  _progress(context),
                  const SizedBox(height: 12),
                ],
                if (_items.isEmpty) _emptyMedia(context) else ...[
                  _previewCarousel(context),
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
        uploading ? l10n.feedUploadingProgress(_uploadingIndex + 1, _items.length) : l10n.feedPublishing,
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

  Widget _previewCarousel(BuildContext context) {
    final l10n = context.l10n;
    final first = _items.first.media;
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
                  ? _LocalVideoPreview(key: item.key, media: item.media)
                  : Image.file(
                      item.media.file,
                      key: item.key,
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
          final uploading = _posting && (i == _uploadingIndex || (item.uploadedPath == null && i > _uploadingIndex));
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
                      onTap: () => _showPreview(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: item.isVideo
                              ? _VideoThumb(durationMs: item.media.durationMs)
                              : Image.file(item.media.file, fit: BoxFit.cover, cacheWidth: 240),
                        ),
                      ),
                    ),
                  ),
                  if (uploading || item.uploadedPath != null && _posting)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: item.uploadedPath != null
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

/// A picked video: first frame, tap to play/pause.
class _LocalVideoPreview extends StatefulWidget {
  const _LocalVideoPreview({super.key, required this.media});

  final PickedMedia media;

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  late final VideoPlayerController _c = VideoPlayerController.file(widget.media.file);
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c.setLooping(true);
    _c.initialize().then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.feedVideo,
      button: true,
      child: GestureDetector(
        onTap: () async {
          if (!_ready) return;
          _c.value.isPlaying ? await _c.pause() : await _c.play();
          if (mounted) setState(() {});
        },
        child: ColoredBox(
          color: Colors.black,
          child: Stack(fit: StackFit.expand, children: [
            if (_ready)
              FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(width: _c.value.size.width, height: _c.value.size.height, child: VideoPlayer(_c)),
              )
            else
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            if (_ready && !_c.value.isPlaying)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
