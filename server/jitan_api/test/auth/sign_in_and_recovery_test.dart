import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

/// The permanent Terminal QR: it never recovers an account.
const _terminalQr = 'n9Xq-2kLmPz8RtYw4VbC5dEf';
const _device = 'device-0123456789abcdef';
const _password = 'correct horse battery';

/// Employee 1 (SBW, activated with [_password]) in company 7. User 9 is the
/// HR/Admin acting through the development identity.
Future<TestApp> _app({bool active = true, bool activated = true, int? devUserId = 9}) async {
  final app = TestApp(devUserId: devUserId, activeUserIds: {if (active) 1, 9});
  app.onboarding.users = {1: (userId: 1, firstName: 'Disan', lastName: 'Ssebowa', code: 'SBW', isActive: active)};
  app.onboarding.companies = {
    1: ['Almeco'],
  };
  if (activated) app.onboarding.passwordHashes[1] = await app.hasher.hash(_password);
  app.companies.existingIds = {7, 8};
  app.employees.members = {(7, 1)};
  return app;
}

String _signIn({String code = 'SBW', String password = _password, String deviceId = _device}) =>
    jsonEncode({'code': code, 'password': password, 'deviceId': deviceId});

Future<Map<String, Object?>> _error(Response response) async =>
    (await jsonBody(response))['error']! as Map<String, Object?>;

Future<String> _tokenOf(Response response) async =>
    SessionResponse.fromJson(await jsonBody(response)).session.accessToken;

