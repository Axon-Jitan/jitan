@Tags(['integration'])
library;

import 'package:jitan_api/src/activities/activity_repository.dart';
import 'package:jitan_api/src/activities/activity_service.dart';
import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/schedules/schedule_repository.dart';
import 'package:jitan_api/src/time_records/my_day_service.dart';
import 'package:jitan_api/src/time_records/time_record_repository.dart';
import 'package:jitan_api/src/time_records/time_record_service.dart';
import 'package:jitan_api/src/time_records/week_plans.dart';
import 'package:jitan_api/src/time_registration/registration_rounding.dart';
import 'package:jitan_api/src/time_registration/time_registration_write_repository.dart';
import 'package:jitan_api/src/time_registration/time_registration_write_service.dart';
import 'package:jitan_api/src/time_registration/workplace_clock.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// PROPOSAL (docs/database/PROPOSED_TABLES.md, D37, D38): activities against
/// the local database. Skipped where the proposed tables are missing. Each
/// test has its own employee, so they don't depend on each other.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late bool available;
  late ActivityService activities;
  late TimeRegistrationWriteService writes;
  late int company;
  late int otherCompany;
  late int clientType;
  late int internalType;
  late int activeStatus;
  late int completedStatus;
  late int address;
  final users = <int>[];
  final clock = WorkplaceClock('Europe/Brussels');
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final prefix = '[DEV-TEST] $stamp';
  var counter = 0;

  /// The time of a start: earlier today, so nothing is in the future.
  DateTime moment(int minutesAgo) => DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo));

  Future<int> newCompany(String name) async => (await db.execute(
    'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:n, 1, 0)',
    {'n': '$prefix $name'},
  )).lastInsertId;

  Future<int> newUser({bool isDefault = false}) async {
    final code = '$stamp${++counter}';
    final id = (await db.execute(
      'INSERT INTO tblUser (userName, userSurname, userCode, userActive, userMFD) VALUES (:n, :s, :c, 1, 0)',
      {'n': 'Test', 's': code, 'c': code},
    )).lastInsertId;
    await db.execute(
      'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD, userCompanyDefault) '
      'VALUES (:u, :c, 1, 0, :d)',
      {'u': id, 'c': company, 'd': isDefault ? 1 : 0},
    );
    users.add(id);
    return id;
  }

  Future<int> newProject(int type, {int? status, int? forCompany, int? addressId}) async => (await db.execute(
    'INSERT INTO tblProject (companyID, projectTypeID, projectStatusID, addressID, projectName, projectStartDate, '
    'projectActive, projectMFD) VALUES (:c, :t, :s, :a, :n, :d, 1, 0)',
    {
      'c': forCompany ?? company,
      't': type,
      's': status ?? activeStatus,
      'a': addressId,
      'n': '$prefix p${++counter}',
      'd': '2026-01-01',
    },
  )).lastInsertId;

  Future<void> assign(int user, int project) async => db.execute(
    'INSERT INTO tblUserProject (userID, projectID, userProjectActive, userProjectMFD) VALUES (:u, :p, 1, 0)',
    {'u': user, 'p': project},
  );

  Future<void> start(int user, DateTime at) => writes.register(
    user,
    RegisterTimeRequest(
      boundary: RegistrationBoundary.start,
      method: TimeRegistrationMethod.manual,
      entry: RegistrationEntry.now,
      at: at,
    ),
  );

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 3);
    available = await const ActivityRepository().available(db);
    if (!available) return;
    final schedules = ScheduleRepository(db);
    final records = TimeRecordRepository(db);
    final days = TimeRecordService(
      records: records,
      employees: EmployeeRepository(db),
      companies: CompanyRepository(db),
      clock: clock,
      schedules: schedules,
      rounding: RegistrationRounding(schedules),
    );
    activities = ActivityService(
      activities: const ActivityRepository(),
      writes: const TimeRegistrationWriteRepository(),
      myDay: MyDayService(days: days, records: records, plans: WeekPlans(schedules), clock: clock),
      audit: const AuditLogRepository(),
      transactions: db,
      executor: db,
      clock: clock,
    );
    writes = TimeRegistrationWriteService(
      transactions: db,
      rounding: RegistrationRounding(schedules),
      clock: clock,
      onDayStart: activities.dayStarted,
    );
    Future<int> lookup(String sql, String name) async => (await db.query(sql, {'n': name})).first.readInt('id');
    clientType = await lookup('SELECT projectTypeID AS id FROM tblProjectType WHERE projectTypeName = :n', 'Client');
    internalType = await lookup('SELECT projectTypeID AS id FROM tblProjectType WHERE projectTypeName = :n', 'Internal');
    activeStatus = await lookup('SELECT projectStatusID AS id FROM tblProjectStatus WHERE projectStatusName = :n', 'Active');
    completedStatus = await lookup('SELECT projectStatusID AS id FROM tblProjectStatus WHERE projectStatusName = :n', 'Completed');
    company = await newCompany('company');
    otherCompany = await newCompany('other');
    address = (await db.execute(
      'INSERT INTO tblAddress (addressStreet, addressLogicalName, addressActive, addressMFD) VALUES (:s, :n, 1, 0)',
      {'s': 'Street', 'n': '$prefix site'},
    )).lastInsertId;
  });

  tearDownAll(() async {
    if (available) {
      for (final user in users) {
        await db.execute(
          'DELETE t FROM tblEventLogEventType t JOIN tblEventLog e ON e.eventLogID = t.eventLogID WHERE e.userIDInit = :u',
          {'u': user},
        );
        await db.execute('DELETE FROM tblEventLog WHERE userIDInit = :u', {'u': user});
        await db.execute('DELETE FROM tblTimeReg WHERE userID = :u', {'u': user});
        await db.execute('DELETE FROM tblUserProject WHERE userID = :u', {'u': user});
        await db.execute('DELETE FROM tblUserCompany WHERE userID = :u', {'u': user});
        await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': user});
      }
      await db.execute('DELETE FROM tblProject WHERE companyID IN (:a, :b)', {'a': company, 'b': otherCompany});
      await db.execute('DELETE FROM tblCompany WHERE companyID IN (:a, :b)', {'a': company, 'b': otherCompany});
      await db.execute('DELETE FROM tblAddress WHERE addressID = :a', {'a': address});
    }
    await db.close();
  });

  void onlyWithTables(String name, Future<void> Function() body) => test(name, () async {
    if (!available) return markTestSkipped('The proposed tables are not here.');
    await body();
  });

  onlyWithTables('one project: the day starts on it, on site for a client', () async {
    final user = await newUser();
    final project = await newProject(clientType, addressId: address);
    await assign(user, project);

    await start(user, moment(10));

    final mine = await activities.mine(user);
    expect(mine.current?.project?.id, project);
    expect(mine.current?.kind, ActivityKind.clientOnSite);
    expect(mine.current?.company?.id, company);
  });

  onlyWithTables('several projects: the day starts on the one used last', () async {
    final user = await newUser();
    final first = await newProject(internalType);
    final last = await newProject(internalType);
    await assign(user, first);
    await assign(user, last);
    await start(user, moment(30));
    await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.internal, at: moment(29), projectId: first));
    await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.internal, at: moment(28), projectId: last));
    await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.internal, at: moment(27), projectId: first));
    await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.internal, at: moment(26), projectId: last));

    await start(user, moment(20));

    expect((await activities.mine(user)).current?.project?.id, last);
  });

  onlyWithTables('several projects never used: work starts without one, and registering still works', () async {
    final user = await newUser();
    await assign(user, await newProject(internalType));
    await assign(user, await newProject(internalType));

    await start(user, moment(10));

    final mine = await activities.mine(user);
    expect(mine.current?.project, isNull);
    expect(mine.current?.company?.id, company, reason: 'their one company');
  });

  onlyWithTables('no project, no company: nothing to store, and the start is still saved', () async {
    final user = await newUser();
    await db.execute('DELETE FROM tblUserCompany WHERE userID = :u', {'u': user});

    await start(user, moment(10));

    expect((await activities.mine(user)).current, isNull);
    final rows = await db.query('SELECT COUNT(*) AS n FROM tblTimeReg WHERE userID = :u', {'u': user});
    expect(rows.single.readInt('n'), 2, reason: 'actual and rounded');
  });

  onlyWithTables('a completed project is not a default, and cannot be chosen', () async {
    final user = await newUser();
    final done = await newProject(internalType, status: completedStatus);
    await assign(user, done);

    await start(user, moment(10));
    expect((await activities.mine(user)).current?.project, isNull);

    await expectLater(
      activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.internal, at: moment(5), projectId: done)),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
    );
  });

  onlyWithTables('a switch keeps the day: the Start and Finish rows are not touched', () async {
    final user = await newUser();
    final project = await newProject(clientType, addressId: address);
    await assign(user, project);
    await start(user, moment(40));
    Future<int> startRows() async => (await db.query(
      'SELECT COUNT(*) AS n FROM tblTimeReg r JOIN tblTimeRegType t ON t.timeRegTypeID = r.timeRegTypeID '
      "WHERE r.userID = :u AND t.timeRegTypeName LIKE 'Start%'",
      {'u': user},
    )).single.readInt('n');
    final before = await startRows();

    final switched = await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.transport, at: moment(20), projectId: project));

    expect(switched.current?.kind, ActivityKind.transport);
    expect(await startRows(), before);
  });

  onlyWithTables('the same switch twice adds one row', () async {
    final user = await newUser();
    final project = await newProject(internalType);
    await assign(user, project);
    await start(user, moment(40));
    final request = SwitchActivityRequest(kind: ActivityKind.internal, at: moment(20), projectId: project);

    await activities.switchTo(user, request);
    await activities.switchTo(user, request);

    final rows = await db.query(
      'SELECT COUNT(*) AS n FROM tblTimeReg r JOIN tblTimeRegType t ON t.timeRegTypeID = r.timeRegTypeID '
      "WHERE r.userID = :u AND t.timeRegTypeName LIKE 'Activity%'",
      {'u': user},
    );
    expect(rows.single.readInt('n'), 2, reason: 'the start and one switch');
  });

  onlyWithTables('checks: a day not running, someone else’s project, a kind that doesn’t fit, the future', () async {
    final user = await newUser();
    final mine = await newProject(internalType);
    final others = await newProject(internalType);
    await assign(user, mine);
    final at = moment(5);

    await expectLater(
      activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.internal, at: at, projectId: mine)),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );

    await start(user, moment(10));
    for (final request in [
      SwitchActivityRequest(kind: ActivityKind.internal, at: at, projectId: others),
      SwitchActivityRequest(kind: ActivityKind.clientOnSite, at: at, projectId: mine),
      SwitchActivityRequest(kind: ActivityKind.work, at: at, projectId: mine),
      SwitchActivityRequest(kind: ActivityKind.work, at: at, companyId: otherCompany),
      SwitchActivityRequest(kind: ActivityKind.internal, at: moment(-10), projectId: mine),
    ]) {
      await expectLater(
        activities.switchTo(user, request),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
      );
    }
  });

  onlyWithTables('the default company is the marked one, and a switch of company lasts for the day', () async {
    final user = await newUser(isDefault: true);
    await db.execute(
      'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)',
      {'u': user, 'c': otherCompany},
    );
    await start(user, moment(30));
    expect((await activities.mine(user)).current?.company?.id, company);

    final switched = await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.work, at: moment(10), companyId: otherCompany));

    expect(switched.current?.company?.id, otherCompany);
    expect(switched.companies, hasLength(2));
  });

}
