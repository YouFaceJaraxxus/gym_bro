import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/business.dart';
import 'package:gym_bro_mobile/services/api_service.dart';

import '../helpers/fake_backend.dart';
import 'api_test_utils.dart';

// Response bodies trimmed from the local stack (GET /businesses,
// /businesses/:id, /businesses/:id/team, /businesses/invites,
// /businesses/review, /businesses/stats, /users, /users/me, /search-users).
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
  'has_gym': true,
  'has_shop': true,
  'status': 'approved',
  'review_note': null,
  'my_roles': ['owner', 'trainer'],
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
  'has_gym': false,
  'has_shop': true,
  'status': 'pending',
  'review_note': null,
  'my_roles': ['staff'],
  'latitude': 40.6915,
  'longitude': -73.9912,
};

final liamJson = {
  'id': liamId,
  'username': 'liamoconnor',
  'email': 'liam.oconnor@example.com',
  'name': 'Liam',
  'last_name': "O'Connor",
  'is_super_user': false,
  'is_trainer': false,
  'avatar_url': 'https://api.dicebear.com/9.x/avataaars/png?seed=liamoconnor&size=256',
  'auth_id': '774941e4-d9e1-4097-9e3d-823aaa9ba6a3',
  'created_at': '2026-09-15T16:05:42.372Z',
  'updated_at': '2026-10-28T18:40:23.199Z',
};

