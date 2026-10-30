import 'package:flutter/material.dart';

import '../config.dart';
import '../l10n/l10n.dart';
import '../models/mention.dart';
import '../models/payment.dart';
import '../models/post.dart';
import '../models/shared_content.dart';
import '../models/story.dart';
import '../pages/feed/post_detail_page.dart';
import '../pages/people/user_profile_page.dart';
import '../pages/shop/order_widgets.dart';
import '../pages/stories/story_viewer_page.dart';
import 'mentions.dart';
import 'post_attachment_card.dart';
import 'social_widgets.dart';

/// A shared thing as a tappable card (chat bubbles, stories, the share
/// sheet). Unavailable content shows why ("This account is private",
/// "Post unavailable", "Story expired") and no preview.
class SharedContentCard extends StatelessWidget {
  const SharedContentCard({
    super.key,
    required this.content,
    this.onDark = false,
    this.maxWidth = 280,
    this.onTap,
    this.sharedBy,
  });

  final SharedContent content;

  /// On a dark/colour background (stories): light text.
  final bool onDark;
  final double maxWidth;

  /// Overrides the default (opening the thing).
  final VoidCallback? onTap;

  /// Who shared it. A logged workout or meal can only be shared by its owner,
  /// so it opens for them when it's me.
  final String? sharedBy;

  @override
  Widget build(BuildContext context) {
    final c = content;
    final Widget card;
    if (!c.isResolved) {
      card = _Skeleton(onDark: onDark);
    } else if (!c.isAvailable) {
      card = _UnavailableCard(content: c, onDark: onDark);
    } else {
      card = switch (c.kind) {
        ShareKind.post => _PostCard(content: c, onTap: onTap ?? () => _open(context)),
        ShareKind.story => _StoryCard(content: c, onTap: onTap ?? () => _open(context)),
        ShareKind.user => _ProfileCard(content: c, onTap: onTap ?? () => _open(context)),
        ShareKind.business || ShareKind.shopItem => _BusinessCard(content: c, onTap: onTap ?? () => _open(context)),
        _ => _attachment(context),
      };
    }
    return ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: card);
  }

  /// Workouts, meals and library items: the post attachment card.
  Widget _attachment(BuildContext context) {
    final type = content.kind.postType ?? PostType.generic;
    final card = PostAttachmentCard(
      type: type,
      attachment: content.attachment,
      refId: content.refId,
      authorId: sharedBy,
      enabled: onTap == null,
    );
    return onTap == null ? card : GestureDetector(onTap: onTap, child: AbsorbPointer(child: card));
  }

  Future<void> _open(BuildContext context) async {
    final id = content.refId;
    if (id == null) return;
    final nav = Navigator.of(context);
    Future<void> push(Widget page) => nav.push<void>(MaterialPageRoute(builder: (_) => page));
    switch (content.kind) {
      case ShareKind.post:
        await push(PostDetailPage(postId: id));
      case ShareKind.story:
        await openStoryById(context, id);
      case ShareKind.user:
        await push(UserProfilePage(userId: id));
      case ShareKind.business:
        await openMention(context, Mention(kind: MentionKind.business, id: id, label: content.name ?? ''));
      case ShareKind.shopItem:
        await openMention(context, Mention(kind: MentionKind.shopItem, id: id, label: content.name ?? ''));
      default:
        break; // the attachment card opens itself
    }
  }
}

/// "Post", "Profile", "Recipe", … for [kind].
String shareKindLabel(AppLocalizations l10n, ShareKind kind) => switch (kind) {
  ShareKind.post => l10n.sharedKindPost,
  ShareKind.story => l10n.sharedKindStory,
  ShareKind.user => l10n.sharedKindProfile,
  ShareKind.business => l10n.sharedKindGym,
  ShareKind.shopItem => l10n.sharedKindProduct,
  _ => postTypeLabel(l10n, kind.postType ?? PostType.generic),
};

