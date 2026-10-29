import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/payment.dart';
import 'package:gym_bro_mobile/services/api_service.dart';
import 'package:http/http.dart' as http;

import '../helpers/fake_backend.dart';

const _token = 'tok-123';

void _expectHeaders(http.Request req) {
  expect(req.headers['Authorization'], 'Bearer $_token');
  expect(req.headers['Content-Type'], startsWith('application/json'));
}

Matcher _throwsMessage(String message) => throwsA(predicate((e) => e is Exception && '$e'.contains(message)));

// GET /payments row (PAYMENT_COLS in functions/payments/index.ts).
Map<String, dynamic> _paymentJson({String status = 'succeeded'}) => {
      'id': 'p1',
      'user_id': 'u1',
      'kind': 'membership',
      'membership_invoice_id': null,
      'order_id': null,
      'membership_type_id': 'mt1',
      'membership_id': 'm1',
      'stripe_checkout_session_id': 'cs_test_x',
      'stripe_payment_intent_id': 'pi_test_x',
      'stripe_subscription_id': null,
      'amount': '119.97',
      'currency': 'eur',
      'status': status,
      'created_at': '2026-10-20T10:00:00.000Z',
      'updated_at': '2026-10-20T10:01:30.000Z',
    };

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('getPaymentsConfig', () {
    test('GETs /payments/config and parses it', () async {
      backend.on('GET /payments/config', ok({'enabled': true, 'currency': 'eur'}));

      final c = await api.getPaymentsConfig(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/payments/config');
      expect(req.url.hasQuery, isFalse);
      _expectHeaders(req);
      expect(c.enabled, isTrue);
      expect(c.currency, 'eur');
    });

    test('local stack without Stripe: disabled, usd', () async {
      backend.on('GET /payments/config', ok({'enabled': false, 'currency': 'usd'}));
      final c = await api.getPaymentsConfig(_token);
      expect(c.enabled, isFalse);
      expect(c.currency, 'usd');
    });

    test('a non-JSON error body still throws a readable error', () async {
      backend.on('GET /payments/config', ok('upstream timeout', 504));
      await expectLater(api.getPaymentsConfig(_token), _throwsMessage('Request failed (504)'));
    });
  });

  group('checkout', () {
    const session = {'url': 'https://checkout.stripe.com/c/pay/cs_test_abc', 'payment_id': 'p9'};

    test('createCheckout POSTs the body as-is and parses the session', () async {
      backend.on('POST /payments/checkout', ok(session, 201));

      final s = await api.createCheckout(_token, {'kind': 'order', 'order_id': 'o1', 'extra': null});

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/payments/checkout');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'kind': 'order', 'order_id': 'o1', 'extra': null}));
      expect(s.url, 'https://checkout.stripe.com/c/pay/cs_test_abc');
      expect(s.paymentId, 'p9');
    });

    test('checkoutInvoice sends {kind: invoice, invoice_id}', () async {
      backend.on('POST /payments/checkout', ok(session, 201));
      final s = await api.checkoutInvoice(_token, 'inv1');
      expect(bodyOf(backend.only), equals({'kind': 'invoice', 'invoice_id': 'inv1'}));
      expect(s.paymentId, 'p9');
    });

    test('checkoutOrder sends {kind: order, order_id}', () async {
      backend.on('POST /payments/checkout', ok(session, 201));
      await api.checkoutOrder(_token, 'o1');
      final req = backend.only;
      expect(pathOf(req), '/payments/checkout');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'kind': 'order', 'order_id': 'o1'}));
    });

    test('checkoutMembership: one month by default, auto_renew false', () async {
      backend.on('POST /payments/checkout', ok(session, 201));
      await api.checkoutMembership(_token, membershipTypeId: 'mt1');
      expect(
        bodyOf(backend.only),
        equals({'kind': 'membership', 'membership_type_id': 'mt1', 'months': 1, 'auto_renew': false}),
      );
    });

    test('checkoutMembership: several months', () async {
      backend.on('POST /payments/checkout', ok(session, 201));
      await api.checkoutMembership(_token, membershipTypeId: 'mt1', months: 6);
      expect(
        bodyOf(backend.only),
        equals({'kind': 'membership', 'membership_type_id': 'mt1', 'months': 6, 'auto_renew': false}),
      );
    });

    test('checkoutMembership: auto-renew omits months', () async {
      backend.on('POST /payments/checkout', ok(session, 201));
      await api.checkoutMembership(_token, membershipTypeId: 'mt1', months: 12, autoRenew: true);
      expect(bodyOf(backend.only), equals({'kind': 'membership', 'membership_type_id': 'mt1', 'auto_renew': true}));
    });

    test('503 not_configured surfaces the message', () async {
      backend.on('POST /payments/checkout', err(503, 'Payments are not configured', code: 'not_configured'));
      await expectLater(api.checkoutOrder(_token, 'o1'), _throwsMessage('Payments are not configured'));
    });

    test('409 surfaces the message', () async {
      backend.on('POST /payments/checkout', err(409, 'You already have an auto-renewing membership at this gym'));
      await expectLater(
        api.checkoutMembership(_token, membershipTypeId: 'mt1', autoRenew: true),
        _throwsMessage('You already have an auto-renewing membership at this gym'),
      );
    });
  });

  group('getMyPayments', () {
    test('GETs /payments and parses every field (amount arrives as a string)', () async {
      backend.on(
        'GET /payments',
        ok([
          _paymentJson(),
          {
            ..._paymentJson(status: 'refunded'),
            'id': 'p2',
            'kind': 'order',
            'order_id': 'o1',
            'membership_type_id': null,
            'membership_id': null,
            'amount': '19.99',
            'currency': 'usd',
            'updated_at': null,
          },
        ]),
      );

      final list = await api.getMyPayments(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/payments');
      expect(req.url.hasQuery, isFalse);
      _expectHeaders(req);

      expect(list, hasLength(2));
      final p = list[0];
      expect(p.id, 'p1');
      expect(p.userId, 'u1');
      expect(p.kind, 'membership');
      expect(p.membershipInvoiceId, isNull);
      expect(p.orderId, isNull);
      expect(p.membershipTypeId, 'mt1');
      expect(p.membershipId, 'm1');
      expect(p.amount, 119.97);
      expect(p.currency, 'eur');
      expect(p.status, PaymentStatus.succeeded);
      expect(p.isSucceeded, isTrue);
      expect(p.createdAt, DateTime.utc(2026, 10, 20, 10));
      expect(p.updatedAt, DateTime.utc(2026, 10, 20, 10, 1, 30));

      final q = list[1];
      expect(q.kind, 'order');
      expect(q.orderId, 'o1');
      expect(q.membershipId, isNull);
      expect(q.amount, 19.99);
      expect(q.status, PaymentStatus.refunded);
      expect(q.updatedAt, isNull);
    });

    test('503 not_configured surfaces the message', () async {
      backend.on('GET /payments', err(503, 'Payments are not configured', code: 'not_configured'));
      await expectLater(api.getMyPayments(_token), _throwsMessage('Payments are not configured'));
    });
  });

  group('getPayment', () {
    test('GETs /payments/:id and parses a pending invoice payment', () async {
      backend.on(
        'GET /payments/p3',
        ok({
          ..._paymentJson(status: 'pending'),
          'id': 'p3',
          'kind': 'invoice',
          'membership_invoice_id': 'inv1',
          'membership_type_id': null,
          'amount': '45.00',
        }),
      );

      final p = await api.getPayment(_token, 'p3');

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/payments/p3');
      _expectHeaders(req);
      expect(p.id, 'p3');
      expect(p.kind, 'invoice');
      expect(p.membershipInvoiceId, 'inv1');
      expect(p.amount, 45.0);
      expect(p.isPending, isTrue);
    });

    test('404 surfaces the message', () async {
      backend.on('GET /payments/nope', err(404, 'Payment not found'));
      await expectLater(api.getPayment(_token, 'nope'), _throwsMessage('Payment not found'));
    });
  });

  group('cancelPayment', () {
    test('POSTs /payments/:id/cancel with no body and parses the cancelled payment', () async {
      backend.on('POST /payments/p1/cancel', ok(_paymentJson(status: 'cancelled')));

      final p = await api.cancelPayment(_token, 'p1');

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/payments/p1/cancel');
      _expectHeaders(req);
      expect(req.body, isEmpty);
      expect(p.status, PaymentStatus.cancelled);
    });

    test('409 (already succeeded) surfaces the message', () async {
      backend.on('POST /payments/p1/cancel', err(409, 'This payment is already succeeded'));
      await expectLater(api.cancelPayment(_token, 'p1'), _throwsMessage('This payment is already succeeded'));
    });
  });

  group('getPurchasableGyms', () {
    test('GETs /payments/gyms and parses gyms with their types', () async {
      backend.on(
        'GET /payments/gyms',
        ok([
          {
            'id': 'g1',
            'name': 'Iron Temple',
            'location': '12 Main St',
            'logo': 'https://picsum.photos/seed/gym/800/400',
            'types': [
              {'id': 'mt1', 'name': 'Basic', 'monthly_cost': '39.99'},
              {'id': 'mt2', 'name': 'Premium', 'monthly_cost': '59.00'},
            ],
          },
          {'id': 'g2', 'name': 'No Types Gym', 'location': null, 'logo': null, 'types': []},
        ]),
      );

      final gyms = await api.getPurchasableGyms(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/payments/gyms');
      _expectHeaders(req);

      expect(gyms, hasLength(2));
      final g = gyms[0];
      expect(g.id, 'g1');
      expect(g.name, 'Iron Temple');
      expect(g.location, '12 Main St');
      expect(g.logo, 'https://picsum.photos/seed/gym/800/400');
      expect(g.types.map((t) => t.id), ['mt1', 'mt2']);
      expect(g.types[0].name, 'Basic');
      expect(g.types[0].monthlyCost, 39.99);
      expect(g.types[1].monthlyCost, 59.0);
      expect(gyms[1].location, '');
      expect(gyms[1].logo, isNull);
      expect(gyms[1].types, isEmpty);
    });

    test('503 not_configured surfaces the message', () async {
      backend.on('GET /payments/gyms', err(503, 'Payments are not configured', code: 'not_configured'));
      await expectLater(api.getPurchasableGyms(_token), _throwsMessage('Payments are not configured'));
    });
  });

  group('cancelMembershipAutoRenew', () {
    test('POSTs /payments/memberships/:id/cancel-auto-renew and parses the membership row', () async {
      // `returningAll()` on membership; DATE columns serialise as midnight UTC.
      backend.on(
        'POST /payments/memberships/m1/cancel-auto-renew',
        ok({
          'id': 'm1',
          'user_id': 'u1',
          'current_membership_type_id': 'mt1',
          'from_date': '2026-06-10T00:00:00.000Z',
          'to_date': '2026-11-30T00:00:00.000Z',
          'last_updated_date': '2026-10-28T09:19:27.208Z',
          'is_active': true,
          'auto_renew': false,
          'stripe_subscription_id': 'sub_test_x',
        }),
      );

      final m = await api.cancelMembershipAutoRenew(_token, 'm1');

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/payments/memberships/m1/cancel-auto-renew');
      _expectHeaders(req);
      expect(req.body, isEmpty);
      expect(m.id, 'm1');
      expect(m.userId, 'u1');
      expect(m.currentMembershipTypeId, 'mt1');
      expect(m.fromDate, DateTime.utc(2026, 6, 10));
      expect(m.toDate, DateTime.utc(2026, 11, 30));
      expect(m.lastUpdatedDate, DateTime.utc(2026, 10, 28, 9, 19, 27, 208));
      expect(m.isActive, isTrue);
      expect(m.autoRenew, isFalse);
    });

    test('502 stripe_error surfaces the message', () async {
      backend.on(
        'POST /payments/memberships/m1/cancel-auto-renew',
        err(502, 'Payment provider error: boom', code: 'stripe_error'),
      );
      await expectLater(api.cancelMembershipAutoRenew(_token, 'm1'), _throwsMessage('Payment provider error: boom'));
    });
  });
}
