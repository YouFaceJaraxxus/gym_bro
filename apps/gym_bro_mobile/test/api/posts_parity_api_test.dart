import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/post.dart';
import 'package:gym_bro_mobile/services/api_service.dart';

import '../helpers/fake_backend.dart';
import 'api_test_utils.dart';

Map<String, dynamic> _post([Map<String, dynamic> extra = const {}]) => {
  'id': 'p1',
  'business_id': null,
  'author_id': 'u1',
  'content': 'x',
  'created_at': '2026-10-26T13:37:54.327Z',
  'updated_at': '2026-10-26T13:37:54.327Z',
  'images': [],
  ...extra,
};

void main() {
  final fake = useFakeBackend();
  FakeBackend backend() => fake.backend();
  ApiService api() => fake.api();

  group('feed modes', () {
    test('mode wins over explore; explore still works', () async {
      backend().on('GET /posts/feed', ok([]));
      await api().getFeed(token, mode: FeedMode.reels, page: 1, pageSize: 10);
      await api().getFeed(token, explore: true);
      expectGet(backend().requests[0], '/posts/feed', {'mode': 'reels', 'page': '1', 'page_size': '10'});
      expectGet(backend().requests[1], '/posts/feed', {'mode': 'explore', 'page': '0', 'page_size': '20'});
    });
  });

  group('post settings', () {
    test('createPersonalPost sends settings only when set', () async {
      backend().on('POST /posts', ok(_post({'hide_like_count': true}), 201));
      await api().createPersonalPost(
        token,
        caption: 'c',
        visibility: PostVisibility.public,
        hideLikeCount: true,
        commentsDisabled: false,
        locationName: '  Belgrade ',
      );
      await api().createPersonalPost(token, caption: 'c', visibility: PostVisibility.public, locationName: '  ');
      expect(bodyOf(backend().requests[0]), {
        'content': 'c',
        'visibility': 'public',
        'media': [],
        'hide_like_count': true,
        'comments_disabled': false,
        'location_name': 'Belgrade',
      });
      expect(bodyOf(backend().requests[1]), {'content': 'c', 'visibility': 'public', 'media': []});
    });

    test('updatePost: a blank location clears it (null), omitted keys stay out', () async {
      backend().on('PUT /posts/p1', ok(_post()));
      await SocialApi(api()).updatePost(token, 'p1', locationName: '');
      await SocialApi(api()).updatePost(token, 'p1', commentsDisabled: true, locationName: 'Gym');
      await SocialApi(api()).updatePost(token, 'p1', hideLikeCount: false);
      expectJson(backend().requests[0], 'PUT', '/posts/p1', {'location_name': null});
      expectJson(backend().requests[1], 'PUT', '/posts/p1', {'comments_disabled': true, 'location_name': 'Gym'});
      expectJson(backend().requests[2], 'PUT', '/posts/p1', {'hide_like_count': false});
    });
  });

  group('pins', () {
    test('pinPost PUTs /posts/:id/pin; 409 pin_limit is typed', () async {
      backend().on('PUT /posts/p1/pin', ok(_post({'pinned': true})));
      final p = await api().pinPost(token, 'p1');
      expect(p.pinned, isTrue);
      expect(backend().only.method, 'PUT');

      backend().on('PUT /posts/p2/pin', err(409, 'Up to 3 posts can be pinned', code: 'pin_limit'));
      await expectLater(api().pinPost(token, 'p2'), throwsA(isA<PostPinLimitException>()));
    });

    test('unpinPost DELETEs', () async {
      backend().on('DELETE /posts/p1/pin', ok(_post({'pinned': false})));
      final p = await api().unpinPost(token, 'p1');
      expect(p.pinned, isFalse);
      expectDelete(backend().only, '/posts/p1/pin');
    });
  });

  group('saved posts', () {
    test('save (into a collection), unsave', () async {
      backend().on('PUT /posts/p1/save', ok({'post_id': 'p1', 'saved': true}));
      backend().on('DELETE /posts/p1/save', ok({'post_id': 'p1', 'saved': false}));
      await api().savePost(token, 'p1');
      await api().savePost(token, 'p1', collectionId: 'c1');
      await api().unsavePost(token, 'p1');
      expectJson(backend().requests[0], 'PUT', '/posts/p1/save', <String, dynamic>{});
      expectJson(backend().requests[1], 'PUT', '/posts/p1/save', {'collection_id': 'c1'});
      expectDelete(backend().requests[2], '/posts/p1/save');
    });

    test('getSavedPosts pages, optionally one collection', () async {
      backend().on('GET /posts/saved', ok([_post({'saved_by_me': true})]));
      final posts = await api().getSavedPosts(token);
      await api().getSavedPosts(token, collectionId: 'c1', page: 2, pageSize: 12);
      expect(posts.single.savedByMe, isTrue);
      expectGet(backend().requests[0], '/posts/saved', {'page': '0', 'page_size': '30'});
      expectGet(backend().requests[1], '/posts/saved', {'page': '2', 'page_size': '12', 'collection_id': 'c1'});
    });

    test('collections: overview, create, rename, delete, file, unfile', () async {
      final col = {'id': 'c1', 'name': 'Gains', 'post_count': 1, 'covers': []};
      backend().on('GET /posts/collections', ok({'saved': {'post_count': 1, 'covers': []}, 'post_saved': true, 'collections': [{...col, 'contains_post': true}]}));
      backend().on('POST /posts/collections', ok(col, 201));
      backend().on('PUT /posts/collections/c1', ok({...col, 'name': 'Cut'}));
      backend().on('DELETE /posts/collections/c1', ok(null, 204));
      backend().on('PUT /posts/collections/c1/posts/p1', ok({'post_id': 'p1', 'collection_id': 'c1', 'saved': true}));
      backend().on('DELETE /posts/collections/c1/posts/p1', ok(null, 204));

      final o = await api().getSaveCollections(token, postId: 'p1');
      expect(o.postSaved, isTrue);
      expect(o.collections.single.containsPost, isTrue);
      expectGet(backend().requests[0], '/posts/collections', {'post_id': 'p1'});

      final created = await api().createSaveCollection(token, 'Gains', postIds: ['p1']);
      expect(created.name, 'Gains');
      expectJson(backend().requests[1], 'POST', '/posts/collections', {'name': 'Gains', 'post_ids': ['p1']});

      final renamed = await api().renameSaveCollection(token, 'c1', 'Cut');
      expect(renamed.name, 'Cut');
      expectJson(backend().requests[2], 'PUT', '/posts/collections/c1', {'name': 'Cut'});

      await api().addToSaveCollection(token, 'c1', 'p1');
      await api().removeFromSaveCollection(token, 'c1', 'p1');
      await api().deleteSaveCollection(token, 'c1');
      expect(describe(backend().requests[3]), 'PUT /posts/collections/c1/posts/p1');
      expectDelete(backend().requests[4], '/posts/collections/c1/posts/p1');
      expectDelete(backend().requests[5], '/posts/collections/c1');
    });

    test('409 on a duplicate collection name surfaces the message', () async {
      backend().on('POST /posts/collections', err(409, 'You already have a collection with that name'));
      await expectLater(
        api().createSaveCollection(token, 'gains'),
        throwsApiError('You already have a collection with that name'),
      );
    });
  });

  group('liked posts and hashtags', () {
    test('getLikedPosts', () async {
      backend().on('GET /posts/liked', ok([_post()]));
      final posts = await api().getLikedPosts(token, page: 1);
      expect(posts, hasLength(1));
      expectGet(backend().only, '/posts/liked', {'page': '1', 'page_size': '30'});
    });

    test('searchHashtags, getHashtag, getHashtagPosts', () async {
      backend().on('GET /posts/hashtags', ok([{'tag': 'legday', 'post_count': 4}]));
      backend().on('GET /posts/hashtags/legday', ok({'tag': 'legday', 'post_count': '4'}));
      backend().on('GET /posts', ok([_post()]));

      final found = await api().searchHashtags(token, '#leg');
      expect(found.single.tag, 'legday');
      expectGet(backend().requests[0], '/posts/hashtags', {'q': '#leg'});

      final info = await api().getHashtag(token, 'legday');
      expect(info.postCount, 4);

      final posts = await api().getHashtagPosts(token, 'legday', sort: 'recent', page: 2);
      expect(posts, hasLength(1));
      expectGet(backend().requests[2], '/posts', {'hashtag': 'legday', 'sort': 'recent', 'page': '2', 'page_size': '30'});
    });
  });
}