/// "Shared a post", "Shared a workout", … — inbox previews of a share
/// without text.
String sharedPreviewText(AppLocalizations l10n, ShareKind kind) => switch (kind) {
  ShareKind.post => l10n.sharedPreviewPost,
  ShareKind.story => l10n.sharedPreviewStory,
  ShareKind.user => l10n.sharedPreviewProfile,
  ShareKind.business => l10n.sharedPreviewBusiness,
  ShareKind.shopItem => l10n.sharedPreviewProduct,
  ShareKind.workout || ShareKind.training => l10n.sharedPreviewWorkout,
  ShareKind.meal => l10n.sharedPreviewMeal,
  ShareKind.exercise => l10n.sharedPreviewExercise,
  ShareKind.routine => l10n.sharedPreviewRoutine,
  ShareKind.recipe => l10n.sharedPreviewRecipe,
  ShareKind.foodItem => l10n.sharedPreviewFood,
  ShareKind.dailyMealPlan => l10n.sharedPreviewDayPlan,
  ShareKind.mealPlan => l10n.sharedPreviewMealPlan,
};

/// Why [content] shows no preview: (icon, title, explanation).
({IconData icon, String title, String body}) unavailableText(AppLocalizations l10n, SharedContent content) {
  final kind = content.kind;
  switch (content.reason ?? ShareUnavailableReason.unavailable) {
    case ShareUnavailableReason.expired:
      return (icon: Icons.timer_off_outlined, title: l10n.sharedExpiredStoryTitle, body: l10n.sharedExpiredStoryBody);
    case ShareUnavailableReason.private:
      return switch (kind) {
        ShareKind.post => (icon: Icons.lock_outline, title: l10n.sharedPrivatePostTitle, body: l10n.sharedPrivatePostBody),
        ShareKind.story => (icon: Icons.lock_outline, title: l10n.sharedPrivateStoryTitle, body: l10n.sharedPrivateStoryBody),
        _ => (
          icon: Icons.lock_outline,
          title: l10n.sharedPrivateItemTitle(shareKindLabel(l10n, kind)),
          body: l10n.sharedPrivateItemBody,
        ),
      };
    case ShareUnavailableReason.unavailable:
      final title = switch (kind) {
        ShareKind.post => l10n.sharedUnavailablePostTitle,
        ShareKind.story => l10n.sharedUnavailableStoryTitle,
        ShareKind.user => l10n.sharedUnavailableAccountTitle,
        _ => l10n.sharedUnavailableTitle,
      };
      return (icon: Icons.visibility_off_outlined, title: title, body: l10n.sharedUnavailableBody);
  }
}

// ── Building blocks ──────────────────────────────────────────────────────────

/// The rounded, outlined surface every card sits on.
class _Shell extends StatelessWidget {
  const _Shell({required this.child, this.onTap, this.muted = false});

