@Tags(['integration'])
library;

import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/time_registration/time_registration_repository.dart';
import 'package:jitan_api/src/time_registration/time_registration_service.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// The read-only registration stream against real MySQL, with `[DEV-TEST]`
/// fixtures removed in tearDownAll.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  late int companyId;
  late int userId;
  late int otherUserId;
  late int typeId;
  late int addressId;
  final ids = <String, int>{};

  TimeRegistrationService service() => TimeRegistrationService(
    registrations: TimeRegistrationRepository(db),
    employees: EmployeeRepository(db),
    companies: CompanyRepository(db),
    executor: db,
  );

  Future<int> insertUser(String code) async => (await db.execute(
    'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
    "VALUES ('[DEV-TEST]', 'TimeReg', :code, :qr, 1, 0)",
    {'code': code, 'qr': 'DEV-TEST-$code'},
  )).lastInsertId;

  Future<void> reg(String key, int user, String at, {bool active = true, bool mfd = false, bool? manual = false}) async {
    ids[key] = (await db.execute(
      'INSERT INTO tblTimeReg (userID, addressID, timeRegTypeID, timeRegTimestamp, timeRegManualEntry, '
      'timeRegActive, timeRegMFD) VALUES (:u, :a, :t, :at, :manual, :active, :mfd)',
      {'u': user, 'a': addressId, 't': typeId, 'at': at, 'manual': manual, 'active': active, 'mfd': mfd},
    )).lastInsertId;
  }

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 2);
    companyId = (await db.execute(
      'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:n, 1, 0)',
      {'n': '[DEV-TEST] TimeReg $stamp'},
    )).lastInsertId;
    userId = await insertUser('DTR$stamp');
    otherUserId = await insertUser('DTO$stamp');
    await db.execute('INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)', {'u': userId, 'c': companyId});
    typeId = (await db.execute(
      'INSERT INTO tblTimeRegType (timeRegTypeName, timeRegTypeActive, timeRegTypeMFD) VALUES (:n, 1, 0)',
      {'n': '[DEV-TEST] type $stamp'},
    )).lastInsertId;
    addressId = (await db.execute(
      'INSERT INTO tblAddress (addressLogicalName, addressActive, addressMFD) VALUES (:n, 1, 0)',
      {'n': '[DEV-TEST] site $stamp'},
    )).lastInsertId;

    await reg('before', userId, '2026-09-30 23:59:59');
    await reg('a', userId, '2026-10-06 08:00:00');
    await reg('b', userId, '2026-10-06 08:00:00', manual: null);
    await reg('c', userId, '2026-10-06 16:30:00', manual: true);
    await reg('inactive', userId, '2026-10-06 12:00:00', active: false);
    await reg('deleted', userId, '2026-10-06 12:30:00', mfd: true);
    await reg('atEnd', userId, '2026-10-08 00:00:00');
    await reg('other', otherUserId, '2026-10-06 09:00:00');
  });

  tearDownAll(() async {
    await db.execute('DELETE FROM tblTimeReg WHERE userID IN (:u, :o)', {'u': userId, 'o': otherUserId});
    await db.execute('DELETE FROM tblUserCompany WHERE userID = :u', {'u': userId});
    for (final id in [userId, otherUserId]) {
      await db.execute('DELETE FROM tblUser WHERE userID = :id', {'id': id});
    }
    await db.execute('DELETE FROM tblTimeRegType WHERE timeRegTypeID = :id', {'id': typeId});
    await db.execute('DELETE FROM tblAddress WHERE addressID = :id', {'id': addressId});
    await db.execute('DELETE FROM tblCompany WHERE companyID = :id', {'id': companyId});
    await db.close();
  });

  const range = {'from': '2026-10-01', 'to': '2026-10-08'};

  test('active, non-MFD registrations in [from, to), oldest first, ties by id; only this user', () async {
    final page = await service().forEmployee(companyId, userId, range);

    expect(page.registrations.map((r) => r.id), [ids['a'], ids['b'], ids['c']]);
    expect(page.nextCursor, isNull);
  });

  test('wall-clock times, raw type and address names, and an unknown manual flag stay as stored', () async {
    final page = await service().forEmployee(companyId, userId, range);
    final [a, b, c] = page.registrations;

    expect(a.timestamp, DateTime(2026, 10, 6, 8));
    expect(a.typeName, '[DEV-TEST] type $stamp');
    expect(a.addressName, '[DEV-TEST] site $stamp');
    expect((a.isManualEntry, b.isManualEntry, c.isManualEntry), (false, null, true));
  });

  test('pages through equal timestamps without skipping or repeating', () async {
    final seen = <int>[];
    String? cursor;
    do {
      final page = await service().forEmployee(companyId, userId, {...range, 'limit': '1', 'cursor': ?cursor});
      seen.addAll(page.registrations.map((r) => r.id));
      cursor = page.nextCursor;
    } while (cursor != null);

    expect(seen, [ids['a'], ids['b'], ids['c']]);
  });

  test('a time-of-day range narrows the result', () async {
    final page = await service().mine(userId, {'from': '2026-10-06T08:00', 'to': '2026-10-06T16:30'});

    expect(page.registrations.map((r) => r.id), [ids['a'], ids['b']]);
  });

  test('an employee outside the company is not found', () async {
    await expectLater(
      service().forEmployee(companyId, otherUserId, range),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });
}
