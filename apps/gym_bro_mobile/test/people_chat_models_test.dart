import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/config.dart';
import 'package:gym_bro_mobile/models/chat.dart';
import 'package:gym_bro_mobile/models/people.dart';
import 'package:gym_bro_mobile/models/post.dart';
import 'package:gym_bro_mobile/models/reaction.dart';
import 'package:gym_bro_mobile/models/social.dart';

void main() {
  group('ReactionSummary', () {
    final summary = ReactionSummary.fromJson({
      'counts': {'like': 3, 'fire': 1, 'nope': 9},
      'total': 4,
      'top': ['like', 'fire'],
    });

    test('parses known reactions and ignores unknown ones', () {
      expect(summary.counts, {ReactionType.like: 3, ReactionType.fire: 1});
      expect(summary.total, 4);
      expect(summary.top, [ReactionType.like, ReactionType.fire]);
    });

    test('switching a reaction moves one count and re-ranks', () {
      final s = summary.switched(ReactionType.like, ReactionType.fire);
      expect(s.counts, {ReactionType.like: 2, ReactionType.fire: 2});
      expect(s.total, 4);
      // Ties keep the canonical order (like before fire).
      expect(s.top, [ReactionType.like, ReactionType.fire]);
    });

    test('adding and removing change the total; empty types disappear', () {
      expect(summary.switched(null, ReactionType.love).total, 5);
      final removed = summary.switched(ReactionType.fire, null);
      expect(removed.total, 3);
      expect(removed.counts.containsKey(ReactionType.fire), isFalse);
      expect(removed.top, [ReactionType.like]);
    });

    test('never goes below zero', () {
      expect(ReactionSummary.empty.switched(ReactionType.like, null).total, 0);
    });
  });

  test('Post reads reactions, visibility and personal media', () {
    final p = Post.fromJson({
      'id': 'p1',
      'business_id': null,
      'author_id': 'u1',
      'content': 'PR!',
      'visibility': 'followers',
      'created_at': '2026-10-20T10:00:00Z',
      'updated_at': '2026-10-20T10:00:00Z',
      'images': [
        {
          'id': 'i1',
          'post_id': 'p1',
          'url': '/storage/v1/object/sign/user-media/u1/a.mp4?token=x',
          'position': 0,
          'media_type': 'video',
          'width': 1280,
          'height': 720,
        },
      ],
      'reactions': {'counts': {'strong': 2}, 'total': 2, 'top': ['strong']},
      'my_reaction': 'strong',
      'comment_count': 1,
    });
    expect(p.isPersonal, isTrue);
    expect(p.visibility, PostVisibility.followers);
    expect(p.myReaction, ReactionType.strong);
    expect(p.likeCount, 2);
    expect(p.images.single.isVideo, isTrue);
    expect(p.images.single.url, startsWith(AppConfig.supabaseOrigin));
    final cleared = p.withMyReaction(null);
    expect(cleared.myReaction, isNull);
    expect(cleared.reactions.total, 1);
  });

  test('PostComment reads thread fields', () {
    final c = PostComment.fromJson({
      'id': 'c2',
      'post_id': 'p1',
      'parent_id': 'c1',
      'depth': 9,
      'author_id': null,
      'author': null,
      'body': null,
      'created_at': '2026-10-20T10:00:00Z',
      'updated_at': '2026-10-20T10:00:00Z',
      'deleted': true,
      'reply_count': 2,
      'reactions': {'counts': {}, 'total': 0, 'top': []},
      'my_reaction': null,
      'can_reply': false,
    });
    expect(c.parentId, 'c1');
    expect(c.depth, kMaxCommentDepth);
    expect(c.deleted, isTrue);
    expect(c.body, '');
    expect(c.replyCount, 2);
    expect(c.withMyReaction(ReactionType.haha).reactions.total, 1);
  });

  test('PublicProfile reads relationship, counts and reasons', () {
    final p = PublicProfile.fromJson({
      'id': 'u2',
      'username': 'sofiarossi',
      'name': 'Sofia',
      'last_name': 'Rossi',
      'is_private': true,
      'is_me': false,
      'counts': {'posts': 2, 'followers': '7', 'following': 5, 'friends': 1},
      'relationship': {'following': 'pending', 'followed_by': 'accepted', 'friendship': 'incoming', 'blocked': false},
      'can_view_content': false,
      'message_status': 'request',
      'mutual_friends': {'count': 3, 'preview': [{'id': 'u3', 'username': 'k', 'name': 'Kenji', 'last_name': 'T'}]},
      'gyms': [{'id': 'g1', 'name': 'Ironclad Fitness'}],
    });
    expect(p.relationship!.following, FollowState.pending);
    expect(p.relationship!.followedBy, FollowState.accepted);
    expect(p.relationship!.friendship, FriendState.incoming);
    expect(p.counts.followers, 7);
    expect(p.canViewContent, isFalse);
    expect(p.mutualFriendsPreview.single.name, 'Kenji');

    final s = Suggestion.fromJson({
      'id': 'u4',
      'username': 'maya',
      'name': 'Maya',
      'last_name': 'Flores',
      'score': 99.5,
      'reasons': [
        {'type': 'same_gym', 'gyms': ['Summit']},
        {'type': 'nearby', 'km': 3},
        {'type': 'something_new'},
      ],
    });
    expect(s.reasons, hasLength(2));
    expect(s.reasons.first, isA<SameGymReason>());
    expect((s.reasons.last as NearbyReason).km, 3);
  });

  test('ChatMessage reads attachments, reactions and replies', () {
    final m = ChatMessage.fromJson({
      'id': 'm1',
      'conversation_id': 'c1',
      'sender_id': 'u1',
      'sender': {'id': 'u1', 'username': 'liam', 'name': 'Liam', 'last_name': "O'Connor"},
      'kind': 'media',
      'body': 'pic',
      'client_id': 'abc',
      'metadata': {},
      'created_at': '2026-10-20T10:00:00Z',
      'attachments': [
        {'id': 'a1', 'url': '/storage/v1/object/sign/chat-media/c1/x.png?token=t', 'mime_type': 'image/png', 'media_type': 'image', 'size_bytes': '42', 'width': 2, 'height': 1},
      ],
      'reactions': [
        {'user_id': 'u2', 'reaction': 'love'},
        {'user_id': 'u3', 'reaction': 'unknown'},
      ],
      'reply_to': {'id': 'm0', 'sender_name': 'Kenji Tanaka', 'body': 'hey', 'media_type': null, 'deleted': false},
    });
    expect(m.attachments.single.type, AttachmentType.image);
    expect(m.attachments.single.sizeBytes, 42);
    expect(m.attachments.single.aspectRatio, 2);
    expect(m.attachments.single.url, startsWith(AppConfig.supabaseOrigin));
    expect(m.reactions, hasLength(1));
    expect(m.reactionOf('u2'), ReactionType.love);
    expect(m.replyTo!.body, 'hey');
  });

  test('Conversation titles fall back to people', () {
    final direct = Conversation.fromJson({
      'id': 'c1',
      'kind': 'direct',
      'last_message_at': '2026-10-20T10:00:00Z',
      'other_user': {'id': 'u2', 'username': 'k', 'name': 'Kenji', 'last_name': 'Tanaka'},
      'participants': [],
      'unread_count': 2,
      'my_status': 'request',
    });
    expect(direct.displayTitle('Chat'), 'Kenji Tanaka');
    expect(direct.isRequest, isTrue);
    final group = Conversation.fromJson({
      'id': 'c2',
      'kind': 'group',
      'title': null,
      'last_message_at': '2026-10-20T10:00:00Z',
      'participants': [
        {'id': 'u2', 'name': 'Kenji', 'last_name': 'T'},
        {'id': 'u3', 'name': 'Daniel', 'last_name': 'K'},
      ],
      'my_role': 'admin',
    });
    expect(group.displayTitle('Group'), 'Kenji, Daniel');
    expect(group.myRole.isAdmin, isTrue);
  });

  test('AttachmentType from MIME', () {
    expect(AttachmentType.fromMime('video/quicktime'), AttachmentType.video);
    expect(AttachmentType.fromMime('audio/mp4'), AttachmentType.audio);
    expect(AttachmentType.fromMime('application/pdf'), AttachmentType.file);
  });

  test('resolveUrl leaves absolute URLs alone', () {
    expect(AppConfig.resolveUrl('https://x.test/a.png'), 'https://x.test/a.png');
    expect(AppConfig.resolveUrl('/storage/v1/x'), '${AppConfig.supabaseOrigin}/storage/v1/x');
  });
}
