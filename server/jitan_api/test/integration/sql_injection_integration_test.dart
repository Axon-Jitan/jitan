@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/database/sql_in_list.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/groups/group_management_repository.dart';
import 'package:jitan_api/src/groups/group_management_service.dart';
import 'package:jitan_api/src/groups/group_member_repository.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// SQL injection and cross-company access against real MySQL
/// (ENGINEERING_RULES §28a): hostile text in every search and stored text
/// field is only ever data, and an employee is never readable through
/// another company. `[DEV-TEST]` fixtures, removed in tearDownAll.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  /// Classic payloads: they must match nothing and change nothing.
  const payloads = [
    "' OR '1'='1",
    "' OR 1=1 -- ",
    '" OR ""="',
    "'; DROP TABLE tblUser; -- ",
    "') UNION SELECT userPassword, userPINCode, 1, 1 FROM tblUser -- ",
    r'\',
    '%',
    '_',
    "%' AND SLEEP(2) AND '%'='",
  ];

  late Database db;
  late EmployeeRepository employees;
  late GroupMemberRepository members;
  late GroupManagementService groups;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final prefix = '[DEV-TEST] $stamp';
  late int companyA;
  late int companyB;
  late int alice; // in A
  late int bob; // in B
  late int actor;
  final createdGroups = <int>[];

  Future<int> tableCount(String table) async =>
      (await db.query(
        'SELECT COUNT(*) AS n FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :t',
        {'t': table},
      ))
          .single
          .readInt('n');

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 2);
    employees = EmployeeRepository(db);
    members = GroupMemberRepository(db);
    groups = GroupManagementService(
      groups: const GroupManagementRepository(),
      audit: const AuditLogRepository(),
      transactions: db,
      executor: db,
    );
    Future<int> company(String name) async => (await db.execute(
      'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:n, 1, 0)',
      {'n': '$prefix $name'},
    )).lastInsertId;
    Future<int> user(String key, int? companyId) async {
      final id = (await db.execute(
        'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
        "VALUES ('[DEV-TEST]', :s, :c, :q, 1, 0)",
        {'s': key, 'c': 'SQ$key$stamp', 'q': 'DEV-TEST-SQ$key$stamp'},
      )).lastInsertId;
      if (companyId != null) {
        await db.execute(
          'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)',
          {'u': id, 'c': companyId},
        );
      }
      return id;
    }

    companyA = await company('A');
    companyB = await company('B');
    alice = await user('Alice', companyA);
    bob = await user('Bob', companyB);
    actor = await user('Actor', null);
    if ((await db.query("SELECT 1 FROM tblEventType WHERE eventTypeName = 'group.created'")).isEmpty) {
      await db.execute("INSERT INTO tblEventType (eventTypeName) VALUES ('group.created')");
    }
  });

  tearDownAll(() async {
    for (final id in createdGroups) {
      for (final log in await db.query('SELECT eventLogID FROM tblEventLog WHERE groupID = :g', {'g': id})) {
        await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
        await db.execute('DELETE FROM tblEventLog WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
      }
      await db.execute('DELETE FROM tblGroup WHERE groupID = :g', {'g': id});
    }
    for (final id in [alice, bob, actor]) {
      await db.execute('DELETE FROM tblUserCompany WHERE userID = :u', {'u': id});
      await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': id});
    }
    for (final id in [companyA, companyB]) {
      await db.execute('DELETE FROM tblCompany WHERE companyID = :c', {'c': id});
    }
    await db.close();
  });

  test('hostile text in the employee search matches nothing and changes nothing', () async {
    for (final payload in payloads) {
      final found = await employees.listForCompany(companyA, nameOrCodeContains: payload);
      expect(found, isEmpty, reason: payload);
    }
    expect(await tableCount('tblUser'), 1, reason: 'tblUser still exists');
    expect([for (final e in await employees.listForCompany(companyA)) e.id], contains(alice), reason: 'data intact');
  });

  test('hostile text in the group candidates search matches nothing', () async {
    for (final payload in payloads) {
      final found = await members.candidates(null, search: payload);
      expect([for (final m in found) m.userId], isNot(contains(alice)), reason: payload);
    }
  });

  test('a group name full of SQL is stored and compared as plain text', () async {
    const hostile = "'); DELETE FROM tblGroup; -- \\ % _ \"";
    final id = await db.transaction((tx) => groups.createIn(tx, actor, '$prefix $hostile'));
    createdGroups.add(id);

    final stored = (await db.query('SELECT groupName FROM tblGroup WHERE groupID = :g', {'g': id})).single;
    expect(stored.readString('groupName'), '$prefix $hostile', reason: 'stored verbatim');
    expect(await tableCount('tblGroup'), 1);
    expect(
      () => db.transaction((tx) => groups.createIn(tx, actor, '$prefix $hostile')),
      throwsA(anything),
      reason: 'the duplicate check compares the exact text',
    );
  });

  test('group_management_repository: escape edge cases stay data in insert, nameTaken and rename', () async {
    const repo = GroupManagementRepository();
    // The driver pastes escaped values into the SQL text (no server-side
    // prepared statements in mysql_client_plus 0.1.3): ' becomes '', \ becomes
    // \. These are the inputs that break weaker escaping.
    const tricky = [
      r"\'",
      r"\'",
      "''",
      r"\' OR 1=1 -- ",
      "x' OR groupName LIKE '%",
      ':except :name :id',
      'ʼ OR 1=1 -- ',
      '\u0000 nul',
    ];
    for (final (i, value) in tricky.indexed) {
      final name = '$prefix E$i $value';
      final id = await db.transaction((tx) => repo.insert(tx, name));
      createdGroups.add(id);
      final stored = (await db.query('SELECT groupName FROM tblGroup WHERE groupID = :g', {'g': id})).single;
      expect(stored.readString('groupName'), name, reason: 'stored verbatim: $value');

      // Taken only by itself, not by every group (an injected OR 1=1 would make it true).
      expect(await db.transaction((tx) => repo.nameTaken(tx, name)), isTrue, reason: value);
      expect(await db.transaction((tx) => repo.nameTaken(tx, name, exceptGroupId: id)), isFalse, reason: value);
      expect(await db.transaction((tx) => repo.nameTaken(tx, '$prefix none $value')), isFalse, reason: value);

      await db.transaction((tx) => repo.rename(tx, id, '$name renamed'));
      final renamed = (await db.query('SELECT groupName FROM tblGroup WHERE groupID = :g', {'g': id})).single;
      expect(renamed.readString('groupName'), '$name renamed', reason: 'rename changed only this row: $value');
    }
    final others = await db.query(
      "SELECT COUNT(*) AS n FROM tblGroup WHERE groupName LIKE '% renamed' AND groupName NOT LIKE CONCAT(:p, '%')",
      {'p': prefix},
    );
    expect(others.single.readInt('n'), 0, reason: 'no other group was renamed');
  });

  test('an employee is never readable through another company', () async {
    expect(await employees.findInCompany(db, companyB, alice), isNull);
    expect(await employees.findDetails(companyB, alice), isNull);
    expect(await employees.findInCompany(db, companyA, bob), isNull);
    expect(await employees.findInCompany(db, companyA, alice), isNotNull, reason: 'their own company works');
  });

  test('IN lists only ever carry placeholders', () {
    final list = SqlInList('u', [1, 2, 3]);
    expect(list.placeholders, ':u0, :u1, :u2');
    expect(list.params, {'u0': 1, 'u1': 2, 'u2': 3});
    expect(() => SqlInList("u'); DROP TABLE x; --", [1]), throwsArgumentError, reason: 'prefixes are code, not input');
    expect(() => SqlInList('u', const []), throwsArgumentError);
  });
}
