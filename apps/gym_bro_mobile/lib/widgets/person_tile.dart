import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/people.dart';
import '../pages/people/people_common.dart';
import '../pages/people/user_profile_page.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'social_widgets.dart';
import 'app_bottom_sheet.dart';

/// Opens someone's profile.
Future<void> openUserProfile(BuildContext context, String userId) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => UserProfilePage(userId: userId)));

/// A person row: avatar, name (+ lock when private), @username or [subtitle],
/// and an optional [trailing] (usually a [RelationshipButton]). Taps open the
/// profile unless [onTap] is given.
class PersonTile extends StatelessWidget {
  const PersonTile({
    super.key,
    required this.person,
    this.onTap,
    this.trailing,
    this.subtitle,
    this.online = false,
  });

  final PersonSummary person;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Replaces the default "@username" line.
  final String? subtitle;

  /// Green "active now" dot on the avatar.
  final bool online;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final name = person.fullName.isEmpty ? person.username : person.fullName;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: UserAvatar(url: person.avatarUrl, initials: person.initials, radius: 22, online: online),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (person.isPrivate) ...[
            const SizedBox(width: 4),
            Icon(Icons.lock_outline, size: 14, color: cs.onSurfaceVariant, semanticLabel: l10n.peopleLocked),
          ],
        ],
      ),
      subtitle: Text(
        subtitle ?? '@${person.username}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
      trailing: trailing,
      onTap: onTap ?? () => openUserProfile(context, person.id),
    );
  }
}

ButtonStyle _compactStyle(bool dense) => ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(0, dense ? 34 : 40)),
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
  visualDensity: VisualDensity.compact,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

Widget _busyIndicator(BuildContext context) => SizedBox(
  width: 16,
  height: 16,
  child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: context.l10n.commonLoading),
);

/// Runs a relationship mutation optimistically: shows [optimistic] at once,
/// then the server's answer, rolling back to [previous] on failure.
Future<void> _runRelationshipAction(
  BuildContext context, {
  required Relationship previous,
  required Relationship optimistic,
  required Future<Relationship?> Function(ApiService api, String token) call,
  required void Function(Relationship rel) apply,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  apply(optimistic);
  try {
    final token = await AuthManager.instance.getValidToken();
    final result = await call(ApiService(), token);
    apply(result ?? optimistic);
  } catch (e) {
    apply(previous);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(peopleErrorText(e))));
  }
}

/// The contextual follow button: "Follow" / "Follow back" / "Requested" (tap
/// to cancel) / "Following" (tap for Unfollow, Remove friend…). Blocked people
/// get "Unblock". Hidden for myself (no relationship).
class RelationshipButton extends StatefulWidget {
  const RelationshipButton({
    super.key,
    required this.person,
    this.relationship,
    this.onChanged,
    this.onSettled,
    this.dense = true,
  });

  final PersonSummary person;

  /// Defaults to [PersonSummary.relationship].
  final Relationship? relationship;
  /// Called with every change, optimistic ones included.
  final ValueChanged<Relationship>? onChanged;

  /// Called once the server answered (or the change was rolled back).
  final ValueChanged<Relationship>? onSettled;

  /// Compact height for list rows; false for the profile header.
  final bool dense;

  @override
  State<RelationshipButton> createState() => _RelationshipButtonState();
}

class _RelationshipButtonState extends State<RelationshipButton> {
  Relationship? _rel;
  bool _busy = false;

  Relationship? get _incoming => widget.relationship ?? widget.person.relationship;

  @override
  void initState() {
    super.initState();
    _rel = _incoming;
  }

  @override
  void didUpdateWidget(RelationshipButton old) {
    super.didUpdateWidget(old);
    final prev = old.relationship ?? old.person.relationship;
    if (!identical(prev, _incoming)) _rel = _incoming;
  }

  void _apply(Relationship rel) {
    if (!mounted) return;
    setState(() => _rel = rel);
    widget.onChanged?.call(rel);
  }

  Future<void> _run(Relationship optimistic, Future<Relationship?> Function(ApiService, String) call) async {
    final previous = _rel;
    if (previous == null || _busy) return;
    setState(() => _busy = true);
    await _runRelationshipAction(context, previous: previous, optimistic: optimistic, call: call, apply: _apply);
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onSettled?.call(_rel!);
  }

  String get _id => widget.person.id;

