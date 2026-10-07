@Tags(['integration'])
library;

import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/health/database_health_repository.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Runs the real SQL against the dev/test database with `[DEV-TEST]`
/// fixtures, removed again in tearDown.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late CompanyRepository repository;
  final marker = '[DEV-TEST] ${DateTime.now().microsecondsSinceEpoch}';
  final createdCompanyIds = <int>[];
  final createdUserIds = <int>[];

  Future<int> insertCompany(String name, {bool active = true, bool mfd = false}) async {
    final fullName = '$marker $name';
    await db.query(
      'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:name, :active, :mfd)',
      {'name': fullName, 'active': active, 'mfd': mfd},
    );
    final rows = await db.query(
      'SELECT companyID FROM tblCompany WHERE companyName = :name',
      {'name': fullName},
    );
    final id = rows.single.readInt('companyID');
    createdCompanyIds.add(id);
    return id;
  }

  Future<int> insertUser(String code, {bool mfd = false}) async {
    final userCode = 'DT${DateTime.now().microsecondsSinceEpoch % 100000000}$code';
    await db.query(
      'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
      'VALUES (:first, :last, :code, :qr, 1, :mfd)',
      {'first': '[DEV-TEST]', 'last': code, 'code': userCode, 'qr': 'DEV-TEST-$userCode', 'mfd': mfd},
    );
    final rows = await db.query('SELECT userID FROM tblUser WHERE userCode = :code', {'code': userCode});
    final id = rows.single.readInt('userID');
    createdUserIds.add(id);
    return id;
  }

  Future<void> addMembership(int userId, int companyId) => db.query(
        'INSERT INTO tblUserCompany (userID, companyID) VALUES (:user, :company)',
        {'user': userId, 'company': companyId},
      );

  setUpAll(() {
    db = TestDatabase.connect();
    repository = CompanyRepository(db);
  });

  tearDownAll(() async {
    // Fixture cleanup only: test rows are removed physically so the dev
    // database is left as it was. Application code never deletes.
    for (final id in createdUserIds) {
      await db.query('DELETE FROM tblUserCompany WHERE userID = :id', {'id': id});
      await db.query('DELETE FROM tblUser WHERE userID = :id', {'id': id});
    }
    for (final id in createdCompanyIds) {
      await db.query('DELETE FROM tblUserCompany WHERE companyID = :id', {'id': id});
      await db.query('DELETE FROM tblCompany WHERE companyID = :id', {'id': id});
    }
    await db.close();
  });

  test('SELECT 1 health check succeeds', () async {
    await DatabaseHealthRepository(db).ping();
  });

  test('lists active and inactive companies, hides MFD, counts non-MFD members', () async {
    final alpha = await insertCompany('Alpha');
    await insertCompany('Bravo', active: false);
    await insertCompany('Charlie', mfd: true);

    await addMembership(await insertUser('A1'), alpha);
    await addMembership(await insertUser('A2'), alpha);
    await addMembership(await insertUser('A3', mfd: true), alpha);

    final result = await repository.listCompanies(nameContains: marker);

    expect(result.map((c) => c.name), ['$marker Alpha', '$marker Bravo']);
    expect(result.first.isActive, isTrue);
    expect(result.first.employeeCount, 2);
    expect(result.last.isActive, isFalse);
    expect(result.last.employeeCount, 0);
    expect(result.first.lastUpdatedAt, isNull);
  });

  test('search treats LIKE wildcards literally', () async {
    await insertCompany('100% Literal_Name');
    await insertCompany('100X LiteralXName');

    final result = await repository.listCompanies(nameContains: '$marker 100% Literal_');

    expect(result.map((c) => c.name), ['$marker 100% Literal_Name']);
  });

  test('search handles quotes and backslashes safely', () async {
    await insertCompany(r"O'Brien \ Sons");

    final result = await repository.listCompanies(nameContains: r"O'Brien \");

    expect(result.map((c) => c.name), ['$marker ' r"O'Brien \ Sons"]);
  });
}
