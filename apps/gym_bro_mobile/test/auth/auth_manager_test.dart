import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/models/user_profile.dart';
import 'package:gym_bro_mobile/services/auth_manager.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backend.dart';
import 'auth_fixtures.dart';

const _storage = FlutterSecureStorage();

int _msFromNow(Duration d) => DateTime.now().add(d).millisecondsSinceEpoch;

/// Secure-storage contents as AuthStorage writes them.
Map<String, String> _stored({
  String access = 'stored-access',
  String refresh = 'stored-refresh',
  Duration expiresIn = const Duration(hours: 1),
  Map<String, dynamic>? profile,
  bool withProfile = true,
  Map<String, dynamic>? admin,
}) =>
    {
      'access_token': access,
      'refresh_token': refresh,
      'expires_at': '${_msFromNow(expiresIn)}',
      if (withProfile) 'user_profile': jsonEncode(profile ?? profileJson()),
      if (admin != null) 'admin_session': jsonEncode(admin),
    };

void main() {
  late FakeBackend backend;
  final auth = AuthManager.instance;

  /// Requests to the auth endpoints (the background settings / realtime calls
  /// after sign-in are filtered out).
  List<String> authCalls() => backend.requests
      .where((r) => pathOf(r).startsWith('/users/') && pathOf(r) != '/users/me/settings')
      .map(describe)
      .toList();

  Future<Map<String, String>> storage() => _storage.readAll();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    backend = FakeBackend()..install();
  });

  tearDown(() async {
    await pumpEventQueue(); // let background work from sign-in finish
    await auth.clear();
    backend.uninstall();
  });

  group('setSession', () {
    test('stores tokens, expiry and profile in memory and in secure storage', () async {
      final before = DateTime.now();
      await auth.setSession(signinJson(), profileData: profileJson(role: 'owner'));

      expect(auth.hasSession, isTrue);
      expect(auth.profile!.id, '8d0b05de-7c18-441b-9536-aaa042eaeaaa');
      expect(auth.profile!.role, UserRole.owner);
      expect(auth.profile!.lastName, "O'Connor");
      expect(auth.isImpersonating, isFalse);

      final s = await storage();
      expect(s['access_token'], 'access-1');
      expect(s['refresh_token'], 'refresh-1');
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(int.parse(s['expires_at']!));
      expect(expiresAt.difference(before).inSeconds, closeTo(3600, 2));
      final storedProfile = jsonDecode(s['user_profile']!) as Map<String, dynamic>;
      expect(storedProfile['id'], '8d0b05de-7c18-441b-9536-aaa042eaeaaa');
      expect(storedProfile['role'], 'owner');
      expect(storedProfile['username'], 'liamoconnor');

      // Token is valid: no refresh needed.
      expect(await auth.getValidToken(), 'access-1');
      expect(authCalls(), isEmpty);
    });

    test('without profileData keeps tokens only (deep-link sessions)', () async {
      await auth.setSession(sessionJson(accessToken: 'link-access'));

      expect(auth.hasSession, isTrue);
      expect(auth.profile, isNull);
      final s = await storage();
      expect(s['access_token'], 'link-access');
      expect(s.containsKey('user_profile'), isFalse);
    });

    test('after sign-in, loads settings in the background with the new token', () async {
      await auth.setSession(signinJson(accessToken: 'fresh'), profileData: profileJson());
      await pumpEventQueue();

      final settings = backend.last('GET /users/me/settings');
      expect(settings.headers['authorization'], 'Bearer fresh');
    });
  });

  group('ensureProfile', () {
    test('fetches GET /users/test when the session has no profile', () async {
      backend.on('GET /users/test', ok({'authenticated': true, 'profile': profileJson(name: 'Fetched')}));
      await auth.setSession(sessionJson(accessToken: 'link-access'));

      await auth.ensureProfile();

      expect(auth.profile!.name, 'Fetched');
      expect(backend.last('GET /users/test').headers['authorization'], 'Bearer link-access');
      expect(jsonDecode((await storage())['user_profile']!)['name'], 'Fetched');
    });

    test('does nothing when the profile is already loaded, and swallows errors', () async {
      await auth.setSession(signinJson(), profileData: profileJson());
      await auth.ensureProfile();
      expect(authCalls(), isEmpty);

      await auth.clear();
      await auth.setSession(sessionJson());
      await auth.ensureProfile(); // GET /users/test → 404
      expect(auth.profile, isNull);
      expect(auth.hasSession, isTrue);
    });
  });

  group('tryRestoreSession', () {
    test('no stored session → false, no requests', () async {
      expect(await auth.tryRestoreSession(), isFalse);
      expect(auth.hasSession, isFalse);
      expect(backend.requests, isEmpty);
    });

    test('only an access token stored → false', () async {
      FlutterSecureStorage.setMockInitialValues({'access_token': 'a'});
      expect(await auth.tryRestoreSession(), isFalse);
      expect(auth.hasSession, isFalse);
    });

    test('a valid stored session is restored without a refresh', () async {
      FlutterSecureStorage.setMockInitialValues(_stored(profile: profileJson(role: 'trainer')));

      expect(await auth.tryRestoreSession(), isTrue);
      expect(auth.hasSession, isTrue);
      expect(auth.profile!.role, UserRole.trainer);
      expect(await auth.getValidToken(), 'stored-access');
      expect(authCalls(), isEmpty);
    });

    test('a valid session stored without a profile fetches it from GET /users/test', () async {
      FlutterSecureStorage.setMockInitialValues(_stored(withProfile: false));
      backend.on('GET /users/test', ok({'authenticated': true, 'profile': profileJson()}));

      expect(await auth.tryRestoreSession(), isTrue);
      expect(auth.profile!.username, 'liamoconnor');
      expect(backend.last('GET /users/test').headers['authorization'], 'Bearer stored-access');
    });

    test('an expired session is refreshed with the stored refresh token', () async {
      FlutterSecureStorage.setMockInitialValues(_stored(expiresIn: const Duration(minutes: -5)));
      backend.on('POST /users/refresh', ok(sessionJson(accessToken: 'access-2', refreshToken: 'refresh-2')));

      expect(await auth.tryRestoreSession(), isTrue);

      expect(authCalls(), ['POST /users/refresh']);
      expect(bodyOf(backend.last('POST /users/refresh')), {'refresh_token': 'stored-refresh'});
      expect(await auth.getValidToken(), 'access-2');
      final s = await storage();
      expect(s['access_token'], 'access-2');
      expect(s['refresh_token'], 'refresh-2');
      expect(int.parse(s['expires_at']!), greaterThan(_msFromNow(const Duration(minutes: 59))));
      expect(auth.profile!.username, 'liamoconnor', reason: 'profile kept across refresh');
    });

    test('a session expiring within 60 s counts as expired', () async {
      FlutterSecureStorage.setMockInitialValues(_stored(expiresIn: const Duration(seconds: 30)));
      backend.on('POST /users/refresh', ok(sessionJson(accessToken: 'access-2')));

      expect(await auth.tryRestoreSession(), isTrue);
      expect(authCalls(), ['POST /users/refresh']);
    });

    test('refresh rejected by the API → session cleared, returns false', () async {
      FlutterSecureStorage.setMockInitialValues(_stored(expiresIn: const Duration(minutes: -5)));
      backend.on('POST /users/refresh', err(400, 'Invalid Refresh Token: Refresh Token Not Found'));

      expect(await auth.tryRestoreSession(), isFalse);
      expect(auth.hasSession, isFalse);
      expect(auth.profile, isNull);
      expect(await storage(), isEmpty);
    });

    test('refresh fails with a network error → session kept (offline start)', () async {
      FlutterSecureStorage.setMockInitialValues(_stored(expiresIn: const Duration(minutes: -5)));
      backend.on('POST /users/refresh', (http.Request _) => throw http.ClientException('Connection refused'));

      expect(await auth.tryRestoreSession(), isTrue);
      expect(auth.hasSession, isTrue);
      expect(auth.profile!.username, 'liamoconnor');
      expect((await storage())['access_token'], 'stored-access');
      // Still offline: the stale token is handed out so cached data can be shown.
      expect(await auth.getValidToken(), 'stored-access');
    });

    // A server outage (here a gateway's 502 HTML page) says nothing about the
    // refresh token: keep the session, like when offline.
    test('refresh hitting a non-JSON gateway error keeps the session', () async {
      FlutterSecureStorage.setMockInitialValues(_stored(expiresIn: const Duration(minutes: -5)));
      backend.on('POST /users/refresh', ok('<html>502 Bad Gateway</html>', 502));

      await auth.tryRestoreSession();
      expect(auth.hasSession, isTrue);
    });
  });

  group('getValidToken', () {
    test('throws without a session', () async {
      await expectLater(auth.getValidToken(), throwsA(isA<Exception>()));
    });

    test('refreshes when the token is about to expire, then reuses the new one', () async {
      await auth.setSession(signinJson(expiresIn: 30), profileData: profileJson());
      await pumpEventQueue();
      backend.requests.clear();
      backend.on('POST /users/refresh', ok(sessionJson(accessToken: 'access-2', refreshToken: 'refresh-2')));

      expect(await auth.getValidToken(), 'access-2');
      expect(bodyOf(backend.last('POST /users/refresh')), {'refresh_token': 'refresh-1'});

      expect(await auth.getValidToken(), 'access-2');
      expect(authCalls(), ['POST /users/refresh'], reason: 'second call needs no refresh');
      expect((await storage())['refresh_token'], 'refresh-2');
    });

    test('a refresh rejected by the API propagates', () async {
      await auth.setSession(signinJson(expiresIn: 30), profileData: profileJson());
      backend.on('POST /users/refresh', err(400, 'Invalid Refresh Token'));

      await expectLater(
        auth.getValidToken(),
        throwsA(predicate<Object>((e) => e.toString().contains('Invalid Refresh Token'))),
      );
    });

    test('offline during refresh → the stale token', () async {
      await auth.setSession(signinJson(accessToken: 'stale', expiresIn: 30), profileData: profileJson());
      backend.on('POST /users/refresh', (http.Request _) => throw http.ClientException('offline'));

      expect(await auth.getValidToken(), 'stale');
    });
  });

  group('logout', () {
    test('POSTs /users/logout with the current token and clears everything', () async {
      SharedPreferences.setMockInitialValues({'user_settings_v1': '{"theme_mode":"dark"}'});
      backend.on('POST /users/logout', ok('', 204));
      await auth.setSession(signinJson(accessToken: 'mine'), profileData: profileJson());
      await pumpEventQueue();

      expect(await auth.logout(), isFalse);

      final r = backend.last('POST /users/logout');
      expect(r.headers['authorization'], 'Bearer mine');
      expect(r.body, isEmpty);
      expect(auth.hasSession, isFalse);
      expect(auth.profile, isNull);
      expect(await storage(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_settings_v1'), isNull, reason: 'cached settings belong to the old user');
    });

    test('refreshes an expired token first so the server can revoke it', () async {
      backend.on('POST /users/refresh', ok(sessionJson(accessToken: 'refreshed')));
      backend.on('POST /users/logout', ok('', 204));
      await auth.setSession(signinJson(accessToken: 'old', expiresIn: 10), profileData: profileJson());
      await pumpEventQueue();

      await auth.logout();

      expect(backend.last('POST /users/logout').headers['authorization'], 'Bearer refreshed');
    });

    test('clears the local session even when the API call fails', () async {
      backend.on('POST /users/logout', err(500, 'boom'));
      await auth.setSession(signinJson(), profileData: profileJson());

      expect(await auth.logout(), isFalse);
      expect(auth.hasSession, isFalse);
      expect(await storage(), isEmpty);
    });

    test('signed out → no request', () async {
      expect(await auth.logout(), isFalse);
      expect(backend.requests, isEmpty);
    });
  });

  group('impersonation', () {
    Map<String, dynamic> impersonated() => signinJson(
          accessToken: 'imp-access',
          refreshToken: 'imp-refresh',
          profile: profileJson(id: 'u-member', username: 'sofiarossi', name: 'Sofia', lastName: 'Rossi'),
        );

    Future<void> signInAsAdmin() => auth.setSession(
          signinJson(accessToken: 'admin-access', refreshToken: 'admin-refresh'),
          profileData: profileJson(id: 'u-admin', username: 'chloe', role: 'super_user'),
        );

    test('start keeps the admin session aside (persisted) and switches to the user', () async {
      await signInAsAdmin();

      await auth.startImpersonation(impersonated());

      expect(auth.isImpersonating, isTrue);
      expect(auth.profile!.id, 'u-member');
      expect(auth.adminProfile!.id, 'u-admin');
      expect(auth.adminProfile!.role, UserRole.superUser);
      expect(await auth.getValidToken(), 'imp-access');

      final s = await storage();
      expect(s['access_token'], 'imp-access');
      expect(s['refresh_token'], 'imp-refresh');
      final admin = jsonDecode(s['admin_session']!) as Map<String, dynamic>;
      expect(admin['access_token'], 'admin-access');
      expect(admin['refresh_token'], 'admin-refresh');
      expect(admin['expires_at'], greaterThan(_msFromNow(const Duration(minutes: 59))));
      expect((admin['profile'] as Map)['id'], 'u-admin');
    });

    test('start requires a session and refuses nesting', () async {
      await expectLater(auth.startImpersonation(impersonated()), throwsA(isA<Exception>()));

      await signInAsAdmin();
      await auth.startImpersonation(impersonated());
      await expectLater(auth.startImpersonation(impersonated()), throwsA(isA<Exception>()));
    });

    test('stop revokes the impersonated session and restores the admin', () async {
      backend.on('POST /users/logout', ok('', 204));
      await signInAsAdmin();
      await auth.startImpersonation(impersonated());

      expect(await auth.stopImpersonation(), isTrue);

      expect(authCalls(), ['POST /users/logout']);
      expect(backend.last('POST /users/logout').headers['authorization'], 'Bearer imp-access');
      expect(auth.isImpersonating, isFalse);
      expect(auth.adminProfile, isNull);
      expect(auth.profile!.id, 'u-admin');
      expect(await auth.getValidToken(), 'admin-access');
      final s = await storage();
      expect(s['access_token'], 'admin-access');
      expect(s['refresh_token'], 'admin-refresh');
      expect(s.containsKey('admin_session'), isFalse);
      expect((jsonDecode(s['user_profile']!) as Map)['id'], 'u-admin');
    });

    test('stop still restores the admin when revoking fails', () async {
      backend.on('POST /users/logout', err(500, 'boom'));
      await signInAsAdmin();
      await auth.startImpersonation(impersonated());

      expect(await auth.stopImpersonation(), isTrue);
      expect(auth.profile!.id, 'u-admin');
    });

    test('logout while impersonating only ends the impersonation', () async {
      backend.on('POST /users/logout', ok('', 204));
      await signInAsAdmin();
      await auth.startImpersonation(impersonated());

      expect(await auth.logout(), isTrue, reason: 'a session remains');
      expect(auth.profile!.id, 'u-admin');
      expect(authCalls(), ['POST /users/logout']);
      expect(backend.last('POST /users/logout').headers['authorization'], 'Bearer imp-access');
    });

    test('stop refreshes an expired admin session; if that fails, signs out', () async {
      backend.on('POST /users/logout', ok('', 204));
      backend.on('POST /users/refresh', err(400, 'Invalid Refresh Token'));
      await auth.setSession(signinJson(accessToken: 'admin-access', refreshToken: 'admin-refresh', expiresIn: 10),
          profileData: profileJson(id: 'u-admin', role: 'super_user'));
      await auth.startImpersonation(impersonated());

      expect(await auth.stopImpersonation(), isFalse);

      expect(bodyOf(backend.last('POST /users/refresh')), {'refresh_token': 'admin-refresh'});
      expect(auth.hasSession, isFalse);
      expect(await storage(), isEmpty);
    });

    test('an app restart while impersonating restores both sessions', () async {
      FlutterSecureStorage.setMockInitialValues(_stored(
        access: 'imp-access',
        refresh: 'imp-refresh',
        profile: profileJson(id: 'u-member'),
        admin: {
          'access_token': 'admin-access',
          'refresh_token': 'admin-refresh',
          'expires_at': _msFromNow(const Duration(hours: 1)),
          'profile': profileJson(id: 'u-admin', role: 'super_user'),
        },
      ));

      expect(await auth.tryRestoreSession(), isTrue);
      expect(auth.isImpersonating, isTrue);
      expect(auth.profile!.id, 'u-member');
      expect(auth.adminProfile!.id, 'u-admin');
    });

    test('restart with an impersonated session that can\'t refresh falls back to the admin (no revoke)', () async {
      backend.on('POST /users/refresh', err(400, 'Invalid Refresh Token'));
      FlutterSecureStorage.setMockInitialValues(_stored(
        access: 'imp-access',
        refresh: 'imp-refresh',
        expiresIn: const Duration(minutes: -1),
        profile: profileJson(id: 'u-member'),
        admin: {
          'access_token': 'admin-access',
          'refresh_token': 'admin-refresh',
          'expires_at': _msFromNow(const Duration(hours: 1)),
          'profile': profileJson(id: 'u-admin', role: 'super_user'),
        },
      ));

      expect(await auth.tryRestoreSession(), isTrue);

      expect(authCalls(), ['POST /users/refresh']);
      expect(bodyOf(backend.last('POST /users/refresh')), {'refresh_token': 'imp-refresh'});
      expect(auth.isImpersonating, isFalse);
      expect(auth.profile!.id, 'u-admin');
      expect(await auth.getValidToken(), 'admin-access');
      expect((await storage()).containsKey('admin_session'), isFalse);
    });
  });

  test('updateProfile replaces the profile in memory and storage', () async {
    await auth.setSession(signinJson(), profileData: profileJson());

    await auth.updateProfile(UserProfile.fromJson(profileJson(name: 'Renamed', avatarUrl: null)));

    expect(auth.profile!.name, 'Renamed');
    final stored = jsonDecode((await storage())['user_profile']!) as Map<String, dynamic>;
    expect(stored['name'], 'Renamed');
    expect(stored['avatar_url'], isNull);
  });
}
