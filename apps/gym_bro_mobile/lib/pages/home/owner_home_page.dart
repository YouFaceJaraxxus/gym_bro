import 'package:flutter/material.dart';
import '../../models/business.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../invoices_page.dart';
import 'home_widgets.dart';

/// Owner dashboard: live stats across the gyms the owner manages.
class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
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

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          HomeHeader(
            title: 'Welcome back, ${widget.profile.name}',
            subtitle: widget.profile.role.displayName,
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_error != null) HomeError(message: _error!, onRetry: _load),
            if (stats != null) ...[
              if (stats.gyms == 0)
                const HomeEmpty(
                  icon: Icons.fitness_center_outlined,
                  label: "You don't own any gyms yet — add one from the "
                      'Businesses tab.',
                )
              else ...[
                BusinessStatsView(stats: stats, onChanged: _load),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const InvoicesPage(initialStatus: null)),
                    );
                    _load();
                  },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('All invoices'),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
