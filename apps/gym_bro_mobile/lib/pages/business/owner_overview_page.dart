import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../home/home_widgets.dart';
import '../invoices_page.dart';

/// Numbers across the gyms the user owns (every gym, for a super user):
/// members, memberships, staff, invoices, memberships expiring soon.
class OwnerOverviewPage extends StatefulWidget {
  const OwnerOverviewPage({super.key});

  @override
  State<OwnerOverviewPage> createState() => _OwnerOverviewPageState();
}

class _OwnerOverviewPageState extends State<OwnerOverviewPage> {
  BusinessStats? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final stats = await ApiService().getBusinessStats(token);
      if (mounted) {
        setState(() {
          _stats = stats;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rolesMenuOwnerOverview),
        actions: [
          IconButton(
            tooltip: l10n.shellOwnerAllInvoices,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoicesPage()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (_error != null)
              HomeError(message: _error!, onRetry: _load)
            else if (stats == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              BusinessStatsView(stats: stats, onChanged: _load),
          ],
        ),
      ),
    );
  }
}
