import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/membership.dart';
import 'package:gym_bro_mobile/models/shop_item.dart';

import '../helpers/fake_backend.dart';
import 'api_test_utils.dart';

// Bodies captured from the local stack (GET /shop-items, /gym-membership-types,
// /memberships, /membership-invoices), trimmed. price, monthly_cost and amount
// are Postgres numerics and arrive as strings.
const gymId = 'ff453a60-28ca-4cdd-a919-c6ecd344ab65';
const shopId = 'fbec11a8-6dfd-4458-a6ad-78e666016a74';
const liamId = '8d0b05de-7c18-441b-9536-aaa042eaeaaa';
const itemId = '9e173a35-07f5-44b2-9739-180655b6d4d7';
const premiumId = '6f3d4e9b-ae3d-4d9d-9a7e-e1684c28b330';
const membershipId = '54febc91-3fa5-494f-9d37-1c99d7ca953f';
const invoiceId = '729c2bea-1003-467f-ab35-807aec479f22';

final bottleJson = {
  'id': itemId,
  'shop_id': shopId,
  'type': 'equipment',
  'name': 'Insulated Steel Water Bottle - 32oz',
  'description': 'A double-wall insulated stainless steel bottle that keeps drinks cold for up to 24 hours.',
  'price': '26.99',
  'quantity': 75,
  'is_active': true,
  'active_until': null,
  'image_url': 'https://picsum.photos/seed/product-Insulated%20Steel%20Water%20Bottle%20-%2032oz/800/800',
};

final giftCardJson = {
  'id': 'gc-1',
  'shop_id': shopId,
  'type': 'gift_card',
  'name': r'$50 Gift Card',
  'description': null,
  'price': '50.00',
  'quantity': 0,
  'is_active': false,
  'active_until': '2026-12-31T23:59:59.000Z',
  'image_url': null,
};

final premiumJson = {
  'id': premiumId,
  'name': 'Premium',
  'monthly_cost': '59.99',
  'gym_id': gymId,
  'is_active': true,
};

final membershipJson = {
  'id': membershipId,
  'user_id': liamId,
  'current_membership_type_id': premiumId,
  'from_date': '2026-06-10T00:00:00.000Z',
  'to_date': '2026-11-30T00:00:00.000Z',
  'last_updated_date': '2026-10-13T09:19:27.208Z',
  'is_active': true,
  'auto_renew': false,
  'stripe_subscription_id': null,
};

final invoiceJson = {
  'id': invoiceId,
  'membership_id': '9e185427-a2a8-4fb4-9190-bb0f04cab2d2',
  'membership_type_id': '023080fb-2104-42ed-9ca0-2f4f2445cc3d',
  'issued_at': '2026-10-13T09:15:27.208Z',
  'amount': '29.99',
  'status': 'paid',
  'paid_at': '2026-10-28T18:40:40.051Z',
  'user_id': 'c5e4e2c2-6d13-4b26-8dd3-bd5067621930',
  'member_name': 'Daniel',
  'member_last_name': 'Kim',
  'gym_id': gymId,
  'gym_name': 'Ironclad Fitness',
  'membership_type_name': 'Basic',
};

