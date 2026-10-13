import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../invoices_page.dart';
import 'home_widgets.dart';
import 'owner_businesses_page.dart';
import 'owner_users_page.dart';

/// Super-user dashboard: platform-wide stats plus admin shortcuts.
class SuperUserHomePage extends StatefulWidget {
  const SuperUserHomePage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<SuperUserHomePage> createState() => _SuperUserHomePageState();
}

class _SuperUserHomePageState extends State<SuperUserHomePage> {
  final _api = ApiService();
  BusinessStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _stats == null;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final stats = await _api.getBusinessStats(token);
      if (mounted) {
        setState(() {
          _stats = stats;
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

  Future<void> _open(String title, Widget body) async {
    await pushTabPage<void>(context, title, body);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          HomeHeader(
            title: l10n.shellAdminPanel,
            subtitle:
                '${widget.profile.username} · ${widget.profile.role.label(l10n)}',
          ),
          const SizedBox(height: 24),
          _AdminTile(
            icon: Icons.business_outlined,
            label: l10n.shellTabBusinesses,
            subtitle: l10n.shellAdminBusinessesSubtitle,
            onTap: () =>
                _open(l10n.shellTabBusinesses, const OwnerBusinessesPage()),
          ),
          const SizedBox(height: 8),
          _AdminTile(
            icon: Icons.people_outline,
            label: l10n.shellTabUsers,
            subtitle: l10n.shellAdminUsersSubtitle,
            onTap: () => _open(l10n.shellTabUsers, const OwnerUsersPage()),
          ),
          const SizedBox(height: 8),
          _AdminTile(
            icon: Icons.receipt_long_outlined,
            label: l10n.shellInvoices,
            subtitle: l10n.shellAdminInvoicesSubtitle,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InvoicesPage(initialStatus: null),
                ),
              );
              _load();
            },
          ),
          HomeSectionTitle(l10n.shellPlatformOverview),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_error != null) HomeError(message: _error!, onRetry: _load),
            if (stats != null)
              BusinessStatsView(stats: stats, onChanged: _load),
          ],
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 28),
        title: Text(label),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
