import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _details = EmployeeDetails(
  id: 1,
  companyId: 7,
  companyName: 'Almeco',
  firstName: 'Disan',
  lastName: 'Ssebowa',
  code: 'SBW',
  groups: ['White collar'],
  phone: '+32 470',
  isActive: true,
);

TestApp _app({bool allow = true}) {
  final app = TestApp(devUserId: 9, activeUserIds: {9}, allowPermissions: allow);
  app.companies.existingIds = {7, 8};
  app.employees.details = {(7, 1): _details};
  return app;
}

void main() {
  test('returns the employee, checking viewEmployees for that company', () async {
    final app = _app();

    final response = await app.get('/companies/7/employees/1');

    expect(response.statusCode, 200);
    expect(await jsonBody(response), _details.toJson());
    expect(app.permissions.checked, [(9, Permission.viewEmployees, 7)]);
  });

  test('404 when the employee is not in that company (no cross-company peeking)', () async {
    expect((await _app().get('/companies/8/employees/1')).statusCode, 404);
  });

  test('404 for an unknown company or employee', () async {
    expect((await _app().get('/companies/99/employees/1')).statusCode, 404);
    expect((await _app().get('/companies/7/employees/42')).statusCode, 404);
  });

  test('403 without the permission', () async {
    expect((await _app(allow: false).get('/companies/7/employees/1')).statusCode, 403);
  });
}
