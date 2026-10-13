import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/business.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../shop/shop_orders_page.dart';
import 'home_widgets.dart';
import 'vendor_shop_page.dart';

/// Shop vendor home: the shops they sell for.
class VendorHomePage extends StatefulWidget {
  const VendorHomePage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<VendorHomePage> createState() => _VendorHomePageState();
}

class _VendorHomePageState extends State<VendorHomePage> {
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
      _loading = _shops.isEmpty;
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          HomeHeader(
            title: context.l10n.shellHello(widget.profile.name),
            subtitle: widget.profile.role.label(context.l10n),
          ),
          HomeSectionTitle(
            _shops.length == 1
                ? context.l10n.shellYourShop
                : context.l10n.shellYourShops,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            HomeError(message: _error!, onRetry: _load)
          else if (_shops.isEmpty)
            HomeEmpty(
              icon: Icons.storefront_outlined,
              label: context.l10n.shellNotAVendor,
            )
          else
            for (final shop in _shops) ...[
              VendorShopTile(shop: shop, onReturn: _load),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ShopOrdersPage(shopId: shop.id, shopName: shop.name),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: Text(context.l10n.shellOrdersForShop(shop.name)),
                ),
              ),
            ],
        ],
      ),
    );
  }
}
