import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/payment.dart';
import '../../models/shop_item.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/quantity_input.dart';
import 'cart_service.dart';
import 'cart_sheet.dart';
import 'order_widgets.dart';

/// One shop's products: search, filter by type, add to cart, check out.
class StorefrontShopPage extends StatefulWidget {
  const StorefrontShopPage({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  final String shopId;
  final String shopName;

  @override
  State<StorefrontShopPage> createState() => _StorefrontShopPageState();
}

class _StorefrontShopPageState extends State<StorefrontShopPage> {
  final _api = ApiService();
  final _cart = CartService.instance;
  final _searchCtrl = TextEditingController();
  List<ShopItem> _items = [];
  PaymentsConfig _config = PaymentsConfigCache.current;
  ShopItemType? _type;
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait([
        _api.getShopItems(token, shopId: widget.shopId, activeOnly: true),
        PaymentsConfigCache.get(_api, token),
        _cart.ensureLoaded(),
      ]);
      final now = DateTime.now();
      final items =
          (results[0] as List<ShopItem>)
              .where(
                (i) => i.activeUntil == null || i.activeUntil!.isAfter(now),
              )
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
      final removed = _cart.reconcile(widget.shopId, items);
      if (mounted) {
        setState(() {
          _items = items;
          _config = results[1] as PaymentsConfig;
          _loading = false;
        });
        if (removed.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.businessShopRemovedFromCart(removed.join(', ')),
              ),
            ),
          );
        }
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

