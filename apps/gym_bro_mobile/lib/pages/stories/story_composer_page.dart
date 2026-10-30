import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../media_editor/edited_media_view.dart';
import '../../media_editor/editable_media.dart';
import '../../media_editor/media_editor_page.dart';
import '../../models/chat.dart';
import '../../models/shared_content.dart';
import '../../models/story.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/media_upload.dart';
import '../../widgets/shared_content_card.dart';
import '../../widgets/social_widgets.dart';

/// The story composer: a photo/video, text on a colour, or — with [share] —
/// the shared thing as a card on a colour. Returns the posted story.
Future<Story?> openStoryComposer(BuildContext context, {ShareRequest? share}) =>
    Navigator.of(context).push<Story>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => StoryComposerPage(share: share)));

/// Composes one story. Without [share] it starts as a text story; "Photo or
/// video" switches to media (editable, with an optional caption). The
/// colour row picks the background of text and shared stories.
class StoryComposerPage extends StatefulWidget {
  const StoryComposerPage({super.key, this.share});

  final ShareRequest? share;

  @override
  State<StoryComposerPage> createState() => _StoryComposerPageState();
}

class _StoryComposerPageState extends State<StoryComposerPage> {
  final _api = ApiService();
  final _text = TextEditingController();
  EditableMedia? _media;
  String _background = kStoryBackgrounds.first;
  bool _posting = false;
  double _progress = 0;

  ShareRequest? get _share => widget.share;
  bool get _dirty => _media != null || _text.text.trim().isNotEmpty;
  bool get _canPost => !_posting && (_media != null || _share != null || _text.text.trim().isNotEmpty);

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

  Future<void> _pickMedia() async {
    final picked = (await pickMedia(context, allowFiles: false, multiple: false))
        .where((m) => m.mimeType.startsWith('image/') || m.mimeType.startsWith('video/'))
        .toList();
    if (!mounted || picked.isEmpty) return;
    setState(() => _media = EditableMedia(picked.first));
  }

  Future<void> _edit() async {
    final m = _media;
    if (m == null || !m.canEdit) return;
    await MediaEditorPage.edit(context, m);
    if (mounted) setState(() {});
  }

  Future<void> _post() async {
    if (!_canPost) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.storyComposerEmpty)));
      return;
    }
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _posting = true;
      _progress = 0;
    });
    try {
      OutgoingAttachment? attachment;
      final media = _media;
      if (media != null) {
        final PickedMedia file;
        try {
          file = await media.export();
        } catch (_) {
          throw Exception(l10n.mediaEditFailed);
        }
        final token = await AuthManager.instance.getValidToken();
        final slot = await _api.requestStoryUpload(token, mimeType: file.mimeType, sizeBytes: file.sizeBytes, fileName: file.fileName);
        try {
          await uploadFileToSlot(slot, file, onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          });
        } catch (_) {
          throw Exception(l10n.socialUploadFailed);
        }
        attachment = file.attachment(slot.path);
      }
      final token = await AuthManager.instance.getValidToken();
      final story = await _api.createStory(
        token,
        media: attachment,
        caption: _text.text,
        background: attachment == null ? _background : null,
        share: _share,
      );
      if (mounted) Navigator.of(context).pop(story);
    } on FutureActivityException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.postShareFutureBlocked)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty || _posting) return !_posting;
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.storyComposerDiscardTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.storyComposerDiscard)),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = _media;
    return PopScope(
      canPop: !_dirty && !_posting,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
      },
      child: Theme(
        data: ThemeData.dark(useMaterial3: true),
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(l10n.storyComposerTitle),
            actions: [
              if (_share == null && media == null)
                IconButton(
                  tooltip: l10n.storyComposerPickMedia,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  onPressed: _posting ? null : _pickMedia,
                ),
              if (media != null && media.canEdit)
                IconButton(tooltip: l10n.storyComposerEdit, icon: const Icon(Icons.tune), onPressed: _posting ? null : _edit),
              if (media != null)
                IconButton(
                  tooltip: l10n.storyComposerRemoveMedia,
                  icon: const Icon(Icons.close),
                  onPressed: _posting ? null : () => setState(() => _media = null),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: ClipRRect(borderRadius: BorderRadius.circular(16), child: media != null ? _mediaCanvas(media) : _colourCanvas()),
                ),
              ),
              if (media == null) _colourRow(),
              if (_posting) LinearProgressIndicator(value: media == null || _progress == 0 ? null : _progress, minHeight: 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('story-post'),
                    onPressed: _canPost ? _post : null,
                    icon: _posting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_circle_outline),
                    label: Text(_posting ? l10n.storyComposerPosting : l10n.storyComposerShare),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _mediaCanvas(EditableMedia media) => Stack(fit: StackFit.expand, children: [
    const ColoredBox(color: Colors.black),
    media.isVideo ? EditedVideoPreview(media: media) : EditedImage(media: media, fit: BoxFit.contain),
    Positioned(left: 12, right: 12, bottom: 12, child: _textField(caption: true)),
  ]);

  Widget _colourCanvas() {
    final share = _share;
    return Container(
      color: parseHexColor(_background),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _textField(caption: share != null),
          if (share != null) ...[
            const SizedBox(height: 20),
            IgnorePointer(
              child: SharedContentCard(
                content: SharedContent(kind: share.kind, refId: share.refId, available: true, preview: share.preview.json),
                onDark: true,
                maxWidth: 320,
              ),
            ),
          ],
        ]),
      ),
    );
  }

  /// Big centred text for a text story; a caption line over media or a share.
  Widget _textField({required bool caption}) {
    final l10n = context.l10n;
    return TextField(
      key: const ValueKey('story-text'),
      controller: _text,
      enabled: !_posting,
      maxLength: 500,
      maxLines: caption ? 3 : 8,
      minLines: 1,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(
        color: Colors.white,
        fontSize: caption ? 18 : 30,
        fontWeight: caption ? FontWeight.w600 : FontWeight.w700,
        shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
      ),
      decoration: InputDecoration(
        hintText: caption ? l10n.storyComposerCaptionHint : l10n.storyComposerTextHint,
        hintStyle: const TextStyle(color: Colors.white70),
        border: InputBorder.none,
        counterText: '',
        filled: caption,
        fillColor: Colors.black38,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _colourRow() {
    final l10n = context.l10n;
    return SizedBox(
      height: 52,
      child: Semantics(
        label: l10n.storyComposerBackground,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final hex in kStoryBackgrounds)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Semantics(
                  button: true,
                  selected: hex == _background,
                  label: hex,
                  child: GestureDetector(
                    onTap: _posting ? null : () => setState(() => _background = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: parseHexColor(hex),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: hex == _background ? 3 : 1),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
