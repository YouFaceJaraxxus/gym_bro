import 'package:flutter/material.dart';
import '../models/business.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'gym_employees_page.dart';
import 'shop_vendors_page.dart';

class OwnerAllStaffPage extends StatefulWidget {
  const OwnerAllStaffPage({super.key});

  @override
  State<OwnerAllStaffPage> createState() => _OwnerAllStaffPageState();
}

class _StaffItem {
  final Business business;
  final UserProfile user;
  final String role;

  const _StaffItem(
      {required this.business, required this.user, required this.role});
}

class _OwnerAllStaffPageState extends State<OwnerAllStaffPage> {
  final _api = ApiService();
  final _search = TextEditingController();

  List<_StaffItem> _all = [];
  List<Business> _businesses = [];
  String? _filterBusinessId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final userId = AuthManager.instance.profile!.id;

      final ownerRecords = await _api.getGymOwners(token, userId: userId);
      final gymIds =
          ownerRecords.map((r) => r['gym_id'] as String).toSet();

      final allBusinesses = await _api.getBusinesses(token);
      final gyms = allBusinesses
          .where((b) => gymIds.contains(b.id) && b.type == 'gym')
          .toList();
      final shops =
          allBusinesses.where((b) => b.type == 'shop').toList();

      final items = <_StaffItem>[];

      for (final gym in gyms) {
        final results = await Future.wait([
          _api.getEmployees(token, gymId: gym.id),
          _api.getEmployeeTrainers(token, gymId: gym.id),
        ]);
        for (final r in results[0]) {
          items.add(_StaffItem(
              business: gym,
              user: UserProfile.fromJson(r),
              role: 'Employee'));
        }
        for (final r in results[1]) {
          items.add(_StaffItem(
              business: gym,
              user: UserProfile.fromJson(r),
              role: 'Emp. Trainer'));
        }
      }

      for (final shop in shops) {
        final vendorRows =
            await _api.getShopVendors(token, shopId: shop.id);
        for (final r in vendorRows) {
          items.add(_StaffItem(
              business: shop,
              user: UserProfile.fromJson(r),
              role: 'Vendor'));
        }
      }

      if (mounted) {
        setState(() {
          _all = items;
          _businesses = [...gyms, ...shops];
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

  List<_StaffItem> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _all.where((s) {
      if (_filterBusinessId != null &&
          s.business.id != _filterBusinessId) {
        return false;
      }
      if (q.isEmpty) return true;
      return s.user.fullName.toLowerCase().contains(q) ||
          s.user.email.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Staff')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
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

  Widget _buildContent() {
    final items = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search staff…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        })
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_businesses.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _filterBusinessId == null,
                    onSelected: (_) =>
                        setState(() => _filterBusinessId = null),
                  ),
                  for (final b in _businesses) ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: Icon(
                          b.type == 'gym'
                              ? Icons.fitness_center
                              : Icons.store,
                          size: 16),
                      label: Text(b.name),
                      selected: _filterBusinessId == b.id,
                      onSelected: (_) =>
                          setState(() => _filterBusinessId = b.id),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No staff found'))
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(item.user.name.isNotEmpty
                                ? item.user.name[0].toUpperCase()
                                : '?'),
                          ),
                          title: Text(item.user.fullName),
                          subtitle: Text(
                              '${item.user.email}  ·  ${item.role}  ·  ${item.business.name}'),
                          trailing: Icon(
                            item.business.type == 'gym'
                                ? Icons.fitness_center
                                : Icons.store,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          onTap: () async {
                            if (item.business.type == 'gym') {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GymEmployeesPage(
                                      gymId: item.business.id,
                                      gymName: item.business.name),
                                ),
                              );
                            } else {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ShopVendorsPage(
                                      shopId: item.business.id,
                                      shopName: item.business.name),
                                ),
                              );
                            }
                            _load();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
