import 'package:flutter_test/flutter_test.dart';
import 'package:gym_bro_mobile/services/auth_service.dart';

import '../helpers/fake_backend.dart';
import 'auth_fixtures.dart';

/// Matches an Exception whose message (without "Exception: ") is [message].
Matcher throwsMessage(String message) => throwsA(
      isA<Exception>().having((e) => e.toString().replaceFirst('Exception: ', ''), 'message', message),
    );

/// A plain Exception with a readable message — not a FormatException from
/// trying to decode an HTML/plain-text error page.
final throwsReadable = throwsA(
  allOf(
    isA<Exception>(),
    isNot(isA<FormatException>()),
    predicate<Object>((e) => e.toString().contains('502'), 'mentions the status code'),
  ),
);

void main() {
  late FakeBackend backend;
  late AuthService auth;

  setUp(() {
    backend = FakeBackend()..install();
    auth = AuthService();
  });

  tearDown(() => backend.uninstall());

  void expectJsonPost(String path, {String? bearer}) {
    final r = backend.only;
    expect(r.method, 'POST');
    expect(pathOf(r), path);
    expect(r.url.hasQuery, isFalse);
    expect(r.headers['content-type'], startsWith('application/json'));
    if (bearer == null) {
      expect(r.headers.containsKey('authorization'), isFalse, reason: 'public endpoint sends no token');
    } else {
      expect(r.headers['authorization'], 'Bearer $bearer');
    }
  }

  group('signup', () {
    Future<Map<String, dynamic>> signup() => auth.signup(
          email: 'new.user@example.com',
          password: 'hunter22',
          username: 'newuser',
          name: 'New',
          lastName: 'User',
        );

    test('POSTs /users/signup with every field (last_name in snake case) and returns the body', () async {
      backend.on(
        'POST /users/signup',
        ok({
          'message': 'Check your email to verify your account.',
          'user': profileJson(id: 'u-new', username: 'newuser', email: 'new.user@example.com'),
          'role_assignment': null,
        }, 201),
      );

      final data = await signup();

      expectJsonPost('/users/signup');
      expect(bodyOf(backend.only), {
        'email': 'new.user@example.com',
        'password': 'hunter22',
        'username': 'newuser',
        'name': 'New',
        'last_name': 'User',
      });
      expect(data['message'], 'Check your email to verify your account.');
      expect((data['user'] as Map)['id'], 'u-new');
    });

    test('invite_pending → SignupException with code, message and status', () async {
      backend.on(
        'POST /users/signup',
        err(409, "You've already been invited. We sent you a new invite email: enter its code to set up your account.",
            code: 'invite_pending'),
      );

      await expectLater(
        signup(),
        throwsA(isA<SignupException>()
            .having((e) => e.code, 'code', 'invite_pending')
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message', startsWith("You've already been invited"))
            .having((e) => e.toString(), 'toString', startsWith("You've already been invited"))),
      );
    });

    test('email_taken → SignupException with code email_taken', () async {
      backend.on('POST /users/signup', err(409, 'An account with this email already exists', code: 'email_taken'));

      await expectLater(
        signup(),
        throwsA(isA<SignupException>()
            .having((e) => e.code, 'code', 'email_taken')
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message', 'An account with this email already exists')),
      );
    });

    test('an error without a code (e.g. validation) → SignupException with code null', () async {
      backend.on('POST /users/signup', err(400, 'Password must be at least 6 characters'));

      await expectLater(
        signup(),
        throwsA(isA<SignupException>()
            .having((e) => e.code, 'code', isNull)
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', 'Password must be at least 6 characters')),
      );
    });

    test('a non-JSON error body → SignupException with a generic message and the status', () async {
      backend.on('POST /users/signup', ok('<html>502 Bad Gateway</html>', 502));

      await expectLater(
        signup(),
        throwsA(isA<SignupException>()
            .having((e) => e.code, 'code', isNull)
            .having((e) => e.statusCode, 'statusCode', 502)
            .having((e) => e.message, 'message', 'Signup failed (502)')),
      );
    });
  });

  group('signin', () {
    test('POSTs {email, password} to /users/signin and returns session + profile', () async {
      backend.on('POST /users/signin', ok(signinJson()));

      final data = await auth.signin(email: 'liam.oconnor@example.com', password: 's3cret!');

      expectJsonPost('/users/signin');
      expect(bodyOf(backend.only), {'email': 'liam.oconnor@example.com', 'password': 's3cret!'});
      expect(data['access_token'], 'access-1');
      expect(data['refresh_token'], 'refresh-1');
      expect(data['expires_in'], 3600);
      expect((data['profile'] as Map)['username'], 'liamoconnor');
    });

    test('wrong credentials surface the API message', () async {
      backend.on('POST /users/signin', err(400, 'Invalid login credentials'));

      await expectLater(auth.signin(email: 'a@b.c', password: 'x'), throwsMessage('Invalid login credentials'));
    });

    test('an error body without "error" falls back to a generic message', () async {
      backend.on('POST /users/signin', ok({'msg': 'nope'}, 500));

      await expectLater(auth.signin(email: 'a@b.c', password: 'x'), throwsMessage('Sign in failed (500)'));
    });

    // A gateway error page (502 HTML) must not surface as a FormatException
    // ("Unexpected character…") on LoginPage.
    test('a non-JSON error body throws a readable error, not a FormatException', () async {
      backend.on('POST /users/signin', ok('<html>502 Bad Gateway</html>', 502));

      await expectLater(auth.signin(email: 'a@b.c', password: 'x'), throwsReadable);
    });
  });

  group('verifyInvite', () {
    test('POSTs {email, token, password} to /users/verify-invite and returns session + profile', () async {
      backend.on('POST /users/verify-invite', ok(signinJson(accessToken: 'inv-access')));

      final data = await auth.verifyInvite(email: 'priya.nair@example.com', token: '123456', password: 'newpass1');

      expectJsonPost('/users/verify-invite');
      expect(bodyOf(backend.only), {'email': 'priya.nair@example.com', 'token': '123456', 'password': 'newpass1'});
      expect(data['access_token'], 'inv-access');
      expect(data['profile'], isA<Map<String, dynamic>>());
    });

    test('a wrong/expired code surfaces the API message', () async {
      backend.on('POST /users/verify-invite', err(403, 'Invalid or expired code — request a new invite link'));

      await expectLater(
        auth.verifyInvite(email: 'a@b.c', token: '000000', password: 'newpass1'),
        throwsMessage('Invalid or expired code — request a new invite link'),
      );
    });

    test('falls back to a generic message', () async {
      backend.on('POST /users/verify-invite', ok(<String, dynamic>{}, 400));

      await expectLater(
        auth.verifyInvite(email: 'a@b.c', token: '000000', password: 'newpass1'),
        throwsMessage('Verification failed (400)'),
      );
    });

    test('a non-JSON error body throws a readable error, not a FormatException', () async {
      backend.on('POST /users/verify-invite', ok('Bad Gateway', 502));

      await expectLater(
        auth.verifyInvite(email: 'a@b.c', token: '000000', password: 'newpass1'),
        throwsReadable,
      );
    });
  });

  group('refresh', () {
    test('POSTs {refresh_token} to /users/refresh and returns the new session', () async {
      backend.on('POST /users/refresh', ok(sessionJson(accessToken: 'access-2', refreshToken: 'refresh-2')));

      final data = await auth.refresh('refresh-1');

      expectJsonPost('/users/refresh');
      expect(bodyOf(backend.only), {'refresh_token': 'refresh-1'});
      expect(data['access_token'], 'access-2');
      expect(data['refresh_token'], 'refresh-2');
      expect(data['expires_in'], 3600);
    });

    test('a revoked refresh token surfaces the API message', () async {
      backend.on('POST /users/refresh', err(400, 'Invalid Refresh Token: Refresh Token Not Found'));

      await expectLater(auth.refresh('stale'), throwsMessage('Invalid Refresh Token: Refresh Token Not Found'));
    });

    test('falls back to a generic message', () async {
      backend.on('POST /users/refresh', ok({'foo': 1}, 401));

      await expectLater(auth.refresh('stale'), throwsMessage('Token refresh failed (401)'));
    });

    // The status code lets AuthManager keep the session on a 5xx (see
    // auth_manager_test.dart).
    test('a non-JSON error body throws a readable error, not a FormatException', () async {
      backend.on('POST /users/refresh', ok('<html>502 Bad Gateway</html>', 502));

      await expectLater(auth.refresh('r'), throwsReadable);
    });
  });

  group('forgotPassword', () {
    test('POSTs {email} to /users/forgot-password', () async {
      backend.on('POST /users/forgot-password', ok({'success': true}));

      await auth.forgotPassword('liam.oconnor@example.com');

      expectJsonPost('/users/forgot-password');
      expect(bodyOf(backend.only), {'email': 'liam.oconnor@example.com'});
    });

    test('surfaces the API message', () async {
      backend.on('POST /users/forgot-password', err(400, 'email is required'));

      await expectLater(auth.forgotPassword(''), throwsMessage('email is required'));
    });

    test('falls back to a generic message', () async {
      backend.on('POST /users/forgot-password', ok(<String, dynamic>{}, 500));

      await expectLater(auth.forgotPassword('a@b.c'), throwsMessage('Failed to send reset email (500)'));
    });

    test('a non-JSON error body throws a readable error, not a FormatException', () async {
      backend.on('POST /users/forgot-password', ok('Bad Gateway', 502));

      await expectLater(auth.forgotPassword('a@b.c'), throwsReadable);
    });
  });

  group('resetPassword', () {
    test('POSTs {password} to /users/reset-password with the recovery session token', () async {
      backend.on('POST /users/reset-password', ok({'success': true}));

      await auth.resetPassword(accessToken: 'recovery-token', password: 'brandnew1');

      expectJsonPost('/users/reset-password', bearer: 'recovery-token');
      expect(bodyOf(backend.only), {'password': 'brandnew1'});
    });

    test('surfaces the API message', () async {
      backend.on('POST /users/reset-password', err(400, 'Password must be at least 6 characters'));

      await expectLater(
        auth.resetPassword(accessToken: 't', password: 'abc'),
        throwsMessage('Password must be at least 6 characters'),
      );
    });

    test('falls back to a generic message', () async {
      backend.on('POST /users/reset-password', ok(<String, dynamic>{}, 401));

      await expectLater(auth.resetPassword(accessToken: 't', password: 'abcdef'), throwsMessage('Password reset failed (401)'));
    });

    test('a non-JSON error body throws a readable error, not a FormatException', () async {
      backend.on('POST /users/reset-password', ok('Bad Gateway', 502));

      await expectLater(auth.resetPassword(accessToken: 't', password: 'abcdef'), throwsReadable);
    });
  });

  group('logout', () {
    test('POSTs /users/logout with the bearer token and no body (API answers 204)', () async {
      backend.on('POST /users/logout', ok('', 204));

      await auth.logout('access-1');

      final r = backend.only;
      expect(r.method, 'POST');
      expect(pathOf(r), '/users/logout');
      expect(r.headers['authorization'], 'Bearer access-1');
      expect(r.body, isEmpty);
    });

    test('throws with the status on failure', () async {
      backend.on('POST /users/logout', err(400, 'invalid JWT'));

      await expectLater(auth.logout('bad'), throwsMessage('Logout failed (400)'));
    });
  });

  group('signInWithGoogle', () {
    test('POSTs {id_token} to /users/google and returns session + profile', () async {
      backend.on('POST /users/google', ok(signinJson(accessToken: 'g-access')));

      final data = await auth.signInWithGoogle('google-id-token');

      expectJsonPost('/users/google');
      expect(bodyOf(backend.only), {'id_token': 'google-id-token'});
      expect(data['access_token'], 'g-access');
      expect((data['profile'] as Map)['id'], '8d0b05de-7c18-441b-9536-aaa042eaeaaa');
    });

    test('surfaces the API message', () async {
      backend.on('POST /users/google', err(409, 'An account with this email already exists', code: 'email_taken'));

      await expectLater(auth.signInWithGoogle('t'), throwsMessage('An account with this email already exists'));
    });

    test('a non-JSON error body → generic message with the status', () async {
      backend.on('POST /users/google', ok('<html>oops</html>', 502));

      await expectLater(auth.signInWithGoogle('t'), throwsMessage('Google sign-in failed (502)'));
    });
  });

  group('testEndpoint', () {
    test('GETs /users/test with the bearer token and returns {authenticated, profile}', () async {
      backend.on('GET /users/test', ok({'authenticated': true, 'profile': profileJson()}));

      final data = await auth.testEndpoint('access-1');

      final r = backend.only;
      expect(r.method, 'GET');
      expect(pathOf(r), '/users/test');
      expect(r.headers['authorization'], 'Bearer access-1');
      expect(data['authenticated'], isTrue);
      expect((data['profile'] as Map)['last_name'], "O'Connor");
    });

    test('surfaces the API message with a status fallback', () async {
      backend.on('GET /users/test', err(404, 'Not found'));
      await expectLater(auth.testEndpoint('t'), throwsMessage('Not found'));

      backend.on('GET /users/test', ok(<String, dynamic>{}, 500));
      await expectLater(auth.testEndpoint('t'), throwsMessage('Request failed (500)'));
    });
  });
}
