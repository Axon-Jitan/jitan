import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _qr = 'n9Xq-2kLmPz8RtYw4VbC5dEf';

/// No dev identity: onboarding works without sign-in (the QR is the credential).
TestApp _app({bool active = true}) {
  final app = TestApp(devUserId: null);
  app.onboarding.users = {_qr: (userId: 1, firstName: 'Disan', lastName: 'Ssebowa', code: 'SBW', isActive: active)};
  app.onboarding.companies = {1: ['Almeco', 'PCA']};
  return app;
}

Future<Map<String, Object?>> _error(Response response) async =>
    (await jsonBody(response))['error']! as Map<String, Object?>;

String _start([String qr = _qr]) => jsonEncode({'qrCode': qr});
String _complete({String qr = _qr, String password = 'correct horse'}) =>
    jsonEncode({'qrCode': qr, 'password': password});

void main() {
  group('POST /onboarding/start', () {
    test('a not-yet-onboarded employee gets the account to confirm, without sign-in', () async {
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

    test('409 onboarding_already_completed once a password is set', () async {
      final app = _app()..onboarding.passwordHashes[1] = r'$2b$04$existing';

      final response = await app.post('/onboarding/start', _start());

      expect(response.statusCode, 409);
      expect(await _error(response), containsPair('code', 'onboarding_already_completed'));
    });

    test('404 invalid_qr_code for an unknown QR (nothing revealed)', () async {
      final response = await _app().post('/onboarding/start', _start('not-a-real-qr'));

      expect(response.statusCode, 404);
      expect(await _error(response), containsPair('code', 'invalid_qr_code'));
    });

    test('403 account_inactive for a disabled employee', () async {
      final response = await _app(active: false).post('/onboarding/start', _start());

      expect(response.statusCode, 403);
      expect(await _error(response), containsPair('code', 'account_inactive'));
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
    test('stores a bcrypt hash of the exact password, audits, commits', () async {
      final app = _app();

      final response = await app.post('/onboarding/complete', _complete(password: '  spaced pass  '));

      expect(response.statusCode, 200);
      expect(await jsonBody(response), containsPair('code', 'SBW'));
      final hash = app.onboarding.passwordHashes[1]!;
      expect(hash, startsWith(r'$2b$'));
      expect(hash, isNot(contains('spaced')));
      expect(await app.hasher.verify('  spaced pass  ', hash), isTrue, reason: 'never trimmed');
      expect(await app.hasher.verify('spaced pass', hash), isFalse);
      final event = app.audit.events.single;
      expect(event.type, AuditEventType.onboardingCompleted);
      expect(event.actorUserId, 1);
      expect(event.references, {EventLogReference.user: 1});
      expect(app.transactions.outcomes, ['commit']);
    });

    test('after completion the same QR cannot restart or redo onboarding', () async {
      final app = _app();
      await app.post('/onboarding/complete', _complete());
      final firstHash = app.onboarding.passwordHashes[1];

      final restart = await app.post('/onboarding/start', _start());
      final redo = await app.post('/onboarding/complete', _complete(password: 'attacker pass'));

      expect(restart.statusCode, 409);
      expect(redo.statusCode, 409);
      expect(await _error(redo), containsPair('code', 'onboarding_already_completed'));
      expect(app.onboarding.passwordHashes[1], firstHash, reason: 'password not replaced');
      expect(app.audit.events, hasLength(1));
    });

    test('a device losing the race to another gets 409 and the transaction rolls back', () async {
      final app = _app()..onboarding.loseRace = true;

      final response = await app.post('/onboarding/complete', _complete());

      expect(response.statusCode, 409);
      expect(app.transactions.outcomes, ['rollback']);
      expect(app.audit.events, isEmpty);
    });

    test('password rules: at least 8 characters, at most 72 bytes; errors name the field', () async {
      final app = _app();

      for (final password in ['short', '        ', 'x' * 73, 'é' * 37]) {
        final response = await app.post('/onboarding/complete', _complete(password: password));
        expect(response.statusCode, 400, reason: password);
        expect(await _error(response), containsPair('field', 'password'));
      }
      expect(app.onboarding.passwordHashes, isEmpty);
    });

    test('a valid password is accepted at both limits', () async {
      expect((await _app().post('/onboarding/complete', _complete(password: '8 chars!'))).statusCode, 200);
      expect((await _app().post('/onboarding/complete', _complete(password: 'x' * 72))).statusCode, 200);
    });

    test('an inactive or unknown account is refused before hashing', () async {
      expect((await _app(active: false).post('/onboarding/complete', _complete())).statusCode, 403);
      expect((await _app().post('/onboarding/complete', _complete(qr: 'unknown'))).statusCode, 404);
    });
  });
}
