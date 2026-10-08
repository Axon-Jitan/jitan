import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _device = 'device-0123456789abcdef';
const _otherDevice = 'device-fedcba9876543210';

/// The permanent Terminal QR of user 1; it must never onboard anyone.
const _terminalQr = 'n9Xq-2kLmPz8RtYw4VbC5dEf';

/// No dev identity: onboarding works without sign-in (the temporary QR is the
/// credential).
TestApp _app({bool active = true}) {
  final app = TestApp(devUserId: null, activeUserIds: {if (active) 1});
  app.onboarding.users = {1: (userId: 1, firstName: 'Disan', lastName: 'Ssebowa', code: 'SBW', isActive: active)};
  app.onboarding.companies = {
    1: ['Almeco', 'PCA'],
  };
  app.languages.languages = const [Language(id: 2, code: 'nl', name: 'Dutch')];
  return app;
}

Future<String> _qr(TestApp app, [TemporaryQrPurpose purpose = TemporaryQrPurpose.onboarding]) => app.issueQr(1, purpose);

Future<Map<String, Object?>> _error(Response response) async =>
    (await jsonBody(response))['error']! as Map<String, Object?>;

String _start(String qr) => jsonEncode({'qrCode': qr});

String _complete(
  String qr, {
  String password = 'correct horse battery',
  String deviceId = _device,
  String? languageCode,
}) => jsonEncode({'qrCode': qr, 'password': password, 'deviceId': deviceId, 'languageCode': languageCode});

