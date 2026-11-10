@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/locations/location_repository.dart';
import 'package:jitan_api/src/locations/location_service.dart';
import 'package:jitan_api/src/projects/project_repository.dart';
import 'package:jitan_api/src/projects/project_service.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Projects on IT's tables (D43, D44): a `tblAddress` row of the kind
/// "Project location", named `<SAP number> <name>`; a client site with its
/// area, or internal work at a workshop. The tests run in order.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late ProjectService projects;
  late LocationService locations;
  late int actor;
  late int workshop;
  late int clientId;
  late int internalId;
  final addresses = <int>[];
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;

  LocationRequest site(String street) => LocationRequest(
    name: 'ignored',
    street: street,
    number: '12',
    zipcode: '7700',
    city: 'Mouscron',
    point: const GeoPoint(latitude: 50.7436, longitude: 3.2167),
    radiusMeters: 75,
  );

  Matcher refused(int status, {String? field}) => throwsA(
    isA<ApiException>().having((e) => e.statusCode, 'status', status).having((e) => e.field, 'field', field ?? anything),
  );

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 2);
    projects = ProjectService(
      projects: const ProjectRepository(),
      locations: const LocationRepository(),
      audit: const AuditLogRepository(),
      transactions: db,
      executor: db,
    );
    locations = LocationService(locations: const LocationRepository(), audit: const AuditLogRepository(), transactions: db, executor: db);
    actor = (await db.execute(
      "INSERT INTO tblUser (userName, userSurname, userCode, userActive, userMFD) VALUES ('[DEV-TEST]', 'Projects', :c, 1, 0)",
      {'c': 'DTP$stamp'},
    )).lastInsertId;
    workshop = (await locations.create(
      actor,
      LocationRequest(
        name: '[DEV-TEST] $stamp workshop',
        street: 'Rue du Progrès',
        number: '1',
        city: 'Mouscron',
        point: const GeoPoint(latitude: 50.7, longitude: 3.2),
        radiusMeters: 50,
      ),
    )).id;
    addresses.add(workshop);
  });

  tearDownAll(() async {
    await db.execute(
      'DELETE t FROM tblEventLogEventType t JOIN tblEventLog e ON e.eventLogID = t.eventLogID WHERE e.userIDInit = :u',
      {'u': actor},
    );
    await db.execute('DELETE FROM tblEventLog WHERE userIDInit = :u', {'u': actor});
    for (final address in addresses) {
      await db.execute('DELETE FROM tblAddressLocationType WHERE addressID = :a', {'a': address});
      final links = await db.query('SELECT geofenceID FROM tblGeofenceAddress WHERE addressID = :a', {'a': address});
      await db.execute('DELETE FROM tblGeofenceAddress WHERE addressID = :a', {'a': address});
      for (final link in links) {
        await db.execute('DELETE FROM tblGeofence WHERE geofenceID = :g', {'g': link.readInt('geofenceID')});
      }
      await db.execute('DELETE FROM tblAddress WHERE addressID = :a', {'a': address});
    }
    await db.execute('DELETE FROM tblUser WHERE userID = :u', {'u': actor});
    await db.close();
  });

  test('a client site: an address with its area, named "<SAP number> <name>", of the kind Project location, audited', () async {
    final created = await projects.create(actor, ProjectRequest(sapNumber: ' P$stamp ', name: ' Office refurbishment ', site: site('Rue A')));
    clientId = created.summary.id;
    addresses.add(clientId);

    expect((created.summary.sapNumber, created.summary.name), ('P$stamp', 'Office refurbishment'));
    expect((created.summary.isClientSite, created.summary.placeName, created.summary.isActive), (true, 'Mouscron', true));
    expect(created.site?.radiusMeters, 75);
    final stored = (await db.query('SELECT addressLogicalName FROM tblAddress WHERE addressID = :a', {'a': clientId})).single;
    expect(stored.readString('addressLogicalName'), 'P$stamp Office refurbishment');
    final audited = await db.query('SELECT addressLocationTypeID FROM tblEventLog WHERE userIDInit = :u AND addressID = :a', {
      'u': actor,
      'a': clientId,
    });
    expect(audited.single.readOptionalInt('addressLocationTypeID'), isNotNull);
  });

  test('internal work: at the workshop, with its coordinates and no area of its own', () async {
    final created = await projects.create(actor, ProjectRequest(sapNumber: 'I$stamp', name: 'Cleaning', workshopId: workshop));
    internalId = created.summary.id;
    addresses.add(internalId);

    expect((created.summary.isClientSite, created.summary.placeName), (false, '[DEV-TEST] $stamp workshop'));
    expect(created.workshopId, workshop);
    expect(created.site, isNull);
  });

  test('the Locations page lists workplaces only; a phone watches the client site too', () async {
    expect((await locations.all()).map((l) => l.id), isNot(contains(clientId)));
    expect((await locations.recognised()).map((l) => l.id), contains(clientId));
    expect((await locations.recognised()).map((l) => l.id), isNot(contains(internalId)), reason: 'no area of its own');
  });

  test('changes are audited; a project keeps its kind of place', () async {
    final changed = await projects.update(actor, clientId, ProjectRequest(sapNumber: 'P$stamp', name: 'Office works', site: site('Rue B')));

    expect(changed.summary.name, 'Office works');
    expect(changed.site?.street, 'Rue B');
    await expectLater(
      projects.update(actor, clientId, ProjectRequest(sapNumber: 'P$stamp', name: 'x', workshopId: workshop)),
      refused(400, field: ProjectRequest.fieldWorkshop),
    );
  });

  test('deactivated: still listed for HR, gone from what can be chosen', () async {
    final off = await projects.setActive(actor, internalId, active: false);

    expect(off.summary.isActive, isFalse);
    expect((await projects.list()).where((p) => p.id == internalId).single.isActive, isFalse);
    expect((await const ProjectRepository().list(db, activeOnly: true)).map((p) => p.id), isNot(contains(internalId)));
    await projects.setActive(actor, internalId, active: true);
  });

  test('checks: SAP number, name, a workshop, and a name in use in any capitals', () async {
    for (final (request, field) in [
      (ProjectRequest(sapNumber: ' ', name: 'x', workshopId: workshop), ProjectRequest.fieldSapNumber),
      (ProjectRequest(sapNumber: 'P 1', name: 'x', workshopId: workshop), ProjectRequest.fieldSapNumber),
      (ProjectRequest(sapNumber: 'P1', name: ' ', workshopId: workshop), ProjectRequest.fieldName),
      (ProjectRequest(sapNumber: 'P1', name: 'x' * 120, workshopId: workshop), ProjectRequest.fieldName),
      (const ProjectRequest(sapNumber: 'P1', name: 'x'), ProjectRequest.fieldWorkshop),
      (ProjectRequest(sapNumber: 'P1', name: 'x', workshopId: clientId), ProjectRequest.fieldWorkshop),
    ]) {
      await expectLater(projects.create(actor, request), refused(400, field: field), reason: field);
    }
    await expectLater(
      projects.create(actor, ProjectRequest(sapNumber: 'p$stamp', name: 'OFFICE WORKS', site: site('Rue C'))),
      refused(409, field: ProjectRequest.fieldName),
    );
  });

  test('a hostile name is stored as text', () async {
    const hostile = "x'); DROP TABLE tblAddress; --";
    final created = await projects.create(actor, ProjectRequest(sapNumber: 'H$stamp', name: hostile, workshopId: workshop));
    addresses.add(created.summary.id);

    expect(created.summary.name, hostile);
  });

  test('a SAP number and name split back', () {
    expect(ProjectRequest.split('P-1042 Office refurbishment'), ('P-1042', 'Office refurbishment'));
    expect(ProjectRequest.split('P-1042'), ('P-1042', ''));
  });
}
