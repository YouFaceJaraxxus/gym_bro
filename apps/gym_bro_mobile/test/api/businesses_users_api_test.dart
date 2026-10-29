import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/user_profile.dart';

import '../helpers/fake_backend.dart';
import 'api_test_utils.dart';

// Response bodies trimmed from the local stack (GET /businesses,
// /businesses/stats, /users, /search-users).
const gymId = 'ff453a60-28ca-4cdd-a919-c6ecd344ab65';
const shopId = 'fbec11a8-6dfd-4458-a6ad-78e666016a74';
const liamId = '8d0b05de-7c18-441b-9536-aaa042eaeaaa';

final gymJson = {
  'id': gymId,
  'name': 'Ironclad Fitness',
  'location': '482 Halsey Street, Brooklyn, NY 11233',
  'logo': 'https://picsum.photos/seed/gym-logo/800/400',
  'working_hours_from': '05:00:00',
  'working_hours_to': '23:00:00',
  'working_weekdays': [1, 2, 3, 4, 5, 6, 7],
  'type': 'gym',
  'latitude': 40.6826,
  'longitude': -73.9298,
};

final shopJson = {
  'id': shopId,
  'name': 'Peak Performance Supply Co.',
  'location': '17 Court Street, Brooklyn, NY 11201',
  'logo': null,
  'working_hours_from': '09:00:00',
  'working_hours_to': '19:00:00',
  'working_weekdays': [1, 2, 3, 4, 5, 6],
  'type': 'shop',
  'latitude': 40.6915,
  'longitude': -73.9912,
};

final liamJson = {
  'id': liamId,
  'username': 'liamoconnor',
  'email': 'liam.oconnor@example.com',
  'name': 'Liam',
  'last_name': "O'Connor",
  'role': 'member',
  'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=liamoconnor&size=256',
  'auth_id': '774941e4-d9e1-4097-9e3d-823aaa9ba6a3',
  'created_at': '2026-09-15T16:05:42.372Z',
  'updated_at': '2026-10-28T18:40:23.199Z',
};

