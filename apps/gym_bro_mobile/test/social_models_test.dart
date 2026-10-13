import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gym_bro_mobile/models/post.dart';
import 'package:gym_bro_mobile/models/social.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final sr = lookupAppLocalizations(const Locale('sr'));
  setUpAll(() => initializeDateFormatting());

  final json = {
    'id': 'p1',
    'business_id': 'b1',
    'author_id': 'u1',
    'content': 'Hello',
    'created_at': '2026-09-15T16:06:25.315Z',
    'updated_at': '2026-09-15T16:06:25.315Z',
    'images': [],
    'author': {'id': 'u1', 'name': 'Elena', 'last_name': 'Vasquez', 'avatar_url': null},
    'like_count': '3',
    'comment_count': 2,
    'liked_by_me': false,
  };

  test('Post parses social fields', () {
    final p = Post.fromJson(json);
    expect(p.likeCount, 3);
    expect(p.commentCount, 2);
    expect(p.likedByMe, isFalse);
    expect(p.author!.fullName, 'Elena Vasquez');
  });

  test('Post without social fields defaults to zero / not liked', () {
    final p = Post.fromJson({...json}
      ..remove('like_count')
      ..remove('comment_count')
      ..remove('liked_by_me')
      ..remove('author'));
    expect(p.likeCount, 0);
    expect(p.commentCount, 0);
    expect(p.likedByMe, isFalse);
    expect(p.author, isNull);
  });

  test('toggledLike flips state and count, never below zero', () {
    final p = Post.fromJson(json);
    final liked = p.toggledLike();
    expect(liked.likedByMe, isTrue);
    expect(liked.likeCount, 4);
    final unliked = liked.toggledLike();
    expect(unliked.likedByMe, isFalse);
    expect(unliked.likeCount, 3);
    final weird = p.copyWith(likedByMe: true, likeCount: 0).toggledLike();
    expect(weird.likeCount, 0);
  });

  test('PostComment parses permissions and deleted authors', () {
    final c = PostComment.fromJson({
      'id': 'c1',
      'post_id': 'p1',
      'author_id': null,
      'author': null,
      'body': 'Nice',
      'created_at': '2026-10-13T07:08:50.250Z',
      'updated_at': '2026-10-13T07:10:50.250Z',
      'can_edit': false,
      'can_delete': true,
    });
    expect(c.authorName(l10n), 'Deleted user');
    expect(c.canEdit, isFalse);
    expect(c.canDelete, isTrue);
    expect(c.isEdited, isTrue);
  });

  test('relativeTime', () {
    final now = DateTime(2026, 10, 13, 12);
    expect(relativeTime(l10n, now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
    expect(relativeTime(l10n, now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
    expect(relativeTime(l10n, now.subtract(const Duration(hours: 3)), now: now), '3h ago');
    expect(relativeTime(l10n, now.subtract(const Duration(days: 2)), now: now), '2d ago');
    expect(relativeTime(l10n, DateTime(2026, 9, 1), now: now), '9/1/2026');
  });

  test('relativeTime in Serbian', () {
    final now = DateTime(2026, 10, 13, 12);
    expect(relativeTime(sr, now.subtract(const Duration(minutes: 5)), now: now), 'pre 5 min');
    expect(relativeTime(sr, now.subtract(const Duration(days: 1)), now: now), 'pre 1 dan');
    expect(relativeTime(sr, now.subtract(const Duration(days: 3)), now: now), 'pre 3 dana');
    expect(relativeTime(sr, DateTime(2026, 9, 1), now: now), '1. 9. 2026.');
  });
}
