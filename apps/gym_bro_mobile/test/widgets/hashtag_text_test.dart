import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/widgets/mentions.dart';

/// The spans [MentionText] renders: (text, tappable).
List<(String, bool)> _spans(WidgetTester tester) {
  final rich = tester.widget<RichText>(find.byType(RichText).first);
  final out = <(String, bool)>[];
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text != null) out.add((span.text!, span.recognizer is TapGestureRecognizer));
    return true;
  });
  return out;
}

Future<void> _pump(WidgetTester tester, String text) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: MentionText(text))));

const _id = '0c7a2e2e-1b1b-4c4c-8d8d-123456789abc';

void main() {
  testWidgets('hashtags and mentions are both links', (tester) async {
    await _pump(tester, 'Hi @[Liam O](user:$_id) #LegDay done#not #10');
    expect(_spans(tester), [
      ('Hi ', false),
      ('@Liam O', true),
      (' ', false),
      ('#LegDay', true),
      (' done#not #10', false),
    ]);
  });

  testWidgets('a hashtag right after a mention is not a tag (inside a word)', (tester) async {
    await _pump(tester, '@[Liam](user:$_id)#x and #y');
    expect(_spans(tester), [
      ('@Liam', true),
      ('#x and ', false),
      ('#y', true),
    ]);
  });

  testWidgets('plain text stays plain', (tester) async {
    await _pump(tester, 'No links here, #1');
    expect(find.text('No links here, #1'), findsOneWidget);
  });
}
