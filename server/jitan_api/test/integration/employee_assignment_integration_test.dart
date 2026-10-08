@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/employees/employee_assignment_repository.dart';
import 'package:jitan_api/src/employees/employee_assignment_service.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Employee assignments against real MySQL with `[DEV-TEST]` fixtures,
/// removed in tearDownAll.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final companyIds = <String, int>{};
  final groupIds = <String, int>{};
  final credGroupIds = <String, int>{};
  late int userId;
  late int actorId;
  const repo = EmployeeAssignmentRepository();

  EmployeeAssignmentService service() => EmployeeAssignmentService(
    assignments: repo,
    employees: EmployeeRepository(db),
    companies: CompanyRepository(db),
    audit: const AuditLogRepository(),
    transactions: db,
    executor: db,
  );

  Future<int> insertCompany(String key, {required bool active, bool mfd = false}) async {
    final id = (await db.execute(
      'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:name, :active, :mfd)',
      {'name': '[DEV-TEST] $key $stamp', 'active': active, 'mfd': mfd},
    )).lastInsertId;
    return companyIds[key] = id;
  }

  Future<int> insertGroup(String key, {required bool active, bool mfd = false}) async {
    final id = (await db.execute(
      'INSERT INTO tblGroup (groupName, groupActive, groupMFD) VALUES (:name, :active, :mfd)',
      {'name': '[DEV-TEST] $key $stamp', 'active': active, 'mfd': mfd},
    )).lastInsertId;
    return groupIds[key] = id;
  }

  Future<int> insertCredGroup(String key, {required bool active, bool mfd = false}) async {
    final id = (await db.execute(
      'INSERT INTO tblCredGroup (credGroupName, credGroupLevel, credGroupActive, credGroupMFD) '
      'VALUES (:name, 99, :active, :mfd)',
      {'name': '[DEV-TEST] $key $stamp', 'active': active, 'mfd': mfd},
    )).lastInsertId;
    return credGroupIds[key] = id;
  }

  Future<int> insertUser(String code) async => (await db.execute(
    'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
    "VALUES ('[DEV-TEST]', 'Assign', :code, :qr, 1, 0)",
    {'code': code, 'qr': 'DEV-TEST-$code'},
  )).lastInsertId;

  Future<int> memberships(int companyId) async => (await db.query(
    'SELECT COUNT(*) AS n FROM tblUserCompany WHERE userID = :u AND companyID = :c',
    {'u': userId, 'c': companyId},
  )).single.readInt('n');

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 4);
    await insertCompany('home', active: true);
    await insertCompany('other', active: true);
    await insertCompany('inactive', active: false);
    await insertCompany('deleted', active: true, mfd: true);
    await insertGroup('active', active: true);
    await insertGroup('inactive', active: false);
    await insertGroup('deleted', active: true, mfd: true);
    await insertCredGroup('active', active: true);
    await insertCredGroup('inactive', active: false);
    await insertCredGroup('deleted', active: true, mfd: true);
    userId = await insertUser('DTA$stamp');
    actorId = await insertUser('DTH$stamp');
    await db.execute('INSERT INTO tblUserCompany (userID, companyID) VALUES (:u, :c)', {
      'u': userId,
      'c': companyIds['home'],
    });
  });

  tearDownAll(() async {
    for (final id in [userId, actorId]) {
      final logs = await db.query('SELECT eventLogID FROM tblEventLog WHERE userIDTarget = :id', {'id': id});
      for (final log in logs) {
        await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
        await db.execute('DELETE FROM tblEventLog WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
      }
      await db.execute('DELETE FROM tblUserCompany WHERE userID = :id', {'id': id});
      await db.execute('DELETE FROM tblUserGroup WHERE userID = :id', {'id': id});
      await db.execute('DELETE FROM tblUserCredGroup WHERE userID = :id', {'id': id});
      await db.execute('DELETE FROM tblUser WHERE userID = :id', {'id': id});
    }
    for (final id in credGroupIds.values) {
      await db.execute('DELETE FROM tblCredGroup WHERE credGroupID = :id', {'id': id});
    }
    for (final id in groupIds.values) {
      await db.execute('DELETE FROM tblGroup WHERE groupID = :id', {'id': id});
    }
    for (final id in companyIds.values) {
      await db.execute('DELETE FROM tblCompany WHERE companyID = :id', {'id': id});
    }
    await db.close();
  });

  test('options: active companies and memberships; inactive and MFD ones are not offered', () async {
    final options = {for (final o in await repo.companyOptions(db, userId)) o.id: o};

    expect(options[companyIds['home']]!.isAssigned, isTrue);
    expect(options[companyIds['other']]!.isAssigned, isFalse);
    expect(options.containsKey(companyIds['inactive']), isFalse);
    expect(options.containsKey(companyIds['deleted']), isFalse);
  });

  test('adding is idempotent: the pair is created once, never duplicated', () async {
    final other = companyIds['other']!;

    final first = await db.transaction((tx) => repo.addCompany(tx, userId, other));
    final second = await db.transaction((tx) => repo.addCompany(tx, userId, other));

    expect(first, isNotNull);
    expect(second, isNull);
    expect(await memberships(other), 1);
    await db.execute('DELETE FROM tblUserCompany WHERE userID = :u AND companyID = :c', {'u': userId, 'c': other});
  });

  test('two concurrent adds of the same company create one membership', () async {
    final other = companyIds['other']!;

    final results = await Future.wait([
      db.transaction((tx) => repo.addCompany(tx, userId, other)),
      db.transaction((tx) => repo.addCompany(tx, userId, other)),
    ]);

    expect(results.whereType<int>(), hasLength(1));
    expect(await memberships(other), 1);
    await db.execute('DELETE FROM tblUserCompany WHERE userID = :u AND companyID = :c', {'u': userId, 'c': other});
  });

  test('service: adds the membership and its audit row with user, company and userCompanyID', () async {
    final home = companyIds['home']!;
    final other = companyIds['other']!;

    final result = await service().addCompanies(
      actorId,
      home,
      userId,
      AddAssignmentsRequest(ids: [home, other]),
      mayManage: (_) async {},
    );

    expect(result.options.firstWhere((o) => o.id == other).isAssigned, isTrue);
    final membership = (await db.query(
      'SELECT userCompanyID FROM tblUserCompany WHERE userID = :u AND companyID = :c',
      {'u': userId, 'c': other},
    )).single.readInt('userCompanyID');
    final logs = await db.query(
      'SELECT userIDInit, companyID, userCompanyID FROM tblEventLog WHERE userIDTarget = :u',
      {'u': userId},
    );
    expect(logs, hasLength(1), reason: 'home was already assigned: only one change');
    expect(logs.single.readInt('userIDInit'), actorId);
    expect(logs.single.readInt('companyID'), other);
    expect(logs.single.readInt('userCompanyID'), membership);
  });

  test('groups: universal options, idempotent concurrent add, one audit row with groupID and userGroupID', () async {
    final home = companyIds['home']!;
    final active = groupIds['active']!;
    final options = {for (final o in await repo.groupOptions(db, userId)) o.id: o};
    expect(options[active]!.isAssigned, isFalse);
    expect(options.containsKey(groupIds['inactive']), isFalse);
    expect(options.containsKey(groupIds['deleted']), isFalse);
    final companiesBefore = await db.query('SELECT COUNT(*) AS n FROM tblUserCompany WHERE userID = :u', {'u': userId});

    final results = await Future.wait([
      service().addGroups(actorId, home, userId, AddAssignmentsRequest(ids: [active])),
      service().addGroups(actorId, home, userId, AddAssignmentsRequest(ids: [active])),
    ]);

    expect(results.first.options.firstWhere((o) => o.id == active).isAssigned, isTrue);
    final pairs = await db.query(
      'SELECT userGroupID FROM tblUserGroup WHERE userID = :u AND groupID = :g',
      {'u': userId, 'g': active},
    );
    expect(pairs, hasLength(1), reason: 'concurrent adds create one row');
    final logs = await db.query(
      'SELECT userIDInit, groupID, userGroupID FROM tblEventLog WHERE userIDTarget = :u AND groupID IS NOT NULL',
      {'u': userId},
    );
    expect(logs, hasLength(1), reason: 'one change, one audit row');
    expect(logs.single.readInt('userIDInit'), actorId);
    expect(logs.single.readInt('userGroupID'), pairs.single.readInt('userGroupID'));
    final companiesAfter = await db.query('SELECT COUNT(*) AS n FROM tblUserCompany WHERE userID = :u', {'u': userId});
    expect(companiesAfter.single.readInt('n'), companiesBefore.single.readInt('n'), reason: 'a group grants no company');
  });

  test('credential groups: options, member companies, concurrent add once, audited with credGroupID', () async {
    final home = companyIds['home']!;
    final active = credGroupIds['active']!;
    final options = {for (final o in await repo.credentialGroupOptions(db, userId)) o.id: o};
    expect(options[active]!.isAssigned, isFalse);
    expect(options.containsKey(credGroupIds['inactive']), isFalse);
    expect(options.containsKey(credGroupIds['deleted']), isFalse);
    expect(await repo.memberCompanyIds(db, userId), contains(home));

    final asked = <int>{};
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        service().addCredentialGroups(
          actorId,
          home,
          userId,
          AddAssignmentsRequest(ids: [active]),
          mayManage: (c) async => asked.add(c),
        ),
    ]);

    expect(asked, (await repo.memberCompanyIds(db, userId)).toSet());
    expect(results.first.options.firstWhere((o) => o.id == active).isAssigned, isTrue);
    final pairs = await db.query(
      'SELECT userCredGroupID FROM tblUserCredGroup WHERE userID = :u AND credGroupID = :g',
      {'u': userId, 'g': active},
    );
    expect(pairs, hasLength(1));
    final logs = await db.query(
      'SELECT userIDInit, userCredGroupID FROM tblEventLog WHERE userIDTarget = :u AND credGroupID = :g',
      {'u': userId, 'g': active},
    );
    expect(logs, hasLength(1));
    expect(logs.single.readInt('userIDInit'), actorId);
    expect(logs.single.readInt('userCredGroupID'), pairs.single.readInt('userCredGroupID'));
  });
}