  final Widget child;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: muted ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.onDark});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final block = cs.onSurface.withValues(alpha: 0.08);
    return Semantics(
      label: context.l10n.sharedLoading,
      child: _Shell(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(10))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 12, width: 120, color: block),
                const SizedBox(height: 8),
                Container(height: 10, width: 80, color: block),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.content, required this.onDark});

  final SharedContent content;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final t = unavailableText(context.l10n, content);
    return _Shell(
      muted: true,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(t.icon, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(t.title, style: tt.titleSmall),
              const SizedBox(height: 2),
              Text(t.body, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Avatar + name line at the top of post and story cards.
class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.name, this.avatarUrl, required this.initials, this.light = false});

  final String name;
  final String? avatarUrl;
  final String initials;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(children: [
      UserAvatar(url: avatarUrl, initials: initials, radius: 12),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: light ? Colors.white : null,
            shadows: light ? const [Shadow(blurRadius: 4, color: Colors.black54)] : null,
          ),
        ),
      ),
    ]);
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.content, required this.onTap});

  final SharedContent content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final c = content;
    final business = c.preview['business'] is Map<String, dynamic> ? c.preview['business'] as Map<String, dynamic> : null;
    final author = c.author;
    final name = business?['name']?.toString() ?? author?.username ?? author?.fullName ?? '';
    final avatar = business?['logo']?.toString() ?? author?.avatarUrl;
    final media = c.mediaUrl;
    final typed = c.postAttachment;
    return _Shell(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: _AuthorRow(
            name: name,
            avatarUrl: avatar,
            initials: author?.initials ?? (name.isEmpty ? '?' : name[0].toUpperCase()),
          ),
        ),
        if (media != null)
          AspectRatio(
            aspectRatio: 1,
            child: Stack(fit: StackFit.expand, children: [
              if (c.isVideo)
                Container(color: Colors.black87)
              else
                MediaImage(url: AppConfig.resolveUrl(media)),
              if (c.isVideo)
                const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 44)),
              if (c.mediaCount > 1)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.collections, color: Colors.white, size: 20, shadows: [Shadow(blurRadius: 4)]),
                ),
            ]),
          )
        else if (typed != null && c.postType != PostType.generic)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: PostAttachmentCard(type: c.postType, attachment: typed, compact: true, enabled: false),
          ),
        if (c.caption != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Text(
              c.caption!,
              maxLines: media == null && typed == null ? 5 : 2,
              overflow: TextOverflow.ellipsis,
              style: media == null && typed == null ? tt.bodyLarge : tt.bodyMedium,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: Text(
            context.l10n.sharedPostOf(author?.fullName.isNotEmpty == true ? author!.fullName : name),
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ]),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.content, required this.onTap});

  final SharedContent content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = content;
    final author = c.author;
    final media = c.mediaUrl;
    return Semantics(
      button: true,
      label: context.l10n.sharedStoryOf(author?.fullName ?? ''),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 150,
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Stack(fit: StackFit.expand, children: [
                Container(color: parseHexColor(c.background) ?? const Color(0xFF2B2D42)),
                if (media != null && !c.isVideo) MediaImage(url: AppConfig.resolveUrl(media)),
                if (c.isVideo) const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40)),
                if (media == null && c.caption != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        c.caption!,
                        textAlign: TextAlign.center,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (media == null && c.caption == null && c.preview['share_kind'] != null)
                  const Center(child: Icon(Icons.ios_share, color: Colors.white70, size: 32)),
                Positioned(
                  left: 8,
                  right: 8,
                  top: 8,
                  child: _AuthorRow(
                    name: author?.username ?? author?.fullName ?? '',
                    avatarUrl: author?.avatarUrl,
                    initials: author?.initials ?? '?',
                    light: true,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.content, required this.onTap});

  final SharedContent content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final c = content;
    final name = c.fullName.isNotEmpty ? c.fullName : (c.username ?? '');
    final initials = name.isEmpty
        ? '?'
        : name.split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();
    return _Shell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          UserAvatar(url: c.avatarUrl, initials: initials, radius: 32),
          const SizedBox(height: 10),
          Text(name, style: tt.titleMedium, textAlign: TextAlign.center),
          if (c.username != null)
            Text('@${c.username}', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          if (c.isPrivate) ...[
            const SizedBox(height: 8),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(context.l10n.sharedPrivateChip, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ],
          if (c.bio != null) ...[
            const SizedBox(height: 8),
            Text(c.bio!, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: tt.bodySmall),
          ],
        ]),
      ),
    );
  }
}

/// A gym/shop page or a product.
class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.content, required this.onTap});

  final SharedContent content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final c = content;
    final product = c.kind == ShareKind.shopItem;
    final image = product ? c.imageUrl : c.logo;
    final kindLabel = product ? l10n.sharedKindProduct : (c.businessType == 'shop' ? l10n.sharedKindShop : l10n.sharedKindGym);
    final subtitle = product
        ? [
            if (c.price != null) formatMoney(c.price!, PaymentsConfigCache.current.currency, l10n.localeName),
            ?c.shopName,
          ].join(' · ')
        : [kindLabel, ?c.location].join(' · ');
    return _Shell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(product ? 10 : 24),
            child: SizedBox(
              width: 48,
              height: 48,
              child: image != null
                  ? MediaImage(url: AppConfig.resolveUrl(image))
                  : Container(
                      color: cs.primaryContainer,
                      child: Icon(
                        product
                            ? Icons.shopping_bag_outlined
                            : (c.businessType == 'shop' ? Icons.storefront_outlined : Icons.fitness_center),
                        color: cs.onPrimaryContainer,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(c.name ?? kindLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleSmall),
              if (subtitle.isNotEmpty)
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ]),
      ),
    );
  }
}
