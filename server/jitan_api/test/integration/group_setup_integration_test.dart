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

/// Create group: the group, its employees and its work hours in one
/// transaction, against real MySQL with `[DEV-TEST]` fixtures (removed in
/// tearDownAll). The tests run in order.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late GroupSetupService setup;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final prefix = '[DEV-TEST] $stamp';
  final users = <String, int>{};
  final createdTypes = <int>[];
  final createdEventTypes = <int>[];
  final createdDays = <int>[];
  late int company;
  late int otherGroup;
  late int monday;

  Future<void> allowed(int companyId) async {}

  CreateGroupRequest request(String name, List<String> employees, {String finish = '16:30'}) => CreateGroupRequest(
    name: '$prefix $name',
    employeeIds: [for (final e in employees) users[e]!],
    schedule: SetGroupScheduleRequest(
      workHours: SetWorkHoursRequest(
        days: [WorkHoursDay(dayId: monday, start: '08:00', finish: finish)],
        arrivalToleranceMinutes: 0,
        leavingToleranceMinutes: 0,
      ),
      breakMinutes: 30,
    ),
  );

  Future<int> groupsNamed(String name) async => (await db.query(
    'SELECT COUNT(*) AS n FROM tblGroup WHERE groupName = :n',
    {'n': '$prefix $name'},
  )).single.readInt('n');

  /// The type names of [user]'s current schedule rows.
  Future<List<String>> scheduleTypes(String user) async => [
    for (final row in await db.query(
      'SELECT st.scheduleTypeName FROM tblUserSchedule us JOIN tblSchedule s ON s.scheduleID = us.scheduleID '
      'JOIN tblScheduleType st ON st.scheduleTypeID = s.scheduleTypeID '
      'WHERE us.userID = :u AND us.userScheduleActive = 1 AND us.userScheduleMFD = 0 ORDER BY st.scheduleTypeName',
      {'u': users[user]},
    ))
      row.readString('scheduleTypeName'),
  ];

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 2);
    final members = GroupMemberService(
      members: GroupMemberRepository(db),
      assignments: const EmployeeAssignmentRepository(),
      employees: EmployeeRepository(db),
      audit: const AuditLogRepository(),
      scheduleSync: const EmployeeScheduleSync(),
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
      schedules: ScheduleEditingService(
        writes: const ScheduleWriteRepository(),
        schedules: ScheduleService(schedules: ScheduleRepository(db), groups: GroupRepository(db)),
        audit: const AuditLogRepository(),
        transactions: db,
      ),
      transactions: db,
    );
    for (final type in AuditEventType.values) {
      if ((await db.query('SELECT 1 FROM tblEventType WHERE eventTypeName = :n', {'n': type.typeName})).isEmpty) {
        createdEventTypes.add(
          (await db.execute('INSERT INTO tblEventType (eventTypeName) VALUES (:n)', {'n': type.typeName})).lastInsertId,
        );
      }
    }
    for (final name in ScheduleTypeNames.all) {
      final rows = await db.query(
        'SELECT 1 FROM tblScheduleType WHERE scheduleTypeName = :n AND scheduleTypeActive = 1 AND scheduleTypeMFD = 0',
        {'n': name},
      );
      if (rows.isEmpty) {
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
    otherGroup = (await db.execute(
      'INSERT INTO tblGroup (groupName, groupActive, groupMFD) VALUES (:n, 1, 0)',
      {'n': '$prefix White collar'},
    )).lastInsertId;
    // S and T: in no group yet. M: already in White collar.
    for (final key in ['actor', 'S', 'M', 'T']) {
      users[key] = (await db.execute(
        'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
        "VALUES ('[DEV-TEST]', 'Setup', :code, :qr, 1, 0)",
        {'code': 'GS$key$stamp', 'qr': 'DEV-TEST-GS$key$stamp'},
      )).lastInsertId;
      await db.execute(
        'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)',
        {'u': users[key], 'c': company},
      );
    }
    await db.execute(
      'INSERT INTO tblUserGroup (userID, groupID, userGroupActive, userGroupMFD) VALUES (:u, :g, 1, 0)',
      {'u': users['M'], 'g': otherGroup},
    );
  });

  tearDownAll(() async {
    final groupIds = [
      for (final row in await db.query("SELECT groupID FROM tblGroup WHERE groupName LIKE CONCAT(:p, '%')", {'p': prefix}))
        row.readInt('groupID'),
    ];
    final scheduleIds = <int>{};
    for (final row in await db.query(
      'SELECT eventLogID, scheduleID FROM tblEventLog WHERE groupID IN (${groupIds.join(',')}) OR userIDInit = :a',
      {'a': users['actor']},
    )) {
      if (row.readOptionalInt('scheduleID') case final id?) scheduleIds.add(id);
      await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID = :l', {'l': row.readInt('eventLogID')});
      await db.execute('DELETE FROM tblEventLog WHERE eventLogID = :l', {'l': row.readInt('eventLogID')});
    }
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
      await db.execute('DELETE FROM tblSchedule WHERE scheduleID = :s', {'s': id});
    }
    for (final id in groupIds) {
      await db.execute('DELETE FROM tblGroup WHERE groupID = :g', {'g': id});
    }
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

  test('nobody who would be only in the group: refused before anything is written', () async {
    await expectLater(
      setup.create(users['actor']!, request('Drivers', ['M']), mayManage: allowed),
      throwsA(isA<ApiException>().having((e) => e.field, 'field', CreateGroupRequest.fieldEmployeeIds)),
    );
    expect(await groupsNamed('Drivers'), 0);
  });

  test('finish before start: refused, no group, the employee keeps no new group', () async {
    await expectLater(
      setup.create(users['actor']!, request('Drivers', ['S'], finish: '07:00'), mayManage: allowed),
      throwsA(isA<ApiException>()),
    );
    expect(await groupsNamed('Drivers'), 0);
    expect(
      (await db.query('SELECT 1 FROM tblUserGroup WHERE userID = :u AND userGroupActive = 1', {'u': users['S']})),
      isEmpty,
    );
  });

  test('the group, both employees and the hours on the one only in it, together', () async {
    final created = await setup.create(users['actor']!, request('Drivers', ['S', 'M']), mayManage: allowed);

    expect((created.name, created.isActive, created.employeeCount), ('$prefix Drivers', true, 2));
    expect(
      await scheduleTypes('S'),
      unorderedEquals([ScheduleTypeNames.breakTime, ScheduleTypeNames.workStart, ScheduleTypeNames.workFinish]),
      reason: 'S is only in Drivers: the hours and the break are kept on S',
    );
    final audited = [
      for (final row in await db.query(
        'SELECT t.eventTypeName FROM tblEventLog l JOIN tblEventLogEventType et ON et.eventLogID = l.eventLogID '
        'JOIN tblEventType t ON t.eventTypeID = et.eventTypeID WHERE l.groupID = :g',
        {'g': created.id},
      ))
        row.readString('eventTypeName'),
    ];
    expect(audited, containsAll(['group.created', 'employee.group.assigned', 'schedule.created']));
  });

  test('a name already taken: refused, nothing else written', () async {
    await expectLater(
      setup.create(users['actor']!, request('DRIVERS', ['T']), mayManage: allowed),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
    );
    expect(await groupsNamed('DRIVERS'), 1, reason: 'the existing Drivers (case-insensitive match)');
  });

  test('a group without employees or work hours (both optional)', () async {
    final created = await setup.create(users['actor']!, CreateGroupRequest(name: '$prefix Empty'), mayManage: allowed);
    expect((created.name, created.employeeCount), ('$prefix Empty', 0));
  });
}