void main() {
  final ctx = useFakeBackend();
  FakeBackend backend() => ctx.backend();

  group('businesses', () {
    test('getBusinesses parses every field of gyms and shops', () async {
      backend().on('GET /businesses', ok([shopJson, gymJson]));
      final list = await ctx.api().getBusinesses(token);

      expectGet(backend().only, '/businesses');
      expect(list, hasLength(2));
      final shop = list[0], gym = list[1];
      expect(shop.id, shopId);
      expect(shop.name, 'Peak Performance Supply Co.');
      expect(shop.location, '17 Court Street, Brooklyn, NY 11201');
      expect(shop.logo, isNull);
      expect(shop.workingHoursFrom, '09:00:00');
      expect(shop.workingHoursTo, '19:00:00');
      expect(shop.workingWeekdays, [1, 2, 3, 4, 5, 6]);
      expect(shop.type, 'shop');
      expect(gym.type, 'gym');
      expect(gym.logo, 'https://picsum.photos/seed/gym-logo/800/400');
      expect(gym.workingWeekdays, [1, 2, 3, 4, 5, 6, 7]);
    });

    test('getBusinesses returns an empty list', () async {
      backend().on('GET /businesses', ok([]));
      expect(await ctx.api().getBusinesses(token), isEmpty);
    });

    test('getBusiness GETs /businesses/:id', () async {
      backend().on('GET /businesses/$gymId', ok(gymJson));
      final b = await ctx.api().getBusiness(token, gymId);
      expectGet(backend().only, '/businesses/$gymId');
      expect(b.name, 'Ironclad Fitness');
      expect(b.workingHoursFrom, '05:00:00');
    });

    test('createBusiness POSTs the form data as-is (logo null included)', () async {
      backend().on('POST /businesses', ok({...gymJson, 'logo': null}, 201));
      final data = {
        'name': 'Ironclad Fitness',
        'location': '482 Halsey Street, Brooklyn, NY 11233',
        'type': 'gym',
        'working_hours_from': '05:00',
        'working_hours_to': '23:00',
        'working_weekdays': [1, 2, 3, 4, 5, 6, 7],
        'logo': null,
      };
      final b = await ctx.api().createBusiness(token, data);
      expectJson(backend().only, 'POST', '/businesses', data);
      expect(b.id, gymId);
      expect(b.logo, isNull);
    });

    test('updateBusiness PUTs /businesses/:id', () async {
      backend().on('PUT /businesses/$gymId', ok({...gymJson, 'working_weekdays': [1, 2, 3, 4, 5]}));
      final data = {'name': 'Ironclad Fitness', 'working_weekdays': [1, 2, 3, 4, 5]};
      final b = await ctx.api().updateBusiness(token, gymId, data);
      expectJson(backend().only, 'PUT', '/businesses/$gymId', data);
      expect(b.workingWeekdays, [1, 2, 3, 4, 5]);
    });

    test('deleteBusiness DELETEs /businesses/:id and accepts 204', () async {
      backend().on('DELETE /businesses/$gymId', ok('', 204));
      await ctx.api().deleteBusiness(token, gymId);
      expectDelete(backend().only, '/businesses/$gymId');
    });

    test('getBusinessStats parses counts and the numeric-string month total', () async {
      backend().on('GET /businesses/stats', ok({
        'gyms': 1,
        'members_total': 8,
        'active_memberships': 4,
        'staff_total': 5,
        'invoices_month_count': 7,
        'invoices_month_total': '369.93',
        'unpaid_invoices_count': 2,
        'expiring_soon': [
          {
            'membership_id': 'm-1',
            'user_id': liamId,
            'name': 'Liam',
            'last_name': "O'Connor",
            'gym_id': gymId,
            'gym_name': 'Ironclad Fitness',
            'to_date': '2026-11-02T00:00:00.000Z',
          },
          // count() as a string, name columns null.
          {
            'membership_id': 'm-2',
            'user_id': 'u-2',
            'name': null,
            'last_name': null,
            'gym_id': gymId,
            'gym_name': null,
            'to_date': '2026-11-05',
          },
        ],
      }));
      final s = await ctx.api().getBusinessStats(token);

      expectGet(backend().only, '/businesses/stats');
      expect(s.gyms, 1);
      expect(s.membersTotal, 8);
      expect(s.activeMemberships, 4);
      expect(s.staffTotal, 5);
      expect(s.invoicesMonthCount, 7);
      expect(s.invoicesMonthTotal, 369.93);
      expect(s.unpaidInvoicesCount, 2);
      expect(s.expiringSoon, hasLength(2));
      final e = s.expiringSoon.first;
      expect(e.membershipId, 'm-1');
      expect(e.userId, liamId);
      expect(e.fullName, "Liam O'Connor");
      expect(e.gymId, gymId);
      expect(e.gymName, 'Ironclad Fitness');
      expect(e.toDate, DateTime.utc(2026, 11, 2));
      expect(s.expiringSoon[1].fullName, '');
      expect(s.expiringSoon[1].gymName, '');
      expect(s.expiringSoon[1].toDate, DateTime(2026, 11, 5));
    });

    test('getBusinessStats accepts string counts and an empty/absent expiring list', () async {
      backend().on('GET /businesses/stats', ok({
        'gyms': '2',
        'members_total': '0',
        'active_memberships': null,
        'staff_total': 3,
        'invoices_month_count': '0',
        'invoices_month_total': null,
        'unpaid_invoices_count': '0',
      }));
      final s = await ctx.api().getBusinessStats(token);
      expect(s.gyms, 2);
      expect(s.membersTotal, 0);
      expect(s.activeMemberships, 0);
      expect(s.invoicesMonthTotal, 0);
      expect(s.expiringSoon, isEmpty);
    });
  });

  group('users', () {
    test('getUsers parses profiles (role mapping, nullable avatar)', () async {
      backend().on('GET /users', ok([
        liamJson,
        {
          'id': 'u-et',
          'username': 'aishamohammed',
          'email': 'aisha.mohammed@example.com',
          'name': 'Aisha',
          'last_name': 'Mohammed',
          'role': 'employee_trainer',
          'avatar_url': null,
        },
        {'id': 'u-su', 'username': 'chloe', 'name': 'Chloe', 'last_name': 'Anderson', 'role': 'super_user'},
      ]));
      final users = await ctx.api().getUsers(token);

      expectGet(backend().only, '/users');
      final liam = users[0];
      expect(liam.id, liamId);
      expect(liam.username, 'liamoconnor');
      expect(liam.email, 'liam.oconnor@example.com');
      expect(liam.name, 'Liam');
      expect(liam.lastName, "O'Connor");
      expect(liam.fullName, "Liam O'Connor");
      expect(liam.role, UserRole.member);
      expect(liam.avatarUrl, startsWith('https://api.dicebear.com/'));
      expect(users[1].role, UserRole.employeeTrainer);
      expect(users[1].avatarUrl, isNull);
      expect(users[2].role, UserRole.superUser);
      expect(users[2].email, '', reason: 'email is omitted for other users');
    });

    test('searchUsers encodes the query and parses role entries', () async {
      backend().on('GET /search-users', ok([
        {
          'id': liamId,
          'username': 'liamoconnor',
          'email': 'liam.oconnor@example.com',
          'name': 'Liam',
          'last_name': "O'Connor",
          'role': 'member',
          'member_entries': [
            {'id': '077bbb0f-ca49-4558-96e9-dc176b9811d5', 'gym_id': gymId},
          ],
          'employee_entries': [],
          'employee_trainer_entries': [],
          'trainer_entries': [
            {'id': 'tr-1', 'gym_id': gymId},
          ],
          'gym_owner_entries': [],
          'shop_owner_entries': [],
          'shop_vendor_entries': [
            {'id': 'sv-1', 'shop_id': shopId},
          ],
        },
      ]));
      final results = await ctx.api().searchUsers(token, query: "o'connor & co", page: 2, pageSize: 5);

      final r = backend().only;
      expectGet(r, '/search-users', {'q': "o'connor & co", 'page': '2', 'page_size': '5'});
      expect(r.url.query, contains('q=o\'connor%20%26%20co'));
      final u = results.single;
      expect(u.id, liamId);
      expect(u.fullName, "Liam O'Connor");
      expect(u.role, 'member');
      expect(u.roleEntries.map((e) => (e.type, e.id, e.gymId, e.shopId)), [
        ('member', '077bbb0f-ca49-4558-96e9-dc176b9811d5', gymId, null),
        ('trainer', 'tr-1', gymId, null),
        ('shop_vendor', 'sv-1', null, shopId),
      ]);
    });

    test('searchUsers defaults: empty q, page 0, page_size 10', () async {
      backend().on('GET /search-users', ok([]));
      expect(await ctx.api().searchUsers(token), isEmpty);
      expectGet(backend().only, '/search-users', {'q': '', 'page': '0', 'page_size': '10'});
    });

    test('getUserByEmail encodes the email and returns the first match', () async {
      backend().on('GET /users', ok([liamJson]));
      final u = await ctx.api().getUserByEmail(token, 'liam+gym@example.com');
      final r = backend().only;
      expectGet(r, '/users', {'email': 'liam+gym@example.com'});
      expect(r.url.query, 'email=liam%2Bgym%40example.com', reason: '+ must not turn into a space');
      expect(u!.id, liamId);
    });

    test('getUserByEmail returns null when nobody matches', () async {
      backend().on('GET /users', ok([]));
      expect(await ctx.api().getUserByEmail(token, 'nobody@example.com'), isNull);
    });

    test('getUser GETs /users/:id (email omitted for others)', () async {
      final other = Map.of(liamJson)..remove('email');
      backend().on('GET /users/$liamId', ok(other));
      final u = await ctx.api().getUser(token, liamId);
      expectGet(backend().only, '/users/$liamId');
      expect(u.email, '');
      expect(u.username, 'liamoconnor');
    });

    test('createUser POSTs /users/signup with snake_case fields and unwraps `user`', () async {
      backend().on('POST /users/signup', ok({
        'message': 'Check your email to verify your account.',
        'user': {...liamJson, 'role': 'trainer'},
        'role_assignment': null,
      }, 201));
      final u = await ctx.api().createUser(
        token,
        email: 'liam.oconnor@example.com',
        password: 'hunter22',
        username: 'liamoconnor',
        name: 'Liam',
        lastName: "O'Connor",
        role: 'trainer',
      );
      expectJson(backend().only, 'POST', '/users/signup', {
        'email': 'liam.oconnor@example.com',
        'password': 'hunter22',
        'username': 'liamoconnor',
        'name': 'Liam',
        'last_name': "O'Connor",
        'role': 'trainer',
      });
      expect(u.role, UserRole.trainer);
      expect(u.id, liamId);
    });

    test('updateUser PUTs /users/:id with the data map', () async {
      backend().on('PUT /users/$liamId', ok({...liamJson, 'name': 'William', 'avatar_url': null}));
      final data = {'name': 'William', 'last_name': "O'Connor", 'username': 'liamoconnor', 'avatar_url': null};
      final u = await ctx.api().updateUser(token, liamId, data);
      expectJson(backend().only, 'PUT', '/users/$liamId', data);
      expect(u.name, 'William');
      expect(u.avatarUrl, isNull);
    });

    test('changePassword POSTs current/new password', () async {
      backend().on('POST /users/change-password', ok({'success': true}));
      await ctx.api().changePassword(token, currentPassword: 'old-pass', newPassword: 'new-pass-1');
      expectJson(backend().only, 'POST', '/users/change-password', {
        'current_password': 'old-pass',
        'new_password': 'new-pass-1',
      });
    });

    test('changePassword surfaces a wrong current password (400)', () async {
      backend().on('POST /users/change-password', err(400, 'Current password is incorrect'));
      await expectLater(
        ctx.api().changePassword(token, currentPassword: 'x', newPassword: 'y'),
        throwsApiError('Current password is incorrect'),
      );
    });

    test('deleteUser DELETEs /users/:id; a 409 explains why', () async {
      backend().on('DELETE /users/$liamId', ok('', 204));
      await ctx.api().deleteUser(token, liamId);
      expectDelete(backend().only, '/users/$liamId');

      backend().on('DELETE /users/$liamId', err(409, 'Transfer or delete your businesses first'));
      await expectLater(ctx.api().deleteUser(token, liamId), throwsApiError('Transfer or delete your businesses first'));
    });

    test('resendInvite POSTs the email', () async {
      backend().on('POST /users/resend-invite', ok({'success': true}));
      await ctx.api().resendInvite(token, 'new.member@example.com');
      expectJson(backend().only, 'POST', '/users/resend-invite', {'email': 'new.member@example.com'});
    });
  });

  group('uploadImage', () {
    String multipart(String body) => body.replaceAll('\r\n', '\n');

    test('sends a multipart form with bucket, folder and the file', () async {
      backend().on('POST /uploads', ok({
        'url': 'http://127.0.0.1:54321/storage/v1/object/public/media/exercises/abc.png',
        'bucket': 'media',
        'path': 'exercises/abc.png',
      }, 201));
      final url = await ctx.api().uploadImage(
        token,
        bytes: utf8.encode('PNGDATA'),
        filename: 'Bench.PNG',
        bucket: 'media',
        folder: 'exercises',
      );

      final r = backend().only;
      expect(r.method, 'POST');
      expect(pathOf(r), '/uploads');
      expectAuthed(r);
      expect(r.headers['content-type'], startsWith('multipart/form-data; boundary='));
      final body = multipart(latin1.decode(r.bodyBytes));
      expect(body, contains('content-disposition: form-data; name="bucket"\n\nmedia\n'));
      expect(body, contains('content-disposition: form-data; name="folder"\n\nexercises\n'));
      expect(body, contains('content-type: image/png\ncontent-disposition: form-data; name="file"; filename="Bench.PNG"\n\nPNGDATA\n'));
      expect(url, 'http://127.0.0.1:54321/storage/v1/object/public/media/exercises/abc.png');
    });

    test('omits folder when null; webp and default jpeg mime types', () async {
      backend().on('POST /uploads', ok({'url': 'https://x/avatars/a.webp'}, 201));
      await ctx.api().uploadImage(token, bytes: [1, 2, 3], filename: 'me.webp', bucket: 'avatars');
      var body = multipart(latin1.decode(backend().requests.last.bodyBytes));
      expect(body, isNot(contains('name="folder"')));
      expect(body, contains('name="bucket"\n\navatars\n'));
      expect(body, contains('content-type: image/webp'));

      await ctx.api().uploadImage(token, bytes: [1, 2, 3], filename: 'photo.heic', bucket: 'media');
      body = multipart(latin1.decode(backend().requests.last.bodyBytes));
      expect(body, contains('content-type: image/jpeg'));
    });
  });

  errorTests(ctx, {
    'getBusinesses': ('GET /businesses', (api) => api.getBusinesses(token)),
    'getBusiness': ('GET /businesses/$gymId', (api) => api.getBusiness(token, gymId)),
    'createBusiness': ('POST /businesses', (api) => api.createBusiness(token, {'name': 'x'})),
    'updateBusiness': ('PUT /businesses/$gymId', (api) => api.updateBusiness(token, gymId, {'name': 'x'})),
    'deleteBusiness': ('DELETE /businesses/$gymId', (api) => api.deleteBusiness(token, gymId)),
    'getBusinessStats': ('GET /businesses/stats', (api) => api.getBusinessStats(token)),
    'getUsers': ('GET /users', (api) => api.getUsers(token)),
    'searchUsers': ('GET /search-users', (api) => api.searchUsers(token, query: 'li')),
    'getUserByEmail': ('GET /users', (api) => api.getUserByEmail(token, 'a@b.c')),
    'getUser': ('GET /users/$liamId', (api) => api.getUser(token, liamId)),
    'createUser': ('POST /users/signup', (api) => api.createUser(token, email: 'a@b.c', password: 'p', username: 'u', name: 'n', lastName: 'l', role: 'member'),
    ),
    'updateUser': ('PUT /users/$liamId', (api) => api.updateUser(token, liamId, {'name': 'x'})),
    'changePassword': ('POST /users/change-password', (api) => api.changePassword(token, currentPassword: 'a', newPassword: 'b')),
    'deleteUser': ('DELETE /users/$liamId', (api) => api.deleteUser(token, liamId)),
    'resendInvite': ('POST /users/resend-invite', (api) => api.resendInvite(token, 'a@b.c')),
    'uploadImage': ('POST /uploads', (api) => api.uploadImage(token, bytes: [1], filename: 'a.png', bucket: 'media')),
  });
}
