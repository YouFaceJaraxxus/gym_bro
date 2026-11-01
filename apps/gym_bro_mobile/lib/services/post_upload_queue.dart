import 'dart:async';

import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';
import '../media_editor/editable_media.dart';
import '../media_editor/media_edit.dart';
import '../models/chat.dart' show OutgoingAttachment;
import '../models/post.dart';
import '../models/shared_content.dart';
import '../models/story.dart';
import 'api_service.dart';
import 'auth_manager.dart';
import 'media_upload.dart';

/// One photo/video of a post being composed and published.
class PostMediaItem {
  PostMediaItem(this.media);

  final EditableMedia media;
  Key get key => media.key;

  /// Of the current step (applying edits or uploading), 0…1.
  double progress = 0;

  /// Storage path of the published (edited) file once uploaded, and the
  /// edits it was made with — a retry skips it unless they changed since.
  String? publishedPath;
  MediaEdit? publishedEdit;

  /// People pinned on it (photos only).
  List<PhotoTag> tags = const [];

  bool get isVideo => media.isVideo;
  bool get isPublished => publishedPath != null && publishedEdit == media.edit;
}

/// Everything needed to publish a composed personal post.
class PostComposition {
  const PostComposition({
    required this.items,
    required this.caption,
    required this.visibility,
    this.share,
    this.hideLikeCount = false,
    this.commentsDisabled = false,
    this.locationName = '',
  });

  final List<PostMediaItem> items;

  /// Caption markup (with @mentions).
  final String caption;
  final PostVisibility visibility;
  final ShareTarget? share;
  final bool hideLikeCount;
  final bool commentsDisabled;
  final String locationName;
}

/// Where publishing is: preparing ([processing]) or uploading item [index]
/// of [count] at [fraction]; [index] -1 once the post itself is being created.
class PublishProgress {
  const PublishProgress({required this.index, required this.count, this.fraction = 0, this.processing = false});

  final int index;
  final int count;
  final double fraction;
  final bool processing;

  bool get creating => index < 0;

  /// The whole thing, 0…1; null when there's nothing to measure (no media).
  double? get overall {
    if (count == 0) return null;
    if (creating) return 1;
    return ((index + fraction.clamp(0, 1)) / count).clamp(0, 1);
  }
}

/// Applies the edits, uploads each file to its signed slot (skipping ones
/// already uploaded with the same edits, so a retry resumes) and creates the
/// post. Reports progress through [onProgress].
Future<Post> publishComposition(
  ApiService api,
  PostComposition c, {
  required AppLocalizations l10n,
  void Function(PublishProgress progress)? onProgress,
  Future<String> Function()? token,
}) async {
  final getToken = token ?? AuthManager.instance.getValidToken;
  final items = c.items;
  final count = items.length;
  final published = <PickedMedia>[];
  for (var i = 0; i < count; i++) {
    final item = items[i];
    final m = item.media;
    // Edits are baked in now; an unedited draft photo is already uploaded.
    final processing = !m.edit.isIdentity;
    item.progress = 0;
    onProgress?.call(PublishProgress(index: i, count: count, processing: processing));
    final PickedMedia file;
    try {
      file = await m.export(onProgress: (p) {
        item.progress = p;
        onProgress?.call(PublishProgress(index: i, count: count, fraction: p, processing: processing));
      });
    } catch (_) {
      throw Exception(l10n.mediaEditFailed);
    }
    published.add(file);
    if (item.isPublished) continue;
    if (identical(file, m.original) && m.uploadedPath != null) {
      item.publishedPath = m.uploadedPath;
      item.publishedEdit = m.edit;
      continue;
    }
    item.progress = 0;
    onProgress?.call(PublishProgress(index: i, count: count));
    final slot = await api.requestPostUpload(
      await getToken(),
      mimeType: file.mimeType,
      sizeBytes: file.sizeBytes,
      fileName: file.fileName,
    );
    try {
      await uploadFileToSlot(slot, file, onProgress: (p) {
        item.progress = p;
        onProgress?.call(PublishProgress(index: i, count: count, fraction: p));
      });
    } catch (_) {
      throw Exception(l10n.socialUploadFailed);
    }
    item.publishedPath = slot.path;
    item.publishedEdit = m.edit;
    item.progress = 1;
  }
  onProgress?.call(PublishProgress(index: -1, count: count));
  return api.createPersonalPost(
    await getToken(),
    caption: c.caption,
    visibility: c.visibility,
    media: [for (var i = 0; i < count; i++) published[i].attachment(items[i].publishedPath!)],
    tags: [for (final it in items) it.isVideo ? const <PhotoTag>[] : it.tags],
    share: c.share,
    hideLikeCount: c.hideLikeCount ? true : null,
    commentsDisabled: c.commentsDisabled ? true : null,
    locationName: c.locationName,
  );
}

