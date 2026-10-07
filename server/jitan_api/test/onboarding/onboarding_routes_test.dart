import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _qr = 'n9Xq-2kLmPz8RtYw4VbC5dEf';
const _device = 'device-0123456789abcdef';

/// No dev identity: onboarding works without sign-in (the QR is the credential).
TestApp _app({bool active = true}) {
  final app = TestApp(devUserId: null, activeUserIds: {if (active) 1});
  app.onboarding.users = {_qr: (userId: 1, firstName: 'Disan', lastName: 'Ssebowa', code: 'SBW', isActive: active)};
  app.onboarding.companies = {
    1: ['Almeco', 'PCA'],
  };
  app.languages.languages = const [Language(id: 2, code: 'nl', name: 'Dutch')];
  return app;
}

Future<Map<String, Object?>> _error(Response response) async =>
    (await jsonBody(response))['error']! as Map<String, Object?>;

String _start([String qr = _qr]) => jsonEncode({'qrCode': qr});

String _complete({
  String qr = _qr,
  String password = 'correct horse battery',
  String deviceId = _device,
  String? languageCode,
}) => jsonEncode({'qrCode': qr, 'password': password, 'deviceId': deviceId, 'languageCode': languageCode});

void main() {
  group('POST /onboarding/start', () {
    test('onboarding allowed when userPassword IS NULL: returns the account to confirm', () async {
      final response = await _app().post('/onboarding/start', _start());

      expect(response.statusCode, 200);
      expect(await jsonBody(response), {
        'firstName': 'Disan',
        'lastName': 'Ssebowa',
        'code': 'SBW',
        'companies': ['Almeco', 'PCA'],
      });
      expect(response.headers['cache-control'], 'no-store');
    });

    test('onboarding blocked when userPassword IS NOT NULL', () async {
      final app = _app()..onboarding.passwordHashes[1] = r'$argon2id$existing';

      final response = await app.post('/onboarding/start', _start());

      expect(response.statusCode, 409);
      expect(await _error(response), containsPair('code', 'onboarding_already_completed'));
    });

    test('unknown QR returns a generic error that reveals nothing', () async {
      final response = await _app().post('/onboarding/start', _start('not-a-real-qr'));

      expect(response.statusCode, 404);
      final error = await _error(response);
      expect(error['code'], 'invalid_qr_code');
      expect(error['message'], 'This is not a Jitan QR code.');
    });

    test('inactive employee is refused', () async {
      final response = await _app(active: false).post('/onboarding/start', _start());

      expect(response.statusCode, 403);
      expect(await _error(response), containsPair('code', 'account_inactive'));
    });

    test('MFD (marked for deletion) employee is refused, also when already activated', () async {
      final app = _app()..onboarding.markedForDeletion.add(1);
      final activated = _app()
        ..onboarding.markedForDeletion.add(1)
        ..onboarding.passwordHashes[1] = r'$argon2id$existing';

      for (final response in [
        await app.post('/onboarding/start', _start()),
        await app.post('/onboarding/complete', _complete()),
        await activated.post('/onboarding/complete', _complete()),
      ]) {
        expect(response.statusCode, 403);
        expect(await _error(response), containsPair('code', 'account_inactive'));
      }
      expect(app.onboarding.passwordHashes, isEmpty);
    });

    test('400 for a blank or absurdly long QR, or a malformed body', () async {
      final app = _app();

      expect((await app.post('/onboarding/start', _start('  '))).statusCode, 400);
      expect((await app.post('/onboarding/start', _start('x' * 257))).statusCode, 400);
      expect((await app.post('/onboarding/start', '{oops')).statusCode, 400);
      expect((await app.post('/onboarding/start', '{}')).statusCode, 400);
    });
  });

  group('POST /onboarding/complete', () {
    test('stores an Argon2id hash of the exact password, audits, commits', () async {
      final app = _app();

      final response = await app.post('/onboarding/complete', _complete(password: '  spaced pass  '));

      expect(response.statusCode, 200);
      final hash = app.onboarding.passwordHashes[1]!;
      expect(hash, startsWith(r'$argon2id$v=19$'));
      expect(await app.hasher.verify('  spaced pass  ', hash), isTrue, reason: 'never trimmed');
      expect(await app.hasher.verify('spaced pass', hash), isFalse);
      final event = app.audit.events.single;
      expect(event.type, AuditEventType.onboardingCompleted);
      expect(event.references, {EventLogReference.user: 1});
      expect(app.transactions.outcomes, ['commit']);
    });

    test('successful onboarding returns a valid authenticated session for this device', () async {
      final app = _app();

      final response = await app.post('/onboarding/complete', _complete());
      final body = SessionResponse.fromJson(await jsonBody(response));

      expect(body.account.code, 'SBW');
      expect(body.session.expiresAt, DateTime.utc(2026, 11, 6, 12));
      final claims = app.sessions.verify(body.session.accessToken)!;
      expect(claims.userId, 1);
      expect(claims.deviceId, _device);
      expect(response.headers['cache-control'], 'no-store');
    });

    test('the employee lands directly in the authenticated app: the session works for GET /me', () async {
      final app = _app();
      final body = SessionResponse.fromJson(
        await jsonBody(await app.post('/onboarding/complete', _complete())),
      );

      final me = await app.getAuthorized('/me', body.session.accessToken);

      expect(me.statusCode, 200);
      expect(await jsonBody(me), containsPair('code', 'SBW'));
      expect((await app.get('/me')).statusCode, 401, reason: 'without the token: no identity');
    });

    test('stores the chosen database language; English needs no row', () async {
      final dutch = _app();
      await dutch.post('/onboarding/complete', _complete(languageCode: 'nl'));
      expect(dutch.onboarding.languages, {1: 2});

      final english = _app();
      expect((await english.post('/onboarding/complete', _complete(languageCode: 'en'))).statusCode, 200);
      expect(english.onboarding.languages, isEmpty);
    });

    test('an unavailable language or a malformed device id is a field error, before anything is stored', () async {
      final app = _app();

      final language = await app.post('/onboarding/complete', _complete(languageCode: 'xx'));
      final device = await app.post('/onboarding/complete', _complete(deviceId: 'short'));

      expect(await _error(language), containsPair('field', 'languageCode'));
      expect(await _error(device), containsPair('field', 'deviceId'));
      expect(app.onboarding.passwordHashes, isEmpty);
    });

    test('after completion the same QR cannot restart or redo onboarding', () async {
      final app = _app();
      await app.post('/onboarding/complete', _complete());
      final firstHash = app.onboarding.passwordHashes[1];

      final restart = await app.post('/onboarding/start', _start());
      final redo = await app.post('/onboarding/complete', _complete(password: 'attacker password'));

      expect(restart.statusCode, 409);
      expect(redo.statusCode, 409);
      expect(await _error(redo), containsPair('code', 'onboarding_already_completed'));
      expect(app.onboarding.passwordHashes[1], firstHash, reason: 'password not replaced');
      expect(app.audit.events, hasLength(1));
    });

    test('session recovery: repeating completion with the same password signs in again, changes nothing', () async {
      final app = _app();
      await app.post('/onboarding/complete', _complete());
      final hash = app.onboarding.passwordHashes[1];

      final retry = await app.post('/onboarding/complete', _complete(deviceId: 'device-retry-0000000000'));

      expect(retry.statusCode, 200);
      final body = SessionResponse.fromJson(await jsonBody(retry));
      expect(app.sessions.verify(body.session.accessToken)!.deviceId, 'device-retry-0000000000');
      expect((await app.getAuthorized('/me', body.session.accessToken)).statusCode, 200);
      expect(app.onboarding.passwordHashes[1], hash, reason: 'password unchanged');
      expect(app.audit.events, hasLength(1), reason: 'onboarding not repeated');
      expect(app.transactions.outcomes, ['commit'], reason: 'no write for the recovery');
    });

    test('session recovery is refused for an inactive employee', () async {
      final app = _app();
      await app.post('/onboarding/complete', _complete());
      app.onboarding.users = {_qr: (userId: 1, firstName: 'Disan', lastName: 'Ssebowa', code: 'SBW', isActive: false)};

      expect((await app.post('/onboarding/complete', _complete())).statusCode, 403);
    });

    test('concurrent completion: the device losing the race gets 409 and nothing is committed', () async {
      final app = _app()..onboarding.loseRace = true;

      final response = await app.post('/onboarding/complete', _complete());

      expect(response.statusCode, 409);
      expect(app.transactions.outcomes, ['rollback']);
      expect(app.audit.events, isEmpty);
    });

    test('password rules: 8..256 characters, any letters, numbers and symbols, no 72-byte limit', () async {
      for (final password in ['short', '        ', 'x' * 257]) {
        final app = _app();
        final response = await app.post('/onboarding/complete', _complete(password: password));
        expect(response.statusCode, 400, reason: password);
        expect(await _error(response), containsPair('field', 'password'));
      }
      for (final password in ['8 chars!', 'é' * 256, r'P@ss w0rd §€ñ 🔐']) {
        expect((await _app().post('/onboarding/complete', _complete(password: password))).statusCode, 200);
      }
    });

    test('an inactive or unknown account is refused', () async {
      expect((await _app(active: false).post('/onboarding/complete', _complete())).statusCode, 403);
      expect((await _app().post('/onboarding/complete', _complete(qr: 'unknown'))).statusCode, 404);
    });

    test('the password and its hash never appear in responses or logs', () async {
      const password = 'Unmistakable-Pass-4471';
      final records = <String>[];
      final subscription = Logger.root.onRecord.listen((r) => records.add('${r.message} ${r.error ?? ''}'));
      addTearDown(subscription.cancel);
      final app = _app();

      final ok = await (await app.post('/onboarding/complete', _complete(password: password))).readAsString();
      final again = await (await app.post('/onboarding/complete', _complete(password: password))).readAsString();
      final hash = app.onboarding.passwordHashes[1]!;
      final hashBody = hash.split(r'$').last;

      for (final text in [ok, again, ...records]) {
        expect(text, isNot(contains(password)));
        expect(text, isNot(contains(hashBody)));
      }
    });
  });

  group('session authentication', () {
    Future<(TestApp, String)> onboarded() async {
      final app = _app();
      final body = SessionResponse.fromJson(
        await jsonBody(await app.post('/onboarding/complete', _complete())),
      );
      return (app, body.session.accessToken);
    }

    test('an expired session is refused', () async {
      final (app, token) = await onboarded();
      app.now = app.now.add(const Duration(days: 31));

      expect((await app.getAuthorized('/me', token)).statusCode, 401);
    });

    test('a password change ends every session', () async {
      final (app, token) = await onboarded();
      app.onboarding.passwordHashes[1] = r'$argon2id$a-new-password-hash';

      expect((await app.getAuthorized('/me', token)).statusCode, 401);
    });

    test('a disabled employee loses access immediately', () async {
      final (app, token) = await onboarded();
      app.users.activeUserIds.remove(1);

      expect((await app.getAuthorized('/me', token)).statusCode, 401);
    });

    test('a tampered or foreign token is refused, never silently ignored', () async {
      final (app, token) = await onboarded();

      expect((await app.getAuthorized('/me', '${token}x')).statusCode, 401);
      expect((await app.get('/me', headers: {'authorization': 'Basic abc'})).statusCode, 401);
    });
  });
}