  Future<void> _follow() => _run(
    _rel!.copyWith(following: widget.person.isPrivate ? FollowState.pending : FollowState.accepted),
    (api, t) => api.follow(t, _id),
  );

  Future<void> _unfollow() => _run(_rel!.copyWith(following: FollowState.none), (api, t) => api.unfollow(t, _id));

  Future<void> _cancelRequest() async {
    final l10n = context.l10n;
    final ok = await confirmPeopleAction(
      context,
      title: l10n.peopleCancelFollowRequestTitle(widget.person.username),
      confirmLabel: l10n.peopleCancelRequest,
      cancelLabel: l10n.peopleKeep,
      destructive: true,
    );
    if (ok && mounted) await _unfollow();
  }

  Future<void> _confirmUnfollow() async {
    final l10n = context.l10n;
    final ok = await confirmPeopleAction(
      context,
      title: l10n.peopleUnfollowTitle(widget.person.username),
      body: widget.person.isPrivate ? l10n.peopleUnfollowPrivateBody : null,
      confirmLabel: l10n.peopleUnfollow,
      destructive: true,
    );
    if (ok && mounted) await _unfollow();
  }

  Future<void> _confirmRemoveFriend() async {
    final l10n = context.l10n;
    final name = widget.person.fullName.isEmpty ? '@${widget.person.username}' : widget.person.fullName;
    final ok = await confirmPeopleAction(
      context,
      title: l10n.peopleRemoveFriendTitle(name),
      body: l10n.peopleRemoveFriendBody,
      confirmLabel: l10n.peopleRemove,
      destructive: true,
    );
    if (ok && mounted) {
      await _run(_rel!.copyWith(friendship: FriendState.none), (api, t) => api.removeFriend(t, _id));
    }
  }

  Future<void> _showFollowingSheet() async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final rel = _rel!;
    final action = await showAppBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: UserAvatar(url: widget.person.avatarUrl, initials: widget.person.initials),
              title: Text(widget.person.fullName.isEmpty ? widget.person.username : widget.person.fullName),
              subtitle: Text('@${widget.person.username}'),
            ),
            const Divider(height: 1),
            if (rel.isFriend)
              ListTile(
                leading: const Icon(Icons.person_remove_outlined),
                title: Text(l10n.peopleRemoveFriend),
                onTap: () => Navigator.pop(ctx, 'unfriend'),
              ),
            ListTile(
              leading: Icon(Icons.person_off_outlined, color: cs.error),
              title: Text(l10n.peopleUnfollow, style: TextStyle(color: cs.error)),
              onTap: () => Navigator.pop(ctx, 'unfollow'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'unfollow':
        await _confirmUnfollow();
      case 'unfriend':
        await _confirmRemoveFriend();
    }
  }

  Future<void> _unblock() => _run(_rel!.copyWith(blocked: false), (api, t) => api.unblock(t, _id));

  @override
  Widget build(BuildContext context) {
    final rel = _rel;
    if (rel == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final style = _compactStyle(widget.dense);
    Widget label(String text, {IconData? trailingIcon}) => _busy
        ? _busyIndicator(context)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (trailingIcon != null) ...[const SizedBox(width: 2), Icon(trailingIcon, size: 18)],
            ],
          );

    if (rel.blocked) {
      return OutlinedButton(onPressed: _busy ? null : _unblock, style: style, child: label(l10n.peopleUnblock));
    }
    return switch (rel.following) {
      FollowState.none => FilledButton(
        onPressed: _busy ? null : _follow,
        style: style,
        child: label(rel.followedBy == FollowState.accepted ? l10n.peopleFollowBack : l10n.peopleFollow),
      ),
      FollowState.pending => Semantics(
        hint: l10n.peopleCancelRequest,
        child: FilledButton.tonal(
          onPressed: _busy ? null : _cancelRequest,
          style: style,
          child: label(l10n.peopleRequested),
        ),
      ),
      FollowState.accepted => FilledButton.tonal(
        onPressed: _busy ? null : _showFollowingSheet,
        style: style,
        child: label(l10n.peopleFollowing, trailingIcon: Icons.expand_more),
      ),
    };
  }
}

/// The friend button on profiles: "Add friend" / "Request sent" (tap to
/// cancel) / "Respond" (accept or decline) / "Friends" (tap to unfriend).
class FriendButton extends StatefulWidget {
  const FriendButton({
    super.key,
    required this.person,
    this.relationship,
    this.onChanged,
    this.onSettled,
    this.dense = false,
  });

