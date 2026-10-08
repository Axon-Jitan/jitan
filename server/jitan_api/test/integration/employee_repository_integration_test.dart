@Tags(['integration'])
library;

import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Real SQL for the employee list against `[DEV-TEST]` fixtures, removed in
/// tearDownAll.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final companyIds = <int>[];
  final userIds = <int>[];
  final groupIds = <int>[];

  Future<int> insertAndFind(String insertSql, Map<String, Object?> params, String findSql, String idColumn) async {
    await db.query(insertSql, params);
    return (await db.query(findSql, params)).single.readInt(idColumn);
  }

  Future<int> company(String name, {bool mfd = false}) async {
    final id = await insertAndFind(
      'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:name, 1, :mfd)',
      {'name': '[DEV-TEST] $stamp $name', 'mfd': mfd},
      'SELECT companyID FROM tblCompany WHERE companyName = :name',
      'companyID',
    );
    companyIds.add(id);
    return id;
  }

  Future<int> user(String first, String last, String code, {bool active = true, bool mfd = false}) async {
    final id = await insertAndFind(
      'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
      'VALUES (:first, :last, :code, :qr, :active, :mfd)',
      {'first': first, 'last': last, 'code': 'DT$stamp$code', 'qr': 'DEV-TEST-$stamp$code', 'active': active, 'mfd': mfd},
      'SELECT userID FROM tblUser WHERE userCode = :code',
      'userID',
    );
    userIds.add(id);
    return id;
  }

  Future<int> group(String name, {bool active = true}) async {
    final id = await insertAndFind(
      'INSERT INTO tblGroup (groupName, groupActive, groupMFD) VALUES (:name, :active, 0)',
      {'name': '[DEV-TEST] $stamp $name', 'active': active},
      'SELECT groupID FROM tblGroup WHERE groupName = :name',
      'groupID',
    );
    groupIds.add(id);
    return id;
  }

  Future<void> member(int userId, int companyId) =>
      db.query('INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)', {'u': userId, 'c': companyId});

  Future<void> inGroup(int userId, int groupId) =>
      db.query('INSERT INTO tblUserGroup (userID, groupID, userGroupActive, userGroupMFD) VALUES (:u, :g, 1, 0)', {'u': userId, 'g': groupId});

  late int almeco;
  late int pca;

  setUpAll(() async {
    db = TestDatabase.connect();
    almeco = await company('Almeco');
    pca = await company('PCA');
    final white = await group('White collar');
    final blue = await group('Blue collar');
    final retired = await group('Retired group', active: false);

    final disan = await user('Disan', 'Ssebowa', 'SBW');
    final thomas = await user('Thomas', 'Vermeulen', 'TVM', active: false);
    final kevin = await user('Kevin', "O'Brien", 'KOB');
    final deleted = await user('Gone', 'Away', 'GONE', mfd: true);
    final pcaOnly = await user('Paula', 'Claes', 'PCL');

    for (final u in [disan, thomas, kevin, deleted]) {
      await member(u, almeco);
    }
    await member(pcaOnly, pca);
    await member(disan, pca); // one person, two companies

    await inGroup(disan, white);
    await inGroup(thomas, blue);
    await inGroup(thomas, white); // several groups: both shown
    await inGroup(kevin, retired); // inactive group: not shown
  });

  tearDownAll(() async {
    for (final id in userIds) {
      await db.query('DELETE FROM tblUserGroup WHERE userID = :id', {'id': id});
      await db.query('DELETE FROM tblUserCompany WHERE userID = :id', {'id': id});
      await db.query('DELETE FROM tblUser WHERE userID = :id', {'id': id});
    }
    for (final id in groupIds) {
      await db.query('DELETE FROM tblGroup WHERE groupID = :id', {'id': id});
    }
    for (final id in companyIds) {
      await db.query('DELETE FROM tblCompany WHERE companyID = :id', {'id': id});
    }
    await db.close();
  });

  String groupName(String name) => '[DEV-TEST] $stamp $name';

  test("lists only that company's non-MFD members, by last name, with all active groups", () async {
    final list = await EmployeeRepository(db).listForCompany(almeco);

    expect(list.map((e) => e.lastName), ["O'Brien", 'Ssebowa', 'Vermeulen']);
    final thomas = list.last;
    expect(thomas.isActive, isFalse);
    expect(thomas.groups, [groupName('Blue collar'), groupName('White collar')]);
    expect(list.first.groups, isEmpty, reason: 'inactive group hidden');
    expect(list.every((e) => !e.isActivated), isTrue, reason: 'no password set (userPassword IS NULL)');
  });

  test('another company sees only its own members', () async {
    final list = await EmployeeRepository(db).listForCompany(pca);

    expect(list.map((e) => e.lastName), ['Claes', 'Ssebowa']);
  });

  test('searches first name, last name, full name and code', () async {
    final repo = EmployeeRepository(db);

    Future<List<String?>> search(String term) async =>
        (await repo.listForCompany(almeco, nameOrCodeContains: term)).map((e) => e.lastName).toList();

    expect(await search('disan'), ['Ssebowa']);
    expect(await search('Vermeulen'), ['Vermeulen']);
    expect(await search('Disan Sse'), ['Ssebowa']);
    expect(await search('${stamp}KOB'), ["O'Brien"]);
    expect(await search("O'Bri"), ["O'Brien"], reason: 'quote in search');
    expect(await search('%'), isEmpty, reason: 'wildcards are literal');
  });

  test('findDetails: scoped to the company, with phone and all active groups', () async {
    final repo = EmployeeRepository(db);
    final list = await repo.listForCompany(almeco);
    final thomas = list.firstWhere((e) => e.lastName == 'Vermeulen');

    final details = await repo.findDetails(almeco, thomas.id);
    expect(details?.companyName, '[DEV-TEST] $stamp Almeco');
    expect(details?.groups, [groupName('Blue collar'), groupName('White collar')]);
    expect(await repo.findDetails(pca, thomas.id), isNull, reason: 'not a PCA member');
  });

  test('CompanyRepository.exists: true for listed, false for unknown', () async {
    final companies = CompanyRepository(db);

    expect(await companies.exists(almeco), isTrue);
    expect(await companies.exists(-1), isFalse);
  });
}
