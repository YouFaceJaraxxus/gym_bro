import 'package:flutter/material.dart';
import '../models/shop_item.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'shop_item_form_page.dart';
import 'shop_vendors_page.dart';

class ShopDetailPage extends StatefulWidget {
  const ShopDetailPage(
      {super.key, required this.shopId, required this.shopName});

  final String shopId;
  final String shopName;

  @override
  State<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends State<ShopDetailPage> {
  final _api = ApiService();
  List<ShopItem> _items = [];
  List<UserProfile> _vendors = [];
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
        _api.getShopVendors(token, shopId: widget.shopId),
      ]);
      if (mounted) {
        setState(() {
          _items = results[0] as List<ShopItem>;
          _vendors = (results[1] as List<Map<String, dynamic>>)
              .map((r) => UserProfile.fromJson(r))
              .toList();
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
        builder: (_) => ShopItemFormPage(
          shopId: widget.shopId,
          item: item,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(ShopItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove "${item.name}" from this shop?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
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
          SnackBar(
              content: Text(
                  e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.shopName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
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
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Vendors section ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Vendors',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShopVendorsPage(
                            shopId: widget.shopId,
                            shopName: widget.shopName),
                      ),
                    );
                    _load();
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_vendors.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.storefront_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(width: 8),
                    Text('No vendors yet',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline)),
                  ],
                ),
              )
            else
              for (final v in _vendors.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(v.name.isNotEmpty
                        ? v.name[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(v.fullName),
                  subtitle: Text(v.email),
                ),
            if (_vendors.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${_vendors.length - 5} more',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary),
                ),
              ),

            const SizedBox(height: 24),

            // ── Items section ─────────────────────────────────────────────
            Text('Items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(width: 8),
                    Text('No items yet',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline)),
                  ],
                ),
              )
            else
              for (final item in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ShopItemTile(
                    item: item,
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
  const _ShopItemTile(
      {required this.item,
      required this.onEdit,
      required this.onDelete});

  final ShopItem item;
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              item.isActive ? cs.primaryContainer : cs.surfaceContainerHighest,
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
                label: const Text('Inactive'),
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
            Text(item.type.displayName,
                style: Theme.of(context).textTheme.bodySmall),
            Row(
              children: [
                Text('\$${item.price.toStringAsFixed(2)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.primary)),
                const SizedBox(width: 12),
                Text('Qty: ${item.quantity}',
                    style: Theme.of(context).textTheme.bodySmall),
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
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: cs.error,
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}
