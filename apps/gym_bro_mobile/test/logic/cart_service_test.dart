import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/shop_item.dart';
import 'package:gym_bro_mobile/pages/shop/cart_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'shop_carts_v1';

/// A shop item as GET /shop-items returns it (price is a Postgres numeric → string).
ShopItem _item(
  String id, {
  String shopId = 'shop-1',
  String name = 'Whey Protein 2kg',
  String price = '49.90',
  int quantity = 10,
  bool isActive = true,
  String? imageUrl,
}) =>
    ShopItem.fromJson({
      'id': id,
      'shop_id': shopId,
      'type': 'supplement',
      'name': name,
      'description': null,
      'price': price,
      'quantity': quantity,
      'is_active': isActive,
      'active_until': null,
      'image_url': imageUrl,
    });

Future<List<dynamic>> _persisted() async {
  await pumpEventQueue(); // _save() runs unawaited
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  return raw == null ? const [] : jsonDecode(raw) as List;
}

void main() {
  final cart = CartService.instance;
  var notifications = 0;
  void listener() => notifications++;

  setUpAll(() => cart.addListener(listener));

  setUp(() {
    notifications = 0;
  });

  tearDown(() {
    // The service is a singleton: empty every cart the tests touched.
    for (final shop in ['shop-1', 'shop-2']) {
      cart.clear(shop);
    }
  });

  // Must run first: ensureLoaded() only reads storage once per process.
  test('ensureLoaded restores carts saved by a previous run, tolerating string numbers', () async {
    SharedPreferences.setMockInitialValues({
      _key: jsonEncode([
        {
          'item_id': 'i-1',
          'shop_id': 'shop-1',
          'name': 'Whey Protein 2kg',
          'price': '49.90',
          'image_url': 'https://cdn.example.com/whey.png',
          'max_quantity': '10',
          'quantity': 2,
        },
        {'item_id': 'i-2', 'shop_id': 'shop-1', 'name': null, 'price': 5, 'max_quantity': null, 'quantity': null},
        {'item_id': 'i-9', 'shop_id': 'shop-2', 'name': 'Belt', 'price': 30.0, 'max_quantity': 1, 'quantity': 1},
      ]),
    });
    expect(cart.isLoaded, isFalse);

    await cart.ensureLoaded();
    await cart.ensureLoaded(); // idempotent

    expect(cart.isLoaded, isTrue);
    expect(notifications, 1);
    final lines = cart.linesFor('shop-1');
    expect(lines.map((l) => l.itemId), ['i-1', 'i-2']);
    expect(lines[0].price, 49.9);
    expect(lines[0].maxQuantity, 10);
    expect(lines[0].quantity, 2);
    expect(lines[0].imageUrl, 'https://cdn.example.com/whey.png');
    // Missing values fall back to defaults.
    expect(lines[1].name, 'Item');
    expect(lines[1].price, 5.0);
    expect(lines[1].maxQuantity, 99);
    expect(lines[1].quantity, 1);
    expect(cart.countFor('shop-2'), 1);
  });

  test('add creates a line from the item and persists it', () async {
    SharedPreferences.setMockInitialValues({});
    cart.add(_item('i-1', imageUrl: 'https://cdn.example.com/whey.png'), 2);

    expect(notifications, 1);
    final line = cart.linesFor('shop-1').single;
    expect(line.itemId, 'i-1');
    expect(line.shopId, 'shop-1');
    expect(line.name, 'Whey Protein 2kg');
    expect(line.price, 49.9);
    expect(line.maxQuantity, 10);
    expect(line.quantity, 2);
    expect(line.lineTotal, closeTo(99.8, 1e-9));
    expect(cart.quantityOf('shop-1', 'i-1'), 2);

    expect(await _persisted(), [
      {
        'item_id': 'i-1',
        'shop_id': 'shop-1',
        'name': 'Whey Protein 2kg',
        'price': 49.9,
        'image_url': 'https://cdn.example.com/whey.png',
        'max_quantity': 10,
        'quantity': 2,
      },
    ]);
  });

  test('adding the same item again sums quantities, capped at stock', () {
    cart.add(_item('i-1', quantity: 5), 3);
    cart.add(_item('i-1', quantity: 5), 4);
    expect(cart.quantityOf('shop-1', 'i-1'), 5);
    expect(cart.linesFor('shop-1'), hasLength(1));
  });

  test('add refreshes price and stock from the latest item data', () {
    cart.add(_item('i-1', price: '49.90', quantity: 10), 1);
    cart.add(_item('i-1', price: '44.90', quantity: 3), 1);
    final line = cart.linesFor('shop-1').single;
    expect(line.price, 44.9);
    expect(line.maxQuantity, 3);
    expect(line.quantity, 2);
  });

  test('carts are per shop; count and total per shop', () {
    cart.add(_item('i-1', price: '49.90'), 2);
    cart.add(_item('i-2', name: 'Creatine', price: '19.99'), 1);
    cart.add(_item('i-3', shopId: 'shop-2', name: 'Belt', price: '30'), 1);

    expect(cart.linesFor('shop-1').map((l) => l.itemId), ['i-1', 'i-2']);
    expect(cart.countFor('shop-1'), 3);
    expect(cart.totalFor('shop-1'), closeTo(119.79, 1e-9));
    expect(cart.countFor('shop-2'), 1);
    expect(cart.totalFor('shop-2'), 30);
    expect(cart.countFor('nope'), 0);
    expect(cart.totalFor('nope'), 0);
    expect(cart.linesFor('nope'), isEmpty);
    expect(() => cart.linesFor('shop-1').clear(), throwsUnsupportedError, reason: 'read-only view');
  });

  test('setQuantity changes a line; 0 or less removes it and drops an empty cart', () async {
    cart.add(_item('i-1'), 1);
    cart.add(_item('i-2'), 1);
    notifications = 0;

    cart.setQuantity('shop-1', 'i-1', 4);
    expect(cart.quantityOf('shop-1', 'i-1'), 4);

    cart.setQuantity('shop-1', 'i-2', 0);
    expect(cart.linesFor('shop-1').map((l) => l.itemId), ['i-1']);

    cart.remove('shop-1', 'i-1');
    expect(cart.linesFor('shop-1'), isEmpty);
    expect(notifications, 3);
    expect(await _persisted(), isEmpty);

    // Unknown lines are ignored without notifying.
    cart.setQuantity('shop-1', 'ghost', 2);
    cart.setQuantity('ghost-shop', 'i-1', 2);
    expect(notifications, 3);
  });

  test('clear empties one shop only, and only notifies when something was there', () async {
    cart.add(_item('i-1'), 1);
    cart.add(_item('i-3', shopId: 'shop-2'), 1);
    notifications = 0;

    cart.clear('shop-1');
    expect(cart.linesFor('shop-1'), isEmpty);
    expect(cart.countFor('shop-2'), 1);
    expect(notifications, 1);
    expect((await _persisted()).map((e) => e['item_id']), ['i-3']);

    cart.clear('shop-1');
    expect(notifications, 1);
  });

  group('reconcile', () {
    test('updates price/stock, caps quantity, drops items no longer sold and returns their names', () async {
      cart.add(_item('i-1', name: 'Whey', price: '49.90', quantity: 10), 5);
      cart.add(_item('i-2', name: 'Creatine', quantity: 10), 1);
      cart.add(_item('i-3', name: 'Shaker', quantity: 10), 1);
      cart.add(_item('i-4', name: 'Gloves', quantity: 10), 1);
      cart.add(_item('i-5', name: 'Bands', quantity: 10), 2);
      notifications = 0;

      final removed = cart.reconcile('shop-1', [
        _item('i-1', name: 'Whey', price: '39.90', quantity: 3), // cheaper, less stock
        _item('i-2', name: 'Creatine', quantity: 10, isActive: false), // unlisted
        _item('i-3', name: 'Shaker', quantity: 0), // sold out
        // i-4 deleted
        _item('i-5', name: 'Bands', quantity: 10), // unchanged
      ]);

      expect(removed, ['Creatine', 'Shaker', 'Gloves']);
      final lines = cart.linesFor('shop-1');
      expect(lines.map((l) => l.itemId), ['i-1', 'i-5']);
      expect(lines[0].price, 39.9);
      expect(lines[0].maxQuantity, 3);
      expect(lines[0].quantity, 3);
      expect(lines[1].quantity, 2);
      expect(notifications, 1);
      final saved = await _persisted();
      expect(saved.firstWhere((e) => e['item_id'] == 'i-1')['price'], 39.9);
    });

    test('no changes → no notification; unknown shop → nothing removed', () {
      cart.add(_item('i-1'), 2);
      notifications = 0;

      expect(cart.reconcile('shop-1', [_item('i-1')]), isEmpty);
      expect(notifications, 0);
      expect(cart.reconcile('shop-9', [_item('i-1')]), isEmpty);
    });

    test('removing every item drops the shop cart', () {
      cart.add(_item('i-1', name: 'Whey'), 1);

      expect(cart.reconcile('shop-1', const []), ['Whey']);
      expect(cart.linesFor('shop-1'), isEmpty);
      expect(cart.countFor('shop-1'), 0);
    });
  });

  test('CartLine JSON round trip', () {
    const line = CartLine(
      itemId: 'i-1',
      shopId: 'shop-1',
      name: 'Whey',
      price: 49.9,
      imageUrl: null,
      maxQuantity: 10,
      quantity: 3,
    );
    final back = CartLine.fromJson(jsonDecode(jsonEncode(line.toJson())) as Map<String, dynamic>);
    expect(back.toJson(), line.toJson());
    expect(line.copyWith(quantity: 5).quantity, 5);
    expect(line.copyWith(price: 1).price, 1);
    expect(line.copyWith(maxQuantity: 2).maxQuantity, 2);
    expect(line.copyWith().toJson(), line.toJson());
  });
}
