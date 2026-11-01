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
import 'package:jitan_api/src/temporary_qr/in_memory_temporary_token_store.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_service.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_tokens.dart';
import 'package:jitan_api/src/terminals/terminal_device_service.dart';
import 'package:jitan_api/src/terminals/terminal_repository.dart';
import 'package:jitan_api/src/terminals/terminal_service.dart';
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

/// PROPOSAL (docs/database/PROPOSED_TABLES.md, D18, D41): terminals against
/// the local database. Skipped where the proposed tables are missing.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late bool available;
  late TerminalService terminals;
  late TerminalDeviceService device;
  late TemporaryQrService temporaryQr;
  late TerminalRepository repository;
  late int company;
  late int otherCompany;
  late int officeType;
  late int vehicleType;
  late int location;
  final users = <int>[];
  final clock = WorkplaceClock('Europe/Brussels');
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final prefix = '[DEV-TEST] $stamp';
  var counter = 0;

  DateTime moment(int minutesAgo) => DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo));

  Future<int> newCompany(String name) async => (await db.execute(
    'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:n, 1, 0)',
    {'n': '$prefix $name'},
  )).lastInsertId;

  /// An employee of [inCompany]; returns their id and Terminal QR.
  Future<(int, String)> newEmployee({int? inCompany, bool active = true}) async {
    final code = '$stamp${++counter}';
    final qr = 'QR-$code';
    final id = (await db.execute(
      'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) VALUES (:n, :s, :c, :q, :a, 0)',
      {'n': 'Terry', 's': code, 'c': code, 'q': qr, 'a': active ? 1 : 0},
    )).lastInsertId;
    await db.execute(
      'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)',
      {'u': id, 'c': inCompany ?? company},
    );
    users.add(id);
    return (id, qr);
  }

  /// Added and connected; returns the terminal and its tablet's token.
  Future<(Terminal, String)> connected({String name = 'Reception'}) async {
    final (actor, _) = await newEmployee();
    final terminal = await terminals.create(
      actor,
      TerminalRequest(name: '$prefix $name', typeId: officeType, companyId: company, addressId: location),
    );
    final qr = await terminals.pairingQr(actor, company, terminal.id);
    final paired = await device.pair(TerminalPairRequest(qrCode: qr.qrCode, deviceId: 'tablet-${++counter}', deviceName: 'Tab A9'));
    return (terminal, paired.token);
  }

  Matcher refusedWith(int status, String code) =>
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status).having((e) => e.code, 'code', code));

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
    final myDay = MyDayService(days: days, records: records, plans: WeekPlans(schedules), clock: clock);
    final activities = ActivityService(
      activities: const ActivityRepository(),
      writes: const TimeRegistrationWriteRepository(),
      myDay: myDay,
      locations: const LocationRepository(),
      kilometres: TripKilometres(
        activities: const ActivityRepository(),
        locations: const LocationRepository(),
        distance: const NoDrivingDistance(),
        executor: db,
        clock: clock,
      ),
      audit: const AuditLogRepository(),
      transactions: db,
      executor: db,
      clock: clock,
    );
    temporaryQr = TemporaryQrService(tokens: TemporaryQrTokens.withRandomKey(), store: InMemoryTemporaryTokenStore());
    repository = const TerminalRepository();
    terminals = TerminalService(
      terminals: repository,
      companies: CompanyRepository(db),
      locations: const LocationRepository(),
      temporaryQr: temporaryQr,
      audit: const AuditLogRepository(),
      transactions: db,
      executor: db,
    );
    device = TerminalDeviceService(
      terminals: repository,
      temporaryQr: temporaryQr,
      writes: TimeRegistrationWriteService(
        transactions: db,
        rounding: RegistrationRounding(schedules),
        clock: clock,
        onDayStart: activities.dayStarted,
      ),
      activities: activities,
      myDay: myDay,
      audit: const AuditLogRepository(),
      transactions: db,
      executor: db,
      clock: clock,
    );
    final types = await repository.types(db);
    officeType = types.firstWhere((t) => t.name == 'Office').id;
    vehicleType = types.firstWhere((t) => t.name == 'Vehicle').id;
    company = await newCompany('company');
    otherCompany = await newCompany('other');
    location = (await db.execute(
      'INSERT INTO tblAddress (addressStreet, addressLogicalName, addressCoordinates, addressActive, addressMFD) '
      'VALUES (:s, :n, :c, 1, 0)',
      {'s': 'Street', 'n': '$prefix site', 'c': '51.0,4.0'},
    )).lastInsertId;
    final geofence = (await db.execute(
      'INSERT INTO tblGeofence (geofenceRadiusInMeter, geofenceActive, geofenceMFD) VALUES (100, 1, 0)',
    )).lastInsertId;
    await db.execute(
      'INSERT INTO tblGeofenceAddress (geofenceID, addressID, geofenceAddressActive, geofenceAddressMFD) VALUES (:g, :a, 1, 0)',
      {'g': geofence, 'a': location},
    );
  });

  tearDownAll(() async {
    if (available) {
      await db.execute(
        'DELETE t FROM tblEventLogEventType t JOIN tblEventLog e ON e.eventLogID = t.eventLogID WHERE e.companyID IN (:a, :b)',
        {'a': company, 'b': otherCompany},
      );
      await db.execute('DELETE FROM tblEventLog WHERE companyID IN (:a, :b)', {'a': company, 'b': otherCompany});
      for (final user in users) {
        await db.execute(
          'DELETE t FROM tblEventLogEventType t JOIN tblEventLog e ON e.eventLogID = t.eventLogID WHERE e.userIDInit = :u',
          {'u': user},
        );
        await db.execute('DELETE FROM tblEventLog WHERE userIDInit = :u OR userIDTarget = :u', {'u': user});
        await db.execute('DELETE FROM tblTimeReg WHERE userID = :u', {'u': user});
        await db.execute('DELETE FROM tblUserCompany WHERE userID = :u', {'u': user});
        await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': user});
      }
      await db.execute('DELETE FROM tblTerminal WHERE companyID IN (:a, :b)', {'a': company, 'b': otherCompany});
      await db.execute('DELETE FROM tblCompany WHERE companyID IN (:a, :b)', {'a': company, 'b': otherCompany});
      final links = await db.query('SELECT geofenceID FROM tblGeofenceAddress WHERE addressID = :a', {'a': location});
      await db.execute('DELETE FROM tblGeofenceAddress WHERE addressID = :a', {'a': location});
      for (final link in links) {
        await db.execute('DELETE FROM tblGeofence WHERE geofenceID = :g', {'g': link.readInt('geofenceID')});
      }
      await db.execute('DELETE FROM tblAddress WHERE addressID = :a', {'a': location});
    }
    await db.close();
  });

  void onlyWithTables(String name, Future<void> Function() body) => test(name, () async {
    if (!available) return markTestSkipped('The proposed tables are not here.');
    await body();
  });

  group('HR', () {
    onlyWithTables('an office needs a location, a vehicle a number plate', () async {
      final (actor, _) = await newEmployee();
      final office = TerminalRequest(name: '$prefix a', typeId: officeType, companyId: company);
      await expectLater(terminals.create(actor, office), throwsA(isA<ApiException>().having((e) => e.field, 'field', 'addressId')));

      final van = TerminalRequest(name: '$prefix van', typeId: vehicleType, companyId: company);
      await expectLater(terminals.create(actor, van), throwsA(isA<ApiException>().having((e) => e.field, 'field', 'plateNumber')));

      final created = await terminals.create(
        actor,
        TerminalRequest(name: '$prefix van', typeId: vehicleType, companyId: company, plateNumber: ' 1-ABC-123 ', addressId: location),
      );
      expect(created.plateNumber, '1-ABC-123');
      expect(created.addressId, isNull, reason: 'a vehicle has no location');
      expect(created.status, TerminalStatus.notConnected);
    });

    onlyWithTables('a list shows only the companies the viewer may see', () async {
      final (terminal, _) = await connected();

      expect((await terminals.list((id) async => id == otherCompany)).map((t) => t.id), isNot(contains(terminal.id)));
      expect((await terminals.list((id) async => id == company)).map((t) => t.id), contains(terminal.id));
    });

    onlyWithTables('another company’s terminal does not exist', () async {
      final (terminal, _) = await connected();

      await expectLater(terminals.find(otherCompany, terminal.id), refusedWith(404, 'not_found'));
    });

    onlyWithTables('deactivate, reactivate, remove: audited once each, and an action that changes nothing is not', () async {
      final (actor, _) = await newEmployee();
      final (terminal, _) = await connected();
      Future<int> audited() async => (await db.query(
        'SELECT COUNT(*) AS n FROM tblEventLog WHERE terminalID = :t AND userIDInit = :u',
        {'t': terminal.id, 'u': actor},
      )).single.readInt('n');

      expect((await terminals.setActive(actor, company, terminal.id, active: false)).status, TerminalStatus.inactive);
      await terminals.setActive(actor, company, terminal.id, active: false);
      expect(await audited(), 1);

      await terminals.setActive(actor, company, terminal.id, active: true);
      await terminals.remove(actor, company, terminal.id);
      expect(await audited(), 3);
      await expectLater(terminals.find(company, terminal.id), refusedWith(404, 'not_found'));
    });
  });

  group('connecting a tablet', () {
    onlyWithTables('the secret is stored hashed, the tablet is online and a new QR ends the old one', () async {
      final (actor, _) = await newEmployee();
      final terminal = await terminals.create(
        actor,
        TerminalRequest(name: '$prefix b', typeId: officeType, companyId: company, addressId: location),
      );
      final first = await terminals.pairingQr(actor, company, terminal.id);
      final second = await terminals.pairingQr(actor, company, terminal.id);

      await expectLater(device.pair(TerminalPairRequest(qrCode: first.qrCode, deviceId: 'x')), throwsA(isA<ApiException>()));

      final paired = await device.pair(TerminalPairRequest(qrCode: second.qrCode, deviceId: 'x', deviceName: 'Tab A9'));

      final stored = (await repository.find(db, terminal.id))!.secretHash!;
      expect(paired.token.split('.').last, isNot(stored));
      final seen = await terminals.find(company, terminal.id);
      expect(seen.status, TerminalStatus.online);
      expect(seen.deviceName, 'Tab A9');
      await expectLater(
        device.pair(TerminalPairRequest(qrCode: second.qrCode, deviceId: 'y')),
        throwsA(isA<ApiException>()),
        reason: 'single use',
      );
    });

    onlyWithTables('reconnecting cuts off the old tablet', () async {
      final (actor, _) = await newEmployee();
      final (terminal, oldToken) = await connected();

      final qr = await terminals.pairingQr(actor, company, terminal.id);
      final paired = await device.pair(TerminalPairRequest(qrCode: qr.qrCode, deviceId: 'new'));

      await expectLater(device.authenticate(oldToken), refusedWith(401, 'unauthenticated'));
      expect((await device.authenticate(paired.token)).id, terminal.id);
    });

    onlyWithTables('a forged or missing token is refused', () async {
      final (terminal, _) = await connected();

      for (final token in [null, '', 'nonsense', '${terminal.id}.wrong', '999999.wrong']) {
        await expectLater(device.authenticate(token), refusedWith(401, 'unauthenticated'));
      }
    });

    onlyWithTables('a pairing QR is not an onboarding QR', () async {
      final (actor, _) = await newEmployee();
      final (terminal, _) = await connected();
      final qr = await terminals.pairingQr(actor, company, terminal.id);

      await expectLater(temporaryQr.check(qr.qrCode, TemporaryQrPurpose.onboarding), refusedWith(400, 'qr_wrong_purpose'));
    });
  });

  group('scanning (D41)', () {
    Future<TerminalRow> tablet() async => device.authenticate((await connected()).$2);

    onlyWithTables('first scan checks in, the next checks out, with the terminal on the rows', () async {
      final terminal = await tablet();
      final (user, qr) = await newEmployee();

      final first = await device.scan(terminal, TerminalScanRequest(qrCode: qr, at: moment(30)));
      expect(first.outcome, TerminalScanOutcome.checkedIn);
      expect(first.firstName, 'Terry');

      final second = await device.scan(terminal, TerminalScanRequest(qrCode: qr, at: moment(5)));
      expect(second.outcome, TerminalScanOutcome.checkedOut);

      final rows = await db.query(
        'SELECT t.timeRegTypeName, r.terminalID, r.addressID FROM tblTimeReg r '
        'JOIN tblTimeRegType t ON t.timeRegTypeID = r.timeRegTypeID '
        "WHERE r.userID = :u AND t.timeRegTypeName LIKE '%actual%' ORDER BY r.timeRegID",
        {'u': user},
      );
      expect(rows.map((r) => r.readString('timeRegTypeName')), ['Start – actual – QR', 'Finish – actual – QR']);
      expect(rows.map((r) => r.readInt('terminalID')).toSet(), {terminal.id});
      expect(rows.first.readInt('addressID'), location);
    });

    onlyWithTables('a double scan changes nothing', () async {
      final terminal = await tablet();
      final (user, qr) = await newEmployee();
      await device.scan(terminal, TerminalScanRequest(qrCode: qr, at: moment(30)));

      final repeat = await device.scan(terminal, TerminalScanRequest(qrCode: qr, at: moment(30).add(const Duration(seconds: 20))));

      expect(repeat.outcome, TerminalScanOutcome.alreadyCheckedIn);
      final rows = await db.query(
        'SELECT COUNT(*) AS n FROM tblTimeReg r JOIN tblTimeRegType t ON t.timeRegTypeID = r.timeRegTypeID '
        "WHERE r.userID = :u AND t.timeRegTypeName LIKE 'Finish%'",
        {'u': user},
      );
      expect(rows.single.readInt('n'), 0);
    });

    onlyWithTables('the refusals', () async {
      final terminal = await tablet();
      final (_, stranger) = await newEmployee(inCompany: otherCompany);
      final (_, inactive) = await newEmployee(active: false);

      await expectLater(device.scan(terminal, TerminalScanRequest(qrCode: 'nonsense', at: moment(1))), refusedWith(400, 'qr_not_recognised'));
      await expectLater(device.scan(terminal, TerminalScanRequest(qrCode: stranger, at: moment(1))), refusedWith(403, 'scan_not_allowed'));
      await expectLater(device.scan(terminal, TerminalScanRequest(qrCode: inactive, at: moment(1))), refusedWith(403, 'employee_unavailable'));
    });

    onlyWithTables('nobody scans at a terminal switched off or deactivated', () async {
      final (actor, _) = await newEmployee();
      final (terminal, token) = await connected();
      final (_, qr) = await newEmployee();

      await terminals.setScanning(actor, company, terminal.id, enabled: false);
      await expectLater(
        device.scan(await device.authenticate(token), TerminalScanRequest(qrCode: qr, at: moment(1))),
        refusedWith(409, 'terminal_off'),
      );

      await terminals.setScanning(actor, company, terminal.id, enabled: true);
      await terminals.setActive(actor, company, terminal.id, active: false);
      final off = await device.authenticate(token);
      expect((await device.seen(off)).canScan, isFalse);
      await expectLater(device.scan(off, TerminalScanRequest(qrCode: qr, at: moment(1))), refusedWith(409, 'terminal_off'));
    });

    onlyWithTables('the day counts for the terminal’s company', () async {
      final terminal = await tablet();
      final (user, qr) = await newEmployee();
      await db.execute(
        'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)',
        {'u': user, 'c': otherCompany},
      );

      final result = await device.scan(terminal, TerminalScanRequest(qrCode: qr, at: moment(10)));

      expect(result.current?.company?.id, company);
    });

    onlyWithTables('a day started at the terminal can change project there', () async {
      final terminal = await tablet();
      final (user, qr) = await newEmployee();
      final type = (await db.query("SELECT projectTypeID AS id FROM tblProjectType WHERE projectTypeName = 'Internal'")).first.readInt('id');
      final status = (await db.query("SELECT projectStatusID AS id FROM tblProjectStatus WHERE projectStatusName = 'Active'")).first.readInt('id');
      final project = (await db.execute(
        'INSERT INTO tblProject (companyID, projectTypeID, projectStatusID, projectName, projectStartDate, projectActive, projectMFD) '
        'VALUES (:c, :t, :s, :n, :d, 1, 0)',
        {'c': company, 't': type, 's': status, 'n': '$prefix project', 'd': '2026-01-01'},
      )).lastInsertId;
      await db.execute(
        'INSERT INTO tblUserProject (userID, projectID, userProjectActive, userProjectMFD) VALUES (:u, :p, 1, 0)',
        {'u': user, 'p': project},
      );
      await device.scan(terminal, TerminalScanRequest(qrCode: qr, at: moment(10)));

      final moved = await device.switchTo(
        terminal,
        TerminalSwitchRequest(qrCode: qr, kind: ActivityKind.transport, at: moment(5)),
      );

      expect(moved.current?.kind, ActivityKind.transport);
      await db.execute('DELETE FROM tblTimeReg WHERE projectID = :p', {'p': project});
      await db.execute('DELETE FROM tblUserProject WHERE projectID = :p', {'p': project});
      await db.execute('DELETE FROM tblProject WHERE projectID = :p', {'p': project});
    });
  });
}
