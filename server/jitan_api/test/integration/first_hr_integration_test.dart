@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:jitan_api/src/auth/credential_access_repository.dart';
import 'package:jitan_api/src/auth/first_hr_setup_service.dart';
import 'package:jitan_api/src/auth/password_hasher.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// The very first HR person in one step (AUTH-03, user 2026-11-13), against
/// real MySQL, and the command itself. `[DEV-TEST]` fixtures are removed
/// afterwards.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late FirstHrSetupService service;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  const password = 'First-Password-2026';
  final users = <int>[];
  final groups = <int>[];
  final modules = <int>[];

  Future<int> insert(String sql, Map<String, Object?> values) async => (await db.execute(sql, values)).lastInsertId;

  Future<int> user(String code, {int active = 1, String? hash}) async {
    final id = await insert(
      'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userPassword, userActive, userMFD) '
      "VALUES ('[DEV-TEST]', 'First', :c, :c, :h, :a, 0)",
      {'c': code, 'a': active, 'h': hash},
    );
    users.add(id);
    return id;
  }

  Future<int> accessGroup(String name) async {
    final id = await insert('INSERT INTO tblCredGroup (credGroupName, credGroupLevel, credGroupActive, credGroupMFD) VALUES (:n, 0, 1, 0)', {
      'n': '[DEV-TEST] $name $stamp',
    });
    groups.add(id);
    return id;
  }

  Future<int> module([String name = 'HR']) async {
    final id = await insert('INSERT INTO tblAppModules (appModuleName, appModuleActive, appModuleMFD) VALUES (:n, 1, 0)', {'n': '[DEV-TEST] $name $stamp'});
    modules.add(id);
    return id;
  }

  Future<int?> userIdOf(String code) async {
    final rows = await db.query('SELECT userID FROM tblUser WHERE userCode = :c', {'c': code});
    if (rows.isEmpty) return null;
    final id = rows.single.readInt('userID');
    if (!users.contains(id)) users.add(id);
    return id;
  }

  Future<String?> hashOf(int id) async =>
      (await db.query('SELECT userPassword FROM tblUser WHERE userID = :u', {'u': id})).single.readOptionalString('userPassword');

  Future<bool> opensHr(int id) => CredentialAccessRepository(db).hasModuleAccess(id);

  Future<int> events(int id) async => (await db.query('SELECT COUNT(*) AS n FROM tblEventLog WHERE userIDInit = :u', {'u': id})).single.readInt('n');

  setUpAll(() async {
    db = TestDatabase.connect();
    service = FirstHrSetupService(transactions: db, executor: db, hasher: const PasswordHasher());
  });

  tearDownAll(() async {
    for (final id in users) {
      await db.execute(
        'DELETE et FROM tblEventLogEventType et JOIN tblEventLog l ON l.eventLogID = et.eventLogID '
        'WHERE l.userIDInit = :u OR l.userIDTarget = :u',
        {'u': id},
      );
      await db.execute('DELETE FROM tblEventLog WHERE userIDInit = :u OR userIDTarget = :u', {'u': id});
      await db.execute('DELETE FROM tblUserCredGroup WHERE userID = :u', {'u': id});
      await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': id});
    }
    for (final id in groups) {
      await db.execute('DELETE FROM tblAppModulesCredGroup WHERE credGroupID = :g', {'g': id});
      await db.execute('DELETE FROM tblCredGroup WHERE credGroupID = :g', {'g': id});
    }
    for (final id in modules) {
      await db.execute('DELETE FROM tblAppModules WHERE appModulesID = :m', {'m': id});
    }
    await db.close();
  });

  test('a new code: the employee, their group, its module and the password, in one step, audited', () async {
    final hr = await accessGroup('HR');
    final hrModule = await module();
    expect((await service.lookUp('FH1$stamp')).code, FirstHrCode.newEmployee);

    final result = await service.setUp(
      code: 'FH1$stamp',
      firstName: '[DEV-TEST] Hanna',
      lastName: 'First',
      credGroupId: hr,
      moduleId: hrModule,
      password: password,
    );

    expect(result, FirstHrResult.done);
    final id = (await userIdOf('FH1$stamp'))!;
    expect(await const PasswordHasher().verify(password, (await hashOf(id))!), true);
    expect(await opensHr(id), true, reason: 'group → module: may open HR');
    final qr = (await db.query('SELECT userQRcode FROM tblUser WHERE userID = :u', {'u': id})).single.readOptionalString('userQRcode');
    expect(qr, isNotNull, reason: 'a Terminal QR, as at any employee creation');
    expect(await events(id), 4, reason: 'created, module linked, group assigned, password set');
  });

  test('an existing employee without a password, in a group that already opens a module', () async {
    final hr = await accessGroup('HR');
    final hrModule = await module();
    await db.execute(
      'INSERT INTO tblAppModulesCredGroup (appModulesID, credGroupID, appModulesCredGroupActive, appModulesCredGroupMFD) VALUES (:m, :g, 1, 0)',
      {'m': hrModule, 'g': hr},
    );
    final id = await user('FH2$stamp');
    expect((await service.lookUp('FH2$stamp')).name, '[DEV-TEST] First');
    expect(await service.opensAModule(hr), true);

    expect(await service.setUp(code: 'FH2$stamp', credGroupId: hr, password: password), FirstHrResult.done);

    expect(await opensHr(id), true);
    expect(await events(id), 2, reason: 'group assigned, password set');
  });

  test('never takes over an account: one with a password changes nothing', () async {
    final hr = await accessGroup('HR');
    final id = await user('FH3$stamp', hash: r'$argon2id$v=19$m=19456,t=2,p=1$c2FsdA$aGFzaA');
    expect((await service.lookUp('FH3$stamp')).code, FirstHrCode.hasPassword);

    expect(await service.setUp(code: 'FH3$stamp', credGroupId: hr, moduleId: await module(), password: password), FirstHrResult.alreadyHasPassword);

    expect(await opensHr(id), false);
    expect(await events(id), 0);
  });

  test('a group with no module and none chosen: nothing is kept, not even the new employee', () async {
    final hr = await accessGroup('HR without module');

    expect(
      await service.setUp(code: 'FH4$stamp', firstName: '[DEV-TEST] New', lastName: 'Person', credGroupId: hr, password: password),
      FirstHrResult.moduleNeeded,
    );

    expect(await userIdOf('FH4$stamp'), isNull, reason: 'rolled back');
  });

  test('a code a switched-off employee has is never reused', () async {
    await user('FH5$stamp', active: 0);

    expect((await service.lookUp('FH5$stamp')).code, FirstHrCode.taken);
    expect(
      await service.setUp(code: 'FH5$stamp', firstName: 'X', lastName: 'Y', credGroupId: await accessGroup('HR'), moduleId: await module(), password: password),
      FirstHrResult.codeTaken,
    );
  });

  test('a password or a name the rules refuse changes nothing', () async {
    final hr = await accessGroup('HR');
    await expectLater(service.setUp(code: 'FH6$stamp', firstName: 'A', lastName: 'B', credGroupId: hr, password: 'short'), throwsA(isA<ApiException>()));
    await expectLater(
      service.setUp(code: 'FH6$stamp', firstName: '', lastName: 'B', credGroupId: hr, moduleId: await module(), password: password),
      throwsA(isA<ApiException>()),
    );
    expect(await userIdOf('FH6$stamp'), isNull);
  });

  group('the command', () {
    /// Runs the command, typing [lines] one after the other.
    Future<ProcessResult> run(List<String> lines) async {
      final process = await Process.start(Platform.resolvedExecutable, ['run', 'bin/first_hr.dart'], environment: {'JITAN_ENV': 'development'});
      process.stdin.write(lines.map((line) => '$line\n').join());
      await process.stdin.close();
      final out = process.stdout.transform(utf8.decoder).join();
      final err = process.stderr.transform(utf8.decoder).join();
      final code = await process.exitCode;
      return ProcessResult(process.pid, code, await out, await err);
    }

    /// The number IT types to pick [name] from a printed list.
    String pick(String output, String name) => RegExp(r'(\d+)\) ' + RegExp.escape(name)).firstMatch(output)!.group(1)!;

    test('a new HR person in one run; the password is never printed', () async {
      await accessGroup('CLI');
      await module('CLI');
      // The lists are IT's rows: a run that stops at a list shows our
      // fixtures' numbers, and changes nothing.
      final atGroups = await run(['FH7$stamp', '[DEV-TEST] Cli', 'First']);
      final groupNumber = pick('${atGroups.stdout}', '[DEV-TEST] CLI $stamp');
      final atModules = await run(['FH7$stamp', '[DEV-TEST] Cli', 'First', groupNumber]);
      final moduleNumber = pick('${atModules.stdout}'.split('Which one may it open?').last, '[DEV-TEST] CLI $stamp');
      expect(await userIdOf('FH7$stamp'), isNull, reason: 'a run that stops changes nothing');

      final result = await run(['FH7$stamp', '[DEV-TEST] Cli', 'First', groupNumber, moduleNumber, password, password]);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('can now sign in'));
      expect('${result.stdout}${result.stderr}', isNot(contains(password)));
      expect(await opensHr((await userIdOf('FH7$stamp'))!), true);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('two different passwords change nothing', () async {
      final hr = await accessGroup('CLI2');
      await db.execute(
        'INSERT INTO tblAppModulesCredGroup (appModulesID, credGroupID, appModulesCredGroupActive, appModulesCredGroupMFD) VALUES (:m, :g, 1, 0)',
        {'m': await module('CLI2'), 'g': hr},
      );
      final id = await user('FH8$stamp');
      final dry = await run(['FH8$stamp']);
      final number = pick('${dry.stdout}', '[DEV-TEST] CLI2 $stamp');

      final result = await run(['FH8$stamp', number, password, 'something-else']);

      expect(result.exitCode, 1);
      expect(await hashOf(id), isNull);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
