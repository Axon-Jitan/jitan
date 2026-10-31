@Tags(['integration'])
library;

import 'package:jitan_api/src/auth/credential_access_repository.dart';
import 'package:jitan_api/src/auth/credential_permission_evaluator.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_api/src/auth/request_identity.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// What IT sets up in its tables decides who opens HR. `[DEV-TEST]` fixtures
/// are removed afterwards. The tests run in order.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late CredentialPermissionEvaluator evaluator;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  late int user, group, module, userLink, moduleLink;

  Future<bool> allowed() => evaluator.isAllowed(RequestIdentity(userId: user), Permission.viewReports, companyId: 7);

  setUpAll(() async {
    db = TestDatabase.connect();
    evaluator = CredentialPermissionEvaluator(CredentialAccessRepository(db));
    user = (await db.execute(
      "INSERT INTO tblUser (userName, userSurname, userCode, userQRcode) VALUES ('[DEV-TEST]', 'Access', :c, :c)",
      {'c': 'ACC$stamp'},
    )).lastInsertId;
    group = (await db.execute(
      'INSERT INTO tblCredGroup (credGroupName, credGroupLevel, credGroupActive, credGroupMFD) VALUES (:n, 1, 1, 0)',
      {'n': '[DEV-TEST] $stamp'},
    )).lastInsertId;
    module = (await db.execute(
      'INSERT INTO tblAppModules (appModuleName, appModuleActive, appModuleMFD) VALUES (:n, 1, 0)',
      {'n': '[DEV-TEST] $stamp'},
    )).lastInsertId;
  });

  tearDownAll(() async {
    await db.execute('DELETE FROM tblAppModulesCredGroup WHERE credGroupID = :g', {'g': group});
    await db.execute('DELETE FROM tblUserCredGroup WHERE credGroupID = :g', {'g': group});
    await db.execute('DELETE FROM tblAppModules WHERE appModulesID = :m', {'m': module});
    await db.execute('DELETE FROM tblCredGroup WHERE credGroupID = :g', {'g': group});
    await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': user});
    await db.close();
  });

  test('nothing set up: no access', () async {
    expect(await allowed(), false);
  });

  test('in a group with no module: no access, like Employee', () async {
    userLink = (await db.execute(
      'INSERT INTO tblUserCredGroup (userID, credGroupID, userCredGroupActive, userCredGroupMFD) VALUES (:u, :g, 1, 0)',
      {'u': user, 'g': group},
    )).lastInsertId;

    expect(await allowed(), false);
  });

  test('IT links the group to a module: access, in any company', () async {
    moduleLink = (await db.execute(
      'INSERT INTO tblAppModulesCredGroup (appModulesID, credGroupID, appModulesCredGroupActive, appModulesCredGroupMFD) '
      'VALUES (:m, :g, 1, 0)',
      {'m': module, 'g': group},
    )).lastInsertId;

    expect(await allowed(), true);
  });

  test('switching off the person takes access away at once', () async {
    await db.execute('UPDATE tblUserCredGroup SET userCredGroupActive = 0 WHERE userCredGroupID = :id', {'id': userLink});
    expect(await allowed(), false);

    await db.execute('UPDATE tblUserCredGroup SET userCredGroupActive = 1 WHERE userCredGroupID = :id', {'id': userLink});
    expect(await allowed(), true);
  });

  test('switching off the group link takes access away at once', () async {
    await db.execute(
      'UPDATE tblAppModulesCredGroup SET appModulesCredGroupMFD = 1 WHERE appModulesCredGroupID = :id',
      {'id': moduleLink},
    );
    expect(await allowed(), false);

    await db.execute(
      'UPDATE tblAppModulesCredGroup SET appModulesCredGroupMFD = 0 WHERE appModulesCredGroupID = :id',
      {'id': moduleLink},
    );
    expect(await allowed(), true);
  });

  test('a group or module switched off opens nothing', () async {
    await db.execute('UPDATE tblCredGroup SET credGroupActive = 0 WHERE credGroupID = :g', {'g': group});
    expect(await allowed(), false);
    await db.execute('UPDATE tblCredGroup SET credGroupActive = 1 WHERE credGroupID = :g', {'g': group});

    await db.execute('UPDATE tblAppModules SET appModuleMFD = 1 WHERE appModulesID = :m', {'m': module});
    expect(await allowed(), false);
    await db.execute('UPDATE tblAppModules SET appModuleMFD = 0 WHERE appModulesID = :m', {'m': module});
    expect(await allowed(), true);
  });

  test('another person gets nothing from it', () async {
    expect(await evaluator.isAllowed(const RequestIdentity(userId: -1), Permission.viewCompanies), false);
  });
}
