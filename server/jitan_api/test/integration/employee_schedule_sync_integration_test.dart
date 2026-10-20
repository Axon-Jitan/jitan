@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/groups/group_repository.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/schedules/employee_schedule_sync.dart';
import 'package:jitan_api/src/schedules/schedule_editing_service.dart';
import 'package:jitan_api/src/schedules/schedule_names.dart';
import 'package:jitan_api/src/schedules/schedule_repository.dart';
import 'package:jitan_api/src/schedules/schedule_service.dart';
import 'package:jitan_api/src/schedules/schedule_write_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// An employee's schedules following their groups, against real MySQL with
/// `[DEV-TEST]` fixtures. The tests run in order and tell one story: N joins
/// Blue, also joins White, switches to White's schedule, leaves White, leaves
/// Blue.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late ScheduleEditingService editing;
  const sync = EmployeeScheduleSync();
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final users = <String, int>{};
  final groups = <String, int>{};
  final createdTypes = <int>[];
  final createdDays = <int>[];
  late int monday;

  Future<void> join(String user, String group) async {
    final existing = await db.query(
      'SELECT userGroupID FROM tblUserGroup WHERE userID = :u AND groupID = :g',
      {'u': users[user], 'g': groups[group]},
    );
    if (existing.isEmpty) {
      await db.execute(
        'INSERT INTO tblUserGroup (userID, groupID, userGroupActive, userGroupMFD) VALUES (:u, :g, 1, 0)',
        {'u': users[user], 'g': groups[group]},
      );
    } else {
      await db.execute(
        'UPDATE tblUserGroup SET userGroupActive = 1, userGroupMFD = 0 WHERE userGroupID = :id',
        {'id': existing.single.readInt('userGroupID')},
      );
    }
  }

  Future<void> leave(String user, String group) => db.execute(
    'UPDATE tblUserGroup SET userGroupActive = 0, userGroupMFD = 1 WHERE userID = :u AND groupID = :g',
    {'u': users[user], 'g': groups[group]},
  );

  Future<void> synced(String user) => db.transaction((tx) => sync.afterGroupChange(tx, users['actor']!, users[user]!));

  Future<Set<int>> rowsOf(String user) async => {
    for (final row in await db.query(
      'SELECT scheduleID FROM tblUserSchedule WHERE userID = :u AND userScheduleActive = 1 AND userScheduleMFD = 0',
      {'u': users[user]},
    ))
      row.readInt('scheduleID'),
  };

  Future<void> setHours(String group, String start) => editing.setWorkHours(
    users['actor']!,
    groups[group]!,
    SetWorkHoursRequest(
      days: [WorkHoursDay(dayId: monday, start: start, finish: '16:00')],
      arrivalToleranceMinutes: 0,
      leavingToleranceMinutes: 0,
      startRounding: const ScheduleRounding(intervalMinutes: 15, roundUp: true),
      finishRounding: const ScheduleRounding(intervalMinutes: 15, roundUp: false),
    ),
  );

  setUpAll(() async {
    db = TestDatabase.connect();
    editing = ScheduleEditingService(
      writes: const ScheduleWriteRepository(),
      schedules: ScheduleService(schedules: ScheduleRepository(db), groups: GroupRepository(db)),
      audit: const AuditLogRepository(),
      transactions: db,
    );
    for (final name in ScheduleTypeNames.all) {
      if ((await db.query(
        'SELECT 1 FROM tblScheduleType WHERE scheduleTypeName = :n AND scheduleTypeActive = 1 AND scheduleTypeMFD = 0',
        {'n': name},
      )).isEmpty) {
        createdTypes.add((await db.execute(
          'INSERT INTO tblScheduleType (scheduleTypeName, scheduleTypeActive, scheduleTypeMFD) VALUES (:n, 1, 0)',
          {'n': name},
        )).lastInsertId);
      }
    }
    final mondays = await db.query("SELECT dayID FROM tblDays WHERE dayName = 'Monday' AND dayActive = 1 AND dayMFD = 0");
    if (mondays.isNotEmpty) {
      monday = mondays.first.readInt('dayID');
    } else {
      monday = (await db.execute("INSERT INTO tblDays (dayName, dayActive, dayMFD) VALUES ('Monday', 1, 0)")).lastInsertId;
      createdDays.add(monday);
    }
    for (final key in ['blue', 'white', 'solo', 'nobody']) {
      groups[key] = (await db.execute(
        'INSERT INTO tblGroup (groupName, groupActive, groupMFD) VALUES (:n, 1, 0)',
        {'n': '[DEV-TEST] $key $stamp'},
      )).lastInsertId;
    }
    for (final key in ['actor', 'A', 'B', 'W', 'S', 'N']) {
      users[key] = (await db.execute(
        'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
        "VALUES ('[DEV-TEST]', 'Sync', :code, :qr, 1, 0)",
        {'code': 'DY$key$stamp', 'qr': 'DEV-TEST-DY$key$stamp'},
      )).lastInsertId;
    }
    await join('A', 'blue');
    await join('B', 'blue');
    await join('W', 'white');
    await join('S', 'solo');
    await setHours('blue', '08:00');
    await setHours('white', '09:00');
    await setHours('solo', '10:00');
  });

  tearDownAll(() async {
    final scheduleIds = <int>{};
    for (final id in users.values) {
      for (final row in await db.query('SELECT scheduleID FROM tblUserSchedule WHERE userID = :u', {'u': id})) {
        scheduleIds.add(row.readInt('scheduleID'));
      }
    }
    for (final row in await db.query(
      'SELECT eventLogID, scheduleID FROM tblEventLog WHERE userIDInit = :a',
      {'a': users['actor']},
    )) {
      if (row.readOptionalInt('scheduleID') case final id?) scheduleIds.add(id);
      await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID = :l', {'l': row.readInt('eventLogID')});
      await db.execute('DELETE FROM tblEventLog WHERE eventLogID = :l', {'l': row.readInt('eventLogID')});
    }
    final ruleIds = <int>{};
    for (final id in scheduleIds) {
      for (final row in await db.query('SELECT roundingRuleID FROM tblScheduleRoundingRule WHERE scheduleID = :s', {'s': id})) {
        ruleIds.add(row.readInt('roundingRuleID'));
      }
      await db.execute('DELETE FROM tblScheduleRoundingRule WHERE scheduleID = :s', {'s': id});
      await db.execute('DELETE FROM tblUserSchedule WHERE scheduleID = :s', {'s': id});
    }
    for (final id in ruleIds) {
      await db.execute('DELETE FROM tblRoundingRule WHERE roundingRuleID = :r', {'r': id});
    }
    for (final id in scheduleIds) {
      await db.execute('DELETE FROM tblSchedule WHERE scheduleID = :s', {'s': id});
    }
    for (final id in users.values) {
      await db.execute('DELETE FROM tblUserGroup WHERE userID = :u', {'u': id});
      await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': id});
    }
    for (final id in groups.values) {
      await db.execute('DELETE FROM tblGroup WHERE groupID = :g', {'g': id});
    }
    for (final id in createdTypes) {
      await db.execute('DELETE FROM tblScheduleType WHERE scheduleTypeID = :t', {'t': id});
    }
    for (final id in createdDays) {
      await db.execute('DELETE FROM tblDays WHERE dayID = :d', {'d': id});
    }
    await db.close();
  });

  test('joining one group gives that group\'s schedule', () async {
    await join('N', 'blue');
    await synced('N');

    expect(await rowsOf('N'), await rowsOf('A'));
    expect(await rowsOf('N'), isNotEmpty);
  });

  test('joining a second group keeps the schedule; its source is still the first group', () async {
    await join('N', 'white');
    await synced('N');

    expect(await rowsOf('N'), await rowsOf('A'));
    expect(await sync.currentSource(db, users['N']!), groups['blue']);
  });

  test('"Schedules come from" another of the groups switches to that group\'s schedule', () async {
    await db.transaction((tx) => sync.useGroup(tx, users['actor']!, users['N']!, groups['white']!));

    expect(await rowsOf('N'), await rowsOf('W'));
    expect(await sync.currentSource(db, users['N']!), groups['white']);
  });

  test('"Schedules come from" refuses a group the employee is not in, or one nobody is only in', () async {
    await expectLater(
      db.transaction((tx) => sync.useGroup(tx, users['actor']!, users['N']!, groups['solo']!)),
      throwsA(isA<ApiException>().having((e) => e.field, 'field', 'groupId')),
    );
    await join('N', 'nobody');
    await expectLater(
      db.transaction((tx) => sync.useGroup(tx, users['actor']!, users['N']!, groups['nobody']!)),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.groupWithoutEmployees)),
    );
    await leave('N', 'nobody');
  });

  test('leaving the group the schedule came from, with one group left: that group\'s schedule', () async {
    await leave('N', 'white');
    await synced('N');

    expect(await rowsOf('N'), await rowsOf('A'));
  });

  test('leaving every group: no schedule (links switched off, kept)', () async {
    await leave('N', 'blue');
    await synced('N');

    expect(await rowsOf('N'), isEmpty);
    final history = await db.query('SELECT COUNT(*) AS n FROM tblUserSchedule WHERE userID = :u', {'u': users['N']});
    expect(history.single.readInt('n'), greaterThan(0), reason: 'nothing deleted');
  });

  test('when the group\'s employees differ, nothing is picked: the employee keeps what they had', () async {
    // B gets an extra start row, so A and B differ.
    final extra = (await db.execute(
      'INSERT INTO tblSchedule (scheduleTypeID, dayID, scheduleHrStart, scheduleMinStart, scheduleHrStop, '
      'scheduleMinStop, scheduleMarginMin, scheduleActive, scheduleMFD) '
      'SELECT scheduleTypeID, :d, 6, 0, 14, 0, 0, 1, 0 FROM tblScheduleType WHERE scheduleTypeName = :t LIMIT 1',
      {'d': monday, 't': ScheduleTypeNames.workStart},
    )).lastInsertId;
    await db.execute(
      'INSERT INTO tblUserSchedule (userID, scheduleID, userScheduleActive, userScheduleMFD) VALUES (:u, :s, 1, 0)',
      {'u': users['B'], 's': extra},
    );

    await join('N', 'blue');
    await synced('N');

    expect(await rowsOf('N'), isEmpty);
    await expectLater(
      db.transaction((tx) => sync.useGroup(tx, users['actor']!, users['N']!, groups['blue']!)),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.scheduleEmployeesDiffer)),
    );
  });

  test('when the last employee with a schedule leaves, the unused rows are switched off and audited', () async {
    final soloRows = await rowsOf('S');

    await leave('S', 'solo');
    await synced('S');

    expect(await rowsOf('S'), isEmpty);
    final rows = await db.query(
      'SELECT scheduleActive, scheduleMFD FROM tblSchedule WHERE scheduleID IN (${soloRows.join(',')})',
    );
    expect([for (final r in rows) (r.readBool('scheduleActive'), r.readBool('scheduleMFD'))], everyElement((false, true)));
    final audited = await db.query(
      'SELECT COUNT(*) AS n FROM tblEventLog WHERE userIDTarget = :u AND scheduleID IN (${soloRows.join(',')})',
      {'u': users['S']},
    );
    expect(audited.single.readInt('n'), soloRows.length);
  });
}
