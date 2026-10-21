import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

const _sbw = EmployeeSummary(
  id: 1,
  firstName: 'Disan',
  lastName: 'Ssebowa',
  code: 'SBW',
  groups: ['White collar'],
  isActive: true,
  isActivated: false,
  companyIds: [7, 8],
);
const _kdv = EmployeeSummary(
  id: 2,
  firstName: 'Kevin',
  lastName: 'De Vos',
  code: 'KDV',
  groups: [],
  isActive: true,
  isActivated: true,
  companyIds: [8],
);

TestApp _app({bool allow = true}) {
  final app = TestApp(devUserId: 9, activeUserIds: {9}, allowPermissions: allow);
  app.companies.companies = [company(7, 'Almeco'), company(8, 'PCA'), company(9, 'Akwa')];
  app.employees.byCompany = {
    7: [_sbw],
    8: [_sbw, _kdv],
    9: const [],
  };
  return app;
}

/// `GET /employees`: the Employees list when no "Current company" is
/// chosen (the switcher is only a filter, product owner 2026-10-21).
void main() {
  test('lists the employees of every company, each once, with their companies', () async {
    final app = _app();

    final response = await app.get('/employees');

    expect(response.statusCode, 200);
    final list = EmployeeListResponse.fromJson(await jsonBody(response));
    expect(list.companyId, isNull);
    expect([for (final e in list.employees) (e.code, e.companyIds.join(','))], [('SBW', '7,8'), ('KDV', '8')]);
    expect(app.employees.allCompanyCalls, [
      [7, 8, 9],
    ]);
  });

  test('only companies where the viewer may see employees are listed (each checked on its own)', () async {
    final app = _app();
    app.permissions.deniedCompanies = {8};

    final response = await app.get('/employees');

    final list = EmployeeListResponse.fromJson(await jsonBody(response));
    expect([for (final e in list.employees) e.code], ['SBW'], reason: 'KDV is only in company 8');
    expect(app.employees.allCompanyCalls, [
      [7, 9],
    ]);
    expect(app.permissions.checked.map((c) => (c.$2, c.$3)), [
      (Permission.viewEmployees, 7),
      (Permission.viewEmployees, 8),
      (Permission.viewEmployees, 9),
    ]);
  });

  test('no right anywhere: an empty list, nothing read', () async {
    final app = _app(allow: false);

    final response = await app.get('/employees');

    expect(response.statusCode, 200);
    expect(EmployeeListResponse.fromJson(await jsonBody(response)).employees, isEmpty);
    expect(app.employees.allCompanyCalls, [<int>[]]);
  });

  test('search is passed on trimmed; too long is 400', () async {
    final app = _app();

    await app.get('/employees?search=%20dis%20');
    expect(app.employees.calls.last, (-1, 'dis'));

    final response = await app.get('/employees?search=${'x' * 101}');
    expect(response.statusCode, 400);
  });
}
