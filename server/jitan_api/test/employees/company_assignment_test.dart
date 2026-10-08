import 'dart:convert';

import 'package:jitan_api/src/auth/permission.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _path = '/companies/1/employees/2/assignments/companies';

/// HR user 9 manages Almeco (1). Employee 2 belongs to Almeco. PCA (2) is
/// active, Akwa (3) inactive. One company per employee (MVP).
TestApp _app() {
  final app = TestApp(devUserId: 9, activeUserIds: {9});
  app.companies.existingIds = {1, 2, 3, 4};
  app.employees.members = {(1, 2)};
  app.assignments.companies = {
    1: (name: 'Almeco', active: true),
    2: (name: 'PCA', active: true),
    3: (name: 'Akwa', active: false),
  };
  app.assignments.userCompanies[(2, 1)] = 11;
  return app;
}

Future<List<(int, String, bool, bool)>> _options(Response response) async => [
  for (final o in (await jsonBody(response))['options']! as List<Object?>)
    if (o case {'id': final int id, 'name': final String name, 'isAssigned': final bool s, 'isAssignable': final bool a})
      (id, name, s, a),
];

String _add(List<int> ids) => jsonEncode({'ids': ids});

void main() {
  group('GET company assignments', () {
    test('the current company is assigned; others are listed but not assignable (one company)', () async {
      final response = await _app().get(_path);

      expect(response.statusCode, 200);
      expect(await _options(response), [(1, 'Almeco', true, false), (2, 'PCA', false, false)]);
    });

    test('existing (historical) second memberships are still shown, never hidden or removed', () async {
      final app = _app()
        ..assignments.companies[4] = (name: 'Proceq', active: false)
        ..assignments.userCompanies[(2, 4)] = 14;

      final options = await _options(await app.get(_path));

      expect(options.where((o) => o.$3).map((o) => o.$2), ['Almeco', 'Proceq']);
    });

    test('company-scoped: needs the permission in that company; another company\'s employee is 404', () async {
      final app = _app();

      await app.get(_path);
      expect(app.permissions.checked.last, (9, Permission.manageEmployeeAssignments, 1));
      expect((await app.get('/companies/2/employees/2/assignments/companies')).statusCode, 404);

      app.permissions.deniedCompanies = {1};
      expect((await app.get(_path)).statusCode, 403);
    });
  });

  group('POST company assignments (one company per employee)', () {
    test('adding a second company is refused with employee_company_limit; nothing is written', () async {
      final app = _app();

      final response = await app.post(_path, _add([2]));

      expect(response.statusCode, 409);
      expect((await jsonBody(response))['error'], containsPair('code', 'employee_company_limit'));
      expect(app.assignments.userCompanies.keys, [(2, 1)]);
      expect(app.audit.events, isEmpty);
      expect(app.transactions.outcomes, isEmpty);
    });

    test('the current company again is a no-op (never duplicated)', () async {
      final app = _app();

      final response = await app.post(_path, _add([1]));

      expect(response.statusCode, 200);
      expect(app.audit.events, isEmpty);
      expect(app.assignments.userCompanies.keys, [(2, 1)]);
    });

    test('mixing the current company with a new one is still refused', () async {
      final app = _app();

      expect((await app.post(_path, _add([1, 2]))).statusCode, 409);
      expect(app.assignments.userCompanies.keys, [(2, 1)]);
    });

    test('inactive, MFD or unknown companies are refused on the ids field', () async {
      for (final ids in [[3], [99], [2, 99]]) {
        final app = _app();
        final response = await app.post(_path, _add(ids));
        expect(response.statusCode, 400, reason: '$ids');
        expect((await jsonBody(response))['error'], containsPair('field', 'ids'));
        expect(app.audit.events, isEmpty);
      }
    });

    test('empty, malformed or oversized requests are refused', () async {
      final app = _app();

      expect((await app.post(_path, _add([]))).statusCode, 400);
      expect((await app.post(_path, jsonEncode({'ids': ['2']}))).statusCode, 400);
      expect((await app.post(_path, '{oops')).statusCode, 400);
      expect((await app.post(_path, _add([for (var i = 1; i <= 101; i++) i]))).statusCode, 400);
    });

    test('another company\'s employee is 404 and nothing is written', () async {
      final app = _app();

      expect((await app.post('/companies/2/employees/2/assignments/companies', _add([2]))).statusCode, 404);
      expect(app.audit.events, isEmpty);
    });
  });
}
