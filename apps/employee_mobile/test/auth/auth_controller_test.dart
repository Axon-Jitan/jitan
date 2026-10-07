import 'package:employee_mobile/src/auth/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';

import '../support/fake_jitan_server.dart';

void main() {
  late TestHarness h;
  late AuthController c;
  final signedIn = <EmployeeAccount>[];

  setUp(() {
    h = TestHarness()..server.password = 'correct horse battery';
    signedIn.clear();
    c = AuthController(
      authApi: h.services.authApi,
      onboardingApi: h.services.onboardingApi,
      session: h.session,
      onSignedIn: signedIn.add,
    );
  });

  test('success stores the session and reports the account; nothing else is kept', () async {
    await c.signIn(' SBW ', 'correct horse battery');

    expect(signedIn.single.code, 'SBW');
    expect(h.session.accessToken, h.server.issuedTokens.single);
  });

  test('maps server answers to the Figma auth error screens', () async {
    await c.signIn('SBW', 'wrong password');
    expect(c.problem, AuthProblem.invalidCredentials);

    h.server.active = false;
    await c.signIn('SBW', 'correct horse battery');
    expect(c.problem, AuthProblem.accountUnavailable);

    h.server
      ..active = true
      ..dropNext.add('/auth/sign-in');
    await c.signIn('SBW', 'correct horse battery');
    expect(c.problem, AuthProblem.unreachable);

    await c.retry();
    expect(signedIn, hasLength(1), reason: 'retry resends the same credentials');
  });

  test('an empty code or password is never sent', () async {
    await c.signIn('  ', 'x');
    await c.signIn('SBW', '');
    expect(h.server.requests, isEmpty);
  });

  test('forgot password sends nothing, resets nothing, and leads to Recover with QR', () {
    c.openForgotPassword();
    c.submitForgotPassword(' SBW ');

    expect((c.step, c.code), (AuthStep.recoverWithQr, 'SBW'));
    expect(h.server.requests, isEmpty);
  });

  group('recovery with the existing QR', () {
    test('refused while a password is set (no HR/Admin reset); an unknown QR the same', () async {
      c.openRecovery();
      await c.submitRecoveryQr(testQr);
      expect((c.step, c.recoveryRefused), (AuthStep.recoverWithQr, true));

      c.openRecovery();
      await c.submitRecoveryQr('not-a-jitan-qr');
      expect(c.recoveryRefused, isTrue, reason: 'nothing reveals whether the QR exists');
    });

    test('allowed after the reset: new password, fresh session, signed in', () async {
      h.server.password = null;
      c.openRecovery();
      await c.submitRecoveryQr(testQr);
      expect(c.step, AuthStep.setNewPassword);

      await c.submitNewPassword('my new password', 'my new password');

      expect(signedIn.single.code, 'SBW');
      expect(h.server.password, 'my new password');
      expect(h.session.accessToken, h.server.issuedTokens.single);
    });

    test('another device set the password first: refused, back to scanning', () async {
      h.server.password = null;
      c.openRecovery();
      await c.submitRecoveryQr(testQr);
      h.server.anotherDeviceWins = true;

      await c.submitNewPassword('my new password', 'my new password');

      expect((c.step, c.recoveryRefused), (AuthStep.recoverWithQr, true));
      expect(signedIn, isEmpty);
    });

    test('an inactive employee gets "Account unavailable"', () async {
      h.server
        ..password = null
        ..active = false;
      c.openRecovery();
      await c.submitRecoveryQr(testQr);
      expect(c.problem, AuthProblem.accountUnavailable);
    });
  });

  test('passwords never reach the logs, also on failures and retries', () async {
    const password = 'Unmistakable-Pass-4471';
    h.server.password = password;
    final records = <String>[];
    final previous = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen((r) => records.add('${r.message} ${r.error ?? ''}'));
    addTearDown(() {
      subscription.cancel();
      Logger.root.level = previous;
    });

    await c.signIn('SBW', 'wrong-$password');
    h.server.dropNext.add('/auth/sign-in');
    await c.signIn('SBW', password);
    await c.retry();

    expect(signedIn, hasLength(1));
    expect(records, isNotEmpty);
    for (final record in records) {
      expect(record, isNot(contains(password)));
    }
  });
}
