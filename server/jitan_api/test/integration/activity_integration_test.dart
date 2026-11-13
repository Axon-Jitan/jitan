@Tags(['integration'])
library;

import 'package:jitan_api/src/activities/activity_entries.dart';
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

/// 42.5 km, whatever the places.
class _FixedDistance implements DrivingDistance {
  @override
  Future<int?> metres(GeoPoint from, GeoPoint to) async => 42500;
}

/// Activities on IT's tables (D37, D38, D40, D44): a project is an address of
/// the kind "Project location", and an activity row's `addressID` is its
/// project or place. Each test has its own employee and projects.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late ActivityService activities;
  late MyDayService myDayLines;
  late TimeRegistrationWriteService writes;
  late int company;
  late int otherCompany;
  late int projectKind;
  late int almeco;
  late int elsewhere;
  final users = <int>[];
  final addresses = <int>[];
  final clock = WorkplaceClock('Europe/Brussels');
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final prefix = '[DEV-TEST] $stamp';
  var counter = 0;

  /// A moment earlier today, so nothing is in the future.
  DateTime moment(int minutesAgo) => DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo));

  Future<int> newCompany(String name) async => (await db.execute(
    'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:n, 1, 0)',
    {'n': '$prefix $name'},
  )).lastInsertId;

  Future<int> newUser({bool isDefault = false}) async {
    final code = 'DT$stamp${++counter}';
    final id = (await db.execute('INSERT INTO tblUser (userName, userSurname, userCode, userActive, userMFD) VALUES (:n, :s, :c, 1, 0)', {
      'n': 'Test',
      's': code,
      'c': code,
    })).lastInsertId;
    await db.execute(
      'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD, userCompanyDefault) '
      'VALUES (:u, :c, 1, 0, :d)',
      {'u': id, 'c': company, 'd': isDefault ? 1 : 0},
    );
    users.add(id);
    return id;
  }

  /// An address, with a pin and a geofence when [area].
  Future<int> newAddress(String name, String coordinates, {bool area = true}) async {
    final id = (await db.execute(
      'INSERT INTO tblAddress (addressStreet, addressLogicalName, addressCoordinates, addressActive, addressMFD) '
      'VALUES (:s, :n, :c, 1, 0)',
      {'s': 'Street', 'n': '$prefix $name', 'c': coordinates},
    )).lastInsertId;
    addresses.add(id);
    if (area) {
      final geofence = (await db.execute(
        'INSERT INTO tblGeofence (geofenceRadiusInMeter, geofenceActive, geofenceMFD) VALUES (100, 1, 0)',
      )).lastInsertId;
      await db.execute(
        'INSERT INTO tblGeofenceAddress (geofenceID, addressID, geofenceAddressActive, geofenceAddressMFD) VALUES (:g, :a, 1, 0)',
        {'g': geofence, 'a': id},
      );
    }
    return id;
  }

  /// A client site with its area, of the kind "Project location".
  Future<int> clientProject() async {
    final id = await newAddress('client ${++counter}', '51.2,4.4');
    await const ProjectRepository().link(db, id, projectKind);
    return id;
  }

  /// Internal work at Almeco: Almeco's coordinates, no area.
  Future<int> internalProject() async {
    final id = await newAddress('internal ${++counter}', '51.000000,4.000000', area: false);
    await const ProjectRepository().link(db, id, projectKind);
    return id;
  }

  Future<void> startAt(int user, DateTime at, int location) => writes.register(
    user,
    RegisterTimeRequest(
      boundary: RegistrationBoundary.start,
      method: TimeRegistrationMethod.geofence,
      entry: RegistrationEntry.now,
      at: at,
      addressId: location,
    ),
  );

  Future<void> start(int user, DateTime at) => writes.register(
    user,
    RegisterTimeRequest(boundary: RegistrationBoundary.start, method: TimeRegistrationMethod.manual, entry: RegistrationEntry.now, at: at),
  );

  Future<void> finish(int user, DateTime at) => writes.register(
    user,
    RegisterTimeRequest(boundary: RegistrationBoundary.finish, method: TimeRegistrationMethod.manual, entry: RegistrationEntry.now, at: at),
  );

  /// [user] worked on [project] earlier today, and finished.
  Future<void> usedEarlier(int user, int project, ActivityKind kind) async {
    // Close to now, so it is still today just after midnight.
    await start(user, moment(40));
    await activities.switchTo(user, SwitchActivityRequest(kind: kind, at: moment(35), projectId: project));
    await finish(user, moment(30));
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
    activities = ActivityService(
      activities: const ActivityRepository(),
      projects: const ProjectRepository(),
      writes: const TimeRegistrationWriteRepository(),
      myDay: MyDayService(days: days, records: records, plans: WeekPlans(schedules), clock: clock),
      locations: const LocationRepository(),
      kilometres: TripKilometres(
        activities: const ActivityRepository(),
        locations: const LocationRepository(),
        distance: _FixedDistance(),
        executor: db,
        clock: clock,
      ),
      audit: const AuditLogRepository(),
      transactions: db,
      executor: db,
      clock: clock,
    );
    myDayLines = MyDayService(
      days: days,
      records: records,
      plans: WeekPlans(schedules),
      clock: clock,
      activities: ActivityEntries(
        activities: const ActivityRepository(),
        projects: const ProjectRepository(),
        locations: const LocationRepository(),
        kilometres: TripKilometres(
          activities: const ActivityRepository(),
          locations: const LocationRepository(),
          distance: _FixedDistance(),
          executor: db,
          clock: clock,
        ),
        executor: db,
        clock: clock,
      ),
    );
    writes = TimeRegistrationWriteService(
      transactions: db,
      rounding: RegistrationRounding(schedules),
      clock: clock,
      onDayStart: activities.dayStarted,
    );
    projectKind = (await const ProjectRepository().projectKindId(db))!;
    company = await newCompany('company');
    otherCompany = await newCompany('other');
    almeco = await newAddress('almeco', '51.000000,4.000000');
    elsewhere = await newAddress('elsewhere', '50.8,3.9');
  });

  tearDownAll(() async {
    for (final user in users) {
      await db.execute('DELETE t FROM tblEventLogEventType t JOIN tblEventLog e ON e.eventLogID = t.eventLogID WHERE e.userIDInit = :u', {
        'u': user,
      });
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

  test('every active project can be chosen; a client site is a client project, internal work names its workshop', () async {
    final user = await newUser();
    final client = await clientProject();
    final internal = await internalProject();

    final projects = (await activities.mine(user)).projects;

    final c = projects.firstWhere((p) => p.id == client), i = projects.firstWhere((p) => p.id == internal);
    expect((c.isClient, c.isRecent), (true, false));
    expect((i.isClient, i.placeName), (false, '$prefix almeco'));
  });

  test('never used a project: work starts without one, and registering still works', () async {
    final user = await newUser();

    await start(user, moment(10));

    expect((await activities.mine(user)).current, isNull);
    final rows = await db.query('SELECT COUNT(*) AS n FROM tblTimeReg WHERE userID = :u', {'u': user});
    expect(rows.single.readInt('n'), 2, reason: 'actual and rounded');
  });

  test('the day starts on the project used last: on site, or in-house when started elsewhere (D38)', () async {
    final user = await newUser(isDefault: true);
    final client = await clientProject();
    await usedEarlier(user, client, ActivityKind.clientOnSite);

    await startAt(user, moment(10), almeco);

    final mine = await activities.mine(user);
    expect(mine.current?.project?.id, client);
    expect(mine.current?.kind, ActivityKind.clientInHouse, reason: 'started at Almeco, not at the client');
    expect(mine.current?.company?.id, company, reason: 'the default company');
    expect(mine.projects.first.id, client, reason: 'recent first');
  });

  test('an inactive project is no default, and cannot be chosen', () async {
    final user = await newUser();
    final internal = await internalProject();
    await usedEarlier(user, internal, ActivityKind.internal);
    await db.execute('UPDATE tblAddress SET addressActive = 0 WHERE addressID = :a', {'a': internal});

    await start(user, moment(10));
    expect((await activities.mine(user)).current?.project, isNull);

    await expectLater(
      activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.internal, at: moment(5), projectId: internal)),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
    );
  });

  test('a switch keeps the day: the Start rows are not touched, and the project is the row’s address', () async {
    final user = await newUser();
    final client = await clientProject();
    await start(user, moment(40));
    Future<int> startRows() async => (await db.query(
      'SELECT COUNT(*) AS n FROM tblTimeReg r JOIN tblTimeRegType t ON t.timeRegTypeID = r.timeRegTypeID '
      "WHERE r.userID = :u AND t.timeRegTypeName LIKE 'Start%'",
      {'u': user},
    )).single.readInt('n');
    final before = await startRows();

    final switched = await activities.switchTo(
      user,
      SwitchActivityRequest(kind: ActivityKind.clientOnSite, at: moment(20), projectId: client),
    );

    expect(switched.current?.project?.id, client);
    expect(await startRows(), before);
    final row = await db.query(
      'SELECT r.addressID FROM tblTimeReg r JOIN tblTimeRegType t ON t.timeRegTypeID = r.timeRegTypeID '
      "WHERE r.userID = :u AND t.timeRegTypeName = 'Activity – Client on site'",
      {'u': user},
    );
    expect(row.single.readInt('addressID'), client);
  });

  test('the same switch twice adds one row', () async {
    final user = await newUser();
    final internal = await internalProject();
    await start(user, moment(40));
    final request = SwitchActivityRequest(kind: ActivityKind.internal, at: moment(20), projectId: internal);

    await activities.switchTo(user, request);
    await activities.switchTo(user, request);

    final rows = await db.query(
      'SELECT COUNT(*) AS n FROM tblTimeReg r JOIN tblTimeRegType t ON t.timeRegTypeID = r.timeRegTypeID '
      "WHERE r.userID = :u AND t.timeRegTypeName LIKE 'Activity%'",
      {'u': user},
    );
    expect(rows.single.readInt('n'), 1);
  });

  test('checks: a day not running, no such project, a kind that doesn’t fit, the future', () async {
    final user = await newUser();
    final internal = await internalProject();
    final at = moment(5);

    await expectLater(
      activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.internal, at: at, projectId: internal)),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );

    await start(user, moment(10));
    for (final request in [
      SwitchActivityRequest(kind: ActivityKind.internal, at: at, projectId: almeco),
      SwitchActivityRequest(kind: ActivityKind.clientOnSite, at: at, projectId: internal),
      SwitchActivityRequest(kind: ActivityKind.work, at: at, projectId: internal),
      SwitchActivityRequest(kind: ActivityKind.internal, at: moment(-10), projectId: internal),
    ]) {
      await expectLater(activities.switchTo(user, request), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)));
    }
  });

  test('today shows what the day went on', () async {
    final user = await newUser();
    final internal = await internalProject();
    await start(user, moment(120));

    await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.internal, at: moment(119), projectId: internal));
    await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.transport, at: moment(60)));
    final mine = await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.internal, at: moment(30), projectId: internal));

    expect(mine.breakdown.internalMinutes, inInclusiveRange(88, 90));
    expect(mine.breakdown.transportMinutes, inInclusiveRange(29, 31));
    expect(mine.breakdown.trips, 1);
    expect(mine.breakdown.isMixed, isTrue);
    // Per project too (Figma 1606:128), transport left out.
    final project = mine.breakdown.projects.single;
    expect(project.name, contains('internal'));
    expect(project.minutes, inInclusiveRange(88, 90));
  });

  test('Period: a day carries what it went on, the same lines as today (2026-11-13)', () async {
    final user = await newUser();
    final internal = await internalProject();
    await start(user, moment(120));
    await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.internal, at: moment(119), projectId: internal));
    await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.transport, at: moment(60)));
    final today = (await activities.mine(user)).today;

    final local = clock.wallClockOf(DateTime.now().toUtc());
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${local.year}-${two(local.month)}-${two(local.day)}';
    final day = (await myDayLines.period(user, date, date)).days.single;

    expect(day.activities, hasLength(2));
    expect(
      [for (final a in day.activities) (a.timeLocal, a.kind, a.projectName)],
      [for (final a in today) (a.timeLocal, a.kind, a.projectName)],
    );
    expect(day.activities.first.projectName, isNotNull);
  });

  group('D40: a trip is known on arrival', () {
    TripRequest trip(int from, int to, int leftAgo, int arrivedAgo) =>
        TripRequest(fromAddressId: from, toAddressId: to, leftAt: moment(leftAgo), arrivedAt: moment(arrivedAgo));

    test('Almeco to a client site: Transport from leaving, on site from arriving, and the kilometres', () async {
      final user = await newUser();
      final client = await clientProject();
      await startAt(user, moment(120), almeco);

      final mine = await activities.registerTrip(user, trip(almeco, client, 60, 15));

      expect(mine.current?.kind, ActivityKind.clientOnSite);
      expect(mine.current?.project?.id, client);
      expect(mine.breakdown.trips, 1);
      expect(mine.breakdown.transportMinutes, inInclusiveRange(44, 46));
      expect(mine.breakdown.distanceMetres, 42500);
      expect(mine.breakdown.tripsWithoutDistance, 0);
      final transport = mine.today.singleWhere((e) => e.kind == ActivityKind.transport);
      expect(transport.metres, 42500);
    });

    test('and back: a second trip, working on without a project', () async {
      final user = await newUser();
      final client = await clientProject();
      await startAt(user, moment(120), almeco);
      await activities.registerTrip(user, trip(almeco, client, 100, 90));

      final mine = await activities.registerTrip(user, trip(client, almeco, 30, 15));

      expect(mine.current?.kind, ActivityKind.work);
      expect(mine.breakdown.trips, 2);
      expect(mine.breakdown.distanceMetres, 85000);
    });

    test('sent twice: one trip', () async {
      final user = await newUser();
      final client = await clientProject();
      await startAt(user, moment(120), almeco);
      final request = trip(almeco, client, 60, 15);

      await activities.registerTrip(user, request);
      final mine = await activities.registerTrip(user, request);

      expect(mine.breakdown.trips, 1);
      expect(mine.breakdown.distanceMetres, 42500);
    });

    test('between places that are no client site: no trip', () async {
      final user = await newUser();
      await startAt(user, moment(120), almeco);

      final mine = await activities.registerTrip(user, trip(almeco, elsewhere, 60, 15));

      expect(mine.breakdown.trips, 0);
    });

    test('their own switch during the drive wins', () async {
      final user = await newUser();
      final client = await clientProject();
      await startAt(user, moment(120), almeco);
      await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.work, at: moment(30)));

      final mine = await activities.registerTrip(user, trip(almeco, client, 60, 15));

      expect(mine.current?.kind, ActivityKind.work);
      expect(mine.breakdown.trips, 0);
    });

    test('already on Transport by hand: only the arrival is added, and it still has its kilometres', () async {
      final user = await newUser();
      final client = await clientProject();
      await startAt(user, moment(120), almeco);
      await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.transport, at: moment(62)));

      final mine = await activities.registerTrip(user, trip(almeco, client, 60, 15));

      expect(mine.current?.kind, ActivityKind.clientOnSite);
      expect(mine.breakdown.trips, 1);
      expect(mine.breakdown.distanceMetres, 42500, reason: 'it left from where the day started');
    });

    test('a manual start: the place is not known, so the trip has no distance', () async {
      final user = await newUser();
      await start(user, moment(120));

      await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.transport, at: moment(60)));
      final mine = await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.work, at: moment(30)));

      expect(mine.breakdown.trips, 1);
      expect(mine.breakdown.distanceMetres, 0);
      expect(mine.breakdown.tripsWithoutDistance, 1);
    });

    test('checks: a day not running, an unknown location, times that can’t be', () async {
      final user = await newUser();
      final client = await clientProject();
      await expectLater(
        activities.registerTrip(user, trip(almeco, client, 60, 15)),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
      await startAt(user, moment(120), almeco);
      for (final request in [
        trip(almeco, 2147483000, 60, 15),
        trip(almeco, almeco, 60, 15),
        trip(almeco, client, 15, 60),
        trip(almeco, client, 60, -10),
      ]) {
        await expectLater(activities.registerTrip(user, request), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)));
      }
    });
  });

  test('time away counts for no activity', () async {
    final user = await newUser();
    final internal = await internalProject();
    await start(user, moment(120));
    await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.internal, at: moment(120), projectId: internal));
    await finish(user, moment(90));
    await start(user, moment(30));

    final mine = await activities.mine(user);

    expect(mine.breakdown.internalMinutes, inInclusiveRange(58, 62), reason: '30 before leaving, 30 since coming back');
  });

  test('the day counts for the default company, of several (D44)', () async {
    final user = await newUser(isDefault: true);
    final internal = await internalProject();
    await db.execute('INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)', {
      'u': user,
      'c': otherCompany,
    });
    await start(user, moment(30));

    final switched = await activities.switchTo(
      user,
      SwitchActivityRequest(kind: ActivityKind.internal, at: moment(10), projectId: internal),
    );

    expect(switched.current?.company?.id, company);
    expect(switched.companies, hasLength(2));
  });
}
