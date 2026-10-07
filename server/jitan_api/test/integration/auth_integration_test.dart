@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/auth/credential_repository.dart';
import 'package:jitan_api/src/auth/password_hasher.dart';
import 'package:jitan_api/src/auth/session_tokens.dart';
import 'package:jitan_api/src/auth/sign_in_service.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/languages/language_repository.dart';
import 'package:jitan_api/src/onboarding/onboarding_repository.dart';
import 'package:jitan_api/src/onboarding/onboarding_service.dart';
import 'package:jitan_api/src/users/user_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Sign-in and "Reset account access" against real MySQL with `[DEV-TEST]`
/// users, removed in tearDown.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final userIds = <int>[];
  final sessions = SessionTokens(secret: 'integration-session-secret-32-chars-min', lifetime: const Duration(days: 1));
  const hasher = PasswordHasher(parameters: Argon2idParameters(memoryKiB: 8192, iterations: 1));
  const credentials = CredentialRepository();

  OnboardingService onboarding() => OnboardingService(
    onboarding: const OnboardingRepository(),
    languages: LanguageRepository(db),
    audit: const AuditLogRepository(),
    transactions: db,
    executor: db,
    sessions: sessions,
    hasher: hasher,
  );

  SignInService signIn() =>
      SignInService(credentials: credentials, users: UserRepository(db), executor: db, sessions: sessions, hasher: hasher);

  Future<(int, String, String)> activatedEmployee(String suffix, {bool active = true, bool mfd = false}) async {
    final code = 'DTA$stamp$suffix';
    final qr = 'DEV-TEST-AUTH-$stamp-$suffix';
    final id = (await db.execute(
      'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
      "VALUES ('[DEV-TEST]', 'Auth', :code, :qr, 1, 0)",
      {'code': code, 'qr': qr},
    )).lastInsertId;
    userIds.add(id);
    await onboarding().complete(
      OnboardingCompleteRequest(qrCode: qr, password: 'first password', deviceId: 'device-AAAAAAAAAAAAAAAA'),
    );
    await db.execute('UPDATE tblUser SET userActive = :a, userMFD = :m WHERE userID = :id', {
      'a': active,
      'm': mfd,
      'id': id,
    });
    return (id, code, qr);
  }

  setUpAll(() => db = TestDatabase.connect());

  tearDownAll(() async {
    for (final id in userIds) {
      final logs = await db.query('SELECT eventLogID FROM tblEventLog WHERE userIDTarget = :id', {'id': id});
      for (final log in logs) {
        await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
        await db.execute('DELETE FROM tblEventLog WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
      }
      await db.execute('DELETE FROM tblUserLanguage WHERE userID = :id', {'id': id});
      await db.execute('DELETE FROM tblUser WHERE userID = :id', {'id': id});
    }
    await db.close();
  });

  Matcher fails(String code) => throwsA(isA<ApiException>().having((e) => e.code, 'code', code));

  SignInRequest request(String code, String password) =>
      SignInRequest(code: code, password: password, deviceId: 'device-BBBBBBBBBBBBBBBB');

  test('sign-in verifies the stored Argon2id hash; failures are generic', () async {
    final (id, code, _) = await activatedEmployee('S');

    final result = await signIn().signIn(request(code, 'first password'));

    expect(sessions.verify(result.session.accessToken)!.userId, id);
    await expectLater(signIn().signIn(request(code, 'wrong password')), fails('invalid_credentials'));
    await expectLater(signIn().signIn(request('DTA-unknown-$stamp', 'first password')), fails('invalid_credentials'));
  });

  test('inactive and MFD employees are refused with the correct password', () async {
    final (_, inactive, _) = await activatedEmployee('I', active: false);
    final (_, deleted, _) = await activatedEmployee('M', mfd: true);

    await expectLater(signIn().signIn(request(inactive, 'first password')), fails('account_inactive'));
    await expectLater(signIn().signIn(request(deleted, 'first password')), fails('account_inactive'));
  });

  test('reset clears userPassword, keeps userQRcode; the QR then sets up a new password once', () async {
    final (id, code, qr) = await activatedEmployee('R');

    final cleared = await db.transaction((tx) => credentials.clearPassword(tx, id));
    final row = (await db.query('SELECT userPassword, userQRcode FROM tblUser WHERE userID = :id', {'id': id})).single;

    expect(cleared, isTrue);
    expect(row.readOptionalString('userPassword'), isNull);
    expect(row.readString('userQRcode'), qr);
    expect(await db.transaction((tx) => credentials.clearPassword(tx, id)), isFalse, reason: 'nothing left to clear');

    await onboarding().complete(
      OnboardingCompleteRequest(qrCode: qr, password: 'second password', deviceId: 'device-CCCCCCCCCCCCCCCC'),
    );
    expect((await signIn().signIn(request(code, 'second password'))).account.code, code);
    await expectLater(onboarding().start(qr), fails('onboarding_already_completed'));
  });
}
