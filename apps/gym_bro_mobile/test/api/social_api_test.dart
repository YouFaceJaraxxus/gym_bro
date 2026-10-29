import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/config.dart';
import 'package:gym_bro_mobile/models/chat.dart';
import 'package:gym_bro_mobile/models/post.dart';
import 'package:gym_bro_mobile/models/reaction.dart';
import 'package:gym_bro_mobile/services/api_service.dart';
import 'package:http/http.dart' as http;

import '../helpers/fake_backend.dart';

const _token = 'tok-123';

void _expectHeaders(http.Request req) {
  expect(req.headers['Authorization'], 'Bearer $_token');
  expect(req.headers['Content-Type'], startsWith('application/json'));
}

Matcher _throwsMessage(String m) => throwsA(predicate((e) => e is Exception && '$e'.contains(m)));

const _signedPath = '/storage/v1/object/sign/user-media/u-liam/seed-deadlift-pr.jpg?token=SIGNED';

// Shape captured from the local stack (GET /posts/feed as liam), token trimmed.
Map<String, dynamic> _personalPostJson({String id = 'p1', String visibility = 'public'}) => {
      'id': id,
      'business_id': null,
      'author_id': 'u-liam',
      'content': '190kg deadlift ✅ 10kg to go.',
      'visibility': visibility,
      'created_at': '2026-10-26T13:37:54.327Z',
      'updated_at': '2026-10-26T13:40:00.000Z',
      'images': [
        {
          'id': 'img1',
          'post_id': id,
          'url': _signedPath,
          'position': 0,
          'media_type': 'image',
          'mime_type': 'image/jpeg',
          'width': 1080,
          'height': 1080,
          'duration_ms': null,
        },
        {
          'id': 'img2',
          'post_id': id,
          'url': '/storage/v1/object/sign/user-media/u-liam/clip.mp4?token=SIGNED',
          'position': 1,
          'media_type': 'video',
          'mime_type': 'video/mp4',
          'width': 1280,
          'height': 720,
          'duration_ms': 8400,
        },
        // A media row whose signing failed comes back without a URL: dropped.
        {'id': 'img3', 'post_id': id, 'url': null, 'position': 2, 'media_type': 'image'},
      ],
      'kind': 'personal',
      'author': {
        'id': 'u-liam',
        'username': 'liamoconnor',
        'name': 'Liam',
        'last_name': "O'Connor",
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=liamoconnor&size=256',
      },
      'business': null,
      'reactions': {
        'counts': {'strong': 1, 'fire': 2, 'love': 3, 'like': 2, 'wow': 1},
        'total': 9,
        'top': ['love', 'like', 'fire'],
      },
      'my_reaction': 'fire',
      'comment_count': 9,
      'like_count': 9,
      'liked_by_me': true,
      'can_edit': true,
    };

Map<String, dynamic> _businessPostJson() => {
      'id': 'bp1',
      'business_id': 'g1',
      'author_id': 'u-marcus',
      'content': 'Pool closed Saturday for maintenance.',
      'visibility': 'public',
      'created_at': '2026-10-25T08:00:00.000Z',
      'updated_at': '2026-10-25T08:00:00.000Z',
      'images': [
        {'id': 'bi1', 'post_id': 'bp1', 'url': 'https://picsum.photos/seed/pool/800/600', 'position': 0},
      ],
      'kind': 'business',
      'author': null,
      'business': {'id': 'g1', 'name': 'Ironclad Fitness', 'logo': null, 'type': 'gym'},
      'reactions': {'counts': {}, 'total': 0, 'top': []},
      'my_reaction': null,
      'comment_count': '0',
      'like_count': 0,
      'liked_by_me': false,
      'can_edit': false,
    };

