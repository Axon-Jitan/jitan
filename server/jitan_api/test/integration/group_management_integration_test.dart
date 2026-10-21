@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/groups/group_management_repository.dart';
import 'package:jitan_api/src/groups/group_management_service.dart';
import 'package:jitan_api/src/groups/group_repository.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// HR/Admin managing employee groups against real MySQL with `[DEV-TEST]`
/// fixtures. The tests run in order.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late GroupManagementService groups;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final prefix = '[DEV-TEST] $stamp';
  final createdEventTypes = <int>[];
  late int actor;
  late int member;
  late int driversId;

  Future<List<String>> auditTypes(int groupId) async => [
    for (final row in await db.query(
      'SELECT t.eventTypeName FROM tblEventLog l JOIN tblEventLogEventType et ON et.eventLogID = l.eventLogID '
      'JOIN tblEventType t ON t.eventTypeID = et.eventTypeID WHERE l.groupID = :g AND l.userIDInit = :a '
      'ORDER BY l.eventLogID',
      {'g': groupId, 'a': actor},
    ))
      row.readString('eventTypeName'),
  ];

  /// Step 1 of Create group on its own (GroupSetupService adds the
  /// employees and work hours in the same transaction).
  Future<GroupOverview> create(String name) async =>
      groups.find(await db.transaction((tx) => groups.createIn(tx, actor, GroupManagementService.validName(name))));

  setUpAll(() async {
    db = TestDatabase.connect();
    groups = GroupManagementService(
      groups: const GroupManagementRepository(),
      audit: const AuditLogRepository(),
      transactions: db,
      executor: db,
    );
    for (final name in ['group.created', 'group.renamed', 'group.deactivated', 'group.reactivated']) {
      if ((await db.query('SELECT 1 FROM tblEventType WHERE eventTypeName = :n', {'n': name})).isEmpty) {
        createdEventTypes.add(
          (await db.execute('INSERT INTO tblEventType (eventTypeName) VALUES (:n)', {'n': name})).lastInsertId,
        );
      }
    }
    Future<int> user(String key) async => (await db.execute(
      'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
      "VALUES ('[DEV-TEST]', 'Groups', :code, :qr, 1, 0)",
      {'code': 'DG$key$stamp', 'qr': 'DEV-TEST-DG$key$stamp'},
    )).lastInsertId;
    actor = await user('A');
    member = await user('M');
  });

  tearDownAll(() async {
    final ids = [
      for (final row in await db.query(
        "SELECT groupID FROM tblGroup WHERE groupName LIKE CONCAT(:p, '%')",
        {'p': prefix},
      ))
        row.readInt('groupID'),
    ];
    for (final id in ids) {
      for (final log in await db.query('SELECT eventLogID FROM tblEventLog WHERE groupID = :g', {'g': id})) {
        await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
        await db.execute('DELETE FROM tblEventLog WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
      }
      await db.execute('DELETE FROM tblUserGroup WHERE groupID = :g', {'g': id});
      await db.execute('DELETE FROM tblGroup WHERE groupID = :g', {'g': id});
    }
    for (final id in [actor, member]) {
      await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': id});
    }
    for (final id in createdEventTypes) {
      await db.execute('DELETE FROM tblEventType WHERE eventTypeID = :t', {'t': id});
    }
    await db.close();
  });

  test('adding a group trims the name, makes it active and assignable, audited', () async {
    final created = await create('  $prefix Drivers  ');
    driversId = created.id;

    expect((created.name, created.isActive, created.employeeCount), ('$prefix Drivers', true, 0));
    expect((await GroupRepository(db).listActive()).map((g) => g.id), contains(driversId));
    expect(await auditTypes(driversId), ['group.created']);
  });

  test('a name already in use, ignoring upper/lower case, is refused', () async {
    await expectLater(
      create('$prefix DRIVERS'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCode.duplicateGroupName)
          .having((e) => e.field, 'field', 'name')),
    );
  });

  test('renaming: to the same name changes nothing; to another group\'s name is refused', () async {
    final other = await create('$prefix Office');

    await groups.rename(actor, driversId, GroupNameRequest(name: '$prefix Drivers'));
    expect(await auditTypes(driversId), ['group.created'], reason: 'nothing changed, nothing audited');

    await expectLater(
      groups.rename(actor, driversId, GroupNameRequest(name: '$prefix office')),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.duplicateGroupName)),
    );

    final renamed = await groups.rename(actor, driversId, GroupNameRequest(name: '$prefix Van drivers'));
    expect(renamed.name, '$prefix Van drivers');
    expect(await auditTypes(driversId), ['group.created', 'group.renamed']);
    expect(other.isActive, isTrue);
  });

  test('a group with employees can\'t be deactivated; an empty one can, and comes back on reactivate', () async {
    await db.execute(
      'INSERT INTO tblUserGroup (userID, groupID, userGroupActive, userGroupMFD) VALUES (:u, :g, 1, 0)',
      {'u': member, 'g': driversId},
    );

    await expectLater(
      groups.deactivate(actor, driversId),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCode.groupInUse)
          .having((e) => e.message, 'message', contains('1 employee'))),
    );

    await db.execute(
      'UPDATE tblUserGroup SET userGroupActive = 0, userGroupMFD = 1 WHERE userID = :u AND groupID = :g',
      {'u': member, 'g': driversId},
    );
    final deactivated = await groups.deactivate(actor, driversId);
    expect(deactivated.isActive, isFalse);
    expect((await GroupRepository(db).listActive()).map((g) => g.id), isNot(contains(driversId)));
    expect((await groups.overview()).firstWhere((g) => g.id == driversId).isActive, isFalse, reason: 'still listed');

    await expectLater(
      create('$prefix Van Drivers'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.duplicateGroupName)),
      reason: 'inactive groups keep their name',
    );

    await groups.deactivate(actor, driversId);
    expect((await groups.reactivate(actor, driversId)).isActive, isTrue);
    await groups.reactivate(actor, driversId);
    expect(
      await auditTypes(driversId),
      ['group.created', 'group.renamed', 'group.deactivated', 'group.reactivated'],
      reason: 'repeating an action that changes nothing is not audited',
    );
  });

  test('the overview counts current employees only', () async {
    await db.execute(
      'UPDATE tblUserGroup SET userGroupActive = 1, userGroupMFD = 0 WHERE userID = :u AND groupID = :g',
      {'u': member, 'g': driversId},
    );

    expect((await groups.overview()).firstWhere((g) => g.id == driversId).employeeCount, 1);
  });

  test('an unknown group is 404', () async {
    await expectLater(
      groups.deactivate(actor, 999999999),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });
}
