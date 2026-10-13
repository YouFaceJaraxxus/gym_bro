part of '../api_service.dart';

/// Post comments and likes.
extension SocialApi on ApiService {
  Future<Post> getPost(String token, String postId) async {
    final r = await _client.get(
      Uri.parse('$_base/posts/$postId'),
      headers: _headers(token),
    );
    _check(r);
    return Post.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Idempotent; returns the new like count.
  Future<LikeResult> likePost(String token, String postId) async {
    final r = await _client.post(
      Uri.parse('$_base/posts/$postId/like'),
      headers: _headers(token),
    );
    _check(r);
    return LikeResult.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Idempotent; returns the new like count.
  Future<LikeResult> unlikePost(String token, String postId) async {
    final r = await _client.delete(
      Uri.parse('$_base/posts/$postId/like'),
      headers: _headers(token),
    );
    _check(r);
    return LikeResult.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Oldest first.
  Future<List<PostComment>> getPostComments(
    String token,
    String postId, {
    int page = 0,
    int pageSize = 50,
  }) async {
    final r = await _client.get(
      Uri.parse('$_base/posts/$postId/comments?page=$page&page_size=$pageSize'),
      headers: _headers(token),
    );
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => PostComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PostComment> createPostComment(
      String token, String postId, String body) async {
    final r = await _client.post(
      Uri.parse('$_base/posts/$postId/comments'),
      headers: _headers(token),
      body: jsonEncode({'body': body}),
    );
    _check(r);
    return PostComment.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<PostComment> updatePostComment(
      String token, String commentId, String body) async {
    final r = await _client.put(
      Uri.parse('$_base/posts/comments/$commentId'),
      headers: _headers(token),
      body: jsonEncode({'body': body}),
    );
    _check(r);
    return PostComment.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deletePostComment(String token, String commentId) async {
    final r = await _client.delete(
      Uri.parse('$_base/posts/comments/$commentId'),
      headers: _headers(token),
    );
    if (r.statusCode >= 400) _check(r);
  }
}
