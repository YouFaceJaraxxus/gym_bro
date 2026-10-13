import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/shop_item.dart';

/// One product in a cart, with enough info to render the cart offline.
class CartLine {
  final String itemId;
  final String shopId;
  final String name;
  final double price;
  final String? imageUrl;

  /// Stock when the item was added; caps the quantity stepper.
  final int maxQuantity;
  final int quantity;

  const CartLine({
    required this.itemId,
    required this.shopId,
    required this.name,
    required this.price,
    this.imageUrl,
    required this.maxQuantity,
    required this.quantity,
  });

  double get lineTotal => price * quantity;

  CartLine copyWith({int? quantity, double? price, int? maxQuantity}) =>
      CartLine(
        itemId: itemId,
        shopId: shopId,
        name: name,
        price: price ?? this.price,
        imageUrl: imageUrl,
        maxQuantity: maxQuantity ?? this.maxQuantity,
        quantity: quantity ?? this.quantity,
      );

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'shop_id': shopId,
        'name': name,
        'price': price,
        'image_url': imageUrl,
        'max_quantity': maxQuantity,
        'quantity': quantity,
      };

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        itemId: json['item_id'] as String,
        shopId: json['shop_id'] as String,
        name: json['name'] as String? ?? 'Item',
        price: double.parse(json['price'].toString()),
        imageUrl: json['image_url'] as String?,
        maxQuantity: int.tryParse(json['max_quantity'].toString()) ?? 99,
        quantity: int.tryParse(json['quantity'].toString()) ?? 1,
      );
}

/// Per-shop shopping carts, persisted across app restarts.
///
/// Orders are placed per shop, so each shop has its own cart.
class CartService extends ChangeNotifier {
  CartService._();
  static final instance = CartService._();

  static const _prefsKey = 'shop_carts_v1';

  /// shopId → itemId → line (insertion ordered).
  final Map<String, Map<String, CartLine>> _carts = {};
  bool _loaded = false;
  Future<void>? _loading;

  /// Loads persisted carts once; safe to call repeatedly.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        for (final e in list) {
          final line = CartLine.fromJson(e as Map<String, dynamic>);
          (_carts[line.shopId] ??= {})[line.itemId] = line;
        }
      }
    } catch (e) {
      debugPrint('CartService: could not restore carts: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = [
        for (final cart in _carts.values)
          for (final line in cart.values) line.toJson(),
      ];
      await prefs.setString(_prefsKey, jsonEncode(all));
    } catch (e) {
      debugPrint('CartService: could not save carts: $e');
    }
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  bool get isLoaded => _loaded;

  List<CartLine> linesFor(String shopId) =>
      List.unmodifiable(_carts[shopId]?.values ?? const <CartLine>[]);

  int quantityOf(String shopId, String itemId) =>
      _carts[shopId]?[itemId]?.quantity ?? 0;

  /// Total units in a shop's cart (for the badge).
  int countFor(String shopId) =>
      linesFor(shopId).fold(0, (n, l) => n + l.quantity);

  double totalFor(String shopId) =>
      linesFor(shopId).fold(0.0, (s, l) => s + l.lineTotal);

  /// Adds [quantity] of [item], capped at its stock.
  void add(ShopItem item, int quantity) {
    final cart = _carts[item.shopId] ??= {};
    final existing = cart[item.id];
    final next = ((existing?.quantity ?? 0) + quantity).clamp(1, item.quantity);
    cart[item.id] = CartLine(
      itemId: item.id,
      shopId: item.shopId,
      name: item.name,
      price: item.price,
      imageUrl: item.imageUrl,
      maxQuantity: item.quantity,
      quantity: next,
    );
    _changed();
  }

  /// Sets a line's quantity; 0 removes it.
  void setQuantity(String shopId, String itemId, int quantity) {
    final cart = _carts[shopId];
    final line = cart?[itemId];
    if (cart == null || line == null) return;
    if (quantity <= 0) {
      cart.remove(itemId);
      if (cart.isEmpty) _carts.remove(shopId);
    } else {
      cart[itemId] = line.copyWith(quantity: quantity);
    }
    _changed();
  }

  void remove(String shopId, String itemId) => setQuantity(shopId, itemId, 0);

  void clear(String shopId) {
    if (_carts.remove(shopId) != null) _changed();
  }

  /// Refreshes prices/stock from fresh item data and drops items that are no
  /// longer sold. Returns the names of removed items.
  List<String> reconcile(String shopId, List<ShopItem> items) {
    final cart = _carts[shopId];
    if (cart == null) return const [];
    final byId = {for (final i in items) i.id: i};
    final removed = <String>[];
    var changed = false;
    for (final line in cart.values.toList()) {
      final item = byId[line.itemId];
      if (item == null || !item.isActive || item.quantity <= 0) {
        cart.remove(line.itemId);
        removed.add(line.name);
        changed = true;
        continue;
      }
      final qty = line.quantity.clamp(1, item.quantity);
      if (qty != line.quantity ||
          item.price != line.price ||
          item.quantity != line.maxQuantity) {
        cart[line.itemId] = line.copyWith(
            quantity: qty, price: item.price, maxQuantity: item.quantity);
        changed = true;
      }
    }
    if (cart.isEmpty) _carts.remove(shopId);
    if (changed) _changed();
    return removed;
  }
}
