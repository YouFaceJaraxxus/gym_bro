import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/media_editor/editable_media.dart';
import 'package:gym_bro_mobile/media_editor/media_edit.dart';
import 'package:gym_bro_mobile/media_editor/media_editor_page.dart';
import 'package:gym_bro_mobile/services/media_upload.dart';

EditableMedia _photo(String name) => EditableMedia(
  PickedMedia(
    file: File('${Directory.systemTemp.path}/$name.jpg'),
    fileName: '$name.jpg',
    mimeType: 'image/jpeg',
    sizeBytes: 10,
    width: 400,
    height: 300,
  ),
);

/// A host screen with buttons that open the editor for [items].
Future<void> _host(WidgetTester tester, List<EditableMedia> items, {EditHistory? history}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Column(children: [
        TextButton(onPressed: () => MediaEditorPage.edit(context, items.first), child: const Text('edit one')),
        TextButton(onPressed: () => MediaEditorPage.editAll(context, items, history: history), child: const Text('edit all')),
      ]),
    ),
  ));
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _openTool(WidgetTester tester, String name) async {
  await _tap(tester, find.text('Adjust'));
  await _tap(tester, find.bySemanticsLabel(RegExp('^$name')));
}

Future<void> _drag(WidgetTester tester, double dx) async {
  await tester.drag(find.byType(Slider), Offset(dx, 0));
  await tester.pumpAndSettle();
}

IconButton _undo(WidgetTester tester) => tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo));

void main() {
  testWidgets('each adjustment has its own undo and reset; edits survive closing the editor', (tester) async {
    final photo = _photo('a');
    await _host(tester, [photo]);
    await _tap(tester, find.text('edit one'));

    await _openTool(tester, 'Brightness');
    expect(_undo(tester).onPressed, isNull);
    await _drag(tester, 80);
    final first = photo.edit.value(Adjustment.brightness);
    expect(first, greaterThan(0));
    await _drag(tester, 160);
    expect(photo.edit.value(Adjustment.brightness), greaterThan(first));

    // Another setting in between doesn't disturb brightness' own undo.
    await _tap(tester, find.byTooltip('Back to tools'));
    await _tap(tester, find.bySemanticsLabel(RegExp('^Contrast')));
    await _drag(tester, -80);
    expect(photo.edit.value(Adjustment.contrast), lessThan(0));
    await _tap(tester, find.byTooltip('Back to tools'));
    await _tap(tester, find.bySemanticsLabel(RegExp('^Brightness')));

    await _tap(tester, find.byTooltip('Undo'));
    expect(photo.edit.value(Adjustment.brightness), first);
    expect(photo.edit.value(Adjustment.contrast), lessThan(0));

    // Leaving keeps the edits — and the undo history, when reopened.
    await _tap(tester, find.text('Done'));
    expect(photo.edit.value(Adjustment.brightness), first);
    await _tap(tester, find.text('edit one'));
    await _openTool(tester, 'Brightness');
    await _tap(tester, find.byTooltip('Undo'));
    expect(photo.edit.value(Adjustment.brightness), 0);

    // Reset sends contrast back to 0 and is itself undoable.
    await _tap(tester, find.byTooltip('Back to tools'));
    await _tap(tester, find.bySemanticsLabel(RegExp('^Contrast')));
    await _tap(tester, find.text('Reset'));
    expect(photo.edit.value(Adjustment.contrast), 0);
    await _tap(tester, find.byTooltip('Undo'));
    expect(photo.edit.value(Adjustment.contrast), lessThan(0));
  });

  testWidgets('filters: pick, set strength, undo, reset', (tester) async {
    final photo = _photo('b');
    await _host(tester, [photo]);
    await _tap(tester, find.text('edit one'));

    await _tap(tester, find.bySemanticsLabel('Punch'));
    expect(photo.edit.filter, 'punch');
    expect(photo.edit.filterStrength, 1);
    await _drag(tester, -150);
    expect(photo.edit.filterStrength, lessThan(1));

    await _tap(tester, find.byTooltip('Undo'));
    expect(photo.edit.filter, 'punch');
    expect(photo.edit.filterStrength, 1);
    await _tap(tester, find.text('Reset'));
    expect(photo.edit.filter, 'normal');
    await _tap(tester, find.byTooltip('Undo'));
    expect(photo.edit.filter, 'punch');
  });

  testWidgets('edit all applies one look to every item', (tester) async {
    final items = [_photo('c'), _photo('d'), _photo('e')];
    items[1].edit = items[1].edit.withAdjustment(Adjustment.warmth, 0.5);
    final history = EditHistory();
    await _host(tester, items, history: history);
    await _tap(tester, find.text('edit all'));
    expect(find.text('Edit all (3)'), findsOneWidget);

    // Just looking doesn't wipe per-item edits.
    await _tap(tester, find.text('Done'));
    expect(items[1].edit.value(Adjustment.warmth), 0.5);

    await _tap(tester, find.text('edit all'));
    await _tap(tester, find.bySemanticsLabel('Golden'));
    for (final m in items) {
      expect(m.edit.filter, 'golden');
      expect(m.edit.value(Adjustment.warmth), 0);
    }
    await _openTool(tester, 'Saturation');
    await _drag(tester, 100);
    final sat = items.first.edit.value(Adjustment.saturation);
    expect(sat, greaterThan(0));
    expect(items.every((m) => m.edit.value(Adjustment.saturation) == sat), isTrue);

    // The group's undo history is kept between visits.
    await _tap(tester, find.text('Done'));
    await _tap(tester, find.text('edit all'));
    await _openTool(tester, 'Saturation');
    await _tap(tester, find.byTooltip('Undo'));
    expect(items.every((m) => m.edit.value(Adjustment.saturation) == 0 && m.edit.filter == 'golden'), isTrue);
  });
}
