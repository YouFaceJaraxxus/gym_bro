import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../business_form_page.dart';
import '../classes/gym_schedule_page.dart';
import '../gym_detail_page.dart';
import '../posts_page.dart';
import '../shop/shop_orders_page.dart';
import '../shop_detail_page.dart';
import 'business_profile_page.dart';
import 'business_team_page.dart';
import 'business_widgets.dart';

/// One business as its team sees it. What shows depends on the user's roles
/// there: owners get everything, staff the front desk and shop, trainers the
/// schedule and posts. Until a super user approves the business, only the
/// profile can be worked on.
class BusinessManagePage extends StatefulWidget {
  const BusinessManagePage({super.key, required this.businessId});

  final String businessId;

  @override
  State<BusinessManagePage> createState() => _BusinessManagePageState();
}

class _BusinessManagePageState extends State<BusinessManagePage> {
  final _api = ApiService();

  Business? _business;
  String? _error;
  bool _busy = false;

  bool get _isSuper => AuthManager.instance.profile?.isSuperUser ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final b = await _api.getBusiness(token, widget.businessId);
      if (mounted) {
        setState(() {
          _business = b;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _push(Widget page) async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (!mounted) return;
    // The form pops true after a delete too; a missing business closes this.
    if (result == true && page is BusinessFormPage) {
      try {
        final token = await AuthManager.instance.getValidToken();
        await _api.getBusiness(token, widget.businessId);
      } catch (_) {
        if (mounted) Navigator.pop(context);
        return;
      }
    }
    _load();
  }

  Future<void> _resubmit() async {
    setState(() => _busy = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.resubmitBusiness(token, widget.businessId);
      await _load();
      if (mounted) _snack(context.l10n.rolesManageResubmitted);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final b = _business!;
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.rolesManageLeaveTitle(b.name)),
        content: Text(l10n.rolesManageLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.rolesManageLeave),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      final me = AuthManager.instance.profile!.id;
      await _api.removeFromTeam(token, b.id, me);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final b = _business;
    return Scaffold(
      appBar: AppBar(
        title: Text(b?.name ?? ''),
        actions: [
          if (b != null && b.isApproved)
            IconButton(
              tooltip: l10n.rolesManageViewProfile,
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () => _push(BusinessProfilePage(businessId: b.id)),
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            )
          : b == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _body(b)),
    );
  }

  Widget _body(Business b) {
    final l10n = context.l10n;
    final owner = b.isOwner || _isSuper;
    final desk = owner || b.isStaff;
    final live = b.isApproved;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── Who / what ──
        Row(
          children: [
            BusinessAvatar(
              logo: b.logo,
              hasGym: b.hasGym,
              hasShop: b.hasShop,
              radius: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    businessKindLabel(l10n, b.hasGym, b.hasShop),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  RoleChips(roles: b.myRoles),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!live) _StatusBanner(business: b, busy: _busy, onResubmit: _resubmit),

        // ── Profile and team ──
        _Group(
          title: l10n.rolesManageProfileGroup,
          tiles: [
            if (b.canEditProfile || _isSuper)
              _Tile(
                Icons.edit_outlined,
                l10n.rolesManageEditProfile,
                l10n.rolesManageEditProfileSubtitle,
                () => _push(BusinessFormPage(business: b)),
              ),
            if (live)
              _Tile(
                Icons.groups_2_outlined,
                l10n.rolesManageTeam,
                owner
                    ? l10n.rolesManageTeamSubtitleOwner
                    : l10n.rolesManageTeamSubtitle,
                () => _push(
                  BusinessTeamPage(businessId: b.id, businessName: b.name),
                ),
              ),
            if (live)
              _Tile(
                Icons.campaign_outlined,
                l10n.rolesManagePosts,
                l10n.rolesManagePostsSubtitle,
                () => _push(
                  PostsPage(businessId: b.id, businessName: b.name, canPost: true),
                ),
              ),
          ],
        ),

        // ── Gym side ──
        if (live && b.hasGym)
          _Group(
            title: l10n.rolesKindGym,
            tiles: [
              if (desk)
                _Tile(
                  Icons.dashboard_outlined,
                  l10n.rolesManageGymDashboard,
                  l10n.rolesManageGymDashboardSubtitle,
                  () => _push(GymDetailPage(gymId: b.id, gymName: b.name)),
                )
              else
                _Tile(
                  Icons.calendar_month_outlined,
                  l10n.businessGymDetailSchedule,
                  l10n.rolesManageScheduleSubtitle,
                  () => _push(GymSchedulePage(gymId: b.id, gymName: b.name)),
                ),
            ],
          ),

        // ── Shop side ──
        if (live && b.hasShop && desk)
          _Group(
            title: l10n.rolesKindShop,
            tiles: [
              _Tile(
                Icons.inventory_2_outlined,
                l10n.businessMgmtItems,
                l10n.rolesManageProductsSubtitle,
                () => _push(ShopDetailPage(shopId: b.id, shopName: b.name)),
              ),
              _Tile(
                Icons.receipt_long_outlined,
                l10n.businessMgmtOrders,
                l10n.businessMgmtOrdersSubtitle,
                () => _push(ShopOrdersPage(shopId: b.id, shopName: b.name)),
              ),
            ],
          ),

        // ── Leaving ──
        if (b.onTeam && b.status != BusinessStatus.blocked) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _leave,
              icon: const Icon(Icons.logout),
              label: Text(l10n.rolesManageLeave),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Why the owner tools are locked, and what to do about it.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.business,
    required this.busy,
    required this.onResubmit,
  });

  final Business business;
  final bool busy;
  final VoidCallback onResubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final b = business;
    final (icon, title, body) = switch (b.status) {
      BusinessStatus.pending => (
        Icons.hourglass_top_outlined,
        l10n.rolesManagePendingTitle,
        l10n.rolesManagePendingBody,
      ),
      BusinessStatus.rejected => (
        Icons.report_outlined,
        l10n.rolesManageRejectedTitle,
        b.reviewNote ?? '',
      ),
      _ => (
        Icons.block,
        l10n.rolesManageBlockedTitle,
        b.reviewNote ?? '',
      ),
    };
    final warn = b.status == BusinessStatus.pending;
    final bg = warn ? cs.secondaryContainer : cs.errorContainer;
    final fg = warn ? cs.onSecondaryContainer : cs.onErrorContainer;
    return Card(
      color: bg,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(body, style: TextStyle(color: fg)),
            ],
            if (b.status == BusinessStatus.rejected && b.isOwner) ...[
              const SizedBox(height: 12),
              Text(
                l10n.rolesManageRejectedHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: fg,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: busy ? null : onResubmit,
                icon: const Icon(Icons.send_outlined),
                label: Text(l10n.rolesManageResubmit),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile {
  const _Tile(this.icon, this.title, this.subtitle, this.onTap);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.tiles});

  final String title;
  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: cs.surfaceContainerLow,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, t) in tiles.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(t.icon, color: cs.primary),
                  title: Text(t.title),
                  subtitle: Text(t.subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: t.onTap,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
