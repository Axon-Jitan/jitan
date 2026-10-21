@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/employees/employee_assignment_repository.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/groups/group_management_repository.dart';
import 'package:jitan_api/src/groups/group_management_service.dart';
import 'package:jitan_api/src/groups/group_member_repository.dart';
import 'package:jitan_api/src/groups/group_member_service.dart';
import 'package:jitan_api/src/groups/group_repository.dart';
import 'package:jitan_api/src/groups/group_setup_service.dart';
import 'package:jitan_api/src/schedules/employee_schedule_sync.dart';
import 'package:jitan_api/src/schedules/group_schedule_link_repository.dart';
import 'package:jitan_api/src/schedules/schedule_editing_service.dart';
import 'package:jitan_api/src/schedules/schedule_names.dart';
import 'package:jitan_api/src/schedules/schedule_repository.dart';
import 'package:jitan_api/src/schedules/schedule_service.dart';
import 'package:jitan_api/src/schedules/schedule_write_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// PROPOSAL (ERD_GAPS GAP-15): groups own their schedule through
/// `tblGroupSchedule`, against the local database where the proposed table
/// exists (`dev/local-db/proposals/gap15_group_schedule.sql`). Skipped where
/// it does not, e.g. IT's database. The tests run in order.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late bool hasTable;
  late GroupSetupService setup;
  late GroupMemberService members;
  late ScheduleEditingService editing;
  late ScheduleService schedules;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final prefix = '[DEV-TEST] $stamp';
  final users = <String, int>{};
  final createdTypes = <int>[];
  final createdEventTypes = <int>[];
  final createdDays = <int>[];
  late int company;
  late int monday;
  late int drivers;

  Future<void> allowed(int companyId) async {}
  Future<bool> everyone(int companyId) async => true;

  SetGroupScheduleRequest hours(String start, String finish) => SetGroupScheduleRequest(
    workHours: SetWorkHoursRequest(
      days: [WorkHoursDay(dayId: monday, start: start, finish: finish)],
      arrivalToleranceMinutes: 0,
      leavingToleranceMinutes: 0,
    ),
    breakMinutes: 30,
  );

  /// The (type, start) of [user]'s current schedule rows.
  Future<List<(String, String)>> employeeRows(String user) async => [
    for (final row in await db.query(
      'SELECT st.scheduleTypeName, s.scheduleHrStart, s.scheduleMinStart FROM tblUserSchedule us '
      'JOIN tblSchedule s ON s.scheduleID = us.scheduleID JOIN tblScheduleType st ON st.scheduleTypeID = s.scheduleTypeID '
      'WHERE us.userID = :u AND us.userScheduleActive = 1 AND us.userScheduleMFD = 0 ORDER BY st.scheduleTypeName',
      {'u': users[user]},
    ))
      (row.readString('scheduleTypeName'), '${row.readInt('scheduleHrStart')}:${row.readInt('scheduleMinStart')}'),
  ];

  Future<int> activeGroupLinks(int groupId) async => (await db.query(
    'SELECT COUNT(*) AS n FROM tblGroupSchedule WHERE groupID = :g AND groupScheduleActive = 1 AND groupScheduleMFD = 0',
    {'g': groupId},
  )).single.readInt('n');

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 2);
    hasTable = (await db.query(
      "SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tblGroupSchedule'",
    )).isNotEmpty;
    if (!hasTable) return;
    const links = GroupScheduleLinkRepository();
    const sync = EmployeeScheduleSync(groupLinks: links);
    schedules = ScheduleService(schedules: ScheduleRepository(db), groups: GroupRepository(db), groupLinks: links, db: db);
    editing = ScheduleEditingService(
      writes: const ScheduleWriteRepository(),
      schedules: schedules,
      audit: const AuditLogRepository(),
      transactions: db,
      groupLinks: links,
    );
    members = GroupMemberService(
      members: GroupMemberRepository(db),
      assignments: const EmployeeAssignmentRepository(),
      employees: EmployeeRepository(db),
      audit: const AuditLogRepository(),
      scheduleSync: sync,
      transactions: db,
    );
    setup = GroupSetupService(
      management: GroupManagementService(
        groups: const GroupManagementRepository(),
        audit: const AuditLogRepository(),
        transactions: db,
        executor: db,
      ),
      members: members,
      schedules: editing,
      transactions: db,
      groupsOwnSchedules: true,
    );
    for (final type in AuditEventType.values) {
      if ((await db.query('SELECT 1 FROM tblEventType WHERE eventTypeName = :n', {'n': type.typeName})).isEmpty) {
        createdEventTypes.add(
          (await db.execute('INSERT INTO tblEventType (eventTypeName) VALUES (:n)', {'n': type.typeName})).lastInsertId,
        );
      }
    }
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
    final days = await db.query("SELECT dayID FROM tblDays WHERE dayName = 'Monday' AND dayActive = 1 AND dayMFD = 0");
    if (days.isNotEmpty) {
      monday = days.first.readInt('dayID');
    } else {
      monday = (await db.execute("INSERT INTO tblDays (dayName, dayActive, dayMFD) VALUES ('Monday', 1, 0)")).lastInsertId;
      createdDays.add(monday);
    }
    company = (await db.execute(
      'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:n, 1, 0)',
      {'n': '$prefix Company'},
    )).lastInsertId;
    for (final key in ['actor', 'A']) {
      users[key] = (await db.execute(
        'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
        "VALUES ('[DEV-TEST]', 'Links', :code, :qr, 1, 0)",
        {'code': 'GL$key$stamp', 'qr': 'DEV-TEST-GL$key$stamp'},
      )).lastInsertId;
      await db.execute(
        'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)',
        {'u': users[key], 'c': company},
      );
    }
  });

  tearDownAll(() async {
    if (!hasTable) return db.close();
    final groupIds = [
      for (final row in await db.query("SELECT groupID FROM tblGroup WHERE groupName LIKE CONCAT(:p, '%')", {'p': prefix}))
        row.readInt('groupID'),
    ];
    final scheduleIds = <int>{};
    final ids = groupIds.isEmpty ? '0' : groupIds.join(',');
    for (final row in await db.query(
      'SELECT eventLogID, scheduleID FROM tblEventLog WHERE groupID IN ($ids) OR userIDInit = :a',
      {'a': users['actor']},
    )) {
      if (row.readOptionalInt('scheduleID') case final id?) scheduleIds.add(id);
      await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID = :l', {'l': row.readInt('eventLogID')});
      await db.execute('DELETE FROM tblEventLog WHERE eventLogID = :l', {'l': row.readInt('eventLogID')});
    }
    for (final row in await db.query('SELECT scheduleID FROM tblGroupSchedule WHERE groupID IN ($ids)')) {
      scheduleIds.add(row.readInt('scheduleID'));
    }
    await db.execute('DELETE FROM tblGroupSchedule WHERE groupID IN ($ids)');
    for (final id in users.values) {
      for (final row in await db.query('SELECT scheduleID FROM tblUserSchedule WHERE userID = :u', {'u': id})) {
        scheduleIds.add(row.readInt('scheduleID'));
      }
      await db.execute('DELETE FROM tblUserSchedule WHERE userID = :u', {'u': id});
      await db.execute('DELETE FROM tblUserGroup WHERE userID = :u', {'u': id});
      await db.execute('DELETE FROM tblUserCompany WHERE userID = :u', {'u': id});
      await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': id});
    }
    for (final id in scheduleIds) {
      await db.execute('DELETE FROM tblScheduleRoundingRule WHERE scheduleID = :s', {'s': id});
      await db.execute('DELETE FROM tblSchedule WHERE scheduleID = :s', {'s': id});
    }
    await db.execute('DELETE FROM tblGroup WHERE groupID IN ($ids)');
    await db.execute('DELETE FROM tblCompany WHERE companyID = :c', {'c': company});
    for (final id in createdTypes) {
      await db.execute('DELETE FROM tblScheduleType WHERE scheduleTypeID = :t', {'t': id});
    }
    for (final id in createdEventTypes) {
      await db.execute('DELETE FROM tblEventType WHERE eventTypeID = :t', {'t': id});
    }
    for (final id in createdDays) {
      await db.execute('DELETE FROM tblDays WHERE dayID = :d', {'d': id});
    }
    await db.close();
  });

  test('an empty group keeps its own work hours', () async {
    if (!hasTable) return markTestSkipped('tblGroupSchedule (GAP-15) is not in this database');
    final created = await setup.create(
      users['actor']!,
      CreateGroupRequest(name: '$prefix Drivers', schedule: hours('06:00', '14:30')),
      mayManage: allowed,
    );
    drivers = created.id;

    expect(created.employeeCount, 0);
    expect(await activeGroupLinks(drivers), 3, reason: 'work start, work finish and the break');
    final schedule = await schedules.groupSchedule(drivers);
    expect(schedule!.status, GroupScheduleStatus.configured);
    expect(schedule.variants.single.workDays.single.start!.time, '06:00');
  });

  test('an employee who joins gets the group\'s hours', () async {
    if (!hasTable) return markTestSkipped('tblGroupSchedule (GAP-15) is not in this database');
    await members.add(users['actor']!, drivers, [users['A']!], mayManage: allowed, mayView: everyone);

    expect(
      await employeeRows('A'),
      unorderedEquals([(ScheduleTypeNames.breakTime, '10:0'), (ScheduleTypeNames.workFinish, '6:0'), (ScheduleTypeNames.workStart, '6:0')]),
      reason: 'the break is placed mid-day: 06:00–14:30, 30 min → 10:00',
    );

    final listed = (await schedules.employeeSchedules([users['A']!]))[users['A']]!;
    expect(listed.workDays.single.start!.time, '06:00', reason: 'the Employees list shows these hours');
    expect(listed.breaks.single.lengthMinutes, 30);
  });

  test('new hours: the group and its employee move to new rows; the old ones are switched off', () async {
    if (!hasTable) return markTestSkipped('tblGroupSchedule (GAP-15) is not in this database');
    final old = [for (final row in await db.query(
      'SELECT scheduleID FROM tblGroupSchedule WHERE groupID = :g AND groupScheduleActive = 1', {'g': drivers})) row.readInt('scheduleID')];
    await editing.setSchedule(users['actor']!, drivers, hours('07:00', '15:30'));

    expect(await activeGroupLinks(drivers), 3);
    expect((await employeeRows('A')).where((r) => r.$1 == ScheduleTypeNames.workStart).single.$2, '7:0');
    final stillActive = await db.query(
      'SELECT COUNT(*) AS n FROM tblSchedule WHERE scheduleID IN (${old.join(',')}) AND scheduleActive = 1',
    );
    expect(stillActive.single.readInt('n'), 0, reason: 'nobody uses the old rows: switched off, not deleted');
  });

  test('when the employee leaves, the group keeps its hours', () async {
    if (!hasTable) return markTestSkipped('tblGroupSchedule (GAP-15) is not in this database');
    await members.remove(users['actor']!, drivers, users['A']!, mayManage: allowed, mayView: everyone);

    expect(await employeeRows('A'), isEmpty);
    expect(await activeGroupLinks(drivers), 3);
    expect((await schedules.groupSchedule(drivers))!.status, GroupScheduleStatus.configured);
  });
}
