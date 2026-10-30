import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/shared_content.dart';
import 'package:gym_bro_mobile/pages/chat/message_bubble.dart';
import 'package:gym_bro_mobile/widgets/share_sheet.dart';
import 'package:gym_bro_mobile/widgets/shared_content_card.dart';

import '../helpers/fake_backend.dart';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: SingleChildScrollView(child: child))),
);

const _author = {'id': 'u-liam', 'username': 'liamoconnor', 'name': 'Liam', 'last_name': "O'Connor"};

SharedContent _content(String kind, {bool? available = true, String? reason, Map<String, dynamic> preview = const {}}) =>
    SharedContent.maybeFromJson({
      'kind': kind,
      'ref_id': 'id-1',
      'available': available,
      'reason': ?reason,
      'preview': preview,
    })!;

Future<void> _pump(WidgetTester tester, SharedContent c) async {
  await tester.pumpWidget(_app(SharedContentCard(content: c)));
  await tester.pump();
}

void main() {
  group('available', () {
    testWidgets('a post: author, caption, whose post it is', (tester) async {
      await _pump(tester, _content('post', preview: {
        'id': 'p-1',
        'author': _author,
        'caption': 'Leg day done',
        'post_type': 'generic',
        'media_count': 0,
      }));
      expect(find.text('liamoconnor'), findsOneWidget);
      expect(find.text('Leg day done'), findsOneWidget);
      expect(find.text("Liam O'Connor's post"), findsOneWidget);
    });

    testWidgets('a profile: name, handle, private chip, bio', (tester) async {
      await _pump(tester, _content('user', preview: {
        'id': 'u-sofia',
        'username': 'sofiarossi',
        'name': 'Sofia',
        'last_name': 'Rossi',
        'is_private': true,
        'bio': 'Powerlifter',
      }));
      expect(find.text('Sofia Rossi'), findsOneWidget);
      expect(find.text('@sofiarossi'), findsOneWidget);
      expect(find.text('Private account'), findsOneWidget);
      expect(find.text('Powerlifter'), findsOneWidget);
    });

    testWidgets('a gym and a product', (tester) async {
      await _pump(tester, _content('business', preview: {'id': 'b-1', 'name': 'Ironclad Fitness', 'type': 'gym', 'location': 'Belgrade'}));
      expect(find.text('Ironclad Fitness'), findsOneWidget);
      expect(find.text('Gym · Belgrade'), findsOneWidget);

      await _pump(tester, _content('shop_item', preview: {'id': 'i-1', 'name': 'Whey Isolate', 'price': '39.9', 'shop_name': 'Peak Supply'}));
      expect(find.text('Whey Isolate'), findsOneWidget);
      expect(find.textContaining('Peak Supply'), findsOneWidget);
      expect(find.textContaining('39.90'), findsOneWidget);
    });

    testWidgets('a story: its author over the colour / text', (tester) async {
      await _pump(tester, _content('story', preview: {'id': 's-1', 'author': _author, 'caption': 'PR today', 'background': '#ef233c'}));
      expect(find.text('liamoconnor'), findsOneWidget);
      expect(find.text('PR today'), findsOneWidget);
    });

    testWidgets('a library item uses the attachment card', (tester) async {
      await _pump(tester, _content('recipe', preview: {'title': 'Overnight oats', 'servings': 2}));
      expect(find.text('Overnight oats'), findsOneWidget);
    });
  });

  group('not available', () {
    const caption = 'secret caption';
    final cases = {
      ('post', 'private'): ('This account is private', 'Only approved followers can see this post.'),
      ('post', 'unavailable'): ('Post unavailable', 'This content was removed or you can no longer see it.'),
      ('story', 'expired'): ('Story expired', 'Stories are only visible for 24 hours.'),
      ('story', 'private'): ('This story is private', 'Only approved followers can see this story.'),
      ('user', 'unavailable'): ('Account unavailable', 'This content was removed or you can no longer see it.'),
      ('routine', 'private'): ('Workout program is private', "Only its author and people it's shared with can see it."),
    };
    for (final MapEntry(key: (kind, reason), value: (title, body)) in cases.entries) {
      testWidgets('$kind / $reason → "$title", no preview', (tester) async {
        // Even if a preview were sent along, nothing of it is shown.
        await _pump(tester, _content(kind, available: false, reason: reason, preview: {'caption': caption, 'author': _author}));
        expect(find.text(title), findsOneWidget);
        expect(find.text(body), findsOneWidget);
        expect(find.text(caption), findsNothing);
        expect(find.text('liamoconnor'), findsNothing);
      });
    }

    testWidgets('unresolved (realtime) → a loading skeleton', (tester) async {
      await _pump(tester, _content('post', available: null));
      expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
    });
  });

  group('StoryReplyHeader', () {
    testWidgets('my reaction to their expired story', (tester) async {
      await tester.pumpWidget(_app(StoryReplyHeader(
        mine: true,
        info: StoryReplyInfo.maybeFromJson({
          'mode': 'reaction',
          'story_id': 's-1',
          'owner_id': 'u-elena',
          'story': {'kind': 'story', 'ref_id': 's-1', 'available': false, 'reason': 'expired'},
        })!,
      )));
      expect(find.text('You reacted to their story'), findsOneWidget);
      expect(find.text('Story expired'), findsOneWidget);
    });

    testWidgets('their reply to a deleted story', (tester) async {
      await tester.pumpWidget(_app(StoryReplyHeader(
        mine: true,
        info: StoryReplyInfo.maybeFromJson({'mode': 'reply', 'story_id': null, 'owner_id': 'u-elena'})!,
      )));
      expect(find.text('You replied to their story'), findsOneWidget);
      expect(find.text('Story unavailable'), findsOneWidget);
    });
  });

  group('ShareSheet quick actions', () {
    late FakeBackend backend;
    setUp(() => backend = FakeBackend()..install());
    tearDown(() => backend.uninstall());

    Future<void> open(WidgetTester tester, ShareRequest r) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SizedBox(height: 800, child: ShareSheet(request: r))),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a library item: add to story and share as post', (tester) async {
      await open(tester, const ShareRequest.of(ShareKind.recipe, 'r-1', title: 'Overnight oats'));
      expect(find.text('Overnight oats'), findsOneWidget);
      expect(find.text('Add to story'), findsOneWidget);
      expect(find.text('Share as post'), findsOneWidget);
    });

    testWidgets("a profile can't go in a story or a post", (tester) async {
      await open(tester, const ShareRequest.of(ShareKind.user, 'u-1', title: 'Sofia Rossi'));
      expect(find.text('Add to story'), findsNothing);
      expect(find.text('Share as post'), findsNothing);
    });

    testWidgets('a post can go in a story; Send waits for a pick', (tester) async {
      await open(tester, const ShareRequest.of(ShareKind.post, 'p-1'));
      expect(find.text('Add to story'), findsOneWidget);
      expect(find.text('Share as post'), findsNothing);
      final send = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'));
      expect(send.onPressed, isNull);
    });
  });
}
