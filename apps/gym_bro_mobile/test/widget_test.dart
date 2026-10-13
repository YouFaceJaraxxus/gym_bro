import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/services/offline/connectivity_service.dart';
import 'package:gym_bro_mobile/widgets/offline_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ConnectivityService.instance.resetForTest();
  });

  Widget host() => const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Column(children: [OfflineBanner()])),
      );

  testWidgets('OfflineBanner is hidden while online and shown when offline', (tester) async {
    await tester.pumpWidget(host());
    expect(find.textContaining("You're offline"), findsNothing);

    ConnectivityService.instance.reportNetworkFailure();
    await tester.pumpAndSettle();
    expect(find.textContaining("You're offline — showing saved data"), findsOneWidget);

    ConnectivityService.instance.reportNetworkSuccess();
    await tester.pumpAndSettle();
    expect(find.textContaining("You're offline"), findsNothing);
  });
}
