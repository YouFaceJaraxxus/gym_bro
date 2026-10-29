import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/order.dart';
import 'package:gym_bro_mobile/services/api_service.dart';
import 'package:http/http.dart' as http;

import '../helpers/fake_backend.dart';

const _token = 'tok-123';

void _expectHeaders(http.Request req, {bool json = true}) {
  expect(req.headers['Authorization'], 'Bearer $_token');
  if (json) expect(req.headers['Content-Type'], startsWith('application/json'));
}

// Shapes captured from the local stack (GET /orders, GET /orders/shops).
Map<String, dynamic> _orderJson({String status = 'fulfilled', String paymentMethod = 'pay_at_pickup'}) => {
      'id': 'o1',
      'shop_id': 's1',
      'shop_name': 'Peak Performance Supply Co.',
      'shop_logo': 'https://picsum.photos/seed/shop-logo/800/400',
      'user_id': 'u1',
      'buyer_name': "Liam O'Connor",
      'buyer_email': 'liam.oconnor@example.com',
      'status': status,
      'payment_method': paymentMethod,
      'note': null,
      'total': '64.98',
      'created_at': '2026-10-01T17:12:00.000Z',
      'paid_at': '2026-10-03T15:42:00.000Z',
      'fulfilled_at': '2026-10-03T15:42:00.000Z',
      'cancelled_at': null,
      'payment_status': null,
      'items': [
        {
          'id': 'ii1',
          'shop_item_id': 'si1',
          'name': 'Creatine Monohydrate - 300g',
          'type': 'supplement',
          'image_url': 'https://picsum.photos/seed/creatine/800/800',
          'quantity': 1,
          'unit_price': '19.99',
          'line_total': '19.99',
        },
        {
          'id': 'ii2',
          'shop_item_id': 'si2',
          'name': 'Whey Protein Isolate - 2lb',
          'type': 'supplement',
          'image_url': null,
          'quantity': 2,
          'unit_price': '22.495',
          'line_total': '44.99',
        },
      ],
      'item_count': 3,
    };

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('getStorefrontShops', () {
    test('GETs /orders/shops and parses every field', () async {
      backend.on(
        'GET /orders/shops',
        ok([
          {
            'id': 's1',
            'name': 'Peak Performance Supply Co.',
            'location': '17 Court Street, Brooklyn, NY 11201',
            'logo': 'https://picsum.photos/seed/shop-logo/800/400',
            'working_hours_from': '09:00:00',
            'working_hours_to': '19:00:00',
            'active_item_count': 18,
          },
          // Counts can come back as strings (bigint); nulls fall back.
          {
            'id': 's2',
            'name': 'Phoenix Shop',
            'location': null,
            'logo': null,
            'working_hours_from': null,
            'working_hours_to': null,
            'active_item_count': '1',
          },
        ]),
      );

      final shops = await api.getStorefrontShops(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/orders/shops');
      expect(req.url.hasQuery, isFalse);
      _expectHeaders(req);

      expect(shops, hasLength(2));
      final a = shops[0];
      expect(a.id, 's1');
      expect(a.name, 'Peak Performance Supply Co.');
      expect(a.location, '17 Court Street, Brooklyn, NY 11201');
      expect(a.logo, 'https://picsum.photos/seed/shop-logo/800/400');
      expect(a.workingHoursFrom, '09:00:00');
      expect(a.workingHoursTo, '19:00:00');
      expect(a.activeItemCount, 18);
      final b = shops[1];
      expect(b.location, '');
      expect(b.logo, isNull);
      expect(b.workingHoursFrom, isNull);
      expect(b.activeItemCount, 1);
    });

    test('surfaces the API error message', () async {
      backend.on('GET /orders/shops', err(500, 'Database unavailable'));
      await expectLater(
        api.getStorefrontShops(_token),
        throwsA(predicate((e) => e.toString().contains('Database unavailable'))),
      );
    });
  });

  group('createOrder', () {
    test('POSTs the items as a list, the payment method and a trimmed note', () async {
      backend.on('POST /orders', ok(_orderJson(status: 'pending', paymentMethod: 'card'), 201));

      final order = await api.createOrder(
        _token,
        shopId: 's1',
        items: {'si1': 1, 'si2': 2},
        paymentMethod: OrderPaymentMethod.card,
        note: '  leave at the desk  ',
      );

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/orders');
      _expectHeaders(req);
      expect(
        bodyOf(req),
        equals({
          'shop_id': 's1',
          'items': [
            {'shop_item_id': 'si1', 'quantity': 1},
            {'shop_item_id': 'si2', 'quantity': 2},
          ],
          'payment_method': 'card',
          'note': 'leave at the desk',
        }),
      );
      expect(order.status, OrderStatus.pending);
      expect(order.paymentMethod, OrderPaymentMethod.card);
      expect(order.awaitingCardPayment, isTrue);
    });

    test('pay at pickup; omits a null or blank note', () async {
      backend.on('POST /orders', ok(_orderJson(status: 'pending'), 201));

      await api.createOrder(_token, shopId: 's1', items: {'si1': 3}, paymentMethod: OrderPaymentMethod.payAtPickup);
      await api.createOrder(_token,
          shopId: 's1', items: {'si1': 3}, paymentMethod: OrderPaymentMethod.payAtPickup, note: '   ');

      for (final req in backend.requests) {
        expect(
          bodyOf(req),
          equals({
            'shop_id': 's1',
            'items': [
              {'shop_item_id': 'si1', 'quantity': 3},
            ],
            'payment_method': 'pay_at_pickup',
          }),
        );
      }
    });

    test('409 (out of stock) surfaces the server message', () async {
      backend.on('POST /orders', err(409, 'Only 2 left of Creatine Monohydrate - 300g'));
      await expectLater(
        api.createOrder(_token, shopId: 's1', items: {'si1': 5}, paymentMethod: OrderPaymentMethod.card),
        throwsA(predicate((e) => e.toString().contains('Only 2 left of Creatine Monohydrate - 300g'))),
      );
    });

    test('a non-JSON error body still throws a readable error', () async {
      backend.on('POST /orders', ok('<html>Bad gateway</html>', 502));
      await expectLater(
        api.createOrder(_token, shopId: 's1', items: {'si1': 1}, paymentMethod: OrderPaymentMethod.card),
        throwsA(predicate((e) => e is Exception && e.toString().contains('502'))),
      );
    });
  });

  group('getMyOrders', () {
    test('GETs /orders without a query and parses orders, items and numeric strings', () async {
      backend.on('GET /orders', ok([_orderJson()]));

      final orders = await api.getMyOrders(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/orders');
      expect(req.url.hasQuery, isFalse);
      _expectHeaders(req);

      final o = orders.single;
      expect(o.id, 'o1');
      expect(o.shopId, 's1');
      expect(o.shopName, 'Peak Performance Supply Co.');
      expect(o.shopLogo, 'https://picsum.photos/seed/shop-logo/800/400');
      expect(o.userId, 'u1');
      expect(o.buyerName, "Liam O'Connor");
      expect(o.buyerEmail, 'liam.oconnor@example.com');
      expect(o.status, OrderStatus.fulfilled);
      expect(o.paymentMethod, OrderPaymentMethod.payAtPickup);
      expect(o.note, isNull);
      expect(o.total, 64.98);
      expect(o.createdAt, DateTime.utc(2026, 10, 1, 17, 12));
      expect(o.paidAt, DateTime.utc(2026, 10, 3, 15, 42));
      expect(o.fulfilledAt, DateTime.utc(2026, 10, 3, 15, 42));
      expect(o.cancelledAt, isNull);
      expect(o.paymentStatus, isNull);
      expect(o.refundStatus, isNull);
      expect(o.itemCount, 3);
      expect(o.awaitingCardPayment, isFalse);
      expect(o.items, hasLength(2));
      final i = o.items[0];
      expect(i.id, 'ii1');
      expect(i.shopItemId, 'si1');
      expect(i.name, 'Creatine Monohydrate - 300g');
      expect(i.type, 'supplement');
      expect(i.imageUrl, 'https://picsum.photos/seed/creatine/800/800');
      expect(i.quantity, 1);
      expect(i.unitPrice, 19.99);
      expect(i.lineTotal, 19.99);
      expect(o.items[1].imageUrl, isNull);
      expect(o.items[1].quantity, 2);
      expect(o.items[1].lineTotal, 44.99);
    });

    test('passes the status filter', () async {
      backend.on('GET /orders', ok([]));
      expect(await api.getMyOrders(_token, status: OrderStatus.cancelled), isEmpty);
      expect(backend.only.url.queryParameters, {'status': 'cancelled'});
    });
  });

  group('getShopOrders', () {
    test('GETs /orders?shop_id= (and status when given)', () async {
      backend.on('GET /orders', ok([_orderJson(status: 'paid')]));

      final orders = await api.getShopOrders(_token, 's1');
      await api.getShopOrders(_token, 's1', status: OrderStatus.paid);

      expect(orders.single.status, OrderStatus.paid);
      expect(backend.requests[0].url.queryParameters, {'shop_id': 's1'});
      expect(backend.requests[1].url.queryParameters, {'shop_id': 's1', 'status': 'paid'});
      for (final r in backend.requests) {
        expect(r.method, 'GET');
        _expectHeaders(r);
      }
    });

    test('403 surfaces the message', () async {
      backend.on('GET /orders', err(403, 'Forbidden'));
      await expectLater(api.getShopOrders(_token, 's1'), throwsA(predicate((e) => '$e'.contains('Forbidden'))));
    });
  });

  group('getOrder', () {
    test('GETs /orders/:id and parses it; item_count falls back to the quantity sum', () async {
      final json = _orderJson()..remove('item_count');
      backend.on('GET /orders/o1', ok(json));

      final o = await api.getOrder(_token, 'o1');

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/orders/o1');
      _expectHeaders(req);
      expect(o.id, 'o1');
      expect(o.itemCount, 3);
      expect(o.total, 64.98);
    });

    test('404 surfaces the message', () async {
      backend.on('GET /orders/nope', err(404, 'Order not found'));
      await expectLater(api.getOrder(_token, 'nope'), throwsA(predicate((e) => '$e'.contains('Order not found'))));
    });
  });

  group('updateOrderStatus', () {
    test('PUTs {status} to /orders/:id/status and parses the refund status', () async {
      backend.on(
        'PUT /orders/o1/status',
        ok({
          ..._orderJson(status: 'cancelled', paymentMethod: 'card'),
          'cancelled_at': '2026-10-04T09:00:00.000Z',
          'payment_status': 'refunded',
          'refund_status': 'refunded',
        }),
      );

      final o = await api.updateOrderStatus(_token, 'o1', OrderStatus.cancelled);

      final req = backend.only;
      expect(req.method, 'PUT');
      expect(pathOf(req), '/orders/o1/status');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'status': 'cancelled'}));
      expect(o.status, OrderStatus.cancelled);
      expect(o.cancelledAt, DateTime.utc(2026, 10, 4, 9));
      expect(o.refundStatus, 'refunded');
      expect(o.paymentStatus, 'refunded');
    });

    test('409 (already fulfilled) surfaces the message', () async {
      backend.on('PUT /orders/o1/status', err(409, 'This order was fulfilled already'));
      await expectLater(
        api.updateOrderStatus(_token, 'o1', OrderStatus.fulfilled),
        throwsA(predicate((e) => '$e'.contains('This order was fulfilled already'))),
      );
    });
  });
}
