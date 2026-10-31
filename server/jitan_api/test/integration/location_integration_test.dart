@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/locations/location_repository.dart';
import 'package:jitan_api/src/locations/location_service.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// HR/Admin managing locations against real MySQL with `[DEV-TEST]`
/// fixtures. The tests run in order.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late LocationService locations;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final name = '[DEV-TEST] $stamp office';
  final createdEventTypes = <int>[];
  final geofences = <int>[];
  late int actor;
  late int locationId;

  LocationRequest request({String? name_, int radius = 50}) => LocationRequest(
    name: name_ ?? name,
    street: 'Rue du Progrès',
    number: '12',
    zipcode: '7700',
    city: 'Mouscron',
    point: const GeoPoint(latitude: 50.7436, longitude: 3.2167),
    radiusMeters: radius,
  );

  Future<List<String>> auditTypes() async => [
    for (final row in await db.query(
      'SELECT t.eventTypeName FROM tblEventLog l JOIN tblEventLogEventType et ON et.eventLogID = l.eventLogID '
      'JOIN tblEventType t ON t.eventTypeID = et.eventTypeID WHERE l.addressID = :a ORDER BY l.eventLogID',
      {'a': locationId},
    ))
      row.readString('eventTypeName'),
  ];

  setUpAll(() async {
    db = TestDatabase.connect();
    locations = LocationService(
      locations: const LocationRepository(),
      audit: const AuditLogRepository(),
      transactions: db,
      executor: db,
    );
    for (final type in ['location.created', 'location.changed', 'location.deactivated', 'location.reactivated']) {
      if ((await db.query('SELECT 1 FROM tblEventType WHERE eventTypeName = :n', {'n': type})).isEmpty) {
        createdEventTypes.add(
          (await db.execute('INSERT INTO tblEventType (eventTypeName) VALUES (:n)', {'n': type})).lastInsertId,
        );
      }
    }
    actor = (await db.execute(
      "INSERT INTO tblUser (userName, userSurname, userCode, userQRcode) VALUES ('[DEV-TEST]', 'Locations', :c, :c)",
      {'c': 'LOC$stamp'},
    )).lastInsertId;
  });

  tearDownAll(() async {
    final addresses = (await db.query(
      'SELECT addressID FROM tblAddress WHERE addressLogicalName LIKE :p',
      {'p': '[DEV-TEST] $stamp%'},
    )).map((r) => r.readInt('addressID')).toList();
    for (final id in addresses) {
      final links = await db.query('SELECT geofenceID FROM tblGeofenceAddress WHERE addressID = :a', {'a': id});
      geofences.addAll(links.map((r) => r.readInt('geofenceID')));
      await db.execute(
        'DELETE et FROM tblEventLogEventType et JOIN tblEventLog l ON l.eventLogID = et.eventLogID WHERE l.addressID = :a',
        {'a': id},
      );
      await db.execute('DELETE FROM tblEventLog WHERE addressID = :a', {'a': id});
      await db.execute('DELETE FROM tblGeofenceAddress WHERE addressID = :a', {'a': id});
      await db.execute('DELETE FROM tblAddress WHERE addressID = :a', {'a': id});
    }
    for (final id in geofences) {
      await db.execute('DELETE FROM tblGeofence WHERE geofenceID = :g', {'g': id});
    }
    await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': actor});
    for (final id in createdEventTypes) {
      await db.execute('DELETE FROM tblEventType WHERE eventTypeID = :t', {'t': id});
    }
    await db.close();
  });

  test('add writes the address, the geofence and their link, audited', () async {
    final created = await locations.create(actor, request());
    locationId = created.id;

    expect(created.name, name);
    expect(created.radiusMeters, 50);
    expect((created.point?.latitude, created.point?.longitude), (50.7436, 3.2167));
    final stored = await db.query('SELECT addressCoordinates FROM tblAddress WHERE addressID = :a', {'a': locationId});
    expect(stored.single.readString('addressCoordinates'), '50.743600,3.216700');
    expect(await auditTypes(), ['location.created']);
  });

  test('the same name is refused and leaves nothing behind', () async {
    final before = (await db.query('SELECT COUNT(*) AS n FROM tblGeofence')).single.readInt('n');

    await expectLater(
      locations.create(actor, request()),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.duplicateLocationName)),
    );

    expect((await db.query('SELECT COUNT(*) AS n FROM tblGeofence')).single.readInt('n'), before);
  });

  test('change updates both tables; the same values again are not audited', () async {
    final changed = await locations.update(actor, locationId, request(radius: 100));
    await locations.update(actor, locationId, request(radius: 100));

    expect(changed.radiusMeters, 100);
    expect(await auditTypes(), ['location.created', 'location.changed']);
  });

  test('deactivate keeps the rows, and the list still shows it; reactivate brings it back', () async {
    expect((await locations.setActive(actor, locationId, active: false)).isActive, false);
    final listed = (await locations.all()).where((l) => l.id == locationId).single;
    expect(listed.isActive, false);

    expect((await locations.setActive(actor, locationId, active: true)).isActive, true);
    expect(await auditTypes(), ['location.created', 'location.changed', 'location.deactivated', 'location.reactivated']);
  });

  test('an address without a geofence is not a location', () async {
    final address = (await db.execute(
      'INSERT INTO tblAddress (addressStreet, addressLogicalName) VALUES (:s, :n)',
      {'s': 'Client street', 'n': '[DEV-TEST] $stamp client'},
    )).lastInsertId;

    expect((await locations.all()).map((l) => l.id), isNot(contains(address)));
    await expectLater(locations.find(address), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
  });
}
