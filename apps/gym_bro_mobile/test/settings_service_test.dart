import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/services/settings_service.dart';

void main() {
  final settings = SettingsService.instance;

  tearDown(() => settings.weightUnit.value = 'kg');

  test('kg is the identity', () {
    settings.weightUnit.value = 'kg';
    expect(settings.toDisplayWeight(62.5), 62.5);
    expect(settings.fromDisplayWeight(62.5), 62.5);
    expect(settings.formatWeight(62.5), '62.5 kg');
    expect(settings.formatWeight(100), '100 kg');
  });

  test('converts kilograms to pounds and back', () {
    settings.weightUnit.value = 'lb';
    expect(settings.toDisplayWeight(100), closeTo(220.462, 0.001));
    expect(settings.fromDisplayWeight(220.46226218), closeTo(100, 1e-6));
    expect(settings.fromDisplayWeight(settings.toDisplayWeight(42.5)), closeTo(42.5, 1e-9));
  });

  test('formats pounds with one decimal and drops whole-number decimals', () {
    settings.weightUnit.value = 'lb';
    expect(settings.formatWeight(62.5), '137.8 lb');
    expect(settings.formatWeight(0), '0 lb');
  });
}
