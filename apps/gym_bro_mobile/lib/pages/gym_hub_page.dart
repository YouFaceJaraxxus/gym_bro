import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/check_in.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'business/business_profile_page.dart';
import 'business/business_search_page.dart';
import 'business/business_widgets.dart';
import 'checkin/member_check_in_page.dart';
import 'shop/buy_membership_page.dart';
import 'shop/storefront_page.dart';

/// The Gym tab: places. The gyms the user is a member of (to their profile),
/// checking in, buying a membership, the store, and finding gyms and shops.
/// Personal tools (workouts, nutrition, …) live in the Home menu.
class GymHubPage extends StatefulWidget {
  const GymHubPage({super.key, this.profile});

  final UserProfile? profile;

  @override
  State<GymHubPage> createState() => _GymHubPageState();
}

class _GymHubPageState extends State<GymHubPage> {
  /// Gyms the user is a member of; null while loading.
  List<CheckInGym>? _gyms;

  @override
  void initState() {
    super.initState();
    _loadGyms();
  }

  Future<void> _loadGyms() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await ApiService().getCheckInGyms(token);
      if (mounted) setState(() => _gyms = rows.where((g) => g.isMember).toList());
    } catch (_) {
      // The list just stays empty; everything else on the hub works.
      if (mounted) setState(() => _gyms = const []);
    }
  }

  void _push(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gyms = _gyms ?? const <CheckInGym>[];
    return RefreshIndicator(
      onRefresh: _loadGyms,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          if (gyms.isNotEmpty) ...[
            Text(l10n.rolesHubMyGyms, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: gyms.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final g = gyms[i];
                  return SizedBox(
                    width: 96,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _push(BusinessProfilePage(businessId: g.gymId)),
                      child: Column(
                        children: [
                          const SizedBox(height: 6),
                          BusinessAvatar(
                            logo: g.logo,
                            hasGym: true,
                            hasShop: false,
                            radius: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            g.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _HubCard(
              icon: Icons.qr_code_2,
              label: l10n.shellHubCheckIn,
              subtitle: l10n.shellHubCheckInSubtitle,
              onTap: () => _push(const MemberCheckInPage()),
            ),
            const SizedBox(height: 14),
          ],
          _HubCard(
            icon: Icons.card_membership_outlined,
            label: l10n.rolesMenuBuyMembership,
            subtitle: l10n.rolesHubBuyMembershipSubtitle,
            onTap: () => _push(const BuyMembershipPage()),
          ),
          const SizedBox(height: 14),
          _HubCard(
            icon: Icons.storefront_outlined,
            label: l10n.shellHubStore,
            subtitle: l10n.shellHubStoreSubtitle,
            onTap: () => _push(const StorefrontPage()),
          ),
          const SizedBox(height: 14),
          _HubCard(
            icon: Icons.travel_explore,
            label: l10n.rolesSearchTitle,
            subtitle: l10n.rolesHubFindSubtitle,
            onTap: () => _push(const BusinessSearchPage()),
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // One button for screen readers: "<label>, <subtitle>".
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 28, color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
