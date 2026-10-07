@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/auth/password_hasher.dart';
import 'package:jitan_api/src/auth/session_tokens.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/languages/language_repository.dart';
import 'package:jitan_api/src/onboarding/onboarding_repository.dart';
import 'package:jitan_api/src/onboarding/onboarding_service.dart';
import 'package:jitan_api/src/users/user_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// The re-onboarding guard and session against real MySQL, including two
/// devices completing at the same moment.
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

  OnboardingService service() => OnboardingService(
    onboarding: const OnboardingRepository(),
    languages: LanguageRepository(db),
    audit: const AuditLogRepository(),
    transactions: db,
    executor: db,
    sessions: sessions,
    hasher: hasher,
  );

  OnboardingCompleteRequest complete(String qr, String password, {String device = 'device-AAAAAAAAAAAAAAAA'}) =>
      OnboardingCompleteRequest(qrCode: qr, password: password, deviceId: device);

  Future<String> newEmployee(String suffix) async {
    final qr = 'DEV-TEST-ONB-$stamp-$suffix';
    userIds.add(
      (await db.execute(
        'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
        "VALUES ('[DEV-TEST]', 'Onboarding', :code, :qr, 1, 0)",
        {'code': 'DT$stamp$suffix', 'qr': qr},
      )).lastInsertId,
    );
    return qr;
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

  Matcher alreadyCompleted() =>
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'onboarding_already_completed'));

  test('start → complete stores an Argon2id hash and signs in; the QR cannot restart onboarding', () async {
    final qr = await newEmployee('A');
    expect((await service().start(qr)).code, 'DT${stamp}A');

    final result = await service().complete(complete(qr, 'correct horse battery'));

    final row = (await db.query('SELECT userPassword, userQRcode FROM tblUser WHERE userID = :id', {
      'id': userIds.last,
    })).single;
    final hash = row.readString('userPassword');
    expect(hash, startsWith(r'$argon2id$v=19$'));
    expect(await hasher.verify('correct horse battery', hash), isTrue);
    expect(row.readString('userQRcode'), qr, reason: 'the QR stays the same for Terminal use');

    final claims = sessions.verify(result.session.accessToken)!;
    expect(claims.userId, userIds.last);
    expect(
      sessions.passwordFingerprint((await UserRepository(db).activePasswordHash(claims.userId))!),
      claims.passwordFingerprint,
      reason: 'session bound to the stored password',
    );

    await expectLater(service().start(qr), alreadyCompleted());
    await expectLater(service().complete(complete(qr, 'attacker password')), alreadyCompleted());
  });

  test('two devices completing at the same moment: exactly one succeeds', () async {
    final qr = await newEmployee('B');

    final outcomes = await Future.wait([
      service()
          .complete(complete(qr, 'first device pass', device: 'device-1111111111111111'))
          .then((_) => 'ok', onError: (Object e) => e is ApiException ? e.code : '$e'),
      service()
          .complete(complete(qr, 'second device pass', device: 'device-2222222222222222'))
          .then((_) => 'ok', onError: (Object e) => e is ApiException ? e.code : '$e'),
    ]);

    expect(outcomes.where((o) => o == 'ok'), hasLength(1));
    expect(outcomes.where((o) => o == 'onboarding_already_completed'), hasLength(1));
  });

  test('a lost response is recovered with the same password; another password stays refused', () async {
    final qr = await newEmployee('C');
    await service().complete(complete(qr, 'my real password'));
    final before = (await db.query('SELECT userPassword FROM tblUser WHERE userID = :id', {
      'id': userIds.last,
    })).single.readString('userPassword');

    final recovered = await service().complete(complete(qr, 'my real password', device: 'device-RRRRRRRRRRRRRRRR'));
    await expectLater(service().complete(complete(qr, 'someone else pass')), alreadyCompleted());

    expect(sessions.verify(recovered.session.accessToken)!.userId, userIds.last);
    final after = (await db.query('SELECT userPassword FROM tblUser WHERE userID = :id', {
      'id': userIds.last,
    })).single.readString('userPassword');
    expect(after, before);
  });
}
