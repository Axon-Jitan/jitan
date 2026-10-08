@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_event.dart';
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
import 'package:jitan_api/src/recovery/recovery_service.dart';
import 'package:jitan_api/src/temporary_qr/in_memory_temporary_token_store.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_service.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_tokens.dart';
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
  final temporaryQr = TemporaryQrService(tokens: TemporaryQrTokens.withRandomKey(), store: InMemoryTemporaryTokenStore());

  OnboardingService onboarding() => OnboardingService(
    onboarding: const OnboardingRepository(),
    languages: LanguageRepository(db),
    audit: const AuditLogRepository(),
    transactions: db,
    executor: db,
    sessions: sessions,
    temporaryQr: temporaryQr,
    hasher: hasher,
  );

  RecoveryService recovery() => RecoveryService(
    accounts: const OnboardingRepository(),
    credentials: credentials,
    audit: const AuditLogRepository(),
    transactions: db,
    executor: db,
    sessions: sessions,
    temporaryQr: temporaryQr,
    hasher: hasher,
  );

  Future<String> qrFor(int userId, TemporaryQrPurpose purpose) async => (await temporaryQr.issue(userId, purpose)).token;

  /// Reset account access as the service does it: password cleared and the
  /// reset recorded in the same transaction.
  Future<bool> resetAccess(int id) => db.transaction((tx) async {
    final cleared = await credentials.clearPassword(tx, id);
    if (cleared) {
      await const AuditLogRepository().record(
        tx,
        AuditEvent(type: AuditEventType.accountAccessReset, actorUserId: id, references: {EventLogReference.user: id}),
      );
    }
    return cleared;
  });

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
      OnboardingCompleteRequest(
        qrCode: await qrFor(id, TemporaryQrPurpose.onboarding),
        password: 'first password',
        deviceId: 'device-AAAAAAAAAAAAAAAA',
      ),
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

  test('reset clears userPassword, keeps userQRcode; a temporary recovery QR sets a new password once', () async {
    final (id, code, terminalQr) = await activatedEmployee('R');

    final cleared = await resetAccess(id);
    final row = (await db.query('SELECT userPassword, userQRcode FROM tblUser WHERE userID = :id', {'id': id})).single;

    expect(cleared, isTrue);
    expect(row.readOptionalString('userPassword'), isNull);
    expect(row.readString('userQRcode'), terminalQr);
    expect(await UserRepository(db).activePasswordHash(id), isNull, reason: 'old sessions no longer verify');

    await expectLater(recovery().start(terminalQr), fails('invalid_qr_code'));
    final qr = await qrFor(id, TemporaryQrPurpose.recovery);
    final result = await recovery().complete(
      RecoveryCompleteRequest(qrCode: qr, password: 'second password', deviceId: 'device-CCCCCCCCCCCCCCCC'),
    );

    expect(sessions.verify(result.session.accessToken)!.userId, id);
    expect((await signIn().signIn(request(code, 'second password'))).account.code, code);
    expect(
      (await db.query('SELECT userQRcode FROM tblUser WHERE userID = :id', {'id': id})).single.readString('userQRcode'),
      terminalQr,
    );
    await expectLater(recovery().start(qr), fails('qr_already_used'));
    await expectLater(recovery().start(await qrFor(id, TemporaryQrPurpose.recovery)), fails('account_not_reset'));
  });

  test('an interrupted recovery: the same device retrying finishes once; the password is set once', () async {
    final (id, code, _) = await activatedEmployee('Y');
    await resetAccess(id);
    final qr = await qrFor(id, TemporaryQrPurpose.recovery);
    RecoveryCompleteRequest finish(String device) =>
        RecoveryCompleteRequest(qrCode: qr, password: 'recovered pass', deviceId: device);

    await recovery().complete(finish('device-DDDDDDDDDDDDDDDD'));
    final hash = await UserRepository(db).activePasswordHash(id);
    final again = await recovery().complete(finish('device-DDDDDDDDDDDDDDDD'));

    expect(sessions.verify(again.session.accessToken)!.userId, id);
    expect(await UserRepository(db).activePasswordHash(id), hash);
    await expectLater(recovery().complete(finish('device-EEEEEEEEEEEEEEEE')), fails('qr_already_used'));
    final recovered = await db.query(
      'SELECT COUNT(*) AS n FROM tblEventLog l JOIN tblEventLogEventType et ON et.eventLogID = l.eventLogID '
      'JOIN tblEventType t ON t.eventTypeID = et.eventTypeID '
      'WHERE l.userIDTarget = :id AND t.eventTypeName = :type',
      {'id': id, 'type': 'employee.access.recovered'},
    );
    expect(recovered.single.readInt('n'), 1);
    expect((await signIn().signIn(request(code, 'recovered pass'))).account.code, code);
  });

  test('onboarding and recovery stay separate on MySQL: the reset event is what allows recovery', () async {
    final (id, _, _) = await activatedEmployee('Z');
    await db.execute('UPDATE tblUser SET userPassword = NULL WHERE userID = :id', {'id': id});

    await expectLater(
      recovery().start(await qrFor(id, TemporaryQrPurpose.recovery)),
      fails('account_not_reset'),
      reason: 'no password but no recorded reset: not an HR-authorized recovery',
    );

    await db.execute('UPDATE tblUser SET userPassword = :p WHERE userID = :id', {'p': r'$argon2id$placeholder', 'id': id});
    await resetAccess(id);
    expect((await recovery().start(await qrFor(id, TemporaryQrPurpose.recovery))).code, 'DTA${stamp}Z');
    await expectLater(onboarding().start(await qrFor(id, TemporaryQrPurpose.onboarding)), fails('onboarding_already_completed'));
  });
}
