@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/employees/employee_assignment_repository.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/groups/group_member_repository.dart';
import 'package:jitan_api/src/groups/group_member_service.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/schedules/employee_schedule_sync.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// A group's members from every company, against real MySQL with
/// `[DEV-TEST]` fixtures (removed in tearDownAll). The tests run in order.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late GroupMemberService service;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final prefix = '[DEV-TEST] $stamp';
  final users = <String, int>{};
  final companies = <String, int>{};
  final createdEventTypes = <int>[];
  late int group;
  late int inactiveGroup;

  Future<bool> everyone(int companyId) async => true;
  Future<void> allowed(int companyId) async {}

  Future<int> audited(String type, int userId) async => (await db.query(
    'SELECT COUNT(*) AS n FROM tblEventLog l JOIN tblEventLogEventType et ON et.eventLogID = l.eventLogID '
    'JOIN tblEventType t ON t.eventTypeID = et.eventTypeID '
    'WHERE t.eventTypeName = :t AND l.userIDTarget = :u AND l.groupID = :g',
    {'t': type, 'u': userId, 'g': group},
  )).single.readInt('n');

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 2);
    service = GroupMemberService(
      members: GroupMemberRepository(db),
      assignments: const EmployeeAssignmentRepository(),
      employees: EmployeeRepository(db),
      audit: const AuditLogRepository(),
      scheduleSync: const EmployeeScheduleSync(),
      transactions: db,
    );
    for (final name in ['employee.group.assigned', 'employee.group.removed']) {
      if ((await db.query('SELECT 1 FROM tblEventType WHERE eventTypeName = :n', {'n': name})).isEmpty) {
        createdEventTypes.add((await db.execute('INSERT INTO tblEventType (eventTypeName) VALUES (:n)', {'n': name})).lastInsertId);
      }
    }
    for (final key in ['north', 'south']) {
      companies[key] = (await db.execute(
        'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:n, 1, 0)',
        {'n': '$prefix $key'},
      )).lastInsertId;
    }
    for (final (key, surname) in [('actor', 'Actor'), ('A', 'Ackers'), ('B', 'Brandt'), ('C', 'Claes'), ('X', 'Xenon')]) {
      users[key] = (await db.execute(
        'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
        "VALUES ('[DEV-TEST]', :s, :code, :qr, 1, 0)",
        {'s': surname, 'code': 'GM$key$stamp', 'qr': 'DEV-TEST-GM$key$stamp'},
      )).lastInsertId;
    }
    // A in North, B in South, C in both; X in no company.
    for (final (user, company) in [('A', 'north'), ('B', 'south'), ('C', 'north'), ('C', 'south')]) {
      await db.execute(
        'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)',
        {'u': users[user], 'c': companies[company]},
      );
    }
    group = (await db.execute(
      'INSERT INTO tblGroup (groupName, groupActive, groupMFD) VALUES (:n, 1, 0)',
      {'n': '$prefix Drivers'},
    )).lastInsertId;
    inactiveGroup = (await db.execute(
      'INSERT INTO tblGroup (groupName, groupActive, groupMFD) VALUES (:n, 0, 0)',
      {'n': '$prefix Old'},
    )).lastInsertId;
  });

  tearDownAll(() async {
    for (final id in users.values) {
      for (final log in await db.query('SELECT eventLogID FROM tblEventLog WHERE userIDTarget = :u OR userIDInit = :u', {'u': id})) {
        await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
        await db.execute('DELETE FROM tblEventLog WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
      }
      await db.execute('DELETE FROM tblUserSchedule WHERE userID = :u', {'u': id});
      await db.execute('DELETE FROM tblUserGroup WHERE userID = :u', {'u': id});
      await db.execute('DELETE FROM tblUserCompany WHERE userID = :u', {'u': id});
      await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': id});
    }
    for (final id in [group, inactiveGroup]) {
      await db.execute('DELETE FROM tblGroup WHERE groupID = :g', {'g': id});
    }
    for (final id in companies.values) {
      await db.execute('DELETE FROM tblCompany WHERE companyID = :c', {'c': id});
    }
    for (final id in createdEventTypes) {
      await db.execute('DELETE FROM tblEventType WHERE eventTypeID = :t', {'t': id});
    }
    await db.close();
  });

  test('candidates: employees of every company, not someone without a company; searchable', () async {
    final all = await service.candidates(group, search: '[DEV-TEST]', mayView: everyone);
    final ours = [for (final m in all) if (users.values.contains(m.id)) m];

    expect([for (final m in ours) m.code], ['GMA$stamp', 'GMB$stamp', 'GMC$stamp'],
        reason: 'A (North), B (South), C (both); X and the actor are in no company');
    expect(ours.firstWhere((m) => m.id == users['C']).companies, ['$prefix north', '$prefix south']);

    final searched = await service.candidates(group, search: 'Brandt', mayView: everyone);
    expect([for (final m in searched) m.id], [users['B']]);
  });

  test('candidates for a group still being created: everyone with a company', () async {
    final all = await service.candidates(null, search: '[DEV-TEST]', mayView: everyone);
    expect([for (final m in all) if (users.values.contains(m.id)) m.code], ['GMA$stamp', 'GMB$stamp', 'GMC$stamp']);
  });

  test('adding several employees from different companies: one save, each audited once', () async {
    final members = await service.add(users['actor']!, group, [users['A']!, users['B']!, users['C']!],
        mayManage: allowed, mayView: everyone);

    expect([for (final m in members) m.id], [users['A'], users['B'], users['C']]);
    expect(members.first.groups, ['$prefix Drivers']);
    for (final key in ['A', 'B', 'C']) {
      expect(await audited('employee.group.assigned', users[key]!), 1, reason: key);
    }
  });

  test('adding someone already in the group changes nothing and is not audited again', () async {
    await service.add(users['actor']!, group, [users['A']!], mayManage: allowed, mayView: everyone);

    expect(await audited('employee.group.assigned', users['A']!), 1);
    expect(await service.candidates(group, search: 'Ackers', mayView: everyone), isEmpty, reason: 'A is a member now');
  });

  test('only employees of companies the user may see are listed', () async {
    final members = await service.members(group, mayView: (companyId) async => companyId == companies['north']);

    expect([for (final m in members) m.id], [users['A'], users['C']], reason: 'B is only in South');
  });

  test('changing a member needs the right in every company of the employee', () async {
    final asked = <int>[];
    await expectLater(
      service.remove(users['actor']!, group, users['C']!, mayView: everyone, mayManage: (companyId) async {
        asked.add(companyId);
        if (companyId == companies['south']) throw const ApiException.forbidden('no');
      }),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );
    expect(asked, containsAll([companies['north'], companies['south']]));
    expect([for (final m in await service.members(group, mayView: everyone)) m.id], contains(users['C']), reason: 'nothing changed');
  });

  test('removing a member is a soft delete, audited; the employee can be added again', () async {
    final members = await service.remove(users['actor']!, group, users['B']!, mayManage: allowed, mayView: everyone);

    expect([for (final m in members) m.id], isNot(contains(users['B'])));
    final link = await db.query(
      'SELECT userGroupActive, userGroupMFD FROM tblUserGroup WHERE userID = :u AND groupID = :g',
      {'u': users['B'], 'g': group},
    );
    expect((link.single.readBool('userGroupActive'), link.single.readBool('userGroupMFD')), (false, true));
    expect(await audited('employee.group.removed', users['B']!), 1);

    await service.add(users['actor']!, group, [users['B']!], mayManage: allowed, mayView: everyone);
    expect(
      (await db.query('SELECT COUNT(*) AS n FROM tblUserGroup WHERE userID = :u AND groupID = :g', {'u': users['B'], 'g': group}))
          .single
          .readInt('n'),
      1,
      reason: 'the removed link is reactivated, not duplicated',
    );
  });

  test('refusals: a deactivated group, no employees, someone in no company, an unknown group', () async {
    await expectLater(
      service.add(users['actor']!, inactiveGroup, [users['A']!], mayManage: allowed, mayView: everyone),
      throwsA(isA<ApiException>().having((e) => e.field, 'field', 'ids')),
    );
    await expectLater(
      service.add(users['actor']!, group, const [], mayManage: allowed, mayView: everyone),
      throwsA(isA<ApiException>().having((e) => e.field, 'field', 'ids')),
    );
    await expectLater(
      service.add(users['actor']!, group, [users['X']!], mayManage: allowed, mayView: everyone),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
    await expectLater(
      service.members(999999999, mayView: everyone),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });
}
