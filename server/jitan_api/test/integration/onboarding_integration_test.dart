@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/auth/password_hasher.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/onboarding/onboarding_repository.dart';
import 'package:jitan_api/src/onboarding/onboarding_service.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// The re-onboarding guard against real MySQL: `userPassword IS NULL` →
/// onboarding; set password → complete; the same QR never restarts it.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final qr = 'DEV-TEST-ONB-$stamp';
  late int userId;

  OnboardingService service() => OnboardingService(
        onboarding: const OnboardingRepository(),
        audit: const AuditLogRepository(),
        transactions: db,
        executor: db,
        hasher: const PasswordHasher(cost: 4),
      );

  setUpAll(() async {
    db = TestDatabase.connect();
    userId = (await db.execute(
      'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
      "VALUES ('[DEV-TEST]', 'Onboarding', :code, :qr, 1, 0)",
      {'code': 'DT${stamp}ONB', 'qr': qr},
    ))
        .lastInsertId;
  });

  tearDownAll(() async {
    final logs = await db.query('SELECT eventLogID FROM tblEventLog WHERE userIDTarget = :id', {'id': userId});
    for (final log in logs) {
      await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
      await db.execute('DELETE FROM tblEventLog WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
    }
    await db.execute('DELETE FROM tblUser WHERE userID = :id', {'id': userId});
    await db.close();
  });

  Matcher alreadyCompleted() =>
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'onboarding_already_completed'));

  test('start → complete stores a hash; afterwards the QR cannot restart onboarding', () async {
    expect((await service().start(qr)).code, 'DT${stamp}ONB');

    await service().complete(qr, 'correct horse');

    final row = (await db.query('SELECT userPassword, userQRcode FROM tblUser WHERE userID = :id', {'id': userId})).single;
    final hash = row.readString('userPassword');
    expect(hash, startsWith(r'$2b$'));
    expect(row.readString('userQRcode'), qr, reason: 'the QR stays the same for Terminal use');

    await expectLater(service().start(qr), alreadyCompleted());
    await expectLater(service().complete(qr, 'attacker pass'), alreadyCompleted());
    final after = (await db.query('SELECT userPassword FROM tblUser WHERE userID = :id', {'id': userId})).single;
    expect(after.readString('userPassword'), hash, reason: 'password never replaced');
  });
}
