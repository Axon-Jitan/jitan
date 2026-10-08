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
import 'package:jitan_api/src/temporary_qr/in_memory_temporary_token_store.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_service.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_tokens.dart';
import 'package:jitan_api/src/users/user_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Onboarding with temporary QRs against real MySQL: the password guard, the
/// session, two devices at once, and that no temporary QR reaches MySQL.
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
  final temporaryQr = TemporaryQrService(tokens: TemporaryQrTokens.withRandomKey(), store: InMemoryTemporaryTokenStore());

  OnboardingService service() => OnboardingService(
    onboarding: const OnboardingRepository(),
    languages: LanguageRepository(db),
    audit: const AuditLogRepository(),
    transactions: db,
    executor: db,
    sessions: sessions,
    temporaryQr: temporaryQr,
    hasher: hasher,
  );

  OnboardingCompleteRequest complete(String qr, String password, {String device = 'device-AAAAAAAAAAAAAAAA'}) =>
      OnboardingCompleteRequest(qrCode: qr, password: password, deviceId: device);

  /// A new employee; returns (userId, permanent Terminal QR).
  Future<(int, String)> newEmployee(String suffix, {bool active = true, bool mfd = false}) async {
    final terminalQr = 'DEV-TEST-ONB-$stamp-$suffix';
    final id = (await db.execute(
      'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
      "VALUES ('[DEV-TEST]', 'Onboarding', :code, :qr, :active, :mfd)",
      {'code': 'DT$stamp$suffix', 'qr': terminalQr, 'active': active, 'mfd': mfd},
    )).lastInsertId;
    userIds.add(id);
    return (id, terminalQr);
  }

  Future<String> onboardingQr(int userId) async => (await temporaryQr.issue(userId, TemporaryQrPurpose.onboarding)).token;

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

  Matcher refused(String code) => throwsA(isA<ApiException>().having((e) => e.code, 'code', code));

  /// Every text column of every table holding [value], as `table.column`.
  Future<List<String>> columnsContaining(String value) async {
    final columns = await db.query(
      'SELECT CAST(TABLE_NAME AS CHAR) AS TABLE_NAME, CAST(COLUMN_NAME AS CHAR) AS COLUMN_NAME FROM information_schema.COLUMNS '
      "WHERE TABLE_SCHEMA = DATABASE() AND DATA_TYPE IN ('varchar', 'char', 'text', 'mediumtext', 'longtext')",
    );
    final found = <String>[];
    for (final c in columns) {
      final table = c.readString('TABLE_NAME');
      final column = c.readString('COLUMN_NAME');
      final n = (await db.query('SELECT COUNT(*) AS n FROM `$table` WHERE `$column` LIKE :v', {'v': '%$value%'}))
          .single
          .readInt('n');
      if (n > 0) found.add('$table.$column');
    }
    return found;
  }

  test('temporary QR → start → complete: Argon2id hash, session, Terminal QR unchanged, QR used up', () async {
    final (id, terminalQr) = await newEmployee('A');
    final qr = await onboardingQr(id);
    expect((await service().start(qr)).code, 'DT${stamp}A');

    final result = await service().complete(complete(qr, 'correct horse battery'));

    final row = (await db.query('SELECT userPassword, userQRcode FROM tblUser WHERE userID = :id', {'id': id})).single;
    final hash = row.readString('userPassword');
    expect(hash, startsWith(r'$argon2id$v=19$'));
    expect(await hasher.verify('correct horse battery', hash), isTrue);
    expect(row.readString('userQRcode'), terminalQr, reason: 'the permanent Terminal QR never changes');

    final claims = sessions.verify(result.session.accessToken)!;
    expect(claims.userId, id);
    expect(
      sessions.passwordFingerprint((await UserRepository(db).activePasswordHash(claims.userId))!),
      claims.passwordFingerprint,
      reason: 'session bound to the stored password: no second sign-in needed',
    );
    await expectLater(service().start(qr), refused('qr_already_used'));
  });

  test('no temporary QR value is stored anywhere in MySQL', () async {
    final (id, _) = await newEmployee('N');
    final qr = await onboardingQr(id);
    await service().complete(complete(qr, 'correct horse battery'));
    final signature = qr.split('.').last;

    expect(await columnsContaining(signature), isEmpty);
  });

  test('the permanent Terminal QR does not onboard', () async {
    final (_, terminalQr) = await newEmployee('T');

    await expectLater(service().start(terminalQr), refused('invalid_qr_code'));
    await expectLater(service().complete(complete(terminalQr, 'correct horse battery')), refused('invalid_qr_code'));
  });

  test('inactive and MFD employees are refused', () async {
    final (inactive, _) = await newEmployee('I', active: false);
    final (deleted, _) = await newEmployee('M', mfd: true);

    await expectLater(service().start(await onboardingQr(inactive)), refused('account_inactive'));
    await expectLater(service().start(await onboardingQr(deleted)), refused('account_inactive'));
  });

  test('two devices completing at the same moment: exactly one succeeds, one password stored', () async {
    final (id, _) = await newEmployee('B');
    final qr = await onboardingQr(id);

    final outcomes = await Future.wait([
      service()
          .complete(complete(qr, 'first device pass', device: 'device-1111111111111111'))
          .then((_) => 'ok', onError: (Object e) => e is ApiException ? e.code : '$e'),
      service()
          .complete(complete(qr, 'second device pass', device: 'device-2222222222222222'))
          .then((_) => 'ok', onError: (Object e) => e is ApiException ? e.code : '$e'),
    ]);

    expect(outcomes.where((o) => o == 'ok'), hasLength(1));
    expect(outcomes.where((o) => o == 'qr_already_used'), hasLength(1));
  });

  test('a lost response: the same device finishes with the same password; nothing else changes', () async {
    final (id, _) = await newEmployee('C');
    final qr = await onboardingQr(id);
    await service().complete(complete(qr, 'my real password'));
    Future<String> stored() async =>
        (await db.query('SELECT userPassword FROM tblUser WHERE userID = :id', {'id': id})).single.readString('userPassword');
    final before = await stored();

    final again = await service().complete(complete(qr, 'my real password'));
    await expectLater(service().complete(complete(qr, 'someone else pass')), refused('onboarding_already_completed'));
    await expectLater(
      service().complete(complete(qr, 'my real password', device: 'device-RRRRRRRRRRRRRRRR')),
      refused('qr_already_used'),
    );

    expect(sessions.verify(again.session.accessToken)!.userId, id);
    expect(await stored(), before);
  });
}
