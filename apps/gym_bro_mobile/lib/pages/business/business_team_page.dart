import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/person_tile.dart';
import '../../widgets/social_widgets.dart';
import '../../widgets/user_search_field.dart';
import 'business_widgets.dart';

/// The people who run a business: owners, staff and trainers, plus open
/// invites. Owners invite people (they join once they accept), change and
/// remove roles; anyone can drop their own roles.
class BusinessTeamPage extends StatefulWidget {
  const BusinessTeamPage({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  final String businessId;
  final String businessName;

  @override
  State<BusinessTeamPage> createState() => _BusinessTeamPageState();
}

class _BusinessTeamPageState extends State<BusinessTeamPage> {
  final _api = ApiService();

  List<TeamMember>? _team;
  bool _isOwner = false;
  String? _error;

  String get _me => AuthManager.instance.profile?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait([
        _api.getBusinessTeam(token, widget.businessId),
        _api.getBusiness(token, widget.businessId),
      ]);
      final business = results[1] as Business;
      if (!mounted) return;
      setState(() {
        _team = results[0] as List<TeamMember>;
        _isOwner =
            business.isOwner ||
            (AuthManager.instance.profile?.isSuperUser ?? false);
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _remove(TeamMember m, BusinessRole role) async {
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.removeFromTeam(token, widget.businessId, m.userId, role: role);
      if (m.userId == _me) {
        await AuthManager.instance.updateProfile(await _api.getMe(token));
      }
      await _load();
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _invite(String userId, BusinessRole role) async {
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.inviteToTeam(
        token,
        widget.businessId,
        role: role,
        userId: userId,
      );
      // Owners give themselves a role straight away; others get an invite.
      if (userId == _me) {
        await AuthManager.instance.updateProfile(await _api.getMe(token));
      }
      await _load();
      if (!mounted) return;
      _snack(
        userId == _me
            ? context.l10n.rolesTeamRoleAdded
            : context.l10n.rolesTeamInviteSent,
      );
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openInvite() async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _InvitePage(
          businessId: widget.businessId,
          businessName: widget.businessName,
          teamIds: {for (final m in _team ?? <TeamMember>[]) m.userId},
        ),
      ),
    );
    if (sent == true) {
      await _load();
      if (mounted) _snack(context.l10n.rolesTeamInviteSent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final team = _team;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.rolesTeamTitle(widget.businessName))),
      floatingActionButton: _isOwner
          ? FloatingActionButton.extended(
              onPressed: _openInvite,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.rolesTeamInvite),
            )
          : null,
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _load,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            )
          : team == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 96),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      l10n.rolesTeamExplainer,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final m in team)
                    _MemberTile(
                      member: m,
                      isMe: m.userId == _me,
                      canManage: _isOwner,
                      onRemove: (role) => _remove(m, role),
                      onInvite: (role) => _invite(m.userId, role),
                    ),
                ],
              ),
            ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.canManage,
    required this.onRemove,
    required this.onInvite,
  });

  final TeamMember member;
  final bool isMe;
  final bool canManage;
  final ValueChanged<BusinessRole> onRemove;
  final ValueChanged<BusinessRole> onInvite;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final m = member;
    final active = [
      for (final r in m.roles)
        if (r.active) r.role,
    ];
    final invited = [
      for (final r in m.roles)
        if (!r.active) r.role,
    ];
    final initials =
        '${m.name.isNotEmpty ? m.name[0] : ''}${m.lastName.isNotEmpty ? m.lastName[0] : ''}'
            .toUpperCase();

    // What the menu offers: owners manage anyone; people manage themselves.
    final entries = <PopupMenuEntry<(BusinessRole, bool)>>[
      if (canManage || isMe)
        for (final r in active)
          PopupMenuItem(
            value: (r, false),
            child: Text(
              isMe
                  ? l10n.rolesTeamStopBeing(businessRoleLabel(l10n, r))
                  : l10n.rolesTeamRemoveAs(businessRoleLabel(l10n, r)),
            ),
          ),
      if (canManage)
        for (final r in invited)
          PopupMenuItem(
            value: (r, false),
            child: Text(
              l10n.rolesTeamCancelInvite(businessRoleLabel(l10n, r)),
            ),
          ),
      if (canManage)
        for (final r in BusinessRole.values)
          if (!active.contains(r) && !invited.contains(r))
            PopupMenuItem(
              value: (r, true),
              child: Text(
                isMe
                    ? l10n.rolesTeamAddRoleSelf(businessRoleLabel(l10n, r))
                    : l10n.rolesTeamInviteAs(businessRoleLabel(l10n, r)),
              ),
            ),
    ];

    return ListTile(
      leading: UserAvatar(url: m.avatarUrl, initials: initials),
      title: Text(
        isMe ? l10n.rolesTeamYou(m.fullName) : m.fullName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.email?.isNotEmpty == true ? m.email! : '@${m.username}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          RoleChips(roles: active, invited: invited),
        ],
      ),
      isThreeLine: true,
      onTap: () => openUserProfile(context, m.userId),
      trailing: entries.isEmpty
          ? null
          : PopupMenuButton<(BusinessRole, bool)>(
              tooltip: l10n.rolesTeamActionsFor(m.fullName),
              itemBuilder: (_) => entries,
              onSelected: (v) => v.$2 ? onInvite(v.$1) : onRemove(v.$1),
            ),
    );
  }
}

