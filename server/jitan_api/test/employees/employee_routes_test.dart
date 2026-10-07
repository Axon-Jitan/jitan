import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _sbw = EmployeeSummary(
  id: 1,
  firstName: 'Disan',
  lastName: 'Ssebowa',
  code: 'SBW',
  groups: ['White collar'],
  isActive: true,
);
const _tvm = EmployeeSummary(
  id: 2,
  firstName: 'Thomas',
  lastName: 'Vermeulen',
  code: 'TVM',
  groups: ['Blue collar', 'Night shift'],
  isActive: false,
);

TestApp _app({bool allow = true}) {
  final app = TestApp(devUserId: 9, activeUserIds: {9}, allowPermissions: allow);
  app.companies.existingIds = {7, 8};
  app.employees.byCompany = {
    7: [_sbw, _tvm],
    8: const [],
  };
  return app;
}

void main() {
  group('GET /companies/{id}/employees', () {
    test("returns that company's employees, all groups included", () async {
      final app = _app();

      final response = await app.get('/companies/7/employees');
      final body = await jsonBody(response);

      expect(response.statusCode, 200);
      expect(body['companyId'], 7);
      expect(body['employees'], [
        {
          'id': 1,
          'firstName': 'Disan',
          'lastName': 'Ssebowa',
          'code': 'SBW',
          'groups': ['White collar'],
          'isActive': true,
        },
        {
          'id': 2,
          'firstName': 'Thomas',
          'lastName': 'Vermeulen',
          'code': 'TVM',
          'groups': ['Blue collar', 'Night shift'],
          'isActive': false,
        },
      ]);
    });

    test('is scoped: another company returns only its own employees', () async {
      final app = _app();

      final body = await jsonBody(await app.get('/companies/8/employees'));

      expect(body, {'companyId': 8, 'employees': <Object?>[]});
      expect(app.employees.calls.single.$1, 8);
    });

    test('checks the permission for that specific company', () async {
      final app = _app();

      await app.get('/companies/7/employees');

      expect(app.permissions.checked, [(9, Permission.viewEmployees, 7)]);
    });

    test('403 when the user may not view that company, before any data access', () async {
      final app = _app(allow: false);

      final response = await app.get('/companies/7/employees');

      expect(response.statusCode, 403);
      expect(app.employees.calls, isEmpty);
    });

    test('404 for an unknown or deleted company', () async {
      final response = await _app().get('/companies/99/employees');

      expect(response.statusCode, 404);
      expect((await jsonBody(response))['error'], containsPair('code', 'not_found'));
    });

    test('404 for a non-numeric company id', () async {
      expect((await _app().get('/companies/abc/employees')).statusCode, 404);
    });

    test('passes a trimmed search; blank means no filter', () async {
      final app = _app();

      await app.get('/companies/7/employees?search=%20sbw%20');
      await app.get('/companies/7/employees?search=%20');

      expect(app.employees.calls, [(7, 'sbw'), (7, null)]);
    });

    test('400 for an over-long search', () async {
      final app = _app();

      final response = await app.get('/companies/7/employees?search=${'a' * 101}');

      expect(response.statusCode, 400);
      expect(app.employees.calls, isEmpty);
    });

    test('401 without an identity', () async {
      final app = TestApp(devUserId: null)..companies.existingIds = {7};

      expect((await app.get('/companies/7/employees')).statusCode, 401);
    });
  });

  test('GET /companies still answers alongside the employee routes', () async {
    expect((await _app().get('/companies')).statusCode, 200);
  });
}
