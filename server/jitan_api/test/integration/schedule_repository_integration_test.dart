@Tags(['integration'])
library;

import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/groups/group_repository.dart';
import 'package:jitan_api/src/schedules/schedule_names.dart';
import 'package:jitan_api/src/schedules/schedule_repository.dart';
import 'package:jitan_api/src/schedules/schedule_service.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Schedule reads against real MySQL with `[DEV-TEST]` fixtures, removed in
/// tearDownAll. Reference rows (schedule types, Monday) are used when they
/// exist and only created, and removed again, when they don't.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late ScheduleRepository repo;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final users = <String, int>{};
  final groups = <String, int>{};
  final schedules = <String, int>{};
  final rules = <String, int>{};
  final typeIds = <String, int>{};
  final createdTypes = <int>[];
  int? createdMonday;
  late int monday;

  Future<int> insertUser(String key, {bool active = true}) async => users[key] = (await db.execute(
    'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
    "VALUES ('[DEV-TEST]', 'Schedule', :code, :qr, :active, 0)",
    {'code': 'DS$key$stamp', 'qr': 'DEV-TEST-DS$key$stamp', 'active': active},
  )).lastInsertId;

  Future<void> link(String user, String group, {bool removed = false}) => db.execute(
    'INSERT INTO tblUserGroup (userID, groupID, userGroupActive, userGroupMFD) VALUES (:u, :g, :a, :m)',
    {'u': users[user], 'g': groups[group], 'a': !removed, 'm': removed},
  );

  Future<int> insertSchedule(String key, String type, {bool active = true}) async => schedules[key] = (await db.execute(
    'INSERT INTO tblSchedule (scheduleTypeID, dayID, scheduleHrStart, scheduleMinStart, scheduleHrStop, '
    'scheduleMinStop, scheduleMarginMin, scheduleActive, scheduleMFD) VALUES (:t, :d, 8, 0, 16, 30, 10, :a, 0)',
    {'t': typeIds[type], 'd': monday, 'a': active},
  )).lastInsertId;

  Future<void> give(String user, String schedule, {bool removed = false}) => db.execute(
    'INSERT INTO tblUserSchedule (userID, scheduleID, userScheduleActive, userScheduleMFD) VALUES (:u, :s, :a, :m)',
    {'u': users[user], 's': schedules[schedule], 'a': !removed, 'm': removed},
  );

  Future<int> insertRule(String key, int minutes, {required bool up, bool deleted = false}) async =>
      rules[key] = (await db.execute(
        'INSERT INTO tblRoundingRule (roundingRuleValueInMin, roundingRuleRoundUp, roundingRuleActive, roundingRuleMFD) '
        'VALUES (:v, :up, 1, :m)',
        {'v': minutes, 'up': up, 'm': deleted},
      )).lastInsertId;

  Future<void> attach(String schedule, String rule, {bool removed = false}) => db.execute(
    'INSERT INTO tblScheduleRoundingRule (scheduleID, roundingRuleID, scheduleRoundingRuleActive, scheduleRoundingRuleMFD) '
    'VALUES (:s, :r, :a, :m)',
    {'s': schedules[schedule], 'r': rules[rule], 'a': !removed, 'm': removed},
  );

  setUpAll(() async {
    db = TestDatabase.connect();
    repo = ScheduleRepository(db);
    for (final name in ScheduleTypeNames.all) {
      final existing = await db.query(
        'SELECT scheduleTypeID FROM tblScheduleType WHERE scheduleTypeName = :n AND scheduleTypeActive = 1 '
        'AND scheduleTypeMFD = 0 ORDER BY scheduleTypeID LIMIT 1',
        {'n': name},
      );
      if (existing.isNotEmpty) {
        typeIds[name] = existing.single.readInt('scheduleTypeID');
      } else {
        final id = (await db.execute(
          'INSERT INTO tblScheduleType (scheduleTypeName, scheduleTypeActive, scheduleTypeMFD) VALUES (:n, 1, 0)',
          {'n': name},
        )).lastInsertId;
        typeIds[name] = id;
        createdTypes.add(id);
      }
    }
    final mondayRows = await db.query(
      "SELECT dayID FROM tblDays WHERE dayName = 'Monday' AND dayActive = 1 AND dayMFD = 0 ORDER BY dayID LIMIT 1",
    );
    if (mondayRows.isNotEmpty) {
      monday = mondayRows.single.readInt('dayID');
    } else {
      monday = createdMonday =
          (await db.execute("INSERT INTO tblDays (dayName, dayActive, dayMFD) VALUES ('Monday', 1, 0)")).lastInsertId;
    }

    for (final key in ['one', 'two']) {
      groups[key] = (await db.execute(
        'INSERT INTO tblGroup (groupName, groupActive, groupMFD) VALUES (:n, 1, 0)',
        {'n': '[DEV-TEST] $key $stamp'},
      )).lastInsertId;
    }
    await insertUser('A'); // only in group one
    await insertUser('B'); // in groups one and two
    await insertUser('C', active: false); // only in group one, but inactive
    await insertUser('D'); // membership in group one removed
    await insertUser('E'); // in group one; membership in group two removed
    await link('A', 'one');
    await link('B', 'one');
    await link('B', 'two');
    await link('C', 'one');
    await link('D', 'one', removed: true);
    await link('E', 'one');
    await link('E', 'two', removed: true);

    await insertSchedule('start', ScheduleTypeNames.workStart);
    await insertSchedule('inactive', ScheduleTypeNames.workStart, active: false);
    await insertSchedule('break', ScheduleTypeNames.breakTime);
    await give('A', 'start');
    await give('A', 'inactive');
    await give('A', 'break', removed: true);

    await insertRule('current', 15, up: true);
    await insertRule('deleted', 30, up: false, deleted: true);
    await insertRule('unlinked', 60, up: true);
    await attach('start', 'current');
    await attach('start', 'deleted');
    await attach('start', 'unlinked', removed: true);
  });

  tearDownAll(() async {
    for (final id in schedules.values) {
      await db.execute('DELETE FROM tblScheduleRoundingRule WHERE scheduleID = :id', {'id': id});
      await db.execute('DELETE FROM tblUserSchedule WHERE scheduleID = :id', {'id': id});
    }
    for (final id in rules.values) {
      await db.execute('DELETE FROM tblRoundingRule WHERE roundingRuleID = :id', {'id': id});
    }
    for (final id in schedules.values) {
      await db.execute('DELETE FROM tblSchedule WHERE scheduleID = :id', {'id': id});
    }
    for (final id in users.values) {
      await db.execute('DELETE FROM tblUserGroup WHERE userID = :id', {'id': id});
      await db.execute('DELETE FROM tblUser WHERE userID = :id', {'id': id});
    }
    for (final id in groups.values) {
      await db.execute('DELETE FROM tblGroup WHERE groupID = :id', {'id': id});
    }
    for (final id in createdTypes) {
      await db.execute('DELETE FROM tblScheduleType WHERE scheduleTypeID = :id', {'id': id});
    }
    if (createdMonday != null) await db.execute('DELETE FROM tblDays WHERE dayID = :id', {'id': createdMonday});
    await db.close();
  });

  test('single-group members: only active employees with exactly one current, active group', () async {
    final members = {
      for (final m in await repo.singleGroupMembers())
        if (groups.values.contains(m.groupId)) (m.groupId, m.userId),
    };

    expect(members, {(groups['one'], users['A']), (groups['one'], users['E'])},
        reason: 'B is in two groups, C is inactive, D was removed, E\'s second group was removed');
  });

  test('schedules of an employee: current links to active schedules only', () async {
    final rows = await repo.schedulesOf([users['A']!]);

    expect([for (final r in rows) r.scheduleId], [schedules['start']]);
    final start = rows.single;
    expect(start.typeName, ScheduleTypeNames.workStart);
    expect((start.dayId, start.startHour, start.startMinute, start.stopHour, start.stopMinute, start.marginMinutes),
        (monday, 8, 0, 16, 30, 10));
  });

  test('rules of a schedule: current links to active, non-deleted rules only', () async {
    final linked = await repo.rulesOf([schedules['start']!]);

    expect([for (final r in linked) (r.intervalMinutes, r.roundUp)], [(15, true)]);
  });

  test('no ids, no query', () async {
    expect(await repo.schedulesOf(const []), isEmpty);
    expect(await repo.rulesOf(const []), isEmpty);
  });

  test('end to end: group one has two employees only in it, with different schedules', () async {
    final service = ScheduleService(schedules: repo, groups: GroupRepository(db));

    final one = (await service.groupSchedules()).firstWhere((g) => g.group.id == groups['one']);

    expect(one.status, GroupScheduleStatus.employeesDiffer, reason: 'A has a start, E has nothing');
    expect(one.singleGroupEmployeeCount, 2);
    final withStart = one.variants.firstWhere((v) => v.workDays.isNotEmpty);
    expect(withStart.workDays.single.start!.time, '08:00');
    expect(withStart.favour, ScheduleRoundingFavour.company);
  });
}