void main() {
  group('POST /onboarding/start', () {
    test('a valid temporary onboarding QR returns the account to confirm, without using the QR', () async {
      final app = _app();
      final qr = await _qr(app);

      final response = await app.post('/onboarding/start', _start(qr));

      expect(response.statusCode, 200);
      expect(await jsonBody(response), {
        'firstName': 'Disan',
        'lastName': 'Ssebowa',
        'code': 'SBW',
        'companies': ['Almeco', 'PCA'],
      });
      expect(response.headers['cache-control'], 'no-store');
      expect((await app.post('/onboarding/start', _start(qr))).statusCode, 200, reason: 'not consumed when scanned');
    });

    test('the permanent Terminal QR no longer authorizes onboarding', () async {
      final response = await _app().post('/onboarding/start', _start(_terminalQr));

      expect(response.statusCode, 400);
      expect(await _error(response), containsPair('code', 'invalid_qr_code'));
    });

    test('expired, replaced and wrong-purpose QRs are refused with their own codes', () async {
      final app = _app();
      final expired = await _qr(app);
      app.now = app.now.add(const Duration(minutes: 10));
      final replaced = await _qr(app);
      await _qr(app);
      final recovery = await _qr(app, TemporaryQrPurpose.recovery);

      expect(await _error(await app.post('/onboarding/start', _start(expired))), containsPair('code', 'qr_expired'));
      expect(await _error(await app.post('/onboarding/start', _start(replaced))), containsPair('code', 'qr_expired'));
      expect(await _error(await app.post('/onboarding/start', _start(recovery))), containsPair('code', 'qr_wrong_purpose'));
    });

    test('onboarding blocked when userPassword IS NOT NULL', () async {
      final app = _app()..onboarding.passwordHashes[1] = r'$argon2id$existing';

      final response = await app.post('/onboarding/start', _start(await _qr(app)));

      expect(response.statusCode, 409);
      expect(await _error(response), containsPair('code', 'onboarding_already_completed'));
    });

    test('a QR for an unknown employee reveals nothing', () async {
      final app = _app();

      final response = await app.post('/onboarding/start', _start(await app.issueQr(99, TemporaryQrPurpose.onboarding)));

      expect(response.statusCode, 400);
      expect(await _error(response), containsPair('code', 'invalid_qr_code'));
    });

    test('inactive or MFD employees are refused', () async {
      final inactive = _app(active: false);
      final deleted = _app()..onboarding.markedForDeletion.add(1);

      for (final app in [inactive, deleted]) {
        final response = await app.post('/onboarding/start', _start(await _qr(app)));
        expect(response.statusCode, 403);
        expect(await _error(response), containsPair('code', 'account_inactive'));
      }
    });

    test('400 for a blank or absurd QR, or a malformed body', () async {
      final app = _app();

      expect((await app.post('/onboarding/start', _start('  '))).statusCode, 400);
      expect((await app.post('/onboarding/start', _start('x' * 2000))).statusCode, 400);
      expect((await app.post('/onboarding/start', '{oops')).statusCode, 400);
      expect((await app.post('/onboarding/start', '{}')).statusCode, 400);
    });
  });

  group('POST /onboarding/complete', () {
    test('stores an Argon2id hash of the exact password, audits, commits, uses up the QR', () async {
      final app = _app();
      final qr = await _qr(app);

      final response = await app.post('/onboarding/complete', _complete(qr, password: '  spaced pass  '));

      expect(response.statusCode, 200);
      final hash = app.onboarding.passwordHashes[1]!;
      expect(hash, startsWith(r'$argon2id$v=19$'));
      expect(await app.hasher.verify('  spaced pass  ', hash), isTrue, reason: 'never trimmed');
      final event = app.audit.events.single;
      expect(event.type, AuditEventType.onboardingCompleted);
      expect(event.references, {EventLogReference.user: 1});
      expect(app.transactions.outcomes, ['commit']);
      expect(await _error(await app.post('/onboarding/start', _start(qr))), containsPair('code', 'qr_already_used'));
    });

    test('returns a session for this device: the employee lands in the app, no second sign-in', () async {
      final app = _app();

      final response = await app.post('/onboarding/complete', _complete(await _qr(app)));
      final body = SessionResponse.fromJson(await jsonBody(response));

      expect(body.account.code, 'SBW');
      final claims = app.sessions.verify(body.session.accessToken)!;
      expect((claims.userId, claims.deviceId), (1, _device));
      expect(response.headers['cache-control'], 'no-store');
      expect((await app.getAuthorized('/me', body.session.accessToken)).statusCode, 200);
    });

    test('stores the chosen database language; English needs no row', () async {
      final dutch = _app();
      await dutch.post('/onboarding/complete', _complete(await _qr(dutch), languageCode: 'nl'));
      expect(dutch.onboarding.languages, {1: 2});

      final english = _app();
      expect((await english.post('/onboarding/complete', _complete(await _qr(english), languageCode: 'en'))).statusCode, 200);
      expect(english.onboarding.languages, isEmpty);
    });

    test('field errors come before anything is stored, and leave the QR usable', () async {
      final app = _app();
      final qr = await _qr(app);

      expect(await _error(await app.post('/onboarding/complete', _complete(qr, languageCode: 'xx'))), containsPair('field', 'languageCode'));
      expect(await _error(await app.post('/onboarding/complete', _complete(qr, deviceId: 'short'))), containsPair('field', 'deviceId'));
      expect(await _error(await app.post('/onboarding/complete', _complete(qr, password: 'short'))), containsPair('field', 'password'));
      expect(app.onboarding.passwordHashes, isEmpty);
      expect((await app.post('/onboarding/complete', _complete(qr))).statusCode, 200);
    });

    test('a used QR cannot onboard again, from any device or with any password', () async {
      final app = _app();
      final qr = await _qr(app);
      await app.post('/onboarding/complete', _complete(qr));
      final firstHash = app.onboarding.passwordHashes[1];

      final other = await app.post('/onboarding/complete', _complete(qr, deviceId: _otherDevice, password: 'attacker password'));
      final sameDeviceOtherPassword = await app.post('/onboarding/complete', _complete(qr, password: 'attacker password'));

      expect(await _error(other), containsPair('code', 'qr_already_used'));
      expect(await _error(sameDeviceOtherPassword), containsPair('code', 'onboarding_already_completed'));
      expect(app.onboarding.passwordHashes[1], firstHash, reason: 'password not replaced');
      expect(app.audit.events, hasLength(1));
    });

    test('lost answer: the same device repeating with the same QR and password gets a new session, nothing written', () async {
      final app = _app();
      final qr = await _qr(app);
      await app.post('/onboarding/complete', _complete(qr));
      final hash = app.onboarding.passwordHashes[1];

      final retry = await app.post('/onboarding/complete', _complete(qr));

      expect(retry.statusCode, 200);
      final body = SessionResponse.fromJson(await jsonBody(retry));
      expect((await app.getAuthorized('/me', body.session.accessToken)).statusCode, 200);
      expect(app.onboarding.passwordHashes[1], hash);
      expect(app.audit.events, hasLength(1), reason: 'onboarding not repeated');
      expect(app.transactions.outcomes, ['commit']);
    });

    test('a new QR for an employee who already set a password is useless', () async {
      final app = _app();
      await app.post('/onboarding/complete', _complete(await _qr(app)));

      final response = await app.post('/onboarding/complete', _complete(await _qr(app)));

      expect(await _error(response), containsPair('code', 'onboarding_already_completed'));
    });

    test('concurrent activation: the device losing the database race gets 409, nothing committed, QR released', () async {
      final app = _app()..onboarding.loseRace = true;
      final qr = await _qr(app);

      final response = await app.post('/onboarding/complete', _complete(qr));

      expect(response.statusCode, 409);
      expect(app.transactions.outcomes, ['rollback']);
      expect(app.audit.events, isEmpty);
    });

    test('concurrent requests cannot both use one QR', () async {
      final app = _app();
      final qr = await _qr(app);

      final responses = await Future.wait([
        app.post('/onboarding/complete', _complete(qr)),
        app.post('/onboarding/complete', _complete(qr, deviceId: _otherDevice)),
      ]);

      expect(responses.map((r) => r.statusCode).toList()..sort(), [200, 409]);
      expect(app.audit.events, hasLength(1));
    });

    test('the permanent Terminal QR cannot complete onboarding', () async {
      final app = _app();

      expect((await app.post('/onboarding/complete', _complete(_terminalQr))).statusCode, 400);
      expect(app.onboarding.passwordHashes, isEmpty);
    });

    test('an inactive account is refused and the QR stays unused', () async {
      final app = _app(active: false);

      expect((await app.post('/onboarding/complete', _complete(await _qr(app)))).statusCode, 403);
      expect(app.onboarding.passwordHashes, isEmpty);
    });

    test('password rules: 8..256 characters, any letters, numbers and symbols', () async {
      for (final password in ['short', '        ', 'x' * 257]) {
        final app = _app();
        final response = await app.post('/onboarding/complete', _complete(await _qr(app), password: password));
        expect(response.statusCode, 400, reason: password);
        expect(await _error(response), containsPair('field', 'password'));
      }
      for (final password in ['8 chars!', 'é' * 256, r'P@ss w0rd §€ñ 🔐']) {
        final app = _app();
        expect((await app.post('/onboarding/complete', _complete(await _qr(app), password: password))).statusCode, 200);
      }
    });

    test('neither the QR, the password nor its hash appear in responses or logs', () async {
      const password = 'Unmistakable-Pass-4471';
      final records = <String>[];
      final subscription = Logger.root.onRecord.listen((r) => records.add('${r.message} ${r.error ?? ''}'));
      addTearDown(subscription.cancel);
      final app = _app();
      final qr = await _qr(app);

      final ok = await (await app.post('/onboarding/complete', _complete(qr, password: password))).readAsString();
      final reused = await (await app.post('/onboarding/complete', _complete(qr, deviceId: _otherDevice))).readAsString();
      final hashBody = app.onboarding.passwordHashes[1]!.split(r'$').last;

      for (final text in [ok, reused, ...records]) {
        expect(text, isNot(contains(password)));
        expect(text, isNot(contains(hashBody)));
        expect(text, isNot(contains(qr)));
      }
    });
  });

  group('session authentication', () {
    Future<(TestApp, String)> onboarded() async {
      final app = _app();
      final body = SessionResponse.fromJson(
        await jsonBody(await app.post('/onboarding/complete', _complete(await _qr(app)))),
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

    test('a tampered token, a foreign one or a temporary QR used as a session is refused', () async {
      final (app, token) = await onboarded();

      expect((await app.getAuthorized('/me', '${token}x')).statusCode, 401);
      expect((await app.get('/me', headers: {'authorization': 'Basic abc'})).statusCode, 401);
      expect((await app.getAuthorized('/me', await _qr(app))).statusCode, 401, reason: 'a QR is never a sign-in');
    });
  });
}
