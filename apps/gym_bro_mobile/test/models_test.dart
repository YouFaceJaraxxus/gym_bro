import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/membership.dart';
import 'package:gym_bro_mobile/models/shop_item.dart';
import 'package:gym_bro_mobile/models/training_session.dart';

// Postgres `numeric` columns arrive from the API as JSON strings; models must
// accept both strings and numbers.
void main() {
  group('MembershipInvoice', () {
    Map<String, dynamic> invoice(Object amount) => {
          'id': 'inv-1',
          'membership_id': 'm-1',
          'membership_type_id': 'mt-1',
          'issued_at': '2026-10-01T10:00:00.000Z',
          'amount': amount,
          'status': 'paid',
          'paid_at': '2026-10-02T09:30:00.000Z',
          'user_id': 'u-1',
          'member_name': 'Liam',
          'member_last_name': "O'Connor",
          'gym_name': 'Ironclad Fitness',
        };

    test('parses numeric strings', () {
      final inv = MembershipInvoice.fromJson(invoice('49.90'));
      expect(inv.amount, 49.90);
      expect(inv.status, InvoiceStatus.paid);
      expect(inv.paidAt, DateTime.utc(2026, 10, 2, 9, 30));
      expect(inv.memberFullName, "Liam O'Connor");
    });

    test('parses plain numbers', () {
      expect(MembershipInvoice.fromJson(invoice(50)).amount, 50.0);
      expect(MembershipInvoice.fromJson(invoice(12.5)).amount, 12.5);
    });

    test('GymMembershipType parses monthly_cost strings', () {
      final t = GymMembershipType.fromJson({
        'id': 'mt-1',
        'gym_id': 'g-1',
        'name': 'Monthly',
        'monthly_cost': '39.00',
      });
      expect(t.monthlyCost, 39.0);
    });
  });

  group('ShopItem', () {
    Map<String, dynamic> item(Object price) => {
          'id': 'si-1',
          'shop_id': 'shop-1',
          'type': 'supplement',
          'name': 'Whey 1kg',
          'price': price,
          'quantity': 12,
          'is_active': true,
          'active_until': null,
        };

    test('parses numeric strings', () {
      final i = ShopItem.fromJson(item('29.99'));
      expect(i.price, 29.99);
      expect(i.type, ShopItemType.supplement);
      expect(i.quantity, 12);
    });

    test('parses plain numbers', () {
      expect(ShopItem.fromJson(item(30)).price, 30.0);
    });
  });

  group('TrainingSession', () {
    Map<String, dynamic> session(Object? weight) => {
          'id': 's-1',
          'user_id': 'u-1',
          'started_at': '2026-10-01T18:00:00.000Z',
          'ended_at': '2026-10-01T19:05:30.000Z',
          'created_at': '2026-10-01T18:00:00.000Z',
          'updated_at': '2026-10-01T19:05:30.000Z',
          'set_logs': [
            {
              'id': 'sl-1',
              'session_id': 's-1',
              'exercise_id': 'ex-1',
              'position': 0,
              'drop_logs': [
                {
                  'id': 'dl-1',
                  'session_set_log_id': 'sl-1',
                  'drop_number': 1,
                  'rep_type_actual': 'count',
                  'rep_count_actual': 8,
                  'weight_kg_actual': weight,
                  'side': 'both',
                },
              ],
            },
          ],
        };

    test('parses weight_kg_actual from a numeric string', () {
      final s = TrainingSession.fromJson(session('62.50'));
      final drop = s.setLogs.single.dropLogs.single;
      expect(drop.weightKgActual, 62.5);
      expect(drop.repCountActual, 8);
      expect(s.isActive, isFalse);
      expect(s.duration, const Duration(hours: 1, minutes: 5, seconds: 30));
    });

    test('parses numbers and nulls', () {
      expect(TrainingSession.fromJson(session(60)).setLogs.single.dropLogs.single.weightKgActual, 60.0);
      expect(TrainingSession.fromJson(session(null)).setLogs.single.dropLogs.single.weightKgActual, isNull);
    });
  });
}
