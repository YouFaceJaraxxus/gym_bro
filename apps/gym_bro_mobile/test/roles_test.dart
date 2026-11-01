import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/business.dart';
import 'package:gym_bro_mobile/models/user_profile.dart';
import 'package:gym_bro_mobile/widgets/plan_enrolment.dart';

// What someone may do comes from their flags and their businesses' roles
// (no single user role any more). These back the coach tools, invoices and
// the gym member pickers.

MyBusiness _biz(
  String id, {
  bool gym = true,
  bool shop = false,
  BusinessStatus status = BusinessStatus.approved,
  List<BusinessRole> roles = const [BusinessRole.owner],
}) => MyBusiness(id: id, name: id, hasGym: gym, hasShop: shop, status: status, roles: roles);

UserProfile _me({bool superUser = false, bool trainer = false, List<MyBusiness> businesses = const []}) =>
    UserProfile(
      id: 'u-me',
      username: 'me',
      email: 'me@example.com',
      name: 'Me',
      lastName: 'Myself',
      isSuperUser: superUser,
      isTrainer: trainer,
      businesses: businesses,
    );

void main() {
  group('canCoach', () {
    test('nobody signed in, or a plain member → no', () {
      expect(canCoach(null), isFalse);
      expect(canCoach(_me()), isFalse);
    });

    test('super users and trainers (even without a gym) → yes', () {
      expect(canCoach(_me(superUser: true)), isTrue);
      expect(canCoach(_me(trainer: true)), isTrue);
    });

    test('anyone on the team of an approved gym → yes', () {
      for (final role in BusinessRole.values) {
        expect(canCoach(_me(businesses: [_biz('g', roles: [role])])), isTrue, reason: role.name);
      }
    });

    test('a shop-only business, or a gym not approved yet → no', () {
      expect(canCoach(_me(businesses: [_biz('s', gym: false, shop: true)])), isFalse);
      for (final status in [BusinessStatus.pending, BusinessStatus.rejected, BusinessStatus.blocked]) {
        expect(canCoach(_me(businesses: [_biz('g', status: status)])), isFalse, reason: status.name);
      }
    });
  });

  group('UserProfile', () {
    test('toJson round-trips flags and businesses (the stored profile)', () {
      final me = _me(
        superUser: true,
        trainer: true,
        businesses: [
          _biz('g-1', shop: true, roles: [BusinessRole.owner, BusinessRole.trainer]),
          _biz('s-1', gym: false, shop: true, status: BusinessStatus.pending, roles: [BusinessRole.staff]),
        ],
      );
      final back = UserProfile.fromJson(me.toJson());
      expect((back.isSuperUser, back.isTrainer), (true, true));
      expect(back.businesses.map((b) => (b.id, b.hasGym, b.hasShop, b.status)), [
        ('g-1', true, true, BusinessStatus.approved),
        ('s-1', false, true, BusinessStatus.pending),
      ]);
      expect(back.businesses.map((b) => b.roles), [
        [BusinessRole.owner, BusinessRole.trainer],
        [BusinessRole.staff],
      ]);
    });

    test('a profile stored before the role change (has `role`, no flags) loads as a plain member', () {
      final old = UserProfile.fromJson({
        'id': 'u-1',
        'username': 'liam',
        'email': 'liam@example.com',
        'name': 'Liam',
        'last_name': "O'Connor",
        'role': 'owner',
      });
      expect((old.isSuperUser, old.isTrainer), (false, false));
      expect(old.businesses, isEmpty);
      expect(old.worksAnywhere, isFalse);
    });

    test('staffedGyms: owner or staff at an approved gym; trainers only in workGyms', () {
      final me = _me(businesses: [
        _biz('own'),
        _biz('desk', roles: [BusinessRole.staff]),
        _biz('coach', roles: [BusinessRole.trainer]),
        _biz('shop', gym: false, shop: true, roles: [BusinessRole.staff]),
      ]);
      expect(me.workGyms.map((b) => b.id), ['own', 'desk', 'coach']);
      expect(me.staffedGyms.map((b) => b.id), ['own', 'desk']);
    });
  });
}
