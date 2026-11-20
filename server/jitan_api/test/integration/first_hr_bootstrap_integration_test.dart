@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/auth/credential_access_repository.dart';
import 'package:jitan_api/src/auth/first_hr_setup_service.dart';
import 'package:jitan_api/src/auth/password_hasher.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/database/sql_executor.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Opt-in, disposable EMPTY schema only. Never use IT's database. Test cleanup
/// clears the tables this command writes; the initial emptiness is verified.
void main() {
  if (Platform.environment['JITAN_TEST_DB_NAME'] != 'jitan_bootstrap_test' || Platform.environment['JITAN_TEST_BOOTSTRAP_EMPTY'] != 'true') {
    test('empty database bootstrap', () {}, skip: 'Requires dedicated jitan_bootstrap_test and JITAN_TEST_BOOTSTRAP_EMPTY=true.');
    return;
  }
  late Database db;
  var verifiedEmpty = false;
  const password = 'Local-test-password-2026';
  const tables = ['tblEventLogEventType', 'tblEventLog', 'tblUserCredGroup', 'tblAppModulesCredGroup', 'tblUser', 'tblCredGroup', 'tblAppModules'];
  Future<int> count(String table) async => (await db.query('SELECT COUNT(*) AS n FROM $table')).single.readInt('n');
  Future<void> expectEmpty() async {
    for (final table in tables) {
      expect(await count(table), 0, reason: table);
    }
  }

  FirstHrSetupService service({AuditLogRepository audit = const AuditLogRepository()}) =>
      FirstHrSetupService(transactions: db, executor: db, hasher: const PasswordHasher(), audit: audit);
  Future<FirstHrResult> create({AuditLogRepository audit = const AuditLogRepository()}) =>
      service(audit: audit).setUp(code: 'BOOTSTRAP_TEST', firstName: '[DEV-TEST] Super', lastName: 'HR', password: password, createMissingAccess: true);
  Future<ProcessResult> run(List<String> lines) async {
    final p = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'bin/first_hr.dart'],
      environment: {
        'JITAN_ENV': 'development',
        'DB_HOST': Platform.environment['JITAN_TEST_DB_HOST']!,
        'DB_PORT': Platform.environment['JITAN_TEST_DB_PORT']!,
        'DB_NAME': 'jitan_bootstrap_test',
        'DB_USER': Platform.environment['JITAN_TEST_DB_USER']!,
        'DB_PASS': Platform.environment['JITAN_TEST_DB_PASSWORD']!,
        'JITAN_DB_SECURE': 'true',
      },
    );
    p.stdin.write('${lines.join('\n')}\n');
    await p.stdin.close();
    final out = p.stdout.transform(utf8.decoder).join();
    final err = p.stderr.transform(utf8.decoder).join();
    return ProcessResult(p.pid, await p.exitCode, await out, await err);
  }

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 4);
    await expectEmpty();
    verifiedEmpty = true;
  });
  tearDown(() async {
    if (verifiedEmpty) {
      for (final table in tables) {
        await db.execute('DELETE FROM $table');
      }
    }
  });
  tearDownAll(() async => db.close());

  test('cancel or mismatched passwords leave all bootstrap records absent', () async {
    for (final lines in [
      ['BOOTSTRAP_TEST', '[DEV-TEST] Super', 'HR'],
      ['BOOTSTRAP_TEST', '[DEV-TEST] Super', 'HR', password, 'different'],
    ]) {
      final result = await run(lines);
      expect(result.exitCode, 1);
      await expectEmpty();
    }
  });

  test('an audit failure rolls back the employee, group and module', () async {
    await expectLater(create(audit: const _FailOnModuleAudit()), throwsStateError);
    await expectEmpty();
  });

  test('inactive access policy is preserved and new employee/group rolled back', () async {
    await db.execute("INSERT INTO tblAppModules (appModuleName, appModuleActive, appModuleMFD) VALUES ('[DEV-TEST] Disabled', 0, 0)");
    expect(await create(), FirstHrResult.moduleNeeded);
    expect(await count('tblUser'), 0);
    expect(await count('tblCredGroup'), 0);
    expect(await count('tblEventLog'), 0);
    expect((await db.query('SELECT appModuleActive FROM tblAppModules')).single.readBool('appModuleActive'), false);
  });

  test('empty CLI creates all required records, grants access, hides password; rerun is safe', () async {
    final result = await run(['BOOTSTRAP_TEST', '[DEV-TEST] Super', 'HR', password, password]);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('can now sign in'));
    expect('${result.stdout}${result.stderr}', isNot(contains(password)));
    final user = (await db.query('SELECT userID, userPassword FROM tblUser')).single;
    expect(await const PasswordHasher().verify(password, user.readString('userPassword')), true);
    expect(await CredentialAccessRepository(db).hasModuleAccess(user.readInt('userID')), true);
    expect(await count('tblCredGroup'), 1);
    expect(await count('tblAppModules'), 1);
    expect(await count('tblUserCredGroup'), 1);
    expect(await count('tblAppModulesCredGroup'), 1);
    expect(await count('tblEventLog'), 6);
    final again = await run(['BOOTSTRAP_TEST']);
    expect(again.exitCode, 1);
    expect(again.stderr, contains('already has a password'));
    expect(await count('tblUser'), 1);
    expect(await count('tblEventLog'), 6);
  });

  test('concurrent first setup creates one account and one access policy', () async {
    final results = await Future.wait([create(), create()]);
    expect(results, unorderedEquals([FirstHrResult.done, FirstHrResult.alreadyHasPassword]));
    expect(await count('tblUser'), 1);
    expect(await count('tblCredGroup'), 1);
    expect(await count('tblAppModules'), 1);
  });
}

class _FailOnModuleAudit extends AuditLogRepository {
  const _FailOnModuleAudit();
  @override
  Future<void> record(SqlExecutor tx, AuditEvent event) async {
    if (event.type == AuditEventType.appModuleCreated) throw StateError('Injected audit failure');
    await super.record(tx, event);
  }
}
