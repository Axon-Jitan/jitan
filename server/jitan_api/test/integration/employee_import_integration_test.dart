@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/employees/employee_import_service.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/employees/employee_service.dart';
import 'package:jitan_api/src/groups/group_repository.dart';
import 'package:jitan_api/src/schedules/employee_schedule_sync.dart';
import 'package:jitan_api/src/temporary_qr/in_memory_temporary_token_store.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_service.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_tokens.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Import employees against the real database: the ready rows are written
/// with their links and audit entries, a taken code (in any case) is
/// skipped. `[DEV-TEST]` fixtures are removed afterwards.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  late int companyId;
  late int groupId;
  late int actorId;
  late EmployeeImportService service;

  setUpAll(() async {
    db = TestDatabase.connect();
    final employees = EmployeeRepository(db);
    final creator = EmployeeService(
      employees: employees,
      companies: CompanyRepository(db),
      groups: GroupRepository(db),
      audit: const AuditLogRepository(),
      transactions: db,
      temporaryQr: TemporaryQrService(tokens: TemporaryQrTokens.withRandomKey(), store: InMemoryTemporaryTokenStore()),
      scheduleSync: const EmployeeScheduleSync(),
    );
    service = EmployeeImportService(
      employees: employees,
      creator: creator,
      companies: CompanyRepository(db),
      groups: GroupRepository(db),
      transactions: db,
    );
    companyId = (await db.execute(
      'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:n, 1, 0)',
      {'n': '[DEV-TEST] $stamp Company'},
    ))
        .lastInsertId;
    groupId = (await db.execute(
      'INSERT INTO tblGroup (groupName, groupActive, groupMFD) VALUES (:n, 1, 0)',
      {'n': '[DEV-TEST] $stamp Group'},
    ))
        .lastInsertId;
    actorId = (await db.execute(
      'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
      "VALUES ('[DEV-TEST]', 'Actor', :c, :q, 1, 0)",
      {'c': 'DT${stamp}ACT', 'q': 'DEV-TEST-${stamp}ACT'},
    ))
        .lastInsertId;
  });

  tearDownAll(() async {
    final users = await db.query("SELECT userID FROM tblUser WHERE userCode LIKE CONCAT(:p, '%')", {'p': 'DT$stamp'});
    for (final row in users) {
      final id = row.readInt('userID');
      final logs = await db.query('SELECT eventLogID FROM tblEventLog WHERE userIDTarget = :id OR userIDInit = :id', {'id': id});
      for (final log in logs) {
        await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
        await db.execute('DELETE FROM tblEventLog WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
      }
      await db.execute('DELETE FROM tblUserGroup WHERE userID = :id', {'id': id});
      await db.execute('DELETE FROM tblUserCompany WHERE userID = :id', {'id': id});
      await db.execute('DELETE FROM tblUser WHERE userID = :id', {'id': id});
    }
    await db.execute('DELETE FROM tblGroup WHERE groupID = :id', {'id': groupId});
    await db.execute('DELETE FROM tblCompany WHERE companyID = :id', {'id': companyId});
    await db.close();
  });

  EmployeeImportRow row(int number, String code, {List<String> groups = const []}) =>
      EmployeeImportRow(row: number, firstName: 'Test', lastName: 'Import $code', code: code, groups: groups);

  test('check: a code taken in any case is reported; hostile text is only a value; nothing is written', () async {
    final check = await service.check(
      companyId,
      EmployeeImportRequest(rows: [
        row(2, 'DT${stamp}I1'),
        row(3, 'dt${stamp}act'),
        row(4, "x' OR '1'='1"),
        row(5, "x') OR 1=1 -- "),
      ]),
    );

    expect([for (final p in check.problems) (p.row, p.kind)], [(3, EmployeeImportProblemKind.codeUsed)]);
    expect(await db.query('SELECT 1 AS found FROM tblUser WHERE userCode = :c', {'c': 'DT${stamp}I1'}), isEmpty);
  });

  test('import: writes the ready rows with company and group links and audit entries, skips the taken code', () async {
    final result = await service.import(
      actorId,
      companyId,
      EmployeeImportRequest(rows: [
        row(2, 'DT${stamp}I1', groups: ['[dev-test] $stamp group']),
        row(3, 'DT${stamp}ACT'),
        row(4, 'DT${stamp}I2'),
      ]),
    );

    expect(result.added, 2);
    expect([for (final p in result.skipped) (p.row, p.kind)], [(3, EmployeeImportProblemKind.codeUsed)]);

    final imported = await db.query(
      'SELECT u.userID, u.userCode, u.userActive, u.userPassword, '
      '(SELECT COUNT(*) FROM tblUserCompany uc WHERE uc.userID = u.userID AND uc.companyID = :company '
      'AND uc.userCompanyActive = 1 AND uc.userCompanyMFD = 0) AS inCompany, '
      '(SELECT COUNT(*) FROM tblUserGroup ug WHERE ug.userID = u.userID AND ug.groupID = :group '
      'AND ug.userGroupActive = 1 AND ug.userGroupMFD = 0) AS inGroup, '
      '(SELECT COUNT(*) FROM tblEventLog e WHERE e.userIDTarget = u.userID AND e.userIDInit = :actor) AS events '
      'FROM tblUser u WHERE u.userCode IN (:a, :b) ORDER BY u.userCode',
      {'company': companyId, 'group': groupId, 'actor': actorId, 'a': 'DT${stamp}I1', 'b': 'DT${stamp}I2'},
    );
    expect([for (final r in imported) (r.readString('userCode'), r.readInt('inCompany'), r.readInt('inGroup'), r.readInt('events'))], [
      ('DT${stamp}I1', 1, 1, 2),
      ('DT${stamp}I2', 1, 0, 1),
    ]);
    for (final r in imported) {
      expect(r.readBool('userActive'), isTrue);
      expect(r.readOptionalString('userPassword'), isNull, reason: 'the employee sets it during onboarding');
    }
  });
}
