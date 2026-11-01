// Challenge wording (monthly titles in the app's language, timing, amounts)
// and which Wrapped slides a year gets.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/challenge.dart';
import 'package:gym_bro_mobile/models/wrapped.dart';
import 'package:gym_bro_mobile/pages/wrapped/wrapped_slides.dart';
import 'package:gym_bro_mobile/widgets/challenge_ring.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../api/wrapped_api_test.dart' show wrappedJson;

final en = lookupAppLocalizations(const Locale('en'));
final sr = lookupAppLocalizations(const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'));

Challenge _c({
  String status = 'active',
  int daysLeft = 5,
  String? autoKey,
  String metric = 'workouts',
  int target = 12,
  String endsOn = '2026-11-30',
}) =>
    Challenge.fromJson({
      'id': 'c',
      'title': 'Server title',
      'metric': metric,
      'target': target,
      'starts_on': '2026-11-01',
      'ends_on': endsOn,
      'auto_key': autoKey,
      'business': null,
      'status': status,
      'days_left': daysLeft,
      'participants': 3,
    });

void main() {
  setUpAll(() => initializeDateFormatting());

  group('challenge titles', () {
    test('monthly ones are worded in the app language', () {
      final c = _c(autoKey: 'monthly:2026-11:workouts');
      expect(c.displayTitle(en), 'November Grind: 12 workouts');
      expect(c.displayTitle(sr), 'Novembar grind: 12 treninga');
      final d = _c(autoKey: 'monthly:2026-11:active_days', metric: 'active_days', target: 20);
      expect(d.displayTitle(en), 'Active November: 20 days');
      expect(challengeDescription(en, d), 'Train on 20 different days in November.');
    });

    test('others keep their creator\'s title', () {
      expect(_c().displayTitle(en), 'Server title');
      expect(_c(autoKey: 'seed:x').displayTitle(en), 'Server title');
      expect(_c().host(en), 'Gym Bro');
    });
  });

  test('timing', () {
    expect(_c(daysLeft: 5).timing(en), '5 days left');
    expect(_c(daysLeft: 1).timing(en), 'Last day');
    expect(_c(status: 'upcoming', daysLeft: 1).timing(en), 'Starts tomorrow');
    expect(_c(status: 'upcoming', daysLeft: 4).timing(en), 'Starts in 4 days');
    expect(_c(status: 'past', daysLeft: 0).timing(en), 'Ended Nov 30');
    expect(_c(daysLeft: 3).timing(sr), 'Još 3 dana');
  });

  test('amounts and units', () {
    expect(ChallengeMetric.workouts.amount(en, 1), '1 workout');
    expect(ChallengeMetric.activeDays.amount(en, 20), '20 active days');
    expect(ChallengeMetric.minutes.amount(en, 1500), '1,500 min');
    expect(ChallengeMetric.checkIns.amount(sr, 5), '5 dolazaka');
    expect(ChallengeMetric.workouts.rule(en), contains('logged set'));
    expect(ChallengeMetric.checkIns.rule(en, gymName: 'Ironclad'), contains('Ironclad'));
  });

  test('volume comparisons pick something about as heavy', () {
    expect(volumeComparison(en, 63040), "That's about 11 elephants 🐘");
    expect(volumeComparison(en, 4500), "That's about 3 cars 🚗");
    expect(volumeComparison(en, 500), "That's about 1 grand piano 🎹");
    expect(volumeComparison(en, 100), isNull);
  });

  group('Wrapped slides', () {
    Widget summary(BuildContext c, bool calm) => const SizedBox();

    test('a full year gets every slide, the summary last', () {
      final slides = buildWrappedSlides(Wrapped.fromJson(wrappedJson()), summary: summary);
      expect(slides.map((s) => s.id), ['intro', 'workouts', 'volume', 'top', 'prs', 'rhythm', 'gym', 'streak', 'summary']);
      expect(slides.last.isFinal, isTrue);
      expect(slides.where((s) => s.isFinal), hasLength(1));
    });

    test('sections without data are skipped', () {
      final j = wrappedJson()
        ..['gym'] = {'check_ins': 0, 'classes_attended': 0, 'favourite': null}
        ..['prs'] = {'count': 0, 'best_lifts': []}
        ..['streak'] = {'longest': 0}
        ..['badges'] = []
        ..['challenges'] = {'completed': 0, 'items': []};
      final slides = buildWrappedSlides(Wrapped.fromJson(j), summary: summary);
      expect(slides.map((s) => s.id), ['intro', 'workouts', 'volume', 'top', 'rhythm', 'summary']);
    });

    test('an empty year is a short story', () {
      final w = Wrapped.fromJson({'year': 2025, 'available': true, 'totals': {'workouts': 0}});
      final slides = buildWrappedSlides(w, summary: summary);
      expect(slides.map((s) => s.id), ['intro', 'empty']);
      expect(slides.last.isFinal, isTrue);
    });
  });
}
