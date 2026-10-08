import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _path = '/companies/1/employees/2/time-registrations';
const _range = 'from=2026-10-01&to=2026-10-08';

TimeRegistration _reg(int id, DateTime at) => TimeRegistration(
  id: id,
  userId: 2,
  timestamp: at,
  typeId: 1,
  typeName: 'Type from tblTimeRegType',
  addressId: null,
  addressName: null,
  isManualEntry: false,
  comment: null,
  modifiedAt: null,
);

/// HR user 9 works in Almeco (1); employee 2 belongs to Almeco.
TestApp _app() {
  final app = TestApp(devUserId: 9, activeUserIds: {9, 2});
  app.companies.existingIds = {1, 2};
  app.employees.members = {(1, 2)};
  app.timeRegistrations.rows = [
    _reg(10, DateTime(2026, 10, 6, 8)),
    _reg(11, DateTime(2026, 10, 6, 8)),
    _reg(12, DateTime(2026, 10, 6, 16, 30)),
  ];
  return app;
}

List<int> _ids(Map<String, Object?> body) => [
  for (final r in (body['registrations']! as List<Object?>).cast<Map<String, Object?>>()) r['id']! as int,
];

void main() {
  group('GET employee time registrations (HR/Admin)', () {
    test('returns the stream oldest first with wall-clock times and raw types', () async {
      final app = _app();

      final response = await app.get('$_path?$_range');

      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      expect(_ids(body), [10, 11, 12]);
      final first = (body['registrations']! as List<Object?>).first! as Map<String, Object?>;
      expect(first['timestamp'], '2026-10-06T08:00:00.000', reason: 'no offset: timezone unknown (GAP-02)');
      expect(first['typeName'], 'Type from tblTimeRegType');
      expect(body['nextCursor'], isNull);
      final query = app.timeRegistrations.queries.single;
      expect((query.userId, query.from, query.to), (2, DateTime(2026, 10, 1), DateTime(2026, 10, 8)));
    });

    test('company-scoped: permission in the path company; another company\'s employee is 404', () async {
      final app = _app();

      await app.get('$_path?$_range');
      expect(app.permissions.checked.last, (9, Permission.viewTimeRegistrations, 1));
      expect((await app.get('/companies/2/employees/2/time-registrations?$_range')).statusCode, 404);
      expect(app.timeRegistrations.queries, hasLength(1), reason: 'nothing read for the refused request');

      app.permissions.deniedCompanies = {1};
      expect((await app.get('$_path?$_range')).statusCode, 403);
    });

    test('pages with an opaque cursor; equal timestamps continue by id', () async {
      final app = _app();

      final first = await jsonBody(await app.get('$_path?$_range&limit=1'));
      final second = await jsonBody(await app.get('$_path?$_range&limit=1&cursor=${first['nextCursor']}'));
      final third = await jsonBody(await app.get('$_path?$_range&limit=1&cursor=${second['nextCursor']}'));

      expect([..._ids(first), ..._ids(second), ..._ids(third)], [10, 11, 12]);
      expect(third['nextCursor'], isNull);
      expect(app.timeRegistrations.queries.first.limit, 2, reason: 'one extra row detects the next page');
    });

    test('from/to are required wall-clock values without timezone; to after from', () async {
      final app = _app();
      Future<Object?> field(String query) async {
        final response = await app.get('$_path?$query');
        expect(response.statusCode, 400, reason: query);
        return ((await jsonBody(response))['error']! as Map<String, Object?>)['field'];
      }

      expect(await field('to=2026-10-08'), 'from');
      expect(await field('from=2026-10-01'), 'to');
      expect(await field('from=2026-10-01T08:00:00Z&to=2026-10-08'), 'from');
      expect(await field('from=2026-10-01T08:00+02:00&to=2026-10-08'), 'from');
      expect(await field('from=yesterday&to=2026-10-08'), 'from');
      expect(await field('from=2026-10-08&to=2026-10-08'), 'to');
      expect(await field('$_range&limit=0'), 'limit');
      expect(await field('$_range&limit=501'), 'limit');
      expect(await field('$_range&cursor=not-a-cursor'), 'cursor');
      expect(app.timeRegistrations.queries, isEmpty);
    });

    test('times of day are accepted', () async {
      final app = _app();

      expect((await app.get('$_path?from=2026-10-06T07:30&to=2026-10-06T12:00:30')).statusCode, 200);
      expect(app.timeRegistrations.queries.single.from, DateTime(2026, 10, 6, 7, 30));
    });
  });

  group('GET /me/time-registrations', () {
    test('the signed-in user reads only their own registrations, no permission needed', () async {
      final app = TestApp(devUserId: 2, activeUserIds: {2}, allowPermissions: false)
        ..timeRegistrations.rows = [_reg(10, DateTime(2026, 10, 6, 8))];

      final response = await app.get('/me/time-registrations?$_range');

      expect(response.statusCode, 200);
      expect(app.timeRegistrations.queries.single.userId, 2);
    });

    test('requires sign-in', () async {
      expect((await TestApp(devUserId: null).get('/me/time-registrations?$_range')).statusCode, 401);
    });
  });
}
