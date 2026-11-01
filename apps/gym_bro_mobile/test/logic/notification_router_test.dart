// Which screen each notification type opens (list taps and push taps both go
// through NotificationRouter.open), with which ids, and what it fetches.
// Metadata shapes are the ones the API functions write (notify(...) calls).

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';
import 'package:gym_bro_mobile/pages/business/business_invites_page.dart';
import 'package:gym_bro_mobile/pages/business/business_manage_page.dart';
import 'package:gym_bro_mobile/pages/chat/chat_thread_page.dart';
import 'package:gym_bro_mobile/pages/classes/class_detail_page.dart';
import 'package:gym_bro_mobile/pages/classes/my_shifts_page.dart';
import 'package:gym_bro_mobile/pages/feed/post_detail_page.dart';
import 'package:gym_bro_mobile/pages/gym_detail_page.dart';
import 'package:gym_bro_mobile/pages/meal_plans_page.dart';
import 'package:gym_bro_mobile/pages/membership_page.dart';
import 'package:gym_bro_mobile/pages/notifications_page.dart';
import 'package:gym_bro_mobile/pages/people/requests_page.dart';
import 'package:gym_bro_mobile/pages/people/user_profile_page.dart';
import 'package:gym_bro_mobile/pages/posts_page.dart';
import 'package:gym_bro_mobile/pages/routine_detail_page.dart';
import 'package:gym_bro_mobile/pages/session_detail_page.dart';
import 'package:gym_bro_mobile/pages/shop/order_detail_page.dart';
import 'package:gym_bro_mobile/pages/shop/storefront_page.dart';
import 'package:gym_bro_mobile/pages/shop/storefront_shop_page.dart';
import 'package:gym_bro_mobile/services/auth_manager.dart';
import 'package:gym_bro_mobile/services/notification_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_fixtures.dart';
import '../helpers/fake_backend.dart';

final en = lookupAppLocalizations(const Locale('en'));

class _Pushes extends NavigatorObserver {
  final List<Route<dynamic>> routes = [];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => routes.add(route);
}

/// GET /businesses/:id as the signed-in user sees it.
Map<String, dynamic> _business(String id, String name, {List<String> myRoles = const []}) => {
      'id': id,
      'name': name,
      'location': 'Knez Mihailova 1, Belgrade',
      'logo': null,
      'working_hours_from': '06:00:00',
      'working_hours_to': '23:00:00',
      'working_weekdays': [1, 2, 3, 4, 5, 6],
      'has_gym': true,
      'has_shop': false,
      'status': 'approved',
      'my_roles': myRoles,
    };

