import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/post.dart';
import 'package:gym_bro_mobile/services/api_service.dart';

import '../helpers/fake_backend.dart';
import 'api_test_utils.dart';

// The archive: archiving / showing again a post, and my archived posts and
// stories by date range (GET /posts/archive, /stories/archive).
const postId = '70069719-f719-4d1d-9a9e-e55d2077e28e';
const liamId = '8d0b05de-7c18-441b-9536-aaa042eaeaaa';

Map<String, dynamic> post({String? archivedAt}) => {
  'id': postId,
  'business_id': null,
  'author_id': liamId,
  'content': 'leg day',
  'visibility': 'public',
  'post_type': 'generic',
  'ref_id': null,
  'attachment': null,
  'archived_at': archivedAt,
  'created_at': '2026-10-30T07:41:38.058Z',
  'updated_at': '2026-10-30T07:41:38.058Z',
  'images': [],
  'reactions': {'counts': {}, 'total': 0, 'top': []},
  'my_reaction': null,
  'comment_count': 0,
  'can_edit': true,
};

Map<String, dynamic> story({required String id, bool live = false}) => {
  'id': id,
  'author_id': liamId,
  'media_type': null,
  'caption': 'gym',
  'background': '#ff5500',
  'share': null,
  'created_at': '2026-10-29T07:00:00.000Z',
  'expires_at': '2026-10-30T07:00:00.000Z',
  'is_live': live,
  'seen': true,
  'is_mine': true,
  'view_count': 3,
  'reaction_count': 1,
};

void main() {
  final ctx = useFakeBackend();
  final backend = ctx.backend, api = ctx.api;

  group('Post.archivedAt', () {
    test('parses archived_at (local) and isArchived', () {
      final p = Post.fromJson(post(archivedAt: '2026-10-30T08:00:00.000Z'));
      expect(p.isArchived, isTrue);
      expect(p.archivedAt, DateTime.utc(2026, 10, 30, 8).toLocal());
      expect(Post.fromJson(post()).isArchived, isFalse);
    });

    test('copyWith keeps, sets and clears it', () {
      final p = Post.fromJson(post(archivedAt: '2026-10-30T08:00:00.000Z'));
      expect(p.copyWith(content: 'x').archivedAt, p.archivedAt);
      expect(p.copyWith(clearArchivedAt: true).isArchived, isFalse);
      expect(Post.fromJson(post()).copyWith(archivedAt: DateTime(2026)).isArchived, isTrue);
    });
  });

  group('archive / show again', () {
    test('archivePost PUTs /posts/:id/archive', () async {
      backend().on('PUT /posts/$postId/archive', ok(post(archivedAt: '2026-10-30T08:00:00.000Z')));
      final p = await api().archivePost(token, postId);
      expectJson(backend().only, 'PUT', '/posts/$postId/archive', null);
      expect(p.isArchived, isTrue);
    });

    test('unarchivePost DELETEs /posts/:id/archive', () async {
      backend().on('DELETE /posts/$postId/archive', ok(post()));
      final p = await api().unarchivePost(token, postId);
      expectDelete(backend().only, '/posts/$postId/archive');
      expect(p.isArchived, isFalse);
    });
  });

  group('ranges', () {
    final from = DateTime(2026, 10);
    final to = DateTime(2026, 11);

    test('getArchivedPosts sends from/to as UTC ISO and the page size', () async {
      backend().on('GET /posts/archive', ok([post(archivedAt: '2026-10-30T08:00:00.000Z')]));
      final posts = await api().getArchivedPosts(token, from: from, to: to);
      expectGet(backend().only, '/posts/archive', {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'page_size': '500',
      });
      expect(posts.single.id, postId);
    });

    test('getStoryArchive: without a range only the page size', () async {
      backend().on('GET /stories/archive', ok([story(id: 's1', live: true), story(id: 's2')]));
      final stories = await api().getStoryArchive(token, pageSize: 50);
      expectGet(backend().only, '/stories/archive', {'page_size': '50'});
      expect(stories.map((s) => s.id), ['s1', 's2']);
      expect(stories.first.isLive, isTrue);
      expect(stories.last.viewCount, 3);
    });

    test('getStoryArchive with a range', () async {
      backend().on('GET /stories/archive', ok([]));
      await api().getStoryArchive(token, from: from, to: to);
      expectGet(backend().only, '/stories/archive', {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'page_size': '500',
      });
    });
  });

  errorTests(ctx, {
    'archivePost': ('PUT /posts/$postId/archive', (a) => a.archivePost(token, postId)),
    'unarchivePost': ('DELETE /posts/$postId/archive', (a) => a.unarchivePost(token, postId)),
    'getArchivedPosts': ('GET /posts/archive', (a) => a.getArchivedPosts(token)),
    'getStoryArchive': ('GET /stories/archive', (a) => a.getStoryArchive(token)),
  });
}
