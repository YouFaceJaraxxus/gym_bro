import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/check_in.dart';

Map<String, dynamic> _result({
  bool duplicate = false,
  Map<String, dynamic>? membership,
  String? warning,
}) =>
    {
      'check_in': {
        'id': 'c1',
        'gym_id': 'g1',
        'user_id': 'u1',
        'checked_in_at': '2026-10-13T07:08:15.923Z',
        'checked_in_by': 's1',
        'method': 'qr',
      },
      'duplicate': duplicate,
      'member': {'id': 'u1', 'name': 'Liam', 'last_name': "O'Connor", 'avatar_url': null},
      'membership': membership,
      'warning': warning,
    };

void main() {
  group('CheckInResult.outcome', () {
    const active = {'is_active': true, 'to_date': '2026-11-15', 'type_name': 'Basic'};
    const expired = {'is_active': false, 'to_date': '2026-01-15', 'type_name': 'Basic'};

    test('active membership → checked in', () {
      final r = CheckInResult.fromJson(_result(membership: active));
      expect(r.outcome, CheckInOutcome.checkedIn);
      expect(r.member.fullName, "Liam O'Connor");
      expect(r.member.initials, 'LO');
      expect(r.membership!.toDate, '2026-11-15');
    });

    test('expired or missing membership → warning', () {
      expect(
        CheckInResult.fromJson(_result(membership: expired, warning: 'no_active_membership')).outcome,
        CheckInOutcome.noActiveMembership,
      );
      expect(
        CheckInResult.fromJson(_result(warning: 'no_active_membership')).outcome,
        CheckInOutcome.noActiveMembership,
      );
    });

    test('duplicate wins over the membership warning', () {
      final r = CheckInResult.fromJson(
          _result(duplicate: true, membership: expired, warning: 'no_active_membership'));
      expect(r.outcome, CheckInOutcome.duplicate);
    });
  });

  group('CheckInToken', () {
    final t = CheckInToken.fromJson({
      'token': 'a.b',
      'expires_at': '2026-10-13T07:13:15.000Z',
      'ttl_seconds': 300,
      'gym_id': 'g1',
      'gym_name': 'Ironclad',
    });
    final exp = DateTime.utc(2026, 10, 13, 7, 13, 15);

    test('remaining never goes negative', () {
      expect(t.remaining(exp.add(const Duration(minutes: 1))), Duration.zero);
      expect(t.remaining(exp.subtract(const Duration(seconds: 90))), const Duration(seconds: 90));
    });

    test('refreshes shortly before expiry', () {
      expect(t.shouldRefresh(exp.subtract(const Duration(minutes: 2))), isFalse);
      expect(t.shouldRefresh(exp.subtract(const Duration(seconds: 10))), isTrue);
      expect(t.shouldRefresh(exp.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('GymAttendanceStats', () {
    final s = GymAttendanceStats.fromJson({
      'days': 3,
      'today': '2',
      'this_week': 5,
      'total': 6,
      'unique_members': 4,
      'per_day': [
        {'date': '2026-10-11', 'count': 1},
        {'date': '2026-10-12', 'count': 3},
        {'date': '2026-10-13', 'count': 2},
      ],
      'busiest_hours': [
        {'hour': 7, 'count': 2},
        {'hour': 18, 'count': 3},
        {'hour': 6, 'count': 2},
        {'hour': 30, 'count': 9},
      ],
      'top_members': [
        {'id': 'u1', 'name': 'A', 'last_name': 'B', 'avatar_url': null, 'visits': 3, 'last_check_in_at': null},
      ],
    });

    test('parses numbers from strings and ignores bad hours', () {
      expect(s.today, 2);
      expect(s.busiestHours.length, 24);
      expect(s.busiestHours[18], 3);
      expect(s.busiestHours.reduce((a, b) => a + b), 7);
      expect(s.topMembers.single.visits, 3);
      expect(s.averagePerDay, 2);
    });

    test('peak hours are busiest first, earlier hour on ties', () {
      expect(s.peakHours(), [18, 6, 7]);
      expect(s.peakHours(1), [18]);
    });
  });

  test('hourRangeLabel wraps midnight', () {
    expect(hourRangeLabel(7), '07:00–08:00');
    expect(hourRangeLabel(23), '23:00–00:00');
  });

  test('niceAxisStep picks round steps', () {
    expect(niceAxisStep(0), 1);
    expect(niceAxisStep(4), 1);
    expect(niceAxisStep(7), 2);
    expect(niceAxisStep(18), 5);
    expect(niceAxisStep(40), 10);
    expect(niceAxisStep(130), 50);
  });

  test('visitsInMonth counts the current calendar month only', () {
    CheckIn at(DateTime t) =>
        CheckIn(id: '${t.millisecondsSinceEpoch}', gymId: 'g', userId: 'u', checkedInAt: t, method: 'qr');
    final now = DateTime(2026, 10, 13);
    final history = [
      at(DateTime(2026, 10, 1, 8)),
      at(DateTime(2026, 10, 12, 18)),
      at(DateTime(2026, 9, 30, 23)),
      at(DateTime(2025, 10, 5)),
    ];
    expect(visitsInMonth(history, now), 2);
  });
}
