import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/draft.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/drafts.dart';
import '../widgets/image_upload_field.dart';
import '../widgets/post_card.dart';

/// Community feed for a gym or shop. Staff (owners/trainers/employees/vendors)
/// can post announcements; everyone with access to the business can read,
/// react and comment (threaded, in [PostCard] → PostDetailPage).
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
  static const _pageSize = 20;

  final _api = ApiService();
  final _scroll = ScrollController();
  List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 0;
  int _gen = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 800) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _load() async {
    final gen = ++_gen;
    setState(() {
      _loading = _posts.isEmpty;
      _loadingMore = false;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final posts = await _api.getPosts(token, businessId: widget.businessId, pageSize: _pageSize);
      if (!mounted || gen != _gen) return;
      setState(() {
        _posts = posts;
        _page = 0;
        _hasMore = posts.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = _msg(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final gen = _gen;
    setState(() => _loadingMore = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final posts = await _api.getPosts(token, businessId: widget.businessId, page: _page + 1, pageSize: _pageSize);
      if (!mounted || gen != _gen) return;
      final known = _posts.map((p) => p.id).toSet();
      setState(() {
        _posts = [..._posts, ...posts.where((p) => !known.contains(p.id))];
        _page++;
        _hasMore = posts.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  void _replace(Post updated) {
    if (!mounted) return;
    setState(() => _posts = [for (final p in _posts) p.id == updated.id ? updated : p]);
  }

  void _remove(String id) {
    if (!mounted) return;
    setState(() => _posts = _posts.where((p) => p.id != id).toList());
  }

  Future<void> _openCreatePost() async {
    final created = await openCreateWithDrafts<Post>(
      context,
      kind: DraftKind.businessPost,
      scopeId: widget.businessId,
      builder: (draft) => _PostFormPage(businessId: widget.businessId, draft: draft),
    );
    if (created != null && mounted) {
      setState(() => _posts = [created, ..._posts.where((p) => p.id != created.id)]);
    }
  }

  Future<void> _openEditPost(Post post) async {
    final saved = await Navigator.push<Post>(
      context,
      MaterialPageRoute(builder: (_) => _PostFormPage(businessId: widget.businessId, post: post)),
    );
    if (saved != null) _replace(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nutritionCommunityTitle(widget.businessName))),
      floatingActionButton: widget.canPost
          ? FloatingActionButton.extended(
              onPressed: _openCreatePost,
              icon: const Icon(Icons.add),
              label: Text(l10n.nutritionNewPost),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: cs.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: Text(context.l10n.commonRetry)),
            ],
          ),
        ),
      );
    }
    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
            Icon(Icons.forum_outlined, size: 48, color: cs.outline),
            const SizedBox(height: 16),
            Center(child: Text(context.l10n.nutritionNoPostsYet)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 88),
        itemCount: _posts.length + 1,
        itemBuilder: (context, i) {
          if (i == _posts.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _loadingMore
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const SizedBox.shrink(),
              ),
            );
          }
          final post = _posts[i];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: PostCard(
                key: ValueKey(post.id),
                post: post,
                onChanged: _replace,
                onDeleted: () => _remove(post.id),
                // Business posts edit text + images in their own form.
                onEdit: () => _openEditPost(post),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Create a post, or edit [post]'s text and images when given.
class _PostFormPage extends StatefulWidget {
  const _PostFormPage({required this.businessId, this.post, this.draft});
  final String businessId;
  final Post? post;

  /// A saved draft to continue (new posts only).
  final Draft? draft;

  @override
  State<_PostFormPage> createState() => _PostFormPageState();
}

class _PostFormPageState extends State<_PostFormPage> with DraftableForm {
  final _api = ApiService();
  late final TextEditingController _contentCtrl;
  late final List<String> _imageUrls;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.post != null;

  // ── Drafts ──────────────────────────────────────────────────────────────────

  @override
  DraftKind get draftKind => DraftKind.businessPost;
  @override
  Draft? get initialDraft => widget.draft;
  @override
  bool get draftsEnabled => !_isEditing;
  @override
  String? get draftScopeId => widget.businessId;
  @override
  bool get hasDraftContent => _contentCtrl.text.trim().isNotEmpty || _imageUrls.isNotEmpty;
  @override
  String? draftTitle() => _contentCtrl.text;
  @override
  String? draftThumbnailUrl() => _imageUrls.firstOrNull;
  @override
  Map<String, dynamic> draftData() => {
        'content': _contentCtrl.text,
        'image_urls': [..._imageUrls],
      };

  @override
  void initState() {
    super.initState();
    final draft = widget.draft?.data;
    if (draft != null && !_isEditing) {
      final content = draft['content'];
      final images = draft['image_urls'];
      _contentCtrl = TextEditingController(text: content is String ? content : '');
      _imageUrls = [
        for (final url in images is List ? images : const [])
          if (url is String && url.isNotEmpty) url,
      ];
      return;
    }
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
      setState(() => _error = context.l10n.nutritionWriteSomethingFirst);
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
      final Post saved;
      if (_isEditing) {
        saved = await _api.updatePost(token, widget.post!.id, {
          'content': _contentCtrl.text.trim(),
          'images': images,
        });
      } else {
        saved = await _api.createPost(token, {
          'business_id': widget.businessId,
          'content': _contentCtrl.text.trim(),
          'images': images,
        });
        await draftPublished();
      }
      if (mounted) Navigator.pop(context, saved);
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
    final l10n = context.l10n;
    final banner = draftBanner(context);
    return draftPopScope(
      busy: _saving,
      child: Scaffold(
        appBar: AppBar(title: Text(_isEditing ? l10n.nutritionEditPostTitle : l10n.nutritionNewPost)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (banner != null) ...[banner, const SizedBox(height: 16)],
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
                                  semanticLabel: l10n.nutritionPostPhotoOf(e.key + 1, _imageUrls.length),
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
                                top: 0,
                                right: 0,
                                child: Semantics(
                                  button: true,
                                  label: l10n.nutritionRemovePhoto,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () =>
                                        setState(() => _imageUrls.removeAt(e.key)),
                                    // 48 dp hit area around the small badge.
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Align(
                                        alignment: Alignment.topRight,
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: CircleAvatar(
                                            radius: 12,
                                            backgroundColor: cs.inverseSurface.withValues(alpha: 0.7),
                                            child: Icon(Icons.close,
                                                size: 14, color: cs.onInverseSurface),
                                          ),
                                        ),
                                      ),
                                    ),
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
                                  Text(l10n.nutritionAddPhoto,
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
                decoration: InputDecoration(
                  labelText: l10n.nutritionShareHint,
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                maxLength: kCaptionMaxLength,
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? l10n.commonSave : l10n.nutritionPostAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
