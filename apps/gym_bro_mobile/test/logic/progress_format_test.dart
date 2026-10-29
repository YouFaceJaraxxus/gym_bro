import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/pages/progress/progress_format.dart';
import 'package:gym_bro_mobile/services/settings_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  final settings = SettingsService.instance;
  final en = lookupAppLocalizations(const Locale('en'));
  final sr = lookupAppLocalizations(const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'));

  setUpAll(() => initializeDateFormatting());
  tearDown(() => settings.weightUnit.value = 'kg');

  group('formatVolume', () {
    test('kilograms: rounded, grouped in the locale', () {
      expect(formatVolume(7758.4, 'en'), '7,758 kg');
      expect(formatVolume(7758.6, 'en'), '7,759 kg');
      expect(formatVolume(0, 'en'), '0 kg');
      expect(formatVolume(99999.4, 'en'), '99,999 kg');
      expect(formatVolume(7758, 'sr_Latn'), '7.758 kg');
    });

    test('100 000 and up is compact', () {
      expect(formatVolume(100000, 'en'), '100K kg');
      expect(formatVolume(1200000, 'en'), '1.2M kg');
      expect(formatVolume(1234567, 'en'), '1.23M kg');
    });

    test('pounds convert before formatting (and before the compact threshold)', () {
      settings.weightUnit.value = 'lb';
      expect(formatVolume(7758, 'en'), '17,103 lb'); // 7758 × 2.2046226 = 17103.46 → 17,103
      expect(formatVolume(100, 'en'), '220 lb');
      // 50 000 kg is 110 231 lb: compact in pounds.
      expect(formatVolume(50000, 'en'), '110K lb');
    });
  });

  group('muscleLabels', () {
    test('maps API values to localized names, keeps unknown values as-is', () {
      expect(muscleLabels(['hamstrings', 'glutes_maximus'], en), 'Hamstrings, Glute Maximus');
      expect(muscleLabels(['chest_upper', 'tibialis'], sr), 'Gornje grudi, tibialis');
      expect(muscleLabels(const [], en), '');
    });
  });

  group('relativeDay', () {
    final now = DateTime.now();
    DateTime daysAgo(int n, {int hour = 12}) => DateTime(now.year, now.month, now.day - n, hour);

    test('today and yesterday by calendar day, not 24 h', () {
      expect(relativeDay(DateTime(now.year, now.month, now.day, 0, 1), en, 'en'), 'Today');
      expect(relativeDay(daysAgo(1, hour: 23), en, 'en'), 'Yesterday');
      expect(relativeDay(daysAgo(1, hour: 0), en, 'en'), 'Yesterday');
      expect(relativeDay(daysAgo(1), sr, 'sr_Latn'), sr.trainingProgressYesterday);
    });

    test('within a week → weekday name; older → date', () {
      final d3 = daysAgo(3);
      expect(relativeDay(d3, en, 'en'), DateFormat.EEEE('en').format(d3));
      final d6 = daysAgo(6);
      expect(relativeDay(d6, en, 'en'), DateFormat.EEEE('en').format(d6));
      final d7 = daysAgo(7);
      expect(relativeDay(d7, en, 'en'), DateFormat.yMMMd('en').format(d7));
      expect(relativeDay(DateTime(2025, 10, 6, 9), en, 'en'), 'Oct 6, 2025');
    });

    test('UTC timestamps from the API are compared in local time', () {
      final localNoon = DateTime(now.year, now.month, now.day, 12);
      expect(relativeDay(localNoon.toUtc(), en, 'en'), 'Today');
    });
  });
}
