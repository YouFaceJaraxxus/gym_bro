import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/user_profile.dart';
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
      MaterialPageRoute(builder: (_) => _PostFormPage(businessId: widget.businessId)),
    );
    if (created == true) _load();
  }

  Future<void> _openEditPost(Post post) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _PostFormPage(businessId: widget.businessId, post: post),
      ),
    );
    if (saved == true) _load();
  }

  /// The API lets only the author (or a super user) edit or delete a post.
  bool _canManage(Post post) {
    final profile = AuthManager.instance.profile;
    if (profile == null) return false;
    return profile.role == UserRole.superUser ||
        (post.authorId != null && post.authorId == profile.id);
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
          canManage: _canManage(_posts[i]),
          onEdit: () => _openEditPost(_posts[i]),
          onDelete: () => _delete(_posts[i]),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final Post post;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.images.length == 1)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                post.images.first.url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            )
          else if (post.images.length > 1)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: PageView(
                children: post.images
                    .map((img) => Image.network(
                          img.url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const SizedBox.shrink(),
                        ))
                    .toList(),
              ),
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
                    if (post.images.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '${post.images.length} photos',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (canManage) ...[
                      IconButton(
                        tooltip: 'Edit post',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: onEdit,
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        tooltip: 'Delete post',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: onDelete,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(post.content),
                if (post.updatedAt.difference(post.createdAt).inMinutes >= 1) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Edited',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.outline),
                  ),
                ],
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

/// Create a post, or edit [post]'s text and images when given.
class _PostFormPage extends StatefulWidget {
  const _PostFormPage({required this.businessId, this.post});
  final String businessId;
  final Post? post;

  @override
  State<_PostFormPage> createState() => _PostFormPageState();
}

class _PostFormPageState extends State<_PostFormPage> {
  final _api = ApiService();
  late final TextEditingController _contentCtrl;
  late final List<String> _imageUrls;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.post != null;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: widget.post?.content ?? '');
    final images = [...?widget.post?.images]
      ..sort((a, b) => a.position.compareTo(b.position));
    _imageUrls = images.map((i) => i.url).toList();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    await pickAndUploadImage(
      context: context,
      bucket: 'media',
      folder: 'posts',
      onUploaded: (url) {
        if (mounted) setState(() => _imageUrls.add(url));
      },
      onUploadingChanged: (v) {
        if (mounted) setState(() => _uploading = v);
      },
    );
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
      final images = _imageUrls
          .asMap()
          .entries
          .map((e) => {'url': e.value, 'position': e.key})
          .toList();
      if (_isEditing) {
        await _api.updatePost(token, widget.post!.id, {
          'content': _contentCtrl.text.trim(),
          'images': images,
        });
      } else {
        await _api.createPost(token, {
          'business_id': widget.businessId,
          'content': _contentCtrl.text.trim(),
          'images': images,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Post' : 'New Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._imageUrls.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                e.value,
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => Container(
                                  width: 110,
                                  height: 110,
                                  color: cs.surfaceContainerHighest,
                                  child: const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _imageUrls.removeAt(e.key)),
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.close,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _uploading || _saving ? null : _addPhoto,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _uploading
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    color: cs.onSurfaceVariant),
                                const SizedBox(height: 4),
                                Text('Add photo',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
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
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving || _uploading ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEditing ? 'Save' : 'Post'),
            ),
          ],
        ),
      ),
    );
  }
}
