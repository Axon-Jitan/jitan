@Tags(['integration'])
library;

import 'package:jitan_api/src/activities/activity_repository.dart';
import 'package:jitan_api/src/activities/activity_service.dart';
import 'package:jitan_api/src/activities/trip_kilometres.dart';
import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/auth/credential_repository.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/locations/location_repository.dart';
import 'package:jitan_api/src/projects/project_repository.dart';
import 'package:jitan_api/src/routing/driving_distance.dart';
import 'package:jitan_api/src/schedules/schedule_repository.dart';
import 'package:jitan_api/src/temporary_qr/in_memory_temporary_token_store.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_service.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_tokens.dart';
import 'package:jitan_api/src/terminals/terminal_device_service.dart';
import 'package:jitan_api/src/terminals/terminal_presence.dart';
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

/// Terminals on IT's tables (GAP-09, D18, D41): a shared `tblDevice`, its
/// kind through `tblDeviceDeviceType`, and a kiosk `tblUser` holding the
/// tablet's hashed secret. Switching project needs the proposed activity
/// tables and is skipped without them.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late bool activitiesHere;
  late TerminalService terminals;
  late TerminalDeviceService device;
  late TemporaryQrService temporaryQr;
  late TerminalRepository repository;
  late TerminalPresence presence;
  late int company;
  late int otherCompany;
  late int officeType;
  late int vehicleType;
  final users = <int>[];
  final devices = <int>[];
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
    final code = 'DT$stamp${++counter}';
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

  TerminalRequest request(String name, {int? type, String? serial}) =>
      TerminalRequest(name: '$prefix $name', typeId: type ?? officeType, serialNumber: serial ?? 'SN$stamp-${++counter}');

  Future<Terminal> add(int actor, TerminalRequest terminal) async {
    final created = await terminals.create(actor, terminal);
    devices.add(created.id);
    return created;
  }

  /// Added and connected; returns the terminal and its tablet's token.
  Future<(Terminal, String)> connected({String name = 'Reception'}) async {
    final (actor, _) = await newEmployee();
    final terminal = await add(actor, request(name));
    final qr = await terminals.pairingQr(actor, terminal.id);
    final paired = await device.pair(TerminalPairRequest(qrCode: qr.qrCode, deviceId: 'tablet-${++counter}'));
    return (terminal, paired.token);
  }

  Matcher refusedWith(int status, String code) =>
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status).having((e) => e.code, 'code', code));

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 3);
    activitiesHere = true;
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
    final activities = activitiesHere
        ? ActivityService(
            activities: const ActivityRepository(),
            projects: const ProjectRepository(),
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
          )
        : null;
    temporaryQr = TemporaryQrService(tokens: TemporaryQrTokens.withRandomKey(), store: InMemoryTemporaryTokenStore());
    repository = const TerminalRepository();
    presence = TerminalPresence();
    terminals = TerminalService(
      terminals: repository,
      presence: presence,
      temporaryQr: temporaryQr,
      audit: const AuditLogRepository(),
      transactions: db,
      executor: db,
    );
    device = TerminalDeviceService(
      terminals: repository,
      presence: presence,
      temporaryQr: temporaryQr,
      writes: TimeRegistrationWriteService(
        transactions: db,
        rounding: RegistrationRounding(schedules),
        clock: clock,
        onDayStart: activities?.dayStarted,
      ),
      activities: activities,
      myDay: myDay,
      audit: const AuditLogRepository(),
      transactions: db,
      executor: db,
      clock: clock,
    );
    final types = await repository.types(db);
    officeType = types.firstWhere((t) => t.name == TerminalRepository.officeTypeName).id;
    vehicleType = types.firstWhere((t) => t.name == TerminalRepository.vehicleTypeName).id;
    company = await newCompany('company');
    otherCompany = await newCompany('other');
  });

  tearDownAll(() async {
    Future<void> eventsWhere(String condition, Map<String, Object?> values) async {
      await db.execute(
        'DELETE t FROM tblEventLogEventType t JOIN tblEventLog e ON e.eventLogID = t.eventLogID WHERE $condition',
        values,
      );
      await db.execute('DELETE e FROM tblEventLog e WHERE $condition', values);
    }

    for (final id in devices) {
      final kiosks = await db.query('SELECT userID FROM tblUserDevice WHERE deviceID = :d', {'d': id});
      await eventsWhere('e.deviceID = :d', {'d': id});
      await db.execute('DELETE FROM tblUserDevice WHERE deviceID = :d', {'d': id});
      await db.execute('DELETE FROM tblDeviceDeviceType WHERE deviceID = :d', {'d': id});
      for (final kiosk in kiosks) {
        await eventsWhere('e.userIDTarget = :u', {'u': kiosk.readInt('userID')});
        await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': kiosk.readInt('userID')});
      }
      await db.execute('DELETE FROM tblDevice WHERE deviceID = :d', {'d': id});
    }
    for (final user in users) {
      await eventsWhere('e.userIDInit = :u OR e.userIDTarget = :u', {'u': user});
      await db.execute('DELETE FROM tblTimeReg WHERE userID = :u', {'u': user});
      await db.execute('DELETE FROM tblUserCompany WHERE userID = :u', {'u': user});
      await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': user});
    }
    await db.execute('DELETE FROM tblCompany WHERE companyID IN (:a, :b)', {'a': company, 'b': otherCompany});
    await db.close();
  });

  group('HR', () {
    test('a terminal is a shared tblDevice with its kind and a kiosk user without a password', () async {
      final (actor, _) = await newEmployee();

      final created = await add(actor, request('van 1-ABC-123', type: vehicleType, serial: '  R9TW51-$stamp '));

      expect(created.serialNumber, 'R9TW51-$stamp');
      expect(created.type.id, vehicleType);
      expect(created.status, TerminalStatus.notConnected);
      final row = (await db.query(
        'SELECT d.deviceMultiUser, u.userKioskMode, u.userPassword, u.userCode FROM tblDevice d '
        'JOIN tblUserDevice ud ON ud.deviceID = d.deviceID JOIN tblUser u ON u.userID = ud.userID WHERE d.deviceID = :d',
        {'d': created.id},
      )).single;
      expect(row.readBool('deviceMultiUser'), isTrue);
      expect(row.readBool('userKioskMode'), isTrue);
      expect(row.readOptionalString('userPassword'), isNull);
      expect(row.readString('userCode'), TerminalRepository.kioskCode(created.id));
    });

    test('a serial number is needed, and one in use (in any capitals) is refused', () async {
      final (actor, _) = await newEmployee();
      await expectLater(
        terminals.create(actor, request('no serial', serial: '  ')),
        throwsA(isA<ApiException>().having((e) => e.field, 'field', TerminalRequest.fieldSerialNumber)),
      );
      final first = await add(actor, request('first', serial: 'abc-$stamp'));

      await expectLater(
        terminals.create(actor, request('second', serial: 'ABC-$stamp')),
        refusedWith(409, ApiErrorCode.duplicateSerialNumber),
      );
      expect(first.serialNumber, 'abc-$stamp');
    });

    test('changing the kind relinks it, and the list shows every terminal', () async {
      final (actor, _) = await newEmployee();
      final created = await add(actor, request('kind'));

      final changed = await terminals.update(actor, created.id, request('kind', type: vehicleType, serial: created.serialNumber));

      expect(changed.type.id, vehicleType);
      expect((await terminals.list()).where((t) => t.id == created.id).single.type.id, vehicleType);
    });

    test('deactivate and reactivate: audited once each, the tablet shut out meanwhile, and an action that changes nothing is not', () async {
      final (actor, _) = await newEmployee();
      final (terminal, _) = await connected();
      Future<int> audited() async => (await db.query(
        'SELECT COUNT(*) AS n FROM tblEventLog WHERE deviceID = :t AND userIDInit = :u',
        {'t': terminal.id, 'u': actor},
      )).single.readInt('n');

      expect((await terminals.setActive(actor, terminal.id, active: false)).status, TerminalStatus.inactive);
      await terminals.setActive(actor, terminal.id, active: false);
      expect(await audited(), 1);
      Future<bool> kioskActive() async => (await db.query(
        'SELECT u.userActive FROM tblUserDevice ud JOIN tblUser u ON u.userID = ud.userID WHERE ud.deviceID = :d',
        {'d': terminal.id},
      )).single.readBool('userActive');
      expect(await kioskActive(), isFalse);

      expect((await terminals.setActive(actor, terminal.id, active: true)).status, isNot(TerminalStatus.inactive));
      expect(await audited(), 2);
      expect(await kioskActive(), isTrue);
    });
  });

  group('connecting a tablet', () {
    test('the secret is stored hashed on the kiosk user, the tablet is online and a new QR ends the old one', () async {
      final (actor, _) = await newEmployee();
      final terminal = await add(actor, request('b'));
      final first = await terminals.pairingQr(actor, terminal.id);
      final second = await terminals.pairingQr(actor, terminal.id);

      await expectLater(device.pair(TerminalPairRequest(qrCode: first.qrCode, deviceId: 'x')), throwsA(isA<ApiException>()));

      final paired = await device.pair(TerminalPairRequest(qrCode: second.qrCode, deviceId: 'x'));

      final stored = (await repository.find(db, terminal.id))!.secretHash!;
      expect(paired.token.split('.').last, isNot(stored));
      final seen = await terminals.find(terminal.id);
      expect(seen.status, TerminalStatus.online);
      expect(seen.lastSeen, isNotNull, reason: 'kept in memory');
      await expectLater(
        device.pair(TerminalPairRequest(qrCode: second.qrCode, deviceId: 'y')),
        throwsA(isA<ApiException>()),
        reason: 'single use',
      );
    });

    test('a kiosk user can never sign in, even with its own code', () async {
      final (terminal, _) = await connected();

      final candidates = await const CredentialRepository().candidatesByCode(db, TerminalRepository.kioskCode(terminal.id));

      expect(candidates, isEmpty);
    });

    test('reconnecting cuts off the old tablet', () async {
      final (actor, _) = await newEmployee();
      final (terminal, oldToken) = await connected();

      final qr = await terminals.pairingQr(actor, terminal.id);
      final paired = await device.pair(TerminalPairRequest(qrCode: qr.qrCode, deviceId: 'new'));

      await expectLater(device.authenticate(oldToken), refusedWith(401, 'unauthenticated'));
      expect((await device.authenticate(paired.token)).id, terminal.id);
    });

    test('a forged or missing token is refused', () async {
      final (terminal, _) = await connected();

      for (final token in [null, '', 'nonsense', '${terminal.id}.wrong', '999999.wrong']) {
        await expectLater(device.authenticate(token), refusedWith(401, 'unauthenticated'));
      }
    });

    test('a pairing QR is not an onboarding QR', () async {
      final (actor, _) = await newEmployee();
      final (terminal, _) = await connected();
      final qr = await terminals.pairingQr(actor, terminal.id);

      await expectLater(temporaryQr.check(qr.qrCode, TemporaryQrPurpose.onboarding), refusedWith(400, 'qr_wrong_purpose'));
    });
  });

  group('scanning (D41)', () {
    Future<TerminalRow> tablet() async => device.authenticate((await connected()).$2);

    test('first scan checks in, the next checks out; the terminal is on the audit row, and is the last scan', () async {
      final terminal = await tablet();
      final (user, qr) = await newEmployee();

      final first = await device.scan(terminal, TerminalScanRequest(qrCode: qr, at: moment(30)));
      expect(first.outcome, TerminalScanOutcome.checkedIn);
      expect(first.firstName, 'Terry');

      final second = await device.scan(terminal, TerminalScanRequest(qrCode: qr, at: moment(5)));
      expect(second.outcome, TerminalScanOutcome.checkedOut);

      final rows = await db.query(
        'SELECT t.timeRegTypeName, e.deviceID FROM tblTimeReg r '
        'JOIN tblTimeRegType t ON t.timeRegTypeID = r.timeRegTypeID '
        'JOIN tblEventLog e ON e.timeRegID = r.timeRegID '
        "WHERE r.userID = :u AND t.timeRegTypeName LIKE '%actual%' ORDER BY r.timeRegID",
        {'u': user},
      );
      expect(rows.map((r) => r.readString('timeRegTypeName')), ['Start – actual – QR', 'Finish – actual – QR']);
      expect(rows.map((r) => r.readInt('deviceID')).toSet(), {terminal.id});
      final lastScan = (await terminals.find(terminal.id)).lastScan!;
      expect(lastScan.difference(moment(5)).inMinutes.abs(), lessThanOrEqualTo(1));
    });

    test('a double scan changes nothing', () async {
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

    test('employees of every company may scan; unknown QRs and inactive employees may not', () async {
      final terminal = await tablet();
      final (_, fromOther) = await newEmployee(inCompany: otherCompany);
      final (_, inactive) = await newEmployee(active: false);

      final scanned = await device.scan(terminal, TerminalScanRequest(qrCode: fromOther, at: moment(1)));
      expect(scanned.outcome, TerminalScanOutcome.checkedIn, reason: 'shared by every company');
      await expectLater(device.scan(terminal, TerminalScanRequest(qrCode: 'nonsense', at: moment(1))), refusedWith(400, 'qr_not_recognised'));
      await expectLater(device.scan(terminal, TerminalScanRequest(qrCode: inactive, at: moment(1))), refusedWith(403, 'employee_unavailable'));
    });

    test('nobody scans at a deactivated terminal', () async {
      final (actor, _) = await newEmployee();
      final (terminal, token) = await connected();
      final (_, qr) = await newEmployee();

      await terminals.setActive(actor, terminal.id, active: false);
      final off = await device.authenticate(token);

      expect(device.seen(off).canScan, isFalse);
      await expectLater(device.scan(off, TerminalScanRequest(qrCode: qr, at: moment(1))), refusedWith(409, 'terminal_off'));
    });

    test('a day started at the terminal can change activity there', () async {
      if (!activitiesHere) return markTestSkipped('The proposed activity tables are not here.');
      final terminal = await tablet();
      final (_, qr) = await newEmployee();
      await device.scan(terminal, TerminalScanRequest(qrCode: qr, at: moment(10)));

      final moved = await device.switchTo(terminal, TerminalSwitchRequest(qrCode: qr, kind: ActivityKind.transport, at: moment(5)));

      expect(moved.current?.kind, ActivityKind.transport);
    });
  });
}
