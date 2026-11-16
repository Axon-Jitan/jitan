@Tags(['integration'])
library;

import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/time_records/my_day_service.dart';
import 'package:jitan_api/src/time_records/time_record_service.dart';
import 'package:jitan_api/src/time_records/time_correction_service.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/schedules/schedule_repository.dart';
import 'package:jitan_api/src/time_records/time_record_repository.dart';
import 'package:jitan_api/src/time_records/week_plans.dart';
import 'package:jitan_api/src/time_registration/registration_rounding.dart';
import 'package:jitan_api/src/time_registration/time_registration_write_service.dart';
import 'package:jitan_api/src/time_registration/workplace_clock.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Registering a start against the real database: the two rows, their types
/// found by name, the time rounded with a real schedule and rounding rule,
/// and the audit entry. `[DEV-TEST]` fixtures are removed afterwards.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  late int userId;

  /// Another person corrects the employee's time: nobody handles their own
  /// (review M3).
  late int hrId;
  late int scheduleId;
  late int userScheduleId;
  late int ruleId;
  late int scheduleRuleId;
  late TimeRegistrationWriteService service;
  int? companyIdForCleanup;

  /// The server's clock: just after the time sent, as when it is tapped
  /// (review H1); [registerNow] moves it.
  var serverNow = DateTime.utc(2026, 10, 22, 12);

  Future<({RegisteredTime registered, bool created})> registerNow(RegisterTimeRequest request) {
    serverNow = request.at.toUtc().add(const Duration(minutes: 1));
    return service.register(userId, request);
  }

  Future<int> id(String sql, Map<String, Object?> params, String column) async =>
      (await db.query(sql, params)).single.readInt(column);

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 3);
    service = TimeRegistrationWriteService(
      transactions: db,
      rounding: RegistrationRounding(ScheduleRepository(db)),
      clock: WorkplaceClock('Europe/Brussels'),
      now: () => serverNow,
    );
    userId = (await db.execute(
      'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
      "VALUES ('[DEV-TEST]', 'Registrations', :c, :q, 1, 0)",
      {'c': 'DT${stamp}REG', 'q': 'DEV-TEST-${stamp}REG'},
    ))
        .lastInsertId;
    hrId = (await db.execute(
      'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
      "VALUES ('[DEV-TEST]', 'Registrations HR', :c, :q, 1, 0)",
      {'c': 'DT${stamp}RHR', 'q': 'DEV-TEST-${stamp}RHR'},
    ))
        .lastInsertId;
    // Thursday: start 08:00–16:30, rounded up every 15 minutes.
    final startType = await id("SELECT scheduleTypeID FROM tblScheduleType WHERE scheduleTypeName = 'Work – start'", {}, 'scheduleTypeID');
    final thursday = await id("SELECT dayID FROM tblDays WHERE dayName = 'Thursday'", {}, 'dayID');
    scheduleId = (await db.execute(
      'INSERT INTO tblSchedule (scheduleTypeID, dayID, scheduleHrStart, scheduleMinStart, scheduleHrStop, scheduleMinStop, '
      'scheduleMarginMin, scheduleActive, scheduleMFD) VALUES (:t, :d, 8, 0, 16, 30, 0, 1, 0)',
      {'t': startType, 'd': thursday},
    ))
        .lastInsertId;
    userScheduleId = (await db.execute(
      'INSERT INTO tblUserSchedule (userID, scheduleID, userScheduleActive, userScheduleMFD) VALUES (:u, :s, 1, 0)',
      {'u': userId, 's': scheduleId},
    ))
        .lastInsertId;
    ruleId = (await db.execute(
      'INSERT INTO tblRoundingRule (roundingRuleValueInMin, roundingRuleRoundUp, roundingRuleActive, roundingRuleMFD) '
      'VALUES (15, 1, 1, 0)',
    ))
        .lastInsertId;
    scheduleRuleId = (await db.execute(
      'INSERT INTO tblScheduleRoundingRule (scheduleID, roundingRuleID, scheduleRoundingRuleActive, scheduleRoundingRuleMFD) '
      'VALUES (:s, :r, 1, 0)',
      {'s': scheduleId, 'r': ruleId},
    ))
        .lastInsertId;
  });

  tearDownAll(() async {
    final logs = await db.query(
      'SELECT eventLogID FROM tblEventLog WHERE userIDTarget = :u OR userIDInit = :u OR companyID = :c',
      {'u': userId, 'c': companyIdForCleanup ?? 0},
    );
    for (final log in logs) {
      await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
      await db.execute('DELETE FROM tblEventLog WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
    }
    await db.execute('DELETE FROM tblTimeReg WHERE userID = :u', {'u': userId});
    await db.execute('DELETE FROM tblScheduleRoundingRule WHERE scheduleRoundingRuleID = :id', {'id': scheduleRuleId});
    await db.execute('DELETE FROM tblRoundingRule WHERE roundingRuleID = :id', {'id': ruleId});
    await db.execute('DELETE FROM tblUserSchedule WHERE userScheduleID = :id', {'id': userScheduleId});
    await db.execute('DELETE FROM tblSchedule WHERE scheduleID = :id', {'id': scheduleId});
    await db.execute('DELETE FROM tblUserCompany WHERE userID = :u', {'u': userId});
    if (companyIdForCleanup case final c?) {
      await db.execute('DELETE FROM tblCompany WHERE companyID = :c', {'c': c});
    }
    await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': userId});
    await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': hrId});
    await db.close();
  });

  test('a manual start: actual and rounded rows with their types, UTC, and an audit entry; a retry adds nothing', () async {
    final request = RegisterTimeRequest(
      boundary: RegistrationBoundary.start,
      method: TimeRegistrationMethod.manual,
      entry: RegistrationEntry.now,
      at: DateTime.utc(2026, 10, 22, 6, 4, 37),
    );

    final (:registered, :created) = await registerNow(request);

    expect(created, isTrue);
    expect(registered.roundedAt, DateTime.utc(2026, 10, 22, 6, 15));
    final rows = await db.query(
      'SELECT tr.timeRegID, t.timeRegTypeName, tr.timeRegTimestamp, tr.timeRegManualEntry, tr.timeRegComment, tr.addressID '
      'FROM tblTimeReg tr JOIN tblTimeRegType t ON t.timeRegTypeID = tr.timeRegTypeID '
      'WHERE tr.userID = :u ORDER BY tr.timeRegID',
      {'u': userId},
    );
    expect([
      for (final r in rows)
        (
          r.readString('timeRegTypeName'),
          r.readOptionalDateTime('timeRegTimestamp').toString(),
          r.readBool('timeRegManualEntry'),
          r.readOptionalString('timeRegComment'),
          r.readOptionalInt('addressID'),
        ),
    ], [
      ('Start – actual – Manual', '2026-10-22 06:04:37.000', false, null, null),
      ('Start – rounded', '2026-10-22 06:15:00.000', false, null, null),
    ]);
    final audited = await db.query(
      'SELECT timeRegID, userIDInit FROM tblEventLog WHERE userIDTarget = :u AND timeRegID IS NOT NULL',
      {'u': userId},
    );
    expect([for (final a in audited) (a.readInt('timeRegID'), a.readInt('userIDInit'))], [(registered.actualId, userId)]);

    final retry = await registerNow(request);
    expect(retry.created, isFalse);
    expect((retry.registered.actualId, retry.registered.roundedId), (registered.actualId, registered.roundedId));
    expect(await db.query('SELECT timeRegID FROM tblTimeReg WHERE userID = :u', {'u': userId}), hasLength(2));

    // Time records reads them back as UTC, within the period only.
    final read = await TimeRecordRepository(db).registrationsOf(
      [userId],
      DateTime.utc(2026, 10, 21, 22),
      DateTime.utc(2026, 10, 22, 22),
    );
    expect(
      await TimeRecordRepository(db).registrationsOf([userId], DateTime.utc(2026, 10, 22, 7), DateTime.utc(2026, 10, 22, 22)),
      isEmpty,
      reason: 'outside the period',
    );
    expect(read.map((r) => (r.typeName, r.at, r.manualEntry)), [
      ('Start – actual – Manual', DateTime.utc(2026, 10, 22, 6, 4, 37), false),
      ('Start – rounded', DateTime.utc(2026, 10, 22, 6, 15), false),
    ]);
  });

  test('the employee sees the day on the phone (GET /me/today): working, from the schedule', () async {
    final clock = WorkplaceClock('Europe/Brussels');
    final now = DateTime.utc(2026, 10, 22, 12);
    final myDay = MyDayService(
      days: TimeRecordService(
        records: TimeRecordRepository(db),
        employees: EmployeeRepository(db),
        companies: CompanyRepository(db),
        clock: clock,
        schedules: ScheduleRepository(db),
        rounding: RegistrationRounding(ScheduleRepository(db)),
        now: () => now,
      ),
      records: TimeRecordRepository(db),
      plans: WeekPlans(ScheduleRepository(db)),
      clock: clock,
      now: () => now,
    );

    final today = await myDay.today(userId);

    expect((today.date, today.firstDay, today.scheduledStart, today.day!.status, today.day!.start!.actualLocal), (
      DateTime.utc(2026, 10, 22),
      false,
      '08:00',
      TimeRecordStatus.working,
      '08:04',
    ));
    expect(today.registeredMinutes, isNull, reason: 'not finished');
  });

  test('HR corrects the start: corrected + rounded rows; the old rounded row switched off, kept; non-work switches all off', () async {
    final companyId = companyIdForCleanup = (await db.execute(
      'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:n, 1, 0)',
      {'n': '[DEV-TEST] $stamp Registrations'},
    ))
        .lastInsertId;
    await db.execute(
      'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)',
      {'u': userId, 'c': companyId},
    );
    final rounding = RegistrationRounding(ScheduleRepository(db));
    final clock = WorkplaceClock('Europe/Brussels');
    final days = TimeRecordService(
      records: TimeRecordRepository(db),
      employees: EmployeeRepository(db),
      companies: CompanyRepository(db),
      clock: clock,
      schedules: ScheduleRepository(db),
      rounding: rounding,
      now: () => DateTime.utc(2026, 10, 23, 12),
    );
    final corrections = TimeCorrectionService(
      transactions: db,
      employees: EmployeeRepository(db),
      companies: CompanyRepository(db),
      records: TimeRecordRepository(db),
      days: days,
      rounding: rounding,
      clock: clock,
      now: () => DateTime.utc(2026, 10, 23, 12),
    );

    final day = await corrections.correct(
      hrId,
      companyId,
      userId,
      '2026-10-22',
      CorrectTimeRequest(boundary: RegistrationBoundary.start, time: '07:58', reason: "[DEV-TEST] It's the gate log"),
    );

    expect((day!.status, day.start!.actualLocal, day.start!.roundedLocal, day.start!.originalLocal), (
      TimeRecordStatus.missingFinish,
      '07:58',
      '08:00',
      '08:04',
    ));
    final rows = await db.query(
      'SELECT t.timeRegTypeName, tr.timeRegActive, tr.timeRegWhenModified FROM tblTimeReg tr '
      'JOIN tblTimeRegType t ON t.timeRegTypeID = tr.timeRegTypeID WHERE tr.userID = :u ORDER BY tr.timeRegID',
      {'u': userId},
    );
    expect([for (final r in rows) (r.readString('timeRegTypeName'), r.readBool('timeRegActive'))], [
      ('Start – actual – Manual', true),
      ('Start – rounded', false),
      ('Start – corrected', true),
      ('Start – rounded', true),
    ]);
    expect(rows[1].readOptionalDateTime('timeRegWhenModified'), isNotNull);

    final nonWork = await corrections.markNonWork(hrId, companyId, userId, '2026-10-22', '[DEV-TEST] Holiday');
    expect((nonWork!.status, nonWork.nonWorkReason), (TimeRecordStatus.nonWork, '[DEV-TEST] Holiday'));
    expect(await db.query('SELECT 1 FROM tblTimeReg WHERE userID = :u AND timeRegActive = 1', {'u': userId}), isEmpty);

    await db.execute('DELETE FROM tblUserCompany WHERE userID = :u AND companyID = :c', {'u': userId, 'c': companyId});
    final logs = await db.query('SELECT eventLogID FROM tblEventLog WHERE companyID = :c', {'c': companyId});
    for (final log in logs) {
      await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
      await db.execute('DELETE FROM tblEventLog WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
    }
    await db.execute('DELETE FROM tblCompany WHERE companyID = :c', {'c': companyId});
  });

  test('the same start sent twice at the same moment is stored once (review H2)', () async {
    final request = RegisterTimeRequest(
      boundary: RegistrationBoundary.start,
      method: TimeRegistrationMethod.manual,
      entry: RegistrationEntry.now,
      at: DateTime.utc(2026, 10, 21, 6, 2, 9),
    );

    serverNow = request.at.add(const Duration(minutes: 1));
    final results = await Future.wait([service.register(userId, request), service.register(userId, request)]);

    expect(results.where((r) => r.created), hasLength(1));
    expect(results[0].registered.actualId, results[1].registered.actualId);
    final rows = await db.query(
      'SELECT tr.timeRegID FROM tblTimeReg tr WHERE tr.userID = :u AND tr.timeRegTimestamp >= :from AND tr.timeRegTimestamp < :to',
      {'u': userId, 'from': '2026-10-21 00:00:00', 'to': '2026-10-21 23:59:59'},
    );
    expect(rows, hasLength(2), reason: 'one actual and one rounded row');
  });

  group('corrections on a day with a gap (review H3, L1)', () {
    late int companyId;
    late TimeCorrectionService corrections;
    final clock = WorkplaceClock('Europe/Brussels');

    setUp(() async {
      companyId = (await db.execute(
        'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:n, 1, 0)',
        {'n': '[DEV-TEST] $stamp Gap ${DateTime.now().microsecondsSinceEpoch}'},
      )).lastInsertId;
      await db.execute(
        'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)',
        {'u': userId, 'c': companyId},
      );
      final rounding = RegistrationRounding(ScheduleRepository(db));
      corrections = TimeCorrectionService(
        transactions: db,
        employees: EmployeeRepository(db),
        companies: CompanyRepository(db),
        records: TimeRecordRepository(db),
        days: TimeRecordService(
          records: TimeRecordRepository(db),
          employees: EmployeeRepository(db),
          companies: CompanyRepository(db),
          clock: clock,
          schedules: ScheduleRepository(db),
          rounding: rounding,
          now: () => DateTime.utc(2026, 10, 22, 12),
        ),
        rounding: rounding,
        clock: clock,
        now: () => DateTime.utc(2026, 10, 22, 12),
      );
    });

    tearDown(() async {
      await db.execute('DELETE FROM tblUserCompany WHERE userID = :u AND companyID = :c', {'u': userId, 'c': companyId});
      for (final log in await db.query('SELECT eventLogID FROM tblEventLog WHERE companyID = :c', {'c': companyId})) {
        await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
        await db.execute('DELETE FROM tblEventLog WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
      }
      await db.execute('DELETE FROM tblCompany WHERE companyID = :c', {'c': companyId});
    });

    Future<int> at(RegistrationBoundary boundary, DateTime when, {String? reason}) async => (await registerNow(
      RegisterTimeRequest(
        boundary: boundary,
        method: TimeRegistrationMethod.manual,
        entry: reason == null ? RegistrationEntry.now : RegistrationEntry.corrected,
        at: when,
        reason: reason,
      ),
    )).registered.actualId;

    /// [day] (UTC midnight of a Brussels summer-time date): 08:00–13:00 and 15:00–17:00.
    Future<void> dayWithGap(DateTime day) async {
      await at(RegistrationBoundary.start, day.add(const Duration(hours: 6)));
      await at(RegistrationBoundary.finish, day.add(const Duration(hours: 11)));
      await at(RegistrationBoundary.start, day.add(const Duration(hours: 13)));
      await at(RegistrationBoundary.finish, day.add(const Duration(hours: 15)));
    }

    test('approving a travel finish closes the gap and keeps the day ending at 17:00', () async {
      final day = DateTime.utc(2026, 10, 13);
      await dayWithGap(day);
      final request = await at(RegistrationBoundary.finish, day.add(const Duration(hours: 13)), reason: '[DEV-TEST] travelling');

      final approved = await corrections.approve(hrId, companyId, userId, request);

      expect((approved!.finish!.actualLocal, approved.finish!.roundedLocal, approved.awayMinutes), ('17:00', '17:00', 0));
      expect(approved.pending, isEmpty);
    });

    test('HR correcting the day’s end replaces only that finish', () async {
      final day = DateTime.utc(2026, 10, 14);
      await dayWithGap(day);

      final corrected = await corrections.correct(
        hrId,
        companyId,
        userId,
        '2026-10-14',
        CorrectTimeRequest(boundary: RegistrationBoundary.finish, time: '17:30', reason: '[DEV-TEST] stayed longer'),
      );

      expect((corrected!.finish!.actualLocal, corrected.finish!.roundedLocal, corrected.awayMinutes), ('17:30', '17:30', 120));
      final midday = await db.query(
        'SELECT tr.timeRegActive FROM tblTimeReg tr JOIN tblTimeRegType t ON t.timeRegTypeID = tr.timeRegTypeID '
        "WHERE tr.userID = :u AND t.timeRegTypeName = 'Finish – rounded' AND tr.timeRegTimestamp = :at",
        {'u': userId, 'at': '2026-10-14 11:00:00'},
      );
      expect(midday.single.readBool('timeRegActive'), isTrue, reason: 'the 13:00 finish keeps its rounded row');
    });

    test('a finish before the start or a start after the finish is refused', () async {
      final day = DateTime.utc(2026, 10, 15);
      await at(RegistrationBoundary.start, day.add(const Duration(hours: 6)));
      await at(RegistrationBoundary.finish, day.add(const Duration(hours: 14)));

      Matcher refused(String message) => throwsA(isA<ApiException>().having((e) => e.message, 'message', contains(message)));
      await expectLater(
        corrections.correct(hrId, companyId, userId, '2026-10-15',
            CorrectTimeRequest(boundary: RegistrationBoundary.finish, time: '07:30', reason: '[DEV-TEST] typo')),
        refused('before the start'),
      );
      await expectLater(
        corrections.correct(hrId, companyId, userId, '2026-10-15',
            CorrectTimeRequest(boundary: RegistrationBoundary.start, time: '16:30', reason: '[DEV-TEST] typo')),
        refused('after the finish'),
      );
    });

    test('an unrelated HR correction leaves the employee’s request waiting', () async {
      final day = DateTime.utc(2026, 10, 16);
      await dayWithGap(day);
      final request = await at(RegistrationBoundary.finish, day.add(const Duration(hours: 13)), reason: '[DEV-TEST] travelling');

      final corrected = await corrections.correct(
        hrId,
        companyId,
        userId,
        '2026-10-16',
        CorrectTimeRequest(boundary: RegistrationBoundary.finish, time: '17:15', reason: '[DEV-TEST] gate log'),
      );

      expect(corrected!.pending.map((p) => p.id), [request]);
      final approved = await corrections.approve(hrId, companyId, userId, request);
      expect(approved!.pending, isEmpty);
    });
  });
}
