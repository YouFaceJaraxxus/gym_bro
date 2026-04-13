import 'package:flutter/material.dart';
import '../models/shop_item.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'shop_item_form_page.dart';

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
      final items = await _api.getShopItems(token, shopId: widget.shopId);
      if (mounted) {
        setState(() {
          _items = items;
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
              : _buildList(),
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

  Widget _buildList() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text('No items yet'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding:
          const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
      itemCount: _items.length,
      itemBuilder: (_, i) => _ShopItemTile(
        item: _items[i],
        onEdit: () => _openForm(item: _items[i]),
        onDelete: () => _delete(_items[i]),
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
            Text('\$${item.price.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.primary)),
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
