// The stories tray (order, rings), the viewer (advancing, views, likes, quick
// reactions to DMs, my own story's viewers) against a FakeBackend.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/social.dart';
import 'package:gym_bro_mobile/models/story.dart';
import 'package:gym_bro_mobile/pages/stories/story_tray.dart';
import 'package:gym_bro_mobile/pages/stories/story_viewer_page.dart';
import 'package:gym_bro_mobile/services/auth_manager.dart';
import 'package:gym_bro_mobile/services/notification_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_fixtures.dart';
import '../helpers/fake_backend.dart';

const _me = 'u-me';
const _ana = {'id': 'u-ana', 'username': 'ana', 'name': 'Ana', 'last_name': 'Kovač', 'avatar_url': null};
const _bo = {'id': 'u-bo', 'username': 'bo', 'name': 'Bo', 'last_name': 'Lee', 'avatar_url': null};
const _meJson = {'id': _me, 'username': 'liamoconnor', 'name': 'Liam', 'last_name': "O'Connor", 'avatar_url': null};

Map<String, dynamic> _tray(Map<String, dynamic> user, {bool me = false, int unseen = 0}) => {
  'user': user,
  'is_me': me,
  'story_count': 2,
  'unseen_count': unseen,
  'has_unseen': unseen > 0,
  'latest_at': DateTime.now().toUtc().toIso8601String(),
};

