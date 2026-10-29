import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/config.dart';
import 'package:gym_bro_mobile/models/app_notification.dart';
import 'package:gym_bro_mobile/models/post.dart';
import 'package:gym_bro_mobile/models/reaction.dart';

import '../helpers/fake_backend.dart';
import 'api_test_utils.dart';

// Bodies captured from the local stack (GET /notifications, /posts), trimmed.
const gymId = 'ff453a60-28ca-4cdd-a919-c6ecd344ab65';
const liamId = '8d0b05de-7c18-441b-9536-aaa042eaeaaa';
const marcusId = 'b8d30b8b-ebb3-4a91-b5c4-39992a7deb8d';
const postId = '5d7190b6-ab40-479b-adf4-acec164e5424';
const notifId = '8a5cd215-012a-4e6a-96de-07c08939e782';

final commentNotif = {
  'id': notifId,
  'user_id': liamId,
  'type': 'post_comment',
  'title': 'Kenji Tanaka commented on your post',
  'body': 'Noted coach 🫡',
  'metadata': {
    'post_id': '70cda22f-aed4-413c-a6f2-220f0bcb0fa8',
    'parent_id': '214a493a-c6ba-4b52-8978-4cb41b210786',
    'comment_id': '2efc66cc-84fa-411f-9fdd-85c6bfea7c5d',
    'business_id': null,
    'business_name': null,
  },
  'is_read': false,
  'created_at': '2026-10-27T18:20:54.327Z',
};

final inviteNotif = {
  'id': 'n-invite',
  'user_id': liamId,
  'type': 'employee_gym_invite',
  'title': 'Marcus Bennett invited you to join Ironclad Fitness',
  'body': null,
  'metadata': {
    'gym_id': gymId,
    'gym_name': 'Ironclad Fitness',
    'employee_type': 'employee_trainer',
    'invite_status': 'pending',
  },
  'is_read': true,
  'created_at': '2026-10-25T03:25:54.327Z',
};

final postJson = {
  'id': postId,
  'business_id': gymId,
  'author_id': marcusId,
  'content': 'Thank you to everyone who came out to our 5K charity run this past weekend.',
  'visibility': 'public',
  'created_at': '2026-09-15T16:06:25.312Z',
  'updated_at': '2026-09-15T16:06:25.312Z',
  'images': [
    {
      'id': '024cf71e-f036-4864-8465-ac6f9aa1fdde',
      'post_id': postId,
      'url': 'https://picsum.photos/seed/post-5d7190b6/1000/600',
      'position': 0,
      'media_type': 'image',
      'mime_type': null,
      'width': null,
      'height': null,
      'duration_ms': null,
    },
    {
      'id': 'vid-1',
      'post_id': postId,
      // Private media comes back relative to the Supabase origin.
      'url': '/storage/v1/object/sign/media/posts/run.mp4?token=redacted',
      'position': 1,
      'media_type': 'video',
      'mime_type': 'video/mp4',
      'width': 1080,
      'height': 1920,
      'duration_ms': 15200,
    },
    // An image whose signed URL couldn't be made is dropped.
    {'id': 'gone', 'post_id': postId, 'url': null, 'position': 2},
  ],
  'kind': 'business',
  'author': {
    'id': marcusId,
    'username': 'marcusbennett',
    'name': 'Marcus',
    'last_name': 'Bennett',
    'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=marcusbennett&size=256',
  },
  'business': {'id': gymId, 'name': 'Ironclad Fitness', 'logo': 'https://picsum.photos/seed/gym-logo/800/400', 'type': 'gym'},
  'reactions': {
    'counts': {'like': 6, 'fire': '2'},
    'total': 8,
    'top': ['like', 'fire'],
  },
  'my_reaction': 'fire',
  'comment_count': '3',
  'like_count': 8,
  'liked_by_me': true,
  'can_edit': true,
};

