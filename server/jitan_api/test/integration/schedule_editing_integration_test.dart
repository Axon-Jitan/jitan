@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/groups/group_repository.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/schedules/schedule_editing_service.dart';
import 'package:jitan_api/src/schedules/schedule_names.dart';
import 'package:jitan_api/src/schedules/schedule_repository.dart';
import 'package:jitan_api/src/schedules/schedule_service.dart';
import 'package:jitan_api/src/schedules/schedule_write_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Saving schedules against real MySQL with `[DEV-TEST]` fixtures. The tests
/// run in order: each one builds on the state the previous left.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late ScheduleEditingService editing;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final users = <String, int>{};
  final groups = <String, int>{};
  final dayIds = <String, int>{};
  final createdTypes = <int>[];
  final createdDays = <int>[];
  final createdEventTypes = <int>[];

  Future<int> insertUser(String key) async => users[key] = (await db.execute(
    'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
    "VALUES ('[DEV-TEST]', 'Editing', :code, :qr, 1, 0)",
    {'code': 'DE$key$stamp', 'qr': 'DEV-TEST-DE$key$stamp'},
  )).lastInsertId;

  Future<void> join(String user, String group) => db.execute(
    'INSERT INTO tblUserGroup (userID, groupID, userGroupActive, userGroupMFD) VALUES (:u, :g, 1, 0)',
    {'u': users[user], 'g': groups[group]},
  );

  SetWorkHoursRequest hours(String start, String finish, {List<String> days = const ['Monday', 'Tuesday']}) =>
      SetWorkHoursRequest(
        days: [for (final d in days) WorkHoursDay(dayId: dayIds[d]!, start: start, finish: finish)],
        arrivalToleranceMinutes: 10,
        leavingToleranceMinutes: 5,
        startRounding: const ScheduleRounding(intervalMinutes: 15, roundUp: true),
        finishRounding: const ScheduleRounding(intervalMinutes: 30, roundUp: false),
      );

  /// (scheduleID, active) of the user's work or break links, current or not.
  Future<List<(int, bool)>> links(String user, {bool currentOnly = true}) async => [
    for (final row in await db.query(
      'SELECT scheduleID, userScheduleActive FROM tblUserSchedule WHERE userID = :u '
      '${currentOnly ? 'AND userScheduleActive = 1 AND userScheduleMFD = 0 ' : ''}ORDER BY scheduleID',
      {'u': users[user]},
    ))
      (row.readInt('scheduleID'), row.readBool('userScheduleActive')),
  ];

  Future<int> auditCount(String typeName) async => (await db.query(
    'SELECT COUNT(*) AS n FROM tblEventLog l '
    'WHERE l.groupID = :g AND l.userIDInit = :a AND EXISTS (SELECT 1 FROM tblEventLogEventType et '
    ' JOIN tblEventType t ON t.eventTypeID = et.eventTypeID WHERE et.eventLogID = l.eventLogID AND t.eventTypeName = :t)',
    {'g': groups['blue'], 'a': users['actor'], 't': typeName},
  )).single.readInt('n');

  Future<int> eventLogRows() async => (await db.query(
    'SELECT COUNT(*) AS n FROM tblEventLog WHERE groupID = :g',
    {'g': groups['blue']},
  )).single.readInt('n');

  setUpAll(() async {
    db = TestDatabase.connect();
    final schedules = ScheduleService(schedules: ScheduleRepository(db), groups: GroupRepository(db));
    editing = ScheduleEditingService(
      writes: const ScheduleWriteRepository(),
      schedules: schedules,
      audit: const AuditLogRepository(),
      transactions: db,
    );
    for (final name in ScheduleTypeNames.all) {
      final rows = await db.query(
        'SELECT scheduleTypeID FROM tblScheduleType WHERE scheduleTypeName = :n AND scheduleTypeActive = 1 '
        'AND scheduleTypeMFD = 0',
        {'n': name},
      );
      if (rows.isEmpty) {
        createdTypes.add((await db.execute(
          'INSERT INTO tblScheduleType (scheduleTypeName, scheduleTypeActive, scheduleTypeMFD) VALUES (:n, 1, 0)',
          {'n': name},
        )).lastInsertId);
      }
    }
    for (final name in ['schedule.created', 'schedule.deactivated']) {
      final rows = await db.query('SELECT eventTypeID FROM tblEventType WHERE eventTypeName = :n', {'n': name});
      if (rows.isEmpty) {
        createdEventTypes.add(
          (await db.execute('INSERT INTO tblEventType (eventTypeName) VALUES (:n)', {'n': name})).lastInsertId,
        );
      }
    }
    for (final name in ['Monday', 'Tuesday', 'Saturday']) {
      final rows = await db.query(
        'SELECT dayID FROM tblDays WHERE dayName = :n AND dayActive = 1 AND dayMFD = 0',
        {'n': name},
      );
      if (rows.isNotEmpty) {
        dayIds[name] = rows.first.readInt('dayID');
      } else {
        final id = (await db.execute(
          'INSERT INTO tblDays (dayName, dayActive, dayMFD) VALUES (:n, 1, 0)',
          {'n': name},
        )).lastInsertId;
        dayIds[name] = id;
        createdDays.add(id);
      }
    }
    for (final key in ['blue', 'white', 'empty']) {
      groups[key] = (await db.execute(
        'INSERT INTO tblGroup (groupName, groupActive, groupMFD) VALUES (:n, 1, 0)',
        {'n': '[DEV-TEST] $key $stamp'},
      )).lastInsertId;
    }
    await insertUser('actor');
    await insertUser('A'); // only Blue
    await insertUser('B'); // only Blue
    await insertUser('C'); // Blue and White
    await insertUser('W'); // only White
    await join('A', 'blue');
    await join('B', 'blue');
    await join('C', 'blue');
    await join('C', 'white');
    await join('W', 'white');
  });

  tearDownAll(() async {
    final userIds = users.values.toList();
    final scheduleIds = <int>{
      for (final id in userIds)
        for (final row in await db.query('SELECT scheduleID FROM tblUserSchedule WHERE userID = :u', {'u': id}))
          row.readInt('scheduleID'),
    };
    for (final row in await db.query(
      'SELECT eventLogID, scheduleID FROM tblEventLog WHERE groupID IN (${groups.values.join(',')})',
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
    for (final id in userIds) {
      await db.execute('DELETE FROM tblUserGroup WHERE userID = :u', {'u': id});
      await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': id});
    }
    for (final id in groups.values) {
      await db.execute('DELETE FROM tblGroup WHERE groupID = :g', {'g': id});
    }
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

  test('setting work hours gives the employees only in the group the same new rows, audited', () async {
    final result = await editing.setWorkHours(users['actor']!, groups['blue']!, hours('08:00', '16:30'));

    expect(result.status, GroupScheduleStatus.configured);
    final variant = result.variants.single;
    expect(variant.employeeCount, 2, reason: 'A and B; C is also in White');
    final monday = variant.workDays.firstWhere((d) => d.day.name == 'Monday');
    expect((monday.start!.time, monday.start!.toleranceMinutes, monday.start!.rounding!.intervalMinutes), ('08:00', 10, 15));
    expect((monday.start!.rounding!.roundUp, monday.finish!.rounding!.roundUp), (true, false));
    expect((monday.finish!.time, monday.finish!.toleranceMinutes, monday.finish!.rounding!.intervalMinutes), ('16:30', 5, 30));

    expect(await links('A'), hasLength(4), reason: 'start and finish on Monday and Tuesday');
    expect(await links('A'), await links('B'), reason: 'shared rows');
    expect(await links('C'), isEmpty, reason: 'C has no schedule from Blue yet');
    expect(await auditCount('schedule.created'), 4);
  });

  test('saving the same work hours again changes nothing', () async {
    final before = await links('A');
    final logs = await eventLogRows();

    await editing.setWorkHours(users['actor']!, groups['blue']!, hours('08:00', '16:30'));

    expect(await links('A'), before);
    expect(await eventLogRows(), logs);
  });

  test('changing them moves everyone to new rows; the old rows are switched off, not deleted', () async {
    final old = [for (final (id, _) in await links('A')) id];
    // C chose Blue as the source of their schedule: same rows as Blue.
    for (final id in old) {
      await db.execute(
        'INSERT INTO tblUserSchedule (userID, scheduleID, userScheduleActive, userScheduleMFD) VALUES (:u, :s, 1, 0)',
        {'u': users['C'], 's': id},
      );
    }

    await editing.setWorkHours(users['actor']!, groups['blue']!, hours('07:30', '16:00'));

    final now = [for (final (id, _) in await links('A')) id];
    expect(now, hasLength(4));
    expect(now.toSet().intersection(old.toSet()), isEmpty);
    expect([for (final (id, _) in await links('C')) id], now, reason: 'C follows Blue, so C moved too');
    final oldRows = await db.query(
      'SELECT scheduleActive, scheduleMFD FROM tblSchedule WHERE scheduleID IN (${old.join(',')})',
    );
    expect([for (final r in oldRows) (r.readBool('scheduleActive'), r.readBool('scheduleMFD'))], everyElement((false, true)));
    expect((await links('A', currentOnly: false)).where((l) => !l.$2), hasLength(4), reason: 'old links kept, switched off');
    expect(await auditCount('schedule.deactivated'), 4);
  });

  test('breaks: within the work hours they are saved; outside them, or on a day without hours, refused', () async {
    final result = await editing.setBreaks(
      users['actor']!,
      groups['blue']!,
      SetBreaksRequest(days: [BreakDay(dayId: dayIds['Monday']!, usualStart: '12:00', lengthMinutes: 30)]),
    );
    expect(result.variants.single.breaks.single.lengthMinutes, 30);
    expect(result.variants.single.workDays, hasLength(2), reason: 'work hours untouched');

    for (final day in [
      BreakDay(dayId: dayIds['Monday']!, usualStart: '15:45', lengthMinutes: 30),
      BreakDay(dayId: dayIds['Saturday']!, usualStart: '12:00', lengthMinutes: 30),
    ]) {
      await expectLater(
        editing.setBreaks(users['actor']!, groups['blue']!, SetBreaksRequest(days: [day])),
        throwsA(isA<ApiException>().having((e) => e.field, 'field', 'days')),
      );
    }
    expect((await editing.removeBreaks(users['actor']!, groups['blue']!)).variants.single.breaks, isEmpty);
  });

  test('a group nobody is only in cannot get a schedule', () async {
    await expectLater(
      editing.setWorkHours(users['actor']!, groups['empty']!, hours('08:00', '16:30')),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.groupWithoutEmployees)),
    );
  });

  test('breaks need one set of work hours: when employees differ, 409; saving work hours unifies them', () async {
    final extra = await db.query(
      'SELECT s.scheduleID FROM tblSchedule s JOIN tblScheduleType st ON st.scheduleTypeID = s.scheduleTypeID '
      'WHERE st.scheduleTypeName = :t AND s.scheduleActive = 0 ORDER BY s.scheduleID DESC LIMIT 1',
      {'t': ScheduleTypeNames.workStart},
    );
    await db.execute('UPDATE tblSchedule SET scheduleActive = 1, scheduleMFD = 0 WHERE scheduleID = :s',
        {'s': extra.single.readInt('scheduleID')});
    await db.execute(
      'UPDATE tblUserSchedule SET userScheduleActive = 1, userScheduleMFD = 0 WHERE userID = :u AND scheduleID = :s',
      {'u': users['B'], 's': extra.single.readInt('scheduleID')},
    );

    await expectLater(
      editing.setBreaks(
        users['actor']!,
        groups['blue']!,
        SetBreaksRequest(days: [BreakDay(dayId: dayIds['Monday']!, usualStart: '12:00', lengthMinutes: 30)]),
      ),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.scheduleEmployeesDiffer)),
    );

    final unified = await editing.setWorkHours(users['actor']!, groups['blue']!, hours('08:00', '16:30'));
    expect(unified.status, GroupScheduleStatus.configured);
    expect(await links('A'), await links('B'));
  });

  test('removing work hours switches them off for everyone in the group', () async {
    final result = await editing.removeWorkHours(users['actor']!, groups['blue']!);

    expect(result.status, GroupScheduleStatus.noSchedule);
    expect(await links('A'), isEmpty);
    expect(await links('C'), isEmpty);
  });

  test('no rounding for the finish: no rule is stored for it; the start keeps its own', () async {
    final result = await editing.setWorkHours(
      users['actor']!,
      groups['blue']!,
      SetWorkHoursRequest(
        days: [WorkHoursDay(dayId: dayIds['Monday']!, start: '08:00', finish: '16:30')],
        arrivalToleranceMinutes: 1,
        leavingToleranceMinutes: 5,
        startRounding: const ScheduleRounding(intervalMinutes: 5, roundUp: true),
      ),
    );

    final monday = result.variants.single.workDays.single;
    expect((monday.start!.rounding!.intervalMinutes, monday.start!.rounding!.roundUp), (5, true));
    expect(monday.finish!.rounding, isNull);
    expect((monday.start!.toleranceMinutes, monday.finish!.toleranceMinutes), (1, 5));
  });

  test('an unknown group is 404', () async {
    await expectLater(
      editing.removeWorkHours(users['actor']!, 999999999),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });

  test('the whole schedule at once: hours and break together; a break that does not fit saves nothing', () async {
    final monday = dayIds['Monday']!;
    final saved = await editing.setSchedule(
      users['actor']!,
      groups['blue']!,
      SetGroupScheduleRequest(
        workHours: hours('09:00', '17:00'),
        breaks: [BreakDay(dayId: monday, usualStart: '12:00', lengthMinutes: 30)],
      ),
    );
    final variant = saved.variants.single;
    expect(variant.workDays.firstWhere((d) => d.day.id == monday).start!.time, '09:00');
    expect(variant.breaks.single.usualStart, '12:00');

    final logs = await eventLogRows();
    final before = await links('A');
    await expectLater(
      editing.setSchedule(
        users['actor']!,
        groups['blue']!,
        SetGroupScheduleRequest(
          workHours: hours('07:00', '15:00'),
          breaks: [BreakDay(dayId: monday, usualStart: '15:30', lengthMinutes: 30)],
        ),
      ),
      throwsA(isA<ApiException>().having((e) => e.field, 'field', SetGroupScheduleRequest.fieldBreaks)),
    );
    expect(await links('A'), before, reason: 'the new hours were not saved either');
    expect(await eventLogRows(), logs, reason: 'nothing audited');

    final noBreak = await editing.setSchedule(
      users['actor']!,
      groups['blue']!,
      SetGroupScheduleRequest(workHours: hours('09:00', '17:00')),
    );
    expect(noBreak.variants.single.breaks, isEmpty, reason: '"No break" removes the break');
    expect(noBreak.variants.single.workDays, hasLength(2), reason: 'the hours stay');
  });
}