void main() {
  final ctx = useFakeBackend();
  FakeBackend backend() => ctx.backend();

  group('shop items', () {
    test('getShopItems parses every field (string price, nullable dates)', () async {
      backend().on('GET /shop-items', ok([bottleJson, giftCardJson]));
      final items = await ctx.api().getShopItems(token);
      expectGet(backend().only, '/shop-items');

      final b = items[0];
      expect(b.id, itemId);
      expect(b.shopId, shopId);
      expect(b.type, ShopItemType.equipment);
      expect(b.name, 'Insulated Steel Water Bottle - 32oz');
      expect(b.description, startsWith('A double-wall'));
      expect(b.price, 26.99);
      expect(b.quantity, 75);
      expect(b.isActive, isTrue);
      expect(b.activeUntil, isNull);
      expect(b.imageUrl, contains('picsum.photos'));

      final gc = items[1];
      expect(gc.type, ShopItemType.giftCard);
      expect(gc.price, 50.0);
      expect(gc.quantity, 0);
      expect(gc.isActive, isFalse);
      expect(gc.activeUntil, DateTime.utc(2026, 12, 31, 23, 59, 59));
      expect(gc.description, isNull);
      expect(gc.imageUrl, isNull);
    });

    test('getShopItems sends shop_id and active_only only when set', () async {
      backend().on('GET /shop-items', ok([]));
      await ctx.api().getShopItems(token, shopId: shopId, activeOnly: true);
      expectGet(backend().requests.last, '/shop-items', {'shop_id': shopId, 'active_only': 'true'});
      await ctx.api().getShopItems(token, shopId: shopId);
      expectGet(backend().requests.last, '/shop-items', {'shop_id': shopId});
    });

    final itemBody = {
      'shop_id': shopId,
      'type': 'supplement',
      'name': 'Creatine Monohydrate 500g',
      'description': null,
      'price': 24.5,
      'quantity': 40,
      'is_active': true,
      'active_until': null,
      'image_url': null,
    };

    test('createShopItem POSTs the body (nulls included)', () async {
      backend().on('POST /shop-items', ok({
        ...bottleJson,
        'id': 'si-new',
        'type': 'supplement',
        'name': 'Creatine Monohydrate 500g',
        'price': '24.50',
        'quantity': 40,
        'image_url': null,
      }, 201));
      final item = await ctx.api().createShopItem(token, itemBody);
      expectJson(backend().only, 'POST', '/shop-items', itemBody);
      expect(item.id, 'si-new');
      expect(item.type, ShopItemType.supplement);
      expect(item.price, 24.5);
    });

    test('updateShopItem PUTs /shop-items/:id', () async {
      final body = Map.of(itemBody)..remove('shop_id');
      backend().on('PUT /shop-items/$itemId', ok({...bottleJson, 'price': '24.50'}));
      final item = await ctx.api().updateShopItem(token, itemId, body);
      expectJson(backend().only, 'PUT', '/shop-items/$itemId', body);
      expect(item.price, 24.5);
    });

    test('deleteShopItem DELETEs /shop-items/:id', () async {
      backend().on('DELETE /shop-items/$itemId', ok('', 204));
      await ctx.api().deleteShopItem(token, itemId);
      expectDelete(backend().only, '/shop-items/$itemId');
    });
  });

  group('gym membership types', () {
    test('getGymMembershipTypes parses string monthly_cost; filters', () async {
      backend().on('GET /gym-membership-types', ok([
        premiumJson,
        {'id': 'old', 'name': 'Legacy', 'monthly_cost': 10, 'gym_id': gymId, 'is_active': false},
      ]));
      final types = await ctx.api().getGymMembershipTypes(token);
      expectGet(backend().requests.last, '/gym-membership-types');
      expect(types[0].id, premiumId);
      expect(types[0].name, 'Premium');
      expect(types[0].monthlyCost, 59.99);
      expect(types[0].gymId, gymId);
      expect(types[0].isActive, isTrue);
      expect(types[1].monthlyCost, 10.0);
      expect(types[1].isActive, isFalse);

      await ctx.api().getGymMembershipTypes(token, gymId: gymId, isActive: true);
      expectGet(backend().requests.last, '/gym-membership-types', {'gym_id': gymId, 'is_active': 'true'});
      await ctx.api().getGymMembershipTypes(token, isActive: false);
      expectGet(backend().requests.last, '/gym-membership-types', {'is_active': 'false'});
    });

    test('createGymMembershipType POSTs the body', () async {
      final body = {'name': 'Student', 'monthly_cost': 19.99, 'is_active': true, 'gym_id': gymId};
      backend().on('POST /gym-membership-types', ok({...premiumJson, 'id': 'mt-new', 'name': 'Student', 'monthly_cost': '19.99'}, 201));
      final t = await ctx.api().createGymMembershipType(token, body);
      expectJson(backend().only, 'POST', '/gym-membership-types', body);
      expect(t.monthlyCost, 19.99);
      expect(t.name, 'Student');
    });

    test('updateGymMembershipType PUTs /gym-membership-types/:id', () async {
      final body = {'name': 'Premium', 'monthly_cost': 64.99, 'is_active': true};
      backend().on('PUT /gym-membership-types/$premiumId', ok({...premiumJson, 'monthly_cost': '64.99'}));
      final t = await ctx.api().updateGymMembershipType(token, premiumId, body);
      expectJson(backend().only, 'PUT', '/gym-membership-types/$premiumId', body);
      expect(t.monthlyCost, 64.99);
    });

    test('deleteGymMembershipType DELETEs /gym-membership-types/:id', () async {
      backend().on('DELETE /gym-membership-types/$premiumId', ok('', 204));
      await ctx.api().deleteGymMembershipType(token, premiumId);
      expectDelete(backend().only, '/gym-membership-types/$premiumId');
    });
  });

  group('memberships', () {
    test('getMemberships parses dates and flags; filters', () async {
      backend().on('GET /memberships', ok([membershipJson, {...membershipJson, 'id': 'm-2', 'is_active': false, 'auto_renew': true}]));
      final list = await ctx.api().getMemberships(token);
      expectGet(backend().requests.last, '/memberships');
      final m = list[0];
      expect(m.id, membershipId);
      expect(m.userId, liamId);
      expect(m.currentMembershipTypeId, premiumId);
      expect(m.fromDate, DateTime.utc(2026, 6, 10));
      expect(m.toDate, DateTime.utc(2026, 11, 30));
      expect(m.lastUpdatedDate, DateTime.utc(2026, 10, 13, 9, 19, 27, 208));
      expect(m.isActive, isTrue);
      expect(m.autoRenew, isFalse);
      expect(m.membershipType, isNull);
      expect(list[1].isActive, isFalse);
      expect(list[1].autoRenew, isTrue);

      await ctx.api().getMemberships(token, userId: liamId, gymId: gymId, isActive: true);
      expectGet(backend().requests.last, '/memberships', {'user_id': liamId, 'gym_id': gymId, 'is_active': 'true'});
    });

    test('createMembership POSTs the body built by the member screen', () async {
      final body = {
        'user_id': liamId,
        'current_membership_type_id': premiumId,
        'from_date': '2026-10-28',
        'to_date': '2027-01-28',
        'is_active': true,
      };
      backend().on('POST /memberships', ok({
        ...membershipJson,
        'from_date': '2026-10-28T00:00:00.000Z',
        'to_date': '2027-01-28T00:00:00.000Z',
      }, 201));
      final m = await ctx.api().createMembership(token, body);
      expectJson(backend().only, 'POST', '/memberships', body);
      expect(m.toDate, DateTime.utc(2027, 1, 28));
    });

    test('updateMembership PUTs /memberships/:id', () async {
      final body = {'to_date': '2027-02-28', 'is_active': true};
      backend().on('PUT /memberships/$membershipId', ok({...membershipJson, 'to_date': '2027-02-28T00:00:00.000Z'}));
      final m = await ctx.api().updateMembership(token, membershipId, body);
      expectJson(backend().only, 'PUT', '/memberships/$membershipId', body);
      expect(m.toDate, DateTime.utc(2027, 2, 28));
    });

    test('deleteMembership DELETEs /memberships/:id', () async {
      backend().on('DELETE /memberships/$membershipId', ok('', 204));
      await ctx.api().deleteMembership(token, membershipId);
      expectDelete(backend().only, '/memberships/$membershipId');
    });
  });

  group('membership invoices', () {
    test('getMembershipInvoices parses joined fields and string amounts; filters', () async {
      backend().on('GET /membership-invoices', ok([
        invoiceJson,
        {
          ...invoiceJson,
          'id': 'inv-2',
          'amount': '119.98',
          'status': 'unpaid',
          'paid_at': null,
          'member_last_name': null,
        },
        {...invoiceJson, 'id': 'inv-3', 'status': 'void', 'paid_at': null},
      ]));
      final list = await ctx.api().getMembershipInvoices(token);
      expectGet(backend().requests.last, '/membership-invoices');

      final inv = list[0];
      expect(inv.id, invoiceId);
      expect(inv.membershipId, '9e185427-a2a8-4fb4-9190-bb0f04cab2d2');
      expect(inv.membershipTypeId, '023080fb-2104-42ed-9ca0-2f4f2445cc3d');
      expect(inv.issuedAt, DateTime.utc(2026, 10, 13, 9, 15, 27, 208));
      expect(inv.amount, 29.99);
      expect(inv.status, InvoiceStatus.paid);
      expect(inv.paidAt, DateTime.utc(2026, 10, 28, 18, 40, 40, 51));
      expect(inv.userId, 'c5e4e2c2-6d13-4b26-8dd3-bd5067621930');
      expect(inv.memberFullName, 'Daniel Kim');
      expect(inv.gymId, gymId);
      expect(inv.gymName, 'Ironclad Fitness');
      expect(inv.membershipTypeName, 'Basic');

      expect(list[1].amount, 119.98);
      expect(list[1].status, InvoiceStatus.unpaid);
      expect(list[1].paidAt, isNull);
      expect(list[1].memberFullName, 'Daniel');
      expect(list[2].status, InvoiceStatus.voided);

      await ctx.api().getMembershipInvoices(
        token,
        membershipId: membershipId,
        gymId: gymId,
        userId: liamId,
        status: InvoiceStatus.voided,
      );
      expectGet(backend().requests.last, '/membership-invoices', {
        'membership_id': membershipId,
        'gym_id': gymId,
        'user_id': liamId,
        'status': 'void',
      });
    });

    test('createMembershipInvoice POSTs the body; the bare insert row parses', () async {
      final body = {'membership_id': membershipId, 'membership_type_id': premiumId, 'amount': 179.97};
      backend().on('POST /membership-invoices', ok({
        'id': 'inv-new',
        'membership_id': membershipId,
        'membership_type_id': premiumId,
        'issued_at': '2026-10-28T12:00:00.000Z',
        'amount': '179.97',
        'status': 'unpaid',
        'paid_at': null,
      }, 201));
      final inv = await ctx.api().createMembershipInvoice(token, body);
      expectJson(backend().only, 'POST', '/membership-invoices', body);
      expect(inv.amount, 179.97);
      expect(inv.status, InvoiceStatus.unpaid);
      expect(inv.memberName, isNull);
      expect(inv.memberFullName, '');
    });

    test('updateMembershipInvoiceStatus PUTs the API status value', () async {
      backend().on('PUT /membership-invoices/$invoiceId', ok({...invoiceJson, 'status': 'void', 'paid_at': null}));
      final inv = await ctx.api().updateMembershipInvoiceStatus(token, invoiceId, InvoiceStatus.voided);
      expectJson(backend().only, 'PUT', '/membership-invoices/$invoiceId', {'status': 'void'});
      expect(inv.status, InvoiceStatus.voided);
      expect(inv.paidAt, isNull);

      backend().on('PUT /membership-invoices/$invoiceId', ok(invoiceJson));
      await ctx.api().updateMembershipInvoiceStatus(token, invoiceId, InvoiceStatus.paid);
      expect(bodyOf(backend().requests.last), {'status': 'paid'});
      await ctx.api().updateMembershipInvoiceStatus(token, invoiceId, InvoiceStatus.unpaid);
      expect(bodyOf(backend().requests.last), {'status': 'unpaid'});
    });
  });

  errorTests(ctx, {
    'getShopItems': ('GET /shop-items', (api) => api.getShopItems(token)),
    'createShopItem': ('POST /shop-items', (api) => api.createShopItem(token, {'name': 'x'})),
    'updateShopItem': ('PUT /shop-items/$itemId', (api) => api.updateShopItem(token, itemId, {'name': 'x'})),
    'deleteShopItem': ('DELETE /shop-items/$itemId', (api) => api.deleteShopItem(token, itemId)),
    'getGymMembershipTypes': ('GET /gym-membership-types', (api) => api.getGymMembershipTypes(token)),
    'createGymMembershipType': ('POST /gym-membership-types', (api) => api.createGymMembershipType(token, {'name': 'x'})),
    'updateGymMembershipType': (
      'PUT /gym-membership-types/$premiumId',
      (api) => api.updateGymMembershipType(token, premiumId, {'name': 'x'}),
    ),
    'deleteGymMembershipType': ('DELETE /gym-membership-types/$premiumId', (api) => api.deleteGymMembershipType(token, premiumId)),
    'getMemberships': ('GET /memberships', (api) => api.getMemberships(token)),
    'createMembership': ('POST /memberships', (api) => api.createMembership(token, {'user_id': 'x'})),
    'updateMembership': ('PUT /memberships/$membershipId', (api) => api.updateMembership(token, membershipId, {'is_active': false})),
    'deleteMembership': ('DELETE /memberships/$membershipId', (api) => api.deleteMembership(token, membershipId)),
    'getMembershipInvoices': ('GET /membership-invoices', (api) => api.getMembershipInvoices(token)),
    'createMembershipInvoice': ('POST /membership-invoices', (api) => api.createMembershipInvoice(token, {'amount': 1})),
    'updateMembershipInvoiceStatus': (
      'PUT /membership-invoices/$invoiceId',
      (api) => api.updateMembershipInvoiceStatus(token, invoiceId, InvoiceStatus.paid),
    ),
  });
}
