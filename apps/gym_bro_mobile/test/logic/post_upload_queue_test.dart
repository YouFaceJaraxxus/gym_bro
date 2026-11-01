import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/post.dart';
import 'package:gym_bro_mobile/models/story.dart';
import 'package:gym_bro_mobile/services/api_service.dart';
import 'package:gym_bro_mobile/services/post_upload_queue.dart';
import 'package:gym_bro_mobile/widgets/posting_bar.dart';

import '../helpers/fake_backend.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

Map<String, dynamic> _postJson(String id) => {
      'id': id,
      'business_id': null,
      'author_id': 'u-liam',
      'content': 'Leg day',
      'visibility': 'public',
      'created_at': '2026-11-01T10:00:00.000Z',
      'updated_at': '2026-11-01T10:00:00.000Z',
      'images': [],
      'kind': 'personal',
    };

Post _post(String id) => Post.fromJson(_postJson(id));

const _composition = PostComposition(items: [], caption: 'Leg day', visibility: PostVisibility.followers);

/// A publisher the test drives: completes when [finish] / [fail] is called.
class _Driven {
  final calls = <Completer<Post>>[];
  final progress = <void Function(PublishProgress)>[];

  Future<Post> call(PostComposition c, AppLocalizations l10n, void Function(PublishProgress) onProgress) {
    final done = Completer<Post>();
    calls.add(done);
    progress.add(onProgress);
    return done.future;
  }
}

void main() {
  group('publishComposition', () {
    late FakeBackend backend;
    setUp(() => backend = FakeBackend()..install());
    tearDown(() => backend.uninstall());

    test('a text post goes straight to POST /posts with every setting', () async {
      backend.on('POST /posts', ok(_postJson('p9'), 201));
      final seen = <PublishProgress>[];
      final post = await publishComposition(
        ApiService(),
        const PostComposition(
          items: [],
          caption: 'Leg day @[Ana](u-ana)',
          visibility: PostVisibility.followers,
          hideLikeCount: true,
          locationName: ' Belgrade ',
        ),
        l10n: _l10n,
        onProgress: seen.add,
        token: () async => 'tok',
      );
      expect(post.id, 'p9');
      expect(bodyOf(backend.only), {
        'content': 'Leg day @[Ana](u-ana)',
        'visibility': 'followers',
        'media': [],
        'hide_like_count': true,
        'location_name': 'Belgrade',
      });
      expect(seen.single.creating, isTrue);
      expect(seen.single.overall, isNull);
    });
  });

  group('publishStory', () {
    late FakeBackend backend;
    setUp(() => backend = FakeBackend()..install());
    tearDown(() => backend.uninstall());

    test('a text story goes straight to POST /stories with its audience', () async {
      backend.on('POST /stories', ok({
        'id': 's1',
        'author_id': 'u-liam',
        'caption': 'Leg day',
        'background': '#2a9d8f',
        'created_at': '2026-11-01T10:00:00.000Z',
        'expires_at': '2026-11-02T10:00:00.000Z',
      }, 201));
      final seen = <PublishProgress>[];
      final story = await publishStory(
        ApiService(),
        const StoryComposition(caption: 'Leg day', background: '#2a9d8f', audience: kStoryAudienceCloseFriends),
        l10n: _l10n,
        onProgress: seen.add,
        token: () async => 'tok',
      );
      expect(story.id, 's1');
      final body = bodyOf(backend.only) as Map;
      expect(body['caption'], 'Leg day');
      expect(body['background'], '#2a9d8f');
      expect(body['audience'], 'close_friends');
      expect(seen.single.creating, isTrue, reason: 'nothing to upload');
    });
  });

  test('PublishProgress.overall spreads over the items', () {
    expect(const PublishProgress(index: 1, count: 4, fraction: 0.5).overall, 0.375);
    expect(const PublishProgress(index: -1, count: 2).overall, 1);
    expect(const PublishProgress(index: 0, count: 1, fraction: 3).overall, 1);
  });

  group('PostUploadQueue', () {
    test('uploading → posted, then leaves after the hold and is announced', () async {
      final driven = _Driven();
      final queue = PostUploadQueue(publisher: driven.call, successHold: const Duration(milliseconds: 20));
      var draftsDeleted = 0;
      final announced = <Post>[];
      queue.posted.listen(announced.add);

      final p = queue.enqueue(_composition, l10n: _l10n, onPosted: () async => draftsDeleted++);
      expect(queue.items, [p]);
      expect(p.status, PendingPostStatus.uploading);

      driven.progress.single(const PublishProgress(index: 0, count: 2, fraction: 0.5));
      expect(p.progress!.overall, 0.25);

      driven.calls.single.complete(_post('p1'));
      await pumpEventQueue(times: 2);
      expect(p.status, PendingPostStatus.posted);
      expect(p.post!.id, 'p1');
      expect(draftsDeleted, 1);
      expect(queue.items, [p]);
      expect(announced, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(queue.items, isEmpty);
      expect(announced.single.id, 'p1');
    });

    test('a failure stays with its message until retried or discarded', () async {
      final driven = _Driven();
      final queue = PostUploadQueue(publisher: driven.call, successHold: Duration.zero);
      final p = queue.enqueue(_composition, l10n: _l10n);

      driven.calls[0].completeError(Exception('Upload failed'));
      await pumpEventQueue();
      expect(p.status, PendingPostStatus.failed);
      expect(p.error, 'Upload failed');

      queue.retry(p);
      expect(p.status, PendingPostStatus.uploading);
      expect(p.error, isNull);
      expect(driven.calls, hasLength(2));
      queue.discard(p); // not while uploading
      expect(queue.items, [p]);

      driven.calls[1].completeError(const FutureActivityException());
      await pumpEventQueue();
      expect(p.error, _l10n.postShareFutureBlocked);
      queue.discard(p);
      expect(queue.items, isEmpty);
    });
  });

  group('PostingBar', () {
    Widget app(PostUploadQueue q) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PostingBar(queue: q)),
        );

    testWidgets('shows progress, then Retry / Discard on failure, then a check', (tester) async {
      final driven = _Driven();
      final queue = PostUploadQueue(publisher: driven.call, successHold: const Duration(milliseconds: 200));
      await tester.pumpWidget(app(queue));
      expect(find.byType(LinearProgressIndicator), findsNothing);

      queue.enqueue(_composition, l10n: _l10n);
      driven.progress[0](const PublishProgress(index: 0, count: 1, fraction: 0.6));
      await tester.pumpAndSettle();
      expect(find.text('Posting…'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo(0.6, 0.001));

      driven.calls[0].completeError(Exception('No network'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't post."), findsOneWidget);
      expect(find.text('No network'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      // No progress yet: an indeterminate bar (never settles).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Posting…'), findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, isNull);

      driven.calls[1].complete(_post('p1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Posted'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Posted'), findsNothing);
    });

    testWidgets('Discard removes a failed post', (tester) async {
      final driven = _Driven();
      final queue = PostUploadQueue(publisher: driven.call);
      await tester.pumpWidget(app(queue));
      queue.enqueue(_composition, l10n: _l10n);
      driven.calls[0].completeError(Exception('x'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(queue.items, isEmpty);
      expect(find.text("Couldn't post."), findsNothing);
    });
  });
}