/// Owner's invite screen: pick a role, then someone already on Gym Bro, or
/// invite a new person by email (they get an account invite too).
class _InvitePage extends StatefulWidget {
  const _InvitePage({
    required this.businessId,
    required this.businessName,
    required this.teamIds,
  });

  final String businessId;
  final String businessName;
  final Set<String> teamIds;

  @override
  State<_InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<_InvitePage> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();

  BusinessRole _role = BusinessRole.staff;
  bool _byEmail = false;
  String? _sendingTo;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _name, _lastName, _username]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send({String? userId}) async {
    if (userId == null && !_formKey.currentState!.validate()) return;
    setState(() {
      _sendingTo = userId ?? '';
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.inviteToTeam(
        token,
        widget.businessId,
        role: _role,
        userId: userId,
        email: userId == null ? _email.text.trim() : null,
        name: userId == null ? _name.text.trim() : null,
        lastName: userId == null ? _lastName.text.trim() : null,
        username: userId == null ? _username.text.trim() : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _sendingTo = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String? requiredField(String? v) =>
        (v == null || v.trim().isEmpty) ? l10n.commonRequired : null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.rolesTeamInviteTitle(widget.businessName))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.rolesTeamInviteRole, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<BusinessRole>(
              segments: [
                ButtonSegment(
                  value: BusinessRole.staff,
                  icon: const Icon(Icons.badge_outlined),
                  label: Text(l10n.rolesRoleStaff),
                ),
                ButtonSegment(
                  value: BusinessRole.trainer,
                  icon: const Icon(Icons.sports_outlined),
                  label: Text(l10n.rolesRoleTrainer),
                ),
                ButtonSegment(
                  value: BusinessRole.owner,
                  icon: const Icon(Icons.key_outlined),
                  label: Text(l10n.rolesRoleCoOwner),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              switch (_role) {
                BusinessRole.staff => l10n.rolesTeamStaffHint,
                BusinessRole.trainer => l10n.rolesTeamTrainerHint,
                BusinessRole.owner => l10n.rolesTeamOwnerHint,
              },
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.search),
                  label: Text(l10n.rolesTeamFindPerson),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.alternate_email),
                  label: Text(l10n.rolesTeamByEmail),
                ),
              ],
              selected: {_byEmail},
              onSelectionChanged: (s) => setState(() => _byEmail = s.first),
            ),
            const SizedBox(height: 16),
            if (!_byEmail)
              UserSearchField(
                excludeUserIds: widget.teamIds,
                addingUserId: _sendingTo,
                enabled: _sendingTo == null,
                onSelect: (u) => _send(userId: u.id),
              )
            else
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.rolesTeamByEmailHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: l10n.rolesTeamEmail),
                      validator: requiredField,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _name,
                      decoration: InputDecoration(labelText: l10n.rolesTeamFirstName),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lastName,
                      decoration: InputDecoration(labelText: l10n.rolesTeamLastName),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _username,
                      decoration: InputDecoration(labelText: l10n.rolesTeamUsername),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _sendingTo != null ? null : () => _send(),
                      icon: const Icon(Icons.send_outlined),
                      label: Text(l10n.rolesTeamSendInvite),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
