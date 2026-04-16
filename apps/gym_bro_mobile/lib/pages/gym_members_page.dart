import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'add_gym_member_page.dart';
import 'edit_gym_member_page.dart';
import 'invite_gym_member_page.dart';

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
      final results = await Future.wait([
        _api.getMembers(token, gymId: widget.gymId),
        _api.getUsers(token),
      ]);
      final memberRows = results[0] as List<Map<String, dynamic>>;
      final allUsers = results[1] as List<UserProfile>;
      final userMap = {for (final u in allUsers) u.id: u};

      if (mounted) {
        setState(() {
          _members = memberRows
              .map((r) {
                final u = userMap[r['user_id'] as String];
                if (u == null) return null;
                return (memberId: r['id'] as String, user: u);
              })
              .whereType<({String memberId, UserProfile user})>()
              .toList();
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
          const SnackBar(content: Text('Invite resent')),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove member?'),
        content: const Text('This will remove the member from this gym.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
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
        ),
      ),
    );
    if (result == 'removed') _load();
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Add existing user'),
              subtitle: const Text('Search users already in the system'),
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
              title: const Text('Invite new member'),
              subtitle: const Text('Send an invite link by email'),
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
      appBar: AppBar(title: Text('${widget.gymName} — Members')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Member'),
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
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildList() {
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
                      const Text('No members yet'),
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
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _MemberAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit Member'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _MemberAction.resendInvite,
                    child: ListTile(
                      leading: Icon(Icons.mark_email_unread_outlined),
                      title: Text('Resend Invite'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _MemberAction.remove,
                    child: ListTile(
                      leading: Icon(Icons.person_remove_outlined),
                      title: Text('Remove'),
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