// Shape captured from GET /posts/:id/comments.
Map<String, dynamic> _commentJson({
  String id = 'c1',
  String? parentId,
  int depth = 0,
  String body = 'That lockout looked clean.',
  String? myReaction,
}) =>
    {
      'id': id,
      'post_id': 'p1',
      'parent_id': parentId,
      'depth': depth,
      'author_id': 'u-elena',
      'body': body,
      'created_at': '2026-10-26T20:13:54.327Z',
      'updated_at': '2026-10-26T20:13:54.327Z',
      'deleted_at': null,
      'deleted': false,
      'hidden': false,
      'author': {
        'id': 'u-elena',
        'username': 'elenavasquez',
        'name': 'Elena',
        'last_name': 'Vasquez',
        'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=elenavasquez&size=256',
      },
      'reply_count': 1,
      'reactions': {
        'counts': {'strong': 1},
        'total': 1,
        'top': ['strong'],
      },
      'my_reaction': myReaction,
      'score': 3,
      'can_edit': false,
      'can_delete': true,
      'can_reply': true,
    };

Map<String, dynamic> _reactionResultJson(String? mine, {int total = 9}) => {
      'post_id': 'p1',
      'reactions': {
        'counts': {'love': 3, 'like': 3, 'fire': 3},
        'total': total,
        'top': ['love', 'like', 'fire'],
      },
      'my_reaction': mine,
      'like_count': total,
      'liked': mine != null,
    };

