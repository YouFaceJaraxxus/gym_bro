import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../media_editor/edited_media_view.dart';
import '../../media_editor/editable_media.dart';
import '../../media_editor/media_editor_page.dart';
import '../../models/mention.dart';
import '../../models/shared_content.dart';
import '../../models/story.dart';
import '../../services/post_upload_queue.dart';
import '../../services/media_upload.dart';
import '../../widgets/mentions.dart';
import '../../widgets/shared_content_card.dart';
import '../../widgets/social_widgets.dart';
import 'story_poll.dart';

/// The story composer: a photo/video, text on a colour, or — with [share] —
/// the shared thing as a card on a colour; with [media], that photo (e.g. a
/// rendered recap card) ready to post. Posting doesn't wait: the story is
/// queued ([PostUploadQueue]) and returned, so callers can follow it (the
/// feed shows it in its "Posting…" bar; elsewhere see [followPending]).
Future<PendingPost?> openStoryComposer(BuildContext context, {ShareRequest? share, PickedMedia? media}) =>
    Navigator.of(context).push<PendingPost>(
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => StoryComposerPage(share: share, media: media)));

/// Composes one story. Without [share] it starts as a text story; "Photo or
/// video" switches to media (editable, with an optional caption). The
/// colour row picks the background of text and shared stories. "@" in the
/// text mentions people; the poll button adds a poll sticker. It's posted to
/// "Your story" (everyone who can see my stories) or "Close friends" only.
class StoryComposerPage extends StatefulWidget {
  const StoryComposerPage({super.key, this.share, this.media});

  final ShareRequest? share;

  /// A photo or video to start with.
  final PickedMedia? media;

  @override
  State<StoryComposerPage> createState() => _StoryComposerPageState();
}

class _StoryComposerPageState extends State<StoryComposerPage> {
  final _text = MentionTextEditingController();
  final _textFocus = FocusNode();
  EditableMedia? _media;
  StoryPoll? _poll;
  String _background = kStoryBackgrounds.first;

  /// What's being posted to (for the progress on its button).

  ShareRequest? get _share => widget.share;
  bool get _dirty => _media != null || _poll != null || _text.text.trim().isNotEmpty;
  bool get _canPost => (_media != null || _share != null || _poll != null || _text.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    if (widget.media != null) _media = EditableMedia(widget.media!);
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _textFocus.dispose();
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

  Future<void> _editPoll() async {
    final poll = await showStoryPollEditor(context, initial: _poll);
    if (poll != null && mounted) setState(() => _poll = poll);
  }

  Future<void> _post({String audience = kStoryAudienceEveryone}) async {
    if (!_canPost) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.storyComposerEmpty)));
      return;
    }
    FocusScope.of(context).unfocus();
    // Uploads in the background; the queue keeps what was composed for a retry.
    final pending = PostUploadQueue.instance.enqueueStory(
      StoryComposition(
        media: _media,
        caption: _text.markup,
        background: _background,
        share: _share,
        audience: audience,
        poll: _poll,
      ),
      l10n: context.l10n,
    );
    Navigator.of(context).pop(pending);
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
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
      canPop: !_dirty,
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
                  onPressed: _pickMedia,
                ),
              IconButton(
                key: const ValueKey('story-poll'),
                tooltip: _poll == null ? l10n.storyPollAdd : l10n.storyPollEdit,
                icon: const Icon(Icons.poll_outlined),
                onPressed: _editPoll,
              ),
              if (media != null && media.canEdit)
                IconButton(tooltip: l10n.storyComposerEdit, icon: const Icon(Icons.tune), onPressed: _edit),
              if (media != null)
                IconButton(
                  tooltip: l10n.storyComposerRemoveMedia,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _media = null),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('story-post'),
                      onPressed: _canPost ? _post : null,
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(
                        l10n.storyYourStory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('story-post-close-friends'),
                      style: FilledButton.styleFrom(backgroundColor: kCloseFriendsGreen, foregroundColor: Colors.white),
                      onPressed: _canPost ? () => _post(audience: kStoryAudienceCloseFriends) : null,
                      icon: const Icon(Icons.star_rounded),
                      label: Text(
                        l10n.storyCloseFriends,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ]),
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
    if (_poll != null) Center(child: Padding(padding: const EdgeInsets.all(32), child: _pollSticker())),
    Positioned(left: 12, right: 12, bottom: 12, child: _textField(caption: true)),
  ]);

  /// The poll as it will show: tap to edit, × to remove.
  Widget _pollSticker() {
    final l10n = context.l10n;
    return Stack(clipBehavior: Clip.none, children: [
      GestureDetector(
        onTap: _editPoll,
        child: AbsorbPointer(child: StoryPollSticker(poll: _poll!, maxWidth: 280)),
      ),
      Positioned(
        right: -10,
        top: -10,
        child: Material(
          color: Colors.black87,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => setState(() => _poll = null),
            child: Tooltip(
              message: l10n.storyPollRemove,
              child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 18, color: Colors.white)),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _colourCanvas() {
    final share = _share;
    return Container(
      color: parseHexColor(_background),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _textField(caption: share != null || _poll != null),
          if (_poll != null) ...[const SizedBox(height: 20), _pollSticker()],
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
    final field = TextField(
      key: const ValueKey('story-text'),
      controller: _text,
      focusNode: _textFocus,
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
    // "@" suggests people (the server also turns a typed @username into a mention).
    return MentionAutocomplete(controller: _text, focusNode: _textFocus, kinds: const {MentionKind.user}, child: field);
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
                    onTap: () => setState(() => _background = hex),
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
