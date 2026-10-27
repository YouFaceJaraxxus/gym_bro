import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/chat.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/image_upload_field.dart';
import '../../widgets/social_widgets.dart';
import '../people/user_profile_page.dart';
import 'chat_launcher.dart';
import 'chat_widgets.dart';
import 'new_chat_page.dart';
import 'shared_media_page.dart';

enum _MemberAction { profile, message, makeAdmin, removeAdmin, makeOwner, remove }

/// Group details: photo, name, description, members and roles, shared
/// media, mute, leave and delete. Pops with `true` when I left or deleted
/// the group (the thread then closes too).
class GroupInfoPage extends StatefulWidget {
  const GroupInfoPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  final _api = ApiService();
  Conversation? _conv;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  String get _id => widget.conversationId;
  String get _me => chatMyId;
  bool get _isAdmin => _conv?.myRole.isAdmin ?? false;
  bool get _isOwner => _conv?.myRole == ParticipantRole.owner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final c = await _api.getConversation(token, _id);
      if (!mounted) return;
      setState(() {
        _conv = c;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = chatErrorText(e);
      });
    }
  }

  /// Runs an API call that returns the updated detail, with a busy state.
  Future<void> _run(Future<Conversation?> Function(String token) call, {String? success}) async {
    setState(() => _busy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final c = await call(token);
      if (!mounted) return;
      setState(() {
        if (c != null) _conv = c.members.isEmpty ? conversationWithMembers(c, _conv?.members ?? const []) : c;
        _busy = false;
      });
      if (success != null) showChatSnack(context, success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showChatSnack(context, chatErrorText(e));
    }
  }

  Future<void> _edit() async {
    final c = _conv;
    if (c == null) return;
    final l10n = context.l10n;
    final title = TextEditingController(text: c.title ?? '');
    final description = TextEditingController(text: c.description ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chatEditGroup),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: title,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.chatGroupName),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: description,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.chatGroupDescription),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.commonSave)),
        ],
      ),
    );
    final newTitle = title.text.trim();
    final newDescription = description.text.trim();
    title.dispose();
    description.dispose();
    if (save != true || !mounted) return;
    final changes = <String, dynamic>{
      if (newTitle != (c.title ?? '')) 'title': newTitle,
      if (newDescription != (c.description ?? '')) 'description': newDescription,
    };
    if (changes.isEmpty) return;
    await _run((token) => _api.updateGroup(token, _id, changes));
  }

  Future<void> _setPhoto(String url) => _run((token) => _api.updateGroup(token, _id, {'avatar_url': url}));

  Future<void> _toggleMute(bool muted) => _run((token) => _api.updateChatSettings(token, _id, muted: muted));

  Future<void> _addPeople() async {
    final c = _conv;
    if (c == null) return;
    final l10n = context.l10n;
    final picked = await NewChatPage.pickPeople(context, exclude: c.members.map((m) => m.person.id).toSet());
    if (picked.isEmpty || !mounted) return;
    await _run(
      (token) => _api.addGroupMembers(token, _id, picked.map((p) => p.id).toList()),
      success: l10n.chatPeopleAdded(picked.length),
    );
  }

  Future<void> _memberActions(ConversationMember m) async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final isMe = m.person.id == _me;
    final canRemove = !isMe &&
        _isAdmin &&
        m.role != ParticipantRole.owner &&
        (m.role != ParticipantRole.admin || _isOwner);
    final action = await showModalBottomSheet<_MemberAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: UserAvatar(url: m.person.avatarUrl, initials: m.person.initials),
            title: Text(m.person.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: m.person.username.isEmpty ? null : Text('@${m.person.username}'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.chatViewProfile),
            onTap: () => Navigator.pop(ctx, _MemberAction.profile),
          ),
          if (!isMe)
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(l10n.chatMessageMember),
              onTap: () => Navigator.pop(ctx, _MemberAction.message),
            ),
          if (_isOwner && !isMe && m.role == ParticipantRole.member)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(l10n.chatMakeAdmin),
              onTap: () => Navigator.pop(ctx, _MemberAction.makeAdmin),
            ),
          if (_isOwner && !isMe && m.role == ParticipantRole.admin)
            ListTile(
              leading: const Icon(Icons.remove_moderator_outlined),
              title: Text(l10n.chatRemoveAdmin),
              onTap: () => Navigator.pop(ctx, _MemberAction.removeAdmin),
            ),
          if (_isOwner && !isMe && m.status == 'active')
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: Text(l10n.chatMakeOwner),
              onTap: () => Navigator.pop(ctx, _MemberAction.makeOwner),
            ),
          if (canRemove)
            ListTile(
              leading: Icon(Icons.person_remove_outlined, color: cs.error),
              title: Text(l10n.chatRemoveMember, style: TextStyle(color: cs.error)),
              onTap: () => Navigator.pop(ctx, _MemberAction.remove),
            ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _MemberAction.profile:
        await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: m.person.id)));
      case _MemberAction.message:
        await openDirectChat(context, m.person.id);
      case _MemberAction.makeAdmin:
        await _run((token) => _api.setGroupRole(token, _id, m.person.id, ParticipantRole.admin));
      case _MemberAction.removeAdmin:
        await _run((token) => _api.setGroupRole(token, _id, m.person.id, ParticipantRole.member));
      case _MemberAction.makeOwner:
        final ok = await confirmChatAction(
          context,
          body: l10n.chatMakeOwnerConfirm(m.person.fullName),
          confirm: l10n.chatMakeOwner,
          destructive: false,
        );
        if (!ok || !mounted) return;
        await _run((token) => _api.setGroupRole(token, _id, m.person.id, ParticipantRole.owner));
      case _MemberAction.remove:
        final ok = await confirmChatAction(
          context,
          body: l10n.chatRemoveMemberConfirm(m.person.fullName),
          confirm: l10n.chatRemoveMember,
        );
        if (!ok || !mounted) return;
        await _run((token) async {
          await _api.removeFromChat(token, _id, m.person.id);
          return _api.getConversation(token, _id);
        });
    }
  }

  Future<void> _leave() async {
    final c = _conv;
    if (c == null) return;
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    final ok = await confirmChatAction(
      context,
      body: l10n.chatLeaveGroupConfirm(c.displayTitle(l10n.chatGroupFallback)),
      confirm: l10n.chatLeaveGroup,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.removeFromChat(token, _id, _me);
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showChatSnack(context, chatErrorText(e));
    }
  }

  Future<void> _delete() async {
    final c = _conv;
    if (c == null) return;
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    final ok = await confirmChatAction(
      context,
      title: l10n.chatDeleteGroup,
      body: l10n.chatDeleteGroupConfirm(c.displayTitle(l10n.chatGroupFallback)),
      confirm: l10n.commonDelete,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteGroup(token, _id);
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showChatSnack(context, chatErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = _conv;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatGroupInfo),
        actions: [
          if (_isAdmin)
            IconButton(tooltip: l10n.chatEditGroup, icon: const Icon(Icons.edit_outlined), onPressed: _busy ? null : _edit),
        ],
        bottom: _busy
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : c == null
              ? ChatErrorState(
                  message: _error ?? l10n.commonSomethingWentWrong,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                )
              : RefreshIndicator(onRefresh: _load, child: _body(c)),
    );
  }

  Widget _body(Conversation c) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = c.displayTitle(l10n.chatGroupFallback);
    final active = c.members.where((m) => m.status == 'active').length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SizedBox(height: 20),
        Center(
          child: _isAdmin
              ? AvatarPicker(imageUrl: c.avatarUrl, folder: 'groups', radius: 48, onUploaded: _setPhoto)
              : ConversationAvatar(conversation: c, radius: 48),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(title, textAlign: TextAlign.center, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 2),
        Text(l10n.chatMembersCount(active), textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        if (c.description != null && c.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Text(c.description!, textAlign: TextAlign.center, style: tt.bodyMedium),
          ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_isAdmin)
            _RoundAction(icon: Icons.person_add_alt_1_outlined, label: l10n.chatAddPeople, onTap: _busy ? null : _addPeople),
          _RoundAction(
            icon: c.muted ? Icons.notifications_off : Icons.notifications_outlined,
            label: c.muted ? l10n.chatUnmute : l10n.chatMute,
            onTap: _busy ? null : () => _toggleMute(!c.muted),
          ),
          _RoundAction(
            icon: Icons.perm_media_outlined,
            label: l10n.chatTabMedia,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => SharedMediaPage(conversationId: _id)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            '${l10n.chatMembersTitle} · ${c.members.length}',
            style: tt.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
          ),
        ),
        if (_isAdmin)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.secondaryContainer,
              child: Icon(Icons.person_add_alt_1, color: cs.onSecondaryContainer),
            ),
            title: Text(l10n.chatAddPeople),
            onTap: _busy ? null : _addPeople,
          ),
        for (final m in c.members)
          ListTile(
            leading: UserAvatar(
              url: m.person.avatarUrl,
              initials: m.person.initials,
              online: m.person.id != _me && isRecentlyActive(m.lastActiveAt),
            ),
            title: Text(
              m.person.id == _me ? '${m.person.fullName} (${l10n.chatYou})' : m.person.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: m.person.username.isEmpty ? null : Text('@${m.person.username}', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Wrap(spacing: 4, children: [
              if (m.status == 'request') ChatTag(l10n.chatInvited),
              if (m.role == ParticipantRole.owner) ChatTag(l10n.chatRoleOwner, strong: true),
              if (m.role == ParticipantRole.admin) ChatTag(l10n.chatRoleAdmin, strong: true),
            ]),
            onTap: _busy ? null : () => _memberActions(m),
          ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.logout, color: cs.error),
          title: Text(l10n.chatLeaveGroup, style: TextStyle(color: cs.error)),
          onTap: _busy ? null : _leave,
        ),
        if (_isOwner)
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: cs.error),
            title: Text(l10n.chatDeleteGroup, style: TextStyle(color: cs.error)),
            onTap: _busy ? null : _delete,
          ),
      ],
    );
  }
}

/// Circular icon + label under the header ("Add people", "Mute", "Media").
class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _RoundAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 92,
      child: Column(children: [
        IconButton.filledTonal(onPressed: onTap, icon: Icon(icon), tooltip: label),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ]),
    );
  }
}
