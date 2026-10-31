import 'dart:convert';

import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _path = '/me/time-registrations';

const _office = LocationRequest(
  name: 'Almeco office',
  street: 'Rue du Progrès',
  point: GeoPoint(latitude: 50.7, longitude: 3.2),
  radiusMeters: 50,
);

/// Thursday 22 October 2026: Brussels is UTC+2.
Future<TestApp> _app() async {
  final app = TestApp(devUserId: 9, activeUserIds: {9})..now = DateTime.utc(2026, 10, 22, 18);
  await app.locations.insert(app.unusedExecutor, _office);
  return app;
}

String _body({
  String boundary = 'start',
  String at = '2026-10-22T06:04:00Z',
  String entry = 'now',
  Object? addressId = 1,
  String method = 'geofence',
}) => jsonEncode({'boundary': boundary, 'method': method, 'entry': entry, 'at': at, 'addressId': addressId});

Future<Map<String, Object?>> _error(TestApp app, String body) async {
  final response = await app.post(_path, body);
  return {'status': response.statusCode, ...(await jsonBody(response))['error']! as Map<String, Object?>};
}

void main() {
  test('an arrival is stored as actual and rounded, at that location, not as a manual entry', () async {
    final app = await _app();

    final response = await app.post(_path, _body());

    expect(response.statusCode, 201);
    final rows = app.timeRegistrationWrites.rows;
    expect(rows.map((r) => r.typeId), [2, 8], reason: 'Start – actual – Geofence, Start – rounded');
    expect(rows.map((r) => r.addressId), [1, 1]);
    expect(rows.first.manualEntry, false);
  });

  test('a day with no schedule starts too (D33)', () async {
    final app = await _app();

    expect((await app.post(_path, _body())).statusCode, 201);
  });

  test('back from a short exit: no second start, the running one comes back (D32)', () async {
    final app = await _app();
    await app.post(_path, _body());

    final back = await app.post(_path, _body(at: '2026-10-22T10:30:00Z'));

    expect(back.statusCode, 200);
    expect(RegisteredTime.fromJson(await jsonBody(back)).actualAt, DateTime.utc(2026, 10, 22, 6, 4));
    expect(app.timeRegistrationWrites.rows, hasLength(2));
  });

  test('a manual start counts as running as well', () async {
    final app = await _app();
    await app.post(_path, _body(method: 'manual', addressId: null));

    expect((await app.post(_path, _body(at: '2026-10-22T07:00:00Z'))).statusCode, 200);
  });

  test('after a finish, an arrival starts again', () async {
    final app = await _app();
    await app.post(_path, _body());
    await app.post(_path, _body(boundary: 'finish', at: '2026-10-22T14:30:00Z'));

    expect((await app.post(_path, _body(at: '2026-10-22T16:00:00Z'))).statusCode, 201);
  });

  test('yesterday\'s open day does not swallow today\'s arrival', () async {
    final app = await _app();
    await app.post(_path, _body(at: '2026-10-21T06:00:00Z'));

    expect((await app.post(_path, _body())).statusCode, 201);
  });

  test('the same event sent twice is stored once', () async {
    final app = await _app();
    await app.post(_path, _body());

    expect((await app.post(_path, _body())).statusCode, 200);
    expect(app.timeRegistrationWrites.rows, hasLength(2));
  });

  for (final (what, addressId) in [('no location', null), ('an unknown location', 99)]) {
    test('$what → 400 on addressId', () async {
      final app = await _app();

      final error = await _error(app, _body(addressId: addressId));

      expect(error, containsPair('status', 400));
      expect(error, containsPair('field', 'addressId'));
    });
  }

  test('an inactive location → 400 on addressId', () async {
    final app = await _app();
    await app.locations.setActive(app.unusedExecutor, 1, active: false);

    expect(await _error(app, _body()), containsPair('field', 'addressId'));
  });

  test('a detected time can only be sent as it happened', () async {
    final app = await _app();

    expect(await _error(app, _body(entry: 'first_day')), containsPair('field', 'entry'));
  });

  group('GET /me/locations', () {
    test('active locations with a pin only', () async {
      final app = await _app();
      await app.locations.insert(app.unusedExecutor, const LocationRequest(
        name: 'Old depot',
        street: 'Kaai',
        point: GeoPoint(latitude: 50, longitude: 3),
        radiusMeters: 75,
      ));
      await app.locations.setActive(app.unusedExecutor, 2, active: false);

      final body = await jsonBody(await app.get('/me/locations'));

      expect(LocationListResponse.fromJson(body).locations.map((l) => l.name), ['Almeco office']);
    });

    test('needs no HR permission: every employee\'s phone reads it', () async {
      final app = TestApp(allowPermissions: false);

      expect((await app.get('/me/locations')).statusCode, 200);
    });

    test('a session is required', () async {
      final app = TestApp(devUserId: null);

      expect((await app.get('/me/locations')).statusCode, 401);
    });
  });
}
