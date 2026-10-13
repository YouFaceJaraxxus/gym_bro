import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'order_detail_page.dart';
import 'order_widgets.dart';
import 'storefront_page.dart';

/// The signed-in user's shop orders, newest first.
class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  final _api = ApiService();
  List<ShopOrder> _orders = [];
  String _currency = PaymentsConfigCache.current.currency;
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
      final results = await Future.wait([
        _api.getMyOrders(token),
        PaymentsConfigCache.get(_api, token),
      ]);
      if (mounted) {
        setState(() {
          _orders = results[0] as List<ShopOrder>;
          _currency = PaymentsConfigCache.current.currency;
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

  Future<void> _open(ShopOrder order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: order.id)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.businessShopMyOrders)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ShopErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: _orders.isEmpty
                  ? ShopEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.businessShopNoOrdersYet,
                      message: l10n.businessShopNoOrdersYetMessage,
                      action: FilledButton.icon(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StorefrontPage(),
                          ),
                        ),
                        icon: const Icon(Icons.storefront_outlined),
                        label: Text(l10n.businessShopBrowseShops),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, i) => OrderTile(
                        order: _orders[i],
                        currency: _currency,
                        onTap: () => _open(_orders[i]),
                      ),
                    ),
            ),
    );
  }
}
