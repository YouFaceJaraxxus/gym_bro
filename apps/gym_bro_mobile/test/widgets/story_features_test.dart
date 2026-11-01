// Close friends, polls and highlights in the stories UI, against a FakeBackend.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/models/story.dart';
import 'package:gym_bro_mobile/pages/people/close_friends_page.dart';
import 'package:gym_bro_mobile/pages/stories/story_composer_page.dart';
import 'package:gym_bro_mobile/pages/stories/highlights.dart';
import 'package:gym_bro_mobile/pages/stories/story_tray.dart';
import 'package:gym_bro_mobile/pages/stories/story_viewer_page.dart';
import 'package:gym_bro_mobile/services/auth_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_fixtures.dart';
import '../helpers/fake_backend.dart';

const _me = 'u-me';
const _ana = {'id': 'u-ana', 'username': 'ana', 'name': 'Ana', 'last_name': 'Kovač', 'avatar_url': null};
const _meJson = {'id': _me, 'username': 'liamoconnor', 'name': 'Liam', 'last_name': "O'Connor", 'avatar_url': null};

Map<String, dynamic> _story(
  String id,
  String caption, {
  Map<String, dynamic> author = _ana,
  bool mine = false,
  bool live = true,
  bool closeFriends = false,
  Map<String, dynamic>? poll,
}) => {
  'id': id,
  'author_id': author['id'],
  'author': author,
  'media_url': null,
  'media_type': null,
  'caption': caption,
  'background': '#2a9d8f',
  'share': null,
  'audience': closeFriends ? 'close_friends' : 'everyone',
  'close_friends': closeFriends,
  'poll': poll,
  'created_at': DateTime.now().subtract(Duration(hours: live ? 2 : 50)).toUtc().toIso8601String(),
  'expires_at': DateTime.now().add(Duration(hours: live ? 22 : -26)).toUtc().toIso8601String(),
  'is_live': live,
  'seen': mine,
  'my_reaction': null,
  'is_mine': mine,
  'view_count': mine ? 1 : null,
  'reaction_count': mine ? 0 : null,
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

  Future<void> openList(WidgetTester tester, List<Story> stories, {String? title}) async {
    await tester.pumpWidget(_app(Scaffold(
      body: Builder(
        builder: (context) => TextButton(onPressed: () => openStoryList(context, stories, title: title), child: const Text('open')),
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

  testWidgets('the tray rings close-friends stories green', (tester) async {
    await signIn(tester);
    backend.on('GET /stories/feed', ok([
      {'user': _ana, 'is_me': false, 'story_count': 1, 'unseen_count': 1, 'close_friends': true, 'latest_at': null},
    ]));
    await tester.pumpWidget(_app(const Scaffold(body: StoryTray())));
    await tester.pumpAndSettle();
    final rings = tester.widgetList<StoryRingAvatar>(find.byType(StoryRingAvatar)).map((a) => a.ring).toList();
    expect(rings, [StoryRing.none, StoryRing.closeFriends]);
    expect(StoryRingAvatar.ringFor(hasStory: true, hasUnseen: false, closeFriends: true), StoryRing.seen);
  });

  testWidgets('voting in a poll shows the results; close-friends badge', (tester) async {
    await signIn(tester);
    const poll = {'question': 'Squat or deadlift?', 'options': ['Squat', 'Deadlift'], 'my_vote': null, 'total': null, 'counts': null};
    backend
      ..on('POST /stories/s-1/view', ok(null, 204))
      ..on('PUT /stories/s-1/vote', ok({
        ..._story('s-1', 'Leg day', closeFriends: true, poll: poll),
        'seen': true,
        'poll': {...poll, 'my_vote': 1, 'total': 4, 'counts': [1, 3]},
      }));
    await openList(tester, [Story.fromJson(_story('s-1', 'Leg day', closeFriends: true, poll: poll))]);

    expect(find.text('Close friends'), findsOneWidget);
    expect(find.text('Squat or deadlift?'), findsOneWidget);
    expect(find.text('75%'), findsNothing);
    await tester.tap(find.text('Deadlift'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(bodyOf(backend.last('PUT /stories/s-1/vote')), {'option': 1});
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('4 votes'), findsOneWidget);
    expect(find.byType(StoryViewerPage), findsOneWidget, reason: 'tapping the poll does not skip the story');
    await close(tester);
  });

  testWidgets('a highlight plays expired stories watch-only', (tester) async {
    await signIn(tester);
    const poll = {'question': 'Q', 'options': ['A', 'B'], 'my_vote': null, 'total': null, 'counts': null};
    backend.on('GET /stories/highlights/h-1', ok({
      'id': 'h-1',
      'user_id': 'u-ana',
      'title': 'Gym',
      'cover_story_id': null,
      'story_count': 1,
      'cover': {'story_id': 's-old', 'media_url': null, 'media_type': null, 'background': '#2a9d8f', 'caption': 'Old'},
      'user': _ana,
      'stories': [_story('s-old', 'Old one', live: false, poll: poll)],
    }));
    await tester.pumpWidget(_app(Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => openHighlight(context, const StoryHighlight(id: 'h-1', userId: 'u-ana', title: 'Gym')),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Old one'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget, reason: "the highlight's name in the header");
    expect(find.text('Send message'), findsNothing, reason: 'no replies to an expired story');
    await tester.tap(find.text('A'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(backend.requests.where((r) => describe(r).contains('/vote')), isEmpty);
    expect(backend.requests.where((r) => describe(r).endsWith('/view')), isEmpty, reason: 'expired views are not posted');
    await close(tester);
  });

  testWidgets('HighlightsRow: nothing for someone without highlights; "New" and circles for me', (tester) async {
    await signIn(tester);
    backend.on('GET /stories/highlights', (req) => req.url.queryParameters['user_id'] == _me
        ? ok([
            {
              'id': 'h-1',
              'user_id': _me,
              'title': 'Gym',
              'cover_story_id': null,
              'story_count': 1,
              'cover': {'story_id': 's-1', 'media_url': null, 'media_type': null, 'background': '#2a9d8f', 'caption': 'Hi'},
            },
          ])
        : ok([]));
    await tester.pumpWidget(_app(const Scaffold(body: HighlightsRow(userId: 'u-ana', isMe: false))));
    await tester.pumpAndSettle();
    expect(find.byType(HighlightBubble), findsNothing);

    await tester.pumpWidget(_app(const Scaffold(body: HighlightsRow(userId: _me, isMe: true))));
    await tester.pumpAndSettle();
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
  });

  testWidgets('adding my story to an existing highlight', (tester) async {
    await signIn(tester);
    final summary = {
      'id': 'h-1',
      'user_id': _me,
      'title': 'Gym',
      'cover_story_id': null,
      'story_count': 2,
      'cover': {'story_id': 's-1', 'media_url': null, 'media_type': null, 'background': '#2a9d8f', 'caption': 'Hi'},
    };
    backend
      ..on('GET /stories/highlights', ok([summary]))
      ..on('PUT /stories/highlights/h-1', ok(summary));
    final story = Story.fromJson(_story('s-9', 'Mine', author: _meJson, mine: true));
    await openList(tester, [story]);
    await tester.tap(find.byKey(const ValueKey('story-highlight')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Add to highlight'), findsOneWidget);
    await tester.tap(find.text('Gym'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(bodyOf(backend.last('PUT /stories/highlights/h-1')), {'add_story_ids': ['s-9']});
    expect(find.text('Added to Gym'), findsOneWidget);
    await close(tester);
  });

  testWidgets('composer: a text story with a poll, to close friends', (tester) async {
    await signIn(tester);
    backend.on('POST /stories', (req) => ok(_story('s-new', 'Hi', author: _meJson, mine: true, closeFriends: true), 201));
    await tester.pumpWidget(_app(const StoryComposerPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('story-text')), 'Which one?');
    await tester.tap(find.byKey(const ValueKey('story-poll')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('story-poll-question')), 'Squat or deadlift?');
    await tester.enterText(find.byKey(const ValueKey('story-poll-option-0')), 'Squat');
    await tester.enterText(find.byKey(const ValueKey('story-poll-option-1')), 'Deadlift');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Squat or deadlift?'), findsOneWidget, reason: 'the sticker shows on the canvas');
    await tester.tap(find.byKey(const ValueKey('story-post-close-friends')));
    await tester.pumpAndSettle();
    expect(bodyOf(backend.last('POST /stories')), {
      'caption': 'Which one?',
      'background': kStoryBackgrounds.first,
      'audience': 'close_friends',
      'poll': {'question': 'Squat or deadlift?', 'options': ['Squat', 'Deadlift']},
    });
    // Posted through the upload queue: let its "Posted" moment run out.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('CloseFriendsPage: remove one, add a follower', (tester) async {
    await signIn(tester);
    const bo = {'id': 'u-bo', 'username': 'bo', 'name': 'Bo', 'last_name': 'Lee', 'avatar_url': null};
    backend
      ..on('GET /social/close-friends', ok([_ana]))
      ..on('GET /social/users/$_me/followers', ok([_ana, bo]))
      ..on('DELETE /social/close-friends/u-ana', ok({'user_id': 'u-ana', 'is_close_friend': false}))
      ..on('PUT /social/close-friends/u-bo', ok({'user_id': 'u-bo', 'is_close_friend': true}));
    await tester.pumpWidget(_app(const CloseFriendsPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Only you can see'), findsOneWidget);
    expect(find.text('Your list · 1 person'), findsOneWidget);
    expect(find.byKey(const ValueKey('close-friend-u-ana')), findsNWidgets(2), reason: 'in the list and among followers');

    await tester.tap(find.byKey(const ValueKey('close-friend-u-bo')));
    await tester.pumpAndSettle();
    expect(backend.requests.where((r) => describe(r) == 'PUT /social/close-friends/u-bo'), hasLength(1));
    expect(find.text('Your list · 2 people'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('close-friend-u-ana')).first);
    await tester.pumpAndSettle();
    expect(backend.requests.where((r) => describe(r) == 'DELETE /social/close-friends/u-ana'), hasLength(1));
    expect(find.text('Your list · 1 person'), findsOneWidget);
  });
}
