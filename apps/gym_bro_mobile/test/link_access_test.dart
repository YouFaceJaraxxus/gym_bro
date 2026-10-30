import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/link_access.dart';
import 'package:gym_bro_mobile/models/plan_entry.dart';
import 'package:gym_bro_mobile/models/post.dart';
import 'package:gym_bro_mobile/widgets/link_access_note.dart';

Map<String, dynamic> _entry([Map<String, dynamic> extra = const {}]) => {
  'id': 'e1',
  'user_id': 'u1',
  'kind': 'workout',
  'status': 'done',
  'starts_at': '2026-10-28T10:30:00.000Z',
  'ends_at': '2026-10-28T11:30:00.000Z',
  'duration_minutes': '60',
  'plan_date': '2026-10-28',
  'routine_id': null,
  'routine_name': 'Deadlift Focus Block',
  'training_id': 't1',
  'training_name': 'Pull Day A',
  ...extra,
};

Map<String, dynamic> _post([Map<String, dynamic> extra = const {}]) => {
  'id': 'p1',
  'author_id': 'u2',
  'content': '',
  'images': [],
  'created_at': '2026-10-30T08:00:00.000Z',
  'updated_at': '2026-10-30T08:00:00.000Z',
  'post_type': 'routine',
  'ref_id': 'r1',
  'attachment': {'title': 'Coach Block'},
  ...extra,
};

void main() {
  test('LinkAccess parses the API values and nothing else', () {
    expect(LinkAccess.tryParse('ok'), LinkAccess.ok);
    expect(LinkAccess.tryParse('private'), LinkAccess.private);
    expect(LinkAccess.tryParse('unavailable'), LinkAccess.unavailable);
    expect(LinkAccess.tryParse(null), isNull);
    expect(LinkAccess.tryParse('expired'), isNull);
    expect(LinkAccess.ok.canOpen, isTrue);
    expect(LinkAccess.private.canOpen, isFalse);
  });

  group('PlanEntry history', () {
    test('a left enrolment keeps names, with status, date and access', () {
      final e = PlanEntry.fromJson(_entry({
        'source_status': 'left',
        'left_at': '2026-10-29T18:00:00.000Z',
        'source_access': 'private',
        'training_access': 'ok',
      }));
      expect(e.sourceStatus, PlanSourceStatus.left);
      expect(e.leftAt, DateTime.parse('2026-10-29T18:00:00.000Z').toLocal());
      expect(e.sourceAccess, LinkAccess.private);
      expect(e.trainingAccess, LinkAccess.ok);
      expect(e.routineName, 'Deadlift Focus Block');
      expect(e.routineId, isNull);
    });

    test('removed / deleted / ended map; rows without the fields are active', () {
      expect(PlanEntry.fromJson(_entry({'source_status': 'removed'})).sourceStatus, PlanSourceStatus.removed);
      expect(PlanEntry.fromJson(_entry({'source_status': 'deleted'})).sourceStatus, PlanSourceStatus.deleted);
      expect(PlanEntry.fromJson(_entry({'source_status': 'ended'})).sourceStatus, PlanSourceStatus.ended);
      final old = PlanEntry.fromJson(_entry());
      expect(old.sourceStatus, PlanSourceStatus.active);
      expect(old.leftAt, isNull);
      expect(old.sourceAccess, isNull);
    });
  });

  test('Post.refAccess comes from ref_access and survives copyWith', () {
    final p = Post.fromJson(_post({'ref_access': 'private'}));
    expect(p.refAccess, LinkAccess.private);
    expect(p.copyWith(commentCount: 3).refAccess, LinkAccess.private);
    expect(Post.fromJson(_post()).refAccess, isNull);
  });

  group('LinkAccessNote', () {
    Future<void> pump(WidgetTester tester, LinkAccess? access) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LinkAccessNote(access: access)),
      ),
    );

    testWidgets('says why a link no longer opens', (tester) async {
      await pump(tester, LinkAccess.private);
      expect(find.textContaining("don't have access"), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      await pump(tester, LinkAccess.unavailable);
      expect(find.textContaining('deleted'), findsOneWidget);
      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    testWidgets('shows nothing when the link opens', (tester) async {
      await pump(tester, LinkAccess.ok);
      expect(find.byType(Text), findsNothing);
      await pump(tester, null);
      expect(find.byType(Text), findsNothing);
    });
  });
}
