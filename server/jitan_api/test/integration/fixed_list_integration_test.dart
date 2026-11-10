@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/lists/fixed_list_repository.dart';
import 'package:jitan_api/src/lists/fixed_list_service.dart';
import 'package:jitan_api/src/terminals/terminal_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// The Lists page against MySQL: what Jitan reads by name, what is missing,
/// and adding exactly that, audited.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late FixedListService lists;
  late int actor;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 2);
    lists = FixedListService(lists: const FixedListRepository(), audit: const AuditLogRepository(), transactions: db, executor: db);
    actor = (await db.execute(
      "INSERT INTO tblUser (userName, userSurname, userCode, userActive, userMFD) VALUES ('[DEV-TEST]', 'Lists', :c, 1, 0)",
      {'c': 'DTL$stamp'},
    )).lastInsertId;
  });

  tearDownAll(() async {
    await db.execute(
      'DELETE t FROM tblEventLogEventType t JOIN tblEventLog e ON e.eventLogID = t.eventLogID WHERE e.userIDInit = :u',
      {'u': actor},
    );
    await db.execute('DELETE FROM tblEventLog WHERE userIDInit = :u', {'u': actor});
    await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': actor});
    await db.close();
  });

  test('every list is there, and the needed entries come first in their own order', () async {
    final overview = await lists.overview();

    expect(overview.lists.map((l) => l.kind), FixedListKind.values);
    final days = await lists.detail(FixedListKind.days);
    expect(days.entries.take(7).map((e) => e.name), ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']);
    expect(days.entries.take(7).every((e) => e.required), isTrue);
  });

  test('a missing entry is added once, audited, and a complete list adds nothing', () async {
    const name = TerminalRepository.vehicleTypeName;
    final original = (await db.query(
      'SELECT deviceTypeID FROM tblDeviceType WHERE deviceTypeName = :n AND deviceTypeActive = 1 AND deviceTypeMFD = 0',
      {'n': name},
    )).single.readInt('deviceTypeID');
    await db.execute('UPDATE tblDeviceType SET deviceTypeActive = 0 WHERE deviceTypeID = :id', {'id': original});
    try {
      expect((await lists.detail(FixedListKind.terminalKinds)).entries.firstWhere((e) => e.name == name).present, isFalse);

      final added = await lists.addMissing(actor, FixedListKind.terminalKinds);
      await lists.addMissing(actor, FixedListKind.terminalKinds);

      expect(added.missing, 0);
      final audited = await db.query('SELECT deviceTypeID FROM tblEventLog WHERE userIDInit = :u', {'u': actor});
      expect(audited, hasLength(1), reason: 'the second add had nothing to add');
      await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID IN (SELECT eventLogID FROM tblEventLog WHERE userIDInit = :u)', {'u': actor});
      await db.execute('DELETE FROM tblEventLog WHERE userIDInit = :u', {'u': actor});
      await db.execute('DELETE FROM tblDeviceType WHERE deviceTypeID = :id', {'id': audited.single.readInt('deviceTypeID')});
    } finally {
      await db.execute('UPDATE tblDeviceType SET deviceTypeActive = 1 WHERE deviceTypeID = :id', {'id': original});
    }
  });

  test('free lists are only counted', () async {
    await expectLater(lists.addMissing(actor, FixedListKind.accessRoles), throwsA(anything));
  });
}