  List<ShopItem> get _visible {
    final q = _query.trim().toLowerCase();
    return _items.where((i) {
      if (_type != null && i.type != _type) return false;
      if (q.isEmpty) return true;
      return i.name.toLowerCase().contains(q) ||
          (i.description?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _openItem(ShopItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ItemSheet(item: item, currency: _config.currency),
    );
  }

  Future<void> _openCart() async {
    await showCartSheet(
      context,
      shopId: widget.shopId,
      shopName: widget.shopName,
      config: _config,
      onStockProblem: _load,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _cart,
      builder: (context, _) {
        final count = _cart.countFor(widget.shopId);
        final l10n = context.l10n;
        final locale = Localizations.localeOf(context).toString();
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.shopName),
            actions: [
              IconButton(
                tooltip: l10n.businessShopCart,
                onPressed: _openCart,
                icon: Badge.count(
                  count: count,
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
              ),
            ],
          ),
          body: _buildBody(),
          floatingActionButton: count > 0 && !_loading && _error == null
              ? FloatingActionButton.extended(
                  onPressed: _openCart,
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: Text(
                    l10n.businessShopCartTotal(
                      formatMoney(
                        _cart.totalFor(widget.shopId),
                        _config.currency,
                        locale,
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ShopErrorState(message: _error!, onRetry: _load);

    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final visible = _visible;
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.businessShopSearchProducts,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.businessShopClearSearch,
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(l10n.businessShopFilterAll),
                    selected: _type == null,
                    onSelected: (_) => setState(() => _type = null),
                  ),
                  for (final t in ShopItemType.values) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(t.label(l10n)),
                      selected: _type == t,
                      onSelected: (_) =>
                          setState(() => _type = _type == t ? null : t),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 56,
                        color: cs.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _items.isEmpty
                            ? l10n.businessShopNoProductsYet
                            : l10n.businessShopNoProductsMatch,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.68,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ProductCard(
                    item: visible[i],
                    currency: _config.currency,
                    inCart: _cart.quantityOf(widget.shopId, visible[i].id),
                    onTap: () => _openItem(visible[i]),
                  ),
                  childCount: visible.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

IconData shopItemTypeIcon(ShopItemType t) => switch (t) {
  ShopItemType.equipment => Icons.fitness_center,
  ShopItemType.supplement => Icons.science_outlined,
  ShopItemType.giftCard => Icons.card_giftcard_outlined,
};

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.item, this.decorative = true});

  final ShopItem item;

  /// When false the photo is announced with the product name.
  final bool decorative;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: cs.surfaceContainerHighest,
      child: Icon(
        shopItemTypeIcon(item.type),
        size: 40,
        color: cs.onSurfaceVariant,
      ),
    );
    if (item.imageUrl == null) return placeholder;
    return Image.network(
      item.imageUrl!,
      fit: BoxFit.cover,
      semanticLabel: decorative ? null : item.name,
      excludeFromSemantics: decorative,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.item,
    required this.currency,
    required this.inCart,
    required this.onTap,
  });

  final ShopItem item;
  final String currency;
  final int inCart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final soldOut = item.quantity <= 0;
    final l10n = context.l10n;
    return MergeSemantics(
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ProductImage(item: item),
                    if (inCart > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Semantics(
                          label: l10n.businessShopInCartCount(inCart),
                          excludeSemantics: true,
                          child: Badge.count(
                            count: inCart,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: cs.primary,
                              child: Icon(
                                Icons.shopping_cart,
                                size: 16,
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          formatMoney(
                            item.price,
                            currency,
                            Localizations.localeOf(context).toString(),
                          ),
                          style: tt.titleSmall?.copyWith(color: cs.primary),
                        ),
                        const Spacer(),
                        Text(
                          soldOut
                              ? l10n.businessShopSoldOut
                              : item.quantity <= 5
                              ? l10n.businessShopLeftCount(item.quantity)
                              : '',
                          style: tt.labelSmall?.copyWith(
                            color: soldOut ? cs.error : cs.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Product details with a quantity stepper and "Add to cart".
class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.item, required this.currency});

  final ShopItem item;
  final String currency;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  final _cart = CartService.instance;
  int _qty = 1;

  int get _inCart => _cart.quantityOf(widget.item.shopId, widget.item.id);
  int get _canAdd => (widget.item.quantity - _inCart).clamp(0, 999);

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final soldOut = item.quantity <= 0;
    final canAdd = _canAdd;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: _ProductImage(item: item, decorative: false),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(shopItemTypeIcon(item.type), size: 16, color: cs.outline),
                const SizedBox(width: 4),
                Text(
                  item.type.label(l10n),
                  style: tt.labelMedium?.copyWith(color: cs.outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(item.name, style: tt.headlineSmall),
            const SizedBox(height: 4),
            Text(
              formatMoney(item.price, widget.currency, locale),
              style: tt.titleLarge?.copyWith(color: cs.primary),
            ),
            if (item.description != null && item.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(item.description!, style: tt.bodyMedium),
            ],
            const SizedBox(height: 12),
            Text(
              soldOut
                  ? l10n.businessShopOutOfStock
                  : [
                      l10n.businessShopInStock(item.quantity),
                      if (_inCart > 0) l10n.businessShopInYourCart(_inCart),
                    ].join(' · '),
              style: tt.bodySmall?.copyWith(
                color: soldOut ? cs.error : cs.onSurfaceVariant,
              ),
            ),
            if (item.activeUntil != null) ...[
              const SizedBox(height: 4),
              Text(
                l10n.businessShopAvailableUntil(
                  formatDate(item.activeUntil!, locale),
                ),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 20),
            if (!soldOut && canAdd > 0)
              Row(
                children: [
                  QuantityInput(
                    value: _qty.clamp(1, canAdd),
                    min: 1,
                    max: canAdd,
                    onChanged: (v) => setState(() => _qty = v),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        final qty = _qty.clamp(1, canAdd);
                        _cart.add(item, qty);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.businessShopAddedToCart(qty, item.name),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text(
                        l10n.businessShopAddWithPrice(
                          formatMoney(
                            item.price * _qty.clamp(1, canAdd),
                            widget.currency,
                            locale,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              FilledButton(
                onPressed: null,
                child: Text(
                  soldOut
                      ? l10n.businessShopOutOfStock
                      : l10n.businessShopAllStockInCart,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
