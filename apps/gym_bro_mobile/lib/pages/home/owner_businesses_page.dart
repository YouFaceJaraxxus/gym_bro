import 'package:flutter/material.dart';
import '../../models/business.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../business_form_page.dart';
import '../gym_detail_page.dart';
import '../shop_detail_page.dart';

class OwnerBusinessesPage extends StatefulWidget {
  const OwnerBusinessesPage({super.key});

  @override
  State<OwnerBusinessesPage> createState() => _OwnerBusinessesPageState();
}

class _OwnerBusinessesPageState extends State<OwnerBusinessesPage> {
  final _api = ApiService();
  List<Business> _businesses = [];
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
      final businesses = await _api.getBusinesses(token);
      if (mounted) {
        setState(() {
          _businesses = businesses;
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

  Future<void> _openEditForm(Business business) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => BusinessFormPage(business: business)),
    );
    if (saved == true) _load();
  }

  Future<void> _openCreateForm() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const BusinessFormPage()),
    );
    if (saved == true) _load();
  }

  Future<void> _openDetail(Business b) async {
    if (b.type == 'gym') {
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                GymDetailPage(gymId: b.id, gymName: b.name)),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                ShopDetailPage(shopId: b.id, shopName: b.name)),
      );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
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

    final gyms = _businesses.where((b) => b.type == 'gym').toList();
    final shops = _businesses.where((b) => b.type == 'shop').toList();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: _businesses.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: constraints.maxHeight,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.business_outlined,
                                  size: 48,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline),
                              const SizedBox(height: 16),
                              const Text('No businesses yet'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 16, bottom: 88),
                  children: [
                    if (gyms.isNotEmpty) ...[
                      _SectionHeader(
                          icon: Icons.fitness_center, label: 'Gyms'),
                      for (final b in gyms)
                        _BusinessTile(
                          business: b,
                          onTap: () => _openDetail(b),
                          onEdit: () => _openEditForm(b),
                        ),
                      const SizedBox(height: 8),
                    ],
                    if (shops.isNotEmpty) ...[
                      _SectionHeader(
                          icon: Icons.store_outlined, label: 'Shops'),
                      for (final b in shops)
                        _BusinessTile(
                          business: b,
                          onTap: () => _openDetail(b),
                          onEdit: () => _openEditForm(b),
                        ),
                    ],
                  ],
                ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: _openCreateForm,
            icon: const Icon(Icons.add),
            label: const Text('Add Business'),
          ),
        ),
      ],
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _BusinessTile extends StatelessWidget {
  const _BusinessTile(
      {required this.business,
      required this.onTap,
      required this.onEdit});

  final Business business;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isGym = business.type == 'gym';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    isGym ? cs.primaryContainer : cs.secondaryContainer,
                child: Icon(
                  isGym ? Icons.fitness_center : Icons.store,
                  color: isGym
                      ? cs.onPrimaryContainer
                      : cs.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(business.name,
                        style: Theme.of(context).textTheme.bodyLarge),
                    Text(business.location,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
