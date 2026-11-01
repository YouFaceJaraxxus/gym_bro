import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/user_profile.dart';

import '../helpers/fake_backend.dart';
import 'api_test_utils.dart';

// Gym member rows (GET /members) trimmed from the local stack. These methods
// return the raw rows; screens map them with UserProfile.fromRoleRow, so the
// tests check that too. Team roles (owner/staff/trainer) live under
// /businesses/:id/team: see businesses_users_api_test.dart.
const gymId = 'ff453a60-28ca-4cdd-a919-c6ecd344ab65';
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
};

void main() {
  final ctx = useFakeBackend();
  FakeBackend backend() => ctx.backend();

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
      expect(p.isSuperUser, isFalse);
      expect(p.businesses, isEmpty);
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

  errorTests(ctx, {
    'getMembers': ('GET /members', (api) => api.getMembers(token, gymId: gymId)),
    'addMember': ('POST /members', (api) => api.addMember(token, userId, gymId)),
    'inviteMember': (
      'POST /members',
      (api) => api.inviteMember(token, email: 'a@b.c', name: 'n', lastName: 'l', username: 'u', gymId: gymId),
    ),
    'removeMember': ('DELETE /members/m-1', (api) => api.removeMember(token, 'm-1')),
  });
}
