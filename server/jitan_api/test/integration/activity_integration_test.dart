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
  late int almeco;
  late int client;
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

  /// A location: an address with a pin and a geofence.
  Future<int> newLocation(String name, String coordinates) async {
    final id = (await db.execute(
      'INSERT INTO tblAddress (addressStreet, addressLogicalName, addressCoordinates, addressActive, addressMFD) '
      'VALUES (:s, :n, :c, 1, 0)',
      {'s': 'Street', 'n': '$prefix $name', 'c': coordinates},
    )).lastInsertId;
    final geofence = (await db.execute(
      'INSERT INTO tblGeofence (geofenceRadiusInMeter, geofenceActive, geofenceMFD) VALUES (100, 1, 0)',
    )).lastInsertId;
    await db.execute(
      'INSERT INTO tblGeofenceAddress (geofenceID, addressID, geofenceAddressActive, geofenceAddressMFD) '
      'VALUES (:g, :a, 1, 0)',
      {'g': geofence, 'a': id},
    );
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
    almeco = await newLocation('almeco', '51.0,4.0');
    client = await newLocation('client', '51.2,4.4');
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
      for (final location in [almeco, client]) {
        final links = await db.query('SELECT geofenceID FROM tblGeofenceAddress WHERE addressID = :a', {'a': location});
        await db.execute('DELETE FROM tblGeofenceAddress WHERE addressID = :a', {'a': location});
        for (final link in links) {
          await db.execute('DELETE FROM tblGeofence WHERE geofenceID = :g', {'g': link.readInt('geofenceID')});
        }
      }
      await db.execute('DELETE FROM tblAddress WHERE addressID IN (:a, :b, :c)', {'a': address, 'b': almeco, 'c': client});
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
    expect(mine.projects.single.statusName, 'Active');
    expect(mine.projects.single.startDate, '2026-01-01');
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

  onlyWithTables('D39: a group decides whether travel counts, and it is audited once', () async {
    final user = await newUser();
    final group = (await db.execute(
      'INSERT INTO tblGroup (groupName, groupActive, groupMFD) VALUES (:n, 1, 0)',
      {'n': '$prefix group'},
    )).lastInsertId;
    await db.execute(
      'INSERT INTO tblUserGroup (userID, groupID, userGroupActive, userGroupMFD) VALUES (:u, :g, 1, 0)',
      {'u': user, 'g': group},
    );
    const repository = ActivityRepository();

    expect((await activities.groupTravel(group)).travelIsWork, isFalse);
    expect(await repository.travelIsWork(db, [user]), isEmpty);

    await activities.setGroupTravel(user, group, travelIsWork: true);
    await activities.setGroupTravel(user, group, travelIsWork: true);

    expect(await repository.travelIsWork(db, [user]), {user});
    final audit = await db.query('SELECT COUNT(*) AS n FROM tblEventLog WHERE groupID = :g', {'g': group});
    expect(audit.single.readInt('n'), 1);

    await db.execute('DELETE t FROM tblEventLogEventType t JOIN tblEventLog e ON e.eventLogID = t.eventLogID WHERE e.groupID = :g', {'g': group});
    await db.execute('DELETE FROM tblEventLog WHERE groupID = :g', {'g': group});
    await db.execute('DELETE FROM tblUserGroup WHERE groupID = :g', {'g': group});
    await db.execute('DELETE FROM tblGroup WHERE groupID = :g', {'g': group});
  });

  onlyWithTables('today shows what the day went on', () async {
    final user = await newUser();
    final project = await newProject(internalType);
    await assign(user, project);
    await start(user, moment(120));

    await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.transport, at: moment(60), projectId: project));
    final mine = await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.internal, at: moment(30), projectId: project));

    expect(mine.breakdown.internalMinutes, inInclusiveRange(89, 90));
    expect(mine.breakdown.transportMinutes, inInclusiveRange(29, 31));
    expect(mine.breakdown.trips, 1);
    expect(mine.breakdown.isMixed, isTrue);
  });

  group('D40: a trip is known on arrival', () {
    TripRequest trip(int from, int to, int leftAgo, int arrivedAgo) =>
        TripRequest(fromAddressId: from, toAddressId: to, leftAt: moment(leftAgo), arrivedAt: moment(arrivedAgo));

    Future<int> withClientProject() async {
      final user = await newUser();
      await assign(user, await newProject(clientType, addressId: client));
      return user;
    }

    onlyWithTables('Almeco to a client of theirs: Transport from leaving, on site from arriving, and the kilometres', () async {
      final user = await withClientProject();
      await startAt(user, moment(120), almeco);

      final mine = await activities.registerTrip(user, trip(almeco, client, 60, 15));

      expect(mine.current?.kind, ActivityKind.clientOnSite);
      expect(mine.breakdown.trips, 1);
      expect(mine.breakdown.transportMinutes, inInclusiveRange(44, 46));
      expect(mine.breakdown.distanceMetres, 42500);
      expect(mine.breakdown.tripsWithoutDistance, 0);

      final transport = mine.today.singleWhere((e) => e.kind == ActivityKind.transport);
      expect((transport.placeName, transport.metres), ('$prefix client', 42500));
      expect(mine.today.first.placeName, '$prefix almeco');
      expect(mine.today.last.kind, ActivityKind.clientOnSite);
    });

    onlyWithTables('and back: a second trip, working on without a project', () async {
      final user = await withClientProject();
      await startAt(user, moment(120), almeco);
      await activities.registerTrip(user, trip(almeco, client, 100, 90));

      final mine = await activities.registerTrip(user, trip(client, almeco, 30, 15));

      expect(mine.current?.kind, ActivityKind.work);
      expect(mine.breakdown.trips, 2);
      expect(mine.breakdown.distanceMetres, 85000);
    });

    onlyWithTables('sent twice: one trip', () async {
      final user = await withClientProject();
      await startAt(user, moment(120), almeco);
      final request = trip(almeco, client, 60, 15);

      await activities.registerTrip(user, request);
      final mine = await activities.registerTrip(user, request);

      expect(mine.breakdown.trips, 1);
      expect(mine.breakdown.distanceMetres, 42500);
    });

    onlyWithTables('between places that are no client of theirs: no trip', () async {
      final user = await newUser();
      await startAt(user, moment(120), almeco);

      final mine = await activities.registerTrip(user, trip(almeco, client, 60, 15));

      expect(mine.breakdown.trips, 0);
    });

    onlyWithTables('their own switch during the drive wins', () async {
      final user = await withClientProject();
      await startAt(user, moment(120), almeco);
      await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.work, at: moment(30)));

      final mine = await activities.registerTrip(user, trip(almeco, client, 60, 15));

      expect(mine.current?.kind, ActivityKind.work);
      expect(mine.breakdown.trips, 0);
    });

    onlyWithTables('already on Transport by hand: only the arrival is added, and it still has its kilometres', () async {
      final user = await withClientProject();
      await startAt(user, moment(120), almeco);
      await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.transport, at: moment(62)));

      final mine = await activities.registerTrip(user, trip(almeco, client, 60, 15));

      expect(mine.current?.kind, ActivityKind.clientOnSite);
      expect(mine.breakdown.trips, 1);
      expect(mine.breakdown.distanceMetres, 42500);
    });

    onlyWithTables('a manual start: the place is not known, so the trip has no distance', () async {
      final user = await withClientProject();
      await start(user, moment(120));
      final project = (await activities.mine(user)).projects.single;
      await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.internal, at: moment(100), projectId: project.id));
      await db.execute('UPDATE tblProject SET addressID = NULL WHERE projectID = :p', {'p': project.id});

      await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.transport, at: moment(60)));
      final mine = await activities.switchTo(user, SwitchActivityRequest(kind: ActivityKind.work, at: moment(30)));

      expect(mine.breakdown.trips, 1);
      expect(mine.breakdown.distanceMetres, 0);
      expect(mine.breakdown.tripsWithoutDistance, 1);
    });

    onlyWithTables('checks: a day not running, an unknown location, times that can’t be', () async {
      final user = await withClientProject();
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
        await expectLater(
          activities.registerTrip(user, request),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
        );
      }
    });

    onlyWithTables('a phone watches its own clients, not everyone’s', () async {
      final mine = await withClientProject();
      final other = await newUser();

      const repository = ActivityRepository();

      expect(await repository.otherProjectAddresses(db, mine), isNot(contains(client)));
      expect(await repository.otherProjectAddresses(db, other), contains(client));
    });
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
