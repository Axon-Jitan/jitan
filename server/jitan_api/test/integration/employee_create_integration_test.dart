@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/database/sql_executor.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/employees/employee_service.dart';
import 'package:jitan_api/src/groups/group_repository.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/temporary_qr/in_memory_temporary_token_store.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_service.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_tokens.dart';
import 'package:jitan_api/src/schedules/employee_schedule_sync.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Creating an employee against the real database: every row, the audit
/// entry, and a real rollback. `[DEV-TEST]` fixtures are removed afterwards.
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

  EmployeeService service({AuditLogRepository audit = const AuditLogRepository()}) => EmployeeService(
        employees: EmployeeRepository(db),
        companies: CompanyRepository(db),
        groups: GroupRepository(db),
        audit: audit,
        transactions: db,
        temporaryQr: TemporaryQrService(tokens: TemporaryQrTokens.withRandomKey(), store: InMemoryTemporaryTokenStore()),
        scheduleSync: const EmployeeScheduleSync(),
      );

  CreateEmployeeRequest request(String code, {int? group}) =>
      CreateEmployeeRequest(firstName: 'Test', lastName: 'Employee $code', code: 'DT$stamp$code', groupId: group);

  Future<int> scalar(String sql, Map<String, Object?> params, String column) async =>
      (await db.query(sql, params)).single.readInt(column);

  setUpAll(() async {
    db = TestDatabase.connect();
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

  test('creates the user, company and group links, and an audit entry', () async {
    final created = await service().create(actorId, companyId, request('A1', group: groupId));

    expect(created.code, 'DT${stamp}A1');
    expect(created.groups, ['[DEV-TEST] $stamp Group']);
    expect(created.isActive, isTrue);

    final qr = (await db.query('SELECT userQRcode FROM tblUser WHERE userID = :id', {'id': created.id}))
        .single
        .readString('userQRcode');
    expect(qr, hasLength(24));

    expect(
      await scalar(
        'SELECT COUNT(*) AS n FROM tblEventLog WHERE userIDInit = :a AND userIDTarget = :u AND companyID = :c',
        {'a': actorId, 'u': created.id, 'c': companyId},
        'n',
      ),
      1,
    );
  });

  test('values of the maximum length fit their columns (no MySQL 1406), counted as MySQL counts', () async {
    final code = 'DT${stamp}M'.padRight(CreateEmployeeRequest.maxCodeLength, 'X');
    final lastName = '😀' * CreateEmployeeRequest.maxLastNameLength;

    final created = await service().create(
      actorId,
      companyId,
      CreateEmployeeRequest(
        firstName: 'T' * CreateEmployeeRequest.maxFirstNameLength,
        lastName: lastName,
        code: code,
        phone: '1' * CreateEmployeeRequest.maxPhoneLength,
      ),
    );

    final row = (await db.query(
      'SELECT userSurname, userCode, cellphoneNumber FROM tblUser WHERE userID = :id',
      {'id': created.id},
    )).single;
    expect(
      (row.readString('userSurname'), row.readString('userCode'), row.readString('cellphoneNumber')),
      (lastName, code, '1' * CreateEmployeeRequest.maxPhoneLength),
    );
  });

  test('a duplicate code is refused with 409 and writes nothing', () async {
    await service().create(actorId, companyId, request('D1'));

    await expectLater(
      service().create(actorId, companyId, request('D1')),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );
    expect(await scalar('SELECT COUNT(*) AS n FROM tblUser WHERE userCode = :c', {'c': 'DT${stamp}D1'}, 'n'), 1);
  });

  test('a temporary onboarding QR leaves the Terminal QR as it was and is audited, not stored', () async {
    final created = await service().create(actorId, companyId, request('Q1'));
    Future<String> terminalQr() async =>
        (await db.query('SELECT userQRcode FROM tblUser WHERE userID = :id', {'id': created.id})).single.readString('userQRcode');
    final before = await terminalQr();

    final qr = await service().temporaryQr(actorId, companyId, created.id, TemporaryQrPurpose.onboarding);

    expect(qr.qrCode, isNot(before));
    expect(await terminalQr(), before);
    final generated = await db.query(
      'SELECT COUNT(*) AS n FROM tblEventLog l JOIN tblEventLogEventType et ON et.eventLogID = l.eventLogID '
      'JOIN tblEventType t ON t.eventTypeID = et.eventTypeID '
      'WHERE l.userIDTarget = :id AND t.eventTypeName = :type',
      {'id': created.id, 'type': 'employee.onboarding_qr.generated'},
    );
    expect(generated.single.readInt('n'), 1);
  });

  test('a failure after the inserts rolls everything back', () async {
    await expectLater(
      service(audit: _FailingAudit()).create(actorId, companyId, request('R1', group: groupId)),
      throwsA(isA<StateError>()),
    );

    expect(await scalar('SELECT COUNT(*) AS n FROM tblUser WHERE userCode = :c', {'c': 'DT${stamp}R1'}, 'n'), 0);
  });
}

/// Fails after the user, company and group rows were inserted.
class _FailingAudit implements AuditLogRepository {
  @override
  Future<void> record(SqlExecutor tx, AuditEvent event) async => throw StateError('audit failed on purpose');
}
