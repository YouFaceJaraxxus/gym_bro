import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/payment.dart';
import '../models/shop_item.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'business/business_team_page.dart';
import 'posts_page.dart';
import 'shop/order_widgets.dart' show PaymentsConfigCache;
import 'shop/shop_orders_page.dart';
import 'shop_item_form_page.dart';

class ShopDetailPage extends StatefulWidget {
  const ShopDetailPage({
    super.key,
    required this.shopId,
    required this.shopName,
    this.embedded = false,
  });

  final String shopId;
  final String shopName;

  /// Rendered inside another Scaffold (e.g. a business dashboard tab):
  /// no app bar; the shop name and Posts action move into the content.
  final bool embedded;

  @override
  State<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends State<ShopDetailPage> {
  final _api = ApiService();
  List<ShopItem> _items = [];
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
        _api.getShopItems(token, shopId: widget.shopId),
        PaymentsConfigCache.get(_api, token),
      ]);
      if (mounted) {
        setState(() {
          _currency = (results[1] as PaymentsConfig).currency;
          _items = results[0] as List<ShopItem>;
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

  Future<void> _openForm({ShopItem? item}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ShopItemFormPage(shopId: widget.shopId, item: item),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(ShopItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.businessMgmtDeleteItemTitle),
        content: Text(context.l10n.businessMgmtDeleteItemMessage(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteShopItem(token, item.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _openOrders() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ShopOrdersPage(shopId: widget.shopId, shopName: widget.shopName),
    ),
  );

  void _openPosts() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PostsPage(
        businessId: widget.shopId,
        businessName: widget.shopName,
        canPost: true,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(widget.shopName),
              actions: [
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined),
                  tooltip: l10n.businessMgmtOrders,
                  onPressed: _openOrders,
                ),
                IconButton(
                  icon: const Icon(Icons.forum_outlined),
                  tooltip: l10n.businessMgmtPosts,
                  onPressed: _openPosts,
                ),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: Text(l10n.businessMgmtAddItem),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(_error!),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: Text(context.l10n.commonRetry)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 88,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.embedded) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.shopName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openPosts,
                    icon: const Icon(Icons.forum_outlined, size: 18),
                    label: Text(l10n.businessMgmtPosts),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            // ── Orders ────────────────────────────────────────────────────
            Card(
              margin: const EdgeInsets.only(bottom: 20),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.tertiaryContainer,
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                title: Text(l10n.businessMgmtOrders),
                subtitle: Text(l10n.businessMgmtOrdersSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openOrders,
              ),
            ),
            // ── Team ──────────────────────────────────────────────────────
            Card(
              margin: const EdgeInsets.only(bottom: 20),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.badge_outlined,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                title: Text(l10n.rolesMiscTeam),
                subtitle: Text(l10n.rolesMiscTeamHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BusinessTeamPage(
                      businessId: widget.shopId,
                      businessName: widget.shopName,
                    ),
                  ),
                ),
              ),
            ),

            // ── Items section ─────────────────────────────────────────────
            Text(
              l10n.businessMgmtItems,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.businessMgmtNoItemsYet,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final item in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ShopItemTile(
                    item: item,
                    currency: _currency,
                    onEdit: () => _openForm(item: item),
                    onDelete: () => _delete(item),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _ShopItemTile extends StatelessWidget {
  const _ShopItemTile({
    required this.item,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  final ShopItem item;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  IconData _typeIcon(ShopItemType t) => switch (t) {
    ShopItemType.equipment => Icons.fitness_center,
    ShopItemType.supplement => Icons.science_outlined,
    ShopItemType.giftCard => Icons.card_giftcard_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: item.imageUrl != null
            // Decorative: the item name is in the title.
            ? ExcludeSemantics(
                child: CircleAvatar(
                  backgroundImage: NetworkImage(item.imageUrl!),
                ),
              )
            : CircleAvatar(
                backgroundColor: item.isActive
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                child: Icon(
                  _typeIcon(item.type),
                  color: item.isActive
                      ? cs.onPrimaryContainer
                      : cs.onSurfaceVariant,
                ),
              ),
        title: Row(
          children: [
            Expanded(child: Text(item.name)),
            if (!item.isActive)
              Chip(
                label: Text(l10n.businessMgmtItemInactive),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                backgroundColor: cs.errorContainer,
                labelStyle: TextStyle(color: cs.onErrorContainer),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.type.label(l10n),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              children: [
                Text(
                  formatMoney(item.price, currency, locale),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  item.quantity <= 0
                      ? l10n.businessMgmtOutOfStock
                      : l10n.businessMgmtQuantity(item.quantity),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: item.quantity <= 0 ? cs.error : null,
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: l10n.businessMgmtEditNamed(item.name),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: cs.error,
              onPressed: onDelete,
              tooltip: l10n.businessMgmtDeleteNamed(item.name),
            ),
          ],
        ),
      ),
    );
  }
}
