import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../shop/shop_orders_page.dart';
import '../shop_detail_page.dart';

/// The shops [userId] sells for (shop_vendor rows → businesses), by name.
Future<List<Business>> loadVendorShops(
  ApiService api,
  String token,
  String userId,
) async {
  final rows = await api.getShopVendors(token, userId: userId);
  final ids = {for (final r in rows) r['shop_id'] as String};
  final shops = await Future.wait(ids.map((id) => api.getBusiness(token, id)));
  shops.sort((a, b) => a.name.compareTo(b.name));
  return shops;
}

/// Shop vendor "My Shop" tab. With one shop it shows that shop directly (in
/// vendor mode); with several it shows a picker list.
class VendorShopPage extends StatefulWidget {
  const VendorShopPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<VendorShopPage> createState() => _VendorShopPageState();
}

class _VendorShopPageState extends State<VendorShopPage> {
  final _api = ApiService();
  List<Business> _shops = [];
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
      final shops = await loadVendorShops(_api, token, widget.profile.id);
      if (mounted) {
        setState(() {
          _shops = shops;
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
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (_shops.length == 1) {
      final shop = _shops.first;
      return ShopDetailPage(
        key: ValueKey(shop.id),
        shopId: shop.id,
        shopName: shop.name,
        vendorMode: true,
        embedded: true,
      );
    }

    if (_shops.isEmpty) {
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
                      Icon(
                        Icons.storefront_outlined,
                        size: 48,
                        color: cs.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(context.l10n.shellNotAVendor),
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
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.l10n.shellChooseShop,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final shop in _shops) VendorShopTile(shop: shop),
        ],
      ),
    );
  }
}

/// A shop card that opens the shop in vendor mode.
class VendorShopTile extends StatelessWidget {
  const VendorShopTile({super.key, required this.shop, this.onReturn});

  final Business shop;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        // Decorative: the shop name is the tile title.
        leading: ExcludeSemantics(
          child: shop.logo != null
              ? CircleAvatar(backgroundImage: NetworkImage(shop.logo!))
              : CircleAvatar(
                  backgroundColor: cs.secondaryContainer,
                  child: Icon(Icons.storefront, color: cs.onSecondaryContainer),
                ),
        ),
        title: Text(shop.name),
        subtitle: Text(shop.location),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: context.l10n.shellOrdersForShop(shop.name),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ShopOrdersPage(shopId: shop.id, shopName: shop.name),
                  ),
                );
                onReturn?.call();
              },
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShopDetailPage(
                shopId: shop.id,
                shopName: shop.name,
                vendorMode: true,
              ),
            ),
          );
          onReturn?.call();
        },
      ),
    );
  }
}