void main() {
  late FakeBackend backend;
  late _Pushes pushes;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    backend = FakeBackend()..install();
    pushes = _Pushes();
  });

  tearDown(() async {
    await AuthManager.instance.clear();
    backend.uninstall();
  });

  Future<void> signIn(WidgetTester tester, {bool superUser = false}) async {
    await tester.runAsync(() async {
      await AuthManager.instance.setSession(signinJson(accessToken: 'tok'),
          profileData: profileJson(id: 'u-me', isSuperUser: superUser));
      await pumpEventQueue();
    });
    backend.requests.clear();
  }

  /// Opens [type] with [metadata] from a host screen and returns the routes
  /// pushed (the host's own route excluded).
  Future<List<Route<dynamic>>> open(WidgetTester tester, String type, Map<String, dynamic> metadata,
      {bool signedIn = true, bool superUser = false}) async {
    if (signedIn) await signIn(tester, superUser: superUser);
    late BuildContext hostContext;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: [pushes],
      home: Scaffold(body: Builder(builder: (c) {
        hostContext = c;
        return const Text('host');
      })),
    ));
    pushes.routes.clear();

    NotificationRouter.open(hostContext, type, metadata);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // route transition + 404s from the page's loaders
    final pushed = List.of(pushes.routes);

    // Dispose whatever was opened before the next test.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    return pushed;
  }

  /// The page widget a pushed MaterialPageRoute builds.
  W pageOf<W extends Widget>(WidgetTester tester, List<Route<dynamic>> pushed) {
    expect(pushed, hasLength(1), reason: 'exactly one screen opens');
    final route = pushed.single as MaterialPageRoute<dynamic>;
    final page = route.builder(tester.element(find.byType(SizedBox).first));
    expect(page, isA<W>());
    return page as W;
  }

  testWidgets('signed out → nothing opens', (tester) async {
    expect(await open(tester, 'class_reminder', {'class_id': 'c-1'}, signedIn: false), isEmpty);
  });

  testWidgets('business_invite opens my team invites', (tester) async {
    pageOf<BusinessInvitesPage>(
        tester, await open(tester, 'business_invite', {'invite_status': 'pending', 'business_id': 'g-1', 'role': 'trainer'}));
  });

  testWidgets('member_invite opens the notifications list (answered there)', (tester) async {
    pageOf<NotificationsPage>(tester, await open(tester, 'member_invite', {'invite_status': 'pending', 'gym_id': 'g-1'}));
  });

  for (final type in ['business_join', 'business_review']) {
    testWidgets('$type opens the business dashboard', (tester) async {
      final page = pageOf<BusinessManagePage>(
          tester, await open(tester, type, {'business_id': 'g-1', 'user_id': 'u-2', 'role': 'staff', 'status': 'approved'}));
      expect(page.businessId, 'g-1');
    });

    testWidgets('$type without a business id opens nothing', (tester) async {
      expect(await open(tester, type, {'status': 'approved'}), isEmpty);
    });
  }

  for (final type in ['employee_gym_invite', 'vendor_shop_invite', 'employee_join', 'vendor_join']) {
    testWidgets('retired type $type opens nothing', (tester) async {
      expect(await open(tester, type, {'gym_id': 'g-1', 'shop_id': 's-1', 'invite_status': 'pending'}), isEmpty);
    });
  }

  for (final type in ['class_reminder', 'events']) {
    testWidgets('$type opens the class', (tester) async {
      final page = pageOf<ClassDetailPage>(
          tester, await open(tester, type, {'class_id': 'c-1', 'gym_id': 'g-1', 'gym_name': 'Iron Temple'}));
      expect(page.classId, 'c-1');
    });
  }

  testWidgets('class_reminder without a class_id (or an empty one) does nothing', (tester) async {
    expect(await open(tester, 'class_reminder', {'gym_id': 'g-1'}), isEmpty);
    expect(await open(tester, 'class_reminder', {'class_id': ''}), isEmpty);
  });

  testWidgets('shift_assigned opens my shifts', (tester) async {
    pageOf<MyShiftsPage>(tester, await open(tester, 'shift_assigned', {'shift_id': 's-1'}));
  });

  for (final type in ['order_update', 'purchase_made']) {
    testWidgets('$type opens the order', (tester) async {
      final page = pageOf<OrderDetailPage>(tester, await open(tester, type, {'order_id': 'o-1', 'status': 'cancelled'}));
      expect(page.orderId, 'o-1');
      expect(page.autoPay, isFalse);
      expect(page.asStaff, isFalse);
    });
  }

  testWidgets('order_update without an order_id does nothing', (tester) async {
    expect(await open(tester, 'order_update', {'status': 'cancelled'}), isEmpty);
  });

  testWidgets('payment_received for an order opens the order', (tester) async {
    final page = pageOf<OrderDetailPage>(
        tester, await open(tester, 'payment_received', {'payment_id': 'p-1', 'kind': 'order', 'order_id': 'o-7'}));
    expect(page.orderId, 'o-7');
  });

  testWidgets('payment_received for a membership opens the membership screen', (tester) async {
    final pushed = await open(tester, 'payment_received', {'payment_id': 'p-1', 'kind': 'membership', 'invoice_id': 'inv-1'});
    final scaffold = pageOf<Scaffold>(tester, pushed);
    expect(((scaffold.appBar as AppBar).title as Text).data, en.shellTabMembership);
    expect((scaffold.body as MembershipPage).profile.id, 'u-me');
  });

  for (final type in ['membership_expiring', 'invoice_issued', 'member_subscription_extended']) {
    testWidgets('$type opens the membership screen for the signed-in user', (tester) async {
      final scaffold = pageOf<Scaffold>(tester, await open(tester, type, {'membership_id': 'm-1'}));
      expect((scaffold.body as MembershipPage).profile.id, 'u-me');
    });
  }

  for (final type in ['post_comment', 'comment_reply', 'post_reaction']) {
    testWidgets('$type opens the post, focused on the comment', (tester) async {
      final page = pageOf<PostDetailPage>(
        tester,
        await open(tester, type, {
          'post_id': 'post-1',
          'business_id': 'g-1',
          'business_name': 'Iron Temple',
          'comment_id': 'cm-1',
          'parent_id': null,
        }),
      );
      expect(page.postId, 'post-1');
      expect(page.focusCommentId, 'cm-1');
    });
  }

  testWidgets('post_reaction (no comment) opens the post without a focus', (tester) async {
    final page = pageOf<PostDetailPage>(
        tester, await open(tester, 'post_reaction', {'post_id': 'post-1', 'business_id': 'g-1', 'reaction': 'fire'}));
    expect(page.focusCommentId, isNull);
  });

  testWidgets('a legacy post_comment without post_id opens the business feed', (tester) async {
    final page = pageOf<PostsPage>(
        tester, await open(tester, 'post_comment', {'business_id': 'g-1', 'business_name': 'Iron Temple'}));
    expect(page.businessId, 'g-1');
    expect(page.businessName, 'Iron Temple');
  });

  testWidgets('comment_reply without post_id does nothing', (tester) async {
    expect(await open(tester, 'comment_reply', {'business_id': 'g-1'}), isEmpty);
  });

  for (final type in ['follow_request', 'friend_request']) {
    testWidgets('$type opens requests', (tester) async {
      pageOf<RequestsPage>(tester, await open(tester, type, {'user_id': 'u-2'}));
    });
  }

  for (final type in ['follow', 'follow_accepted', 'friend_accepted']) {
    testWidgets('$type opens the person\'s profile', (tester) async {
      final page = pageOf<UserProfilePage>(tester, await open(tester, type, {'user_id': 'u-2'}));
      expect(page.userId, 'u-2');
    });
  }

  for (final type in ['chat_message', 'group_added']) {
    testWidgets('$type opens the conversation', (tester) async {
      final page = pageOf<ChatThreadPage>(tester, await open(tester, type, {'conversation_id': 'conv-1', 'message_id': 'msg-1'}));
      expect(page.conversationId, 'conv-1');
      expect(page.initial, isNull);
    });
  }

  group('news', () {
    testWidgets('opens the business feed with the name from metadata (no request)', (tester) async {
      final page = pageOf<PostsPage>(
        tester,
        await open(tester, 'news', {'business_id': 'g-1', 'business_name': 'Iron Temple', 'post_id': 'post-1'}),
      );
      expect(page.businessId, 'g-1');
      expect(page.businessName, 'Iron Temple');
      expect(page.canPost, isFalse);
      expect(backend.requests.where((r) => pathOf(r).startsWith('/businesses/')), isEmpty);
    });

    testWidgets('falls back to gym_id / shop_id and gym_name / shop_name', (tester) async {
      var page = pageOf<PostsPage>(tester, await open(tester, 'news', {'gym_id': 'g-2', 'gym_name': 'Gym Two'}));
      expect((page.businessId, page.businessName), ('g-2', 'Gym Two'));

      page = pageOf<PostsPage>(tester, await open(tester, 'news', {'shop_id': 's-1', 'shop_name': 'Protein Hub'}));
      expect((page.businessId, page.businessName), ('s-1', 'Protein Hub'));
    });

    testWidgets('fetches GET /businesses/:id for the name when metadata has none', (tester) async {
      backend.on('GET /businesses/g-1', ok(_business('g-1', 'Iron Temple')));

      final page = pageOf<PostsPage>(tester, await open(tester, 'news', {'business_id': 'g-1'}));

      expect(page.businessName, 'Iron Temple');
      final r = backend.requests.firstWhere((r) => pathOf(r) == '/businesses/g-1');
      expect(r.method, 'GET');
      expect(r.headers['authorization'], 'Bearer tok');
    });

    testWidgets('a failing name lookup opens nothing', (tester) async {
      backend.on('GET /businesses/g-1', err(404, 'Business not found'));
      expect(await open(tester, 'news', {'business_id': 'g-1'}), isEmpty);
    });

    testWidgets('without any business id does nothing', (tester) async {
      expect(await open(tester, 'news', {'post_id': 'post-1'}), isEmpty);
    });
  });

  testWidgets('session_comment opens the session', (tester) async {
    final page = pageOf<SessionDetailPage>(tester, await open(tester, 'session_comment', {'session_id': 'ts-1', 'comment_id': 'cm-1'}));
    expect(page.sessionId, 'ts-1');
  });

  testWidgets('training with a routine opens the routine; older meal-plan ones open meal plans', (tester) async {
    final routine = pageOf<RoutineDetailPage>(
        tester, await open(tester, 'training', {'routine_id': 'r-1', 'routine_assignment_id': 'ra-1'}));
    expect(routine.routineId, 'r-1');

    pageOf<MealPlansPage>(tester, await open(tester, 'training', {'meal_plan_id': 'mp-1', 'assignment_id': 'a-1'}));
  });

  testWidgets('shop_item_update opens the shop (name from metadata, else "Shop"); no shop → storefront', (tester) async {
    var page = pageOf<StorefrontShopPage>(
        tester, await open(tester, 'shop_item_update', {'shop_item_id': 'i-1', 'shop_id': 's-1', 'shop_name': 'Protein Hub'}));
    expect((page.shopId, page.shopName), ('s-1', 'Protein Hub'));

    page = pageOf<StorefrontShopPage>(tester, await open(tester, 'shop_item_update', {'shop_id': 's-1'}));
    expect(page.shopName, en.shellMuteShop);

    pageOf<StorefrontPage>(tester, await open(tester, 'shop_item_update', {'shop_item_id': 'i-1'}));
  });

  group('member_join (opens the gym only for its owners and staff)', () {
    for (final roles in [['owner'], ['staff']]) {
      testWidgets('${roles.single} of the gym → GET /businesses/:id → gym page', (tester) async {
        backend.on('GET /businesses/g-1', ok(_business('g-1', 'Iron Temple (renamed)', myRoles: roles)));

        final page = pageOf<GymDetailPage>(
            tester, await open(tester, 'member_join', {'gym_id': 'g-1', 'user_id': 'u-2', 'gym_name': 'Iron Temple'}));

        expect((page.gymId, page.gymName), ('g-1', 'Iron Temple'), reason: "the notification's name wins");
        final r = backend.last('GET /businesses/g-1');
        expect(r.headers['authorization'], 'Bearer tok');
      });
    }

    testWidgets('without gym_name the business name is used', (tester) async {
      backend.on('GET /businesses/g-1', ok(_business('g-1', 'Iron Temple', myRoles: ['owner'])));
      final page = pageOf<GymDetailPage>(tester, await open(tester, 'member_join', {'gym_id': 'g-1', 'user_id': 'u-2'}));
      expect(page.gymName, 'Iron Temple');
    });

    testWidgets('a trainer there, or not on the team → nothing', (tester) async {
      backend.on('GET /businesses/g-1', ok(_business('g-1', 'Iron Temple', myRoles: ['trainer'])));
      expect(await open(tester, 'member_join', {'gym_id': 'g-1', 'user_id': 'u-2'}), isEmpty);
      backend.on('GET /businesses/g-1', ok(_business('g-1', 'Iron Temple')));
      expect(await open(tester, 'member_join', {'gym_id': 'g-1', 'user_id': 'u-2'}), isEmpty);
    });

    testWidgets("the new member's own welcome notification opens nothing, no requests", (tester) async {
      expect(await open(tester, 'member_join', {'gym_id': 'g-1', 'user_id': 'u-me'}), isEmpty);
      expect(backend.requests.where((r) => pathOf(r).startsWith('/businesses')), isEmpty);
    });

    testWidgets('a super user opens any gym', (tester) async {
      backend.on('GET /businesses/g-1', ok(_business('g-1', 'Iron Temple')));
      final page = pageOf<GymDetailPage>(
        tester,
        await open(tester, 'member_join', {'gym_id': 'g-1', 'user_id': 'u-2', 'gym_name': 'Iron Temple'}, superUser: true),
      );
      expect(page.gymId, 'g-1');
      expect(AuthManager.instance.profile!.isSuperUser, isTrue);
    });

    testWidgets('a lookup error opens nothing', (tester) async {
      backend.on('GET /businesses/g-1', err(500, 'boom'));
      expect(await open(tester, 'member_join', {'gym_id': 'g-1', 'gym_name': 'Iron Temple'}), isEmpty);
    });

    testWidgets('no gym id → nothing, no requests', (tester) async {
      expect(await open(tester, 'member_join', {'user_id': 'u-2'}), isEmpty);
      expect(backend.requests.where((r) => pathOf(r).startsWith('/businesses')), isEmpty);
    });
  });

  for (final type in ['training_update', 'something_new_from_a_newer_api']) {
    testWidgets('$type opens nothing', (tester) async {
      expect(await open(tester, type, {'class_id': 'c-1', 'order_id': 'o-1'}), isEmpty);
    });
  }
}