/// Everything needed to publish a composed story.
class StoryComposition {
  const StoryComposition({
    this.media,
    this.caption = '',
    this.background,
    this.share,
    this.audience = kStoryAudienceEveryone,
    this.poll,
  });

  final EditableMedia? media;

  /// Caption markup (with @mentions).
  final String caption;

  /// For text and shared stories (no media).
  final String? background;
  final ShareRequest? share;
  final String audience;
  final StoryPoll? poll;
}

/// Applies the edits, uploads the photo/video (if any) and creates the story.
Future<Story> publishStory(
  ApiService api,
  StoryComposition c, {
  required AppLocalizations l10n,
  void Function(PublishProgress progress)? onProgress,
  Future<String> Function()? token,
}) async {
  final getToken = token ?? AuthManager.instance.getValidToken;
  OutgoingAttachment? attachment;
  final media = c.media;
  if (media != null) {
    final processing = !media.edit.isIdentity;
    onProgress?.call(PublishProgress(index: 0, count: 1, processing: processing));
    final PickedMedia file;
    try {
      file = await media.export(onProgress: (p) {
        onProgress?.call(PublishProgress(index: 0, count: 1, fraction: p, processing: processing));
      });
    } catch (_) {
      throw Exception(l10n.mediaEditFailed);
    }
    final slot = await api.requestStoryUpload(await getToken(), mimeType: file.mimeType, sizeBytes: file.sizeBytes, fileName: file.fileName);
    try {
      await uploadFileToSlot(slot, file, onProgress: (p) {
        onProgress?.call(PublishProgress(index: 0, count: 1, fraction: p));
      });
    } catch (_) {
      throw Exception(l10n.socialUploadFailed);
    }
    attachment = file.attachment(slot.path);
  }
  onProgress?.call(PublishProgress(index: -1, count: media == null ? 0 : 1));
  return api.createStory(
    await getToken(),
    media: attachment,
    caption: c.caption,
    background: attachment == null ? c.background : null,
    share: c.share,
    audience: c.audience,
    poll: c.poll,
  );
}

enum PendingPostStatus { uploading, posted, failed }

/// A post (or a story) publishing in the background (see [PostUploadQueue]).
class PendingPost {
  PendingPost._(this.id, this.composition, this.l10n, this.onPosted, {this.story});

  final String id;

  /// What's being posted: a post, or else [story].
  final PostComposition? composition;
  final StoryComposition? story;
  final AppLocalizations l10n;
  final Future<void> Function()? onPosted;

  PendingPostStatus status = PendingPostStatus.uploading;
  PublishProgress? progress;

  /// Once [PendingPostStatus.posted].
  Post? post;

  /// Why it failed, ready to show.
  String? error;

  /// Once a story is [PendingPostStatus.posted].
  Story? postedStory;

  bool get isStory => story != null;

  /// Sharing something (a workout, a post…) rather than posting media.
  bool get isShare => (composition?.share ?? story?.share) != null;