void main() {
  final ctx = useFakeBackend();
  FakeBackend backend() => ctx.backend();

  group('notifications', () {
    test('getNotifications parses the page, items and metadata', () async {
      backend().on('GET /notifications', ok({
        'items': [
          commentNotif,
          inviteNotif,
          {...commentNotif, 'id': 'n-new', 'type': 'some_future_type', 'metadata': null, 'body': ''},
        ],
        'unread_count': 11,
      }));
      final page = await ctx.api().getNotifications(token, userId: liamId);
      expectGet(backend().only, '/notifications', {'user_id': liamId, 'page': '0', 'page_size': '20'});

      expect(page.unreadCount, 11);
      expect(page.items, hasLength(3));
      final c = page.items[0];
      expect(c.id, notifId);
      expect(c.userId, liamId);
      expect(c.type, NotificationType.postComment);
      expect(c.title, 'Kenji Tanaka commented on your post');
      expect(c.body, 'Noted coach 🫡');
      expect(c.metadata!['comment_id'], '2efc66cc-84fa-411f-9fdd-85c6bfea7c5d');
      expect(c.metadata!['business_id'], isNull);
      expect(c.isRead, isFalse);
      expect(c.createdAt, DateTime.utc(2026, 10, 27, 18, 20, 54, 327));
      expect(c.inviteStatus, isNull);

      final inv = page.items[1];
      expect(inv.type, NotificationType.employeeGymInvite);
      expect(inv.body, isNull);
      expect(inv.isRead, isTrue);
      expect(inv.inviteStatus, InviteStatus.pending);
      expect(inv.gymId, gymId);
      expect(inv.entityName, 'Ironclad Fitness');
      expect(inv.employeeType, 'employee_trainer');

      expect(page.items[2].type, NotificationType.news, reason: 'unknown types fall back to news');
      expect(page.items[2].metadata, isNull);
    });

    test('getNotifications: paging, unread_only only when true, encoded user id', () async {
      backend().on('GET /notifications', ok({'items': [], 'unread_count': 0}));
      final page = await ctx.api().getNotifications(token, userId: 'a b/c', page: 2, pageSize: 50, unreadOnly: true);
      final r = backend().only;
      expectGet(r, '/notifications', {'user_id': 'a b/c', 'page': '2', 'page_size': '50', 'unread_only': 'true'});
      expect(r.url.query, startsWith('user_id=a%20b%2Fc&'));
      expect(page.items, isEmpty);
      expect(page.unreadCount, 0);
    });

    test('markNotificationRead POSTs /:id/read without a body', () async {
      backend().on('POST /notifications/$notifId/read', ok({...commentNotif, 'is_read': true}));
      final n = await ctx.api().markNotificationRead(token, notifId);
      expectJson(backend().only, 'POST', '/notifications/$notifId/read', null);
      expect(n.isRead, isTrue);
    });

    test('acceptInvite POSTs /:id/accept and returns the updated invite', () async {
      backend().on('POST /notifications/n-invite/accept', ok({
        ...inviteNotif,
        'metadata': {...inviteNotif['metadata'] as Map<String, dynamic>, 'invite_status': 'accepted'},
      }));
      final n = await ctx.api().acceptInvite(token, 'n-invite');
      expectJson(backend().only, 'POST', '/notifications/n-invite/accept', null);
      expect(n.inviteStatus, InviteStatus.accepted);
    });

    test('declineInvite POSTs /:id/decline; 409 when no longer pending', () async {
      backend().on('POST /notifications/n-invite/decline', ok({
        ...inviteNotif,
        'metadata': {...inviteNotif['metadata'] as Map<String, dynamic>, 'invite_status': 'declined'},
      }));
      final n = await ctx.api().declineInvite(token, 'n-invite');
      expectJson(backend().only, 'POST', '/notifications/n-invite/decline', null);
      expect(n.inviteStatus, InviteStatus.declined);

      backend().on('POST /notifications/n-invite/decline', err(409, 'Invite is no longer pending'));
      await expectLater(ctx.api().declineInvite(token, 'n-invite'), throwsApiError('Invite is no longer pending'));
    });

    test('markAllNotificationsRead POSTs /notifications/mark-all-read', () async {
      backend().on('POST /notifications/mark-all-read', ok({'updated': 11}));
      await ctx.api().markAllNotificationsRead(token);
      expectJson(backend().only, 'POST', '/notifications/mark-all-read', null);
    });

    test('deleteNotification DELETEs /notifications/:id', () async {
      backend().on('DELETE /notifications/$notifId', ok('', 204));
      await ctx.api().deleteNotification(token, notifId);
      expectDelete(backend().only, '/notifications/$notifId');
    });
  });

  group('posts', () {
    test('getPosts parses author, business, media, reactions', () async {
      backend().on('GET /posts', ok([postJson]));
      final p = (await ctx.api().getPosts(token, businessId: gymId)).single;
      expectGet(backend().only, '/posts', {'business_id': gymId, 'page': '0', 'page_size': '20'});

      expect(p.id, postId);
      expect(p.businessId, gymId);
      expect(p.isPersonal, isFalse);
      expect(p.authorId, marcusId);
      expect(p.content, startsWith('Thank you to everyone'));
      expect(p.visibility, PostVisibility.public);
      expect(p.createdAt, DateTime.utc(2026, 9, 15, 16, 6, 25, 312));
      expect(p.updatedAt, DateTime.utc(2026, 9, 15, 16, 6, 25, 312));
      expect(p.author!.id, marcusId);
      expect(p.author!.username, 'marcusbennett');
      expect(p.author!.name, 'Marcus');
      expect(p.author!.lastName, 'Bennett');
      expect(p.business!.id, gymId);
      expect(p.business!.name, 'Ironclad Fitness');
      expect(p.business!.type, 'gym');

      expect(p.images, hasLength(2), reason: 'media without a url is dropped');
      final img = p.images[0];
      expect(img.id, '024cf71e-f036-4864-8465-ac6f9aa1fdde');
      expect(img.postId, postId);
      expect(img.isVideo, isFalse);
      expect(img.aspectRatio, isNull);
      final vid = p.images[1];
      expect(vid.url, '${AppConfig.supabaseOrigin}/storage/v1/object/sign/media/posts/run.mp4?token=redacted');
      expect(vid.isVideo, isTrue);
      expect(vid.position, 1);
      expect(vid.width, 1080);
      expect(vid.height, 1920);
      expect(vid.durationMs, 15200);
      expect(p.imageUrl, img.url);

      expect(p.reactions.counts, {ReactionType.like: 6, ReactionType.fire: 2});
      expect(p.reactions.total, 8);
      expect(p.reactions.top, [ReactionType.like, ReactionType.fire]);
      expect(p.myReaction, ReactionType.fire);
      expect(p.commentCount, 3);
      expect(p.canEdit, isTrue);
    });

    test('getPosts: legacy like_count/liked_by_me when reactions are absent; paging', () async {
      final legacy = Map.of(postJson)
        ..remove('reactions')
        ..remove('my_reaction')
        ..remove('can_edit')
        ..['images'] = <Object>[]
        ..['like_count'] = '4'
        ..['comment_count'] = 0;
      backend().on('GET /posts', ok([legacy]));
      final p = (await ctx.api().getPosts(token, businessId: gymId, page: 3, pageSize: 5)).single;
      expectGet(backend().only, '/posts', {'business_id': gymId, 'page': '3', 'page_size': '5'});
      expect(p.reactions.total, 4);
      expect(p.reactions.counts, {ReactionType.like: 4});
      expect(p.myReaction, ReactionType.like);
      expect(p.canEdit, isFalse);
      expect(p.images, isEmpty);
      expect(p.imageUrl, isNull);
    });

    test('createPost POSTs business_id, content and images', () async {
      final body = {
        'business_id': gymId,
        'content': 'New class schedule is up!',
        'images': [
          {'url': 'https://example.com/a.jpg', 'position': 0},
          {'url': 'https://example.com/b.jpg', 'position': 1},
        ],
      };
      backend().on('POST /posts', ok({
        ...postJson,
        'id': 'p-new',
        'content': 'New class schedule is up!',
        'reactions': {'counts': {}, 'total': 0, 'top': []},
        'my_reaction': null,
        'comment_count': 0,
        'like_count': 0,
        'liked_by_me': false,
      }, 201));
      final p = await ctx.api().createPost(token, body);
      expectJson(backend().only, 'POST', '/posts', body);
      expect(p.id, 'p-new');
      expect(p.reactions.total, 0);
      expect(p.myReaction, isNull);
    });

    test('updatePost PUTs /posts/:id', () async {
      final body = {'content': 'Edited', 'images': <Object>[]};
      backend().on('PUT /posts/$postId', ok({...postJson, 'content': 'Edited', 'images': []}));
      final p = await ctx.api().updatePost(token, postId, body);
      expectJson(backend().only, 'PUT', '/posts/$postId', body);
      expect(p.content, 'Edited');
      expect(p.images, isEmpty);
    });

    test('deletePost DELETEs /posts/:id', () async {
      backend().on('DELETE /posts/$postId', ok('', 204));
      await ctx.api().deletePost(token, postId);
      expectDelete(backend().only, '/posts/$postId');
    });
  });

  errorTests(ctx, {
    'getNotifications': ('GET /notifications', (api) => api.getNotifications(token, userId: liamId)),
    'markNotificationRead': ('POST /notifications/$notifId/read', (api) => api.markNotificationRead(token, notifId)),
    'acceptInvite': ('POST /notifications/$notifId/accept', (api) => api.acceptInvite(token, notifId)),
    'declineInvite': ('POST /notifications/$notifId/decline', (api) => api.declineInvite(token, notifId)),
    'markAllNotificationsRead': ('POST /notifications/mark-all-read', (api) => api.markAllNotificationsRead(token)),
    'deleteNotification': ('DELETE /notifications/$notifId', (api) => api.deleteNotification(token, notifId)),
    'getPosts': ('GET /posts', (api) => api.getPosts(token, businessId: gymId)),
    'createPost': ('POST /posts', (api) => api.createPost(token, {'content': 'x'})),
    'updatePost': ('PUT /posts/$postId', (api) => api.updatePost(token, postId, {'content': 'x'})),
    'deletePost': ('DELETE /posts/$postId', (api) => api.deletePost(token, postId)),
  });
}
