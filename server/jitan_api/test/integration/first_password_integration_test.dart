@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:jitan_api/src/auth/first_password_service.dart';
import 'package:jitan_api/src/auth/password_hasher.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// The very first password (AUTH-03) against real MySQL, and the tool itself.
/// `[DEV-TEST]` fixtures are removed afterwards.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late FirstPasswordService service;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final users = <int>[];
  const password = 'First-Password-2026';

  Future<int> user(String code, {int active = 1}) async {
    final id = (await db.execute(
      'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
      "VALUES ('[DEV-TEST]', 'First', :c, :c, :a, 0)",
      {'c': code, 'a': active},
    )).lastInsertId;
    users.add(id);
    return id;
  }

  Future<String?> hashOf(int id) async =>
      (await db.query('SELECT userPassword FROM tblUser WHERE userID = :u', {'u': id})).single.readOptionalString('userPassword');

  setUpAll(() async {
    db = TestDatabase.connect();
    service = FirstPasswordService(transactions: db, hasher: const PasswordHasher());
  });

  tearDownAll(() async {
    for (final id in users) {
      await db.execute(
        'DELETE et FROM tblEventLogEventType et JOIN tblEventLog l ON l.eventLogID = et.eventLogID '
        'WHERE l.userIDInit = :u OR l.userIDTarget = :u',
        {'u': id},
      );
      await db.execute('DELETE FROM tblEventLog WHERE userIDInit = :u OR userIDTarget = :u', {'u': id});
      await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': id});
    }
    await db.close();
  });

  test('sets a real password, audited; the password is never stored as typed', () async {
    final id = await user('FP1$stamp');

    expect(await service.set('FP1$stamp', password), FirstPasswordResult.set);

    final hash = (await hashOf(id))!;
    expect(hash, startsWith(r'$argon2id$'));
    expect(await const PasswordHasher().verify(password, hash), true);
    final events = await db.query('SELECT eventLogID FROM tblEventLog WHERE userIDTarget = :u', {'u': id});
    expect(events, hasLength(1));
  });

  test('never replaces a password: it can not take over an account', () async {
    final id = await user('FP2$stamp');
    await service.set('FP2$stamp', password);
    final before = await hashOf(id);

    expect(await service.set('FP2$stamp', 'Another-Password-1'), FirstPasswordResult.alreadyHasPassword);

    expect(await hashOf(id), before);
  });

  test('an unknown code or a switched-off account changes nothing', () async {
    final id = await user('FP3$stamp', active: 0);

    expect(await service.set('FP3$stamp', password), FirstPasswordResult.noSuchEmployee);
    expect(await service.set('NOBODY$stamp', password), FirstPasswordResult.noSuchEmployee);
    expect(await hashOf(id), isNull);
  });

  test('a password that breaks the rules is refused before anything else', () async {
    await expectLater(service.set('FP1$stamp', 'short'), throwsA(isA<ApiException>()));
  });

  group('the tool', () {
    Future<ProcessResult> run(List<String> arguments, String typed) async {
      final process = await Process.start(Platform.resolvedExecutable, ['run', 'bin/set_first_password.dart', ...arguments], environment: {'JITAN_ENV': 'development'});
      process.stdin.write(typed);
      await process.stdin.close();
      final out = process.stdout.transform(utf8.decoder).join();
      final err = process.stderr.transform(utf8.decoder).join();
      final code = await process.exitCode;
      return ProcessResult(process.pid, code, await out, await err);
    }

    test('sets the password and never prints it', () async {
      final id = await user('FP4$stamp');

      final result = await run(['FP4$stamp'], '$password\n$password\n');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, contains('can now sign in'));
      expect('${result.stdout}${result.stderr}', isNot(contains(password)));
      expect(await hashOf(id), isNotNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('two different passwords change nothing', () async {
      final id = await user('FP5$stamp');

      final result = await run(['FP5$stamp'], '$password\nsomething-else\n');

      expect(result.exitCode, 1);
      expect(await hashOf(id), isNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('no code: says how to use it', () async {
      final result = await run([], '');

      expect(result.exitCode, 64);
      expect(result.stderr, contains('Usage'));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
