import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/user_profile.dart';

import '../helpers/fake_backend.dart';
import 'api_test_utils.dart';

// Gym/shop role rows (GET /gym-owners, /shop-owners, /members, /employees,
// /employee-trainers, /shop-vendors, /trainers) trimmed from the local stack.
// These methods return the raw rows; screens map them with
// UserProfile.fromRoleRow, so the tests check that too.
const gymId = 'ff453a60-28ca-4cdd-a919-c6ecd344ab65';
const shopId = 'fbec11a8-6dfd-4458-a6ad-78e666016a74';
const userId = '8e6bec6e-9e70-43ef-8740-17d81727474d';

final memberRow = {
  'id': 'cfb09a22-20c9-4db1-b1a1-18de7419b6cb',
  'user_id': userId,
  'gym_id': gymId,
  'name': 'Kenji',
  'last_name': 'Tanaka',
  'username': 'kenjitanaka',
  'email': 'kenji.tanaka@example.com',
  'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=kenjitanaka&size=256',
  'role': 'member',
};

final employeeRow = {
  'id': 'ea7e879d-0ee7-4953-862c-e1020b82ace1',
  'user_id': '2ad357f9-06dd-4c3a-82a0-e60f0feaa84e',
  'gym_id': gymId,
  'email': 'priya.nair@example.com',
  'name': 'Priya',
  'last_name': 'Nair',
  'username': 'priyanair',
  'role': 'employee',
  'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=priyanair&size=256',
};

final employeeTrainerRow = {
  'id': '68511de4-7166-4fcc-a9b1-c00fb5130bcb',
  'user_id': 'e0260907-13bf-41a4-98a0-10a6193f6628',
  'gym_id': gymId,
  'email': 'aisha.mohammed@example.com',
  'name': 'Aisha',
  'last_name': 'Mohammed',
  'username': 'aishamohammed',
  'role': 'employee_trainer',
  'avatar_url': null,
};

final vendorRow = {
  'id': '1fab3baa-0369-4e23-aba3-458e9a639e6b',
  'user_id': '9b96e959-3ba5-497c-bae0-9cf1f6d2dc55',
  'shop_id': shopId,
  'email': 'ravi.deshmukh@example.com',
  'name': 'Ravi',
  'last_name': 'Deshmukh',
  'username': 'ravideshmukh',
  'role': 'shop_vendor',
  'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=ravideshmukh&size=256',
};

// Trainer and gym-owner rows carry no email/role.
final trainerRow = {
  'id': '42089778-a99c-4160-984a-ba84d29829d0',
  'user_id': 'f591534f-a631-4b71-9fd4-b8260e6f3ee6',
  'gym_id': gymId,
  'name': 'Elena',
  'last_name': 'Vasquez',
  'username': 'elenavasquez',
  'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=elenavasquez&size=256',
};

final gymOwnerRow = {
  'id': '257a29f1-a43a-433b-ad5a-d34c41c3d73e',
  'user_id': 'b8d30b8b-ebb3-4a91-b5c4-39992a7deb8d',
  'gym_id': gymId,
  'name': 'Marcus',
  'last_name': 'Bennett',
  'username': 'marcusbennett',
  'avatar_url': null,
};

final shopOwnerRow = {
  'id': 'dd025902-3cbe-49b2-83ff-9063c8375bbe',
  'user_id': 'b8d30b8b-ebb3-4a91-b5c4-39992a7deb8d',
  'shop_id': shopId,
};

