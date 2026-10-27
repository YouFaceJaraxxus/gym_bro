import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../models/people.dart';
import '../../models/post.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/person_tile.dart';
import '../../widgets/post_grid.dart';
import '../../widgets/social_widgets.dart';
import '../chat/chat_launcher.dart';
import '../feed/post_detail_page.dart';
import 'blocked_users_page.dart';
import 'edit_social_profile_page.dart';
import 'people_common.dart';
import 'people_list_page.dart';

const _kPostsPageSize = 30;

/// Instagram-like profile of any user, including me.
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.userId});

  /// users.id of the person to show (may be me).
  final String userId;
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _api = ApiService();

  PublicProfile? _profile;
  Relationship? _rel;
  bool _loading = true;
  String? _error;

  List<Post> _posts = [];
  int _postsPage = 0;
  bool _postsHasMore = false;
  bool _postsLoading = false;
  bool _postsLoadingMore = false;
  bool _postsPrivate = false;
  String? _postsError;

  bool _actionBusy = false;
  int _refreshGen = 0;

  bool get _isMe => _profile?.isMe ?? widget.userId == AuthManager.instance.profile?.id;
  bool get _blocked => _rel?.blocked ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final token = await AuthManager.instance.getValidToken();
      final profile = await _api.getProfile(token, widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _rel = profile.relationship;
        _loading = false;
      });
      await _loadPosts();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = peopleErrorText(e);
        _loading = false;
      });
    }
  }

  /// Re-reads the profile after a relationship change (counts, visibility).
  Future<void> _refreshProfile() async {
    final gen = ++_refreshGen;
    try {
      final token = await AuthManager.instance.getValidToken();
      final profile = await _api.getProfile(token, widget.userId);
      if (!mounted || gen != _refreshGen) return;
      final couldView = _profile?.canViewContent ?? false;
      setState(() {
        _profile = profile;
        _rel = profile.relationship;
      });
      if (profile.canViewContent != couldView || _blocked) await _loadPosts();
    } catch (_) {
      // The optimistic state stays; pull-to-refresh recovers.
    }
  }

  Future<void> _loadPosts() async {
    final profile = _profile;
    if (profile == null) return;
    if (!profile.canViewContent || _blocked) {
      setState(() {
        _posts = [];
        _postsHasMore = false;
        _postsPrivate = !profile.canViewContent;
        _postsError = null;
      });
      return;
    }
    setState(() {
      _postsLoading = true;
      _postsError = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final posts = await _api.getUserPosts(token, profile.id, pageSize: _kPostsPageSize);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _postsPage = 0;
        _postsHasMore = posts.length >= _kPostsPageSize;
        _postsPrivate = false;
      });
    } on PrivateAccountException {
      if (!mounted) return;
      setState(() {
        _posts = [];
        _postsPrivate = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _postsError = peopleErrorText(e));
    } finally {
      if (mounted) setState(() => _postsLoading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    final profile = _profile;
    if (profile == null || !_postsHasMore || _postsLoadingMore || _postsLoading) return;
    setState(() => _postsLoadingMore = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final posts = await _api.getUserPosts(token, profile.id, page: _postsPage + 1, pageSize: _kPostsPageSize);
      if (!mounted) return;
      final seen = _posts.map((p) => p.id).toSet();
      setState(() {
        _posts = [..._posts, ...posts.where((p) => !seen.contains(p.id))];
        _postsPage++;
        _postsHasMore = posts.length >= _kPostsPageSize;
      });
    } catch (_) {
      // Retried on the next scroll.
    } finally {
      if (mounted) setState(() => _postsLoadingMore = false);
    }
  }

  void _onRelationshipChanged(Relationship rel) => setState(() => _rel = rel);

  void _onRelationshipSettled(Relationship _) => _refreshProfile();

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _copyUsername() async {
    final profile = _profile;
    if (profile == null) return;
    await Clipboard.setData(ClipboardData(text: '@${profile.username}'));
    if (!mounted) return;
    showPeopleSnack(context, context.l10n.peopleUsernameCopied);
  }

  Future<void> _mutate(Future<Relationship?> Function(String token) call, {String? successMessage}) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final rel = await call(token);
      if (!mounted) return;
      if (rel != null) setState(() => _rel = rel);
      if (successMessage != null) showPeopleSnack(context, successMessage);
      await _refreshProfile();
    } catch (e) {
      if (!mounted) return;
      showPeopleSnack(context, peopleErrorText(e));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _block() async {
    final profile = _profile!;
    final l10n = context.l10n;
    final ok = await confirmPeopleAction(
      context,
      title: l10n.peopleBlockTitle(profile.username),
      body: l10n.peopleBlockBody,
      confirmLabel: l10n.peopleBlock,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _mutate((t) => _api.block(t, profile.id), successMessage: l10n.peopleBlockedSnack(profile.username));
  }

  Future<void> _unblock() async {
    final profile = _profile!;
    await _mutate(
      (t) => _api.unblock(t, profile.id),
      successMessage: context.l10n.peopleUnblockedSnack(profile.username),
    );
  }

  Future<void> _removeFollower() async {
    final profile = _profile!;
    final l10n = context.l10n;
    final ok = await confirmPeopleAction(
      context,
      title: l10n.peopleRemoveFollowerTitle(profile.username),
      body: l10n.peopleRemoveFollowerBody,
      confirmLabel: l10n.peopleRemove,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _mutate((t) => _api.removeFollower(t, profile.id));
  }

  Future<void> _openEdit() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const EditSocialProfilePage()));
    if (mounted) _load();
  }

  void _openList(PeopleListTab tab) {
    final profile = _profile;
    if (profile == null) return;
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => PeopleListPage(userId: profile.id, initialTab: tab, title: '@${profile.username}'),
    ));
  }

  void _openPost(Post post) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => PostDetailPage(postId: post.id, initial: post)));
  }

  void _onMenu(String action) {
    switch (action) {
      case 'copy':
        _copyUsername();
      case 'edit':
        _openEdit();
      case 'blocked':
        Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const BlockedUsersPage()));
      case 'remove_follower':
        _removeFollower();
      case 'block':
        _block();
      case 'unblock':
        _unblock();
      case 'report':
        final p = _profile!;
        showReportUserSheet(context, userId: p.id, username: p.username);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = _profile;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: profile == null ? null : Text('@${profile.username}'),
        actions: [
          if (profile != null)
            PopupMenuButton<String>(
              tooltip: l10n.peopleMoreOptions,
              onSelected: _onMenu,
              itemBuilder: (_) => [
                if (_isMe) ...[
                  PopupMenuItem(value: 'edit', child: Text(l10n.peopleEditProfile)),
                  PopupMenuItem(value: 'blocked', child: Text(l10n.peopleBlockedUsers)),
                ],
                PopupMenuItem(value: 'copy', child: Text(l10n.peopleCopyUsername)),
                if (!_isMe) ...[
                  if (_rel?.followedBy == FollowState.accepted && !_blocked)
                    PopupMenuItem(value: 'remove_follower', child: Text(l10n.peopleRemoveFollower)),
                  PopupMenuItem(
                    value: _blocked ? 'unblock' : 'block',
                    child: Text(
                      _blocked ? l10n.peopleUnblock : l10n.peopleBlock,
                      style: _blocked ? null : TextStyle(color: cs.error),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'report',
                    child: Text(l10n.peopleReport, style: TextStyle(color: cs.error)),
                  ),
                ],
              ],
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    final profile = _profile;
    if (_loading) return Center(child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading));
    if (profile == null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 48),
            PeopleMessageState(
              icon: Icons.person_off_outlined,
              message: l10n.peopleProfileUnavailable,
              body: _error,
              action: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                icon: const Icon(Icons.refresh),
                label: Text(l10n.commonRetry),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 600) _loadMorePosts();
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(profile)),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            ..._buildContent(profile),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(PublicProfile profile) {
    final l10n = context.l10n;
    if (_blocked) {
      return [
        SliverToBoxAdapter(
          child: PeopleMessageState(
            icon: Icons.block,
            message: l10n.peopleBlockedStateTitle,
            body: l10n.peopleBlockedStateBody,
            action: FilledButton(onPressed: _actionBusy ? null : _unblock, child: Text(l10n.peopleUnblock)),
          ),
        ),
      ];
    }
    if (!profile.canViewContent || _postsPrivate) {
      final requested = _rel?.following == FollowState.pending;
      return [
        SliverToBoxAdapter(
          child: PeopleMessageState(
            icon: Icons.lock_outline,
            message: l10n.peoplePrivateTitle,
            body: requested ? l10n.peoplePrivateRequestedBody : l10n.peoplePrivateBody,
          ),
        ),
      ];
    }
    if (_postsLoading && _posts.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading)),
          ),
        ),
      ];
    }
    if (_postsError != null && _posts.isEmpty) {
      return [SliverToBoxAdapter(child: PeopleErrorState(message: _postsError!, onRetry: _loadPosts))];
    }
    if (_posts.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: PeopleMessageState(icon: Icons.photo_camera_outlined, message: l10n.peopleNoPosts),
        ),
      ];
    }
    return [
      SliverPostGrid(posts: _posts, onTap: _openPost),
      if (_postsLoadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  Widget _buildHeader(PublicProfile p) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final locked = !p.canViewContent || _blocked;
    final role = UserRole.fromString(p.role);
    final activeText = lastActiveText(l10n, p.lastActiveAt);
    final initials = p.summary.initials;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(url: p.avatarUrl, initials: initials, radius: 42, online: isActiveNow(p.lastActiveAt)),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    _CountTile(count: p.counts.posts, label: l10n.peoplePosts),
                    _CountTile(
                      count: p.counts.followers,
                      label: l10n.peopleFollowers,
                      locked: locked,
                      onTap: () => _openList(PeopleListTab.followers),
                    ),
                    _CountTile(
                      count: p.counts.following,
                      label: l10n.peopleFollowing,
                      locked: locked,
                      onTap: () => _openList(PeopleListTab.following),
                    ),
                    _CountTile(
                      count: p.counts.friends,
                      label: l10n.peopleFriends,
                      locked: locked,
                      onTap: () => _openList(PeopleListTab.friends),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(p.fullName.isEmpty ? p.username : p.fullName, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (p.isPrivate) Icon(Icons.lock_outline, size: 16, color: cs.onSurfaceVariant, semanticLabel: l10n.peopleLocked),
              if (role != UserRole.member)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                  child: Text(role.label(l10n), style: text.labelSmall?.copyWith(color: cs.onSecondaryContainer)),
                ),
            ],
          ),
          if (activeText != null) ...[
            const SizedBox(height: 2),
            Text(
              activeText,
              style: text.bodySmall?.copyWith(
                color: isActiveNow(p.lastActiveAt) ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
          if (p.bio != null && p.bio!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _ExpandableBio(text: p.bio!.trim()),
          ],
          if (p.interests.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final i in p.interests)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
                    child: Text(interestLabel(l10n, i), style: text.labelMedium),
                  ),
              ],
            ),
          ],
          if (p.gyms.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.fitness_center, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.peopleTrainsAt(p.gyms.map((g) => g.name).join(', ')),
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          if (!_isMe && !_blocked && p.mutualFriendCount > 0 && p.mutualFriendsPreview.isNotEmpty) ...[
            const SizedBox(height: 10),
            _MutualFriendsLine(profile: p, onTap: () => _openList(PeopleListTab.mutual)),
          ],
          const SizedBox(height: 14),
          if (_isMe) _buildMyActions() else if (!_blocked) _buildActions(p),
        ],
      ),
    );
  }

  Widget _buildMyActions() {
    final l10n = context.l10n;
    final style = FilledButton.styleFrom(
      minimumSize: const Size(0, 40),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Row(
      children: [
        Expanded(child: FilledButton.tonal(onPressed: _openEdit, style: style, child: Text(l10n.peopleEditProfile))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton.tonal(onPressed: _copyUsername, style: style, child: Text(l10n.peopleShare))),
      ],
    );
  }

  Widget _buildActions(PublicProfile p) {
    final l10n = context.l10n;
    final person = p.summary;
    final rel = _rel;
    final status = p.messageStatus;
    return Row(
      children: [
        Expanded(
          child: RelationshipButton(
            person: person,
            relationship: rel,
            dense: false,
            onChanged: _onRelationshipChanged,
            onSettled: _onRelationshipSettled,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FriendButton(
            person: person,
            relationship: rel,
            onChanged: _onRelationshipChanged,
            onSettled: _onRelationshipSettled,
          ),
        ),
        if (status != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: status == 'request' ? l10n.peopleMessageRequestHint : l10n.peopleMessage,
              child: OutlinedButton(
                onPressed: () => openDirectChat(context, p.id),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(l10n.peopleMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Header pieces ─────────────────────────────────────────────────────────────

class _CountTile extends StatelessWidget {
  const _CountTile({required this.count, required this.label, this.onTap, this.locked = false});

  final int count;
  final String label;
  final VoidCallback? onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final enabled = onTap != null && !locked;
    return Expanded(
      child: Semantics(
        button: enabled,
        label: '$count $label',
        excludeSemantics: true,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$count', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (locked && onTap != null) ...[
                      const SizedBox(width: 2),
                      Icon(Icons.lock_outline, size: 12, color: cs.onSurfaceVariant),
                    ],
                  ],
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandableBio extends StatefulWidget {
  const _ExpandableBio({required this.text});
  final String text;

  @override
  State<_ExpandableBio> createState() => _ExpandableBioState();
}

class _ExpandableBioState extends State<_ExpandableBio> {
  static const _collapsedLines = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return GestureDetector(
          onTap: overflows ? () => setState(() => _expanded = !_expanded) : null,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.text,
                  style: style,
                  maxLines: _expanded ? null : _collapsedLines,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                if (overflows)
                  Text(
                    _expanded ? l10n.peopleBioLess : l10n.peopleBioMore,
                    style: style?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MutualFriendsLine extends StatelessWidget {
  const _MutualFriendsLine({required this.profile, required this.onTap});

  final PublicProfile profile;
  final VoidCallback onTap;

  String _first(PersonSummary p) => p.name.isNotEmpty ? p.name : '@${p.username}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final preview = profile.mutualFriendsPreview;
    final count = profile.mutualFriendCount;
    final String line;
    if (count <= 1 || preview.length < 2) {
      line = l10n.peopleMutualFriendsOne(_first(preview.first));
    } else if (count == 2) {
      line = l10n.peopleMutualFriendsTwo(_first(preview[0]), _first(preview[1]));
    } else {
      line = l10n.peopleMutualFriendsMore(count - 2, _first(preview[0]), _first(preview[1]));
    }
    final avatars = preview.take(3).toList();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 14.0 * avatars.length + 14,
              height: 28,
              child: Stack(
                children: [
                  for (var i = 0; i < avatars.length; i++)
                    Positioned(
                      left: 14.0 * i,
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cs.surface, width: 2)),
                        child: UserAvatar(url: avatars[i].avatarUrl, initials: avatars[i].initials, radius: 12),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
