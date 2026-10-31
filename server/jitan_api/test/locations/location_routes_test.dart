import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_api/src/locations/location_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

Map<String, Object?> _body({
  String name = 'Almeco office',
  String street = 'Rue du Progrès',
  Object? number = '12',
  Object? point = const {'latitude': 50.7436, 'longitude': 3.2167},
  Object? radius = 50,
}) => {'name': name, 'street': street, 'number': number, 'box': null, 'zipcode': '7700', 'city': 'Mouscron', 'point': point, 'radiusMeters': radius};

Future<Map<String, Object?>> _error(Future<Response> request) async {
  final response = await request;
  return {'status': response.statusCode, ...(await jsonBody(response))['error']! as Map<String, Object?>};
}

void main() {
  test('add: the location comes back, audited with its three rows', () async {
    final app = TestApp();

    final response = await app.post('/locations', jsonEncode(_body()));

    expect(response.statusCode, 201);
    final body = await jsonBody(response);
    expect(body['name'], 'Almeco office');
    expect(body['radiusMeters'], 50);
    expect(body['isActive'], true);
    final event = app.audit.events.single;
    expect(event.type, AuditEventType.locationCreated);
    expect(event.references.keys, [EventLogReference.address, EventLogReference.geofence, EventLogReference.geofenceAddress]);
  });

  test('the list holds every location, inactive ones too', () async {
    final app = TestApp();
    await app.post('/locations', jsonEncode(_body()));
    await app.post('/locations/1/deactivate', '');

    final list = LocationListResponse.fromJson(await jsonBody(await app.get('/locations'))).locations;

    expect(list.single.isActive, false);
    expect(list.single.point?.latitude, 50.7436);
  });

  test('texts are trimmed and an empty optional text is stored as nothing', () async {
    final app = TestApp();

    final body = await jsonBody(await app.post('/locations', jsonEncode(_body(name: '  Depot  ', number: '  '))));

    expect(body['name'], 'Depot');
    expect(body['number'], isNull);
  });

  group('checked before any write', () {
    for (final (what, body, field) in [
      ('no name', _body(name: '   '), 'name'),
      ('a long name', _body(name: 'x' * 101), 'name'),
      ('no street', _body(street: ' '), 'street'),
      ('a long number', _body(number: '1' * 21), 'number'),
      ('a pin outside the map', _body(point: {'latitude': 91, 'longitude': 3}), 'point'),
      ('an area too small', _body(radius: 24), 'radiusMeters'),
      ('an area too big', _body(radius: 201), 'radiusMeters'),
    ]) {
      test('$what → 400 naming "$field"', () async {
        final app = TestApp();

        final error = await _error(app.post('/locations', jsonEncode(body)));

        expect(error, containsPair('status', 400));
        expect(error, containsPair('field', field));
        expect(app.audit.events, isEmpty);
      });
    }

    test('malformed bodies are bad requests', () async {
      final app = TestApp();

      expect((await app.post('/locations', '{')).statusCode, 400);
      expect((await app.post('/locations', jsonEncode(_body(point: null)))).statusCode, 400);
      expect((await app.post('/locations', jsonEncode(_body(radius: '50')))).statusCode, 400);
    });
  });

  test('a name in use → 409 on the name field, also when changing another location', () async {
    final app = TestApp();
    await app.post('/locations', jsonEncode(_body()));
    await app.post('/locations', jsonEncode(_body(name: 'Depot')));

    for (final request in [
      app.post('/locations', jsonEncode(_body())),
      app.put('/locations/2', jsonEncode(_body())),
    ]) {
      final error = await _error(request);
      expect(error, containsPair('status', 409));
      expect(error, containsPair('code', ApiErrorCode.duplicateLocationName));
      expect(error, containsPair('field', 'name'));
    }
  });

  test('change: saved and audited once; saving the same again changes nothing', () async {
    final app = TestApp();
    await app.post('/locations', jsonEncode(_body()));

    final changed = await jsonBody(await app.put('/locations/1', jsonEncode(_body(radius: 100))));
    await app.put('/locations/1', jsonEncode(_body(radius: 100)));

    expect(changed['radiusMeters'], 100);
    expect(app.audit.events.map((e) => e.type), [AuditEventType.locationCreated, AuditEventType.locationChanged]);
  });

  test('deactivate and reactivate are audited once each', () async {
    final app = TestApp();
    await app.post('/locations', jsonEncode(_body()));

    await app.post('/locations/1/deactivate', '');
    await app.post('/locations/1/deactivate', '');
    final body = await jsonBody(await app.post('/locations/1/reactivate', ''));

    expect(body['isActive'], true);
    expect(app.audit.events.map((e) => e.type), [
      AuditEventType.locationCreated,
      AuditEventType.locationDeactivated,
      AuditEventType.locationReactivated,
    ]);
  });

  test('an unknown location is 404', () async {
    final app = TestApp();

    expect((await app.put('/locations/9', jsonEncode(_body()))).statusCode, 404);
    expect((await app.post('/locations/9/deactivate', '')).statusCode, 404);
  });

  test('a failed audit leaves no success', () async {
    final app = TestApp();
    app.audit.failWith = StateError('audit down');

    expect((await app.post('/locations', jsonEncode(_body()))).statusCode, 500);
    expect(app.transactions.outcomes, ['rollback']);
  });

  test('reading needs viewLocations, every change manageLocations; neither is company-scoped', () async {
    final app = TestApp(allowPermissions: false);

    for (final response in [
      await app.get('/locations'),
      await app.post('/locations', jsonEncode(_body())),
      await app.put('/locations/1', jsonEncode(_body())),
      await app.post('/locations/1/deactivate', ''),
      await app.post('/locations/1/reactivate', ''),
    ]) {
      expect(response.statusCode, 403);
    }
    expect(app.permissions.checked.map((c) => (c.$2, c.$3)).toSet(), {
      (Permission.viewLocations, null),
      (Permission.manageLocations, null),
    });
  });

  group('addressCoordinates', () {
    test('written as "latitude,longitude"', () {
      expect(LocationRepository.formatCoordinates(const GeoPoint(latitude: 50.7436, longitude: 3.2167)), '50.743600,3.216700');
    });

    test('read back, also the short form in IT\'s comment', () {
      final point = LocationRepository.parseCoordinates('50.7436,3.2167');
      expect((point?.latitude, point?.longitude), (50.7436, 3.2167));
    });

    for (final stored in [null, '', '50.7', '50.7;3.2', 'a,b', '1,2,3', '91,3']) {
      test('unreadable: $stored', () => expect(LocationRepository.parseCoordinates(stored), isNull));
    }
  });
}