void main() {
  final ctx = useFakeBackend();
  FakeBackend backend() => ctx.backend();

  group('owners', () {
    test('getGymOwners without a filter sends no query', () async {
      backend().on('GET /gym-owners', ok([gymOwnerRow]));
      final rows = await ctx.api().getGymOwners(token);
      expectGet(backend().only, '/gym-owners');
      expect(rows, [gymOwnerRow]);
      final owner = UserProfile.fromRoleRow(rows.single);
      expect(owner.id, 'b8d30b8b-ebb3-4a91-b5c4-39992a7deb8d');
      expect(owner.fullName, 'Marcus Bennett');
      expect(owner.email, '');
      expect(owner.avatarUrl, isNull);
    });

    test('getGymOwners filters by user_id', () async {
      backend().on('GET /gym-owners', ok([gymOwnerRow]));
      await ctx.api().getGymOwners(token, userId: 'b8d30b8b-ebb3-4a91-b5c4-39992a7deb8d');
      expectGet(backend().only, '/gym-owners', {'user_id': 'b8d30b8b-ebb3-4a91-b5c4-39992a7deb8d'});
    });

    test('getShopOwners returns raw rows; user_id filter', () async {
      backend().on('GET /shop-owners', ok([shopOwnerRow]));
      expect(await ctx.api().getShopOwners(token), [shopOwnerRow]);
      expectGet(backend().requests.last, '/shop-owners');

      await ctx.api().getShopOwners(token, userId: 'u-9');
      expectGet(backend().requests.last, '/shop-owners', {'user_id': 'u-9'});
    });
  });

  group('members', () {
    test('getMembers: no filters, gym only, gym + user', () async {
      backend().on('GET /members', ok([memberRow]));
      final rows = await ctx.api().getMembers(token);
      expectGet(backend().requests.last, '/members');
      final p = UserProfile.fromRoleRow(rows.single);
      expect(p.id, userId);
      expect(p.username, 'kenjitanaka');
      expect(p.email, 'kenji.tanaka@example.com');
      expect(p.fullName, 'Kenji Tanaka');
      expect(p.role, UserRole.member);
      expect(rows.single['id'], 'cfb09a22-20c9-4db1-b1a1-18de7419b6cb');

      await ctx.api().getMembers(token, gymId: gymId);
      expectGet(backend().requests.last, '/members', {'gym_id': gymId});

      await ctx.api().getMembers(token, gymId: gymId, userId: userId);
      expectGet(backend().requests.last, '/members', {'gym_id': gymId, 'user_id': userId});
      expect(backend().requests.last.url.query, 'gym_id=$gymId&user_id=$userId');
    });

    test('addMember POSTs user_id + gym_id and returns the member row', () async {
      final created = {'id': 'mem-new', 'user_id': userId, 'gym_id': gymId, 'created_at': '2026-10-28T10:00:00.000Z'};
      backend().on('POST /members', ok(created, 201));
      final row = await ctx.api().addMember(token, userId, gymId);
      expectJson(backend().only, 'POST', '/members', {'user_id': userId, 'gym_id': gymId});
      expect(row, created);
    });

    test('addMember surfaces "already a member" (409)', () async {
      backend().on('POST /members', err(409, 'This user is already a member of this gym'));
      await expectLater(ctx.api().addMember(token, userId, gymId), throwsApiError('This user is already a member of this gym'));
    });

    test('inviteMember POSTs the new user fields without user_id', () async {
      final created = {'id': 'mem-new', 'user_id': 'u-new', 'gym_id': gymId};
      backend().on('POST /members', ok(created, 201));
      final row = await ctx.api().inviteMember(
        token,
        email: 'new.member@example.com',
        name: 'Nora',
        lastName: 'Lindqvist',
        username: 'noralindqvist',
        gymId: gymId,
      );
      expectJson(backend().only, 'POST', '/members', {
        'email': 'new.member@example.com',
        'name': 'Nora',
        'last_name': 'Lindqvist',
        'username': 'noralindqvist',
        'gym_id': gymId,
      });
      expect(row['user_id'], 'u-new');
    });

    test('removeMember DELETEs /members/:id', () async {
      backend().on('DELETE /members/mem-1', ok('', 204));
      await ctx.api().removeMember(token, 'mem-1');
      expectDelete(backend().only, '/members/mem-1');
    });
  });

  group('employees', () {
    test('getEmployees: filters and embedded user fields', () async {
      backend().on('GET /employees', ok([employeeRow]));
      final rows = await ctx.api().getEmployees(token, gymId: gymId);
      expectGet(backend().only, '/employees', {'gym_id': gymId});
      final p = UserProfile.fromRoleRow(rows.single);
      expect(p.fullName, 'Priya Nair');
      expect(p.role, UserRole.employee);
      expect(p.email, 'priya.nair@example.com');

      await ctx.api().getEmployees(token, userId: 'u-1');
      expectGet(backend().requests.last, '/employees', {'user_id': 'u-1'});
      await ctx.api().getEmployees(token);
      expectGet(backend().requests.last, '/employees');
    });

    test('addEmployee for an existing user sends only user_id, gym_id, employee_type', () async {
      final invited = {'status': 'invited', 'notification_id': 'n-1'};
      backend().on('POST /employees', ok(invited, 201));
      final res = await ctx.api().addEmployee(
        token,
        userId: 'u-1',
        // Ignored when userId is given.
        email: 'ignored@example.com',
        name: 'Ignored',
        gymId: gymId,
        employeeType: 'employee_trainer',
      );
      expectJson(backend().only, 'POST', '/employees', {
        'gym_id': gymId,
        'employee_type': 'employee_trainer',
        'user_id': 'u-1',
      });
      expect(res, invited);
    });

    test('addEmployee for a new user sends email + names', () async {
      backend().on('POST /employees', ok({...employeeRow}, 201));
      await ctx.api().addEmployee(
        token,
        email: 'priya.nair@example.com',
        name: 'Priya',
        lastName: 'Nair',
        username: 'priyanair',
        gymId: gymId,
        employeeType: 'employee',
      );
      expectJson(backend().only, 'POST', '/employees', {
        'gym_id': gymId,
        'employee_type': 'employee',
        'email': 'priya.nair@example.com',
        'name': 'Priya',
        'last_name': 'Nair',
        'username': 'priyanair',
      });
    });

    test('addEmployee by email omits null name fields (email key always present)', () async {
      backend().on('POST /employees', ok({'id': 'e-1'}, 201));
      await ctx.api().addEmployee(token, email: 'x@example.com', gymId: gymId, employeeType: 'employee');
      expectJson(backend().only, 'POST', '/employees', {
        'gym_id': gymId,
        'employee_type': 'employee',
        'email': 'x@example.com',
      });
    });

    test('removeEmployee DELETEs /employees/:id', () async {
      backend().on('DELETE /employees/emp-1', ok('', 204));
      await ctx.api().removeEmployee(token, 'emp-1');
      expectDelete(backend().only, '/employees/emp-1');
    });

    test('changeEmployeeRole PUTs /employees/role and returns the new staff row', () async {
      backend().on('PUT /employees/role', ok(employeeTrainerRow));
      final row = await ctx.api().changeEmployeeRole(
        token,
        userId: 'e0260907-13bf-41a4-98a0-10a6193f6628',
        gymId: gymId,
        employeeType: 'employee_trainer',
      );
      expectJson(backend().only, 'PUT', '/employees/role', {
        'user_id': 'e0260907-13bf-41a4-98a0-10a6193f6628',
        'gym_id': gymId,
        'employee_type': 'employee_trainer',
      });
      expect(row['id'], '68511de4-7166-4fcc-a9b1-c00fb5130bcb');
      expect(UserProfile.fromRoleRow(row).role, UserRole.employeeTrainer);
    });
  });

  group('employee-trainers', () {
    test('getEmployeeTrainers: filters and null avatar', () async {
      backend().on('GET /employee-trainers', ok([employeeTrainerRow]));
      final rows = await ctx.api().getEmployeeTrainers(token, gymId: gymId, userId: 'u-2');
      expectGet(backend().only, '/employee-trainers', {'gym_id': gymId, 'user_id': 'u-2'});
      final p = UserProfile.fromRoleRow(rows.single);
      expect(p.fullName, 'Aisha Mohammed');
      expect(p.avatarUrl, isNull);
      expect(p.role, UserRole.employeeTrainer);
    });

    test('removeEmployeeTrainer DELETEs /employee-trainers/:id', () async {
      backend().on('DELETE /employee-trainers/et-1', ok('', 204));
      await ctx.api().removeEmployeeTrainer(token, 'et-1');
      expectDelete(backend().only, '/employee-trainers/et-1');
    });
  });

  group('trainers', () {
    test('getTrainers: filters; rows without email/role', () async {
      backend().on('GET /trainers', ok([trainerRow]));
      final rows = await ctx.api().getTrainers(token, gymId: gymId);
      expectGet(backend().only, '/trainers', {'gym_id': gymId});
      final p = UserProfile.fromRoleRow(rows.single);
      expect(p.id, 'f591534f-a631-4b71-9fd4-b8260e6f3ee6');
      expect(p.email, '');
      expect(p.fullName, 'Elena Vasquez');

      await ctx.api().getTrainers(token, userId: 'u-3');
      expectGet(backend().requests.last, '/trainers', {'user_id': 'u-3'});
      await ctx.api().getTrainers(token);
      expectGet(backend().requests.last, '/trainers');
    });
  });

  group('shop vendors', () {
    test('getShopVendors: shop_id / user_id filters', () async {
      backend().on('GET /shop-vendors', ok([vendorRow]));
      final rows = await ctx.api().getShopVendors(token, shopId: shopId);
      expectGet(backend().only, '/shop-vendors', {'shop_id': shopId});
      expect(UserProfile.fromRoleRow(rows.single).role, UserRole.shopVendor);
      expect(rows.single['shop_id'], shopId);

      await ctx.api().getShopVendors(token, shopId: shopId, userId: 'u-4');
      expectGet(backend().requests.last, '/shop-vendors', {'shop_id': shopId, 'user_id': 'u-4'});
      await ctx.api().getShopVendors(token);
      expectGet(backend().requests.last, '/shop-vendors');
    });

    test('addShopVendor with an existing user sends shop_id + user_id only', () async {
      backend().on('POST /shop-vendors', ok({'status': 'invited'}, 201));
      final res = await ctx.api().addShopVendor(token, userId: 'u-4', email: 'ignored@example.com', shopId: shopId);
      expectJson(backend().only, 'POST', '/shop-vendors', {'shop_id': shopId, 'user_id': 'u-4'});
      expect(res, {'status': 'invited'});
    });

    test('addShopVendor by email sends the new user fields, omitting nulls', () async {
      backend().on('POST /shop-vendors', ok(vendorRow, 201));
      await ctx.api().addShopVendor(
        token,
        email: 'ravi.deshmukh@example.com',
        name: 'Ravi',
        lastName: 'Deshmukh',
        username: 'ravideshmukh',
        shopId: shopId,
      );
      expectJson(backend().last('POST /shop-vendors'), 'POST', '/shop-vendors', {
        'shop_id': shopId,
        'email': 'ravi.deshmukh@example.com',
        'name': 'Ravi',
        'last_name': 'Deshmukh',
        'username': 'ravideshmukh',
      });

      await ctx.api().addShopVendor(token, email: 'v@example.com', lastName: 'Only', shopId: shopId);
      expect(bodyOf(backend().requests.last), {'shop_id': shopId, 'email': 'v@example.com', 'last_name': 'Only'});
    });

    test('removeShopVendor DELETEs /shop-vendors/:id', () async {
      backend().on('DELETE /shop-vendors/sv-1', ok('', 204));
      await ctx.api().removeShopVendor(token, 'sv-1');
      expectDelete(backend().only, '/shop-vendors/sv-1');
    });
  });

  errorTests(ctx, {
    'getGymOwners': ('GET /gym-owners', (api) => api.getGymOwners(token)),
    'getShopOwners': ('GET /shop-owners', (api) => api.getShopOwners(token)),
    'getMembers': ('GET /members', (api) => api.getMembers(token, gymId: gymId)),
    'addMember': ('POST /members', (api) => api.addMember(token, userId, gymId)),
    'inviteMember': (
      'POST /members',
      (api) => api.inviteMember(token, email: 'a@b.c', name: 'n', lastName: 'l', username: 'u', gymId: gymId),
    ),
    'removeMember': ('DELETE /members/m-1', (api) => api.removeMember(token, 'm-1')),
    'getEmployees': ('GET /employees', (api) => api.getEmployees(token)),
    'addEmployee': ('POST /employees', (api) => api.addEmployee(token, userId: 'u', gymId: gymId, employeeType: 'employee')),
    'removeEmployee': ('DELETE /employees/e-1', (api) => api.removeEmployee(token, 'e-1')),
    'changeEmployeeRole': (
      'PUT /employees/role',
      (api) => api.changeEmployeeRole(token, userId: 'u', gymId: gymId, employeeType: 'employee'),
    ),
    'getEmployeeTrainers': ('GET /employee-trainers', (api) => api.getEmployeeTrainers(token)),
    'removeEmployeeTrainer': ('DELETE /employee-trainers/et-1', (api) => api.removeEmployeeTrainer(token, 'et-1')),
    'getTrainers': ('GET /trainers', (api) => api.getTrainers(token)),
    'getShopVendors': ('GET /shop-vendors', (api) => api.getShopVendors(token)),
    'addShopVendor': ('POST /shop-vendors', (api) => api.addShopVendor(token, userId: 'u', shopId: shopId)),
    'removeShopVendor': ('DELETE /shop-vendors/sv-1', (api) => api.removeShopVendor(token, 'sv-1')),
  });
}