void _expectPersonalPost(Post p) {
  expect(p.id, 'p1');
  expect(p.businessId, isNull);
  expect(p.isPersonal, isTrue);
  expect(p.authorId, 'u-liam');
  expect(p.content, '190kg deadlift ✅ 10kg to go.');
  expect(p.visibility, PostVisibility.public);
  expect(p.createdAt, DateTime.utc(2026, 10, 26, 13, 37, 54, 327));
  expect(p.updatedAt, DateTime.utc(2026, 10, 26, 13, 40));
  expect(p.images, hasLength(2));
  final img = p.images[0];
  expect(img.id, 'img1');
  expect(img.postId, 'p1');
  expect(img.url, AppConfig.resolveUrl(_signedPath));
  expect(img.url, startsWith('http'));
  expect(img.position, 0);
  expect(img.mediaType, 'image');
  expect(img.isVideo, isFalse);
  expect(img.width, 1080);
  expect(img.height, 1080);
  expect(img.durationMs, isNull);
  final vid = p.images[1];
  expect(vid.isVideo, isTrue);
  expect(vid.durationMs, 8400);
  expect(vid.aspectRatio, closeTo(16 / 9, 1e-9));
  expect(p.author!.id, 'u-liam');
  expect(p.author!.username, 'liamoconnor');
  expect(p.author!.fullName, "Liam O'Connor");
  expect(p.author!.avatarUrl, startsWith('https://api.dicebear.com/'));
  expect(p.business, isNull);
  expect(p.reactions.total, 9);
  expect(p.reactions.counts, {
    ReactionType.strong: 1,
    ReactionType.fire: 2,
    ReactionType.love: 3,
    ReactionType.like: 2,
    ReactionType.wow: 1,
  });
  expect(p.reactions.top, [ReactionType.love, ReactionType.like, ReactionType.fire]);
  expect(p.myReaction, ReactionType.fire);
  expect(p.commentCount, 9);
  expect(p.canEdit, isTrue);
}

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('getPost', () {
    test('GETs /posts/:id and parses a personal post fully', () async {
      backend.on('GET /posts/p1', ok(_personalPostJson()));

      final p = await api.getPost(_token, 'p1');

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/posts/p1');
      expect(req.url.hasQuery, isFalse);
      _expectHeaders(req);
      _expectPersonalPost(p);
    });

    test('parses a business post (business, string comment_count, public image URL)', () async {
      backend.on('GET /posts/bp1', ok(_businessPostJson()));

      final p = await api.getPost(_token, 'bp1');

      expect(p.businessId, 'g1');
      expect(p.isPersonal, isFalse);
      expect(p.author, isNull);
      expect(p.business!.id, 'g1');
      expect(p.business!.name, 'Ironclad Fitness');
      expect(p.business!.logo, isNull);
      expect(p.business!.type, 'gym');
      expect(p.images.single.url, 'https://picsum.photos/seed/pool/800/600');
      expect(p.images.single.mediaType, 'image');
      expect(p.commentCount, 0);
      expect(p.myReaction, isNull);
      expect(p.reactions.total, 0);
      expect(p.canEdit, isFalse);
    });

    test('404 surfaces the message', () async {
      backend.on('GET /posts/nope', err(404, 'Post not found'));
      await expectLater(api.getPost(_token, 'nope'), _throwsMessage('Post not found'));
    });

    test('a non-JSON error body still throws a readable error', () async {
      backend.on('GET /posts/p1', ok('<html>Bad gateway</html>', 502));
      await expectLater(api.getPost(_token, 'p1'), _throwsMessage('Request failed (502)'));
    });
  });

  group('getFeed', () {
    test('GETs /posts/feed?mode=home with paging and parses a mixed list', () async {
      backend.on('GET /posts/feed', ok([_personalPostJson(), _businessPostJson()]));

      final posts = await api.getFeed(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/posts/feed');
      expect(req.url.queryParameters, {'mode': 'home', 'page': '0', 'page_size': '20'});
      _expectHeaders(req);
      expect(posts, hasLength(2));
      _expectPersonalPost(posts[0]);
      expect(posts[1].business!.name, 'Ironclad Fitness');
    });

    test('explore mode and custom paging', () async {
      backend.on('GET /posts/feed', ok([]));
      await api.getFeed(_token, explore: true, page: 3, pageSize: 10);
      expect(backend.only.url.queryParameters, {'mode': 'explore', 'page': '3', 'page_size': '10'});
    });
  });

  group('getUserPosts', () {
    test('GETs /posts?author_id= with paging (no media filter by default)', () async {
      backend.on('GET /posts', ok([_personalPostJson(visibility: 'followers')]));

      final posts = await api.getUserPosts(_token, 'u-liam');

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/posts');
      expect(req.url.queryParameters, {'author_id': 'u-liam', 'page': '0', 'page_size': '30'});
      _expectHeaders(req);
      expect(posts.single.visibility, PostVisibility.followers);
    });

    test('mediaOnly adds media=only', () async {
      backend.on('GET /posts', ok([]));
      await api.getUserPosts(_token, 'u-liam', mediaOnly: true, page: 2, pageSize: 12);
      expect(backend.only.url.queryParameters, {'author_id': 'u-liam', 'page': '2', 'page_size': '12', 'media': 'only'});
    });

    test('403 private_account throws PrivateAccountException', () async {
      backend.on('GET /posts', err(403, 'This account is private', code: 'private_account'));
      await expectLater(api.getUserPosts(_token, 'u-sofia'), throwsA(isA<PrivateAccountException>()));
    });

    test('another 403 is a plain error with the message', () async {
      backend.on('GET /posts', err(403, 'Forbidden'));
      await expectLater(
        api.getUserPosts(_token, 'u-sofia'),
        throwsA(allOf(isNot(isA<PrivateAccountException>()), predicate((e) => '$e'.contains('Forbidden')))),
      );
    });
  });

  group('requestPostUpload', () {
    test('POSTs mime/size/file name to /posts/uploads and resolves the relative upload URL', () async {
      backend.on(
        'POST /posts/uploads',
        ok({
          'path': 'u-liam/1b2c.jpg',
          'upload_url': '/storage/v1/object/upload/sign/user-media/u-liam/1b2c.jpg?token=SIGNED',
          'token': 'SIGNED',
          'mime_type': 'image/jpeg',
          'expires_in': 7200,
        }, 201),
      );

      final slot = await api.requestPostUpload(_token, mimeType: 'image/jpeg', sizeBytes: 245760, fileName: 'pr.jpg');

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/posts/uploads');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'mime_type': 'image/jpeg', 'size_bytes': 245760, 'file_name': 'pr.jpg'}));
      expect(slot.path, 'u-liam/1b2c.jpg');
      expect(slot.uploadUrl,
          AppConfig.resolveUrl('/storage/v1/object/upload/sign/user-media/u-liam/1b2c.jpg?token=SIGNED'));
      expect(slot.uploadUrl, startsWith('http'));
      expect(slot.mimeType, 'image/jpeg');
    });

    test('omits a null file name', () async {
      backend.on('POST /posts/uploads', ok({'path': 'p', 'upload_url': 'https://x/u', 'mime_type': 'video/mp4'}, 201));
      final slot = await api.requestPostUpload(_token, mimeType: 'video/mp4', sizeBytes: 10);
      expect(bodyOf(backend.only), equals({'mime_type': 'video/mp4', 'size_bytes': 10}));
      expect(slot.uploadUrl, 'https://x/u');
    });

    test('413 surfaces the message', () async {
      backend.on('POST /posts/uploads', err(413, 'Files are limited to 50 MB'));
      await expectLater(
        api.requestPostUpload(_token, mimeType: 'video/mp4', sizeBytes: 999999999),
        _throwsMessage('Files are limited to 50 MB'),
      );
    });
  });

  group('createPersonalPost', () {
    test('POSTs content, visibility and media (attachment JSON) to /posts', () async {
      backend.on('POST /posts', ok(_personalPostJson(visibility: 'followers'), 201));

      final p = await api.createPersonalPost(
        _token,
        caption: 'Leg day',
        visibility: PostVisibility.followers,
        media: const [
          OutgoingAttachment(path: 'u-liam/a.jpg', fileName: 'a.jpg', sizeBytes: 1000, width: 1080, height: 1350),
          OutgoingAttachment(path: 'u-liam/b.mp4', sizeBytes: 5000, width: 1280, height: 720, durationMs: 8400),
        ],
      );

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/posts');
      _expectHeaders(req);
      expect(
        bodyOf(req),
        equals({
          'content': 'Leg day',
          'visibility': 'followers',
          'media': [
            {'path': 'u-liam/a.jpg', 'file_name': 'a.jpg', 'size_bytes': 1000, 'width': 1080, 'height': 1350},
            {'path': 'u-liam/b.mp4', 'size_bytes': 5000, 'width': 1280, 'height': 720, 'duration_ms': 8400},
          ],
        }),
      );
      expect((bodyOf(req) as Map).containsKey('business_id'), isFalse);
      expect(p.visibility, PostVisibility.followers);
      expect(p.images, hasLength(2));
    });

    test('text-only post sends an empty media list', () async {
      backend.on('POST /posts', ok(_personalPostJson(), 201));
      await api.createPersonalPost(_token, caption: 'Rest day', visibility: PostVisibility.public);
      expect(bodyOf(backend.only), equals({'content': 'Rest day', 'visibility': 'public', 'media': []}));
    });

    test('400 surfaces the message', () async {
      backend.on('POST /posts', err(400, 'A post needs a caption or media'));
      await expectLater(
        api.createPersonalPost(_token, caption: '', visibility: PostVisibility.public),
        _throwsMessage('A post needs a caption or media'),
      );
    });
  });

  // ApiService.updatePost (business posts, a Map body) shadows the extension
  // method, so callers use SocialApi(api).updatePost — as post_card.dart does.
  group('SocialApi.updatePost', () {
    test('PUTs content and visibility to /posts/:id', () async {
      backend.on('PUT /posts/p1', ok(_personalPostJson(visibility: 'followers')));

      final p = await SocialApi(api).updatePost(_token, 'p1', content: 'Edited', visibility: PostVisibility.followers);

      final req = backend.only;
      expect(req.method, 'PUT');
      expect(pathOf(req), '/posts/p1');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'content': 'Edited', 'visibility': 'followers'}));
      expect(p.visibility, PostVisibility.followers);
    });

    test('omits null keys (a caption-only edit never touches visibility)', () async {
      backend.on('PUT /posts/p1', ok(_personalPostJson()));

      await SocialApi(api).updatePost(_token, 'p1', content: 'Only caption');
      await SocialApi(api).updatePost(_token, 'p1', visibility: PostVisibility.public);
      await SocialApi(api).updatePost(_token, 'p1');

      expect(bodyOf(backend.requests[0]), equals({'content': 'Only caption'}));
      expect(bodyOf(backend.requests[1]), equals({'visibility': 'public'}));
      expect(bodyOf(backend.requests[2]), equals({}));
    });

    test('400 surfaces the message', () async {
      backend.on('PUT /posts/bp1', err(400, 'visibility must be public or followers (personal posts only)'));
      await expectLater(
        SocialApi(api).updatePost(_token, 'bp1', visibility: PostVisibility.followers),
        _throwsMessage('personal posts only'),
      );
    });
  });

  group('reactToPost', () {
    test('PUTs {reaction} to /posts/:id/reaction and parses the result', () async {
      backend.on('PUT /posts/p1/reaction', ok(_reactionResultJson('love')));

      final r = await api.reactToPost(_token, 'p1', ReactionType.love);

      final req = backend.only;
      expect(req.method, 'PUT');
      expect(pathOf(req), '/posts/p1/reaction');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'reaction': 'love'}));
      expect(r.postId, 'p1');
      expect(r.myReaction, ReactionType.love);
      expect(r.reactions.total, 9);
      expect(r.reactions.counts, {ReactionType.love: 3, ReactionType.like: 3, ReactionType.fire: 3});
      expect(r.reactions.top, [ReactionType.love, ReactionType.like, ReactionType.fire]);
    });

    test('null DELETEs /posts/:id/reaction with no body', () async {
      backend.on('DELETE /posts/p1/reaction', ok(_reactionResultJson(null, total: 8)));

      final r = await api.reactToPost(_token, 'p1', null);

      final req = backend.only;
      expect(req.method, 'DELETE');
      expect(pathOf(req), '/posts/p1/reaction');
      _expectHeaders(req);
      expect(req.body, isEmpty);
      expect(r.myReaction, isNull);
      expect(r.reactions.total, 8);
    });

    test('400 surfaces the message', () async {
      backend.on('PUT /posts/p1/reaction', err(400, 'reaction must be one of: like, love'));
      await expectLater(api.reactToPost(_token, 'p1', ReactionType.like), _throwsMessage('reaction must be one of'));
    });
  });

  group('likePost / unlikePost', () {
    test('likePost PUTs reaction=like', () async {
      backend.on('PUT /posts/p1/reaction', ok(_reactionResultJson('like')));

      final r = await api.likePost(_token, 'p1');

      final req = backend.only;
      expect(req.method, 'PUT');
      expect(pathOf(req), '/posts/p1/reaction');
      expect(bodyOf(req), equals({'reaction': 'like'}));
      expect(r.myReaction, ReactionType.like);
    });

    test('unlikePost DELETEs the reaction', () async {
      backend.on('DELETE /posts/p1/reaction', ok(_reactionResultJson(null)));

      final r = await api.unlikePost(_token, 'p1');

      final req = backend.only;
      expect(req.method, 'DELETE');
      expect(pathOf(req), '/posts/p1/reaction');
      expect(req.body, isEmpty);
      expect(r.myReaction, isNull);
    });
  });

  group('getPostReactions', () {
    test('GETs /posts/:id/reactions?page= and parses reactors', () async {
      backend.on(
        'GET /posts/p1/reactions',
        ok([
          {
            'id': 'u-liam',
            'username': 'liamoconnor',
            'name': 'Liam',
            'last_name': "O'Connor",
            'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=liamoconnor&size=256',
            'reaction': 'fire',
            'created_at': '2026-10-27T19:16:59.088Z',
          },
          {
            'id': 'u-dan',
            'username': null,
            'name': 'Daniel',
            'last_name': 'Kim',
            'avatar_url': null,
            'reaction': 'clap',
            'created_at': '2026-10-27T18:00:00.000Z',
          },
        ]),
      );

      final list = await api.getPostReactions(_token, 'p1');

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/posts/p1/reactions');
      expect(req.url.queryParameters, {'page': '0'});
      _expectHeaders(req);
      expect(list, hasLength(2));
      expect(list[0].user.id, 'u-liam');
      expect(list[0].user.fullName, "Liam O'Connor");
      expect(list[0].user.avatarUrl, startsWith('https://api.dicebear.com/'));
      expect(list[0].username, 'liamoconnor');
      expect(list[0].reaction, ReactionType.fire);
      expect(list[1].username, '');
      expect(list[1].user.avatarUrl, isNull);
      expect(list[1].reaction, ReactionType.clap);
    });

    test('filters by reaction and pages', () async {
      backend.on('GET /posts/p1/reactions', ok([]));
      await api.getPostReactions(_token, 'p1', reaction: ReactionType.strong, page: 2);
      expect(backend.only.url.queryParameters, {'page': '2', 'reaction': 'strong'});
    });
  });

  group('getPostComments', () {
    test('GETs /posts/:id/comments with sort and paging and parses the flat tree', () async {
      backend.on(
        'GET /posts/p1/comments',
        ok([
          _commentJson(),
          {
            ..._commentJson(id: 'c2', parentId: 'c1', depth: 1, body: "From your lips to the barbell's ears 🙏"),
            'author_id': 'u-liam',
            'author': {'id': 'u-liam', 'username': 'liamoconnor', 'name': 'Liam', 'last_name': "O'Connor", 'avatar_url': null},
            'updated_at': '2026-10-26T20:20:00.000Z',
            'reply_count': '0',
            'reactions': {
              'counts': {'clap': 1, 'love': 1},
              'total': 2,
              'top': ['love', 'clap'],
            },
            'my_reaction': 'love',
            'score': '2',
            'can_edit': true,
          },
          // Deleted placeholder that still has replies.
          {
            ..._commentJson(id: 'c3', body: ''),
            'author_id': null,
            'author': null,
            'deleted': true,
            'deleted_at': '2026-10-27T00:00:00.000Z',
            'reactions': {'counts': {}, 'total': 0, 'top': []},
            'can_delete': false,
            'can_reply': false,
          },
        ]),
      );

      final list = await api.getPostComments(_token, 'p1');

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/posts/p1/comments');
      expect(req.url.queryParameters, {'sort': 'top', 'page': '0', 'page_size': '20'});
      _expectHeaders(req);

      expect(list, hasLength(3));
      final c = list[0];
      expect(c.id, 'c1');
      expect(c.postId, 'p1');
      expect(c.parentId, isNull);
      expect(c.depth, 0);
      expect(c.authorId, 'u-elena');
      expect(c.author!.username, 'elenavasquez');
      expect(c.author!.fullName, 'Elena Vasquez');
      expect(c.body, 'That lockout looked clean.');
      expect(c.createdAt, DateTime.utc(2026, 10, 26, 20, 13, 54, 327).toLocal());
      expect(c.createdAt.isUtc, isFalse);
      expect(c.isEdited, isFalse);
      expect(c.deleted, isFalse);
      expect(c.hidden, isFalse);
      expect(c.replyCount, 1);
      expect(c.reactions.counts, {ReactionType.strong: 1});
      expect(c.reactions.total, 1);
      expect(c.myReaction, isNull);
      expect(c.score, 3);
      expect(c.canEdit, isFalse);
      expect(c.canDelete, isTrue);
      expect(c.canReply, isTrue);

      final reply = list[1];
      expect(reply.parentId, 'c1');
      expect(reply.depth, 1);
      expect(reply.author!.avatarUrl, isNull);
      expect(reply.isEdited, isTrue);
      expect(reply.replyCount, 0);
      expect(reply.score, 2);
      expect(reply.myReaction, ReactionType.love);
      expect(reply.reactions.top, [ReactionType.love, ReactionType.clap]);
      expect(reply.canEdit, isTrue);

      final gone = list[2];
      expect(gone.deleted, isTrue);
      expect(gone.author, isNull);
      expect(gone.authorId, isNull);
      expect(gone.body, '');
      expect(gone.canDelete, isFalse);
      expect(gone.canReply, isFalse);
    });

    test('passes sort and paging', () async {
      backend.on('GET /posts/p1/comments', ok([]));
      await api.getPostComments(_token, 'p1', sort: 'new', page: 1, pageSize: 50);
      expect(backend.only.url.queryParameters, {'sort': 'new', 'page': '1', 'page_size': '50'});
    });

    test('404 surfaces the message', () async {
      backend.on('GET /posts/p1/comments', err(404, 'Post not found'));
      await expectLater(api.getPostComments(_token, 'p1'), _throwsMessage('Post not found'));
    });
  });

  group('createPostComment', () {
    test('POSTs {body} for a top-level comment', () async {
      backend.on('POST /posts/p1/comments', ok(_commentJson(), 201));

      final c = await api.createPostComment(_token, 'p1', 'That lockout looked clean.');

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/posts/p1/comments');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'body': 'That lockout looked clean.'}));
      expect(c.id, 'c1');
      expect(c.parentId, isNull);
    });

    test('POSTs {body, parent_id} for a reply', () async {
      backend.on('POST /posts/p1/comments', ok(_commentJson(id: 'c9', parentId: 'c1', depth: 1, body: 'Thanks'), 201));

      final c = await api.createPostComment(_token, 'p1', 'Thanks', parentId: 'c1');

      expect(bodyOf(backend.only), equals({'body': 'Thanks', 'parent_id': 'c1'}));
      expect(c.parentId, 'c1');
      expect(c.depth, 1);
    });

    test('400 surfaces the message', () async {
      backend.on('POST /posts/p1/comments', err(400, 'body is required'));
      await expectLater(api.createPostComment(_token, 'p1', ''), _throwsMessage('body is required'));
    });
  });

  group('updatePostComment', () {
    test('PUTs {body} to /posts/comments/:id', () async {
      backend.on('PUT /posts/comments/c1', ok({..._commentJson(body: 'Edited'), 'updated_at': '2026-10-26T21:00:00.000Z'}));

      final c = await api.updatePostComment(_token, 'c1', 'Edited');

      final req = backend.only;
      expect(req.method, 'PUT');
      expect(pathOf(req), '/posts/comments/c1');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'body': 'Edited'}));
      expect(c.body, 'Edited');
      expect(c.isEdited, isTrue);
    });

    test('403 surfaces the message', () async {
      backend.on('PUT /posts/comments/c1', err(403, 'Only the author can edit a comment'));
      await expectLater(api.updatePostComment(_token, 'c1', 'x'), _throwsMessage('Only the author can edit'));
    });
  });

  group('deletePostComment', () {
    test('DELETEs /posts/comments/:id; 204 is fine', () async {
      backend.on('DELETE /posts/comments/c1', ok('', 204));

      await api.deletePostComment(_token, 'c1');

      final req = backend.only;
      expect(req.method, 'DELETE');
      expect(pathOf(req), '/posts/comments/c1');
      _expectHeaders(req);
    });

    test('404 surfaces the message', () async {
      backend.on('DELETE /posts/comments/c1', err(404, 'Comment not found'));
      await expectLater(api.deletePostComment(_token, 'c1'), _throwsMessage('Comment not found'));
    });
  });

  group('reactToComment', () {
    test('PUTs {reaction} to /posts/comments/:id/reaction and parses the comment', () async {
      backend.on(
        'PUT /posts/comments/c1/reaction',
        ok({
          ..._commentJson(myReaction: 'clap'),
          'reactions': {
            'counts': {'strong': 1, 'clap': 1},
            'total': 2,
            'top': ['strong', 'clap'],
          },
        }),
      );

      final c = await api.reactToComment(_token, 'c1', ReactionType.clap);

      final req = backend.only;
      expect(req.method, 'PUT');
      expect(pathOf(req), '/posts/comments/c1/reaction');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'reaction': 'clap'}));
      expect(c.myReaction, ReactionType.clap);
      expect(c.reactions.total, 2);
    });

    test('null DELETEs the reaction with no body', () async {
      backend.on('DELETE /posts/comments/c1/reaction', ok(_commentJson()));

      final c = await api.reactToComment(_token, 'c1', null);

      final req = backend.only;
      expect(req.method, 'DELETE');
      expect(pathOf(req), '/posts/comments/c1/reaction');
      _expectHeaders(req);
      expect(req.body, isEmpty);
      expect(c.myReaction, isNull);
    });

    test('404 surfaces the message', () async {
      backend.on('PUT /posts/comments/c1/reaction', err(404, 'Comment not found'));
      await expectLater(api.reactToComment(_token, 'c1', ReactionType.like), _throwsMessage('Comment not found'));
    });
  });
}
