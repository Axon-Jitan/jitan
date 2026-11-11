@Tags(['integration'])
library;

import 'package:jitan_api/src/activities/activity_repository.dart';
import 'package:jitan_api/src/activities/activity_service.dart';
import 'package:jitan_api/src/activities/trip_kilometres.dart';
import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/locations/location_repository.dart';
import 'package:jitan_api/src/projects/project_repository.dart';
import 'package:jitan_api/src/reports/project_report_service.dart';
import 'package:jitan_api/src/routing/driving_distance.dart';
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

/// The project report against MySQL (D24): from the registrations and
/// activity rows written the normal way, for the companies the viewer may see.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late ActivityService activities;
  late TimeRegistrationWriteService writes;
  late ProjectReportService reports;
  late int company;
  late int otherCompany;
  late int projectKind;
  final users = <int>[];
  final addresses = <int>[];
  final clock = WorkplaceClock('Europe/Brussels');
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final prefix = '[DEV-TEST] $stamp';
  var counter = 0;

  DateTime moment(int minutesAgo) => DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo));
  String thisMonth() {
    final local = clock.wallClockOf(moment(0));
    return '${local.year}-${local.month.toString().padLeft(2, '0')}';
  }

  Future<int> newCompany(String name) async => (await db.execute(
    'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:n, 1, 0)',
    {'n': '$prefix $name'},
  )).lastInsertId;

  Future<int> newUser(int companyId) async {
    final code = 'PR$stamp${++counter}';
    final id = (await db.execute(
      'INSERT INTO tblUser (userName, userSurname, userCode, userActive, userMFD) VALUES (:n, :s, :c, 1, 0)',
      {'n': 'Test', 's': code, 'c': code},
    )).lastInsertId;
    await db.execute(
      'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD, userCompanyDefault) '
      'VALUES (:u, :c, 1, 0, 1)',
      {'u': id, 'c': companyId},
    );
    users.add(id);
    return id;
  }

  Future<int> clientProject() async {
    final id = (await db.execute(
      'INSERT INTO tblAddress (addressStreet, addressLogicalName, addressCity, addressCoordinates, addressActive, addressMFD) '
      'VALUES (:s, :n, :city, :c, 1, 0)',
      {'s': 'Street', 'n': 'P-$stamp${++counter} $prefix site', 'city': 'Engis', 'c': '51.2,4.4'},
    )).lastInsertId;
    addresses.add(id);
    final geofence = (await db.execute(
      'INSERT INTO tblGeofence (geofenceRadiusInMeter, geofenceActive, geofenceMFD) VALUES (100, 1, 0)',
    )).lastInsertId;
    await db.execute(
      'INSERT INTO tblGeofenceAddress (geofenceID, addressID, geofenceAddressActive, geofenceAddressMFD) VALUES (:g, :a, 1, 0)',
      {'g': geofence, 'a': id},
    );
    await const ProjectRepository().link(db, id, projectKind);
    return id;
  }

  RegisterTimeRequest at(RegistrationBoundary boundary, DateTime when) =>
      RegisterTimeRequest(boundary: boundary, method: TimeRegistrationMethod.manual, entry: RegistrationEntry.now, at: when);

  /// [user] worked on [project] from 25 to 5 minutes ago, and finished.
  Future<void> workedOn(int user, int project) async {
    await writes.register(user, at(RegistrationBoundary.start, moment(30)));
    await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.clientOnSite, at: moment(25), projectId: project));
    await writes.register(user, at(RegistrationBoundary.finish, moment(5)));
  }

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 3);
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
    final kilometres = TripKilometres(
      activities: const ActivityRepository(),
      locations: const LocationRepository(),
      distance: const NoDrivingDistance(),
      executor: db,
      clock: clock,
    );
    activities = ActivityService(
      activities: const ActivityRepository(),
      projects: const ProjectRepository(),
      writes: const TimeRegistrationWriteRepository(),
      myDay: MyDayService(days: days, records: records, plans: WeekPlans(schedules), clock: clock),
      locations: const LocationRepository(),
      kilometres: kilometres,
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
    reports = ProjectReportService(
      days: days,
      plans: WeekPlans(schedules),
      employees: EmployeeRepository(db),
      companies: CompanyRepository(db),
      activities: const ActivityRepository(),
      projects: const ProjectRepository(),
      locations: const LocationRepository(),
      kilometres: kilometres,
      executor: db,
      clock: clock,
    );
    projectKind = (await const ProjectRepository().projectKindId(db))!;
    company = await newCompany('company');
    otherCompany = await newCompany('other');
  });

  tearDownAll(() async {
    for (final user in users) {
      await db.execute(
        'DELETE t FROM tblEventLogEventType t JOIN tblEventLog e ON e.eventLogID = t.eventLogID WHERE e.userIDInit = :u',
        {'u': user},
      );
      await db.execute('DELETE FROM tblEventLog WHERE userIDInit = :u', {'u': user});
      await db.execute('DELETE FROM tblTimeReg WHERE userID = :u', {'u': user});
      await db.execute('DELETE FROM tblUserCompany WHERE userID = :u', {'u': user});
      await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': user});
    }
    for (final address in addresses) {
      await db.execute('DELETE FROM tblAddressLocationType WHERE addressID = :a', {'a': address});
      final links = await db.query('SELECT geofenceID FROM tblGeofenceAddress WHERE addressID = :a', {'a': address});
      await db.execute('DELETE FROM tblGeofenceAddress WHERE addressID = :a', {'a': address});
      for (final link in links) {
        await db.execute('DELETE FROM tblGeofence WHERE geofenceID = :g', {'g': link.readInt('geofenceID')});
      }
      await db.execute('DELETE FROM tblAddress WHERE addressID = :a', {'a': address});
    }
    await db.execute('DELETE FROM tblCompany WHERE companyID IN (:a, :b)', {'a': company, 'b': otherCompany});
    await db.close();
  });

  test('a finished day on a project: its time, the employee, the place; another company’s employee only with the right there', () async {
    final project = await clientProject();
    final mine = await newUser(company);
    final theirs = await newUser(otherCompany);
    await workedOn(mine, project);
    await workedOn(theirs, project);

    final report = await reports.projects(month: thisMonth(), mayView: (id) async => id == company);

    final row = report.projects.singleWhere((p) => p.project.id == project);
    expect((row.project.isClientSite, row.project.placeName), (true, 'Engis'));
    expect(row.employees.map((e) => e.employeeId), [mine], reason: 'only companies the viewer may see (§28a.5)');
    expect(row.workedMinutes, inInclusiveRange(19, 20));
    expect(row.employees.single.days, 1);

    final both = await reports.projects(month: thisMonth(), mayView: (_) async => true);
    expect(both.projects.singleWhere((p) => p.project.id == project).employees, hasLength(2));
  });

  test('a malformed month is refused', () async {
    await expectLater(
      reports.projects(month: '2026-13', mayView: (_) async => true),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
    );
  });
}
