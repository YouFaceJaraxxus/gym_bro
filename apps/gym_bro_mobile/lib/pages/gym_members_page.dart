import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'add_gym_member_page.dart';
import 'edit_gym_member_page.dart';
import 'invite_gym_member_page.dart';
import '../widgets/app_bottom_sheet.dart';

class GymMembersPage extends StatefulWidget {
  const GymMembersPage(
      {super.key, required this.gymId, required this.gymName});

  final String gymId;
  final String gymName;

  @override
  State<GymMembersPage> createState() => _GymMembersPageState();
}

class _GymMembersPageState extends State<GymMembersPage> {
  final _api = ApiService();

  List<({String memberId, UserProfile user})> _members = [];
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
      final memberRows = await _api.getMembers(token, gymId: widget.gymId);

      if (mounted) {
        setState(() {
          _members = [
            for (final r in memberRows)
              (memberId: r['id'] as String, user: UserProfile.fromRoleRow(r)),
          ];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _resendInvite(({String memberId, UserProfile user}) entry) async {
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.resendInvite(token, entry.user.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.businessGymInviteResent)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _removeMember(String memberId) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.businessGymRemoveMemberTitle),
        content: Text(l10n.businessGymRemoveMemberMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.businessGymRemove)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.removeMember(token, memberId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _openEdit(({String memberId, UserProfile user}) entry) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EditGymMemberPage(
          memberId: entry.memberId,
          user: entry.user,
          gymName: widget.gymName,
          gymId: widget.gymId,
        ),
      ),
    );
    if (result == 'removed') _load();
  }

  void _showAddOptions() {
    final l10n = context.l10n;
    showAppBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: Text(l10n.businessGymAddExistingUser),
              subtitle: Text(l10n.businessGymAddExistingUserHint),
              onTap: () async {
                Navigator.pop(context);
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddGymMemberPage(gymId: widget.gymId),
                  ),
                );
                if (added == true) _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mark_email_unread_outlined),
              title: Text(l10n.businessGymInviteNewMember),
              subtitle: Text(l10n.businessGymInviteNewMemberHint),
              onTap: () async {
                Navigator.pop(context);
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        InviteGymMemberPage(gymId: widget.gymId),
                  ),
                );
                if (added == true) _load();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(context.l10n.businessGymMembersTitle(widget.gymName))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        icon: const Icon(Icons.person_add_outlined),
        label: Text(context.l10n.businessGymAddMember),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(_error!),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _load, child: Text(context.l10n.commonRetry)),
        ],
      ),
    );
  }

  Widget _buildList() {
    final l10n = context.l10n;
    if (_members.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(context.l10n.businessGymNoMembersYet),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
        itemCount: _members.length,
        itemBuilder: (_, i) {
          final entry = _members[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () => _openEdit(entry),
              leading: CircleAvatar(
                child: Text(entry.user.name.isNotEmpty
                    ? entry.user.name[0].toUpperCase()
                    : '?'),
              ),
              title: Text(entry.user.fullName),
              subtitle: Text(entry.user.email),
              trailing: PopupMenuButton<_MemberAction>(
                icon: const Icon(Icons.more_vert),
                tooltip: l10n.businessGymMemberActions,
                onSelected: (action) {
                  switch (action) {
                    case _MemberAction.edit:
                      _openEdit(entry);
                    case _MemberAction.resendInvite:
                      _resendInvite(entry);
                    case _MemberAction.remove:
                      _removeMember(entry.memberId);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _MemberAction.edit,
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(l10n.businessGymEditMember),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _MemberAction.resendInvite,
                    child: ListTile(
                      leading: const Icon(Icons.mark_email_unread_outlined),
                      title: Text(l10n.businessGymResendInvite),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _MemberAction.remove,
                    child: ListTile(
                      leading: const Icon(Icons.person_remove_outlined),
                      title: Text(l10n.businessGymRemove),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _MemberAction { edit, resendInvite, remove }
