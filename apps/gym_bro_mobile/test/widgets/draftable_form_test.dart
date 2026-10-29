import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/draft.dart';
import 'package:gym_bro_mobile/widgets/drafts.dart';

class _Form extends StatefulWidget {
  const _Form({this.editing = false});

  final bool editing;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> with DraftableForm {
  final name = TextEditingController();

  @override
  DraftKind get draftKind => DraftKind.exercise;
  @override
  Draft? get initialDraft => null;
  @override
  bool get draftsEnabled => !widget.editing;
  @override
  bool get hasDraftContent => name.text.trim().isNotEmpty;
  @override
  Map<String, dynamic> draftData() => {'name': name.text};
  @override
  String? draftTitle() => name.text;

  @override
  Widget build(BuildContext context) => draftPopScope(
    child: Scaffold(appBar: AppBar(), body: TextField(controller: name)),
  );
}

Future<void> _open(WidgetTester tester, {bool editing = false}) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _Form(editing: editing))),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('leaving an empty form just closes it', (tester) async {
    await _open(tester);
    await _back(tester);
    expect(find.byType(_Form), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('leaving with content offers a draft; keep editing stays, discard leaves', (tester) async {
    await _open(tester);
    await tester.enterText(find.byType(TextField), 'Squat');
    await _back(tester);
    expect(find.text('Save as a draft?'), findsOneWidget);
    expect(find.text('Save draft'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(_Form), findsOneWidget);

    await _back(tester);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(_Form), findsNothing);
  });

  testWidgets('editing something that exists never offers a draft', (tester) async {
    await _open(tester, editing: true);
    await tester.enterText(find.byType(TextField), 'Squat');
    await _back(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(_Form), findsNothing);
  });
}
