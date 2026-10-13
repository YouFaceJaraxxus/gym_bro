import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'cart_service.dart';
import 'my_orders_page.dart';
import 'order_widgets.dart';
import 'storefront_shop_page.dart';

/// Browse every shop and buy from it.
class StorefrontPage extends StatefulWidget {
  const StorefrontPage({super.key});

  @override
  State<StorefrontPage> createState() => _StorefrontPageState();
}

class _StorefrontPageState extends State<StorefrontPage> {
  final _api = ApiService();
  final _cart = CartService.instance;
  List<StorefrontShop> _shops = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cart.ensureLoaded();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final shops = await _api.getStorefrontShops(token);
      // Warm the payments config so the checkout sheet opens instantly.
      PaymentsConfigCache.get(_api, token).ignore();
      if (mounted) {
        setState(() {
          _shops = shops;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _loading = false;
        });
      }
    }
  }

  void _openShop(StorefrontShop shop) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => StorefrontShopPage(shopId: shop.id, shopName: shop.name),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.businessShopShop),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: l10n.businessShopMyOrders,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyOrdersPage()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ShopErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: _shops.isEmpty
                  ? ShopEmptyState(
                      icon: Icons.storefront_outlined,
                      title: l10n.businessShopNoShopsYet,
                      message: l10n.businessShopNoShopsYetMessage,
                    )
                  : ListenableBuilder(
                      listenable: _cart,
                      builder: (context, _) => ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _shops.length,
                        itemBuilder: (context, i) => _ShopCard(
                          shop: _shops[i],
                          cartCount: _cart.countFor(_shops[i].id),
                          onTap: () => _openShop(_shops[i]),
                        ),
                      ),
                    ),
            ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.shop,
    required this.cartCount,
    required this.onTap,
  });

  final StorefrontShop shop;
  final int cartCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    String? hours;
    if (shop.workingHoursFrom != null && shop.workingHoursTo != null) {
      // "HH:mm[:ss]" from the API, shown in the user's time format.
      String hm(String t) {
        final parts = t.split(':');
        final h = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
        final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
        if (h == null || m == null) return t;
        return TimeOfDay(hour: h, minute: m).format(context);
      }

      hours = '${hm(shop.workingHoursFrom!)}–${hm(shop.workingHoursTo!)}';
    }
    return MergeSemantics(
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 14),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 6,
                child: shop.logo != null
                    ? Image.network(
                        shop.logo!,
                        fit: BoxFit.cover,
                        // Decorative banner: the shop name is shown below.
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => _placeholder(cs),
                      )
                    : _placeholder(cs),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shop.name, style: tt.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            shop.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            [
                              l10n.businessShopProductCount(
                                shop.activeItemCount,
                              ),
                              ?hours,
                            ].join(' · '),
                            style: tt.bodySmall?.copyWith(color: cs.primary),
                          ),
                        ],
                      ),
                    ),
                    if (cartCount > 0)
                      Semantics(
                        label: l10n.businessShopInCartCount(cartCount),
                        excludeSemantics: true,
                        child: Badge.count(
                          count: cartCount,
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            color: cs.primary,
                          ),
                        ),
                      )
                    else
                      Icon(Icons.chevron_right, color: cs.outline),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
    color: cs.secondaryContainer,
    child: Icon(Icons.storefront, size: 40, color: cs.onSecondaryContainer),
  );
}