  final PersonSummary person;
  final Relationship? relationship;
  /// Called with every change, optimistic ones included.
  final ValueChanged<Relationship>? onChanged;

  /// Called once the server answered (or the change was rolled back).
  final ValueChanged<Relationship>? onSettled;
  final bool dense;

  @override
  State<FriendButton> createState() => _FriendButtonState();
}

class _FriendButtonState extends State<FriendButton> {
  Relationship? _rel;
  bool _busy = false;

  Relationship? get _incoming => widget.relationship ?? widget.person.relationship;

  @override
  void initState() {
    super.initState();
    _rel = _incoming;
  }

  @override
  void didUpdateWidget(FriendButton old) {
    super.didUpdateWidget(old);
    final prev = old.relationship ?? old.person.relationship;
    if (!identical(prev, _incoming)) _rel = _incoming;
  }

  void _apply(Relationship rel) {
    if (!mounted) return;
    setState(() => _rel = rel);
    widget.onChanged?.call(rel);
  }

  Future<void> _run(Relationship optimistic, Future<Relationship?> Function(ApiService, String) call) async {
    final previous = _rel;
    if (previous == null || _busy) return;
    setState(() => _busy = true);
    await _runRelationshipAction(context, previous: previous, optimistic: optimistic, call: call, apply: _apply);
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onSettled?.call(_rel!);
  }

  String get _id => widget.person.id;
  String get _name => widget.person.fullName.isEmpty ? '@${widget.person.username}' : widget.person.fullName;

  Future<void> _add() => _run(_rel!.copyWith(friendship: FriendState.outgoing), (api, t) => api.addFriend(t, _id));

  Future<void> _accept() => _run(
    // Friends also follow each other.
    _rel!.copyWith(friendship: FriendState.friends, following: FollowState.accepted, followedBy: FollowState.accepted),
    (api, t) => api.addFriend(t, _id),
  );

  Future<void> _remove() => _run(_rel!.copyWith(friendship: FriendState.none), (api, t) => api.removeFriend(t, _id));

  Future<void> _cancel() async {
    final l10n = context.l10n;
    final ok = await confirmPeopleAction(
      context,
      title: l10n.peopleCancelFriendRequestTitle(_name),
      confirmLabel: l10n.peopleCancelRequest,
      cancelLabel: l10n.peopleKeep,
      destructive: true,
    );
    if (ok && mounted) await _remove();
  }

  Future<void> _unfriend() async {
    final l10n = context.l10n;
    final ok = await confirmPeopleAction(
      context,
      title: l10n.peopleRemoveFriendTitle(_name),
      body: l10n.peopleRemoveFriendBody,
      confirmLabel: l10n.peopleRemove,
      destructive: true,
    );
    if (ok && mounted) await _remove();
  }

  Future<void> _respond() async {
    final l10n = context.l10n;
    final action = await showAppBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: UserAvatar(url: widget.person.avatarUrl, initials: widget.person.initials),
              title: Text(l10n.peopleFriendRequestFrom(_name)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.check),
              title: Text(l10n.peopleAccept),
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l10n.peopleDecline),
              onTap: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    await (action ? _accept() : _remove());
  }

  @override
  Widget build(BuildContext context) {
    final rel = _rel;
    if (rel == null || rel.blocked) return const SizedBox.shrink();
    final l10n = context.l10n;
    final style = _compactStyle(widget.dense);
    final (String text, IconData icon, VoidCallback onPressed) = switch (rel.friendship) {
      FriendState.none => (l10n.peopleAddFriend, Icons.person_add_alt_1_outlined, _add),
      FriendState.outgoing => (l10n.peopleFriendRequestSent, Icons.schedule_send_outlined, _cancel),
      FriendState.incoming => (l10n.peopleRespond, Icons.person_add_alt_1, _respond),
      FriendState.friends => (l10n.peopleFriends, Icons.how_to_reg, _unfriend),
    };
    final child = _busy
        ? _busyIndicator(context)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          );
    // A pending incoming request is the call to action; everything else is secondary.
    return rel.friendship == FriendState.incoming
        ? FilledButton(onPressed: _busy ? null : onPressed, style: style, child: child)
        : FilledButton.tonal(onPressed: _busy ? null : onPressed, style: style, child: child);
  }
}