void main() {
  final ctx = useFakeBackend();
  FakeBackend backend() => ctx.backend();

  group('businesses', () {
    test('getBusinesses parses sides, status and my roles', () async {
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
      expect((shop.hasGym, shop.hasShop), (false, true));
      expect(shop.status, BusinessStatus.pending);
      expect(shop.myRoles, [BusinessRole.staff]);
      expect(shop.isStaff, isTrue);
      expect(shop.isOwner, isFalse);
      expect((gym.hasGym, gym.hasShop), (true, true), reason: 'a business can be both');
      expect(gym.status, BusinessStatus.approved);
      expect(gym.myRoles, [BusinessRole.owner, BusinessRole.trainer]);
      expect(gym.canEditProfile, isTrue);
      expect(gym.logo, 'https://picsum.photos/seed/gym-logo/800/400');
      expect(gym.latitude, 40.6826);
      expect(gym.workingWeekdays, [1, 2, 3, 4, 5, 6, 7]);
    });

    test('getBusinesses filters by side; unknown roles are skipped', () async {
      backend().on('GET /businesses', ok([
        {...gymJson, 'my_roles': ['owner', 'employee']},
      ]));
      final list = await ctx.api().getBusinesses(token, side: 'gym');
      expectGet(backend().only, '/businesses', {'side': 'gym'});
      expect(list.single.myRoles, [BusinessRole.owner]);
    });

    test('getBusinesses returns an empty list', () async {
      backend().on('GET /businesses', ok([]));
      expect(await ctx.api().getBusinesses(token), isEmpty);
    });

    test('searchBusinesses encodes the query and side', () async {
      backend().on('GET /businesses/search', ok([gymJson]));
      final list = await ctx.api().searchBusinesses(token, query: 'iron & co', side: 'gym');
      final r = backend().only;
      expectGet(r, '/businesses/search', {'q': 'iron & co', 'side': 'gym'});
      expect(r.url.query, contains('q=iron+%26+co'));
      expect(list.single.id, gymId);

      backend().requests.clear();
      await ctx.api().searchBusinesses(token);
      expectGet(backend().only, '/businesses/search');
    });

    test('getBusiness parses the profile extras', () async {
      backend().on('GET /businesses/$gymId', ok({
        ...gymJson,
        'bio': 'Strength and conditioning since 2009.',
        'website': 'https://ironclad.fit',
        'phone': '+1 718 555 0101',
        'follower_count': '12',
        'is_following': true,
        'my_roles': [],
        'my_invites': ['trainer'],
        'owners': [
          {'id': 'u-marcus', 'username': 'marcusbennett', 'name': 'Marcus', 'last_name': 'Bennett', 'avatar_url': null},
        ],
        'trainers': [
          {'id': 'u-elena', 'username': 'elenavasquez', 'name': 'Elena', 'last_name': 'Vasquez'},
        ],
      }));
      final b = await ctx.api().getBusiness(token, gymId);
      expectGet(backend().only, '/businesses/$gymId');
      expect(b.name, 'Ironclad Fitness');
      expect(b.workingHoursFrom, '05:00:00');
      expect(b.bio, 'Strength and conditioning since 2009.');
      expect(b.website, 'https://ironclad.fit');
      expect(b.phone, '+1 718 555 0101');
      expect(b.followerCount, 12, reason: 'counts may arrive as strings');
      expect(b.isFollowing, isTrue);
      expect(b.onTeam, isFalse);
      expect(b.myInvites, [BusinessRole.trainer]);
      expect(b.owners.single.fullName, 'Marcus Bennett');
      expect(b.trainers.single.username, 'elenavasquez');
      expect(b.trainers.single.avatarUrl, isNull);
    });

    test('createBusiness POSTs the form data as-is (logo null included)', () async {
      backend().on('POST /businesses', ok({...gymJson, 'logo': null, 'status': 'pending'}, 201));
      final data = {
        'name': 'Ironclad Fitness',
        'location': '482 Halsey Street, Brooklyn, NY 11233',
        'has_gym': true,
        'has_shop': false,
        'working_hours_from': '05:00',
        'working_hours_to': '23:00',
        'working_weekdays': [1, 2, 3, 4, 5, 6, 7],
        'logo': null,
      };
      final b = await ctx.api().createBusiness(token, data);
      expectJson(backend().only, 'POST', '/businesses', data);
      expect(b.id, gymId);
      expect(b.logo, isNull);
      expect(b.status, BusinessStatus.pending);
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

    test('setFollowingBusiness PUTs to follow and DELETEs to unfollow', () async {
      backend().on('PUT /businesses/$gymId/follow', ok({'is_following': true}));
      backend().on('DELETE /businesses/$gymId/follow', ok({'is_following': false}));
      expect(await ctx.api().setFollowingBusiness(token, gymId, follow: true), isTrue);
      expect(describe(backend().requests.last), 'PUT /businesses/$gymId/follow');
      expect(await ctx.api().setFollowingBusiness(token, gymId, follow: false), isFalse);
      expect(describe(backend().requests.last), 'DELETE /businesses/$gymId/follow');
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

  group('review', () {
    test('getBusinessReviewQueue asks for a status and parses the applicant', () async {
      backend().on('GET /businesses/review', ok([
        {
          ...shopJson,
          'applicant_id': liamId,
          'applicant_name': 'Liam',
          'applicant_last_name': "O'Connor",
          'applicant_username': 'liamoconnor',
          'applicant_email': 'liam.oconnor@example.com',
          'applicant_avatar_url': null,
          'created_at': '2026-10-28T10:00:00.000Z',
          'reviewed_at': null,
        },
      ]));
      final queue = await ctx.api().getBusinessReviewQueue(token, status: BusinessStatus.rejected);
      expectGet(backend().only, '/businesses/review', {'status': 'rejected'});
      final a = queue.single;
      expect(a.business.id, shopId);
      expect(a.business.status, BusinessStatus.pending);
      expect(a.applicantName, "Liam O'Connor");
      expect(a.applicantUsername, 'liamoconnor');
      expect(a.applicantEmail, 'liam.oconnor@example.com');
      expect(a.createdAt, DateTime.utc(2026, 10, 28, 10));
      expect(a.reviewedAt, isNull);
    });

    test('reviewBusiness sends the status, and a note only when given', () async {
      backend().on('POST /businesses/$shopId/review', ok({...shopJson, 'status': 'approved'}));
      final b = await ctx.api().reviewBusiness(token, shopId, status: BusinessStatus.approved);
      expectJson(backend().only, 'POST', '/businesses/$shopId/review', {'status': 'approved'});
      expect(b.status, BusinessStatus.approved);

      backend().on('POST /businesses/$shopId/review', ok({...shopJson, 'status': 'rejected', 'review_note': 'Add an address'}));
      final r = await ctx.api().reviewBusiness(token, shopId, status: BusinessStatus.rejected, note: 'Add an address');
      expect(bodyOf(backend().requests.last), {'status': 'rejected', 'note': 'Add an address'});
      expect(r.reviewNote, 'Add an address');
    });

    test('resubmitBusiness POSTs /businesses/:id/resubmit', () async {
      backend().on('POST /businesses/$shopId/resubmit', ok(shopJson));
      final b = await ctx.api().resubmitBusiness(token, shopId);
      expect(describe(backend().only), 'POST /businesses/$shopId/resubmit');
      expect(b.status, BusinessStatus.pending);
    });
  });

  group('team', () {
    test('getBusinessTeam parses held roles and open invites', () async {
      backend().on('GET /businesses/$gymId/team', ok([
        {
          'user_id': 'u-marcus',
          'username': 'marcusbennett',
          'name': 'Marcus',
          'last_name': 'Bennett',
          'email': 'marcus@example.com',
          'avatar_url': null,
          'roles': [
            {'role': 'owner', 'status': 'active'},
            {'role': 'trainer', 'status': 'invited'},
            {'role': 'employee', 'status': 'active'},
          ],
        },
        {'user_id': 'u-elena', 'name': 'Elena', 'last_name': 'Vasquez', 'roles': [{'role': 'trainer', 'status': 'active'}]},
      ]));
      final team = await ctx.api().getBusinessTeam(token, gymId);
      expectGet(backend().only, '/businesses/$gymId/team');
      final marcus = team[0];
      expect(marcus.fullName, 'Marcus Bennett');
      expect(marcus.email, 'marcus@example.com');
      expect(marcus.roles, hasLength(2), reason: 'unknown roles are skipped');
      expect(marcus.holds(BusinessRole.owner), isTrue);
      expect(marcus.holds(BusinessRole.trainer), isFalse);
      expect(marcus.invitedAs(BusinessRole.trainer), isTrue);
      expect(team[1].username, '');
      expect(team[1].email, isNull, reason: 'emails only for owners and staff');
      expect(team[1].holds(BusinessRole.trainer), isTrue);
    });

    test('inviteToTeam sends the role and only the given person fields', () async {
      backend().on('POST /businesses/$gymId/team', ok({'ok': true}, 201));
      await ctx.api().inviteToTeam(token, gymId, role: BusinessRole.staff, userId: liamId);
      expectJson(backend().only, 'POST', '/businesses/$gymId/team', {'role': 'staff', 'user_id': liamId});

      await ctx.api().inviteToTeam(
        token,
        gymId,
        role: BusinessRole.trainer,
        email: 'new.coach@example.com',
        name: 'Nora',
        lastName: 'Lindqvist',
        username: 'noralindqvist',
      );
      expect(bodyOf(backend().requests.last), {
        'role': 'trainer',
        'email': 'new.coach@example.com',
        'name': 'Nora',
        'last_name': 'Lindqvist',
        'username': 'noralindqvist',
      });
    });

    test('removeFromTeam DELETEs one role or all of them', () async {
      backend().on('DELETE /businesses/$gymId/team/$liamId', ok('', 204));
      await ctx.api().removeFromTeam(token, gymId, liamId, role: BusinessRole.trainer);
      final r = backend().only;
      expect(r.method, 'DELETE');
      expect(r.url.queryParameters, {'role': 'trainer'});

      await ctx.api().removeFromTeam(token, gymId, liamId);
      expectDelete(backend().requests.last, '/businesses/$gymId/team/$liamId');
    });

    test('getMyBusinessInvites parses the business, role and inviter', () async {
      backend().on('GET /businesses/invites', ok([
        {
          'business_id': gymId,
          'business_name': 'Ironclad Fitness',
          'logo': null,
          'has_gym': true,
          'has_shop': false,
          'role': 'trainer',
          'inviter_name': 'Marcus',
          'inviter_last_name': 'Bennett',
          'created_at': '2026-10-30T08:15:00.000Z',
        },
        {'business_id': shopId, 'role': 'staff', 'created_at': '2026-10-29T08:15:00.000Z'},
      ]));
      final invites = await ctx.api().getMyBusinessInvites(token);
      expectGet(backend().only, '/businesses/invites');
      expect(invites[0].businessName, 'Ironclad Fitness');
      expect(invites[0].hasGym, isTrue);
      expect(invites[0].role, BusinessRole.trainer);
      expect(invites[0].inviterName, 'Marcus Bennett');
      expect(invites[0].createdAt, DateTime.utc(2026, 10, 30, 8, 15));
      expect(invites[1].role, BusinessRole.staff);
      expect(invites[1].inviterName, isNull);
    });

    test('answerBusinessInvite POSTs accept or decline for the role', () async {
      backend().on('POST /businesses/$gymId/invites/trainer/accept', ok({'ok': true}));
      backend().on('POST /businesses/$gymId/invites/staff/decline', ok({'ok': true}));
      await ctx.api().answerBusinessInvite(token, gymId, BusinessRole.trainer, accept: true);
      expect(describe(backend().requests.last), 'POST /businesses/$gymId/invites/trainer/accept');
      await ctx.api().answerBusinessInvite(token, gymId, BusinessRole.staff, accept: false);
      expect(describe(backend().requests.last), 'POST /businesses/$gymId/invites/staff/decline');
    });
  });

  group('me', () {
    final meJson = {
      ...liamJson,
      'is_trainer': true,
      'pending_invites': 2,
      'businesses': [
        {'id': gymId, 'name': 'Ironclad Fitness', 'logo': null, 'has_gym': true, 'has_shop': true, 'status': 'approved', 'review_note': null, 'roles': ['owner', 'staff']},
        {'id': 'b-trainer', 'name': 'Harbor Boxing', 'has_gym': true, 'has_shop': false, 'status': 'approved', 'roles': ['trainer']},
        {'id': shopId, 'name': 'Peak Performance Supply Co.', 'has_gym': false, 'has_shop': true, 'status': 'approved', 'roles': ['staff']},
        {'id': 'b-new', 'name': 'New Gym', 'has_gym': true, 'has_shop': false, 'status': 'pending', 'roles': ['owner']},
      ],
    };

    test('getMe parses my businesses, roles and invite count', () async {
      backend().on('GET /users/me', ok(meJson));
      final me = await ctx.api().getMe(token);
      expectGet(backend().only, '/users/me');
      expect(me.isTrainer, isTrue);
      expect(me.isSuperUser, isFalse);
      expect(me.pendingInvites, 2);
      expect(me.businesses, hasLength(4));
      expect(me.businesses.first.roles, [BusinessRole.owner, BusinessRole.staff]);
      expect(me.businesses.last.status, BusinessStatus.pending);
      // Only approved businesses count; gyms only for gym work.
      expect(me.workGyms.map((b) => b.id), [gymId, 'b-trainer']);
      expect(me.staffedGyms.map((b) => b.id), [gymId]);
      expect(me.businessesAs(BusinessRole.owner).map((b) => b.id), [gymId]);
      expect(me.businessesAs(BusinessRole.staff).map((b) => b.id), [gymId, shopId]);
      expect(me.worksAnywhere, isTrue);
    });

    test('setTrainer PUTs the switch and returns my profile', () async {
      backend().on('PUT /users/me/trainer', ok({...liamJson, 'is_trainer': false}));
      final me = await ctx.api().setTrainer(token, enabled: false);
      expectJson(backend().only, 'PUT', '/users/me/trainer', {'enabled': false});
      expect(me.isTrainer, isFalse);
    });
  });

  group('users', () {
    test('getUsers parses profiles (admin and trainer flags, nullable avatar)', () async {
      backend().on('GET /users', ok([
        liamJson,
        {
          'id': 'u-et',
          'username': 'aishamohammed',
          'email': 'aisha.mohammed@example.com',
          'name': 'Aisha',
          'last_name': 'Mohammed',
          'is_trainer': true,
          'avatar_url': null,
        },
        {'id': 'u-su', 'username': 'chloe', 'name': 'Chloe', 'last_name': 'Anderson', 'is_super_user': true},
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
      expect((liam.isSuperUser, liam.isTrainer), (false, false));
      expect(liam.avatarUrl, startsWith('https://api.dicebear.com/'));
      expect(users[1].isTrainer, isTrue);
      expect(users[1].avatarUrl, isNull);
      expect(users[2].isSuperUser, isTrue);
      expect(users[2].isTrainer, isFalse, reason: 'absent flags default to false');
      expect(users[2].email, '', reason: 'email is omitted for other users');
    });

    test('searchUsers encodes the query and parses member and team entries', () async {
      backend().on('GET /search-users', ok([
        {
          'id': liamId,
          'username': 'liamoconnor',
          'email': 'liam.oconnor@example.com',
          'name': 'Liam',
          'last_name': "O'Connor",
          'is_trainer': true,
          'member_entries': [
            {'id': '077bbb0f-ca49-4558-96e9-dc176b9811d5', 'gym_id': gymId},
          ],
          'team_entries': [
            {'business_id': gymId, 'role': 'trainer', 'status': 'active'},
            {'business_id': shopId, 'role': 'staff', 'status': 'invited'},
            {'business_id': shopId, 'role': 'vendor', 'status': 'active'},
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
      expect(u.isTrainer, isTrue);
      expect(u.memberEntries.map((e) => (e.id, e.gymId)), [('077bbb0f-ca49-4558-96e9-dc176b9811d5', gymId)]);
      expect(u.teamEntries.map((e) => (e.businessId, e.role, e.isActive)), [
        (gymId, BusinessRole.trainer, true),
        (shopId, BusinessRole.staff, false),
      ], reason: 'unknown roles are skipped');
      expect(u.holds(BusinessRole.trainer), isTrue);
      expect(u.holds(BusinessRole.staff), isFalse, reason: 'only invited');
    });

    test('searchUsers tolerates rows without entries', () async {
      backend().on('GET /search-users', ok([
        {'id': liamId, 'username': 'liamoconnor', 'email': 'liam.oconnor@example.com', 'name': 'Liam', 'last_name': "O'Connor"},
      ]));
      final u = (await ctx.api().searchUsers(token)).single;
      expect(u.isTrainer, isFalse);
      expect(u.memberEntries, isEmpty);
      expect(u.teamEntries, isEmpty);
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
        'user': liamJson,
      }, 201));
      final u = await ctx.api().createUser(
        token,
        email: 'liam.oconnor@example.com',
        password: 'hunter22',
        username: 'liamoconnor',
        name: 'Liam',
        lastName: "O'Connor",
      );
      expectJson(backend().only, 'POST', '/users/signup', {
        'email': 'liam.oconnor@example.com',
        'password': 'hunter22',
        'username': 'liamoconnor',
        'name': 'Liam',
        'last_name': "O'Connor",
      });
      expect(u.isSuperUser, isFalse);
      expect(u.id, liamId);
    });

    test('updateUser sends is_super_user (super users only)', () async {
      backend().on('PUT /users/$liamId', ok({...liamJson, 'is_super_user': true}));
      final u = await ctx.api().updateUser(token, liamId, {'is_super_user': true});
      expectJson(backend().only, 'PUT', '/users/$liamId', {'is_super_user': true});
      expect(u.isSuperUser, isTrue);
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
    'searchBusinesses': ('GET /businesses/search', (api) => api.searchBusinesses(token, query: 'iron')),
    'getBusiness': ('GET /businesses/$gymId', (api) => api.getBusiness(token, gymId)),
    'createBusiness': ('POST /businesses', (api) => api.createBusiness(token, {'name': 'x'})),
    'updateBusiness': ('PUT /businesses/$gymId', (api) => api.updateBusiness(token, gymId, {'name': 'x'})),
    'deleteBusiness': ('DELETE /businesses/$gymId', (api) => api.deleteBusiness(token, gymId)),
    'setFollowingBusiness': ('PUT /businesses/$gymId/follow', (api) => api.setFollowingBusiness(token, gymId, follow: true)),
    'getBusinessReviewQueue': ('GET /businesses/review', (api) => api.getBusinessReviewQueue(token)),
    'reviewBusiness': (
      'POST /businesses/$gymId/review',
      (api) => api.reviewBusiness(token, gymId, status: BusinessStatus.blocked, note: 'x'),
    ),
    'resubmitBusiness': ('POST /businesses/$gymId/resubmit', (api) => api.resubmitBusiness(token, gymId)),
    'getBusinessTeam': ('GET /businesses/$gymId/team', (api) => api.getBusinessTeam(token, gymId)),
    'inviteToTeam': ('POST /businesses/$gymId/team', (api) => api.inviteToTeam(token, gymId, role: BusinessRole.staff, userId: 'u')),
    'removeFromTeam': ('DELETE /businesses/$gymId/team/u', (api) => api.removeFromTeam(token, gymId, 'u')),
    'getMyBusinessInvites': ('GET /businesses/invites', (api) => api.getMyBusinessInvites(token)),
    'answerBusinessInvite': (
      'POST /businesses/$gymId/invites/staff/accept',
      (api) => api.answerBusinessInvite(token, gymId, BusinessRole.staff, accept: true),
    ),
    'getMe': ('GET /users/me', (api) => api.getMe(token)),
    'setTrainer': ('PUT /users/me/trainer', (api) => api.setTrainer(token, enabled: true)),
    'getBusinessStats': ('GET /businesses/stats', (api) => api.getBusinessStats(token)),
    'getUsers': ('GET /users', (api) => api.getUsers(token)),
    'searchUsers': ('GET /search-users', (api) => api.searchUsers(token, query: 'li')),
    'getUserByEmail': ('GET /users', (api) => api.getUserByEmail(token, 'a@b.c')),
    'getUser': ('GET /users/$liamId', (api) => api.getUser(token, liamId)),
    'createUser': ('POST /users/signup', (api) => api.createUser(token, email: 'a@b.c', password: 'p', username: 'u', name: 'n', lastName: 'l'),
    ),
    'updateUser': ('PUT /users/$liamId', (api) => api.updateUser(token, liamId, {'name': 'x'})),
    'changePassword': ('POST /users/change-password', (api) => api.changePassword(token, currentPassword: 'a', newPassword: 'b')),
    'deleteUser': ('DELETE /users/$liamId', (api) => api.deleteUser(token, liamId)),
    'resendInvite': ('POST /users/resend-invite', (api) => api.resendInvite(token, 'a@b.c')),
    'uploadImage': ('POST /uploads', (api) => api.uploadImage(token, bytes: [1], filename: 'a.png', bucket: 'media')),
  });
}
