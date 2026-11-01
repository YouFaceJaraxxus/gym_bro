import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'business_profile_page.dart';
import 'business_widgets.dart';

/// Invites to join a gym's or shop's team that the user hasn't answered.
/// Accepting makes the role active (and a trainer invite turns on the
/// trainer tools); declining removes the invite.
class BusinessInvitesPage extends StatefulWidget {
  const BusinessInvitesPage({super.key});

  @override
  State<BusinessInvitesPage> createState() => _BusinessInvitesPageState();
}

class _BusinessInvitesPageState extends State<BusinessInvitesPage> {
  final _api = ApiService();

  List<BusinessInvite>? _invites;
  String? _error;

  /// `businessId/role` of the invite being answered.
  String? _answering;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final invites = await _api.getMyBusinessInvites(token);
      if (mounted) {
        setState(() {
          _invites = invites;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _answer(BusinessInvite invite, bool accept) async {
    final l10n = context.l10n;
    setState(() => _answering = '${invite.businessId}/${invite.role.name}');
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.answerBusinessInvite(
        token,
        invite.businessId,
        invite.role,
        accept: accept,
      );
      await AuthManager.instance.updateProfile(await _api.getMe(token));
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? l10n.rolesInvitesJoined(invite.businessName)
                : l10n.rolesInvitesDeclined,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _answering = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final invites = _invites;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.rolesInvitesTitle)),
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
          : invites == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: invites.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Icon(
                          Icons.mark_email_read_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Center(child: Text(l10n.rolesInvitesEmpty)),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: invites.length,
                      itemBuilder: (context, i) {
                        final inv = invites[i];
                        final busy =
                            _answering == '${inv.businessId}/${inv.role.name}';
                        return _InviteCard(
                          invite: inv,
                          busy: busy,
                          disabled: _answering != null,
                          onAnswer: (accept) => _answer(inv, accept),
                        );
                      },
                    ),
            ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invite,
    required this.busy,
    required this.disabled,
    required this.onAnswer,
  });

  final BusinessInvite invite;
  final bool busy;
  final bool disabled;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inv = invite;
    final role = businessRoleLabel(l10n, inv.role);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      BusinessProfilePage(businessId: inv.businessId),
                ),
              ),
              child: Row(
                children: [
                  BusinessAvatar(
                    logo: inv.logo,
                    hasGym: inv.hasGym,
                    hasShop: inv.hasShop,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv.businessName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          businessKindLabel(l10n, inv.hasGym, inv.hasShop),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              inv.inviterName == null
                  ? l10n.rolesInvitesAs(role)
                  : l10n.rolesInvitesFrom(inv.inviterName!, role),
            ),
            if (inv.role == BusinessRole.trainer) ...[
              const SizedBox(height: 4),
              Text(
                l10n.rolesInvitesTrainerNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                TextButton(
                  onPressed: disabled ? null : () => onAnswer(false),
                  child: Text(l10n.rolesInviteDecline),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: disabled ? null : () => onAnswer(true),
                  child: Text(l10n.rolesInviteAccept),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