Map<String, dynamic> _story(String id, String caption, {Map<String, dynamic> author = _ana, bool mine = false, bool seen = false}) => {
  'id': id,
  'author_id': author['id'],
  'author': author,
  'media_url': null,
  'media_type': null,
  'caption': caption,
  'background': '#2a9d8f',
  'share': null,
  'created_at': DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
  'expires_at': DateTime.now().add(const Duration(hours: 22)).toUtc().toIso8601String(),
  'is_live': true,
  'seen': mine || seen,
  'my_reaction': null,
  'is_mine': mine,
  'view_count': mine ? 2 : null,
  'reaction_count': mine ? 1 : null,
};

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  late FakeBackend backend;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    backend = FakeBackend()..install();
  });

  tearDown(() async {
    await AuthManager.instance.clear();
    backend.uninstall();
  });

  Future<void> signIn(WidgetTester tester) async {
    await tester.runAsync(() async {
      await AuthManager.instance.setSession(signinJson(accessToken: 'tok'), profileData: profileJson(id: _me, avatarUrl: null));
      await pumpEventQueue();
    });
    backend.requests.clear();
  }

  group('StoryRingAvatar', () {
    Future<BoxDecoration> ringOf(WidgetTester tester, StoryRing ring) async {
      await tester.pumpWidget(_app(Scaffold(
        body: StoryRingAvatar(radius: 30, ring: ring, child: const CircleAvatar(radius: 30)),
      )));
      final outer = tester.widgetList<Container>(find.byType(Container)).first;
      return outer.decoration! as BoxDecoration;
    }

    testWidgets('gradient for unwatched, grey for watched, none without stories', (tester) async {
      expect((await ringOf(tester, StoryRing.unseen)).gradient, kStoryGradient);
      final seen = await ringOf(tester, StoryRing.seen);
      expect(seen.gradient, isNull);
      expect(seen.color, isNot(Colors.transparent));
      final none = await ringOf(tester, StoryRing.none);
      expect(none.gradient, isNull);
      expect(none.color, Colors.transparent);
    });

    test('ringFor', () {
      expect(StoryRingAvatar.ringFor(hasStory: false, hasUnseen: true), StoryRing.none);
      expect(StoryRingAvatar.ringFor(hasStory: true, hasUnseen: true), StoryRing.unseen);
      expect(StoryRingAvatar.ringFor(hasStory: true, hasUnseen: false), StoryRing.seen);
    });
  });

  group('StoryTray', () {
    List<StoryRing> rings(WidgetTester tester) =>
        tester.widgetList<StoryRingAvatar>(find.byType(StoryRingAvatar)).map((a) => a.ring).toList();

    testWidgets('"Your story" first, then unwatched (gradient) and watched (grey)', (tester) async {
      await signIn(tester);
      backend.on('GET /stories/feed', ok([_tray(_meJson, me: true), _tray(_ana, unseen: 2), _tray(_bo)]));
      await tester.pumpWidget(_app(const Scaffold(body: StoryTray())));
      await tester.pumpAndSettle();

      expect(find.text('Your story'), findsOneWidget);
      final x = [for (final t in ['Your story', 'ana', 'bo']) tester.getTopLeft(find.text(t)).dx];
      expect(x, orderedEquals([...x]..sort()), reason: 'shown in this order');
      expect(rings(tester), [StoryRing.unseen, StoryRing.unseen, StoryRing.seen]);
      expect(find.byIcon(Icons.add), findsOneWidget, reason: 'the + to add a story');
    });

    testWidgets('without stories of mine, "Your story" is still first, without a ring', (tester) async {
      await signIn(tester);
      backend.on('GET /stories/feed', ok([_tray(_bo)]));
      await tester.pumpWidget(_app(const Scaffold(body: StoryTray())));
      await tester.pumpAndSettle();
      expect(rings(tester), [StoryRing.none, StoryRing.seen]);
      expect(find.text('Your story'), findsOneWidget);
    });
  });

  group('viewer', () {
    Future<void> openAna(WidgetTester tester, {void Function(String)? onSeen}) async {
      await signIn(tester);
      backend
        ..on('GET /stories', ok([_story('s-1', 'First'), _story('s-2', 'Second')]))
        ..on('POST /stories/s-1/view', ok(null, 204))
        ..on('POST /stories/s-2/view', ok(null, 204));
      await tester.pumpWidget(_app(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => openUserStories(context, [const SocialUser(id: 'u-ana', username: 'ana', name: 'Ana', lastName: 'Kovač')], onSeen: onSeen),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('plays each story, records views, and closes after the last', (tester) async {
      final seen = <String>[];
      await openAna(tester, onSeen: seen.add);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('ana'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2), reason: 'one bar per story');
      expect(backend.requests.where((r) => describe(r) == 'POST /stories/s-1/view'), hasLength(1));

      // Tap the right side → next.
      final size = tester.getSize(find.byType(StoryViewerPage));
      await tester.tapAt(Offset(size.width * 0.8, size.height / 2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Second'), findsOneWidget);
      expect(backend.requests.where((r) => describe(r) == 'POST /stories/s-2/view'), hasLength(1));
      expect(seen, ['u-ana'], reason: 'all of hers are watched');

      // Left side → back.
      await tester.tapAt(Offset(size.width * 0.1, size.height / 2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('First'), findsOneWidget);

      // Let both run out (5 s each): the viewer closes.
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Second'), findsOneWidget);
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byType(StoryViewerPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
      await close(tester);
    });

    testWidgets('like, and a quick reaction from the swipe-up panel goes to their DMs', (tester) async {
      await openAna(tester);
      backend
        ..on('PUT /stories/s-1/reaction', ok({'story_id': 's-1', 'my_reaction': 'like', 'liked': true, 'reaction_count': null}))
        ..on('POST /chat/story-replies', ok({
          'id': 'm-1',
          'conversation_id': 'c-1',
          'sender_id': _me,
          'kind': 'text',
          'body': '🔥',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }, 201));

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump(const Duration(milliseconds: 100));
      expect(bodyOf(backend.last('PUT /stories/s-1/reaction')), {'reaction': 'like'});
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.fling(find.byType(StoryViewerPage), const Offset(0, -400), 1200);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Quick reactions'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('story-reaction-fire')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(bodyOf(backend.last('POST /chat/story-replies')), {'story_id': 's-1', 'reaction': 'fire'});
      expect(find.text('Reaction sent'), findsOneWidget);
      expect(find.text('Quick reactions'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await close(tester);
    });

    testWidgets('my own story: view count, and who watched it', (tester) async {
      await signIn(tester);
      backend.on('GET /stories/s-9/viewers', ok([
        {'user': _ana, 'viewed_at': DateTime.now().toUtc().toIso8601String(), 'reaction': 'like'},
        {'user': _bo, 'viewed_at': DateTime.now().toUtc().toIso8601String(), 'reaction': null},
      ]));
      final story = Story.fromJson(_story('s-9', 'Mine', author: _meJson, mine: true));
      await tester.pumpWidget(_app(Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () => openStoryList(context, [story]), child: const Text('open')),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Mine'), findsOneWidget);
      expect(find.text('Send message'), findsNothing, reason: 'no replying to myself');
      await tester.tap(find.text('2 views'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Ana Kovač'), findsOneWidget);
      expect(find.text('Bo Lee'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsWidgets, reason: 'Ana liked it');
      expect(backend.requests.where((r) => describe(r).startsWith('POST /stories/s-9/view')), isEmpty,
          reason: 'my own views are not recorded');
      await close(tester);
    });
  });

  group('story_reaction notifications', () {
    Future<void> open(WidgetTester tester) async {
      await signIn(tester);
      late BuildContext host;
      await tester.pumpWidget(_app(Scaffold(body: Builder(builder: (c) {
        host = c;
        return const Text('host');
      }))));
      NotificationRouter.open(host, 'story_reaction', {'story_id': 's-9', 'user_id': 'u-ana', 'reaction': 'like'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('open my story (even once expired)', (tester) async {
      backend.on('GET /stories/s-9', ok({..._story('s-9', 'Mine', author: _meJson, mine: true), 'is_live': false}));
      await open(tester);
      expect(find.byType(StoryViewerPage), findsOneWidget);
      expect(find.text('Mine'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a deleted story explains itself', (tester) async {
      backend.on('GET /stories/s-9', err(404, 'Story not found'));
      await open(tester);
      expect(find.byType(StoryViewerPage), findsNothing);
      expect(find.text('This story is no longer available'), findsOneWidget);
    });
  });
}
