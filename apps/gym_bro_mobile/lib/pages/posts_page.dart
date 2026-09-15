import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/image_upload_field.dart';

/// Community feed for a gym or shop. Staff (owners/trainers/employees/vendors)
/// can post announcements; everyone with access to the business can read them.
class PostsPage extends StatefulWidget {
  const PostsPage({
    super.key,
    required this.businessId,
    required this.businessName,
    this.canPost = false,
  });

  final String businessId;
  final String businessName;
  final bool canPost;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  final _api = ApiService();
  List<Post> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final posts = await _api.getPosts(token, businessId: widget.businessId);
      if (mounted) setState(() { _posts = posts; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _openCreatePost() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _CreatePostPage(businessId: widget.businessId)),
    );
    if (created == true) _load();
  }

  Future<void> _delete(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deletePost(token, post.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.businessName} · Community')),
      floatingActionButton: widget.canPost
          ? FloatingActionButton.extended(
              onPressed: _openCreatePost,
              icon: const Icon(Icons.add),
              label: const Text('New Post'),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text('No posts yet'),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: _posts.length,
        itemBuilder: (_, i) => _PostCard(
          post: _posts[i],
          canDelete: widget.canPost,
          onDelete: () => _delete(_posts[i]),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.canDelete, required this.onDelete});

  final Post post;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.imageUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(post.imageUrl!, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _relativeTime(post.createdAt),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.outline),
                      ),
                    ),
                    if (canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: onDelete,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(post.content),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _CreatePostPage extends StatefulWidget {
  const _CreatePostPage({required this.businessId});
  final String businessId;

  @override
  State<_CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<_CreatePostPage> {
  final _api = ApiService();
  final _contentCtrl = TextEditingController();
  String? _imageUrl;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_contentCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Write something first');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.createPost(token, {
        'business_id': widget.businessId,
        'content': _contentCtrl.text.trim(),
        'images': _imageUrl != null ? [{'url': _imageUrl, 'position': 0}] : [],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ImagePickerField(
              imageUrl: _imageUrl,
              folder: 'posts',
              label: 'Add a photo (optional)',
              onUploaded: (url) => setState(() => _imageUrl = url),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentCtrl,
              decoration: const InputDecoration(
                labelText: 'What do you want to share?',
                alignLabelWithHint: true,
              ),
              maxLines: 6,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }
}
