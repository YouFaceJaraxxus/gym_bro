import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/services/api_service.dart';
import 'package:http/http.dart' as http;

import '../helpers/fake_backend.dart';

const _token = 'tok-123';

void _expectHeaders(http.Request req) {
  expect(req.headers['Authorization'], 'Bearer $_token');
  expect(req.headers['Content-Type'], startsWith('application/json'));
}

Matcher _throwsMessage(String message) => throwsA(predicate((e) => e is Exception && '$e'.contains(message)));

void main() {
  late FakeBackend backend;
  late ApiService api;

  setUp(() {
    backend = FakeBackend()..install();
    api = ApiService();
  });
  tearDown(() => backend.uninstall());

  group('getSettings', () {
    test('GETs /users/me/settings; never-saved defaults (captured from the local stack)', () async {
      backend.on(
        'GET /users/me/settings',
        ok({
          'push_enabled': true,
          'muted_types': [],
          'weight_unit': 'kg',
          'theme_mode': 'system',
          'locale': null,
          'updated_at': null,
        }),
      );

      final s = await api.getSettings(_token);

      final req = backend.only;
      expect(req.method, 'GET');
      expect(pathOf(req), '/users/me/settings');
      expect(req.url.hasQuery, isFalse);
      _expectHeaders(req);
      expect(s.pushEnabled, isTrue);
      expect(s.mutedTypes, isEmpty);
      expect(s.weightUnit, 'kg');
      expect(s.themeMode, 'system');
      expect(s.locale, isNull);
    });

    test('parses saved settings', () async {
      backend.on(
        'GET /users/me/settings',
        ok({
          'push_enabled': false,
          'muted_types': ['class_reminder', 'post_reaction'],
          'weight_unit': 'lb',
          'theme_mode': 'dark',
          'locale': 'sr',
          'updated_at': '2026-10-20T10:00:00.000Z',
        }),
      );

      final s = await api.getSettings(_token);
      expect(s.pushEnabled, isFalse);
      expect(s.mutedTypes, {'class_reminder', 'post_reaction'});
      expect(s.weightUnit, 'lb');
      expect(s.themeMode, 'dark');
      expect(s.locale, 'sr');
    });

    test('401 surfaces the message', () async {
      backend.on('GET /users/me/settings', err(401, 'Invalid or expired token'));
      await expectLater(api.getSettings(_token), _throwsMessage('Invalid or expired token'));
    });
  });

  group('updateSettings', () {
    test('PUTs exactly the changes (null locale included) and parses the saved settings', () async {
      backend.on(
        'PUT /users/me/settings',
        ok({
          'push_enabled': true,
          'muted_types': ['chat_message'],
          'weight_unit': 'lb',
          'theme_mode': 'light',
          'locale': null,
          'updated_at': '2026-10-28T08:00:00.000Z',
        }),
      );

      final s = await api.updateSettings(_token, {
        'weight_unit': 'lb',
        'muted_types': ['chat_message'],
        'theme_mode': 'light',
        'locale': null,
      });

      final req = backend.only;
      expect(req.method, 'PUT');
      expect(pathOf(req), '/users/me/settings');
      _expectHeaders(req);
      expect(
        bodyOf(req),
        equals({
          'weight_unit': 'lb',
          'muted_types': ['chat_message'],
          'theme_mode': 'light',
          'locale': null,
        }),
      );
      expect(s.weightUnit, 'lb');
      expect(s.themeMode, 'light');
      expect(s.mutedTypes, {'chat_message'});
      expect(s.locale, isNull);
    });

    test('400 surfaces the validation message', () async {
      backend.on('PUT /users/me/settings', err(400, 'push_enabled must be a boolean'));
      await expectLater(
        api.updateSettings(_token, {'push_enabled': 'yes'}),
        _throwsMessage('push_enabled must be a boolean'),
      );
    });
  });

  group('registerDevice', () {
    test('POSTs {token, platform} to /devices', () async {
      backend.on(
        'POST /devices',
        ok({
          'id': 'd1',
          'token': 'fcm-abc',
          'platform': 'ios',
          'created_at': '2026-10-28T08:00:00.000Z',
          'last_seen_at': '2026-10-28T08:00:00.000Z',
        }, 201),
      );

      await api.registerDevice(_token, deviceToken: 'fcm-abc', platform: 'ios');

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/devices');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'token': 'fcm-abc', 'platform': 'ios'}));
    });

    test('400 surfaces the message', () async {
      backend.on('POST /devices', err(400, 'platform must be one of: android, ios, web, macos'));
      await expectLater(
        api.registerDevice(_token, deviceToken: 'x', platform: 'tv'),
        _throwsMessage('platform must be one of'),
      );
    });
  });

  group('unregisterDevice', () {
    test('DELETEs /devices with {token}; a 204 with no body is fine', () async {
      backend.on('DELETE /devices', ok('', 204));

      await api.unregisterDevice(_token, 'fcm-abc');

      final req = backend.only;
      expect(req.method, 'DELETE');
      expect(pathOf(req), '/devices');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'token': 'fcm-abc'}));
    });

    test('a non-JSON error body still throws a readable error', () async {
      backend.on('DELETE /devices', ok('Internal Server Error', 500));
      await expectLater(api.unregisterDevice(_token, 'fcm-abc'), _throwsMessage('Request failed (500)'));
    });
  });

  group('changeEmail', () {
    test('POSTs {new_email, password} and returns the API message', () async {
      backend.on(
        'POST /users/change-email',
        ok({
          'success': true,
          'new_email': 'liam.new@example.com',
          'message': 'We sent a confirmation link to liam.new@example.com. Your email changes once you open it.',
        }),
      );

      final msg = await api.changeEmail(_token, newEmail: 'liam.new@example.com', password: 'hunter2');

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/users/change-email');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'new_email': 'liam.new@example.com', 'password': 'hunter2'}));
      expect(msg, 'We sent a confirmation link to liam.new@example.com. Your email changes once you open it.');
    });

    test('falls back to a local message when the API sends none', () async {
      backend.on('POST /users/change-email', ok({'success': true}));
      expect(
        await api.changeEmail(_token, newEmail: 'a@b.co', password: 'pw'),
        'Check a@b.co for a confirmation link.',
      );
    });

    test('400 invalid_password / 409 email_taken surface the message', () async {
      backend.on('POST /users/change-email', err(400, 'Password is incorrect', code: 'invalid_password'));
      await expectLater(
        api.changeEmail(_token, newEmail: 'a@b.co', password: 'bad'),
        _throwsMessage('Password is incorrect'),
      );
      backend.on('POST /users/change-email', err(409, 'An account with this email already exists', code: 'email_taken'));
      await expectLater(
        api.changeEmail(_token, newEmail: 'a@b.co', password: 'pw'),
        _throwsMessage('An account with this email already exists'),
      );
    });
  });

  group('impersonate', () {
    test('POSTs {user_id} and returns the session map with the profile', () async {
      final session = {
        'access_token': 'access-x',
        'refresh_token': 'refresh-x',
        'expires_in': 3600,
        'expires_at': 1793174400,
        'token_type': 'bearer',
        'profile': {
          'id': 'u2',
          'name': 'Liam',
          'last_name': "O'Connor",
          'username': 'liam',
          'email': 'liam.oconnor@example.com',
          'role': 'user',
        },
      };
      backend.on('POST /users/impersonate', ok(session));

      final res = await api.impersonate(_token, 'u2');

      final req = backend.only;
      expect(req.method, 'POST');
      expect(pathOf(req), '/users/impersonate');
      _expectHeaders(req);
      expect(bodyOf(req), equals({'user_id': 'u2'}));
      expect(res, equals(session));
    });

    test('403 surfaces the message', () async {
      backend.on('POST /users/impersonate', err(403, "You can't sign in as another super user"));
      await expectLater(api.impersonate(_token, 'u3'), _throwsMessage("You can't sign in as another super user"));
    });
  });
}