  /// The first photo/video, for the thumbnail.
  EditableMedia? get cover => composition?.items.firstOrNull?.media ?? story?.media;
}

typedef PostPublisher = Future<Post> Function(
  PostComposition composition,
  AppLocalizations l10n,
  void Function(PublishProgress progress) onProgress,
);

/// Posts publishing in the background, so the composer can close right
/// away: the feed shows them in a "Posting…" bar. A finished one shows
/// "Posted" for [successHold], then leaves and is announced on [posted]. A
/// failed one stays (with what was composed, in memory) until it's retried
/// or discarded. Nothing survives an app restart.
class PostUploadQueue extends ChangeNotifier {
  PostUploadQueue({ApiService? api, PostPublisher? publisher, this.successHold = const Duration(milliseconds: 1500)})
      : _apiOverride = api,
        _publisher = publisher;

  static final PostUploadQueue instance = PostUploadQueue();

  final ApiService? _apiOverride;
  late final ApiService _api = _apiOverride ?? ApiService();
  final PostPublisher? _publisher;
  final Duration successHold;

  final List<PendingPost> _items = [];
  final _posted = StreamController<Post>.broadcast();
  var _nextId = 0;

  /// Oldest first.
  List<PendingPost> get items => List.unmodifiable(_items);

  /// Each post once its "Posted" moment is over (it belongs in the feed now).
  Stream<Post> get posted => _posted.stream;

  /// Each story once it's out (the story tray reloads).
  Stream<Story> get storyPosted => _storyPosted.stream;
  final _storyPosted = StreamController<Story>.broadcast();

  /// Starts publishing a story; it shows in the same bar as posts.
  PendingPost enqueueStory(StoryComposition story, {required AppLocalizations l10n}) {
    final p = PendingPost._('pending-${_nextId++}', null, l10n, null, story: story);
    _items.add(p);
    notifyListeners();
    _run(p);
    return p;
  }

  /// Starts publishing [composition]. [onPosted] runs once it's created
  /// (e.g. deleting the draft it came from). [l10n] words the errors.
  PendingPost enqueue(PostComposition composition, {required AppLocalizations l10n, Future<void> Function()? onPosted}) {
    final p = PendingPost._('pending-${_nextId++}', composition, l10n, onPosted);
    _items.add(p);
    notifyListeners();
    _run(p);
    return p;
  }

  /// Tries a failed one again; files already uploaded aren't sent again.
  void retry(PendingPost p) {
    if (p.status != PendingPostStatus.failed || !_items.contains(p)) return;
    _run(p);
  }

  /// Drops a failed one.
  void discard(PendingPost p) {
    if (p.status == PendingPostStatus.uploading) return;
    if (_items.remove(p)) notifyListeners();
  }

  Future<void> _run(PendingPost p) async {
    p
      ..status = PendingPostStatus.uploading
      ..error = null
      ..progress = null;
    notifyListeners();
    Post? post;
    Story? story;
    try {
      void report(PublishProgress progress) {
        p.progress = progress;
        notifyListeners();
      }

      if (p.story != null) {
        story = await publishStory(_api, p.story!, l10n: p.l10n, onProgress: report);
      } else {
        post = await (_publisher != null
            ? _publisher(p.composition!, p.l10n, report)
            : publishComposition(_api, p.composition!, l10n: p.l10n, onProgress: report));
      }
    } catch (e) {
      p
        ..status = PendingPostStatus.failed
        ..error = e is FutureActivityException ? p.l10n.postShareFutureBlocked : e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return;
    }
    p
      ..status = PendingPostStatus.posted
      ..post = post
      ..postedStory = story;
    notifyListeners();
    if (story != null) _storyPosted.add(story);
    try {
      await p.onPosted?.call();
    } catch (_) {
      // Only cleanup (a draft); the post is out.
    }
    await Future<void>.delayed(successHold);
    if (_items.remove(p)) notifyListeners();
    if (post != null) _posted.add(post);
  }
}