void main() {
  group('POST /auth/sign-in', () {
    test('code + password signs this device in: a session that works for GET /me', () async {
      final app = await _app();

      final response = await app.post('/auth/sign-in', _signIn());

      expect(response.statusCode, 200);
      expect(response.headers['cache-control'], 'no-store');
      final body = SessionResponse.fromJson(await jsonBody(response));
      expect(body.account.code, 'SBW');
      expect(app.sessions.verify(body.session.accessToken)!.deviceId, _device);
      expect((await app.getAuthorized('/me', body.session.accessToken)).statusCode, 200);
    });

    test('five wrong passwords block the code: even the right one is refused, and no hashing runs', () async {
      final app = await _app();
      for (var i = 0; i < 5; i++) {
        expect((await app.post('/auth/sign-in', _signIn(password: 'wrong password'))).statusCode, 401);
      }

      final response = await app.post('/auth/sign-in', _signIn());

      expect(response.statusCode, 429);
      expect(await _error(response), containsPair('code', ApiErrorCode.tooManyAttempts));
    });

    test('a code that does not exist is blocked the same way: nothing shows which codes are real', () async {
      final app = await _app();
      for (var i = 0; i < 5; i++) {
        await app.post('/auth/sign-in', _signIn(code: 'NOBODY'));
      }

      expect((await app.post('/auth/sign-in', _signIn(code: 'NOBODY'))).statusCode, 429);
      expect((await app.post('/auth/sign-in', _signIn())).statusCode, 200, reason: 'other codes are not affected');
    });

    test('signing in clears the count', () async {
      final app = await _app();
      for (var i = 0; i < 4; i++) {
        await app.post('/auth/sign-in', _signIn(password: 'wrong password'));
      }
      await app.post('/auth/sign-in', _signIn());

      for (var i = 0; i < 4; i++) {
        await app.post('/auth/sign-in', _signIn(password: 'wrong password'));
      }
      expect((await app.post('/auth/sign-in', _signIn())).statusCode, 200);
    });

    test('wrong password, unknown code and a never-activated employee get the same generic answer', () async {
      final wrongPassword = await (await _app()).post('/auth/sign-in', _signIn(password: 'wrong password'));
      final unknownCode = await (await _app()).post('/auth/sign-in', _signIn(code: 'NOBODY'));
      final notActivated = await (await _app(activated: false)).post('/auth/sign-in', _signIn());

      final bodies = [
        for (final r in [wrongPassword, unknownCode, notActivated]) (r.statusCode, await r.readAsString()),
      ];
      expect(bodies.map((b) => b.$1), everyElement(401));
      expect(bodies.map((b) => b.$2).toSet(), hasLength(1), reason: 'identical: nothing reveals which field was wrong');
      expect(jsonDecode(bodies.first.$2), {
        'error': {'code': 'invalid_credentials', 'message': 'The employee code or password is incorrect.'},
      });
    });

    test('inactive or MFD employee: refused as "account unavailable", but only with the correct password', () async {
      final inactive = await _app(active: false);
      final deleted = await _app();
      deleted.onboarding.markedForDeletion.add(1);

      for (final app in [inactive, deleted]) {
        final right = await app.post('/auth/sign-in', _signIn());
        final wrong = await app.post('/auth/sign-in', _signIn(password: 'wrong password'));
        expect((right.statusCode, (await _error(right))['code']), (403, 'account_inactive'));
        expect((wrong.statusCode, (await _error(wrong))['code']), (401, 'invalid_credentials'));
      }
    });

    test('a malformed request or device id is refused before any password check', () async {
      final app = await _app();

      expect((await app.post('/auth/sign-in', '{oops')).statusCode, 400);
      expect((await app.post('/auth/sign-in', jsonEncode({'code': 'SBW'}))).statusCode, 400);
      expect(await _error(await app.post('/auth/sign-in', _signIn(deviceId: 'short'))), containsPair('field', 'deviceId'));
    });

    test('signing in changes nothing stored', () async {
      final app = await _app();
      final hash = app.onboarding.passwordHashes[1];

      await app.post('/auth/sign-in', _signIn());
      await app.post('/auth/sign-in', _signIn(password: 'wrong password'));

      expect(app.onboarding.passwordHashes[1], hash);
      expect(app.audit.events, isEmpty);
    });
  });

  group('POST /me/password (trusted signed-in device)', () {
    Future<(TestApp, String)> signedIn() async {
      final app = await _app(devUserId: null);
      return (app, await _tokenOf(await app.post('/auth/sign-in', _signIn())));
    }

    String change(String password, {String current = _password}) =>
        jsonEncode({'currentPassword': current, 'newPassword': password});

    test('sets a new Argon2id password, audited; this device stays signed in, others are signed out', () async {
      final (app, token) = await signedIn();
      final otherDevice = await _tokenOf(await app.post('/auth/sign-in', _signIn(deviceId: 'device-other-000000000')));

      final response = await app.postAuthorized('/me/password', change('a brand new password'), token);

      expect(response.statusCode, 200);
      final newToken = await _tokenOf(response);
      expect(app.sessions.verify(newToken)!.deviceId, _device);
      expect((await app.getAuthorized('/me', newToken)).statusCode, 200);
      expect((await app.getAuthorized('/me', token)).statusCode, 401, reason: 'old session of this device');
      expect((await app.getAuthorized('/me', otherDevice)).statusCode, 401, reason: 'other devices signed out');

      final hash = app.onboarding.passwordHashes[1]!;
      expect(hash, startsWith(r'$argon2id$'));
      expect(await app.hasher.verify('a brand new password', hash), isTrue);
      expect(await app.hasher.verify(_password, hash), isFalse);
      final event = app.audit.events.single;
      expect(event.type, AuditEventType.passwordChanged);
      expect(event.references, {EventLogReference.user: 1});
      expect(app.transactions.outcomes, ['commit']);
    });

    test('a wrong current password is refused on its field; nothing changes, no session ends', () async {
      final (app, token) = await signedIn();

      final wrong = await app.postAuthorized('/me/password', change('a brand new password', current: 'not mine'), token);

      expect(wrong.statusCode, 400);
      expect(await _error(wrong), containsPair('field', 'currentPassword'));
      expect(await app.hasher.verify(_password, app.onboarding.passwordHashes[1]!), isTrue, reason: 'unchanged');
      expect(app.audit.events, isEmpty);
      expect((await app.getAuthorized('/me', token)).statusCode, 200, reason: 'still signed in');
    });

    test('the new password must follow the policy', () async {
      final (app, token) = await signedIn();

      final tooShort = await app.postAuthorized('/me/password', change('short'), token);

      expect(tooShort.statusCode, 400);
      expect(await _error(tooShort), containsPair('field', 'newPassword'));
      expect(await app.hasher.verify(_password, app.onboarding.passwordHashes[1]!), isTrue, reason: 'unchanged');
    });

    test('a locked-out employee cannot change or clear the password without a session', () async {
      final app = await _app(devUserId: null);

      expect((await app.post('/me/password', change('a brand new password'))).statusCode, 401);
      expect(await app.hasher.verify(_password, app.onboarding.passwordHashes[1]!), isTrue);
    });
  });

  group('Reset account access + temporary recovery QR (HR/Admin)', () {
    const path = '/companies/7/employees/1/reset-access';
    const recoveryQrPath = '/companies/7/employees/1/recovery-qr';
    const otherDevice = 'device-fedcba9876543210';

    String complete(String qr, {String password = 'my new password', String deviceId = _device}) =>
        jsonEncode({'qrCode': qr, 'password': password, 'deviceId': deviceId});

    Future<String> recoveryQr(TestApp app) async =>
        TemporaryQrResponse.fromJson(await jsonBody(await app.post(recoveryQrPath, ''))).qrCode;

    test('reset clears the password, audited, and signs every device out', () async {
      final app = await _app();
      final employeeSession = await _tokenOf(await app.post('/auth/sign-in', _signIn()));

      final response = await app.post(path, '');

      expect(response.statusCode, 204);
      expect(app.onboarding.passwordHashes.containsKey(1), isFalse, reason: 'userPassword = NULL');
      final event = app.audit.events.single;
      expect(event.type, AuditEventType.accountAccessReset);
      expect(event.actorUserId, 9);
      expect(event.references, {EventLogReference.user: 1, EventLogReference.company: 7});
      expect((await app.getAuthorized('/me', employeeSession)).statusCode, 401);
    });

    test('recovery before the reset: no recovery QR is generated, and a recovery QR is refused', () async {
      final app = await _app();
      final hash = app.onboarding.passwordHashes[1];

      final generate = await app.post(recoveryQrPath, '');
      final qr = await app.issueQr(1, TemporaryQrPurpose.recovery);
      final start = await app.post('/recovery/start', jsonEncode({'qrCode': qr}));
      final finish = await app.post('/recovery/complete', complete(qr, password: 'attacker password'));

      expect((generate.statusCode, (await _error(generate))['code']), (409, 'account_not_reset'));
      expect((start.statusCode, (await _error(start))['code']), (409, 'account_not_reset'));
      expect((finish.statusCode, (await _error(finish))['code']), (409, 'account_not_reset'));
      expect(app.onboarding.passwordHashes[1], hash);
    });

    test('a never-activated employee (no password, no reset) cannot recover, even with a recovery QR', () async {
      final app = await _app(activated: false);

      final generate = await app.post(recoveryQrPath, '');
      final qr = await app.issueQr(1, TemporaryQrPurpose.recovery);
      final start = await app.post('/recovery/start', jsonEncode({'qrCode': qr}));
      final finish = await app.post('/recovery/complete', complete(qr));

      expect((generate.statusCode, (await _error(generate))['code']), (409, 'account_not_reset'));
      expect((start.statusCode, (await _error(start))['code']), (409, 'account_not_reset'));
      expect((finish.statusCode, (await _error(finish))['code']), (409, 'account_not_reset'));
      expect(app.onboarding.passwordHashes.containsKey(1), isFalse);
    });

    test('a reset employee cannot use onboarding instead of recovery', () async {
      final app = await _app();
      await app.post(path, '');
      final qr = await app.issueQr(1, TemporaryQrPurpose.onboarding);

      final start = await app.post('/onboarding/start', jsonEncode({'qrCode': qr}));
      final finish = await app.post(
        '/onboarding/complete',
        jsonEncode({'qrCode': qr, 'password': 'my new password', 'deviceId': _device}),
      );

      expect((start.statusCode, (await _error(start))['code']), (409, 'onboarding_already_completed'));
      expect((finish.statusCode, (await _error(finish))['code']), (409, 'onboarding_already_completed'));
      expect(app.onboarding.passwordHashes.containsKey(1), isFalse);
    });

    test('Employee details tells HR/Admin a reset is pending (so the recovery QR applies)', () async {
      final app = await _app();
      app.employees.details[(7, 1)] = const EmployeeDetails(
        id: 1, companyId: 7, companyName: 'Almeco', firstName: 'Disan', lastName: 'Ssebowa',
        code: 'SBW', groups: [], phone: null, isActive: true, isActivated: false,
      );
      expect((await jsonBody(await app.get('/companies/7/employees/1')))['accessResetPending'], isFalse);

      await app.post(path, '');

      expect((await jsonBody(await app.get('/companies/7/employees/1')))['accessResetPending'], isTrue);
    });

    test('the permanent Terminal QR cannot authorize recovery', () async {
      final app = await _app();
      await app.post(path, '');

      final start = await app.post('/recovery/start', jsonEncode({'qrCode': _terminalQr}));
      final finish = await app.post('/recovery/complete', complete(_terminalQr));

      expect((start.statusCode, (await _error(start))['code']), (400, 'invalid_qr_code'));
      expect(finish.statusCode, 400);
      expect(app.onboarding.passwordHashes.containsKey(1), isFalse);
    });

    test('full recovery: reset → recovery QR → new password → fresh session; the QR then works no more', () async {
      final app = await _app();
      final oldSession = await _tokenOf(await app.post('/auth/sign-in', _signIn()));
      await app.post(path, '');
      final qr = await recoveryQr(app);

      final start = await app.post('/recovery/start', jsonEncode({'qrCode': qr}));
      final finish = await app.post('/recovery/complete', complete(qr));

      expect(start.statusCode, 200);
      expect(await jsonBody(start), containsPair('code', 'SBW'));
      expect(finish.statusCode, 200);
      expect(finish.headers['cache-control'], 'no-store');
      final hash = app.onboarding.passwordHashes[1]!;
      expect(hash, startsWith(r'$argon2id$v=19$'));
      expect(await app.hasher.verify('my new password', hash), isTrue);
      expect((await app.getAuthorized('/me', await _tokenOf(finish))).statusCode, 200, reason: 'fresh session');
      expect((await app.getAuthorized('/me', oldSession)).statusCode, 401, reason: 'old sessions stay revoked');
      expect(app.audit.events.map((e) => e.type), [
        AuditEventType.accountAccessReset,
        AuditEventType.recoveryQrGenerated,
        AuditEventType.accessRecovered,
      ]);
      expect(await _error(await app.post('/recovery/start', jsonEncode({'qrCode': qr}))), containsPair('code', 'qr_already_used'));
      expect((await app.post('/recovery/complete', complete(qr, deviceId: otherDevice))).statusCode, 409);
      expect((await app.post('/auth/sign-in', _signIn(password: 'my new password'))).statusCode, 200);
    });

    test('an interrupted recovery can be finished safely by the same device, never by another', () async {
      final app = await _app();
      await app.post(path, '');
      final qr = await recoveryQr(app);
      await app.post('/recovery/complete', complete(qr));
      final hash = app.onboarding.passwordHashes[1];

      final retry = await app.post('/recovery/complete', complete(qr));
      final otherPassword = await app.post('/recovery/complete', complete(qr, password: 'a different password'));
      final otherDevice_ = await app.post('/recovery/complete', complete(qr, deviceId: otherDevice));

      expect(retry.statusCode, 200);
      expect((await app.getAuthorized('/me', await _tokenOf(retry))).statusCode, 200);
      expect(await _error(otherPassword), containsPair('code', 'account_not_reset'));
      expect(await _error(otherDevice_), containsPair('code', 'qr_already_used'));
      expect(app.onboarding.passwordHashes[1], hash, reason: 'set once');
      expect(app.audit.events.where((e) => e.type == AuditEventType.accessRecovered), hasLength(1));
    });

    test('an onboarding QR cannot be used for recovery, nor a recovery QR for onboarding', () async {
      final app = await _app();
      await app.post(path, '');
      final onboardingQr = await app.issueQr(1, TemporaryQrPurpose.onboarding);
      final qr = await recoveryQr(app);

      expect(await _error(await app.post('/recovery/start', jsonEncode({'qrCode': onboardingQr}))), containsPair('code', 'qr_wrong_purpose'));
      expect(await _error(await app.post('/onboarding/start', jsonEncode({'qrCode': qr}))), containsPair('code', 'qr_wrong_purpose'));
    });

    test('a new recovery QR invalidates the previous one', () async {
      final app = await _app();
      await app.post(path, '');
      final first = await recoveryQr(app);
      final second = await recoveryQr(app);

      expect(await _error(await app.post('/recovery/start', jsonEncode({'qrCode': first}))), containsPair('code', 'qr_expired'));
      expect((await app.post('/recovery/complete', complete(second))).statusCode, 200);
    });

    test('an expired recovery QR is refused', () async {
      final app = await _app();
      await app.post(path, '');
      final qr = await recoveryQr(app);
      app.now = app.now.add(const Duration(minutes: 10));

      expect(await _error(await app.post('/recovery/complete', complete(qr))), containsPair('code', 'qr_expired'));
      expect(app.onboarding.passwordHashes.containsKey(1), isFalse);
    });

    test('an employee disabled after the reset cannot recover', () async {
      final app = await _app();
      await app.post(path, '');
      final qr = await recoveryQr(app);
      app.onboarding.users = {1: (userId: 1, firstName: 'Disan', lastName: 'Ssebowa', code: 'SBW', isActive: false)};

      expect(await _error(await app.post('/recovery/complete', complete(qr))), containsPair('code', 'account_inactive'));
    });

    test('an employee who never activated has nothing to reset', () async {
      final app = await _app(activated: false);

      final response = await app.post(path, '');

      expect(response.statusCode, 409);
      expect(await _error(response), containsPair('code', 'account_not_activated'));
      expect(app.audit.events, isEmpty);
    });

    test('scoped to the company: another company, an unknown company or employee is 404', () async {
      final app = await _app();

      expect((await app.post('/companies/8/employees/1/reset-access', '')).statusCode, 404);
      expect((await app.post('/companies/99/employees/1/reset-access', '')).statusCode, 404);
      expect((await app.post('/companies/7/employees/2/reset-access', '')).statusCode, 404);
      expect(app.onboarding.passwordHashes.containsKey(1), isTrue);
    });

    test('HR/Admin only: refused without the permission, and nobody can reset their own access', () async {
      final noPermission = TestApp(devUserId: 9, activeUserIds: {1, 9}, allowPermissions: false);
      expect((await noPermission.post(path, '')).statusCode, 403);

      final self = await _app(devUserId: 1);
      final response = await self.post(path, '');
      expect(response.statusCode, 403);
      expect(self.onboarding.passwordHashes.containsKey(1), isTrue);
    });
  });

  test('passwords and hashes never appear in responses or logs', () async {
    const secret = 'Unmistakable-Pass-4471';
    final records = <String>[];
    final subscription = Logger.root.onRecord.listen((r) => records.add('${r.message} ${r.error ?? ''}'));
    addTearDown(subscription.cancel);
    final app = await _app(devUserId: null);
    final token = await _tokenOf(await app.post('/auth/sign-in', _signIn()));

    final texts = [
      await (await app.post('/auth/sign-in', _signIn(password: secret))).readAsString(),
      await (await app.postAuthorized(
        '/me/password',
        jsonEncode({'currentPassword': _password, 'newPassword': secret}),
        token,
      )).readAsString(),
      await (await app.post('/auth/sign-in', _signIn(password: secret))).readAsString(),
      ...records,
    ];

    final hashBody = app.onboarding.passwordHashes[1]!.split(r'$').last;
    for (final text in texts) {
      expect(text, isNot(contains(secret)));
      expect(text, isNot(contains(hashBody)));
      expect(text, isNot(contains('argon2id')));
    }
  });
}
